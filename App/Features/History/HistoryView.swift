import SwiftUI
import SwiftData
import LoseWeightCore

/// Every past entry, by day, filterable by type. Tap to edit, swipe to delete.
struct HistoryView: View {
    let profile: UserProfile

    enum Filter: String, CaseIterable, Identifiable {
        case all, weight, food, exercise, drink
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All"
            case .food: "Food"
            case .drink: "Drinks"
            case .exercise: "Exercise"
            case .weight: "Weight"
            }
        }
    }

    enum Item: Identifiable {
        case food(FoodEntry)
        case drink(DrinkEntry)
        case exercise(ExerciseEntry)
        case weight(WeightEntry)

        var id: PersistentIdentifier {
            switch self {
            case .food(let e): e.persistentModelID
            case .drink(let e): e.persistentModelID
            case .exercise(let e): e.persistentModelID
            case .weight(let e): e.persistentModelID
            }
        }

        var isFood: Bool {
            switch self {
            case .food: true
            default: false
            }
        }

        var date: Date {
            switch self {
            case .food(let e): e.timestamp
            case .drink(let e): e.timestamp
            case .exercise(let e): e.timestamp
            case .weight(let e): e.timestamp
            }
        }
    }

    struct Day: Identifiable {
        let day: Date
        let items: [Item]
        var id: Date { day }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foods: [FoodEntry]
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var drinks: [DrinkEntry]
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    @AppStorage("historyFilter") private var filterRaw = Filter.all.rawValue
    @State private var editing: Item?

    private var filter: Filter { Filter(rawValue: filterRaw) ?? .all }

    var body: some View {
        let snap = Snapshot(profile: profile, weights: weights)
        let days = grouped()

        List {
            Section {
                Picker("Show", selection: $filterRaw) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if days.isEmpty {
                Text("Nothing logged yet")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.items) { item in
                        Button { editing = item } label: { row(item) }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(item) }
                            }
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(item) }
                            }
                    }
                } header: {
                    HStack {
                        Text(title(for: day.day))
                        Spacer()
                        if filter == .all || filter == .food,
                           day.items.contains(where: \.isFood) {
                            let budget = snap.dayBudget(foods: foods, drinks: drinks, exercises: exercises, on: day.day)
                            Text("\(Format.percent(budget.fraction)) of budget")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("History")
        .sheet(item: $editing) { item in
            switch item {
            case .food(let e): EditFoodView(entry: e)
            case .drink(let e): EditDrinkView(entry: e)
            case .exercise(let e): EditExerciseView(entry: e, weightKg: snap.weightForExerciseKg)
            case .weight(let e): EditWeightView(entry: e, units: profile.units)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .food(let e): e.row(showNumbers: profile.showCalorieNumbers)
        case .drink(let e): e.row(showNumbers: profile.showCalorieNumbers)
        case .exercise(let e): e.row
        case .weight(let e): e.row(units: profile.units)
        }
    }

    private func grouped() -> [Day] {
        var items: [Item] = []
        if filter == .all || filter == .food { items += foods.map(Item.food) }
        if filter == .all || filter == .drink { items += drinks.map(Item.drink) }
        if filter == .all || filter == .exercise { items += exercises.map(Item.exercise) }
        if filter == .all || filter == .weight { items += weights.map(Item.weight) }
        let cal = Calendar.current
        let byDay = Dictionary(grouping: items) { cal.startOfDay(for: $0.date) }
        return byDay.keys.sorted(by: >).map { day in
            // Within a day, read top to bottom like the day happened.
            Day(day: day, items: byDay[day]!.sorted { $0.date < $1.date })
        }
    }

    private func title(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        let sameYear = cal.component(.year, from: day) == cal.component(.year, from: .now)
        return sameYear
            ? day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : day.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func delete(_ item: Item) {
        switch item {
        case .food(let e): context.delete(e)
        case .drink(let e): context.delete(e)
        case .exercise(let e): context.delete(e)
        case .weight(let e): context.delete(e)
        }
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { HistoryView(profile: profile) }
    }
}
