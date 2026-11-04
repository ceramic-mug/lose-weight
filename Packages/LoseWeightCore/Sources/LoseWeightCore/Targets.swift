import Foundation

public enum Sex: String, CaseIterable, Codable, Sendable, Identifiable {
    case female
    case male
    case unspecified

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unspecified: "Prefer not to say"
        }
    }
}

/// Everyday activity *outside* logged exercise. Logged workouts are added on top,
/// so this deliberately stops at "on your feet most of the day".
public enum ActivityLevel: String, CaseIterable, Codable, Sendable, Identifiable {
    case sedentary
    case light
    case active

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sedentary: "Mostly sitting"
        case .light: "On my feet some of the day"
        case .active: "On my feet most of the day"
        }
    }

    public var example: String {
        switch self {
        case .sedentary: "Desk job, drive most places"
        case .light: "Teacher, retail, lots of errands"
        case .active: "Nurse, server, trades, warehouse"
        }
    }

    /// Standard activity multipliers applied to resting energy.
    public var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .active: 1.55
        }
    }
}

/// How fast to aim to lose. All options stay within the CDC's 0.5–1 kg (1–2 lb) per week.
public enum LossPace: String, CaseIterable, Codable, Sendable, Identifiable {
    case gentle
    case steady
    case brisk

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .brisk: "Brisk"
        }
    }

    public var kgPerWeek: Double {
        switch self {
        case .gentle: 0.25
        case .steady: 0.5
        case .brisk: 0.75
        }
    }

    public var dailyDeficit: Double { kgPerWeek * EnergyConstants.kcalPerKg / 7 }
}

public enum EnergyConstants {
    /// Widely used approximation for the energy in 1 kg of body fat tissue.
    public static let kcalPerKg: Double = 7700
    /// NIH/NHLBI: don't go below these without medical supervision.
    public static func calorieFloor(for sex: Sex) -> Double {
        switch sex {
        case .male: 1500
        case .female, .unspecified: 1200
        }
    }
    /// HHS 2018 Physical Activity Guidelines.
    public static let weeklyActiveMinutesGoal: Double = 150
    public static let weeklyStrengthDaysGoal: Int = 2
    /// Losing faster than this share of body weight per week is a caution sign.
    public static let maxSafeWeeklyLossFraction: Double = 0.01
}

public struct Profile: Equatable, Sendable {
    public var sex: Sex
    public var ageYears: Int
    public var heightCm: Double
    public var weightKg: Double
    public var goalWeightKg: Double
    public var activity: ActivityLevel
    public var pace: LossPace
    /// Pregnancy, breastfeeding, or an eating-disorder history: we don't set a deficit.
    public var maintenanceOnly: Bool

    public init(
        sex: Sex,
        ageYears: Int,
        heightCm: Double,
        weightKg: Double,
        goalWeightKg: Double,
        activity: ActivityLevel,
        pace: LossPace = .steady,
        maintenanceOnly: Bool = false
    ) {
        self.sex = sex
        self.ageYears = ageYears
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goalWeightKg = goalWeightKg
        self.activity = activity
        self.pace = pace
        self.maintenanceOnly = maintenanceOnly
    }
}

public struct DailyTarget: Equatable, Sendable {
    public var restingKcal: Double
    public var maintenanceKcal: Double
    public var targetKcal: Double
    public var plannedDeficit: Double
    /// True if the calorie floor kicked in and limited the deficit.
    public var limitedByFloor: Bool

    public var expectedKgPerWeek: Double { plannedDeficit * 7 / EnergyConstants.kcalPerKg }
}

public enum TargetCalculator {
    /// Mifflin-St Jeor resting energy expenditure (kcal/day).
    public static func restingEnergy(sex: Sex, ageYears: Int, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .unspecified: return base - 78
        }
    }

    public static func dailyTarget(for profile: Profile) -> DailyTarget {
        let resting = restingEnergy(
            sex: profile.sex,
            ageYears: profile.ageYears,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg
        )
        let maintenance = resting * profile.activity.factor
        let wantsLoss = !profile.maintenanceOnly && profile.goalWeightKg < profile.weightKg - 0.1
        guard wantsLoss else {
            return DailyTarget(
                restingKcal: resting,
                maintenanceKcal: maintenance,
                targetKcal: maintenance.rounded(),
                plannedDeficit: 0,
                limitedByFloor: false
            )
        }
        let floor = EnergyConstants.calorieFloor(for: profile.sex)
        let desired = maintenance - profile.pace.dailyDeficit
        let target = max(floor, desired)
        return DailyTarget(
            restingKcal: resting,
            maintenanceKcal: maintenance,
            targetKcal: target.rounded(),
            plannedDeficit: max(0, maintenance - target),
            limitedByFloor: desired < floor
        )
    }

    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// Weight for a given BMI at this height.
    public static func weight(forBMI bmi: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return bmi * m * m
    }

    /// The lowest goal we'll accept: BMI 18.5 (the bottom of the healthy range).
    public static func minimumGoalWeight(heightCm: Double) -> Double {
        weight(forBMI: 18.5, heightCm: heightCm)
    }

    /// NIH/AHA guidance: a first goal of 5–10% of starting weight brings real health benefits.
    public static func suggestedGoals(currentKg: Double, heightCm: Double) -> [Double] {
        let floor = minimumGoalWeight(heightCm: heightCm)
        return [0.05, 0.10]
            .map { currentKg * (1 - $0) }
            .filter { $0 >= floor }
    }

    public static func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: "Below the healthy range"
        case ..<25: "Healthy range"
        case ..<30: "Above the healthy range"
        default: "Well above the healthy range"
        }
    }
}
