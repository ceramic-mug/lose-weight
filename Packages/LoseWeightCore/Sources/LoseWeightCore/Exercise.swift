import Foundation

public enum ExerciseType: String, CaseIterable, Codable, Sendable, Identifiable {
    case walk
    case run
    case cycle
    case swim
    case strength
    case yoga
    case sports
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .walk: "Walking"
        case .run: "Running"
        case .cycle: "Cycling"
        case .swim: "Swimming"
        case .strength: "Strength"
        case .yoga: "Yoga / stretching"
        case .sports: "Sports"
        case .other: "Other"
        }
    }

    public var systemImage: String {
        switch self {
        case .walk: "figure.walk"
        case .run: "figure.run"
        case .cycle: "figure.outdoor.cycle"
        case .swim: "figure.pool.swim"
        case .strength: "dumbbell"
        case .yoga: "figure.yoga"
        case .sports: "sportscourt"
        case .other: "figure.mixed.cardio"
        }
    }

    /// Counts toward the "muscle-strengthening 2 days a week" guideline.
    public var isMuscleStrengthening: Bool { self == .strength }

    /// MET values from the Adult Compendium of Physical Activities (2011 / 2024 update).
    public func met(for intensity: Intensity) -> Double {
        switch (self, intensity) {
        case (.walk, .light): 2.8      // ~2.5 mph, strolling
        case (.walk, .moderate): 3.5   // ~3 mph
        case (.walk, .vigorous): 5.0   // ~4 mph brisk, or uphill
        case (.run, .light): 6.0       // jogging
        case (.run, .moderate): 8.3    // ~5 mph
        case (.run, .vigorous): 11.0   // ~7 mph
        case (.cycle, .light): 4.0     // leisure, <10 mph
        case (.cycle, .moderate): 6.8  // 12–14 mph
        case (.cycle, .vigorous): 10.0 // 16–19 mph
        case (.swim, .light): 5.0      // leisurely
        case (.swim, .moderate): 7.0   // steady laps
        case (.swim, .vigorous): 9.8   // fast laps
        case (.strength, .light): 3.5  // light effort
        case (.strength, .moderate): 5.0
        case (.strength, .vigorous): 6.0
        case (.yoga, .light): 2.3      // stretching
        case (.yoga, .moderate): 2.5   // hatha
        case (.yoga, .vigorous): 4.0   // power yoga
        case (.sports, .light): 4.0
        case (.sports, .moderate): 6.0
        case (.sports, .vigorous): 8.0
        case (.other, .light): 3.0
        case (.other, .moderate): 4.5
        case (.other, .vigorous): 7.0
        }
    }
}

public enum Intensity: String, CaseIterable, Codable, Sendable, Identifiable {
    case light
    case moderate
    case vigorous

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .light: "Easy"
        case .moderate: "Moderate"
        case .vigorous: "Hard"
        }
    }

    /// The "talk test" from the CDC: an easy way to judge effort without a heart-rate monitor.
    public var talkTest: String {
        switch self {
        case .light: "Easy to chat"
        case .moderate: "Can talk, but not sing"
        case .vigorous: "Only a few words at a time"
        }
    }
}

public enum ExerciseMath {
    /// Gross energy expenditure: kcal = MET × kg × hours.
    public static func grossCalories(met: Double, weightKg: Double, minutes: Double) -> Double {
        max(0, met * weightKg * minutes / 60)
    }

    /// Calories above what the body would burn at rest anyway (MET − 1).
    /// This is what gets added back to the day's food budget, so exercise isn't double counted.
    public static func netCalories(met: Double, weightKg: Double, minutes: Double) -> Double {
        max(0, (met - 1) * weightKg * minutes / 60)
    }

    public static func netCalories(type: ExerciseType, intensity: Intensity, weightKg: Double, minutes: Double) -> Double {
        netCalories(met: type.met(for: intensity), weightKg: weightKg, minutes: minutes)
    }

    /// Minutes credited toward the 150-minute weekly guideline (HHS 2018).
    /// Moderate (3–5.9 MET) counts 1×, vigorous (≥6 MET) counts 2×. Light (<3 MET) is great
    /// for health but doesn't count toward the aerobic target.
    public static func guidelineMinutes(met: Double, minutes: Double) -> Double {
        if met >= 6 { return minutes * 2 }
        if met >= 3 { return minutes }
        return 0
    }

    public static func guidelineMinutes(type: ExerciseType, intensity: Intensity, minutes: Double) -> Double {
        guidelineMinutes(met: type.met(for: intensity), minutes: minutes)
    }
}
