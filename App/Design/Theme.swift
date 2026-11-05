import SwiftUI
import LoseWeightCore

enum Theme {
    /// One calm accent; everything else is neutral so the data colors stand out.
    static let accent = Color(red: 0.16, green: 0.50, blue: 0.73)
    static let food = Color(red: 0.16, green: 0.50, blue: 0.73)
    static let exercise = Color(red: 0.93, green: 0.49, blue: 0.20)
    static let drink = Color(hex: 0x9C6644)
    static let weight = Color(red: 0.42, green: 0.36, blue: 0.80)

    // Tier colors: teal / amber / rose. Checked for color-blind separation and contrast
    // on both light and dark surfaces. Always paired with an icon or label, never color alone.
    static let lighter = Color(hex: 0x1E9C8A)
    static let balanced = Color(hex: 0xC38600)
    static let indulgent = Color(hex: 0xD6416A)

    static let cornerRadius: CGFloat = 18
    static let spacing: CGFloat = 16

    static var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var subtleFill: Color { Color.secondary.opacity(0.12) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Healthiness {
    var color: Color {
        switch self {
        case .lighter: Theme.lighter
        case .balanced: Theme.balanced
        case .indulgent: Theme.indulgent
        }
    }

    var systemImage: String {
        switch self {
        case .lighter: "leaf.fill"
        case .balanced: "circle.lefthalf.filled"
        case .indulgent: "flame.fill"
        }
    }
}

extension Intensity {
    var systemImage: String {
        switch self {
        case .light: "gauge.with.dots.needle.0percent"
        case .moderate: "gauge.with.dots.needle.50percent"
        case .vigorous: "gauge.with.dots.needle.100percent"
        }
    }
}

extension Insight.Kind {
    var color: Color {
        switch self {
        case .celebrate: Theme.lighter
        case .suggest: Theme.accent
        case .caution: Theme.indulgent
        }
    }
}

extension DayBudget.Status {
    var color: Color {
        switch self {
        case .under: Theme.accent
        case .onTrack: Theme.lighter
        case .over: Theme.indulgent
        }
    }
}
