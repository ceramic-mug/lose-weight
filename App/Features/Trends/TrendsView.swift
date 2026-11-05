import SwiftUI
import SwiftData
import Charts
import LoseWeightCore

enum TrendRange: String, CaseIterable, Identifiable {
    case week, month, quarter, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .quarter: "3 Months"
        case .year: "Year"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 91
        case .year: 365
        }
    }

    /// Short ranges show days; long ones group by week so bars stay readable.
    var bucket: Calendar.Component { days <= 31 ? .day : .weekOfYear }

    var start: Date {
        Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
    }
}

struct TrendsView: View {
    let profile: UserProfile

    @Query(sort: \FoodEntry.timestamp) private var foods: [FoodEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]
    @State private var range: TrendRange = .month
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// One column on iPhone, two on iPad and Mac.
    private var columns: [GridItem] {
        #if os(iOS)
        let count = sizeClass == .regular ? 2 : 1
        #else
        let count = 2
        #endif
        return Array(repeating: GridItem(.flexible(), spacing: Theme.spacing, alignment: .top), count: count)
    }

    var body: some View {
        let snap = Snapshot(profile: profile, weights: weights)
        let start = range.start
        let rangeFoods = foods.filter { $0.timestamp >= start }
        let rangeExercise = exercises.filter { $0.timestamp >= start }

        ScrollView {
            VStack(spacing: Theme.spacing) {
                Picker("Range", selection: $range) {
                    ForEach(TrendRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                LazyVGrid(columns: columns, spacing: Theme.spacing) {
                    WeightTrendChart(snapshot: snap, range: range)
                    EatingQualityChart(foods: rangeFoods, range: range)
                    BudgetChart(foods: rangeFoods, exercises: rangeExercise, snapshot: snap, range: range)
                    CategoryMixChart(foods: rangeFoods)
                    ActiveMinutesChart(exercises: exercises, range: range)
                    ActivityHeatmap(exercises: exercises)
                }
            }
            .padding()
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Trends")
        .toolbar { ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .trend) } }
    }
}

// MARK: - Weight

struct WeightTrendChart: View {
    let snapshot: Snapshot
    let range: TrendRange
    @State private var selected: Date?

    var body: some View {
        let units = snapshot.units
        let points = snapshot.trend.filter { $0.day >= range.start }
        let goal = units.displayWeight(fromKg: snapshot.profile.goalWeightKg)
        let values = points.flatMap { [units.displayWeight(fromKg: $0.scaleKg), units.displayWeight(fromKg: $0.trendKg)] }
        let lo = min(values.min() ?? goal, goal) - 1
        let hi = (values.max() ?? goal) + 1
        let selectedPoint = selected.flatMap { d in points.min { abs($0.day.timeIntervalSince(d)) < abs($1.day.timeIntervalSince(d)) } }

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Weight", systemImage: "scalemass", tint: Theme.weight,
                       trailing: snapshot.kgPerWeek.map { "\(units.formatWeightChange($0))/wk" })
            if points.count < 2 {
                EmptyHint(text: "Not enough weigh-ins yet", systemImage: "scalemass")
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(points) { p in
                        PointMark(x: .value("Day", p.day, unit: .day),
                                  y: .value("Scale", units.displayWeight(fromKg: p.scaleKg)))
                            .symbolSize(30)
                            .foregroundStyle(Theme.weight.opacity(0.35))
                        LineMark(x: .value("Day", p.day, unit: .day),
                                 y: .value("Trend", units.displayWeight(fromKg: p.trendKg)),
                                 series: .value("Series", "Trend"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(Theme.weight)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    if let p = selectedPoint {
                        RuleMark(x: .value("Day", p.day, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                ChartTooltip(title: p.day.formatted(.dateTime.month().day()), lines: [
                                    "Scale \(units.formatWeight(p.scaleKg))",
                                    "Trend \(units.formatWeight(p.trendKg))",
                                ])
                            }
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartXSelection(value: $selected)
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.2)); AxisValueLabel() } }
                .frame(height: 220)

                HStack(spacing: 16) {
                    LegendSwatch(label: "Scale", color: Theme.weight.opacity(0.35), shape: .dot)
                    LegendSwatch(label: "Trend", color: Theme.weight, shape: .line)
                    Spacer()
                    if let date = snapshot.projectedGoalDate {
                        Text("Goal ≈ \(date.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Eating quality

struct TierBucket: Identifiable {
    let start: Date
    let tier: Healthiness
    let count: Int
    var id: String { "\(start.timeIntervalSince1970)-\(tier.rawValue)" }
}

struct EatingQualityChart: View {
    let foods: [FoodEntry]
    let range: TrendRange

    var body: some View {
        let buckets = Self.buckets(foods, by: range.bucket)
        let healthy = foods.filter { $0.healthiness != .indulgent }.count
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Food choices", systemImage: "leaf", tint: Theme.lighter,
                       trailing: foods.isEmpty ? nil : "\(Format.percent(Double(healthy) / Double(foods.count))) healthy")
            if foods.isEmpty {
                EmptyHint(text: "No meals yet").frame(height: 180)
            } else {
                Chart(buckets) { b in
                    BarMark(x: .value("Date", b.start, unit: range.bucket),
                            y: .value("Items", b.count))
                        .foregroundStyle(by: .value("Healthiness", b.tier.displayName))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .chartForegroundStyleScale(
                    domain: Healthiness.allCases.map(\.displayName),
                    range: Healthiness.allCases.map(\.color)
                )
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.2)); AxisValueLabel() } }
                .frame(height: 200)
            }
        }
        .card()
    }

    static func buckets(_ foods: [FoodEntry], by component: Calendar.Component) -> [TierBucket] {
        let cal = Calendar.current
        var counts: [Date: [Healthiness: Int]] = [:]
        for f in foods {
            let start = cal.dateInterval(of: component, for: f.timestamp)?.start ?? cal.startOfDay(for: f.timestamp)
            counts[start, default: [:]][f.healthiness, default: 0] += 1
        }
        return counts.keys.sorted().flatMap { day in
            Healthiness.allCases.compactMap { tier in
                counts[day]?[tier].map { TierBucket(start: day, tier: tier, count: $0) }
            }
        }
    }
}

// MARK: - Budget adherence

struct BudgetChart: View {
    let foods: [FoodEntry]
    let exercises: [ExerciseEntry]
    let snapshot: Snapshot
    let range: TrendRange

