import SwiftUI
import SwiftData
import Charts
import LoseWeightCore

struct TodayView: View {
    let profile: UserProfile

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foods: [FoodEntry]
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    private var snapshot: Snapshot { Snapshot(profile: profile, weights: weights) }

    var body: some View {
        let snap = snapshot
        let budget = snap.dayBudget(foods: foods, exercises: exercises)
        ScrollView {
            VStack(spacing: Theme.spacing) {
                quickLog
                if isWide {
                    HStack(alignment: .top, spacing: Theme.spacing) {
                        BudgetCard(budget: budget, showNumbers: profile.showCalorieNumbers)
                        VStack(spacing: Theme.spacing) {
                            ActivityCard(exercises: exercises)
                            WeightCard(snapshot: snap)
                        }
                    }
                } else {
                    BudgetCard(budget: budget, showNumbers: profile.showCalorieNumbers)
                    ActivityCard(exercises: exercises)
                    WeightCard(snapshot: snap)
                }
                TodayLogCard(
                    foods: foods.filter { Calendar.current.isDateInToday($0.timestamp) },
                    exercises: exercises.filter { Calendar.current.isDateInToday($0.timestamp) },
                    showNumbers: profile.showCalorieNumbers
                )
                streakFooter(snap.streak(foods: foods, exercises: exercises, weights: weights))
            }
            .padding()
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Today")
    }

    private var isWide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    private var quickLog: some View {
        HStack(spacing: 12) {
            QuickLogButton(title: "Food", systemImage: "fork.knife", tint: Theme.food) { router.sheet = .food }
            QuickLogButton(title: "Exercise", systemImage: "figure.walk", tint: Theme.exercise) { router.sheet = .exercise }
            QuickLogButton(title: "Weight", systemImage: "scalemass", tint: Theme.weight) { router.sheet = .weight }
        }
    }

    @ViewBuilder
    private func streakFooter(_ streak: Int) -> some View {
        if streak > 1 {
            Label("\(streak)-day logging streak", systemImage: "flame")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Budget

struct BudgetCard: View {
    let budget: DayBudget
    let showNumbers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Food budget", systemImage: "fork.knife", tint: Theme.food)
            HStack(spacing: 24) {
                ZStack {
                    ProgressRing(fraction: budget.fraction, tint: budget.status.color, lineWidth: 18)
                    VStack(spacing: 2) {
                        Text(Format.percent(budget.fraction))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                        Text("of today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                    Text(subline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if budget.exerciseKcal > 0 {
                        Label(showNumbers ? "+\(Format.kcal(budget.exerciseKcal)) from exercise" : "Exercise added room",
                              systemImage: "plus.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.exercise)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .card()
    }

    private var headline: String {
        if budget.eaten.mid == 0 { return "Nothing logged yet" }
        switch budget.status {
        case .under: return "Room to spare"
        case .onTrack: return "Right on track"
        case .over: return "Over for today"
        }
    }

    private var subline: String {
        if showNumbers {
            let remaining = budget.remainingKcal
            let eaten = "Eaten ≈ \(Format.kcalRange(budget.eaten)) of \(Format.kcal(budget.budgetKcal))."
            return remaining >= 0 ? "\(eaten) About \(Format.kcal(remaining)) left." : "\(eaten) About \(Format.kcal(-remaining)) over."
        }
        switch budget.status {
        case .under where budget.eaten.mid == 0: return "Tap Food after each meal — it takes three taps."
        case .under: return budget.fraction < 0.5 ? "Plenty left for a full meal." : "Enough left for a lighter meal or snack."
        case .onTrack: return "You're close to your target. Nice."
        case .over: return "No big deal — one day doesn't define the week. A walk helps."
        }
    }
}

// MARK: - Activity

struct ActivityCard: View {
    let exercises: [ExerciseEntry]

    var body: some View {
        let week = Calendar.current.weekInterval(containing: .now)
        let thisWeek = exercises.filter { week.contains($0.timestamp) }
        let credited = thisWeek.reduce(0) { $0 + $1.log.guidelineMinutes }
        let strengthDays = Set(thisWeek.filter { $0.type.isMuscleStrengthening }.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let goal = EnergyConstants.weeklyActiveMinutesGoal

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Active minutes this week", systemImage: "figure.run", tint: Theme.exercise,
                       trailing: "\(Int(credited)) / \(Int(goal))")
            GoalBar(value: credited, goal: goal, tint: Theme.exercise)
            HStack {
                Text(credited >= goal ? "Guideline met — great work." : "\(Int(goal - credited)) min to go. Hard effort counts double.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<EnergyConstants.weeklyStrengthDaysGoal, id: \.self) { i in
                        Image(systemName: i < strengthDays ? "dumbbell.fill" : "dumbbell")
                            .foregroundStyle(i < strengthDays ? Theme.exercise : .secondary)
                    }
                }
                .font(.caption)
                .accessibilityLabel("\(strengthDays) of 2 strength days")
            }
        }
        .card()
    }
}

// MARK: - Weight

struct WeightCard: View {
    let snapshot: Snapshot

    var body: some View {
        let units = snapshot.units
        let recent = Array(snapshot.trend.suffix(30))
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Weight", systemImage: "scalemass", tint: Theme.weight,
                       trailing: snapshot.kgPerWeek.map { "\(units.formatWeightChange($0)) / wk" })
            if recent.isEmpty {
                EmptyHint(text: "Weigh in to start your trend line.", systemImage: "scalemass")
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(units.formatWeight(snapshot.currentKg))
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Text("trend · goal \(units.formatWeight(snapshot.profile.goalWeightKg, decimals: 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Chart(recent) { p in
                        LineMark(x: .value("Day", p.day), y: .value("Trend", units.displayWeight(fromKg: p.trendKg)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.weight)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 120, height: 44)
                    .accessibilityHidden(true)
                }
                GoalBar(value: snapshot.goalProgress, goal: 1, tint: Theme.weight, height: 6)
            }
        }
        .card()
    }
}

// MARK: - Today's log

struct TodayLogCard: View {
    let foods: [FoodEntry]
    let exercises: [ExerciseEntry]
    let showNumbers: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Today's log", systemImage: "list.bullet")
            if foods.isEmpty && exercises.isEmpty {
                EmptyHint(text: "Your meals and workouts will show up here.")
            }
            ForEach(MealSlot.allCases) { slot in
                let items = foods.filter { $0.meal == slot }.sorted { $0.timestamp < $1.timestamp }
                if !items.isEmpty {
                    Text(slot.displayName).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(items) { item in
                        row(icon: item.category.systemImage,
                            title: item.category.displayName,
                            detail: "\(item.healthiness.displayName) · \(item.portion.displayName)" + (showNumbers ? " · \(Format.kcalRange(item.calories))" : ""),
                            dot: item.healthiness,
                            time: item.timestamp) { context.delete(item) }
                    }
                }
            }
            if !exercises.isEmpty {
                Text("Exercise").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(exercises) { item in
                    row(icon: item.type.systemImage,
                        title: item.type.displayName,
                        detail: "\(Format.minutes(item.minutes)) · \(item.intensity.displayName)" + (item.isFromHealth ? " · Health" : ""),
                        dot: nil,
                        time: item.timestamp) { context.delete(item) }
                }
            }
        }
        .card()
    }

    private func row(icon: String, title: String, detail: String, dot: Healthiness?, time: Date, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let dot { TierDot(healthiness: dot) }
            Text(time, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { TodayView(profile: profile) }
    }
}
