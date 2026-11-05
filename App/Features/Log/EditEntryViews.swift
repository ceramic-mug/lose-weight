import SwiftUI
import SwiftData
import LoseWeightCore

/// Tap a meal on Today to change its time or any choice, or delete it.
struct EditFoodView: View {
    let entry: FoodEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var time: Date
    @State private var meal: MealSlot
    @State private var category: FoodCategory
    @State private var healthiness: Healthiness
    @State private var portion: Portion

    init(entry: FoodEntry) {
        self.entry = entry
        _time = State(initialValue: entry.timestamp)
        _meal = State(initialValue: entry.meal)
        _category = State(initialValue: entry.category)
        _healthiness = State(initialValue: entry.healthiness)
        _portion = State(initialValue: entry.portion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: [.date, .hourAndMinute])
                    Picker("Meal", selection: $meal) {
                        ForEach(MealSlot.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Where from?") {
                    Picker("Where from?", selection: $category) {
                        ForEach(FoodCategory.allCases) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Section("How healthy?") {
                    Picker("How healthy?", selection: $healthiness) {
                        ForEach(Healthiness.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("How much?") {
                    Picker("How much?", selection: $portion) {
                        ForEach(Portion.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section {
                    Button("Delete", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit meal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.update(timestamp: time, category: category, healthiness: healthiness, portion: portion, meal: meal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
    }
}

/// Tap a workout on Today to change its time, type, effort or minutes, or delete it.
struct EditExerciseView: View {
    let entry: ExerciseEntry
    let weightKg: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var time: Date
    @State private var type: ExerciseType
    @State private var intensity: Intensity
    @State private var minutes: Double

    init(entry: ExerciseEntry, weightKg: Double) {
        self.entry = entry
        self.weightKg = weightKg
        _time = State(initialValue: entry.timestamp)
        _type = State(initialValue: entry.type)
        _intensity = State(initialValue: entry.intensity)
        _minutes = State(initialValue: entry.minutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: [.date, .hourAndMinute])
                    Picker("Activity", selection: $type) {
                        ForEach(ExerciseType.allCases) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Effort") {
                    Picker("Effort", selection: $intensity) {
                        ForEach(Intensity.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("Minutes") {
                    Stepper(value: $minutes, in: 5...600, step: 5) {
                        Text(Format.minutes(minutes)).monospacedDigit()
                    }
                }
                Section {
                    Button("Delete", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.update(timestamp: time, type: type, intensity: intensity, minutes: minutes, weightKg: weightKg)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 400)
        #endif
    }
}
