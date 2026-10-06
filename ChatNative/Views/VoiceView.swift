import SwiftUI

struct VoiceView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechController()
    @State private var spokenText = ""
    @State private var waitingForReply = false
    @State private var sentConversationID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var status: String {
        if speech.isListening { return "正在聆听" }
        if waitingForReply && store.isStreaming { return "正在思考" }
        if speech.isSpeaking { return "正在回答" }
        return "准备好就开始说话"
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(symbol: "chevron.down", label: "返回聊天") { dismiss() }
                Spacer()
                VStack(spacing: 3) { Text(store.modelName).font(.system(size: 15, weight: .medium)); Text("语音对话").font(.system(size: 11)).foregroundStyle(.secondary) }
                Spacer()
                IconButton(symbol: "ellipsis", label: "语音说明") { speech.error = "使用 iOS 语音识别和系统朗读。识别服务可能使用 Apple 服务器；文字会发送至配置的 API。" }
            }.padding(.horizontal, 14).padding(.top, 5)
            Spacer()
            ZStack {
                Circle().fill(Color(red: 0.65, green: 0.83, blue: 1).opacity(0.14)).frame(width: 255, height: 255).blur(radius: 16)
                Circle().fill(
                    RadialGradient(colors: [.white, Color(red: 0.58, green: 0.82, blue: 1), Color(red: 0.22, green: 0.47, blue: 0.98)], center: .init(x: 0.3, y: 0.2), startRadius: 1, endRadius: 190)
                ).frame(width: 190, height: 190)
                    .overlay(Circle().fill(.white.opacity(0.16)).blur(radius: 18).offset(x: -35, y: -35))
                    .scaleEffect(speech.isListening ? 1 + CGFloat(speech.level) * 0.15 : speech.isSpeaking ? 1.05 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: speech.level)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: speech.isSpeaking)
            }.accessibilityLabel(status)
            Spacer().frame(height: 42)
            Text(status).font(.system(size: 19, weight: .medium))
            ScrollView {
                Text(spokenText.isEmpty ? "点击麦克风开始，完成后点击发送。" : spokenText).font(.system(size: 15)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 36).padding(.top, 14)
            }.frame(maxHeight: 120)
            if let error = speech.error ?? store.errorMessage { Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30).padding(.top, 12) }
            Spacer()
            HStack(spacing: 30) {
                Button {
                    if speech.isSpeaking { speech.stopSpeaking() }
                    else if speech.isListening { speech.stopListening() }
                    else { speech.startListening(language: store.settings.speechLanguage) { spokenText = $0 } }
                } label: {
                    Image(systemName: speech.isSpeaking ? "speaker.slash" : speech.isListening ? "mic.slash" : "mic.fill")
                        .font(.system(size: 24)).frame(width: 64, height: 64).background(Palette.secondary, in: Circle())
                }.tint(.primary).disabled(store.isStreaming).accessibilityLabel(speech.isSpeaking ? "停止朗读" : speech.isListening ? "结束聆听" : "开始聆听")
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 24, weight: .semibold)).foregroundStyle(Palette.background).frame(width: 64, height: 64).background(.primary, in: Circle())
                }.disabled(spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isStreaming).opacity(spokenText.isEmpty || store.isStreaming ? 0.3 : 1).accessibilityLabel("发送语音文字")
                Button { speech.stopListening(); speech.stopSpeaking(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 22, weight: .medium)).frame(width: 64, height: 64).background(Palette.secondary, in: Circle())
                }.tint(.primary).accessibilityLabel("结束语音对话")
            }.padding(.bottom, 28)
            Text("系统听写与朗读 · 非实时语音 API").font(.system(size: 11)).foregroundStyle(.tertiary).padding(.bottom, 16)
        }.background(Palette.background)
            .onChange(of: store.isStreaming) { _, streaming in
                if !streaming && waitingForReply {
                    waitingForReply = false
                    if store.settings.autoRead, store.selectedID == sentConversationID, let last = store.messages.last, last.role == .assistant, !last.interrupted {
                        speech.speak(last.text, language: store.settings.speechLanguage)
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stopListening(); speech.stopSpeaking() } }
            .onDisappear { speech.stopListening(); speech.stopSpeaking() }
    }
    private func send() {
        speech.stopListening()
        speech.stopSpeaking()
        // Preserve the chat composer's unfinished text and images.
        let oldDraft = store.draft
        let oldAttachments = store.attachments
        store.draft = spokenText
        store.attachments = []
        store.send()
        waitingForReply = store.isStreaming
        sentConversationID = store.selectedID
        store.draft = oldDraft
        store.attachments = oldAttachments
        if waitingForReply { spokenText = "" }
    }
}
