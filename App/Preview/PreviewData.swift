import SwiftUI
import SwiftData
import LoseWeightCore

/// Wraps a preview with an in-memory store full of 10 weeks of realistic sample data.
struct PreviewHost<Content: View>: View {
    @ViewBuilder var content: (UserProfile) -> Content

    @State private var container: ModelContainer
    @State private var profile: UserProfile

    init(@ViewBuilder content: @escaping (UserProfile) -> Content) {
        self.content = content
        let (container, profile) = PreviewData.make()
        _container = State(initialValue: container)
        _profile = State(initialValue: profile)
    }

    var body: some View {
        content(profile)
            .environment(AppRouter())
            .environment(HealthKitService())
            .modelContainer(container)
            .tint(Theme.accent)
    }
}

@MainActor
enum PreviewData {
    static func make(days: Int = 70) -> (ModelContainer, UserProfile) {
        let container = AppContainer.make(inMemory: true)
        let context = container.mainContext
        let cal = Calendar.current
        var rng = SeededRandom(seed: 42)

        let profile = UserProfile()
        profile.hasOnboarded = true
        profile.sex = .female
        profile.birthYear = cal.component(.year, from: .now) - 42
        profile.heightCm = 165
        profile.startWeightKg = 86
        profile.goalWeightKg = 79
        profile.activity = .sedentary
        profile.units = .imperial
        profile.showCalorieNumbers = true
        profile.startDate = cal.date(byAdding: .day, value: -days, to: .now)!
        context.insert(profile)

        let today = cal.startOfDay(for: .now)
        for i in stride(from: days, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -i, to: today)!
            func at(_ h: Int, _ m: Int = 0) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: day)! }
            let isToday = i == 0
            // Habits improve over time.
            let progress = 1 - Double(i) / Double(days)

            // Weight: ~0.35 kg/week loss with daily noise.
            if rng.next() < 0.85 || isToday {
                let kg = 86 - 0.05 * Double(days - i) + (rng.next() - 0.5) * 1.2
                context.insert(WeightEntry(timestamp: at(7), kg: kg))
            }

            let meals: [(Int, MealSlot)] = isToday ? [(8, .breakfast), (12, .lunch)] : [(8, .breakfast), (12, .lunch), (19, .dinner)]
            for (hour, slot) in meals {
                let category: FoodCategory = {
                    let r = rng.next()
                    switch slot {
                    case .lunch: return r < 0.35 ? .cafeteria : (r < 0.6 - progress * 0.2 ? .fastFood : .homeCooked)
                    case .dinner: return r < 0.15 ? .restaurant : (r < 0.3 - progress * 0.1 ? .fastFood : .homeCooked)
                    default: return r < 0.2 ? .packaged : .homeCooked
                    }
                }()
                let r = rng.next()
                let tier: Healthiness = r < 0.25 + progress * 0.25 ? .lighter : (r < 0.8 ? .balanced : .indulgent)
                let portion: Portion = rng.next() < 0.2 ? .large : (rng.next() < 0.25 ? .small : .regular)
                context.insert(FoodEntry(timestamp: at(hour, 15), category: category, healthiness: tier, portion: portion, meal: slot))
            }
            if rng.next() < 0.6 {
                context.insert(FoodEntry(timestamp: at(15, 30), category: .snack,
                                         healthiness: rng.next() < 0.5 ? .lighter : .indulgent, portion: .regular, meal: .snack))
            }
            context.insert(DrinkEntry(timestamp: at(7, 30), style: .latte, size: .medium))
            if rng.next() < 0.6 { context.insert(DrinkEntry(timestamp: at(13), style: .blackCoffee, size: .medium)) }
            if rng.next() < 0.25 { context.insert(DrinkEntry(timestamp: at(15, 30), style: .coldBrew, size: .large)) }
            for h in [9, 12, 17] where rng.next() < 0.7 { context.insert(DrinkEntry(timestamp: at(h), style: .water, size: .medium)) }
            if rng.next() < 0.2 { context.insert(DrinkEntry(timestamp: at(19), style: .regularSoda, size: .medium)) }

            // Exercise: walks most days, some strength and cycling.
            if rng.next() < 0.45 + progress * 0.3 {
                context.insert(ExerciseEntry(timestamp: at(18), type: .walk, intensity: rng.next() < 0.6 ? .moderate : .vigorous,
                                             minutes: [20, 30, 40][Int(rng.next() * 3)], weightKg: 84))
            }
            if cal.component(.weekday, from: day) == 3 || (cal.component(.weekday, from: day) == 6 && progress > 0.5) {
                context.insert(ExerciseEntry(timestamp: at(6, 30), type: .strength, intensity: .moderate, minutes: 30, weightKg: 84))
            }
            if cal.component(.weekday, from: day) == 7, rng.next() < 0.7 {
                context.insert(ExerciseEntry(timestamp: at(10), type: .cycle, intensity: .moderate, minutes: 45, weightKg: 84))
            }
        }
        return (container, profile)
    }
}

/// Deterministic generator so previews look the same every time.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    /// Uniform value in 0..<1.
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
