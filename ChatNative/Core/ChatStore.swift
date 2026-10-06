import SwiftUI
import UIKit

@MainActor
final class ChatStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedID: UUID?
    @Published var settings: AppSettings
    @Published var streamingID: UUID?
    @Published var errorMessage: String?
    @Published var errorConversationID: UUID?
    @Published var sidebarOpen = false
    @Published var settingsOpen = false
    @Published var modelPickerOpen = false
    @Published var voiceOpen = false
    @Published var draft = ""
    @Published var attachments: [Attachment] = []
    @Published var apiKey: String
    private var generation: Task<Void, Never>?
    private var generationToken: UUID?
    private var diskSave: Task<Void, Never>?
    private var storageWritable = true
    private let stateURL: URL
    private let client = OpenAIClient()

    var selectedConversation: Conversation? { conversations.first { $0.id == selectedID } }
    var messages: [Message] { selectedConversation?.messages ?? [] }
    var currentModel: String { selectedConversation?.model ?? settings.selectedModel }
    var modelName: String { settings.models.first { $0.id == currentModel }?.name ?? currentModel }
    var isStreaming: Bool { streamingID != nil }
    var selectedIsStreaming: Bool { streamingID != nil && streamingID == selectedID }
    var canSend: Bool { !isStreaming && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty) }

    init() {
        let saved = UserDefaults.standard.data(forKey: "app-settings")
        settings = saved.flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        apiKey = Keychain.read()
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ChatNative", isDirectory: true)
        stateURL = directory.appendingPathComponent("conversations.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stateURL.path) {
                let state = try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: stateURL))
                conversations = state.conversations
                selectedID = state.selectedID
                if !conversations.contains(where: { $0.id == selectedID }) { selectedID = nil }
            }
        } catch {
            let backup = directory.appendingPathComponent("conversations-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            if FileManager.default.fileExists(atPath: stateURL.path) {
                do {
                    try FileManager.default.copyItem(at: stateURL, to: backup)
                    errorMessage = "本地记录无法读取，原内容已备份至 \(backup.lastPathComponent)。"
                } catch { storageWritable = false; errorMessage = "无法读取和备份记录：\(error.localizedDescription)。已暂停写入以保留原文件。" }
            } else { errorMessage = "无法创建聊天存储：\(error.localizedDescription)" }
        }
    }

    @discardableResult
    func saveSettings() -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try Keychain.save(apiKey)
            UserDefaults.standard.set(data, forKey: "app-settings")
            return true
        } catch { errorMessage = error.localizedDescription; errorConversationID = nil; return false }
    }

    func persist() {
        guard storageWritable else { return }
        diskSave?.cancel()
        do {
            let data = try JSONEncoder().encode(StoredState(conversations: conversations, selectedID: selectedID))
            try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { errorMessage = "无法保存聊天记录：\(error.localizedDescription)" }
    }

    private func scheduleSave() {
        diskSave?.cancel()
        diskSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    func haptic() { if settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    func newChat() {
        if isStreaming { stop() }
        selectedID = nil
        draft = ""
        attachments = []
        errorMessage = nil
        sidebarOpen = false
        persist()
        haptic()
    }
    func select(_ conversation: Conversation) {
        selectedID = conversation.id
        draft = ""
        attachments = []
        errorMessage = nil
        sidebarOpen = false
        persist()
    }
    func chooseModel(_ model: ModelOption) {
        settings.selectedModel = model.id
        if let index = conversations.firstIndex(where: { $0.id == selectedID }) { conversations[index].model = model.id }
        saveSettings()
        persist()
        modelPickerOpen = false
        haptic()
    }
    func rename(_ id: UUID, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        conversations[index].title = String(title.prefix(100))
        persist()
    }
    func delete(_ id: UUID) {
        if streamingID == id { stop() }
        conversations.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil; draft = ""; attachments = [] }
        persist()
    }
    func clearHistory() {
        stop()
        conversations.removeAll()
        selectedID = nil
        draft = ""
        attachments = []
        persist()
    }
    func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let media = attachments
        // Validate before consuming the draft.
        do { _ = try OpenAIClient.request(settings: settings, key: apiKey, model: currentModel, messages: messages + [Message(role: .user, text: text, attachments: media)]) }
        catch { errorMessage = error.localizedDescription; errorConversationID = selectedID; return }
        if selectedID == nil {
            let conversation = Conversation(model: settings.selectedModel)
            conversations.insert(conversation, at: 0)
            selectedID = conversation.id
        }
        guard let id = selectedID, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messages.append(Message(role: .user, text: text, attachments: media))
        if conversations[index].messages.count == 1 { conversations[index].title = text.isEmpty ? "图片对话" : String(text.prefix(30)) }
        draft = ""
        attachments = []
        begin(id: id)
        haptic()
    }
    func retry() {
        guard !isStreaming, let id = selectedID, let index = conversations.firstIndex(where: { $0.id == id }),
              let lastUser = conversations[index].messages.lastIndex(where: { $0.role == .user }) else { return }
        conversations[index].messages = Array(conversations[index].messages.prefix(lastUser + 1))
        begin(id: id)
    }
    func editAndResend(messageID: UUID, text: String) {
        guard !isStreaming, let id = selectedID, let index = conversations.firstIndex(where: { $0.id == id }),
              let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == messageID }),
              conversations[index].messages[messageIndex].role == .user else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty || !conversations[index].messages[messageIndex].attachments.isEmpty else { return }
        conversations[index].messages[messageIndex].text = clean
        conversations[index].messages = Array(conversations[index].messages.prefix(messageIndex + 1))
        begin(id: id)
    }
    func fork(at messageID: UUID) {
        guard let source = selectedConversation, let index = source.messages.firstIndex(where: { $0.id == messageID }) else { return }
        var branch = source
        branch.id = UUID()
        branch.title = String(source.title.prefix(25)) + " · 分支"
        branch.messages = Array(source.messages.prefix(index + 1))
        branch.updatedAt = Date()
        conversations.insert(branch, at: 0)
        selectedID = branch.id
        draft = ""
        attachments = []
        persist()
    }
    func stop() {
        generation?.cancel()
        generation = nil
        generationToken = nil
        if let id = streamingID, let ci = conversations.firstIndex(where: { $0.id == id }), let mi = conversations[ci].messages.indices.last {
            if conversations[ci].messages[mi].role == .assistant { conversations[ci].messages[mi].interrupted = true }
        }
        streamingID = nil
        persist()
    }
    private func begin(id: UUID) {
        guard !isStreaming, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let history = conversations[index].messages
        let model = conversations[index].model
        let snapshot = settings
        let key = apiKey
        let reply = Message(role: .assistant, text: "", interrupted: true)
        conversations[index].messages.append(reply)
        conversations[index].updatedAt = Date()
        errorMessage = nil
        errorConversationID = nil
        streamingID = id
        let token = UUID()
        generationToken = token
        persist()
        generation = Task { [weak self] in
            guard let self else { return }
            do {
                try await client.stream(settings: snapshot, key: key, model: model, messages: history) { [weak self] text in
                    await self?.append(text, conversationID: id, messageID: reply.id, token: token)
                }
                guard generationToken == token else { return }
                if let ci = conversations.firstIndex(where: { $0.id == id }), let mi = conversations[ci].messages.firstIndex(where: { $0.id == reply.id }) {
                    conversations[ci].messages[mi].interrupted = false
                }
                streamingID = nil
                generation = nil
                generationToken = nil
                persist()
            } catch {
                guard generationToken == token else { return }
                if let ci = conversations.firstIndex(where: { $0.id == id }), let mi = conversations[ci].messages.firstIndex(where: { $0.id == reply.id }) {
                    conversations[ci].messages[mi].interrupted = true
                }
                if !(error is CancellationError) {
                    errorMessage = error.localizedDescription.replacingOccurrences(of: key, with: "[已隐藏]")
                    errorConversationID = id
                }
                streamingID = nil
                generation = nil
                generationToken = nil
                persist()
            }
        }
    }
    private func append(_ text: String, conversationID: UUID, messageID: UUID, token: UUID) {
        guard generationToken == token, let ci = conversations.firstIndex(where: { $0.id == conversationID }),
              let mi = conversations[ci].messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversations[ci].messages[mi].text += text
        scheduleSave()
    }

    func exportHistory() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChatNative-\(UUID().uuidString.prefix(8)).json")
        try encoder.encode(conversations).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}
