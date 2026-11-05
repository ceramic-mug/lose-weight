import SwiftUI
import SwiftData
import LoseWeightCore

/// Three taps: where from → how healthy → how much. The last tap saves.
struct LogFoodView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var history: [FoodEntry]

    @State private var category: FoodCategory?
    @State private var healthiness: Healthiness?
    @State private var meal: MealSlot = MealSlot.suggested(for: .now)
    @State private var mealEdited = false
    @State private var time = Date.now
    @State private var saved = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    whenRow
                    quickPicks

                    StepSection(title: "Where from?") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            // Drinks have their own log now.
                            ForEach(FoodCategory.allCases.filter { $0 != .drink }) { c in
                                ChoiceTile(title: c.displayName, systemImage: c.systemImage, tint: Theme.food,
                                           isSelected: category == c) { select(c) }
                            }
                        }
                    }

                    if category != nil {
                        StepSection(title: "How healthy?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(Healthiness.allCases) { h in
                                    ChoiceTile(title: h.displayName, systemImage: h.systemImage, tint: h.color,
                                               isSelected: healthiness == h) {
                                        withAnimation(.snappy) { healthiness = h }
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if category != nil, healthiness != nil {
                        StepSection(title: "How much?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(Portion.allCases) { p in
                                    ChoiceTile(title: p.displayName, systemImage: p.systemImage, tint: Theme.food,
                                               isSelected: false) { save(p) }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Food")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .food) }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    /// Meal and time are filled in automatically; change them only if needed.
    private var whenRow: some View {
        HStack {
            Picker("Meal", selection: Binding(get: { meal }, set: { meal = $0; mealEdited = true })) {
                ForEach(MealSlot.allCases) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Spacer()
            DatePicker("Time", selection: $time, in: ...Date.now.addingTimeInterval(3600),
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .onChange(of: time) { _, newValue in
                    if !mealEdited { meal = MealSlot.suggested(for: newValue, category: category) }
                }
        }
    }

    @ViewBuilder
    private var quickPicks: some View {
        let recents = recentCombos
        let yesterday = yesterdaysMeal
        if !recents.isEmpty || !yesterday.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !yesterday.isEmpty {
                        Button { copy(yesterday) } label: {
                            Label("Yesterday's \(meal.displayName.lowercased())", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.food)
                    }
                    // One tap logs a recent choice again.
                    ForEach(recents, id: \.comboKey) { e in
                        Button { copy([e]) } label: {
                            HStack(spacing: 6) {
                                TierDot(healthiness: e.healthiness, size: 8)
                                Image(systemName: e.category.systemImage)
                                Text(e.portion.displayName)
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("\(e.category.displayName), \(e.healthiness.displayName), \(e.portion.displayName)")
                    }
                }
            }
        }
    }

    // MARK: Data

    /// The four most-used choices from the last 40 entries.
    private var recentCombos: [FoodEntry] {
        var counts: [String: (FoodEntry, Int)] = [:]
        for e in history.prefix(40) {
            counts[e.comboKey] = (counts[e.comboKey]?.0 ?? e, (counts[e.comboKey]?.1 ?? 0) + 1)
        }
        return counts.values.sorted { $0.1 > $1.1 }.prefix(4).map(\.0)
    }

    private var yesterdaysMeal: [FoodEntry] {
        guard meal != .snack else { return [] }
        return history.filter { Calendar.current.isDateInYesterday($0.timestamp) && $0.meal == meal }
    }

    private func select(_ c: FoodCategory) {
        withAnimation(.snappy) {
            category = c
            if !mealEdited { meal = MealSlot.suggested(for: time, category: c) }
        }
    }

    private func save(_ portion: Portion) {
        guard let category, let healthiness else { return }
        context.insert(FoodEntry(timestamp: time, category: category, healthiness: healthiness, portion: portion, meal: meal))
        finish()
    }

    private func copy(_ entries: [FoodEntry]) {
        for e in entries {
            let slot = entries.count == 1 ? MealSlot.suggested(for: time, category: e.category) : e.meal
            context.insert(FoodEntry(timestamp: time, category: e.category, healthiness: e.healthiness,
                                     portion: e.portion, meal: mealEdited ? meal : slot))
        }
        finish()
    }

    private func finish() {
        saved.toggle()
        dismiss()
    }
}

extension Portion {
    var systemImage: String {
        switch self {
        case .small: "circle.bottomhalf.filled"
        case .regular: "circle.fill"
        case .large: "plus.circle.fill"
        }
    }
}

/// A short step heading with its content underneath.
struct StepSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
    }
}

#Preview {
    PreviewHost { profile in LogFoodView(profile: profile) }
}
