import SwiftUI
#if os(macOS)
import AppKit
#endif
import SwiftData
import LoseWeightCore

/// A short, friendly setup. Everything can be changed later in Settings.
struct OnboardingView: View {
    let existing: UserProfile?

    @Environment(\.modelContext) private var context
    @Environment(HealthKitService.self) private var health

    @State private var step = 0
    @State private var draft = ProfileDraft()

    private let lastStep = 5
    private let stepTitles = ["Welcome", "About you", "Weight", "Activity", "Goal", "Options"]

    var body: some View {
        #if os(macOS)
        macBody
        #else
        phoneBody
        #endif
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcome
        case 1: AboutYouStep(draft: $draft)
        case 2: WeightStep(draft: $draft)
        case 3: ActivityStep(draft: $draft)
        case 4: GoalStep(draft: $draft)
        default: FinishStep(draft: $draft)
        }
    }

    private var primaryTitle: String { step == lastStep ? "Start" : (step == 0 ? "Get started" : "Continue") }

    private func advance() {
        guard canContinue else { return }
        if step == lastStep { finish() } else { withAnimation(.snappy) { step += 1 } }
    }

    #if os(macOS)
    /// Mac: a setup-assistant layout with the steps listed on the left and keyboard shortcuts.
    private var macBody: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sensible").font(.title2.weight(.bold))
                        Text("weight loss").foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stepTitles.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(i < step ? Theme.accent : (i == step ? Theme.accent.opacity(0.15) : Color.clear))
                                Circle().strokeBorder(i <= step ? Theme.accent : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                if i < step {
                                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                } else {
                                    Text("\(i + 1)").font(.caption2.weight(.semibold))
                                        .foregroundStyle(i == step ? Theme.accent : .secondary)
                                }
                            }
                            .frame(width: 22, height: 22)
                            Text(stepTitles[i])
                                .fontWeight(i == step ? .semibold : .regular)
                                .foregroundStyle(i <= step ? .primary : .secondary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        // Jump back to any step already done.
                        .onTapGesture { if i < step { withAnimation(.snappy) { step = i } } }
                    }
                }
                Spacer()
                Text("General guidance, not medical advice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(width: 250, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.subtleFill)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        stepContent
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 40)
                    .frame(maxWidth: 600, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.opacity)
                }
                Divider()
                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation(.snappy) { step -= 1 } }
                            .keyboardShortcut(.cancelAction)
                    }
                    Spacer()
                    Button(primaryTitle, action: advance)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                        .disabled(!canContinue)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .background(Theme.pageBackground)
        .tint(Theme.accent)
    }
    #endif

    private var phoneBody: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step), total: Double(lastStep))
                .tint(Theme.accent)
                .padding(.horizontal)
                .padding(.top)
                .opacity(step == 0 ? 0 : 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
            }

            HStack {
                if step > 0 {
                    Button("Back") { withAnimation(.snappy) { step -= 1 } }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(primaryTitle, action: advance)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
            }
            .padding()
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.pageBackground)
        .tint(Theme.accent)
    }

    private var canContinue: Bool {
        switch step {
        case 1: draft.heightCm > 100
        case 2: draft.weightKg > 25
        case 4: draft.goalWeightKg >= TargetCalculator.minimumGoalWeight(heightCm: draft.heightCm) - 0.05
        default: true
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.lighter)
            Text("Lose weight without counting every bite")
                .font(.largeTitle.weight(.bold))
            VStack(alignment: .leading, spacing: 14) {
                feature("fork.knife", "Log a meal in three taps")
                feature("figure.walk", "Track exercise in two")
                feature("chart.line.downtrend.xyaxis", "See your real trend")
            }
            HStack(spacing: 4) {
                Text("Not medical advice.")
                ExplainLink(topic: .safety, title: "Learn more")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func feature(_ icon: String, _ title: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
    }

    private func finish() {
        let profile = existing ?? UserProfile()
        if existing == nil { context.insert(profile) }
        draft.apply(to: profile)
        profile.hasOnboarded = true
        profile.startDate = .now
        profile.updatedAt = .now
        context.insert(WeightEntry(timestamp: .now, kg: draft.weightKg))
        if draft.reminderEnabled {
            Task {
                if await ReminderService.requestPermission() {
                    await ReminderService.schedule(hour: profile.reminderHour, minute: profile.reminderMinute)
                }
            }
        }
    }
}

// MARK: - Draft

struct ProfileDraft {
    var sex: Sex = .unspecified
    var birthYear: Int = Calendar.current.component(.year, from: .now) - 40
    var units: UnitSystem = Locale.current.measurementSystem == .metric ? .metric : .imperial
    var heightCm: Double = 170
    var weightKg: Double = 85
    var goalWeightKg: Double = 80.75
    var activity: ActivityLevel = .sedentary
    var pace: LossPace = .steady
    var useHealth = false
    var reminderEnabled = true
    var showCalories = false

    var age: Int { Calendar.current.component(.year, from: .now) - birthYear }

    var profile: Profile {
        Profile(sex: sex, ageYears: age, heightCm: heightCm, weightKg: weightKg, goalWeightKg: goalWeightKg,
                activity: activity, pace: pace)
    }

    func apply(to p: UserProfile) {
        p.sex = sex
        p.birthYear = birthYear
        p.units = units
        p.heightCm = heightCm
        p.startWeightKg = weightKg
        p.goalWeightKg = goalWeightKg
        p.activity = activity
        p.pace = pace
        p.maintenanceOnly = false
        p.useHealth = useHealth
        p.reminderEnabled = reminderEnabled
        p.showCalorieNumbers = showCalories
    }
}

// MARK: - Steps

private struct StepTitle: View {
    let title: String

    var body: some View {
        Text(title).font(.title.weight(.bold))
    }
}

struct AboutYouStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "About you")

        VStack(alignment: .leading, spacing: 16) {
            Picker("Units", selection: $draft.units) {
                ForEach(UnitSystem.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Sex") {
                Picker("Sex", selection: $draft.sex) {
                    ForEach(Sex.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
            }

            LabeledContent("Birth year") {
                Picker("Birth year", selection: $draft.birthYear) {
                    let year = Calendar.current.component(.year, from: .now)
                    ForEach((year - 100)...(year - 18), id: \.self) { Text(String($0)).tag($0) }
                }
                .labelsHidden()
            }

            HeightField(heightCm: $draft.heightCm, units: draft.units)
        }
        .card()
    }
}

struct WeightStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "Current weight")
        WeightWheel(kg: $draft.weightKg, units: draft.units)
            .card()
            .onChange(of: draft.weightKg) { _, newValue in
                draft.goalWeightKg = (newValue * 0.95 * 10).rounded() / 10
            }
    }
}

