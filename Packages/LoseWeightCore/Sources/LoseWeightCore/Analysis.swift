import Foundation

/// Longer-range analysis used by the Mac Analysis view. Pure functions, no UI.
public enum Analysis {

    // MARK: When you eat best

    public struct QualityCell: Equatable, Sendable, Identifiable {
        public let weekday: Int      // Calendar weekday, 1 = Sunday
        public let slot: MealSlot
        public let quality: Double   // 0...1, average healthiness
        public let count: Int
        public var id: String { "\(weekday)-\(slot.rawValue)" }
    }

    /// Average food quality by weekday × meal. Drinks are left out (they have their own log).
    public static func qualityGrid(_ food: [FoodLog], calendar: Calendar = .current) -> [QualityCell] {
        var sums: [String: (Int, MealSlot, Double, Int)] = [:]
        for f in food where f.category != .drink {
            let wd = calendar.component(.weekday, from: f.date)
            let key = "\(wd)-\(f.meal.rawValue)"
            let cur = sums[key] ?? (wd, f.meal, 0, 0)
            sums[key] = (wd, f.meal, cur.2 + f.healthiness.qualityScore, cur.3 + 1)
        }
        return sums.values.map { QualityCell(weekday: $0.0, slot: $0.1, quality: $0.2 / Double($0.3), count: $0.3) }
    }

    // MARK: Weeks

    public struct WeekPoint: Equatable, Sendable, Identifiable {
        public let start: Date
        public let activeMinutes: Double
        /// Change in smoothed weight over the week (needs a reading near both ends).
        public let weightChangeKg: Double?
        /// Share of meals that were lighter or balanced.
        public let healthyShare: Double?
        public let meals: Int
        public var id: Date { start }
    }

    /// One point per complete calendar week that overlaps `start...end`.
    public static func weeks(
        food: [FoodLog], exercise: [ExerciseLog], weights: [WeightSample],
        from start: Date, to end: Date, calendar: Calendar = .current
    ) -> [WeekPoint] {
        let trend = WeightTrend.compute(weights, calendar: calendar)
        func trendKg(onOrBefore d: Date, within days: Int = 3) -> Double? {
            guard let p = trend.last(where: { $0.day <= d }),
                  (calendar.dateComponents([.day], from: p.day, to: d).day ?? 99) <= days else { return nil }
            return p.trendKg
        }
        guard var week = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { return [] }
        var out: [WeekPoint] = []
        while let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week), next <= calendar.startOfDay(for: end).addingTimeInterval(86_400) {
            let inWeek: (Date) -> Bool = { $0 >= week && $0 < next }
            let meals = food.filter { inWeek($0.date) && $0.category != .drink }
            let minutes = exercise.filter { inWeek($0.date) }.reduce(0) { $0 + $1.minutes }
            var change: Double?
            if let endKg = trendKg(onOrBefore: next.addingTimeInterval(-1)),
               let startKg = trendKg(onOrBefore: week.addingTimeInterval(-1)) {
                change = endKg - startKg
            }
            let healthy: Double? = meals.isEmpty ? nil
                : Double(meals.filter { $0.healthiness != .indulgent }.count) / Double(meals.count)
            out.append(WeekPoint(start: week, activeMinutes: minutes, weightChangeKg: change,
                                 healthyShare: healthy, meals: meals.count))
            week = next
        }
        return out
    }

    // MARK: Caffeine timing

    /// Average caffeine (mg per day with any drink logged) for each hour of the day.
    public static func caffeineByHour(_ drinks: [DrinkLog], calendar: Calendar = .current) -> [Int: Double] {
        let days = Set(drinks.map { calendar.startOfDay(for: $0.date) }).count
        guard days > 0 else { return [:] }
        var totals: [Int: Double] = [:]
        for d in drinks where d.caffeineMg > 0 {
            totals[calendar.component(.hour, from: d.date), default: 0] += d.caffeineMg
        }
        return totals.mapValues { $0 / Double(days) }
    }

    // MARK: Statistics

    /// Pearson correlation; nil with fewer than 4 pairs or no variation.
    public static func correlation(_ xs: [Double], _ ys: [Double]) -> Double? {
        let n = min(xs.count, ys.count)
        guard n >= 4 else { return nil }
        let x = Array(xs.prefix(n)), y = Array(ys.prefix(n))
        let mx = x.reduce(0, +) / Double(n), my = y.reduce(0, +) / Double(n)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in 0..<n {
            sxy += (x[i] - mx) * (y[i] - my)
            sxx += (x[i] - mx) * (x[i] - mx)
            syy += (y[i] - my) * (y[i] - my)
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    /// Plain words for a correlation's strength.
    public static func describe(_ r: Double) -> String {
        switch abs(r) {
        case 0.5...: "strong"
        case 0.3..<0.5: "moderate"
        case 0.1..<0.3: "weak"
        default: "no clear"
        }
    }
}
