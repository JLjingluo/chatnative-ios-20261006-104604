import SwiftUI

@main
struct ChatNativeApp: App {
    @StateObject private var store = ChatStore()
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
