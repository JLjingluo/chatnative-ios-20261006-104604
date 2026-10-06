import SwiftUI
import PhotosUI
import UIKit

struct ComposerView: View {
    @EnvironmentObject private var store: ChatStore
    var focused: FocusState<Bool>.Binding
    @ObservedObject var speech: SpeechController
    @State private var photos: [PhotosPickerItem] = []
    @State private var loadingPhotos = false

    var body: some View {
        VStack(spacing: 8) {
            if let error = speech.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 20) }
            VStack(alignment: .leading, spacing: 8) {
                if !store.attachments.isEmpty || loadingPhotos {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.attachments) { attachment in
                                if let image = UIImage(data: attachment.data) {
                                    Image(uiImage: image).resizable().scaledToFill().frame(width: 66, height: 66).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(alignment: .topTrailing) {
                                            Button { store.attachments.removeAll { $0.id == attachment.id } } label: {
                                                Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .black).font(.system(size: 19))
                                            }.offset(x: 4, y: -4).accessibilityLabel("移除图片")
                                        }
                                }
                            }
                            if loadingPhotos { ProgressView().frame(width: 66, height: 66) }
                        }.padding(.top, 5)
                    }
                }
                TextField(speech.isListening ? "正在聆听…" : "发送消息", text: $store.draft, axis: .vertical)
                    .font(.system(size: 17)).lineLimit(1...7).focused(focused)
                    .padding(.top, 5).padding(.horizontal, 3).accessibilityLabel("消息输入框")
                HStack(spacing: 5) {
                    PhotosPicker(selection: $photos, maxSelectionCount: 4, matching: .images) {
                        Image(systemName: "plus").font(.system(size: 21)).foregroundStyle(.primary).frame(width: 36, height: 36)
                    }.accessibilityLabel("添加图片").disabled(loadingPhotos || store.isStreaming)
                    Spacer()
                    Button {
                        if speech.isListening { speech.stopListening() }
                        else {
                            let initial = store.draft
                            speech.startListening(language: store.settings.speechLanguage) { text in store.draft = initial.isEmpty ? text : initial + " " + text }
                        }
                    } label: {
                        Image(systemName: speech.isListening ? "mic.fill" : "mic").font(.system(size: 20)).foregroundStyle(speech.isListening ? .red : .primary).frame(width: 36, height: 36)
                    }.accessibilityLabel(speech.isListening ? "结束听写" : "开始语音听写").disabled(store.isStreaming)
                    if store.selectedIsStreaming {
                        Button { store.stop() } label: {
                            Image(systemName: "stop.fill").font(.system(size: 13)).foregroundStyle(Palette.background).frame(width: 35, height: 35).background(.primary, in: Circle())
                        }.accessibilityLabel("停止生成")
                    } else if !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.attachments.isEmpty {
                        Button { speech.stopListening(); store.send(); focused.wrappedValue = false } label: {
                            Image(systemName: "arrow.up").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.background).frame(width: 35, height: 35).background(.primary, in: Circle())
                        }.disabled(!store.canSend || loadingPhotos).opacity(store.canSend ? 1 : 0.4).accessibilityLabel("发送消息")
                    } else {
                        Button { speech.stopListening(); focused.wrappedValue = false; store.voiceOpen = true } label: {
                            Image(systemName: "waveform").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.background).frame(width: 35, height: 35).background(.primary, in: Circle())
                        }.accessibilityLabel("打开语音对话").disabled(store.isStreaming)
                    }
                }
            }.padding(.horizontal, 13).padding(.top, 9).padding(.bottom, 10)
                .background(Palette.secondary, in: RoundedRectangle(cornerRadius: 27))
                .overlay(RoundedRectangle(cornerRadius: 27).stroke(Palette.tertiary.opacity(0.35), lineWidth: 0.5))
                .padding(.horizontal, 14)
            Text("AI 的回答可能有误，请核实重要信息。")
                .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.bottom, 5)
        }
        .background(Palette.background)
        .onChange(of: photos) { _, selection in
            guard !selection.isEmpty else { return }
            let conversationID = store.selectedID
            Task { @MainActor in
                loadingPhotos = true
                defer { loadingPhotos = false; photos = [] }
                for item in selection {
                    guard store.attachments.count < 4 else { break }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw APIError.server("无法读取这张图片。") }
                        let maxSide: CGFloat = 1600
                        let scale = min(1, maxSide / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw APIError.server("图片转换失败。") }
                        guard store.selectedID == conversationID else { return }
                        store.attachments.append(Attachment(data: jpeg))
                    } catch { store.errorMessage = error.localizedDescription }
                }
            }
        }
        .onDisappear { speech.stopListening() }
    }
}
