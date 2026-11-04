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
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]
    @State private var period: AuditPeriod = .thisWeek

    private let tileColumns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let snap = Snapshot(profile: profile, weights: weights)
        let interval = period.interval
        let report = snap.report(start: interval.start, end: interval.end, foods: foods, exercises: exercises, weights: weights)
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
                             caption: "\(report.mealsLogged) items logged",
                             systemImage: "leaf", tint: Theme.lighter)
                    StatTile(title: "Avg. daily food",
                             value: report.averageDailyKcal.map { profile.showCalorieNumbers ? Format.kcal($0) : Format.percent($0 / max(report.targetKcal, 1)) } ?? "—",
                             caption: profile.showCalorieNumbers ? "Target \(Format.kcal(report.targetKcal))" : "of your daily target",
                             systemImage: "fork.knife", tint: Theme.food)
                    StatTile(title: "Active minutes",
                             value: "\(Int(report.guidelineMinutesPerWeek.rounded()))",
                             caption: "per week · goal 150",
                             systemImage: "figure.run", tint: Theme.exercise)
                    StatTile(title: "Strength days",
                             value: "\(report.strengthDays)",
                             caption: "goal 2 per week",
                             systemImage: "dumbbell", tint: Theme.exercise)
                    StatTile(title: "Trend weight",
                             value: report.trendChangeKg.map { units.formatWeightChange($0) } ?? "—",
                             caption: report.kgPerWeek.map { "\(units.formatWeightChange($0)) per week" } ?? "\(report.weighIns) weigh-ins",
                             systemImage: "scalemass", tint: Theme.weight)
                    StatTile(title: "Days logged",
                             value: "\(report.daysWithAnyLog) / \(report.days)",
                             caption: "\(snap.streak(foods: foods, exercises: exercises, weights: weights))-day streak",
                             systemImage: "checkmark.circle", tint: Theme.accent)
                }

                GoalCard(snapshot: snap)

                VStack(alignment: .leading, spacing: 10) {
                    Text("What to focus on").font(.title3.weight(.semibold))
                    if report.insights.isEmpty {
                        EmptyHint(text: "Log for a few days and personalised tips will appear here.")
                            .card()
                    }
                    ForEach(report.insights) { InsightRow(insight: $0) }
                }

                Text("Estimates are based on typical portions and published guidelines. They're a guide, not medical advice — talk to your doctor or a registered dietitian about your own needs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Insights")
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
                Text("Food quality 40 · Near target 20 · Movement 30 · Logging 10")
                    .font(.caption)
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
            CardHeader(title: "Goal progress", systemImage: "flag.checkered", tint: Theme.weight,
                       trailing: Format.percent(snapshot.goalProgress))
            GoalBar(value: snapshot.goalProgress, goal: 1, tint: Theme.weight)
            HStack {
                VStack(alignment: .leading) {
                    Text("Start").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(p.startWeightKg)).font(.subheadline.weight(.medium))
                }
                Spacer()
                VStack {
                    Text("Now (trend)").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(snapshot.currentKg)).font(.subheadline.weight(.medium))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Goal").font(.caption).foregroundStyle(.secondary)
                    Text(units.formatWeight(p.goalWeightKg)).font(.subheadline.weight(.medium))
                }
            }
            .monospacedDigit()
            Text(projectionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var projectionText: String {
        if !snapshot.profile.wantsLoss { return "You're in maintenance mode — the aim is to hold steady and build healthy habits." }
        if let date = snapshot.projectedGoalDate {
            return "At your current pace you'll reach your goal around \(date.formatted(.dateTime.month(.wide).year()))."
        }
        if snapshot.kgPerWeek == nil { return "Keep weighing in — after about a week we can project when you'll reach your goal." }
        return "Your trend is flat or rising right now. Small, steady changes add up — check the tips below."
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
