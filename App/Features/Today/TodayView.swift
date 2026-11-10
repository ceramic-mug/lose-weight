import SwiftUI
import SwiftData
import LoseWeightCore

struct TodayView: View {
    let profile: UserProfile

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foods: [FoodEntry]
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var drinks: [DrinkEntry]
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    private var snapshot: Snapshot { Snapshot(profile: profile, weights: weights) }

    var body: some View {
        let snap = snapshot
        let budget = snap.dayBudget(foods: foods, drinks: drinks, exercises: exercises)
        let todaysDrinks = drinks.filter { Calendar.current.isDateInToday($0.timestamp) }
        let todaysExercises = exercises.filter { Calendar.current.isDateInToday($0.timestamp) }
        let todaysWeights = weights.filter { Calendar.current.isDateInToday($0.timestamp) }
        ScrollView {
            VStack(spacing: Theme.spacing) {
                quickLog
                if isWide {
                    HStack(alignment: .top, spacing: Theme.spacing) {
                        BudgetCard(budget: budget, showNumbers: profile.showCalorieNumbers)
                        VStack(spacing: Theme.spacing) {
                            ActivityCard(exercises: todaysExercises, showNumbers: profile.showCalorieNumbers)
                            WeightCard(weights: todaysWeights, units: profile.units)
                        }
                    }
                } else {
                    BudgetCard(budget: budget, showNumbers: profile.showCalorieNumbers)
                    ActivityCard(exercises: todaysExercises, showNumbers: profile.showCalorieNumbers)
                    WeightCard(weights: todaysWeights, units: profile.units)
                }
                DrinksCard(drinks: todaysDrinks)
                TodayLogCard(
                    foods: foods.filter { Calendar.current.isDateInToday($0.timestamp) },
                    drinks: todaysDrinks,
                    exercises: todaysExercises,
                    showNumbers: profile.showCalorieNumbers,
                    weightKg: snap.weightForExerciseKg
                )
                streakFooter(snap.streak(foods: foods, drinks: drinks, exercises: exercises, weights: weights))
            }
            .padding()
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Today")
        .toolbar { ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .budget) } }
    }

    private var isWide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    private var quickLog: some View {
        HStack(spacing: 10) {
            QuickLogButton(title: "Food", systemImage: "fork.knife", tint: Theme.food) { router.sheet = .food }
            QuickLogButton(title: "Drink", systemImage: "cup.and.saucer.fill", tint: Theme.drink) { router.sheet = .drink }
            QuickLogButton(title: "Exercise", systemImage: "figure.walk", tint: Theme.exercise) { router.sheet = .exercise }
            QuickLogButton(title: "Weight", systemImage: "scalemass", tint: Theme.weight) { router.sheet = .weight }
        }
    }

    @ViewBuilder
    private func streakFooter(_ streak: Int) -> some View {
        if streak > 1 {
            Label("\(streak)-day streak", systemImage: "flame")
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
            CardHeader(title: "Food", systemImage: "fork.knife", tint: Theme.food)
            HStack(spacing: 24) {
                ZStack {
                    ProgressRing(fraction: budget.fraction, tint: budget.status.color, lineWidth: 18)
                    VStack(spacing: 2) {
                        Text(Format.percent(budget.fraction))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                    }
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                    if showNumbers {
                        Text("\(Format.kcal(budget.eaten.mid)) of \(Format.kcal(budget.budgetKcal))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if budget.exerciseKcal > 0 {
                        Label(showNumbers ? "+\(Format.kcal(budget.exerciseKcal))" : "Exercise bonus", systemImage: "plus.circle.fill")
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
        if budget.eaten.mid == 0 { return "Nothing yet" }
        switch budget.status {
        case .under: return "Room to spare"
        case .onTrack: return "On track"
        case .over: return "Over budget"
        }
    }

}

// MARK: - Activity

/// Today's movement only; weekly totals live on Trends and Insights.
struct ActivityCard: View {
    /// Today's workouts.
    let exercises: [ExerciseEntry]
    let showNumbers: Bool
    @Environment(AppRouter.self) private var router

    /// 150 minutes a week is about 30 minutes on 5 days.
    private let dailyTarget: Double = 30

    var body: some View {
        let minutes = exercises.reduce(0) { $0 + $1.minutes }
        let kcal = exercises.reduce(0) { $0 + $1.netKcal }
        let sessions = exercises.sorted { $0.timestamp < $1.timestamp }
            .map { "\($0.type.displayName) \(Int($0.minutes))" }
            .joined(separator: " · ")

        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Active today", systemImage: "figure.run", tint: Theme.exercise,
                       trailing: showNumbers && kcal > 0 ? "+\(Format.kcal(kcal))" : nil)
            if exercises.isEmpty {
                HStack {
                    EmptyHint(text: "No activity yet", systemImage: "figure.walk")
                    Button("Log") { router.sheet = .exercise }
                        .buttonStyle(.bordered)
                        .tint(Theme.exercise)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(minutes)) min")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Text(sessions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                GoalBar(value: minutes, goal: dailyTarget, tint: Theme.exercise, height: 6)
            }
        }
        .card()
    }
}

// MARK: - Weight

/// Today's scale reading only; the smoothed trend lives on Trends.
struct WeightCard: View {
    /// Today's weigh-ins.
    let weights: [WeightEntry]
    let units: UnitSystem
    @Environment(AppRouter.self) private var router

    var body: some View {
        let latest = weights.max { $0.timestamp < $1.timestamp }
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Weight today", systemImage: "scalemass", tint: Theme.weight)
            if let latest {
                Text(units.formatWeight(latest.kg))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            } else {
                HStack {
                    EmptyHint(text: "Not weighed in today", systemImage: "scalemass")
                    Button("Log") { router.sheet = .weight }
                        .buttonStyle(.bordered)
                        .tint(Theme.weight)
                }
            }
        }
        .card()
    }
}

// MARK: - Drinks

/// One slim line: caffeine so far (bar to 400 mg) and glasses of water.
struct DrinksCard: View {
    let drinks: [DrinkEntry]

    var body: some View {
        let caffeine = drinks.reduce(0) { $0 + $1.caffeineMg }
        let waterMl = drinks.filter { $0.kind == .water }.reduce(0) { $0 + $1.ml }
        let glasses = Int((waterMl / DrinkMath.glassMl).rounded())
        let limit = DrinkMath.caffeineDailyLimitMg

        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundStyle(Theme.drink)
                .font(.subheadline)
            Text("\(Int(caffeine)) mg")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
            GoalBar(value: caffeine, goal: limit, tint: caffeine > limit ? Theme.balanced : Theme.drink, height: 4)
            Label("\(glasses)", systemImage: "drop.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("\(glasses) glasses of water")
        }
        .card(padding: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Today's log

struct TodayLogCard: View {
    let foods: [FoodEntry]
    let drinks: [DrinkEntry]
    let exercises: [ExerciseEntry]
    let showNumbers: Bool
    let weightKg: Double
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @State private var editingFood: FoodEntry?
    @State private var editingExercise: ExerciseEntry?
    @State private var editingDrink: DrinkEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardHeader(title: "Logged", systemImage: "list.bullet")
                Button("See all") { router.section = .history }
                    .font(.subheadline)
            }
            if foods.isEmpty && drinks.isEmpty && exercises.isEmpty {
                EmptyHint(text: "Nothing logged today")
            }
            ForEach(MealSlot.allCases) { slot in
                let items = foods.filter { $0.meal == slot }.sorted { $0.timestamp < $1.timestamp }
                if !items.isEmpty {
                    Text(slot.displayName).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(items) { item in
                        row(item.row(showNumbers: showNumbers), onTap: { editingFood = item }) { context.delete(item) }
                    }
                }
            }
            if !drinks.isEmpty {
                Text("Drinks").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(drinks.sorted { $0.timestamp < $1.timestamp }) { item in
                    row(item.row(showNumbers: showNumbers), onTap: { editingDrink = item }) { context.delete(item) }
                }
            }
            if !exercises.isEmpty {
                Text("Exercise").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(exercises.sorted { $0.timestamp < $1.timestamp }) { item in
                    row(item.row, onTap: { editingExercise = item }) { context.delete(item) }
                }
            }
        }
        .card()
        .sheet(item: $editingFood) { EditFoodView(entry: $0) }
        .sheet(item: $editingExercise) { EditExerciseView(entry: $0, weightKg: weightKg) }
        .sheet(item: $editingDrink) { EditDrinkView(entry: $0) }
    }

    private func row(_ content: LogRow, onTap: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        Button(action: onTap) { content }
            .buttonStyle(.plain)
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
