import Foundation
import LoseWeightCore

/// Everything the screens derive from the raw entries, computed once per render.
struct Snapshot {
    let profile: UserProfile
    let trend: [TrendPoint]
    let target: DailyTarget
    let kgPerWeek: Double?

    init(profile: UserProfile, weights: [WeightEntry]) {
        self.profile = profile
        let trend = WeightTrend.compute(weights.map(\.sample))
        self.trend = trend
        self.kgPerWeek = WeightTrend.kgPerWeek(trend)
        self.target = profile.dailyTarget(currentWeightKg: trend.last?.trendKg)
    }

    var units: UnitSystem { profile.units }

    /// Still working toward the goal, judged from where you are now (not where you started).
    var wantsLoss: Bool { !profile.maintenanceOnly && profile.goalWeightKg < currentKg - 0.1 }

    /// Smoothed current weight, or the starting weight if nothing has been logged yet.
    var currentKg: Double { trend.last?.trendKg ?? profile.startWeightKg }
    var latestScaleKg: Double? { trend.last?.scaleKg }

    var projectedGoalDate: Date? {
        GoalProjection.projectedDate(currentKg: currentKg, goalKg: profile.goalWeightKg, kgPerWeek: kgPerWeek, from: .now)
    }

    var goalProgress: Double {
        GoalProjection.progress(startKg: profile.startWeightKg, currentKg: currentKg, goalKg: profile.goalWeightKg)
    }

    /// Weight used for exercise calorie math.
    var weightForExerciseKg: Double { latestScaleKg ?? profile.startWeightKg }

    func dayBudget(foods: [FoodEntry], drinks: [DrinkEntry] = [], exercises: [ExerciseEntry],
                   on day: Date = .now, calendar: Calendar = .current) -> DayBudget {
        let drinkKcal = drinks
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .reduce(0) { $0 + $1.kcal }
        let eaten = foods
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .reduce(CalorieRange(drinkKcal, drinkKcal)) { $0 + $1.calories }
        let burned = exercises
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .reduce(0) { $0 + $1.netKcal }
        return DayBudget(targetKcal: target.targetKcal, eaten: eaten, exerciseKcal: burned)
    }

    func report(start: Date, end: Date, foods: [FoodEntry], drinks: [DrinkEntry] = [], exercises: [ExerciseEntry], weights: [WeightEntry]) -> PeriodReport {
        Auditor.report(
            start: start,
            end: end,
            food: foods.map(\.log),
            drinks: drinks.map(\.log),
            exercise: exercises.map(\.log),
            weights: weights.map(\.sample),
            targetKcal: target.targetKcal,
            currentWeightKg: currentKg,
            wantsLoss: wantsLoss
        )
    }

    func streak(foods: [FoodEntry], drinks: [DrinkEntry] = [], exercises: [ExerciseEntry], weights: [WeightEntry]) -> Int {
        var days = Set<Date>()
        drinks.forEach { days.insert($0.timestamp) }
        foods.forEach { days.insert($0.timestamp) }
        exercises.forEach { days.insert($0.timestamp) }
        weights.forEach { days.insert($0.timestamp) }
        return Auditor.streak(loggedDays: days, today: .now)
    }
}

extension Calendar {
    /// Monday–Sunday style week containing `date`, respecting the user's locale.
    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 7 * 86_400)
    }
}
