import Foundation
import SwiftData
import LoseWeightCore

// CloudKit-backed SwiftData rules: every property has a default, no unique constraints,
// and relationships (if any) are optional. Enums are stored as raw strings so the schema
// can grow without migrations.

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var categoryRaw: String = FoodCategory.homeCooked.rawValue
    var healthinessRaw: String = Healthiness.balanced.rawValue
    var portionRaw: String = Portion.regular.rawValue
    var mealRaw: String = MealSlot.lunch.rawValue
    var kcalLow: Double = 0
    var kcalHigh: Double = 0
    var note: String = ""

    init(timestamp: Date = .now, category: FoodCategory, healthiness: Healthiness, portion: Portion, meal: MealSlot, note: String = "") {
        self.timestamp = timestamp
        self.categoryRaw = category.rawValue
        self.healthinessRaw = healthiness.rawValue
        self.portionRaw = portion.rawValue
        self.mealRaw = meal.rawValue
        self.note = note
        let range = EnergyEstimator.calories(category: category, healthiness: healthiness, portion: portion)
        self.kcalLow = range.low
        self.kcalHigh = range.high
    }

    /// Change any detail; the calorie estimate is recalculated.
    func update(timestamp: Date, category: FoodCategory, healthiness: Healthiness, portion: Portion, meal: MealSlot) {
        self.timestamp = timestamp
        categoryRaw = category.rawValue
        healthinessRaw = healthiness.rawValue
        portionRaw = portion.rawValue
        mealRaw = meal.rawValue
        let range = EnergyEstimator.calories(category: category, healthiness: healthiness, portion: portion)
        kcalLow = range.low
        kcalHigh = range.high
    }

    var category: FoodCategory { FoodCategory(rawValue: categoryRaw) ?? .homeCooked }
    var healthiness: Healthiness { Healthiness(rawValue: healthinessRaw) ?? .balanced }
    var portion: Portion { Portion(rawValue: portionRaw) ?? .regular }
    var meal: MealSlot { MealSlot(rawValue: mealRaw) ?? .snack }
    var calories: CalorieRange { CalorieRange(kcalLow, kcalHigh) }

    var log: FoodLog { FoodLog(date: timestamp, category: category, healthiness: healthiness, portion: portion, meal: meal) }

    /// Used for "recent" chips: the same choice made again.
    var comboKey: String { "\(categoryRaw)|\(healthinessRaw)|\(portionRaw)" }
}

@Model
final class ExerciseEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var typeRaw: String = ExerciseType.walk.rawValue
    var intensityRaw: String = Intensity.moderate.rawValue
    var minutes: Double = 0
    /// Net (above resting) calories, fixed at the time of logging using that day's weight.
    var netKcal: Double = 0
    /// Set when imported from Apple Health, to avoid duplicates.
    var healthKitID: String?

    init(timestamp: Date = .now, type: ExerciseType, intensity: Intensity, minutes: Double, weightKg: Double, healthKitID: String? = nil) {
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
        self.intensityRaw = intensity.rawValue
        self.minutes = minutes
        self.netKcal = ExerciseMath.netCalories(type: type, intensity: intensity, weightKg: weightKg, minutes: minutes)
        self.healthKitID = healthKitID
    }

    /// Change any detail; calories are recalculated.
    func update(timestamp: Date, type: ExerciseType, intensity: Intensity, minutes: Double, weightKg: Double) {
        self.timestamp = timestamp
        typeRaw = type.rawValue
        intensityRaw = intensity.rawValue
        self.minutes = minutes
        netKcal = ExerciseMath.netCalories(type: type, intensity: intensity, weightKg: weightKg, minutes: minutes)
    }

    var type: ExerciseType { ExerciseType(rawValue: typeRaw) ?? .other }
    var intensity: Intensity { Intensity(rawValue: intensityRaw) ?? .moderate }
    var isFromHealth: Bool { healthKitID != nil }

    var log: ExerciseLog { ExerciseLog(date: timestamp, type: type, intensity: intensity, minutes: minutes) }
}

