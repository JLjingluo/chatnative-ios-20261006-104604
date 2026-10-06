import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var clearAlert = false
    @State private var exportedURL: URL?
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        BrandMark(size: 36).frame(width: 50, height: 50)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ChatNative").font(.title3.weight(.semibold))
                            Text("你的模型，你的对话").font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("连接") {
                    NavigationLink { APISettingsView() } label: { Label("API 与模型", systemImage: "network") }
                    HStack { Label("当前模型", systemImage: "sparkles"); Spacer(); Text(store.modelName).foregroundStyle(.secondary).lineLimit(1) }
                }
                Section("偏好") {
                    Picker(selection: $store.settings.appearance) {
                        Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark")
                    } label: { Label("外观", systemImage: "circle.lefthalf.filled") }
                    Toggle(isOn: $store.settings.haptics) { Label("触感反馈", systemImage: "hand.tap") }.tint(.primary)
                    NavigationLink { ConversationSettingsView() } label: { Label("对话与上下文", systemImage: "text.bubble") }
                    Picker(selection: $store.settings.speechLanguage) {
                        Text("中文").tag("zh-CN"); Text("English").tag("en-US"); Text("日本語").tag("ja-JP")
                    } label: { Label("语音语言", systemImage: "waveform") }
                    Toggle(isOn: $store.settings.autoRead) { Label("语音模式自动朗读", systemImage: "speaker.wave.2") }.tint(.primary)
                }
                Section {
                    Button {
                        do { exportedURL = try store.exportHistory() } catch { localError = error.localizedDescription }
                    } label: { Label("导出聊天记录", systemImage: "square.and.arrow.up").foregroundStyle(.primary) }
                    Button(role: .destructive) { clearAlert = true } label: { Label("清除全部对话", systemImage: "trash") }
                } header: { Text("数据") } footer: { Text("聊天和图片保存在本机，令牌保存在 Keychain。发送消息时，上下文与图片会传给你配置的 API 服务；导出文件也包含图片，请妥善保管。") }
                Section {
                    LabeledContent("版本", value: "1.0.0")
                    Text("独立开发的 OpenAI 兼容客户端，与 OpenAI 官方 ChatGPT App 无隶属关系。").font(.footnote).foregroundStyle(.secondary)
                } header: { Text("关于") }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { if store.saveSettings() { dismiss() } else { localError = store.errorMessage } }.tint(.primary).fontWeight(.semibold) } }
                .alert("清除全部对话？", isPresented: $clearAlert) {
                    Button("取消", role: .cancel) {}
                    Button("清除", role: .destructive) { store.clearHistory() }
                } message: { Text("这会删除本机所有聊天记录和图片，无法恢复。API 配置会保留。") }
                .alert("操作失败", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("好", role: .cancel) {} } message: { Text(localError ?? "") }
                .sheet(isPresented: Binding(get: { exportedURL != nil }, set: { if !$0 { if let url = exportedURL { try? FileManager.default.removeItem(at: url) }; exportedURL = nil } })) {
                    if let url = exportedURL { ShareSheet(items: [url]) }
                }
        }.onDisappear { store.saveSettings() }
    }
}

