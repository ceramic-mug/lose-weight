import SwiftUI
import LoseWeightCore

/// The one place for explanations, so every other screen can stay short.
enum ExplainTopic: String, CaseIterable, Identifiable {
    case food, portions, drinks, effort, budget, trend, reportCard, goals, health, safety, sources
    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Healthiness levels"
        case .portions: "Portions"
        case .drinks: "Drinks and caffeine"
        case .effort: "Exercise effort"
        case .budget: "Daily food budget"
        case .trend: "Weight trend"
        case .reportCard: "Report card"
        case .goals: "Goals and BMI"
        case .health: "Apple Health and Apple Watch"
        case .safety: "Safety"
        case .sources: "Sources"
        }
    }
}

struct ExplainView: View {
    var topic: ExplainTopic?
    /// False when pushed inside an existing navigation stack.
    var showsDone = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            List {
                food
                section(.portions) {
                    ForEach(Portion.allCases) { p in
                        row(p.displayName, "\(p.hint). Counted as \(Format.percent(p.multiplier)) of a regular serving.")
                    }
                }
                section(.drinks) {
                    Text("Pick the drink and its size. Caffeine and calories are typical amounts for that drink, so a homemade cup may differ a little.")
                    Text("Up to 400 mg of caffeine a day is generally safe for healthy adults (FDA). That's about four cups of brewed coffee. Caffeine after 2 pm can affect sleep.")
                    Text("Drink calories count toward your food budget. Sweet drinks — soda, flavored lattes, juice, energy drinks, cocktails — count toward the sweet drinks tip.")
                    DisclosureGroup("Caffeine by drink (medium)") {
                        ForEach(DrinkStyle.allCases.filter { $0.spec.mg[1] > 0 }) { s in
                            LabeledContent(s.displayName, value: "\(Int(s.spec.mg[1])) mg")
                                .font(.footnote)
                        }
                    }
                }
                section(.effort) {
                    ForEach(Intensity.allCases) { i in row(i.displayName, i.talkTest + ".") }
                    Text("The weekly goal is 150 active minutes plus strength training on 2 days (Physical Activity Guidelines for Americans). Every logged minute counts toward the 150. Effort only changes how many calories are added back.")
                }
                section(.budget) {
                    Text("Your budget is the energy your body uses in a day (Mifflin-St Jeor equation × your everyday activity) minus about 275–825 kcal, depending on your pace. It never goes below 1,200 kcal (1,500 for men).")
                    Text("Each meal is an estimate, not an exact count. Within 10% of budget counts as on track.")
                    Text("Exercise adds the calories it burns above resting (Compendium of Physical Activities MET values) back to that day's budget.")
                }
                section(.trend) {
                    Text("Scale weight swings 1–2 lb a day from water and salt. The trend line smooths this out with a 10% moving average. The weekly rate is the slope of the trend over the last three weeks.")
                    Text("For the most consistent readings, weigh in first thing in the morning.")
                }
                section(.reportCard) {
                    row("Food quality · 40", "Lighter = full marks, balanced = 60%, indulgent = 0.")
                    row("Near budget · 20", "Full marks on budget, falling to 0 at 30% over or under.")
                    row("Movement · 30", "Active minutes per week out of 150.")
                    row("Logging · 10", "Share of days with any entry.")
                    Text("A 85+, B 70+, C 55+, D 40+.")
                }
                section(.goals) {
                    Text("Losing 5–10% of your weight improves blood pressure, blood sugar and cholesterol, so it makes a good first goal. Goals below a healthy BMI (18.5) aren't allowed.")
                    Text("BMI is a rough screening tool. It doesn't account for muscle, age or ethnicity.")
                    Text("Aim to lose no more than 1–2 lb (0.5–1 kg) a week. Slower loss is easier to keep off.")
                }
                section(.health) {
                    Text("Optional, and off by default. When it's on, the app imports workouts and smart-scale weigh-ins from Apple Health and saves the weights you log there.")
                    Text("If your watch already records a workout, you don't need to log it too.")
                    Text("Health data is only available on iPhone. Your Mac gets the same entries through iCloud.")
                }
                section(.safety) {
                    Text("Your budget never goes below 1,200 kcal (1,500 for men). If you'd rather not cut calories at all, turn on \"Just maintain my weight\" in Settings.")
                    Text("If your weight drops faster than 1% a week, the app will suggest easing off.")
                    Text("Sensible gives general guidance and is not medical advice. Talk to your doctor or a registered dietitian about your own needs.")
                }
                section(.sources) {
                    ForEach(sources, id: \.self) { Text($0).font(.footnote) }
                }
            }
            .navigationTitle("Explanations")
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .onAppear {
                if let topic { proxy.scrollTo(topic, anchor: .top) }
            }
        }
    }

    private var food: some View {
        section(.food) {
            ForEach(Healthiness.allCases) { h in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: h.systemImage).foregroundStyle(h.color).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.displayName).font(.subheadline.weight(.semibold))
                        Text(h.shortHint).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            DisclosureGroup("Examples by category") {
                ForEach(FoodCategory.allCases) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(c.displayName, systemImage: c.systemImage).font(.subheadline.weight(.semibold))
                        ForEach(Healthiness.allCases) { h in
                            HStack(alignment: .top, spacing: 8) {
                                TierDot(healthiness: h, size: 8).padding(.top, 5)
                                Text(c.examples(for: h)).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func section<Content: View>(_ t: ExplainTopic, @ViewBuilder content: () -> Content) -> some View {
        Section(t.title) { content() }.id(t)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private let sources = [
        "Mifflin MD et al. A new predictive equation for resting energy expenditure. Am J Clin Nutr 1990.",
        "NHLBI. Clinical Guidelines on the Identification, Evaluation, and Treatment of Overweight and Obesity in Adults.",
        "Jensen MD et al. 2013 AHA/ACC/TOS Guideline for the Management of Overweight and Obesity in Adults.",
        "CDC. Losing Weight; Measuring Physical Activity Intensity (talk test).",
        "USDA MyPlate; Harvard T.H. Chan School of Public Health, Healthy Eating Plate.",
        "Dietary Guidelines for Americans, 2020–2025.",
        "U.S. HHS. Physical Activity Guidelines for Americans, 2nd edition, 2018.",
        "Herrmann SD et al. 2024 Adult Compendium of Physical Activities.",
        "U.S. FDA. Spilling the Beans: How Much Caffeine Is Too Much?",
        "USDA FoodData Central (caffeine and energy for beverages).",
    ]
}

/// A small "?" button that opens the explanations page at a topic.
struct ExplainButton: View {
    var topic: ExplainTopic?
    @State private var isShowing = false

    var body: some View {
        Button { isShowing = true } label: { Image(systemName: "questionmark.circle") }
            .accessibilityLabel("Explanations")
            .sheet(isPresented: $isShowing) {
                NavigationStack { ExplainView(topic: topic) }
                    #if os(macOS)
                    .frame(minWidth: 520, minHeight: 600)
                    #endif
            }
    }
}

/// An inline text link that opens the explanations page at a topic.
struct ExplainLink: View {
    var topic: ExplainTopic?
    var title: String = "Learn more"
    @State private var isShowing = false

    var body: some View {
        Button(title) { isShowing = true }
            .buttonStyle(.borderless)
            .sheet(isPresented: $isShowing) {
                NavigationStack { ExplainView(topic: topic) }
                    #if os(macOS)
                    .frame(minWidth: 520, minHeight: 600)
                    #endif
            }
    }
}
