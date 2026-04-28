import SwiftUI

@main
struct HomeCompanionApp: App {
    var body: some Scene {
        MenuBarExtra("Home Companion", systemImage: "house.fill") {
            MenuContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
