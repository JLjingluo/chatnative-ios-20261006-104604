import SwiftUI
import UIKit

struct MessageView: View {
    @EnvironmentObject private var store: ChatStore
    let message: Message
    let streaming: Bool
    let onEdit: () -> Void
    let onShare: () -> Void
    let onSpeak: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 10) {
            if message.role == .user {
                HStack {
                    Spacer(minLength: 36)
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(message.attachments) { attachment in
                            if let image = UIImage(data: attachment.data) {
                                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel("已发送的图片")
                            }
                        }
                        if !message.text.isEmpty {
                            Text(message.text).font(.system(size: 17)).lineSpacing(4).textSelection(.enabled)
                                .padding(.horizontal, 17).padding(.vertical, 12)
                                .background(Palette.secondary, in: RoundedRectangle(cornerRadius: 23))
                        }
                    }
                }
            } else {
                if message.text.isEmpty {
                    if streaming { TimelineView(.animation(minimumInterval: 0.5)) { context in
                        Circle().fill(.primary).frame(width: 10, height: 10).opacity(Int(context.date.timeIntervalSince1970 * 2) % 2 == 0 ? 1 : 0.35)
                    }.frame(height: 22).accessibilityLabel("正在生成回复") }
                    else { Text(message.interrupted ? "生成已结束" : "暂无内容").font(.footnote).foregroundStyle(.secondary) }
                } else { MarkdownView(source: message.text) }
                if message.interrupted && !streaming && !message.text.isEmpty { Text("未完成的回复").font(.caption).foregroundStyle(.secondary) }
                if !streaming && !message.text.isEmpty {
                    HStack(spacing: 18) {
                        action(copied ? "checkmark" : "doc.on.doc", copied ? "已复制" : "复制") { copy() }
                        action("speaker.wave.2", "朗读") { onSpeak() }
                        action("square.and.arrow.up", "分享") { onShare() }
                        if message.id == store.messages.last?.id { action("arrow.clockwise", "重新生成") { store.retry() } .disabled(store.isStreaming) }
                        Menu {
                            Button("从此处创建分支", systemImage: "arrow.triangle.branch") { store.fork(at: message.id) }
                        } label: { Image(systemName: "ellipsis").font(.system(size: 17)).frame(width: 30, height: 32) }.tint(.secondary).accessibilityLabel("更多消息操作")
                    }.padding(.top, 2)
                }
            }
        }.frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .contextMenu {
            Button("复制", systemImage: "doc.on.doc") { copy() }
            if message.role == .user { Button("编辑", systemImage: "pencil") { onEdit() }.disabled(store.isStreaming) }
            Button("分享", systemImage: "square.and.arrow.up") { onShare() }
            Button("创建对话分支", systemImage: "arrow.triangle.branch") { store.fork(at: message.id) }
        }
    }
    private func action(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 16)).frame(minWidth: 26, minHeight: 32) }
            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(label)
    }
    private func copy() {
        UIPasteboard.general.string = message.text
        copied = true
        store.haptic()
        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
    }
}

struct MarkdownBlock: Identifiable {
    enum Kind { case prose, code(String), table }
    let id: Int
    let kind: Kind
    let text: String
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var buffer: [String] = []
        var inCode = false
        var language = ""
        func flush(kind: Kind) {
            if !buffer.isEmpty { blocks.append(MarkdownBlock(id: blocks.count, kind: kind, text: buffer.joined(separator: "\n"))); buffer.removeAll() }
        }
        for line in source.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                flush(kind: inCode ? .code(language) : .prose)
                if !inCode { language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                inCode.toggle()
            } else { buffer.append(line) }
        }
        flush(kind: inCode ? .code(language) : .prose)
        return blocks
    }
}

struct MarkdownView: View {
    let source: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MarkdownBlock.parse(source)) { block in
                switch block.kind {
                case .code(let language): CodeBlockView(code: block.text, language: language)
                case .prose, .table: prose(block.text)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func prose(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.isEmpty { Color.clear.frame(height: 4) }
                else if line.hasPrefix("### ") { inline(String(line.dropFirst(4))).font(.system(size: 18, weight: .semibold)).padding(.top, 5) }
                else if line.hasPrefix("## ") { inline(String(line.dropFirst(3))).font(.system(size: 21, weight: .semibold)).padding(.top, 7) }
                else if line.hasPrefix("# ") { inline(String(line.dropFirst(2))).font(.system(size: 25, weight: .semibold)).padding(.top, 7) }
                else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    HStack(alignment: .top, spacing: 10) { Text("•"); inline(String(line.dropFirst(2))) }.padding(.leading, 4)
                } else if line.hasPrefix("> ") {
                    HStack(alignment: .top, spacing: 12) { Rectangle().fill(Palette.tertiary).frame(width: 3); inline(String(line.dropFirst(2))).foregroundStyle(.secondary) }.fixedSize(horizontal: false, vertical: true)
                } else if line == "---" { Divider().padding(.vertical, 5) }
                else { inline(line) }
            }
        }.font(.system(size: 17)).lineSpacing(5).tint(.primary).textSelection(.enabled)
    }
    private func inline(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "代码" : language).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                } label: { Label(copied ? "已复制" : "复制代码", systemImage: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12)) }.tint(.secondary)
            }.padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ScrollView(.horizontal) {
                Text(code).font(.system(size: 13, design: .monospaced)).lineSpacing(5).textSelection(.enabled).padding(14).fixedSize(horizontal: true, vertical: false)
            }
        }.background(Palette.secondary, in: RoundedRectangle(cornerRadius: 14)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
