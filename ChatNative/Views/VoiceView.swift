import SwiftUI

struct VoiceView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechController()
    @State private var spokenText = ""
    @State private var waitingForReply = false
    @State private var sentConversationID: UUID?
    @State private var showTranscript = false
    @State private var showInfo = false
    @Namespace private var glassNamespace
    @Environment(\.scenePhase) private var scenePhase
    private var status: String {
        if speech.isListening { return "正在聆听" }
        if waitingForReply && store.isStreaming { return "正在思考" }
        if speech.isSpeaking { return "正在回答" }
        return "点击开始说话"
    }
    var body: some View {
        VStack(spacing: 0) {
            GlassGroup(spacing: 16) {
                HStack {
                    GlassIconButton(symbol: "chevron.down", label: "返回聊天") { dismiss() }
                    Spacer()
                    Text("语音对话").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    GlassIconButton(symbol: "ellipsis", label: "语音说明") { showInfo = true }
                }
            }.padding(.horizontal, 20).padding(.top, 8)
            Spacer()
            VoiceOrb(power: speech.level, active: speech.isListening || speech.isSpeaking, thinking: waitingForReply && store.isStreaming)
                .frame(width: 250, height: 250).accessibilityLabel(status)
            Spacer().frame(height: 38)
            Text(status).font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary)
            if !spokenText.isEmpty {
                ScrollView { Text(spokenText).font(.body).multilineTextAlignment(.center).padding(.horizontal, 34).padding(.top, 16) }.frame(maxHeight: 100)
            }
            if let error = speech.error ?? store.errorMessage { Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30).padding(.top, 12) }
            Spacer()
            GlassGroup(spacing: 20) {
                HStack(spacing: 22) {
                    GlassIconButton(symbol: "text.bubble", label: "查看对话文字", diameter: 52) { showTranscript = true }
                    GlassIconButton(symbol: speech.isSpeaking ? "speaker.slash" : speech.isListening ? "mic.slash.fill" : "mic.fill", label: speech.isSpeaking ? "停止朗读" : speech.isListening ? "结束聆听" : "开始聆听", diameter: 64, prominent: true) {
                        if speech.isSpeaking { speech.stopSpeaking() }
                        else if speech.isListening { speech.stopListening() }
                        else { speech.startListening(language: store.settings.speechLanguage) { spokenText = $0 } }
                    }.disabled(store.isStreaming)
                    if store.selectedIsStreaming {
                        GlassIconButton(symbol: "stop.fill", label: "停止生成", diameter: 52) { store.stop(); waitingForReply = false }.glassMorph("voice-action", in: glassNamespace)
                    } else if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        GlassIconButton(symbol: "arrow.up", label: "发送语音文字", diameter: 52) { send() }.disabled(store.isStreaming).glassMorph("voice-action", in: glassNamespace)
                    } else {
                        GlassIconButton(symbol: "xmark", label: "结束语音对话", diameter: 52) { dismiss() }.glassMorph("voice-action", in: glassNamespace)
                    }
                }
            }.padding(.bottom, 24)
            Text(store.modelName).font(.caption).foregroundStyle(.tertiary).padding(.bottom, 12)
        }.background(Palette.background)
            .sheet(isPresented: $showTranscript) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(store.messages) { message in
                                VStack(alignment: .leading, spacing: 7) { Text(message.role == .user ? "你" : store.modelName).font(.caption.weight(.semibold)).foregroundStyle(.secondary); MarkdownView(source: message.text) }
                            }
                        }.padding(24)
                    }.navigationTitle("对话文字").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showTranscript = false }.tint(.primary) } }
                }.presentationDragIndicator(.visible)
            }
            .alert("语音模式", isPresented: $showInfo) { Button("好", role: .cancel) {} } message: {
                Text("此版本使用 iOS 听写与系统朗读。说话后点击发送；文字会发送到配置的 API。系统识别可能使用 Apple 服务器。此功能不是实时双向语音 API。")
            }
            .onChange(of: store.isStreaming) { _, streaming in
                if !streaming && waitingForReply {
                    waitingForReply = false
                    if store.settings.autoRead, store.selectedID == sentConversationID, let last = store.messages.last, last.role == .assistant, !last.interrupted { speech.speak(last.text, language: store.settings.speechLanguage) }
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stopListening(); speech.stopSpeaking() } }
            .onDisappear { speech.stopListening(); speech.stopSpeaking() }
    }
    private func send() {
        speech.stopListening(); speech.stopSpeaking()
        let oldDraft = store.draft; let oldAttachments = store.attachments
        store.draft = spokenText; store.attachments = []; store.send()
        waitingForReply = store.isStreaming; sentConversationID = store.selectedID
        store.draft = oldDraft; store.attachments = oldAttachments
        if waitingForReply { spokenText = "" }
    }
}

struct VoiceOrb: View {
    var power: Float
    var active: Bool
    var thinking: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let phase = t * (active ? 1.3 : thinking ? 0.9 : 0.35)
            let amplitude = active ? 0.035 + Double(power) * 0.12 : 0.018
            GeometryReader { geometry in
                let size = geometry.size.width
                ZStack {
                    Circle().fill(Color(red: 0.88, green: 0.96, blue: 1))
                    Ellipse().fill(Color(red: 0.08, green: 0.40, blue: 0.98))
                        .frame(width: size * 1.1, height: size * 0.70).blur(radius: 25)
                        .offset(x: sin(phase) * size * 0.16, y: size * 0.32 + cos(phase) * size * 0.08)
                    Ellipse().fill(Color(red: 0.18, green: 0.69, blue: 0.98))
                        .frame(width: size * 0.85, height: size * 0.8).blur(radius: 30)
                        .offset(x: size * 0.3 * cos(phase * 0.7), y: size * 0.22 * sin(phase * 0.8))
                    Ellipse().fill(.white).frame(width: size * 0.9, height: size * 0.5).blur(radius: 26)
                        .offset(x: size * 0.12 * sin(phase * 0.6), y: -size * 0.3)
                }.clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    .scaleEffect(1 + amplitude * sin(phase * 1.6))
            }
        }.accessibilityHidden(true)
    }
}
