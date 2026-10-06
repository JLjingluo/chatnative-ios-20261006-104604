import SwiftUI
import PhotosUI
import UIKit

struct ComposerView: View {
    @EnvironmentObject private var store: ChatStore
    var focused: FocusState<Bool>.Binding
    @ObservedObject var speech: SpeechController
    @State private var photos: [PhotosPickerItem] = []
    @State private var loadingPhotos = false
    @State private var attachmentSheet = false
    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: 7) {
            if let error = speech.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 20) }
            GlassGroup(spacing: 8) {
                HStack(alignment: .bottom, spacing: 9) {
                    GlassIconButton(symbol: "plus", label: "添加附件与更多选项", diameter: 48) { focused.wrappedValue = false; attachmentSheet = true; store.haptic() }
                        .disabled(loadingPhotos || store.isStreaming).padding(.bottom, 3)
                    VStack(alignment: .leading, spacing: 0) {
                        if !store.attachments.isEmpty || loadingPhotos { attachments.padding(.top, 10).padding(.horizontal, 12) }
                        HStack(alignment: .bottom, spacing: 3) {
                            TextField(speech.isListening ? "正在聆听…" : "询问任何问题", text: $store.draft, axis: .vertical)
                                .font(.body).lineLimit(1...7).focused(focused).padding(.leading, 16).padding(.vertical, 17).accessibilityLabel("消息输入框")
                            Button {
                                if speech.isListening { speech.stopListening() }
                                else {
                                    let initial = store.draft
                                    speech.startListening(language: store.settings.speechLanguage) { store.draft = initial.isEmpty ? $0 : initial + " " + $0 }
                                }
                            } label: {
                                Image(systemName: speech.isListening ? "mic.fill" : "mic").font(.system(size: 19)).foregroundStyle(speech.isListening ? .red : .primary).frame(width: 36, height: 44)
                            }.accessibilityLabel(speech.isListening ? "结束听写" : "开始语音听写").disabled(store.isStreaming).padding(.bottom, 5)
                            primaryAction.padding(.trailing, 7).padding(.bottom, 7)
                        }
                    }.nativeGlass(radius: 28).glassMorph("composer", in: glassNamespace)
                }
            }.padding(.horizontal, 14)
            if !focused.wrappedValue { Text("AI 的回答可能有误，请核实重要信息。") .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.bottom, 2) }
        }
        .animation(.easeInOut(duration: 0.2), value: store.draft.isEmpty)
        .sheet(isPresented: $attachmentSheet) {
            VStack(spacing: 0) {
                SheetHeader(title: "添加到对话") { attachmentSheet = false }
                HStack(spacing: 12) {
                    PhotosPicker(selection: $photos, maxSelectionCount: max(1, 4 - store.attachments.count), matching: .images) {
                        VStack(spacing: 10) { Image(systemName: "photo.on.rectangle.angled").font(.system(size: 26)); Text("照片").font(.system(size: 14, weight: .medium)) }.frame(maxWidth: .infinity).padding(.vertical, 22).nativeGlass(radius: 22, interactive: true)
                    }.tint(.primary).disabled(store.attachments.count >= 4)
                    Button { store.draft += UIPasteboard.general.string ?? ""; attachmentSheet = false; focused.wrappedValue = true } label: {
                        VStack(spacing: 10) { Image(systemName: "doc.on.clipboard").font(.system(size: 26)); Text("粘贴文字").font(.system(size: 14, weight: .medium)) }.frame(maxWidth: .infinity).padding(.vertical, 22).nativeGlass(radius: 22, interactive: true)
                    }.tint(.primary)
                }.padding(.horizontal, 20)
                Button { attachmentSheet = false; Task { @MainActor in try? await Task.sleep(for: .milliseconds(350)); store.modelPickerOpen = true } } label: {
                    Label("选择模型", systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .leading).padding(18)
                }.tint(.primary).padding(.horizontal, 10).padding(.top, 10)
                Button { attachmentSheet = false; Task { @MainActor in try? await Task.sleep(for: .milliseconds(350)); store.voiceOpen = true } } label: {
                    Label("语音对话", systemImage: "waveform").frame(maxWidth: .infinity, alignment: .leading).padding(18)
                }.tint(.primary).padding(.horizontal, 10)
                Spacer(minLength: 0)
            }.presentationDetents([.height(355)]).presentationDragIndicator(.visible)
        }
        .onChange(of: photos) { _, selection in
            guard !selection.isEmpty else { return }
            attachmentSheet = false
            let conversationID = store.selectedID
            Task { @MainActor in
                loadingPhotos = true
                defer { loadingPhotos = false; photos = [] }
                for item in selection {
                    guard store.attachments.count < 4 else { break }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw APIError.server("无法读取这张图片。") }
                        let scale = min(1, 1600 / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw APIError.server("图片转换失败。") }
                        guard store.selectedID == conversationID else { return }
                        store.attachments.append(Attachment(data: jpeg))
                    } catch { store.errorMessage = error.localizedDescription; store.errorConversationID = store.selectedID }
                }
            }
        }
        .onAppear {
            #if DEBUG
            if UIPreviewFixture.requestedMode == "keyboard" { focused.wrappedValue = true }
            #endif
        }
        .onDisappear { speech.stopListening() }
    }
    private var attachments: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.attachments) { attachment in
                    if let image = UIImage(data: attachment.data) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topTrailing) {
                                Button { store.attachments.removeAll { $0.id == attachment.id } } label: {
                                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .black).font(.system(size: 20))
                                }.offset(x: 4, y: -4).accessibilityLabel("移除图片")
                            }
                    }
                }
                if loadingPhotos { ProgressView().frame(width: 64, height: 64) }
            }.padding(.top, 4)
        }
    }
    @ViewBuilder private var primaryAction: some View {
        if store.selectedIsStreaming {
            GlassIconButton(symbol: "stop.fill", label: "停止生成", diameter: 40, prominent: true) { store.stop() }.glassMorph("primary-action", in: glassNamespace)
        } else if !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.attachments.isEmpty {
            GlassIconButton(symbol: "arrow.up", label: "发送消息", diameter: 40, prominent: true) { speech.stopListening(); store.send(); focused.wrappedValue = false }
                .disabled(!store.canSend || loadingPhotos).opacity(store.canSend ? 1 : 0.4).glassMorph("primary-action", in: glassNamespace)
        } else {
            GlassIconButton(symbol: "waveform", label: "打开语音对话", diameter: 40, prominent: true) { speech.stopListening(); focused.wrappedValue = false; store.voiceOpen = true }
                .disabled(store.isStreaming).glassMorph("primary-action", in: glassNamespace)
        }
    }
}
