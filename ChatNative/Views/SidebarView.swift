import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: ChatStore
    let close: () -> Void
    @State private var search = ""
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var deleteID: UUID?
    @FocusState private var searchFocused: Bool

    private var filtered: [Conversation] {
        store.conversations.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.messages.contains { $0.text.localizedCaseInsensitiveContains(search) } }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    private var groups: [(String, [Conversation])] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day)!
        let week = calendar.date(byAdding: .day, value: -7, to: day)!
        return [
            ("今天", filtered.filter { $0.updatedAt >= day }),
            ("昨天", filtered.filter { $0.updatedAt >= yesterday && $0.updatedAt < day }),
            ("过去 7 天", filtered.filter { $0.updatedAt >= week && $0.updatedAt < yesterday }),
            ("更早", filtered.filter { $0.updatedAt < week })
        ].filter { !$0.1.isEmpty }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandMark(size: 27).padding(.leading, 8)
                Spacer()
                IconButton(symbol: "square.and.pencil", label: "新对话") { store.newChat() }
                IconButton(symbol: "sidebar.left", label: "关闭侧栏") { close() }
            }.padding(.horizontal, 14).padding(.vertical, 8)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索对话", text: $search).font(.system(size: 15)).focused($searchFocused)
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("清除搜索") }
            }.padding(12).background(Palette.tertiary.opacity(0.6), in: RoundedRectangle(cornerRadius: 13)).padding(.horizontal, 18).padding(.bottom, 12)
            Button { store.newChat() } label: {
                Label("新对话", systemImage: "plus").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }.padding(.horizontal, 9)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(search.isEmpty ? "你的想法，从这里开始" : "未找到对话").font(.system(size: 15, weight: .medium))
                            Text(search.isEmpty ? "发送第一条消息后，对话会保存在这里。" : "尝试搜索标题或消息内容。") .font(.footnote).foregroundStyle(.secondary)
                        }.padding(.horizontal, 22).padding(.top, 24)
                    }
                    ForEach(groups, id: \.0) { title, conversations in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.bottom, 5)
                            ForEach(conversations) { conversation in
                                Button { searchFocused = false; store.select(conversation) } label: {
                                    HStack(spacing: 8) {
                                        Text(conversation.title).font(.system(size: 15)).lineLimit(1)
                                        Spacer(minLength: 0)
                                        if store.streamingID == conversation.id { ProgressView().scaleEffect(0.7) }
                                    }.foregroundStyle(.primary).padding(.horizontal, 13).padding(.vertical, 13)
                                        .background(store.selectedID == conversation.id ? Palette.tertiary : .clear, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).padding(.horizontal, 9)
                                    .contextMenu {
                                        Button("重命名", systemImage: "pencil") { renameID = conversation.id; renameText = conversation.title }
                                        Button("删除对话", systemImage: "trash", role: .destructive) { deleteID = conversation.id }
                                    }
                            }
                        }
                    }
                }.padding(.vertical, 14)
            }.scrollDismissesKeyboard(.interactively)
            Divider().padding(.horizontal, 18)
            Button { searchFocused = false; close(); store.settingsOpen = true } label: {
                HStack(spacing: 12) {
                    Text("你").font(.system(size: 14, weight: .semibold)).frame(width: 34, height: 34).background(Palette.tertiary, in: Circle())
                    VStack(alignment: .leading, spacing: 3) { Text("个人设置").font(.system(size: 15, weight: .medium)); Text("接口、模型与偏好").font(.system(size: 11)).foregroundStyle(.secondary) }
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(.secondary)
                }.foregroundStyle(.primary).padding(.horizontal, 22).padding(.vertical, 18)
            }.buttonStyle(.plain)
        }.background(Palette.secondary).accessibilityAddTraits(.isModal)
            .alert("重命名对话", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
                TextField("对话标题", text: $renameText)
                Button("取消", role: .cancel) { renameID = nil }
                Button("保存") { if let id = renameID { store.rename(id, title: renameText) }; renameID = nil }
            }
            .alert("删除这个对话？", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("取消", role: .cancel) { deleteID = nil }
                Button("删除", role: .destructive) { if let id = deleteID { store.delete(id) }; deleteID = nil }
            } message: { Text("对话和其中的图片会从本机移除。") }
    }
}
