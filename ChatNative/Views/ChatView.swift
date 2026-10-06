import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: ChatStore
    @StateObject private var speech = SpeechController()
    @State private var editing: Message?
    @State private var shareText: String?
    @State private var followBottom = true
    @FocusState private var composerFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(geometry.size.width - 54, 360)
            ZStack(alignment: .leading) {
                mainContent
                    .offset(x: store.sidebarOpen ? sidebarWidth : 0)
                    .disabled(store.sidebarOpen).accessibilityHidden(store.sidebarOpen)
                if store.sidebarOpen {
                    Color.black.opacity(0.24).ignoresSafeArea().onTapGesture { closeSidebar() }
                        .accessibilityLabel("关闭历史记录").accessibilityAddTraits(.isButton)
                    SidebarView(close: closeSidebar).frame(width: sidebarWidth)
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 28, topTrailingRadius: 28))
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 10)
                        .transition(.move(edge: .leading))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: store.sidebarOpen)
            .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in
                if value.startLocation.x < 24 && value.translation.width > 70 { composerFocused = false; store.sidebarOpen = true }
                else if store.sidebarOpen && value.translation.width < -60 { closeSidebar() }
            })
        }
        .background(Palette.background)
        .sheet(isPresented: $store.settingsOpen) { SettingsView().environmentObject(store) }
        .sheet(isPresented: $store.modelPickerOpen) {
            ModelPickerView().environmentObject(store).presentationDetents([.height(430), .large]).presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $store.voiceOpen) { VoiceView().environmentObject(store) }
        .sheet(item: $editing) { message in EditMessageSheet(text: message.text) { store.editAndResend(messageID: message.id, text: $0) } }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) { ShareSheet(items: [shareText ?? ""]) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stopListening(); speech.stopSpeaking() } }
        .onChange(of: store.selectedID) { _, _ in followBottom = true }
    }

    private var mainContent: some View {
        Group { if store.messages.isEmpty { emptyState } else { transcript } }
            .safeAreaInset(edge: .top, spacing: 0) { toolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    if let error = store.errorMessage, store.errorConversationID == nil || store.errorConversationID == store.selectedID { errorBanner(error) }
                    if store.isStreaming && !store.selectedIsStreaming {
                        HStack { Text("另一个对话正在生成").font(.footnote).foregroundStyle(.secondary); Spacer(); Button("停止") { store.stop() }.font(.footnote).tint(.primary) }.padding(.horizontal, 22)
                    }
                    ComposerView(focused: $composerFocused, speech: speech)
                }.padding(.top, 6)
            }
            .background(Palette.background)
    }
    private var toolbar: some View {
        GlassGroup(spacing: 14) {
            HStack(spacing: 12) {
                GlassIconButton(symbol: "line.3.horizontal", label: "打开历史记录") { composerFocused = false; store.sidebarOpen = true; store.haptic() }
                Button { composerFocused = false; store.modelPickerOpen = true } label: {
                    HStack(spacing: 6) {
                        Text("ChatGPT").font(.system(size: 17, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }.foregroundStyle(.primary).padding(.horizontal, 17).frame(height: 44).nativeGlass(radius: 22, interactive: true)
                }.buttonStyle(.plain).accessibilityLabel("选择模型，当前 \(store.modelName)")
                Spacer(minLength: 0)
                GlassIconButton(symbol: "square.and.pencil", label: "新对话") { store.newChat(); composerFocused = false }
            }
        }.padding(.horizontal, 18).padding(.top, 7).padding(.bottom, 10)
    }
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("我能帮你做什么？").font(.system(size: 29, weight: .semibold)).tracking(-0.8).multilineTextAlignment(.center)
            Spacer().frame(height: 26)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    suggestion("pencil.line", "帮我写作", "帮我写一封简洁得体的工作邮件，先问我收件人和内容", .orange)
                    suggestion("lightbulb", "一起想点子", "帮我构思几个有创意的周末活动", .yellow)
                }
                HStack(spacing: 10) {
                    suggestion("graduationcap", "学习新知识", "用简单的例子讲解一个有趣的科学知识", .blue)
                    suggestion("chevron.left.forwardslash.chevron.right", "编写代码", "帮我梳理一个 SwiftUI 项目的结构", .green)
                }
            }
            Spacer()
            Text(store.modelName).font(.caption).foregroundStyle(.tertiary).padding(.bottom, 18)
        }.frame(maxWidth: .infinity).padding(.horizontal, 18)
    }
    private func suggestion(_ icon: String, _ title: String, _ prompt: String, _ color: Color) -> some View {
        Button { store.draft = prompt; composerFocused = true; store.haptic() } label: {
            HStack(spacing: 7) { Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(color); Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary) }
                .padding(.horizontal, 15).padding(.vertical, 12).background(Capsule().stroke(.primary.opacity(0.10), lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(store.messages) { message in
                        MessageView(message: message, streaming: store.selectedIsStreaming && message.id == store.messages.last?.id,
                                    onEdit: { editing = message }, onShare: { shareText = message.text }, onSpeak: { speech.speak(message.text, language: store.settings.speechLanguage) }).id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(DragGesture().onChanged { value in if value.translation.height > 15 { followBottom = false } })
            .overlay(alignment: .bottomTrailing) {
                if !followBottom {
                    GlassIconButton(symbol: "arrow.down", label: "回到最新消息", diameter: 40) {
                        followBottom = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }.padding(18)
                }
            }
            .onChange(of: store.messages.last?.text) { _, _ in if followBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: store.messages.count) { _, _ in if followBottom { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
            .onChange(of: composerFocused) { _, focused in if focused && followBottom { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
    private func errorBanner(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 7) {
                Text(error).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                HStack(spacing: 18) {
                    Button("接口设置") { store.settingsOpen = true }
                    if !store.messages.isEmpty { Button("重试") { store.retry() }.disabled(store.isStreaming) }
                }.font(.footnote.weight(.medium)).tint(.primary)
            }
            Spacer(minLength: 0)
            Button { store.errorMessage = nil } label: { Image(systemName: "xmark").font(.footnote) }.tint(.secondary).accessibilityLabel("关闭错误提示")
        }.padding(14).background(Palette.secondary, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 18)
    }
    private func closeSidebar() { store.sidebarOpen = false }
}
