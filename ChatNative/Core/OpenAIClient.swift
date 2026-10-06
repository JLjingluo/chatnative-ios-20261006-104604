import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum APIError: LocalizedError {
    case invalidURL, missingKey, emptyResponse, http(Int, String), server(String), invalidImageModel
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请输入有效的 HTTPS API 地址，例如 https://api.openai.com/v1。"
        case .missingKey: return "请先在设置中填写 API Key 或网关用户令牌。"
        case .emptyResponse: return "接口没有返回文字内容，请检查模型是否支持 Chat Completions。"
        case .http(let code, let detail): return "请求失败（\(code)）：\(detail)"
        case .server(let message): return message
        case .invalidImageModel: return "当前模型未启用图片能力。请在模型设置中开启，或移除图片。"
        }
    }
}

/// SSE supports comments, CRLF, multi-line data and an unterminated final event.
struct SSEParser {
    private var dataLines: [String] = []
    mutating func feed(_ line: String) -> String? {
        let clean = line.hasSuffix("\r") ? String(line.dropLast()) : line
        if clean.isEmpty { return flush() }
        if clean.hasPrefix("data:") {
            var value = String(clean.dropFirst(5))
            if value.hasPrefix(" ") { value.removeFirst() }
            dataLines.append(value)
        }
        return nil
    }
    mutating func flush() -> String? {
        guard !dataLines.isEmpty else { return nil }
        defer { dataLines.removeAll() }
        return dataLines.joined(separator: "\n")
    }
}

struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { var content: String? }
        var delta: Delta
    }
    struct Failure: Decodable { var message: String }
    var choices: [Choice]?
    var error: Failure?
}

struct OpenAIClient {
    var session: URLSession = .shared
    static func endpoint(base: String, resource: String) throws -> URL {
        guard var parts = URLComponents(string: base.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.scheme == "https" || (parts.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host))
        else { throw APIError.invalidURL }
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        // Accept a full chat endpoint as well as an API root.
        if path.hasSuffix("/chat/completions") { path = String(path.dropLast("/chat/completions".count)) }
        parts.path = path + "/" + resource
        guard let url = parts.url else { throw APIError.invalidURL }
        return url
    }

    static func context(_ messages: [Message], limit: Int) -> [Message] {
        let eligible = messages.filter {
            $0.role != .system && (!$0.text.isEmpty || !$0.attachments.isEmpty) && !($0.role == .assistant && $0.interrupted)
        }
        var result = Array(eligible.suffix(max(1, limit)))
        while result.first?.role == .assistant { result.removeFirst() }
        return result
    }

    static func request(settings: AppSettings, key: String, model: String, messages: [Message]) throws -> URLRequest {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.missingKey }
        let history = context(messages, limit: settings.contextLimit)
        if history.contains(where: { !$0.attachments.isEmpty }), settings.models.first(where: { $0.id == model })?.supportsImages != true {
            throw APIError.invalidImageModel
        }
        var wireMessages: [[String: Any]] = []
        if !settings.systemPrompt.isEmpty { wireMessages.append(["role": "system", "content": settings.systemPrompt]) }
        wireMessages += history.map { message in
            if message.attachments.isEmpty { return ["role": message.role.rawValue, "content": message.text] }
            var content: [[String: Any]] = []
            if !message.text.isEmpty { content.append(["type": "text", "text": message.text]) }
            content += message.attachments.map { ["type": "image_url", "image_url": ["url": $0.dataURL]] }
            return ["role": message.role.rawValue, "content": content]
        }
        var body: [String: Any] = ["model": model, "messages": wireMessages, "stream": true]
        if settings.temperatureEnabled { body["temperature"] = settings.temperature }
        var request = URLRequest(url: try endpoint(base: settings.baseURL, resource: "chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func content(event: String) throws -> String? {
        if event == "[DONE]" { return nil }
        let chunk = try JSONDecoder().decode(StreamChunk.self, from: Data(event.utf8))
        if let error = chunk.error { throw APIError.server(error.message) }
        return chunk.choices?.first?.delta.content
    }

    #if !os(Linux)
    func stream(settings: AppSettings, key: String, model: String, messages: [Message], onText: @escaping @Sendable (String) async -> Void) async throws {
        let request = try Self.request(settings: settings, key: key, model: model, messages: messages)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= 4096 { break }
            }
            throw APIError.http(http.statusCode, Self.errorDetail(body, key: key))
        }
        // Some compatible providers ignore stream=true and return a regular completion.
        if http.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true {
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                data.append(byte)
                if data.count > 8_000_000 { throw APIError.server("接口响应过大。") }
            }
            struct Completion: Decodable {
                struct Choice: Decodable { struct Reply: Decodable { let content: String? }; let message: Reply }
                let choices: [Choice]
            }
            let completion = try JSONDecoder().decode(Completion.self, from: data)
            guard let text = completion.choices.first?.message.content, !text.isEmpty else { throw APIError.emptyResponse }
            await onText(text)
            return
        }
        try await Self.consumeSSE(bytes, onText: onText)
    }
    #endif

    /// Shared by the native transport and portable integration tests.
    static func consumeSSE<S: AsyncSequence>(_ bytes: S, onText: @escaping @Sendable (String) async -> Void) async throws where S.Element == UInt8 {
        var parser = SSEParser()
        var receivedText = false
        var lineBuffer = Data()
        var done = false
        var eventBytes = 0
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte == 10 {
                let line = String(decoding: lineBuffer, as: UTF8.self)
                if line.isEmpty || line == "\r" { eventBytes = 0 }
                lineBuffer.removeAll(keepingCapacity: true)
                if let event = parser.feed(line) {
                    if event == "[DONE]" { done = true; break }
                    if let text = try Self.content(event: event), !text.isEmpty {
                        receivedText = true
                        await onText(text)
                    }
                }
            } else {
                lineBuffer.append(byte)
                eventBytes += 1
                if eventBytes > 8_000_000 { throw APIError.server("接口事件过大。") }
                if lineBuffer.count > 1_000_000 { throw APIError.server("接口事件过大。") }
            }
        }
        if !done {
            if !lineBuffer.isEmpty { _ = parser.feed(String(decoding: lineBuffer, as: UTF8.self)) }
            if let event = parser.flush(), event != "[DONE]", let text = try Self.content(event: event), !text.isEmpty {
                receivedText = true
                await onText(text)
            }
        }
        try Task.checkCancellation()
        if !receivedText { throw APIError.emptyResponse }
    }

    static func errorDetail(_ data: Data, key: String) -> String {
        struct Envelope: Decodable { struct Failure: Decodable { let message: String }; let error: Failure }
        let message = (try? JSONDecoder().decode(Envelope.self, from: data).error.message) ?? "请检查地址、令牌、模型名称及上游服务状态。"
        return String(message.replacingOccurrences(of: key, with: "[已隐藏]").prefix(500))
    }

    func fetchModels(settings: AppSettings, key: String) async throws -> [String] {
        guard !key.isEmpty else { throw APIError.missingKey }
        var request = URLRequest(url: try Self.endpoint(base: settings.baseURL, resource: "models"))
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode, Self.errorDetail(data, key: key)) }
        struct List: Decodable { struct Entry: Decodable { let id: String }; let data: [Entry] }
        return try JSONDecoder().decode(List.self, from: data).data.map(\.id).sorted()
    }
}
