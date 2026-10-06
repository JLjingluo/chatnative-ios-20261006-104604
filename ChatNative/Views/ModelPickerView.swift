import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "选择模型") { dismiss() }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.settings.models) { model in
                        Button { store.chooseModel(model); dismiss() } label: {
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: model.supportsImages ? "sparkles" : "bubble.left").font(.system(size: 22)).frame(width: 32)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(model.name).font(.system(size: 17, weight: .semibold))
                                    Text(model.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                                    if model.name != model.id { Text(model.id).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary) }
                                }
                                Spacer(minLength: 0)
                                if store.currentModel == model.id { Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)) }
                            }.foregroundStyle(.primary).padding(16)
                                .background(store.currentModel == model.id ? Palette.secondary : .clear, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).disabled(store.isStreaming)
                    }
                }.padding(.horizontal, 14)
            }
            Button {
                dismiss()
                Task { @MainActor in try? await Task.sleep(for: .milliseconds(350)); store.settingsOpen = true }
            } label: { Label("管理模型与接口", systemImage: "slider.horizontal.3").font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(18) }.tint(.primary)
            if store.isStreaming { Text("停止生成后可以切换模型").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 12) }
        }.background(Palette.background)
    }
}
