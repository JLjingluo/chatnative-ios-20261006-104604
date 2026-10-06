import Foundation

struct Attachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var data: Data
    var mimeType = "image/jpeg"
    var dataURL: String { "data:\(mimeType);base64,\(data.base64EncodedString())" }
}

struct Message: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case system, user, assistant }
    var id = UUID()
    var role: Role
    var text: String
    var attachments: [Attachment] = []
    var createdAt = Date()
    var interrupted = false
}

struct Conversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = "新对话"
    var messages: [Message] = []
    var updatedAt = Date()
    var model: String
}

struct ModelOption: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var detail: String = "OpenAI 兼容模型"
    var supportsImages = false
}

struct AppSettings: Codable {
    var baseURL = "https://api.openai.com/v1"
    var selectedModel = "gpt-4o-mini"
    var models: [ModelOption] = [
        .init(id: "gpt-4o-mini", name: "GPT-4o mini", detail: "快速、轻量，适合日常交流", supportsImages: true),
        .init(id: "gpt-4o", name: "GPT-4o", detail: "支持文字与图片", supportsImages: true)
    ]
    var systemPrompt = "你是一位乐于助人、准确且清晰的助手。"
    var contextLimit = 40
    var appearance = "system"
    var haptics = true
    var speechLanguage = "zh-CN"
    var autoRead = true
    var temperatureEnabled = false
    var temperature = 0.7
}

struct StoredState: Codable {
    var conversations: [Conversation]
    var selectedID: UUID?
}
