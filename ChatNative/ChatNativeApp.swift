import SwiftUI

@main
@MainActor
struct ChatNativeApp: App {
    @StateObject private var store: ChatStore
    init() {
        #if DEBUG
        let mode = UIPreviewFixture.requestedMode
        let state = ChatStore(preview: mode != nil)
        if let mode { state.configurePreview(mode: mode) }
        _store = StateObject(wrappedValue: state)
        #else
        _store = StateObject(wrappedValue: ChatStore())
        #endif
    }
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ChatView()
                .environmentObject(store)
                .preferredColorScheme(store.settings.appearance == "dark" ? .dark : store.settings.appearance == "light" ? .light : nil)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { store.persist() }
                    if phase == .background { store.stop() }
                }
        }
    }
}
