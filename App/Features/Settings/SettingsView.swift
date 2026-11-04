import SwiftUI
import SwiftData
import LoseWeightCore

struct SettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(HealthKitService.self) private var health
    @Query private var foods: [FoodEntry]
    @Query private var exercises: [ExerciseEntry]
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    @State private var confirmDelete = false
    @State private var showGuidelines = false

    var body: some View {
        let target = profile.dailyTarget(currentWeightKg: Snapshot(profile: profile, weights: weights).trend.last?.trendKg)
        Form {
            Section("Your plan") {
                LabeledContent("Daily food budget", value: Format.kcal(target.targetKcal))
                LabeledContent("Maintenance (estimated)", value: Format.kcal(target.maintenanceKcal))
                Picker("Pace", selection: $profile.paceRaw) {
                    ForEach(LossPace.allCases) { p in
                        Text("\(p.displayName) · \(profile.units.formatWeight(p.kgPerWeek, decimals: profile.units == .metric ? 2 : 1))/wk").tag(p.rawValue)
                    }
                }
                .disabled(profile.maintenanceOnly)
                WeightField(title: "Goal weight", kg: $profile.goalWeightKg, units: profile.units)
                    .disabled(profile.maintenanceOnly)
                Toggle("Maintenance only (no calorie cut)", isOn: $profile.maintenanceOnly)
                if target.limitedByFloor {
                    Text("Your budget is held at a safe minimum, so loss may be slower than the pace you chose.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("About you") {
                Picker("Sex", selection: $profile.sexRaw) {
                    ForEach(Sex.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                Picker("Birth year", selection: $profile.birthYear) {
                    let year = Calendar.current.component(.year, from: .now)
                    ForEach((year - 100)...(year - 18), id: \.self) { Text(String($0)).tag($0) }
                }
                HeightField(heightCm: $profile.heightCm, units: profile.units)
                Picker("Everyday activity", selection: $profile.activityRaw) {
                    ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                WeightField(title: "Starting weight", kg: $profile.startWeightKg, units: profile.units)
            }

            Section("Display") {
                Picker("Units", selection: $profile.unitsRaw) {
                    ForEach(UnitSystem.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                Toggle("Show calorie numbers", isOn: $profile.showCalorieNumbers)
            }

            Section {
                if health.isAvailable {
                    Toggle("Use Apple Health", isOn: Binding(
                        get: { profile.useHealth },
                        set: { newValue in
                            if newValue {
                                Task {
                                    profile.useHealth = await health.requestAuthorization()
                                    if profile.useHealth { await health.sync(into: context, profile: profile, days: 90) }
                                }
                            } else {
                                profile.useHealth = false
                            }
                        }
                    ))
                    if profile.useHealth {
                        Button("Sync now") { Task { await health.sync(into: context, profile: profile, days: 90) } }
                        if let last = health.lastSync {
                            LabeledContent("Last synced", value: last.formatted(date: .omitted, time: .shortened))
                        }
                    }
                } else {
                    Text("Apple Health is available on iPhone. Data logged there syncs here through iCloud.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Daily reminder", isOn: $profile.reminderEnabled)
                if profile.reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Health & reminders")
            }

            Section("Your data") {
                ShareLink(item: CSVExport(foods: foods, exercises: exercises, weights: weights),
                          preview: SharePreview("Lose Weight export.csv")) {
                    Label("Export as CSV", systemImage: "square.and.arrow.up")
                }
                Button("Delete all data", role: .destructive) { confirmDelete = true }
            }

            Section("About") {
                Button("How the numbers work") { showGuidelines = true }
                Text("Lose Weight offers general guidance based on public health guidelines. It is not a medical device and doesn't replace advice from your doctor or a registered dietitian.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onChange(of: profile.reminderEnabled) { _, enabled in updateReminder(enabled) }
        .onChange(of: profile.reminderHour) { _, _ in updateReminder(profile.reminderEnabled) }
        .onChange(of: profile.reminderMinute) { _, _ in updateReminder(profile.reminderEnabled) }
        .onChange(of: profile.maintenanceOnly) { _, on in if on { profile.goalWeightKg = profile.startWeightKg } }
        .onDisappear { profile.updatedAt = .now }
        .confirmationDialog("Delete everything?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all entries and profile", role: .destructive, action: deleteAll)
        } message: {
            Text("This removes your data from this device and iCloud. Data in Apple Health is not affected.")
        }
        .sheet(isPresented: $showGuidelines) { GuidelinesSheet() }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: profile.reminderHour, minute: profile.reminderMinute)) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.reminderHour = c.hour ?? 20
                profile.reminderMinute = c.minute ?? 0
            }
        )
    }

    private func updateReminder(_ enabled: Bool) {
        if enabled {
            let hour = profile.reminderHour, minute = profile.reminderMinute
            Task {
                if await ReminderService.requestPermission() {
                    await ReminderService.schedule(hour: hour, minute: minute)
                }
            }
        } else {
            ReminderService.cancel()
        }
    }

    private func deleteAll() {
        try? context.delete(model: FoodEntry.self)
        try? context.delete(model: ExerciseEntry.self)
        try? context.delete(model: WeightEntry.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
        ReminderService.cancel()
    }
}

/// Plain-language explanation of the method, with sources.
struct GuidelinesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Your daily budget") {
                    Text("We estimate your resting energy with the Mifflin-St Jeor equation, multiply by your everyday activity level, then subtract about 275–825 kcal depending on the pace you chose (0.25–0.75 kg a week). The budget never drops below 1,200 kcal (1,500 for men), per NIH guidance.")
                }
                Section("Food estimates") {
                    Text("Each category and healthiness level maps to a typical calorie range for a regular portion; small is about 60% of that and large about 150%. These are honest ranges, not exact counts — the goal is to spot patterns, not to be perfect.")
                    Text("Healthiness levels follow the USDA MyPlate and Harvard Healthy Eating Plate ideas: half the plate vegetables and fruit, whole grains, lean protein, and fewer fried, sugary or creamy foods.")
                }
                Section("Exercise") {
                    Text("Calories burned use MET values from the Compendium of Physical Activities. Only the energy above resting is added to your budget, so it isn't counted twice.")
                    Text("The weekly target is 150 minutes of moderate activity (or 75 hard), plus strength training on 2 days — the Physical Activity Guidelines for Americans. Hard minutes count double.")
                }
                Section("Weight trend") {
                    Text("Daily weight swings by 1–2 lb from water and salt. We smooth readings with a 10% exponential moving average so you can see the real direction. The weekly rate is the slope of that trend over the last three weeks.")
                }
                Section("Safety") {
                    Text("We recommend losing no more than 0.5–1 kg (1–2 lb) a week (CDC). If your trend drops faster than 1% of your body weight a week, the app will suggest easing off. No calorie cut is set during pregnancy, breastfeeding, or with an eating-disorder history.")
                }
            }
            .navigationTitle("How the numbers work")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }
}

#Preview {
    PreviewHost { profile in
        NavigationStack { SettingsView(profile: profile) }
    }
}
