import Foundation

// Plain value types so the audit logic doesn't depend on any database.

public struct FoodLog: Equatable, Sendable {
    public var date: Date
    public var category: FoodCategory
    public var healthiness: Healthiness
    public var portion: Portion
    public var meal: MealSlot

    public init(date: Date, category: FoodCategory, healthiness: Healthiness, portion: Portion, meal: MealSlot? = nil) {
        self.date = date
        self.category = category
        self.healthiness = healthiness
        self.portion = portion
        self.meal = meal ?? MealSlot.suggested(for: date, category: category)
    }

    public var calories: CalorieRange { EnergyEstimator.calories(category: category, healthiness: healthiness, portion: portion) }
}

public struct ExerciseLog: Equatable, Sendable {
    public var date: Date
    public var type: ExerciseType
    public var intensity: Intensity
    public var minutes: Double

    public init(date: Date, type: ExerciseType, intensity: Intensity, minutes: Double) {
        self.date = date
        self.type = type
        self.intensity = intensity
        self.minutes = minutes
    }

}

public enum EnergyEstimator {
    public static func calories(category: FoodCategory, healthiness: Healthiness, portion: Portion) -> CalorieRange {
        category.regularRange(for: healthiness).scaled(by: portion.multiplier)
    }
}

// MARK: - Day

public struct DayBudget: Equatable, Sendable {
    public var targetKcal: Double
    public var eaten: CalorieRange
    public var exerciseKcal: Double

    public init(targetKcal: Double, eaten: CalorieRange, exerciseKcal: Double) {
        self.targetKcal = targetKcal
        self.eaten = eaten
        self.exerciseKcal = exerciseKcal
    }

    /// Exercise "earns back" food, using net (above-resting) calories.
    public var budgetKcal: Double { targetKcal + exerciseKcal }
    public var remainingKcal: Double { budgetKcal - eaten.mid }
    /// 0...∞, where 1.0 means exactly on budget.
    public var fraction: Double { budgetKcal > 0 ? eaten.mid / budgetKcal : 0 }

    public enum Status: Sendable { case under, onTrack, over }

    /// Within ±10% counts as on track — the estimates aren't precise enough to be stricter.
    public var status: Status {
        if fraction > 1.10 { return .over }
        if fraction >= 0.90 { return .onTrack }
        return .under
    }
}

// MARK: - Week

public struct Insight: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case celebrate, suggest, caution }

    public var kind: Kind
    public var title: String
    public var detail: String
    public var systemImage: String

    public var id: String { title }
}

public struct PeriodReport: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var days: Int

    // Eating
    public var mealsLogged: Int
    public var tierCounts: [Healthiness: Int]
    public var categoryCounts: [FoodCategory: Int]
    /// Indulgent drinks (soda, sweet coffee, alcohol).
    public var sweetDrinks: Int
    public var drinksLogged: Int
    /// Average caffeine on days with any drink logged.
    public var avgCaffeineMg: Double?
    /// Days over the 400 mg guideline.
    public var highCaffeineDays: Int
    /// Days with caffeine after 2 pm.
    public var lateCaffeineDays: Int
    public var foodDaysLogged: Int
    public var averageDailyKcal: Double?
    public var targetKcal: Double
    /// Share of logged items that were lighter or balanced (0...1).
    public var healthyShare: Double?
    /// Average quality score (0...1).
    public var qualityScore: Double?

    // Movement
    /// Minutes actually logged in the period.
    public var activeMinutes: Double
    public var strengthDays: Int
    public var exerciseSessions: Int
    /// Minutes to compare with the 150-a-week goal: the real total for a week or less
    /// (never projected), or the weekly average for longer periods.
    public var activeMinutesPerWeek: Double

    // Weight
    public var trendChangeKg: Double?
    public var kgPerWeek: Double?
    public var weighIns: Int

    // Habit
    public var daysWithAnyLog: Int
    public var bestWeekday: Int?

    /// 0–100 overall score: food quality 40, staying near target 20, movement 30, consistency 10.
    public var overallScore: Int
    public var insights: [Insight]

    public var grade: String {
        switch overallScore {
        case 85...: "A"
        case 70..<85: "B"
        case 55..<70: "C"
        case 40..<55: "D"
        default: "Getting started"
        }
    }
}

