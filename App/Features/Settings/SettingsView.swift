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

    var body: some View {
        let target = profile.dailyTarget(currentWeightKg: Snapshot(profile: profile, weights: weights).trend.last?.trendKg)
        Form {
            Section("Your plan") {
                LabeledContent("Daily food budget", value: Format.kcal(target.targetKcal))
                LabeledContent("Maintenance", value: Format.kcal(target.maintenanceKcal))
                Picker("Pace", selection: $profile.paceRaw) {
                    ForEach(LossPace.allCases) { p in
                        Text("\(p.displayName) · \(profile.units.formatWeight(p.kgPerWeek, decimals: profile.units == .metric ? 2 : 1))/wk").tag(p.rawValue)
                    }
                }
                .disabled(profile.maintenanceOnly)
                WeightField(title: "Goal weight", kg: $profile.goalWeightKg, units: profile.units)
                    .disabled(profile.maintenanceOnly)
                Toggle("Maintenance only", isOn: $profile.maintenanceOnly)
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
                    Toggle("Apple Health / Watch", isOn: Binding(
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
                }
                Toggle("Daily reminder", isOn: $profile.reminderEnabled)
                if profile.reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminders & Health")
            } footer: {
                if health.isAvailable { Text("Apple Health is optional.") }
            }

            Section("Your data") {
                ShareLink(item: CSVExport(foods: foods, exercises: exercises, weights: weights),
                          preview: SharePreview("Lose Weight export.csv")) {
                    Label("Export as CSV", systemImage: "square.and.arrow.up")
                }
                Button("Delete all data", role: .destructive) { confirmDelete = true }
            }

            Section {
                NavigationLink {
                    ExplainView(showsDone: false)
                } label: {
                    Label("Explanations", systemImage: "questionmark.circle")
                }
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

#Preview {
    PreviewHost { profile in
        NavigationStack { SettingsView(profile: profile) }
    }
}
