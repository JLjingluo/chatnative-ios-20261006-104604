#if DEBUG
import Foundation

/// Debug-only, isolated fixtures for real simulator screenshots; never ship in Release.
enum UIPreviewFixture {
    static var requestedMode: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--ui-preview"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}

extension ChatStore {
    func configurePreview(mode: String) {
        settings = AppSettings()
        settings.appearance = mode == "dark" ? "dark" : "light"
        let conversation = Conversation(title: "周末的城市漫步", messages: [
            Message(role: .user, text: "帮我安排一个轻松的周末，想喝咖啡，也想逛逛公园。"),
            Message(role: .assistant, text: "当然。把周末留给自己，安排得松一点就好。\n\n## 上午 · 慢慢开始\n\n找一家安静的咖啡馆，点一杯喜欢的咖啡。带上书，或者只是看看窗外，不需要赶时间。\n\n## 下午 · 去公园走走\n\n- 选一条树荫多的步道，散步 30–45 分钟。\n- 路过喜欢的地方，就停下来拍张照。\n- 如果累了，在长椅上坐一会儿。\n\n**小建议：** 少安排一个目的地，会多一点发现的空间。")
        ], model: "gpt-4o-mini")
        var code = Conversation(title: "SwiftUI 入门笔记", messages: [
            Message(role: .user, text: "给我一个 SwiftUI 按钮的小例子。"),
            Message(role: .assistant, text: "可以，下面这个按钮使用原生 Liquid Glass：\n\n```swift\nButton(\"开始\") {\n    print(\"Hello, SwiftUI\")\n}\n.buttonStyle(.glass)\n```\n\n这是 iOS 26+ 的系统效果，会响应背景和触摸。")
        ], model: "gpt-4o")
        code.updatedAt = Date().addingTimeInterval(-3600)
        let yesterday = Conversation(title: "让邮件表达更自然", updatedAt: Date().addingTimeInterval(-86400), model: "gpt-4o-mini")
        conversations = [conversation, code, yesterday]
        selectedID = ["chat", "dark", "sidebar", "voice"].contains(mode) ? conversation.id : mode == "code" ? code.id : nil
        sidebarOpen = mode == "sidebar"
        settingsOpen = mode == "settings"
        modelPickerOpen = mode == "models"
        voiceOpen = mode == "voice"
        if mode == "keyboard" { draft = "帮我把这个想法写成一段文字" }
    }
}
#endif