public enum Auditor {
    public static func report(
        start: Date,
        end: Date,
        food: [FoodLog],
        drinks: [DrinkLog] = [],
        exercise: [ExerciseLog],
        weights: [WeightSample],
        targetKcal: Double,
        currentWeightKg: Double,
        wantsLoss: Bool,
        calendar: Calendar = .current
    ) -> PeriodReport {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dayCount = max(1, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) else {
            fatalError("Calendar could not add a day")
        }
        func inRange(_ d: Date) -> Bool { d >= startDay && d < endExclusive }

        let food = food.filter { inRange($0.date) }
        let exercise = exercise.filter { inRange($0.date) }
        let drinks = drinks.filter { inRange($0.date) }

        // Eating
        var tiers: [Healthiness: Int] = [:]
        var categories: [FoodCategory: Int] = [:]
        var kcalByDay: [Date: Double] = [:]
        var qualityByDay: [Date: [Double]] = [:]
        for f in food {
            tiers[f.healthiness, default: 0] += 1
            categories[f.category, default: 0] += 1
            let day = calendar.startOfDay(for: f.date)
            kcalByDay[day, default: 0] += f.calories.mid
            qualityByDay[day, default: []].append(f.healthiness.qualityScore)
        }
        // Drink calories count toward intake on days with food logged. A coffee-only
        // day shouldn't look like a day of barely eating.
        for d in drinks {
            let day = calendar.startOfDay(for: d.date)
            if kcalByDay[day] != nil { kcalByDay[day]! += d.kcal }
        }
        // Water, black coffee etc. shouldn't count toward "healthy share" or quality.
        let scored = food.filter { !($0.category == .drink && $0.healthiness == .lighter) }
        let healthyShare: Double? = scored.isEmpty ? nil :
            Double(scored.filter { $0.healthiness != .indulgent }.count) / Double(scored.count)
        let quality: Double? = scored.isEmpty ? nil :
            scored.map(\.healthiness.qualityScore).reduce(0, +) / Double(scored.count)
        let avgKcal: Double? = kcalByDay.isEmpty ? nil : kcalByDay.values.reduce(0, +) / Double(kcalByDay.count)

        // Movement
        let activeMinutes = exercise.map(\.minutes).reduce(0, +)
        let strengthDays = Set(exercise.filter { $0.type.isMuscleStrengthening }.map { calendar.startOfDay(for: $0.date) }).count
        let perWeek = dayCount <= 7 ? activeMinutes : activeMinutes / Double(dayCount) * 7

        // Weight — compute the trend on all history so the start of the period is already smoothed.
        let trend = WeightTrend.compute(weights, calendar: calendar)
        let inPeriod = trend.filter { inRange($0.day) }
        let before = trend.last { $0.day < startDay }
        var trendChange: Double?
        if let last = inPeriod.last, let first = before ?? inPeriod.first, last.day != first.day {
            trendChange = last.trendKg - first.trendKg
        }
        let rate = WeightTrend.kgPerWeek(trend, endingAt: inPeriod.last?.day, calendar: calendar)

        // Drinks & caffeine
        let caffeineByDay = DrinkMath.caffeineByDay(drinks, calendar: calendar)
        let drinkDays = Set(drinks.map { calendar.startOfDay(for: $0.date) })
        let avgCaffeine: Double? = drinkDays.isEmpty ? nil : caffeineByDay.values.reduce(0, +) / Double(drinkDays.count)
        let highCaffeineDays = caffeineByDay.values.filter { $0 > DrinkMath.caffeineDailyLimitMg }.count
        let lateCaffeineDays = Set(drinks
            .filter { $0.caffeineMg >= 30 && calendar.component(.hour, from: $0.date) >= DrinkMath.lateCaffeineHour }
            .map { calendar.startOfDay(for: $0.date) }).count

        // Habit
        var loggedDays = Set(kcalByDay.keys).union(drinkDays)
        exercise.forEach { loggedDays.insert(calendar.startOfDay(for: $0.date)) }
        inPeriod.forEach { loggedDays.insert($0.day) }

        // Best weekday needs a real pattern: each weekday seen on 2+ separate days,
        // and at least 3 weekdays to compare. A single week never qualifies.
        var weekdayDays: [Int: [Double]] = [:]
        for (day, scores) in qualityByDay {
            weekdayDays[calendar.component(.weekday, from: day), default: []].append(avg(scores))
        }
        let eligible = weekdayDays.filter { $0.value.count >= 2 }
        let bestWeekday = eligible.count >= 3
            ? eligible.max { avg($0.value) < avg($1.value) }?.key
            : nil

        // Score
        let foodPart = (quality ?? 0) * 40
        var targetPart = 0.0
        if let avgKcal, targetKcal > 0 {
            let off = abs(avgKcal - targetKcal) / targetKcal
            targetPart = max(0, 1 - off / 0.3) * 20 // full marks within ~0%, zero at 30% off
        }
        let movePart = min(1, perWeek / EnergyConstants.weeklyActiveMinutesGoal) * 30
        let consistencyPart = Double(loggedDays.count) / Double(dayCount) * 10
        let score = Int((foodPart + targetPart + movePart + consistencyPart).rounded())

        var report = PeriodReport(
            start: startDay,
            end: endDay,
            days: dayCount,
            mealsLogged: food.count,
            tierCounts: tiers,
            categoryCounts: categories,
            sweetDrinks: food.filter { $0.category == .drink && $0.healthiness == .indulgent }.count
                + drinks.filter(\.isSweet).count,
            drinksLogged: drinks.count,
            avgCaffeineMg: avgCaffeine,
            highCaffeineDays: highCaffeineDays,
            lateCaffeineDays: lateCaffeineDays,
            foodDaysLogged: kcalByDay.count,
            averageDailyKcal: avgKcal,
            targetKcal: targetKcal,
            healthyShare: healthyShare,
            qualityScore: quality,
            activeMinutes: activeMinutes,
            strengthDays: strengthDays,
            exerciseSessions: exercise.count,
            activeMinutesPerWeek: perWeek,
            trendChangeKg: trendChange,
            kgPerWeek: rate,
            weighIns: inPeriod.count,
            daysWithAnyLog: loggedDays.count,
            bestWeekday: bestWeekday,
            overallScore: min(100, max(0, score)),
            insights: []
        )
        report.insights = InsightEngine.insights(for: report, currentWeightKg: currentWeightKg, wantsLoss: wantsLoss, calendar: calendar)
        return report
    }

