import SwiftUI
import SwiftData

@main
struct LoseWeightApp: App {
    @State private var router = AppRouter()
    @State private var health = HealthKitService()
    private let container = AppContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(health)
                .tint(Theme.accent)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
        .commands {
            CommandMenu("Log") {
                Button("Log Food…") { router.sheet = .food }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Log Drink…") { router.sheet = .drink }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Log Exercise…") { router.sheet = .exercise }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Log Weight…") { router.sheet = .weight }
                    .keyboardShortcut("4", modifiers: .command)
            }
        }
    }
}
