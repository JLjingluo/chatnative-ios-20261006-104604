import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "模型") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.settings.models) { model in
                        Button { store.chooseModel(model); dismiss() } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(model.name).font(.system(size: 17, weight: .semibold))
                                        if model.supportsImages { Image(systemName: "photo").font(.system(size: 12)).foregroundStyle(.secondary) }
                                    }
                                    Text(model.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: store.currentModel == model.id ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(store.currentModel == model.id ? .primary : .tertiary)
                            }.foregroundStyle(.primary).padding(17).frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.currentModel == model.id ? Palette.secondary : .clear, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).disabled(store.isStreaming)
                    }
                }.padding(.horizontal, 16)
            }
            Divider().padding(.horizontal, 24)
            Button {
                dismiss(); Task { @MainActor in try? await Task.sleep(for: .milliseconds(350)); store.settingsOpen = true }
            } label: { Label("管理模型与接口", systemImage: "slider.horizontal.3").font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 16).nativeGlass(radius: 24, interactive: true) }
                .tint(.primary).padding(.horizontal, 20).padding(.vertical, 16)
            if store.isStreaming { Text("停止生成后可以切换模型").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 12) }
        }.background(Palette.background)
    }
}