    private static func avg(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

    /// Consecutive days, ending today (or yesterday, so a streak isn't "lost" before you log today),
    /// with at least one entry of any kind.
    public static func streak(loggedDays: Set<Date>, today: Date, calendar: Calendar = .current) -> Int {
        let normalized = Set(loggedDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !normalized.contains(day) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day), normalized.contains(y) else { return 0 }
            day = y
        }
        var count = 0
        while normalized.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
}

// MARK: - Plain-language tips

public enum InsightEngine {
    public static func insights(for r: PeriodReport, currentWeightKg: Double, wantsLoss: Bool, calendar: Calendar = .current) -> [Insight] {
        var out: [Insight] = []
        // Scale counts to "per week" only for periods longer than a week; a week in
        // progress shows its real counts (one drink on Monday is not "7 a week").
        let weekScale = r.days > 7 ? 7 / Double(r.days) : 1

        // Safety first.
        if let rate = r.kgPerWeek, wantsLoss, currentWeightKg > 0,
           -rate > currentWeightKg * EnergyConstants.maxSafeWeeklyLossFraction {
            out.append(Insight(
                kind: .caution,
                title: "Losing faster than recommended",
                detail: "Over 1% of body weight a week. Eat a little more; see a doctor if it continues.",
                systemImage: "exclamationmark.triangle"
            ))
        }
        if let avg = r.averageDailyKcal, r.foodDaysLogged >= 3, avg < r.targetKcal * 0.75 {
            out.append(Insight(
                kind: .caution,
                title: "Eating well under your target",
                detail: "Aim to land close to your budget, not far under it.",
                systemImage: "exclamationmark.triangle"
            ))
        }

        if r.highCaffeineDays > 0 {
            out.append(Insight(
                kind: .caution,
                title: "Caffeine topped 400 mg on \(r.highCaffeineDays) day\(r.highCaffeineDays == 1 ? "" : "s")",
                detail: "400 mg is the daily guideline for most adults. Swap one cup for decaf or tea.",
                systemImage: "cup.and.saucer"
            ))
        }

        // Celebrations.
        if r.activeMinutesPerWeek >= EnergyConstants.weeklyActiveMinutesGoal {
            out.append(Insight(
                kind: .celebrate,
                title: "Activity goal met",
                detail: "\(Int(r.activeMinutesPerWeek.rounded())) active minutes a week.",
                systemImage: "figure.run"
            ))
        }
        if let share = r.healthyShare, r.mealsLogged >= 5, share >= 0.75 {
            out.append(Insight(
                kind: .celebrate,
                title: "Mostly healthy choices",
                detail: "\(Int((share * 100).rounded()))% lighter or balanced.",
                systemImage: "leaf"
            ))
        }
        if let change = r.trendChangeKg, wantsLoss, change < -0.1 {
            out.append(Insight(
                kind: .celebrate,
                title: "Trend is going down",
                detail: "Keep doing what you're doing.",
                systemImage: "chart.line.downtrend.xyaxis"
            ))
        }

        // Suggestions.
        let takeout = (r.categoryCounts[.fastFood] ?? 0) + (r.categoryCounts[.restaurant] ?? 0)
        let meals = r.categoryCounts.filter { $0.key.isMeal }.map(\.value).reduce(0, +)
        if meals >= 5, Double(takeout) / Double(meals) >= 0.25 {
            let saving = FoodCategory.fastFood.regularRange(for: .balanced).mid
                - FoodCategory.homeCooked.regularRange(for: .balanced).mid
            let kgPerWeek = saving * 2 / EnergyConstants.kcalPerKg
            out.append(Insight(
                kind: .suggest,
                title: "Swap two takeout meals a week",
                detail: "\(takeout) of \(meals) meals were takeout. Cooking 2 at home saves ≈\(Int((saving * 2).rounded(toNearest: 50))) kcal (≈\(kgPerWeek.formatted(.number.precision(.fractionLength(2)))) kg) a week.",
                systemImage: "frying.pan"
            ))
        }
        let sugaryDrinks = r.sweetDrinks
        if Double(sugaryDrinks) * weekScale >= 3 {
            out.append(Insight(
                kind: .suggest,
                title: "Fewer sweet drinks",
                detail: "≈\(Int((Double(sugaryDrinks) * weekScale).rounded())) a week. Swap half for water or unsweetened coffee.",
                systemImage: "cup.and.saucer"
            ))
        }
        if r.lateCaffeineDays >= 2 {
            out.append(Insight(
                kind: .suggest,
                title: "Caffeine after 2 pm on \(r.lateCaffeineDays) days",
                detail: "It can affect sleep hours later. Try decaf in the afternoon.",
                systemImage: "moon.zzz"
            ))
        }
        let indulgent = r.tierCounts[.indulgent] ?? 0
        if r.mealsLogged >= 5, Double(indulgent) / Double(r.mealsLogged) > 0.35 {
            out.append(Insight(
                kind: .suggest,
                title: "One lighter swap a day",
                detail: "Over a third were indulgent. Try grilled instead of fried, or half the plate veg.",
                systemImage: "leaf"
            ))
        }
        let minutesShort = EnergyConstants.weeklyActiveMinutesGoal - r.activeMinutesPerWeek
        if minutesShort > 0 {
            let perDay = Int((minutesShort / 5 / 5).rounded(.up) * 5)
            out.append(Insight(
                kind: .suggest,
                title: "\(Int(minutesShort.rounded())) more active minutes a week",
                detail: "≈\(max(perDay, 5)) min on 5 days. A walk counts.",
                systemImage: "figure.walk"
            ))
        }
        if Double(r.strengthDays) * weekScale < Double(EnergyConstants.weeklyStrengthDaysGoal) {
            out.append(Insight(
                kind: .suggest,
                title: "Add strength twice a week",
                detail: "Squats, push-ups or bands at home are enough.",
                systemImage: "dumbbell"
            ))
        }
        if Double(r.daysWithAnyLog) / Double(r.days) < 0.6 {
            out.append(Insight(
                kind: .suggest,
                title: "Log most days",
                detail: "Even one entry a day helps.",
                systemImage: "checkmark.circle"
            ))
        }
        if let change = r.trendChangeKg, wantsLoss, change > 0.3, r.foodDaysLogged >= 3 {
            out.append(Insight(
                kind: .suggest,
                title: "Trend is creeping up",
                detail: "Try a smaller portion at one meal a day.",
                systemImage: "arrow.up.right"
            ))
        }
        if let wd = r.bestWeekday {
            let name = calendar.weekdaySymbols[(wd - 1) % 7]
            out.append(Insight(
                kind: .celebrate,
                title: "\(name)s are your best day",
                detail: "Your healthiest choices. Borrow that routine.",
                systemImage: "calendar"
            ))
        }

        // Cautions first, then suggestions, then celebrations.
        let order: [Insight.Kind: Int] = [.caution: 0, .suggest: 1, .celebrate: 2]
        return out.enumerated()
            .sorted { (order[$0.element.kind]!, $0.offset) < (order[$1.element.kind]!, $1.offset) }
            .map(\.element)
    }
}

private extension Double {
    func rounded(toNearest step: Double) -> Double { (self / step).rounded() * step }
}
