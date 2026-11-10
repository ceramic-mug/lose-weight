import SwiftUI
import SwiftData
import Charts
import LoseWeightCore

/// Mac-first analysis: bigger charts, more history, and a plain-language takeaway on each.
/// The phone keeps Today / Trends for quick glances; this is where you dig in.
struct AnalysisView: View {
    let profile: UserProfile

    enum Range: String, CaseIterable, Identifiable {
        case month, quarter, year, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .month: "30 days"
            case .quarter: "90 days"
            case .year: "Year"
            case .all: "All time"
            }
        }
        var days: Int? {
            switch self {
            case .month: 30
            case .quarter: 90
            case .year: 365
            case .all: nil
            }
        }
    }

    @Query(sort: \FoodEntry.timestamp) private var foods: [FoodEntry]
    @Query(sort: \DrinkEntry.timestamp) private var drinks: [DrinkEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]
    @AppStorage("analysisRange") private var rangeRaw = Range.quarter.rawValue

    private var range: Range { Range(rawValue: rangeRaw) ?? .quarter }

    var body: some View {
        let cal = Calendar.current
        let earliest = [foods.first?.timestamp, drinks.first?.timestamp, exercises.first?.timestamp, weights.first?.timestamp]
            .compactMap { $0 }.min() ?? .now
        let start = range.days.flatMap { cal.date(byAdding: .day, value: -($0 - 1), to: cal.startOfDay(for: .now)) }
            ?? cal.startOfDay(for: earliest)
        let data = AnalysisData(
            profile: profile, start: start,
            foods: foods.filter { $0.timestamp >= start },
            drinks: drinks.filter { $0.timestamp >= start },
            exercises: exercises.filter { $0.timestamp >= start },
            allWeights: weights
        )
        let pair = [GridItem(.flexible(), spacing: 20, alignment: .top), GridItem(.flexible(), spacing: 20, alignment: .top)]

        ScrollView {
            VStack(spacing: 20) {
                StatStrip(data: data)
                WeightAnalysisCard(data: data)
                ConsistencyCard(data: data)
                LazyVGrid(columns: pair, spacing: 20) {
                    QualityGridCard(data: data)
                    CalorieSourcesCard(data: data)
                    ActivityVsWeightCard(data: data)
                    HealthyShareCard(data: data)
                    CaffeineTimingCard(data: data)
                    ExerciseMixCard(data: data)
                }
            }
            .padding(24)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Analysis")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Range", selection: $rangeRaw) {
                    ForEach(Range.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Shared data

/// Everything the cards need, derived once per render.
struct AnalysisData {
    let profile: UserProfile
    let start: Date
    let foods: [FoodEntry]
    let drinks: [DrinkEntry]
    let exercises: [ExerciseEntry]
    let snapshot: Snapshot
    let trendInRange: [TrendPoint]
    let weeks: [Analysis.WeekPoint]
    let days: Int

    init(profile: UserProfile, start: Date, foods: [FoodEntry], drinks: [DrinkEntry], exercises: [ExerciseEntry], allWeights: [WeightEntry]) {
        self.profile = profile
        self.start = start
        self.foods = foods
        self.drinks = drinks
        self.exercises = exercises
        let snap = Snapshot(profile: profile, weights: allWeights)
        snapshot = snap
        trendInRange = snap.trend.filter { $0.day >= start }
        weeks = Analysis.weeks(food: foods.map(\.log), exercise: exercises.map(\.log),
                               weights: allWeights.map(\.sample), from: start, to: .now)
        days = max(1, (Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0) + 1)
    }

    var units: UnitSystem { profile.units }

    /// Budget used on each day with food logged.
    var dailyBudget: [Date: DayBudget] {
        let cal = Calendar.current
        let days = Set(foods.map { cal.startOfDay(for: $0.timestamp) })
        var out: [Date: DayBudget] = [:]
        for d in days { out[d] = snapshot.dayBudget(foods: foods, drinks: drinks, exercises: exercises, on: d) }
        return out
    }
}

/// Card with a title, a one-line takeaway, then the chart.
struct AnalysisCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let takeaway: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            if let takeaway {
                Text(takeaway)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
                .padding(.top, 6)
        }
        .card(padding: 20)
    }
}

private func gridAxis() -> some AxisContent {
    AxisMarks(position: .leading) { _ in
        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
        AxisValueLabel()
    }
}

// MARK: - Stat strip

struct StatStrip: View {
    let data: AnalysisData

    var body: some View {
        let units = data.units
        let first = data.trendInRange.first?.trendKg
        let last = data.trendInRange.last?.trendKg
        let budgets = Array(data.dailyBudget.values)
        let avgBudget = budgets.isEmpty ? nil : budgets.map(\.fraction).reduce(0, +) / Double(budgets.count)
        let minutes = data.exercises.reduce(0) { $0 + $1.minutes }
        let perWeek = data.days > 7 ? minutes / Double(data.days) * 7 : minutes
        let meals = data.foods.filter { $0.category != .drink }
        let healthy = meals.isEmpty ? nil : Double(meals.filter { $0.healthiness != .indulgent }.count) / Double(meals.count)
        let drinkDays = Set(data.drinks.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let caffeine = drinkDays == 0 ? nil : data.drinks.reduce(0) { $0 + $1.caffeineMg } / Double(drinkDays)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
            StatTile(title: "Weight (trend)", value: last.map { units.formatWeight($0) } ?? "—",
                     caption: (first != nil && last != nil) ? "\(units.formatWeightChange(last! - first!)) in range" : nil,
                     systemImage: "scalemass", tint: Theme.weight)
            StatTile(title: "Food budget", value: avgBudget.map(Format.percent) ?? "—",
                     caption: "average day used", systemImage: "fork.knife", tint: Theme.food)
            StatTile(title: "Active", value: "\(Int(perWeek.rounded())) min",
                     caption: "per week · goal 150", systemImage: "figure.run", tint: Theme.exercise)
            StatTile(title: "Healthy choices", value: healthy.map(Format.percent) ?? "—",
                     caption: "\(meals.count) meals", systemImage: "leaf", tint: Theme.lighter)
            StatTile(title: "Caffeine", value: caffeine.map { "\(Int($0.rounded())) mg" } ?? "—",
                     caption: "a day · limit 400", systemImage: "cup.and.saucer.fill", tint: Theme.drink)
        }
    }
}

// MARK: - Weight

struct WeightAnalysisCard: View {
    let data: AnalysisData
    @State private var hovered: TrendPoint?

    var body: some View {
        let units = data.units
        let points = data.trendInRange
        let goal = data.profile.goalWeightKg
        let snap = data.snapshot
        let projection: Date? = {
            guard let last = points.last, let date = snap.projectedGoalDate,
                  date.timeIntervalSince(last.day) < 400 * 86_400 else { return nil }
            return date
        }()
        let values = points.flatMap { [$0.scaleKg, $0.trendKg] } + [goal]
        let lo = units.displayWeight(fromKg: values.min() ?? goal) - 1
        let hi = units.displayWeight(fromKg: values.max() ?? goal) + 1

        AnalysisCard(title: "Weight", systemImage: "scalemass", tint: Theme.weight, takeaway: takeaway(points: points)) {
            if points.count < 2 {
                EmptyHint(text: "A few weigh-ins will draw your trend here.").frame(height: 300)
            } else {
                Chart {
                    ForEach(points) { p in
                        PointMark(x: .value("Day", p.day, unit: .day), y: .value("Scale", units.displayWeight(fromKg: p.scaleKg)))
                            .symbolSize(28)
                            .foregroundStyle(Theme.weight.opacity(0.3))
                        LineMark(x: .value("Day", p.day, unit: .day), y: .value("Weight", units.displayWeight(fromKg: p.trendKg)),
                                 series: .value("Series", "Trend"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(Theme.weight)
                    }
                    if let date = projection, let last = points.last {
                        let kg = goal
                        LineMark(x: .value("Day", last.day, unit: .day), y: .value("Weight", units.displayWeight(fromKg: last.trendKg)),
                                 series: .value("Series", "Projection"))
                            .foregroundStyle(Theme.weight.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        LineMark(x: .value("Day", date, unit: .day), y: .value("Weight", units.displayWeight(fromKg: kg)),
                                 series: .value("Series", "Projection"))
                            .foregroundStyle(Theme.weight.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        PointMark(x: .value("Day", date, unit: .day), y: .value("Weight", units.displayWeight(fromKg: kg)))
                            .symbol(.circle)
                            .foregroundStyle(Theme.weight)
                            .annotation(position: .top) {
                                Text(date.formatted(.dateTime.month(.abbreviated).year()))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                    RuleMark(y: .value("Goal", units.displayWeight(fromKg: goal)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal \(units.formatWeight(goal, decimals: 0))").font(.caption2).foregroundStyle(.secondary)
                        }
                    if let h = hovered {
                        RuleMark(x: .value("Day", h.day, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.35))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                ChartTooltip(title: h.day.formatted(.dateTime.weekday(.abbreviated).month().day()),
                                             lines: ["Scale \(units.formatWeight(h.scaleKg))", "Trend \(units.formatWeight(h.trendKg))"])
                            }
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartYAxis { gridAxis() }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let frame = proxy.plotFrame else { return }
                                    let x = location.x - geo[frame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        hovered = points.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) }
                                    }
                                case .ended:
                                    hovered = nil
                                }
                            }
                    }
                }
                .frame(height: 300)
                HStack(spacing: 18) {
                    LegendSwatch(label: "Daily weigh-in", color: Theme.weight.opacity(0.3), shape: .dot)
                    LegendSwatch(label: "Trend", color: Theme.weight, shape: .line)
                    if projection != nil { LegendSwatch(label: "Projection at current pace", color: Theme.weight.opacity(0.6), shape: .line) }
                }
            }
        }
    }

    private func takeaway(points: [TrendPoint]) -> String? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let units = data.units
        let change = last.trendKg - first.trendKg
        var parts = ["\(units.formatWeightChange(change)) since \(first.day.formatted(.dateTime.month(.abbreviated).day()))"]
        if let rate = data.snapshot.kgPerWeek { parts.append("\(units.formatWeightChange(rate)) a week lately") }
        if let date = data.snapshot.projectedGoalDate {
            parts.append("goal around \(date.formatted(.dateTime.month(.wide).year()))")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Consistency calendar

struct ConsistencyCard: View {
    let data: AnalysisData

    enum Status { case none, under, onTrack, over }

    var body: some View {
        let cal = Calendar.current
        let budgets = data.dailyBudget
        let weeksShown = min(53, max(5, Int((Double(data.days) / 7).rounded(.up))))
        let thisWeek = cal.weekInterval(containing: .now).start
        let first = cal.date(byAdding: .weekOfYear, value: -(weeksShown - 1), to: thisWeek)!
        let today = cal.startOfDay(for: .now)
        let logged = budgets.count
        let onTrack = budgets.values.filter { $0.status != .over }.count
        let overByWeekday = Dictionary(grouping: budgets.filter { $0.value.status == .over }.keys) { cal.component(.weekday, from: $0) }
        let worstDay = overByWeekday.max { $0.value.count < $1.value.count }
        let symbols = cal.shortWeekdaySymbols
        var takeaway: String? = nil
        if logged > 0 {
            takeaway = "Within budget on \(onTrack) of \(logged) logged days (\(Format.percent(Double(onTrack) / Double(logged))))."
            if let worst = worstDay, worst.value.count >= 2 {
                takeaway! += " Most overs fall on \(cal.weekdaySymbols[worst.key - 1])s."
            }
        }

        return AnalysisCard(title: "Consistency", systemImage: "calendar", tint: Theme.food, takeaway: takeaway) {
            GeometryReader { geo in
                let gap: CGFloat = 4
                let labelWidth: CGFloat = 34
                let size = min(26, (geo.size.width - labelWidth - gap * CGFloat(weeksShown - 1)) / CGFloat(weeksShown))
                HStack(alignment: .top, spacing: gap) {
                    VStack(alignment: .trailing, spacing: gap) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(i % 2 == 1 ? symbols[(cal.firstWeekday - 1 + i) % 7] : "")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(width: labelWidth - 6, height: size, alignment: .trailing)
                        }
                    }
                    ForEach(0..<weeksShown, id: \.self) { w in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { i in
                                let day = cal.date(byAdding: .day, value: w * 7 + i, to: first)!
                                let budget = budgets[day]
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(day > today ? Color.clear : color(status(budget)))
                                    .frame(width: size, height: size)
                                    .help(day > today ? "" : tooltip(day, budget))
                            }
                        }
                    }
                }
            }
            .frame(height: 7 * 26 + 6 * 4)
            HStack(spacing: 18) {
                LegendSwatch(label: "Under budget", color: color(.under), shape: .square)
                LegendSwatch(label: "On track (±10%)", color: color(.onTrack), shape: .square)
                LegendSwatch(label: "Over", color: color(.over), shape: .square)
                LegendSwatch(label: "Not logged", color: color(.none), shape: .square)
            }
        }
    }

    private func status(_ b: DayBudget?) -> Status {
        guard let b else { return .none }
        switch b.status {
        case .under: return .under
        case .onTrack: return .onTrack
        case .over: return .over
        }
    }

    private func color(_ s: Status) -> Color {
        switch s {
        case .none: Theme.subtleFill
        case .under: Theme.food.opacity(0.45)
        case .onTrack: Theme.lighter
        case .over: Theme.indulgent
        }
    }

    private func tooltip(_ day: Date, _ b: DayBudget?) -> String {
        let d = day.formatted(.dateTime.weekday(.abbreviated).month().day())
        guard let b else { return "\(d): nothing logged" }
        return "\(d): \(Format.percent(b.fraction)) of budget"
    }
}

// MARK: - When you eat best

struct QualityGridCard: View {
    let data: AnalysisData

    var body: some View {
        let cal = Calendar.current
        let cells = Analysis.qualityGrid(data.foods.map(\.log))
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        let names = order.map { cal.shortWeekdaySymbols[$0 - 1] }
        let slots = MealSlot.allCases.map(\.displayName)
        let ranked = cells.filter { $0.count >= 2 }.sorted { $0.quality > $1.quality }
        var takeaway: String? = nil
        if let best = ranked.first, let worst = ranked.last, ranked.count >= 3 {
            takeaway = "Healthiest: \(cal.weekdaySymbols[best.weekday - 1]) \(best.slot.displayName.lowercased()). Hardest: \(cal.weekdaySymbols[worst.weekday - 1]) \(worst.slot.displayName.lowercased())."
        }

        return AnalysisCard(title: "When you eat best", systemImage: "square.grid.3x3.fill", tint: Theme.lighter, takeaway: takeaway) {
            if cells.isEmpty {
                EmptyHint(text: "Log meals to see your patterns by day and meal.").frame(height: 220)
            } else {
                Chart(cells) { c in
                    RectangleMark(x: .value("Day", cal.shortWeekdaySymbols[c.weekday - 1]),
                                  y: .value("Meal", c.slot.displayName))
                        .foregroundStyle(by: .value("Quality", c.quality))
                        .cornerRadius(5)
                        .annotation(position: .overlay) {
                            Text("\(c.count)").font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                        }
                }
                .chartForegroundStyleScale(range: Gradient(colors: [Theme.indulgent, Color.gray.opacity(0.55), Theme.lighter]))
                .chartXScale(domain: names)
                .chartYScale(domain: slots)
                .chartLegend(.hidden)
                .frame(height: 220)
                HStack(spacing: 8) {
                    Text("More indulgent").font(.caption).foregroundStyle(.secondary)
                    LinearGradient(colors: [Theme.indulgent, Color.gray.opacity(0.55), Theme.lighter], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 120, height: 8).clipShape(Capsule())
                    Text("Lighter").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Numbers are meals logged").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Where calories come from

struct CalorieSourcesCard: View {
    let data: AnalysisData

    struct Row: Identifiable {
        let name: String
        let kcal: Double
        var id: String { name }
    }

    var body: some View {
        var totals: [String: Double] = [:]
        for f in data.foods { totals[f.category.displayName, default: 0] += f.calories.mid }
        let drinkKcal = data.drinks.reduce(0) { $0 + $1.kcal }
        if drinkKcal > 0 { totals["Drinks", default: 0] += drinkKcal }
        let sum = totals.values.reduce(0, +)
        let rows = totals.map { Row(name: $0.key, kcal: $0.value) }.sorted { $0.kcal > $1.kcal }
        let out = (totals[FoodCategory.fastFood.displayName] ?? 0) + (totals[FoodCategory.restaurant.displayName] ?? 0)
        let takeaway: String? = sum > 0
            ? "Fast food and restaurants: \(Format.percent(out / sum)) of calories. \(rows.first.map { "Biggest source: \($0.name.lowercased())." } ?? "")"
            : nil

        return AnalysisCard(title: "Where calories come from", systemImage: "chart.bar.fill", tint: Theme.food, takeaway: takeaway) {
            if rows.isEmpty {
                EmptyHint(text: "Log meals to see where your calories come from.").frame(height: 220)
            } else {
                Chart(rows) { r in
                    BarMark(x: .value("Share", r.kcal / sum), y: .value("Source", r.name))
                        .foregroundStyle(r.name == "Drinks" ? Theme.drink : Theme.food)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .annotation(position: .trailing) {
                            Text(Format.percent(r.kcal / sum)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: rows.map(\.name))
                .frame(height: max(160, CGFloat(rows.count) * 30))
            }
        }
    }
}

// MARK: - Moving more vs weight

struct ActivityVsWeightCard: View {
    let data: AnalysisData

    struct ScatterPoint: Identifiable {
        let week: Date
        let minutes: Double
        let change: Double
        var id: Date { week }
    }

    var body: some View {
        let units = data.units
        let pts = data.weeks.compactMap { w in
            w.weightChangeKg.map { ScatterPoint(week: w.start, minutes: w.activeMinutes, change: units.displayWeight(fromKg: $0)) }
        }
        let goal = EnergyConstants.weeklyActiveMinutesGoal
        let active = pts.filter { $0.minutes >= goal }.map(\.change)
        let less = pts.filter { $0.minutes < goal }.map(\.change)
        let avg: ([Double]) -> Double = { $0.reduce(0, +) / Double($0.count) }
        var takeaway: String? = pts.count < 4 ? "A few more weeks of weigh-ins will show how activity and weight move together." : nil
        if active.count >= 2, less.count >= 2 {
            takeaway = "Weeks with 150+ active minutes: \(signed(avg(active), units)) on average, vs \(signed(avg(less), units)) in other weeks."
        } else if let r = Analysis.correlation(pts.map(\.minutes), pts.map(\.change)) {
            takeaway = "So far there's a \(Analysis.describe(r)) link between active minutes and weekly weight change."
        }

        return AnalysisCard(title: "Moving more vs. weight change", systemImage: "figure.run", tint: Theme.exercise, takeaway: takeaway) {
            if pts.isEmpty {
                EmptyHint(text: "Needs both workouts and weigh-ins across several weeks.").frame(height: 220)
            } else {
                Chart {
                    RuleMark(y: .value("No change", 0)).foregroundStyle(.secondary.opacity(0.5))
                    RuleMark(x: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) { Text("150 min").font(.caption2).foregroundStyle(.secondary) }
                    ForEach(pts) { p in
                        PointMark(x: .value("Active minutes", p.minutes), y: .value("Weight change", p.change))
                            .symbolSize(70)
                            .foregroundStyle(Theme.exercise)
                    }
                }
                .chartXAxisLabel("Active minutes in the week")
                .chartYAxisLabel("Weekly change (\(units.weightSymbol))")
                .chartYAxis { gridAxis() }
                .frame(height: 220)
            }
        }
    }

    private func signed(_ display: Double, _ units: UnitSystem) -> String {
        let mag = abs(display).formatted(.number.precision(.fractionLength(1)))
        return "\(display < -0.05 ? "−" : (display > 0.05 ? "+" : ""))\(mag) \(units.weightSymbol)"
    }
}

// MARK: - Healthy share by week

struct HealthyShareCard: View {
    let data: AnalysisData

    struct SharePoint: Identifiable {
        let week: Date
        let share: Double
        var id: Date { week }
    }

    var body: some View {
        let pts = data.weeks.filter { $0.meals >= 3 }.compactMap { w in w.healthyShare.map { SharePoint(week: w.start, share: $0) } }
        var takeaway: String? = nil
        if pts.count >= 4 {
            let half = pts.count / 2
            let early = pts.prefix(half).map(\.share).reduce(0, +) / Double(half)
            let late = pts.suffix(pts.count - half).map(\.share).reduce(0, +) / Double(pts.count - half)
            let diff = late - early
            takeaway = abs(diff) < 0.05
                ? "Steady at about \(Format.percent(late)) lighter or balanced."
                : "\(diff > 0 ? "Up" : "Down") from \(Format.percent(early)) to \(Format.percent(late)) lighter or balanced."
        }

        return AnalysisCard(title: "Healthy choices by week", systemImage: "leaf.fill", tint: Theme.lighter, takeaway: takeaway) {
            if pts.count < 2 {
                EmptyHint(text: "A couple of weeks of meals will show the direction.").frame(height: 220)
            } else {
                Chart {
                    ForEach(pts) { p in
                        AreaMark(x: .value("Week", p.week, unit: .weekOfYear), y: .value("Share", p.share))
                            .foregroundStyle(Theme.lighter.opacity(0.12))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Week", p.week, unit: .weekOfYear), y: .value("Share", p.share))
                            .foregroundStyle(Theme.lighter)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Week", p.week, unit: .weekOfYear), y: .value("Share", p.share))
                            .foregroundStyle(Theme.lighter)
                            .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1]) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel { if let x = v.as(Double.self) { Text(Format.percent(x)) } }
                    }
                }
                .frame(height: 220)
            }
        }
    }
}

// MARK: - Caffeine timing

struct CaffeineTimingCard: View {
    let data: AnalysisData

    var body: some View {
        let byHour = Analysis.caffeineByHour(data.drinks.map(\.log))
        let total = byHour.values.reduce(0, +)
        let late = byHour.filter { $0.key >= DrinkMath.lateCaffeineHour }.values.reduce(0, +)
        let peak = byHour.max { $0.value < $1.value }?.key
        var takeaway: String? = nil
        if total > 0 {
            takeaway = "\(Format.percent(late / total)) of your caffeine comes after 2 pm."
            if let peak { takeaway! += " Peak: around \(hourLabel(peak))." }
        }

        return AnalysisCard(title: "Caffeine by time of day", systemImage: "clock", tint: Theme.drink, takeaway: takeaway) {
            if byHour.isEmpty {
                EmptyHint(text: "Log coffee or tea to see when your caffeine lands.").frame(height: 220)
            } else {
                Chart {
                    ForEach(byHour.keys.sorted(), id: \.self) { hour in
                        BarMark(x: .value("Hour", Double(hour)), y: .value("mg", byHour[hour] ?? 0), width: .fixed(14))
                            .foregroundStyle(hour >= DrinkMath.lateCaffeineHour ? Theme.balanced : Theme.drink)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    RuleMark(x: .value("2 pm", Double(DrinkMath.lateCaffeineHour) - 0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) { Text("2 pm").font(.caption2).foregroundStyle(.secondary) }
                }
                .chartXScale(domain: 4.0...24.0)
                .chartXAxis {
                    AxisMarks(values: [6.0, 9.0, 12.0, 15.0, 18.0, 21.0]) { v in
                        AxisValueLabel { if let h = v.as(Double.self) { Text(hourLabel(Int(h))) } }
                    }
                }
                .chartYAxis { gridAxis() }
                .chartYAxisLabel("mg on an average day")
                .frame(height: 220)
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let hour = h % 24
        let suffix = hour < 12 ? "am" : "pm"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve) \(suffix)"
    }
}

// MARK: - Exercise mix

struct ExerciseMixCard: View {
    let data: AnalysisData

    struct Row: Identifiable {
        let type: ExerciseType
        let minutes: Double
        var id: String { type.rawValue }
    }

    var body: some View {
        var totals: [ExerciseType: Double] = [:]
        for e in data.exercises { totals[e.type, default: 0] += e.minutes }
        let rows = totals.map { Row(type: $0.key, minutes: $0.value) }.sorted { $0.minutes > $1.minutes }
        let sum = rows.reduce(0) { $0 + $1.minutes }
        let strength = totals[.strength] ?? 0
        var takeaway: String? = nil
        if let top = rows.first, sum > 0 {
            takeaway = "\(top.type.displayName) is \(Format.percent(top.minutes / sum)) of your active time."
            if strength == 0 { takeaway! += " No strength work yet — twice a week is the guideline." }
        }

        return AnalysisCard(title: "How you move", systemImage: "figure.mixed.cardio", tint: Theme.exercise, takeaway: takeaway) {
            if rows.isEmpty {
                EmptyHint(text: "Log workouts to see your mix.").frame(height: 220)
            } else {
                Chart(rows) { r in
                    BarMark(x: .value("Minutes", r.minutes), y: .value("Type", r.type.displayName))
                        .foregroundStyle(Theme.exercise)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .annotation(position: .trailing) {
                            Text(Format.minutes(r.minutes)).font(.caption).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: rows.map(\.type.displayName))
                .frame(height: max(160, CGFloat(rows.count) * 30))
            }
        }
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { AnalysisView(profile: profile) }
            .frame(width: 1200, height: 900)
    }
}
