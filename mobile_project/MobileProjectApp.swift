import SwiftUI

@main
struct MobileProjectApp: App {
    @StateObject private var store = LedgerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshAutoLedgerShortcutState()
                    } else if newPhase == .inactive || newPhase == .background {
                        store.flushPendingSettingsPersistence()
                    }
                }
        }
    }
}
