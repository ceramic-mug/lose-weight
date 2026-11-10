import SwiftUI

@MainActor
@Observable
final class AppRouter {
    enum Sheet: String, Identifiable {
        case food, drink, exercise, weight
        var id: String { rawValue }
    }

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case analysis, today, history, trends, insights, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .analysis: "Analysis"
            case .today: "Today"
            case .history: "History"
            case .trends: "Trends"
            case .insights: "Insights"
            case .settings: "Settings"
            }
        }

        /// The phone is for logging and quick glances; Analysis is Mac-only.
        static var visible: [Section] {
            #if os(macOS)
            [.analysis, .today, .history, .trends, .insights, .settings]
            #else
            [.today, .history, .trends, .insights, .settings]
            #endif
        }

        var systemImage: String {
            switch self {
            case .analysis: "chart.bar.doc.horizontal"
            case .today: "sun.max"
            case .history: "clock.arrow.circlepath"
            case .trends: "chart.xyaxis.line"
            case .insights: "checklist"
            case .settings: "gearshape"
            }
        }
    }

    var sheet: Sheet?
    /// The Mac opens on Analysis (it's the place for looking at data); the phone on Today.
    var section: Section = Section.visible[0]
}
