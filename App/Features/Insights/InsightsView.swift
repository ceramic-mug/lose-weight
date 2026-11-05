import SwiftUI
import SwiftData
import LoseWeightCore

enum AuditPeriod: String, CaseIterable, Identifiable {
    case thisWeek, lastWeek, last30
    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisWeek: "This week"
        case .lastWeek: "Last week"
        case .last30: "30 days"
        }
    }

    var interval: (start: Date, end: Date) {
        let cal = Calendar.current
        let week = cal.weekInterval(containing: .now)
        switch self {
        case .thisWeek:
            return (week.start, .now)
        case .lastWeek:
            let start = cal.date(byAdding: .weekOfYear, value: -1, to: week.start)!
            return (start, cal.date(byAdding: .day, value: -1, to: week.start)!)
        case .last30:
            return (cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: .now))!, .now)
        }
    }
}

struct InsightsView: View {
    let profile: UserProfile

    @Query(sort: \FoodEntry.timestamp) private var foods: [FoodEntry]
    @Query(sort: \DrinkEntry.timestamp) private var drinks: [DrinkEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]
    @State private var period: AuditPeriod = .thisWeek

    private let tileColumns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let snap = Snapshot(profile: profile, weights: weights)
        let interval = period.interval
        let report = snap.report(start: interval.start, end: interval.end, foods: foods, drinks: drinks, exercises: exercises, weights: weights)
        let units = profile.units

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Picker("Period", selection: $period) {
                    ForEach(AuditPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ReportCardHeader(report: report)

                LazyVGrid(columns: tileColumns, spacing: 12) {
                    StatTile(title: "Healthy choices",
                             value: report.healthyShare.map(Format.percent) ?? "—",
                             caption: "\(report.mealsLogged) items",
                             systemImage: "leaf", tint: Theme.lighter)
                    StatTile(title: "Daily food",
                             value: report.averageDailyKcal.map { profile.showCalorieNumbers ? Format.kcal($0) : Format.percent($0 / max(report.targetKcal, 1)) } ?? "—",
                             caption: profile.showCalorieNumbers ? "of \(Format.kcal(report.targetKcal))" : "of budget",
                             systemImage: "fork.knife", tint: Theme.food)
                    StatTile(title: "Active minutes",
                             value: "\(Int(report.activeMinutesPerWeek.rounded()))",
                             caption: report.days > 7 ? "per week (avg) · goal 150" : "of 150 this week",
                             systemImage: "figure.run", tint: Theme.exercise)
                    StatTile(title: "Strength days",
                             value: "\(report.strengthDays)",
                             caption: report.days > 7 ? "days in \(report.days) · goal 2 a week" : "of 2 this week",
                             systemImage: "dumbbell", tint: Theme.exercise)
                    if let mg = report.avgCaffeineMg {
                        StatTile(title: "Caffeine",
                                 value: "\(Int(mg.rounded())) mg",
                                 caption: "a day · limit 400",
                                 systemImage: "cup.and.saucer.fill", tint: Theme.drink)
                    }
                    StatTile(title: "Trend weight",
                             value: report.trendChangeKg.map { units.formatWeightChange($0) } ?? "—",
                             caption: report.kgPerWeek.map { "\(units.formatWeightChange($0))/wk" },
                             systemImage: "scalemass", tint: Theme.weight)
                    StatTile(title: "Days logged",
                             value: "\(report.daysWithAnyLog) / \(report.days)",
                             caption: "\(snap.streak(foods: foods, drinks: drinks, exercises: exercises, weights: weights))-day streak",
                             systemImage: "checkmark.circle", tint: Theme.accent)
                }

                GoalCard(snapshot: snap)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Focus").font(.title3.weight(.semibold))
                    if report.insights.isEmpty {
                        EmptyHint(text: "Tips appear after a few days of logging").card()
                    }
                    ForEach(report.insights) { InsightRow(insight: $0) }
                }

            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Insights")
        .toolbar { ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .reportCard) } }
    }
}

struct ReportCardHeader: View {
    let report: PeriodReport

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(fraction: Double(report.overallScore) / 100, tint: color, lineWidth: 12)
                VStack(spacing: 0) {
                    Text(report.grade.count == 1 ? report.grade : "\(report.overallScore)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("score \(report.overallScore)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 6) {
                Text("Report card").font(.title3.weight(.semibold))
                Text("\(report.start.formatted(.dateTime.month(.abbreviated).day())) – \(report.end.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var color: Color {
        switch report.overallScore {
        case 70...: Theme.lighter
        case 45..<70: Theme.balanced
        default: Theme.accent
        }
    }
}

struct GoalCard: View {
    let snapshot: Snapshot

    var body: some View {
        let units = snapshot.units
        let p = snapshot.profile
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Goal", systemImage: "flag.checkered", tint: Theme.weight,
                       trailing: Format.percent(snapshot.goalProgress))
            GoalBar(value: snapshot.goalProgress, goal: 1, tint: Theme.weight)
            HStack {
                VStack(alignment: .leading) {
                    Text("Start").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(p.startWeightKg)).font(.subheadline.weight(.medium))
                }
                Spacer()
                VStack {
                    Text("Now").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(snapshot.currentKg)).font(.subheadline.weight(.medium))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Goal").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(p.goalWeightKg)).font(.subheadline.weight(.medium))
                }
            }
            .monospacedDigit()
            if let projection = projectionText {
                Text(projection).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var projectionText: String? {
        guard snapshot.wantsLoss else { return snapshot.profile.maintenanceOnly ? "Maintenance" : "Goal reached" }
        return snapshot.projectedGoalDate.map { "On pace for \($0.formatted(.dateTime.month(.abbreviated).year()))" }
    }
}

struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.systemImage)
                .font(.title3)
                .foregroundStyle(insight.kind.color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(insight.kind.color).frame(width: 4).padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { InsightsView(profile: profile) }
    }
}
