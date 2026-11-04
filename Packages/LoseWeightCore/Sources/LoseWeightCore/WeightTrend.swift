import Foundation

public struct WeightSample: Equatable, Sendable {
    public var date: Date
    public var kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public struct TrendPoint: Equatable, Sendable, Identifiable {
    public var day: Date
    /// The scale reading for that day (average if more than one).
    public var scaleKg: Double
    /// The smoothed trend weight.
    public var trendKg: Double

    public var id: Date { day }
}

/// Smooths daily weigh-ins so water and salt swings don't drown out real fat loss.
/// Uses an exponentially weighted moving average (as in "The Hacker's Diet"),
/// adjusted for missed days.
public enum WeightTrend {
    public static let defaultSmoothing = 0.1

    public static func compute(
        _ samples: [WeightSample],
        smoothing alpha: Double = defaultSmoothing,
        calendar: Calendar = .current
    ) -> [TrendPoint] {
        // One reading per day: average any duplicates.
        var byDay: [Date: [Double]] = [:]
        for s in samples where s.kg > 0 {
            byDay[calendar.startOfDay(for: s.date), default: []].append(s.kg)
        }
        let days = byDay.keys.sorted()
        var points: [TrendPoint] = []
        points.reserveCapacity(days.count)
        var trend: Double?
        var lastDay: Date?
        for day in days {
            let values = byDay[day]!
            let scale = values.reduce(0, +) / Double(values.count)
            if let prev = trend, let lastDay {
                let gap = max(1, calendar.dateComponents([.day], from: lastDay, to: day).day ?? 1)
                // Skipped days count as multiple smoothing steps toward the new reading.
                let effective = 1 - pow(1 - alpha, Double(gap))
                trend = prev + effective * (scale - prev)
            } else {
                trend = scale
            }
            points.append(TrendPoint(day: day, scaleKg: scale, trendKg: trend!))
            lastDay = day
        }
        return points
    }

    /// Rate of change in kg per week, from a least-squares fit of the trend line
    /// over the last `windowDays` days. Negative means losing.
    public static func kgPerWeek(
        _ points: [TrendPoint],
        windowDays: Int = 21,
        endingAt end: Date? = nil,
        calendar: Calendar = .current
    ) -> Double? {
        guard let last = end ?? points.last?.day else { return nil }
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: last) else { return nil }
        let window = points.filter { $0.day >= start && $0.day <= last }
        guard window.count >= 3, let first = window.first else { return nil }
        let xs = window.map { $0.day.timeIntervalSince(first.day) / 86_400 }
        guard (xs.last ?? 0) >= 6 else { return nil } // need about a week of spread
        let ys = window.map(\.trendKg)
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for (x, y) in zip(xs, ys) {
            num += (x - meanX) * (y - meanY)
            den += (x - meanX) * (x - meanX)
        }
        guard den > 0 else { return nil }
        return num / den * 7
    }
}

public enum GoalProjection {
    /// When the goal will be reached at the current rate. Nil if not heading toward it.
    public static func projectedDate(
        currentKg: Double,
        goalKg: Double,
        kgPerWeek: Double?,
        from date: Date
    ) -> Date? {
        guard let rate = kgPerWeek else { return nil }
        let remaining = goalKg - currentKg
        if abs(remaining) < 0.1 { return date }
        // Must be moving in the right direction at a meaningful pace.
        guard rate != 0, remaining.sign == rate.sign, abs(rate) >= 0.05 else { return nil }
        let weeks = remaining / rate
        guard weeks.isFinite, weeks < 52 * 5 else { return nil }
        return date.addingTimeInterval(weeks * 7 * 86_400)
    }

    /// Share of the journey from start to goal that's done (0...1).
    public static func progress(startKg: Double, currentKg: Double, goalKg: Double) -> Double {
        let total = startKg - goalKg
        guard abs(total) > 0.01 else { return 1 }
        return min(1, max(0, (startKg - currentKg) / total))
    }
}