struct APISettingsView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var revealKey = false
    @State private var loading = false
    @State private var status: String?
    @State private var fetched: [String] = []
    @State private var addingModel = false
    @State private var editingModel: ModelOption?
    @State private var fetchTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                TextField("https://api.example.com/v1", text: $store.settings.baseURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).font(.system(size: 14, design: .monospaced))
                HStack {
                    Group {
                        if revealKey { TextField("API Key / 用户令牌", text: $store.apiKey) }
                        else { SecureField("API Key / 用户令牌", text: $store.apiKey) }
                    }.textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size: 14, design: .monospaced))
                    Button { revealKey.toggle() } label: { Image(systemName: revealKey ? "eye.slash" : "eye") }.tint(.secondary).accessibilityLabel(revealKey ? "隐藏令牌" : "显示令牌")
                }
                Button {
                    guard store.saveSettings() else { status = store.errorMessage; return }
                    loading = true
                    status = nil
                    let snapshot = store.settings
                    let key = store.apiKey
                    fetchTask = Task { @MainActor in
                        defer { loading = false }
                        do {
                            fetched = try await OpenAIClient().fetchModels(settings: snapshot, key: key)
                            status = "已连接，发现 \(fetched.count) 个模型。此检查验证 /models；聊天能力请发送消息测试。"
                        } catch { if !Task.isCancelled { status = error.localizedDescription } }
                    }
                } label: {
                    HStack { Text("测试连接并获取模型"); Spacer(); if loading { ProgressView() } else { Image(systemName: "arrow.clockwise") } }
                }.disabled(loading).tint(.primary)
                if let status { Text(status).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled) }
            } header: { Text("OpenAI 兼容接口") } footer: { Text("填写服务商提供的 API 根地址，通常以 /v1 结尾。支持 LiteLLM、New API 等网关。部分接口不开放 /models，仍可手动添加模型。公网地址须使用 HTTPS。") }
            Section {
                ForEach(store.settings.models) { model in
                    Button { editingModel = model } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name).foregroundStyle(.primary)
                                Text(model.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.supportsImages { Image(systemName: "photo").foregroundStyle(.secondary) }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }.swipeActions { Button("删除", role: .destructive) { remove(model) }.disabled(store.settings.models.count < 2 || store.isStreaming) }
                }
                Button { addingModel = true } label: { Label("手动添加模型", systemImage: "plus") }.tint(.primary).disabled(store.isStreaming)
            } header: { Text("可用模型") } footer: { Text("模型 ID 必须与上游一致。图片能力需要手动确认，开启选项不会让文字模型获得图片能力。") }
            if !fetched.isEmpty {
                Section("服务端模型 · 点击添加") {
                    ForEach(fetched, id: \.self) { id in
                        Button {
                            guard !store.settings.models.contains(where: { $0.id == id }) else { return }
                            store.settings.models.append(ModelOption(id: id, name: id))
                            store.saveSettings()
                        } label: {
                            HStack { Text(id).font(.system(size: 13, design: .monospaced)); Spacer(); Image(systemName: store.settings.models.contains(where: { $0.id == id }) ? "checkmark" : "plus") }
                        }.tint(.primary).disabled(store.settings.models.contains(where: { $0.id == id }) || store.isStreaming)
                    }
                }
            }
        }.navigationTitle("API 与模型").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $addingModel) { ModelEditorView(original: nil).environmentObject(store) }
            .sheet(item: $editingModel) { model in ModelEditorView(original: model).environmentObject(store) }
            .onDisappear { fetchTask?.cancel(); store.saveSettings() }
    }
    private func remove(_ model: ModelOption) {
        store.settings.models.removeAll { $0.id == model.id }
        if store.settings.selectedModel == model.id, let first = store.settings.models.first { store.settings.selectedModel = first.id }
        store.saveSettings()
    }
}

struct ModelEditorView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let original: ModelOption?
    @State private var id = ""
    @State private var name = ""
    @State private var detail = ""
    @State private var images = false
    @State private var validation: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("模型") {
                    TextField("模型 ID，例如 gpt-4o-mini", text: $id).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(original != nil)
                    TextField("显示名称", text: $name)
                    TextField("简短说明", text: $detail)
                    Toggle("支持图片输入", isOn: $images).tint(.primary)
                }
                if let validation { Text(validation).font(.footnote).foregroundStyle(.red) }
                Section { Text("请核对服务商文档。这里只声明能力，实际支持情况由服务端决定。").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle(original == nil ? "添加模型" : "编辑模型").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(.primary) }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.fontWeight(.semibold).tint(.primary).disabled(store.isStreaming) }
                }
        }.onAppear { if let original { id = original.id; name = original.name; detail = original.detail; images = original.supportsImages } }
    }
    private func save() {
        let modelID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else { validation = "模型 ID 不能为空。"; return }
        let item = ModelOption(id: modelID, name: name.isEmpty ? modelID : name, detail: detail.isEmpty ? "OpenAI 兼容模型" : detail, supportsImages: images)
        if let index = store.settings.models.firstIndex(where: { $0.id == modelID }) {
            guard original != nil else { validation = "这个模型已经添加。"; return }
            store.settings.models[index] = item
        } else { store.settings.models.append(item) }
        store.saveSettings()
        dismiss()
    }
}

struct ConversationSettingsView: View {
    @EnvironmentObject private var store: ChatStore
    var body: some View {
        Form {
            Section { TextEditor(text: $store.settings.systemPrompt).frame(minHeight: 140) } header: { Text("系统提示词") } footer: { Text("会以 system 消息发送。有些模型限制系统提示词，请按上游要求调整。") }
            Section {
                Stepper("最近 \(store.settings.contextLimit) 条消息", value: $store.settings.contextLimit, in: 2...100, step: 2)
            } header: { Text("上下文") } footer: { Text("每次请求发送最近的消息，从用户消息开始。未完成的助手回复不会进入上下文；历史记录仍全部保留。更长上下文会增加用量，这不是按 token 精确截断。") }
            Section {
                Toggle("发送 temperature 参数", isOn: $store.settings.temperatureEnabled).tint(.primary)
                if store.settings.temperatureEnabled {
                    HStack { Text("随机性"); Spacer(); Text(store.settings.temperature, format: .number.precision(.fractionLength(1))).foregroundStyle(.secondary) }
                    Slider(value: $store.settings.temperature, in: 0...2, step: 0.1).tint(.primary)
                }
            } footer: { Text("默认不发送此参数，以兼容限制采样参数的模型。") }
        }.navigationTitle("对话与上下文").navigationBarTitleDisplayMode(.inline).onDisappear { store.saveSettings() }
    }
}
