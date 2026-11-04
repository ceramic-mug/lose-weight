import SwiftUI
import SwiftData
import LoseWeightCore

struct LogFoodView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var history: [FoodEntry]

    @State private var category: FoodCategory?
    @State private var healthiness: Healthiness?
    @State private var portion: Portion = .regular
    @State private var meal: MealSlot = MealSlot.suggested(for: .now)
    @State private var mealEdited = false
    @State private var time = Date.now

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    shortcuts
                    StepSection(number: 1, title: "Where was it from?") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(FoodCategory.allCases) { c in
                                ChoiceTile(title: c.displayName, systemImage: c.systemImage, tint: Theme.food,
                                           isSelected: category == c) { select(c) }
                            }
                        }
                    }

                    if let category {
                        StepSection(number: 2, title: "How healthy was it?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(Healthiness.allCases) { h in
                                    ChoiceTile(title: h.displayName, subtitle: h.shortHint, systemImage: h.systemImage,
                                               tint: h.color, isSelected: healthiness == h) {
                                        withAnimation(.snappy) { healthiness = h }
                                    }
                                }
                            }
                            Text(category.examples(for: healthiness ?? .balanced))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                                .animation(.default, value: healthiness)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if category != nil, healthiness != nil {
                        StepSection(number: 3, title: "How much?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(Portion.allCases) { p in
                                    ChoiceTile(title: p.displayName, subtitle: p.hint, systemImage: portionIcon(p),
                                               tint: Theme.food, isSelected: portion == p) {
                                        withAnimation(.snappy) { portion = p }
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        details
                        estimate
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Log food")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(category == nil || healthiness == nil)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var shortcuts: some View {
        let recents = recentCombos
        let yesterday = yesterdaysMeal
        if !recents.isEmpty || !yesterday.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick picks").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if !yesterday.isEmpty {
                            Button {
                                copyYesterday(yesterday)
                            } label: {
                                Label("Same as yesterday's \(meal.displayName.lowercased())", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.food)
                        }
                        ForEach(recents, id: \.comboKey) { entry in
                            Button {
                                withAnimation(.snappy) {
                                    select(entry.category)
                                    healthiness = entry.healthiness
                                    portion = entry.portion
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    TierDot(healthiness: entry.healthiness, size: 8)
                                    Text("\(entry.category.displayName) · \(entry.portion.displayName)")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Meal", selection: Binding(get: { meal }, set: { meal = $0; mealEdited = true })) {
                ForEach(MealSlot.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            DatePicker("Time", selection: $time, in: ...Date.now.addingTimeInterval(3600), displayedComponents: [.date, .hourAndMinute])
                .onChange(of: time) { _, newValue in
                    if !mealEdited { meal = MealSlot.suggested(for: newValue, category: category) }
                }
        }
        .card()
    }

    @ViewBuilder
    private var estimate: some View {
        if let category, let healthiness {
            let range = EnergyEstimator.calories(category: category, healthiness: healthiness, portion: portion)
            let target = profile.dailyTarget(currentWeightKg: nil).targetKcal
            HStack(spacing: 12) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    if profile.showCalorieNumbers {
                        Text("About \(Format.kcalRange(range))").font(.subheadline.weight(.semibold))
                    }
                    Text("Roughly \(Format.percent(range.mid / max(target, 1))) of your daily food budget.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .card(padding: 12)
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

    private func portionIcon(_ p: Portion) -> String {
        switch p {
        case .small: "circle.bottomhalf.filled"
        case .regular: "circle.fill"
        case .large: "circle.circle.fill"
        }
    }

    private func save() {
        guard let category, let healthiness else { return }
        context.insert(FoodEntry(timestamp: time, category: category, healthiness: healthiness, portion: portion, meal: meal))
        dismiss()
    }

    private func copyYesterday(_ entries: [FoodEntry]) {
        for e in entries {
            context.insert(FoodEntry(timestamp: time, category: e.category, healthiness: e.healthiness, portion: e.portion, meal: e.meal))
        }
        dismiss()
    }
}

/// A numbered step heading with its content underneath.
struct StepSection<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.accent))
                Text(title).font(.headline)
            }
            content
        }
    }
}

#Preview {
    PreviewHost { profile in LogFoodView(profile: profile) }
}
