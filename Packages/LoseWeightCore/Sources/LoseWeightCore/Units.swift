import Foundation

public enum UnitSystem: String, CaseIterable, Codable, Sendable, Identifiable {
    case imperial
    case metric

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .imperial: "lb, ft/in"
        case .metric: "kg, cm"
        }
    }

    public var weightSymbol: String {
        switch self {
        case .imperial: "lb"
        case .metric: "kg"
        }
    }

    /// The nudge step for weight entry (0.2 lb or 0.1 kg).
    public var weightStep: Double {
        switch self {
        case .imperial: 0.2
        case .metric: 0.1
        }
    }

    public func displayWeight(fromKg kg: Double) -> Double {
        switch self {
        case .imperial: Units.kgToLb(kg)
        case .metric: kg
        }
    }

    public func kg(fromDisplay value: Double) -> Double {
        switch self {
        case .imperial: Units.lbToKg(value)
        case .metric: value
        }
    }

    public func formatWeight(_ kg: Double, decimals: Int = 1) -> String {
        let value = displayWeight(fromKg: kg)
        return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(weightSymbol)"
    }

    /// Formats a weight change with a sign, e.g. "−1.2 lb".
    public func formatWeightChange(_ kg: Double, decimals: Int = 1) -> String {
        let value = displayWeight(fromKg: kg)
        let magnitude = abs(value).formatted(.number.precision(.fractionLength(decimals)))
        let sign = value < -0.05 ? "−" : (value > 0.05 ? "+" : "")
        return "\(sign)\(magnitude) \(weightSymbol)"
    }

    public func formatHeight(_ cm: Double) -> String {
        switch self {
        case .metric:
            return "\(Int(cm.rounded())) cm"
        case .imperial:
            let (ft, inch) = Units.cmToFeetInches(cm)
            return "\(ft)′ \(inch)″"
        }
    }
}

public enum Units {
    public static let lbPerKg = 2.2046226218

    public static func kgToLb(_ kg: Double) -> Double { kg * lbPerKg }
    public static func lbToKg(_ lb: Double) -> Double { lb / lbPerKg }

    public static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((cm / 2.54).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    public static func feetInchesToCm(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * 2.54
    }
}
