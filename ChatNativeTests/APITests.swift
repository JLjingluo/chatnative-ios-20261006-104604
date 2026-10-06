import XCTest
#if canImport(ChatNativeCore)
@testable import ChatNativeCore
#else
@testable import ChatNative
#endif

final class APITests: XCTestCase {
    func testEndpointNormalization() throws {
        XCTAssertEqual(try OpenAIClient.endpoint(base: "https://gateway.test/v1/", resource: "chat/completions").absoluteString, "https://gateway.test/v1/chat/completions")
        XCTAssertEqual(try OpenAIClient.endpoint(base: "https://gateway.test/api/chat/completions", resource: "models").absoluteString, "https://gateway.test/api/models")
        XCTAssertThrowsError(try OpenAIClient.endpoint(base: "http://public.test/v1", resource: "models"))
        XCTAssertThrowsError(try OpenAIClient.endpoint(base: "https://user:secret@gateway.test/v1", resource: "models"))
        XCTAssertThrowsError(try OpenAIClient.endpoint(base: "https://gateway.test/v1?key=secret", resource: "models"))
        XCTAssertThrowsError(try OpenAIClient.endpoint(base: "not a url", resource: "models"))
        XCTAssertEqual(try OpenAIClient.endpoint(base: "http://localhost:4000/v1", resource: "models").host, "localhost")
    }
    func testRequestIncludesSystemHistoryAndImages() throws {
        let settings = AppSettings()
        let messages = [Message(role: .user, text: "描述图片", attachments: [Attachment(data: Data([0, 1, 2]))])]
        let request = try OpenAIClient.request(settings: settings, key: "test-key", model: "gpt-4o-mini", messages: messages)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertNil(body["temperature"])
        XCTAssertEqual(body["model"] as? String, "gpt-4o-mini")
        let wire = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(wire.first?["role"] as? String, "system")
        let content = try XCTUnwrap(wire.last?["content"] as? [[String: Any]])
        XCTAssertEqual(content.first?["text"] as? String, "描述图片")
        XCTAssertEqual((content.last?["image_url"] as? [String: String])?["url"], "data:image/jpeg;base64,AAEC")
    }
    func testVisionCapabilityAndMissingKey() {
        var settings = AppSettings()
        settings.models = [ModelOption(id: "text-only", name: "Text")]
        XCTAssertThrowsError(try OpenAIClient.request(settings: settings, key: "x", model: "text-only", messages: [Message(role: .user, text: "hi", attachments: [Attachment(data: Data())])]))
        XCTAssertThrowsError(try OpenAIClient.request(settings: settings, key: "  ", model: "text-only", messages: [Message(role: .user, text: "hi")]))
    }
    func testContextStartsWithUserAndExcludesInterruptedReplies() {
        let messages = [Message(role: .user, text: "one"), Message(role: .assistant, text: "answer"), Message(role: .user, text: "two"), Message(role: .assistant, text: "partial", interrupted: true), Message(role: .user, text: "three")]
        XCTAssertEqual(OpenAIClient.context(messages, limit: 3).map(\.text), ["two", "three"])
        XCTAssertEqual(OpenAIClient.context(messages, limit: 1).map(\.text), ["three"])
    }
    func testSSEPreservesBlankBoundaryCRLFCommentsAndMultiline() {
        var parser = SSEParser()
        XCTAssertNil(parser.feed(": keep-alive"))
        XCTAssertNil(parser.feed("event: message\r"))
        XCTAssertNil(parser.feed("data: {\r"))
        XCTAssertNil(parser.feed("data: \"choices\": []}\r"))
        XCTAssertEqual(parser.feed("\r"), "{\n\"choices\": []}")
        XCTAssertNil(parser.feed(""))
        XCTAssertNil(parser.feed("data: [DONE]"))
        XCTAssertEqual(parser.flush(), "[DONE]")
    }
    func testStreamContentHandlesUnicodeMetadataAndErrors() throws {
        XCTAssertEqual(try OpenAIClient.content(event: #"{"choices":[{"delta":{"content":"你好🌍"}}]}"#), "你好🌍")
        XCTAssertNil(try OpenAIClient.content(event: #"{"choices":[{"delta":{"role":"assistant"}}]}"#))
        XCTAssertNil(try OpenAIClient.content(event: #"{"choices":[],"usage":{"total_tokens":12}}"#))
        XCTAssertNil(try OpenAIClient.content(event: "[DONE]"))
        XCTAssertThrowsError(try OpenAIClient.content(event: #"{"error":{"message":"Quota exceeded"}}"#))
        XCTAssertThrowsError(try OpenAIClient.content(event: "invalid JSON"))
    }
    func testErrorRedactsKeyAndDoesNotDisplayRawHTML() {
        XCTAssertEqual(OpenAIClient.errorDetail(Data(#"{"error":{"message":"Invalid test-key"}}"#.utf8), key: "test-key"), "Invalid [已隐藏]")
        XCTAssertFalse(OpenAIClient.errorDetail(Data("<html>private proxy info</html>".utf8), key: "key").contains("private"))
    }
    func testSettingsAndConversationRoundTrip() throws {
        let conversation = Conversation(messages: [Message(role: .user, text: "hi", attachments: [Attachment(data: Data([3, 4]))])], model: "custom")
        let state = StoredState(conversations: [conversation], selectedID: conversation.id)
        let restored = try JSONDecoder().decode(StoredState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.conversations, state.conversations)
        XCTAssertEqual(restored.selectedID, state.selectedID)
        let settings = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(AppSettings()))
        XCTAssertEqual(settings.models.count, 2)
        XCTAssertFalse(settings.temperatureEnabled)
    }
}

private actor TextCollector {
    var values: [String] = []
    func append(_ value: String) { values.append(value) }
    func result() -> String { values.joined() }
}

extension APITests {
    private func byteStream(_ text: String) -> AsyncStream<UInt8> {
        AsyncStream { continuation in
            for byte in text.utf8 { continuation.yield(byte) }
            continuation.finish()
        }
    }
    func testStreamingBytesPreserveUnicodeAndStopAtDone() async throws {
        let text = ":ping\r\n\r\ndata: {\"choices\":[{\"delta\":{\"content\":\"你好🌍\"}}]}\r\n\r\ndata: [DONE]\r\n\r\ndata: invalid\n\n"
        let collector = TextCollector()
        try await OpenAIClient.consumeSSE(byteStream(text)) { await collector.append($0) }
        let result = await collector.result()
        XCTAssertEqual(result, "你好🌍")
    }
    func testStreamingFlushesUnterminatedFinalEvent() async throws {
        let collector = TextCollector()
        try await OpenAIClient.consumeSSE(byteStream(#"data: {"choices":[{"delta":{"content":"last"}}]}"#)) { await collector.append($0) }
        let result = await collector.result()
        XCTAssertEqual(result, "last")
    }
    func testEmptyStreamFailsInsteadOfShowingSuccess() async {
        do {
            try await OpenAIClient.consumeSSE(byteStream("data: [DONE]\n\n")) { _ in }
            XCTFail("Expected empty-response error")
        } catch { XCTAssertTrue(error is APIError) }
    }
    func testStreamingCancellationStopsConsumption() async {
        let task = Task {
            try await OpenAIClient.consumeSSE(AsyncStream<UInt8> { continuation in
                for byte in "data: {}\n\n".utf8 { continuation.yield(byte) }
                continuation.finish()
            }) { _ in }
        }
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
