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
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    toolbar
                    if store.messages.isEmpty { emptyState }
                    else { transcript }
                    if let error = store.errorMessage, store.errorConversationID == nil || store.errorConversationID == store.selectedID {
                        errorBanner(error)
                    }
                    if store.isStreaming && !store.selectedIsStreaming {
                        HStack { Text("另一个对话正在生成").font(.footnote).foregroundStyle(.secondary); Spacer(); Button("停止") { store.stop() }.font(.footnote).tint(.primary) }.padding(.horizontal, 22).padding(.vertical, 8)
                    }
                    ComposerView(focused: $composerFocused, speech: speech)
                }
                .background(Palette.background)
                .offset(x: store.sidebarOpen ? min(geometry.size.width * 0.83, 340) * 0.18 : 0)
                .disabled(store.sidebarOpen)
                .accessibilityHidden(store.sidebarOpen)
                if store.sidebarOpen {
                    Color.black.opacity(0.28).ignoresSafeArea()
                        .onTapGesture { closeSidebar() }
                        .accessibilityLabel("关闭历史记录").accessibilityAddTraits(.isButton)
                    SidebarView(close: closeSidebar)
                        .frame(width: min(geometry.size.width * 0.83, 340))
                        .transition(.move(edge: .leading))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: store.sidebarOpen)
            .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                if value.startLocation.x < 24 && value.translation.width > 80 { composerFocused = false; store.sidebarOpen = true }
                else if store.sidebarOpen && value.translation.width < -60 { closeSidebar() }
            })
        }
        .sheet(isPresented: $store.settingsOpen) { SettingsView().environmentObject(store) }
        .sheet(isPresented: $store.modelPickerOpen) {
            ModelPickerView().environmentObject(store).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $store.voiceOpen) { VoiceView().environmentObject(store) }
        .sheet(item: $editing) { message in
            EditMessageSheet(text: message.text) { store.editAndResend(messageID: message.id, text: $0) }
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            ShareSheet(items: [shareText ?? ""])
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stopListening(); speech.stopSpeaking() } }
        .onChange(of: store.selectedID) { _, _ in followBottom = true }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            IconButton(symbol: "line.3.horizontal", label: "打开历史记录") { composerFocused = false; store.sidebarOpen = true; store.haptic() }
            Spacer(minLength: 0)
            Button { composerFocused = false; store.modelPickerOpen = true } label: {
                HStack(spacing: 6) {
                    VStack(spacing: 1) {
                        Text("ChatNative").font(.system(size: 17, weight: .semibold))
                        Text(store.modelName).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }.foregroundStyle(.primary).padding(.horizontal, 8)
            }.buttonStyle(.plain).accessibilityLabel("选择模型，当前 \(store.modelName)")
            Spacer(minLength: 0)
            IconButton(symbol: "square.and.pencil", label: "新对话") { store.newChat(); composerFocused = false }
        }.padding(.horizontal, 10).padding(.bottom, 5).background(Palette.background)
    }
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            BrandMark(size: 48).padding(.bottom, 25)
            Text("有什么可以帮你？").font(.system(size: 27, weight: .semibold)).tracking(-0.7)
            Spacer()
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    suggestion("lightbulb", "一起想点子", "帮我构思几个有创意的周末活动")
                    suggestion("doc.text", "帮我写作", "帮我写一封简洁得体的工作邮件，先问我收件人和内容")
                }
                HStack(spacing: 10) {
                    suggestion("graduationcap", "学习新知识", "用简单的例子讲解一个有趣的科学知识")
                    suggestion("terminal", "编写代码", "帮我梳理一个 SwiftUI 项目的结构")
                }
            }.padding(.horizontal, 24).padding(.bottom, 22)
        }.frame(maxWidth: .infinity)
    }
    private func suggestion(_ icon: String, _ title: String, _ prompt: String) -> some View {
        Button { store.draft = prompt; composerFocused = true; store.haptic() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }.padding(.horizontal, 13).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).stroke(Palette.tertiary, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(store.messages) { message in
                        MessageView(message: message, streaming: store.selectedIsStreaming && message.id == store.messages.last?.id,
                                    onEdit: { editing = message }, onShare: { shareText = message.text }, onSpeak: { speech.speak(message.text, language: store.settings.speechLanguage) })
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(DragGesture().onChanged { value in if value.translation.height > 15 { followBottom = false } })
            .overlay(alignment: .bottomTrailing) {
                if !followBottom {
                    Button { followBottom = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } label: {
                        Image(systemName: "arrow.down").font(.system(size: 14, weight: .semibold)).padding(13)
                            .background(Palette.background, in: Circle()).overlay(Circle().stroke(Palette.tertiary))
                    }.tint(.primary).padding(18).accessibilityLabel("回到最新消息")
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
        }.padding(14).background(Palette.secondary, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 18).padding(.bottom, 8)
    }
    private func closeSidebar() { store.sidebarOpen = false }
}