    struct Day: Identifiable {
        let day: Date
        let fraction: Double
        var id: Date { day }
    }

    var body: some View {
        let cal = Calendar.current
        let days = Set(foods.map { cal.startOfDay(for: $0.timestamp) }).sorted()
        let data = days.map { d in
            Day(day: d, fraction: snapshot.dayBudget(foods: foods, exercises: exercises, on: d).fraction)
        }
        let onTrack = data.filter { $0.fraction <= 1.1 }.count

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Budget", systemImage: "chart.bar", tint: Theme.food,
                       trailing: data.isEmpty ? nil : "\(onTrack)/\(data.count) days")
            if data.isEmpty {
                EmptyHint(text: "No meals yet").frame(height: 180)
            } else {
                Chart {
                    ForEach(data) { d in
                        BarMark(x: .value("Day", d.day, unit: .day), y: .value("Budget used", d.fraction))
                            .foregroundStyle(d.fraction > 1.1 ? Theme.indulgent : Theme.food)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    RuleMark(y: .value("Budget", 1.0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1, 1.5]) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel { if let x = v.as(Double.self) { Text(Format.percent(x)) } }
                    }
                }
                .frame(height: 200)
                HStack(spacing: 16) {
                    LegendSwatch(label: "On budget", color: Theme.food, shape: .square)
                    LegendSwatch(label: "Over", color: Theme.indulgent, shape: .square)
                }
            }
        }
        .card()
    }
}

// MARK: - Category mix

struct CategoryMixChart: View {
    let foods: [FoodEntry]

    struct Row: Identifiable {
        let category: FoodCategory
        let tier: Healthiness
        let count: Int
        var id: String { category.rawValue + tier.rawValue }
    }

    var body: some View {
        var counts: [FoodCategory: [Healthiness: Int]] = [:]
        for f in foods { counts[f.category, default: [:]][f.healthiness, default: 0] += 1 }
        let order = FoodCategory.allCases.filter { counts[$0] != nil }
            .sorted { (counts[$0]?.values.reduce(0, +) ?? 0) > (counts[$1]?.values.reduce(0, +) ?? 0) }
        let rows = order.flatMap { c in
            Healthiness.allCases.compactMap { t in counts[c]?[t].map { Row(category: c, tier: t, count: $0) } }
        }

        return VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Food sources", systemImage: "fork.knife", tint: Theme.food)
            if rows.isEmpty {
                EmptyHint(text: "No meals yet").frame(height: 160)
            } else {
                Chart(rows) { r in
                    BarMark(x: .value("Items", r.count), y: .value("Category", r.category.displayName))
                        .foregroundStyle(by: .value("Healthiness", r.tier.displayName))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .chartForegroundStyleScale(
                    domain: Healthiness.allCases.map(\.displayName),
                    range: Healthiness.allCases.map(\.color)
                )
                .chartYScale(domain: order.map(\.displayName))
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: CGFloat(max(order.count, 2)) * 34 + 40)
            }
        }
        .card()
    }
}

// MARK: - Active minutes

