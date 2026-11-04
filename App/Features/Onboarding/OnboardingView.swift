import SwiftUI
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

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step), total: Double(lastStep))
                .tint(Theme.accent)
                .padding(.horizontal)
                .padding(.top)
                .opacity(step == 0 ? 0 : 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case 0: welcome
                    case 1: AboutYouStep(draft: $draft)
                    case 2: SafetyStep(draft: $draft)
                    case 3: ActivityStep(draft: $draft)
                    case 4: GoalStep(draft: $draft)
                    default: FinishStep(draft: $draft)
                    }
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
                Button(step == lastStep ? "Start" : (step == 0 ? "Get started" : "Continue")) {
                    if step == lastStep { finish() } else { withAnimation(.snappy) { step += 1 } }
                }
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
        case 1: draft.isAdult && draft.weightKg > 25 && draft.heightCm > 100
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
                feature("fork.knife", "Log meals in three taps", "Where it came from, how healthy, and how much. That's it.")
                feature("figure.walk", "Track movement simply", "Type and minutes. Apple Health workouts come in automatically.")
                feature("chart.line.downtrend.xyaxis", "See real progress", "A smoothed weight trend, clear charts, and a weekly report card.")
                feature("stethoscope", "Built on medical guidelines", "Targets follow NIH, CDC and USDA advice for safe, steady loss.")
            }
            Text("This app gives general guidance, not medical advice. If you have a health condition, take medication that affects weight, or plan a big change, talk to your doctor first.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
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
    var pregnant = false
    var eatingDisorderHistory = false
    var useHealth = false
    var reminderEnabled = true
    var showCalories = false

    var age: Int { Calendar.current.component(.year, from: .now) - birthYear }
    var isAdult: Bool { age >= 18 }
    var maintenanceOnly: Bool { pregnant || eatingDisorderHistory }

    var profile: Profile {
        Profile(sex: sex, ageYears: age, heightCm: heightCm, weightKg: weightKg, goalWeightKg: goalWeightKg,
                activity: activity, pace: pace, maintenanceOnly: maintenanceOnly)
    }

    func apply(to p: UserProfile) {
        p.sex = sex
        p.birthYear = birthYear
        p.units = units
        p.heightCm = heightCm
        p.startWeightKg = weightKg
        p.goalWeightKg = maintenanceOnly ? weightKg : goalWeightKg
        p.activity = activity
        p.pace = pace
        p.maintenanceOnly = maintenanceOnly
        p.useHealth = useHealth
        p.reminderEnabled = reminderEnabled
        p.showCalorieNumbers = showCalories
    }
}

// MARK: - Steps

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct AboutYouStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "About you", subtitle: "Used to estimate how much energy your body needs each day.")

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
                    ForEach((year - 100)...(year - 10), id: \.self) { Text(String($0)).tag($0) }
                }
                .labelsHidden()
            }
            if !draft.isAdult {
                Label("This app is designed for adults. For under-18s, weight goals should be set with a pediatrician.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.indulgent)
            }

            HeightField(heightCm: $draft.heightCm, units: draft.units)
            WeightField(title: "Current weight", kg: $draft.weightKg, units: draft.units)
        }
        .card()
        .onChange(of: draft.weightKg) { _, newValue in
            draft.goalWeightKg = (newValue * 0.95 * 10).rounded() / 10
        }
    }
}

struct SafetyStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "A couple of safety questions", subtitle: "Some situations call for a doctor-guided plan instead of a calorie deficit. Your answers stay on your devices.")

        VStack(alignment: .leading, spacing: 16) {
            Toggle("I'm pregnant or breastfeeding", isOn: $draft.pregnant)
            Toggle("I have a history of an eating disorder", isOn: $draft.eatingDisorderHistory)
        }
        .card()

        if draft.maintenanceOnly {
            Label {
                Text("We'll set your target to **maintenance** — no calorie cut. You can still track healthy choices and movement. Please work with your doctor or a registered dietitian on any weight goals.")
            } icon: {
                Image(systemName: "heart.text.square").foregroundStyle(Theme.accent)
            }
            .font(.subheadline)
            .card()
        }
    }
}

struct ActivityStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepTitle(title: "How active is a normal day?", subtitle: "Not counting workouts — you'll log those separately and they add to your budget.")

        VStack(spacing: 10) {
            ForEach(ActivityLevel.allCases) { level in
                Button {
                    draft.activity = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName).font(.headline)
                            Text(level.example).font(.subheadline).foregroundStyle(.secondary)
                        }
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

        StepTitle(title: "Set a first goal", subtitle: "Losing just 5–10% of your weight improves blood pressure, blood sugar and cholesterol. You can always set a new goal later.")

        if draft.maintenanceOnly {
            Text("You're in maintenance mode, so there's no weight-loss goal to set.").card()
        } else {
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
                WeightField(title: "Goal weight", kg: $draft.goalWeightKg, units: units)
                if draft.goalWeightKg < minGoal {
                    Label("That's below a healthy weight for your height. The lowest goal we'll set is \(units.formatWeight(minGoal, decimals: 0)).",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.indulgent)
                }
                Text("Current BMI \(bmi.formatted(.number.precision(.fractionLength(1)))) — \(TargetCalculator.bmiCategory(bmi).lowercased()). BMI is a rough screening tool; it doesn't account for muscle, age or ethnicity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Text("Pace").font(.headline)
                Picker("Pace", selection: $draft.pace) {
                    ForEach(LossPace.allCases) { p in
                        Text("\(p.displayName) · \(units.formatWeight(p.kgPerWeek, decimals: units == .metric ? 2 : 1))/wk").tag(p)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text("The CDC recommends 1–2 lb (0.5–1 kg) a week at most. Slower is easier to stick with.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .card()
        }

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your daily food budget").font(.headline)
                Text(target.limitedByFloor
                     ? "Capped at a safe minimum, so loss may be a bit slower than the pace you picked."
                     : "Logged exercise adds to this each day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        StepTitle(title: "Last touches", subtitle: "Make it work the way you like.")

        VStack(alignment: .leading, spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect Apple Health")
                        Text("Import workouts and smart-scale weigh-ins; save your weight to Health.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Toggle(isOn: $draft.reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening reminder")
                    Text("One gentle nudge a day at 8 pm.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $draft.showCalories) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show calorie numbers")
                    Text("Off keeps things simple: you'll see percentages and plain-language feedback.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()

        Label("Your data stays private in your iCloud account and syncs between your iPhone and Mac. No account, no ads.", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Fields

struct WeightField: View {
    let title: String
    @Binding var kg: Double
    let units: UnitSystem

    var body: some View {
        let display = Binding<Double>(
            get: { (units.displayWeight(fromKg: kg) * 10).rounded() / 10 },
            set: { kg = units.kg(fromDisplay: $0) }
        )
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, value: display, format: .number.precision(.fractionLength(0...1)))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(units.weightSymbol).foregroundStyle(.secondary)
                Stepper(title, value: display, in: 30...700, step: units == .metric ? 0.5 : 1)
                    .labelsHidden()
            }
        }
    }
}

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
