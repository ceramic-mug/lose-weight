import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(AppRouter.self) private var router
    @Environment(HealthKitService.self) private var health
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let profile = profiles.current, profile.hasOnboarded {
                MainView(profile: profile)
                    .task(id: scenePhase) {
                        guard scenePhase == .active, profile.useHealth else { return }
                        await health.sync(into: context, profile: profile)
                    }
            } else {
                OnboardingView(existing: profiles.current)
            }
        }
    }
}

struct MainView: View {
    let profile: UserProfile
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        content
            .sheet(item: $router.sheet) { sheet in
                Group {
                    switch sheet {
                    case .food: LogFoodView(profile: profile)
                    case .exercise: LogExerciseView(profile: profile)
                    case .weight: LogWeightView(profile: profile)
                    }
                }
                #if os(macOS)
                .frame(minWidth: 520, idealWidth: 560, minHeight: 600, idealHeight: 680)
                #endif
            }
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var router = router
        #if os(macOS)
        NavigationSplitView {
            List(AppRouter.Section.allCases, selection: Binding(
                get: { router.section },
                set: { if let s = $0 { router.section = s } }
            )) { section in
                Label(section.title, systemImage: section.systemImage).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            NavigationStack {
                screen(for: router.section)
            }
        }
        #else
        TabView(selection: $router.section) {
            ForEach(AppRouter.Section.allCases) { section in
                NavigationStack {
                    screen(for: section)
                }
                .tabItem { Label(section.title, systemImage: section.systemImage) }
                .tag(section)
            }
        }
        #endif
    }

    @ViewBuilder
    private func screen(for section: AppRouter.Section) -> some View {
        switch section {
        case .today: TodayView(profile: profile)
        case .history: HistoryView(profile: profile)
        case .trends: TrendsView(profile: profile)
        case .insights: InsightsView(profile: profile)
        case .settings: SettingsView(profile: profile)
        }
    }
}