struct ActiveMinutesChart: View {
    let exercises: [ExerciseEntry]
    let range: TrendRange
    @State private var selected: Date?

    struct Week: Identifiable {
        let start: Date
        let minutes: Double
        var id: Date { start }
    }

    var body: some View {
        let cal = Calendar.current
        let weeksShown = max(4, range.days / 7)
        let thisWeek = cal.weekInterval(containing: .now).start
        let weeks: [Week] = (0..<weeksShown).reversed().compactMap { i in
            guard let start = cal.date(byAdding: .weekOfYear, value: -i, to: thisWeek),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let mins = exercises.filter { $0.timestamp >= start && $0.timestamp < end }.reduce(0) { $0 + $1.minutes }
            return Week(start: start, minutes: mins)
        }
        let goal = EnergyConstants.weeklyActiveMinutesGoal
        let met = weeks.filter { $0.minutes >= goal }.count
        let selectedWeek = selected.flatMap { d in weeks.last { $0.start <= d } }

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Active minutes", systemImage: "figure.run", tint: Theme.exercise,
                       trailing: "\(met)/\(weeks.count) wks at 150")
            Chart {
                ForEach(weeks) { w in
                    BarMark(x: .value("Week", w.start, unit: .weekOfYear), y: .value("Minutes", w.minutes))
                        .foregroundStyle(Theme.exercise.opacity(selectedWeek == nil || selectedWeek?.start == w.start ? 1 : 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                RuleMark(y: .value("Guideline", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("150").font(.caption2).foregroundStyle(.secondary)
                    }
                if let w = selectedWeek {
                    RuleMark(x: .value("Week", w.start, unit: .weekOfYear))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            ChartTooltip(title: "Week of \(w.start.formatted(.dateTime.month().day()))",
                                         lines: ["\(Int(w.minutes)) min"])
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.secondary.opacity(0.2)); AxisValueLabel() } }
            .frame(height: 200)
        }
        .card()
    }
}

// MARK: - Heatmap

struct ActivityHeatmap: View {
    let exercises: [ExerciseEntry]
    private let weeks = 16

    struct Cell: Identifiable {
        let day: Date
        let week: Int
        let weekday: Int
        let minutes: Double
        var id: Date { day }
    }

    var body: some View {
        let cal = Calendar.current
        let thisWeek = cal.weekInterval(containing: .now).start
        let first = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)!
        var minutesByDay: [Date: Double] = [:]
        for e in exercises where e.timestamp >= first {
            minutesByDay[cal.startOfDay(for: e.timestamp), default: 0] += e.minutes
        }
        let today = cal.startOfDay(for: .now)
        let cells: [Cell] = (0..<(weeks * 7)).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: first), d <= today else { return nil }
            return Cell(day: d, week: i / 7, weekday: i % 7, minutes: minutesByDay[d] ?? 0)
        }
        let activeDays = cells.filter { $0.minutes > 0 }.count

        return VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Activity", systemImage: "calendar", tint: Theme.exercise,
                       trailing: "\(activeDays) days")
            GeometryReader { geo in
                let gap: CGFloat = 3
                let size = min(22, (geo.size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks))
                HStack(alignment: .top, spacing: gap) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { wd in
                                let cell = cells.first { $0.week == w && $0.weekday == wd }
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(color(for: cell?.minutes, exists: cell != nil))
                                    .frame(width: size, height: size)
                                    .help(cell.map { "\($0.day.formatted(.dateTime.month().day())): \(Format.minutes($0.minutes))" } ?? "")
                            }
                        }
                    }
                }
            }
            .frame(height: 7 * 22 + 6 * 3)
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 15, 30, 60], id: \.self) { m in
                    RoundedRectangle(cornerRadius: 3).fill(color(for: m, exists: true)).frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    /// Single-hue sequential scale: more minutes, deeper orange.
    private func color(for minutes: Double?, exists: Bool) -> Color {
        guard exists else { return .clear }
        guard let minutes, minutes > 0 else { return Theme.subtleFill }
        switch minutes {
        case ..<15: return Theme.exercise.opacity(0.3)
        case ..<30: return Theme.exercise.opacity(0.55)
        case ..<60: return Theme.exercise.opacity(0.8)
        default: return Theme.exercise
        }
    }
}

// MARK: - Chart helpers

struct ChartTooltip: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold))
            ForEach(lines, id: \.self) { Text($0).font(.caption).monospacedDigit() }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LegendSwatch: View {
    enum Shape { case dot, line, square }
    let label: String
    let color: Color
    let shape: Shape

    var body: some View {
        HStack(spacing: 6) {
            switch shape {
            case .dot: Circle().fill(color).frame(width: 8, height: 8)
            case .line: Capsule().fill(color).frame(width: 14, height: 3)
            case .square: RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { TrendsView(profile: profile) }
    }
}
