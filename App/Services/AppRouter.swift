import SwiftUI

@MainActor
@Observable
final class AppRouter {
    enum Sheet: String, Identifiable {
        case food, exercise, weight
        var id: String { rawValue }
    }

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case today, trends, insights, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: "Today"
            case .trends: "Trends"
            case .insights: "Insights"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .today: "sun.max"
            case .trends: "chart.xyaxis.line"
            case .insights: "checklist"
            case .settings: "gearshape"
            }
        }
    }

    var sheet: Sheet?
    var section: Section = .today
}
