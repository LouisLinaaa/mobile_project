import SwiftUI

@main
struct MobileProjectApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
