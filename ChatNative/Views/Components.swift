import SwiftUI
import UIKit

enum Palette {
    static let background = Color(uiColor: .systemBackground)
    static let secondary = Color(uiColor: .secondarySystemBackground)
    static let tertiary = Color(uiColor: .tertiarySystemFill)
    static let ink = Color.primary
}

struct IconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 21
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .regular))
                .foregroundStyle(.primary).frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct BrandMark: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                RoundedRectangle(cornerRadius: size * 0.19)
                    .stroke(.primary, lineWidth: size * 0.047)
                    .frame(width: size * 0.42, height: size * 0.64)
                    .offset(y: -size * 0.15)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct SheetHeader: View {
    let title: String
    let dismiss: () -> Void
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 30, height: 30).background(Palette.secondary, in: Circle())
            }.accessibilityLabel("关闭")
        }.padding(.horizontal, 24).padding(.vertical, 20)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct EditMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var text: String
    let onSave: (String) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("修改后会从这条消息重新生成，后续消息将被替换。可先通过消息菜单创建分支。").font(.footnote).foregroundStyle(.secondary)
                TextEditor(text: $text).padding(12).background(Palette.secondary, in: RoundedRectangle(cornerRadius: 20))
            }.padding().navigationTitle("编辑消息").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("发送") { onSave(text); dismiss() }.fontWeight(.semibold) }
                }
        }
    }
}