struct ActivityStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "A normal day, not counting workouts")

        VStack(spacing: 10) {
            ForEach(ActivityLevel.allCases) { level in
                Button {
                    draft.activity = level
                } label: {
                    HStack {
                        Text(level.displayName).font(.headline)
                        Spacer()
                        Image(systemName: draft.activity == level ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(draft.activity == level ? Theme.accent : .secondary)
                    }
                    .card()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GoalStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        let units = draft.units
        let suggestions = TargetCalculator.suggestedGoals(currentKg: draft.weightKg, heightCm: draft.heightCm)
        let minGoal = TargetCalculator.minimumGoalWeight(heightCm: draft.heightCm)
        let target = TargetCalculator.dailyTarget(for: draft.profile)
        let bmi = TargetCalculator.bmi(weightKg: draft.weightKg, heightCm: draft.heightCm)

        StepTitle(title: "First goal")

        VStack(alignment: .leading, spacing: 16) {
            if !suggestions.isEmpty {
                HStack {
                    ForEach(suggestions.indices, id: \.self) { i in
                        let kg = suggestions[i]
                        Button("−\(i == 0 ? 5 : 10)% · \(units.formatWeight(kg, decimals: 0))") {
                            draft.goalWeightKg = (kg * 10).rounded() / 10
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Text("Goal weight").font(.headline)
            WeightWheel(kg: $draft.goalWeightKg, units: units)
            if draft.goalWeightKg < minGoal {
                Label("Lowest healthy goal: \(units.formatWeight(minGoal, decimals: 0))", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.indulgent)
            }
            LabeledContent("BMI", value: bmi.formatted(.number.precision(.fractionLength(1))))
                .font(.subheadline)
        }
        .card()

        VStack(alignment: .leading, spacing: 10) {
            Text("Pace").font(.headline)
            Picker("Pace", selection: $draft.pace) {
                ForEach(LossPace.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("≈ \(units.formatWeight(draft.pace.kgPerWeek, decimals: units == .metric ? 2 : 1)) a week")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()

        HStack(alignment: .firstTextBaseline) {
            Text("Daily food budget").font(.headline)
            Spacer()
            Text(Format.kcal(target.targetKcal))
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .card()
    }
}

struct FinishStep: View {
    @Binding var draft: ProfileDraft
    @Environment(HealthKitService.self) private var health

    var body: some View {
        StepTitle(title: "Options")

        VStack(alignment: .leading, spacing: 16) {
            Toggle("Daily reminder at 8 pm", isOn: $draft.reminderEnabled)
            Toggle("Show calorie numbers", isOn: $draft.showCalories)
        }
        .card()

        if health.isAvailable {
            Toggle(isOn: Binding(
                get: { draft.useHealth },
                set: { newValue in
                    if newValue {
                        Task { draft.useHealth = await health.requestAuthorization() }
                    } else {
                        draft.useHealth = false
                    }
                }
            )) {
                Label("Apple Health / Watch (optional)", systemImage: "applewatch")
            }
            .card()
        }
    }
}

// MARK: - Fields

struct HeightField: View {
    @Binding var heightCm: Double
    let units: UnitSystem

    var body: some View {
        LabeledContent("Height") {
            switch units {
            case .metric:
                Picker("Height", selection: Binding(get: { Int(heightCm.rounded()) }, set: { heightCm = Double($0) })) {
                    ForEach(120...220, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .labelsHidden()
            case .imperial:
                let parts = Units.cmToFeetInches(heightCm)
                HStack {
                    Picker("Feet", selection: Binding(get: { parts.feet }, set: { heightCm = Units.feetInchesToCm(feet: $0, inches: parts.inches) })) {
                        ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .labelsHidden()
                    Picker("Inches", selection: Binding(get: { parts.inches }, set: { heightCm = Units.feetInchesToCm(feet: parts.feet, inches: $0) })) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                    .labelsHidden()
                }
            }
        }
    }
}

#Preview {
    OnboardingView(existing: nil)
        .environment(HealthKitService())
        .modelContainer(AppContainer.make(inMemory: true))
}
