import SwiftUI

@MainActor
@Observable
final class AppRouter {
    enum Sheet: String, Identifiable {
        case food, drink, exercise, weight
        var id: String { rawValue }
    }

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case today, history, trends, insights, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: "Today"
            case .history: "History"
            case .trends: "Trends"
            case .insights: "Insights"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .today: "sun.max"
            case .history: "clock.arrow.circlepath"
            case .trends: "chart.xyaxis.line"
            case .insights: "checklist"
            case .settings: "gearshape"
            }
        }
    }

    var sheet: Sheet?
    var section: Section = .today
}