@Model
final class DrinkEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var styleRaw: String = DrinkStyle.water.rawValue
    var sizeRaw: String = DrinkSize.medium.rawValue
    // Stored at log time so past entries don't change if the table is updated.
    var ml: Double = 0
    var caffeineMg: Double = 0
    var kcal: Double = 0

    init(timestamp: Date = .now, style: DrinkStyle, size: DrinkSize) {
        let spec = style.spec
        self.timestamp = timestamp
        self.styleRaw = style.rawValue
        self.sizeRaw = size.rawValue
        self.ml = spec.ml(size)
        self.caffeineMg = spec.caffeine(size)
        self.kcal = spec.kcal(size)
    }

    func update(timestamp: Date, style: DrinkStyle, size: DrinkSize) {
        self.timestamp = timestamp
        styleRaw = style.rawValue
        sizeRaw = size.rawValue
        let spec = style.spec
        ml = spec.ml(size)
        caffeineMg = spec.caffeine(size)
        kcal = spec.kcal(size)
    }

    var style: DrinkStyle { DrinkStyle(rawValue: styleRaw) ?? .water }
    var size: DrinkSize { DrinkSize(rawValue: sizeRaw) ?? .medium }
    var kind: DrinkKind { style.kind }
    var comboKey: String { "\(styleRaw)|\(sizeRaw)" }

    var log: DrinkLog { DrinkLog(date: timestamp, style: style, size: size) }
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var kg: Double = 0
    /// The matching Apple Health sample (whether we wrote it or read it).
    var healthKitID: String?
    /// True when the reading came from Apple Health (e.g. a smart scale).
    var isImported: Bool = false

    init(timestamp: Date = .now, kg: Double, healthKitID: String? = nil, isImported: Bool = false) {
        self.timestamp = timestamp
        self.kg = kg
        self.healthKitID = healthKitID
        self.isImported = isImported
    }

    var sample: WeightSample { WeightSample(date: timestamp, kg: kg) }
}

@Model
final class UserProfile {
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var hasOnboarded: Bool = false

    var sexRaw: String = Sex.unspecified.rawValue
    var birthYear: Int = 1985
    var heightCm: Double = 170
    var startWeightKg: Double = 80
    var startDate: Date = Date.now
    var goalWeightKg: Double = 76
    var activityRaw: String = ActivityLevel.sedentary.rawValue
    var paceRaw: String = LossPace.steady.rawValue
    var unitsRaw: String = UnitSystem.imperial.rawValue
    /// "Just maintain my weight": no calorie deficit.
    var maintenanceOnly: Bool = false

    var showCalorieNumbers: Bool = false
    var useHealth: Bool = false
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .sedentary }
        set { activityRaw = newValue.rawValue }
    }
    var pace: LossPace {
        get { LossPace(rawValue: paceRaw) ?? .steady }
        set { paceRaw = newValue.rawValue }
    }
    var units: UnitSystem {
        get { UnitSystem(rawValue: unitsRaw) ?? .imperial }
        set { unitsRaw = newValue.rawValue }
    }

    var ageYears: Int {
        let year = Calendar.current.component(.year, from: .now)
        return max(18, year - birthYear)
    }

    var wantsLoss: Bool { !maintenanceOnly && goalWeightKg < startWeightKg - 0.1 }

    func coreProfile(currentWeightKg: Double?) -> Profile {
        Profile(
            sex: sex,
            ageYears: ageYears,
            heightCm: heightCm,
            weightKg: currentWeightKg ?? startWeightKg,
            goalWeightKg: goalWeightKg,
            activity: activity,
            pace: pace,
            maintenanceOnly: maintenanceOnly
        )
    }

    func dailyTarget(currentWeightKg: Double?) -> DailyTarget {
        TargetCalculator.dailyTarget(for: coreProfile(currentWeightKg: currentWeightKg))
    }
}

extension Array where Element == UserProfile {
    /// iCloud sync can briefly create duplicates; the most recently edited onboarded profile wins.
    var current: UserProfile? {
        self.sorted {
            if $0.hasOnboarded != $1.hasOnboarded { return $0.hasOnboarded }
            return $0.updatedAt > $1.updatedAt
        }.first
    }
}
