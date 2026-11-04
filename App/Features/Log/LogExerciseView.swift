import SwiftUI
import SwiftData
import LoseWeightCore

struct LogExerciseView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weights: [WeightEntry]

    @State private var type: ExerciseType?
    @State private var intensity: Intensity = .moderate
    @State private var minutes: Double = 30
    @State private var time = Date.now

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let presets: [Double] = [10, 20, 30, 45, 60]

    private var weightKg: Double { weights.first?.kg ?? profile.startWeightKg }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StepSection(number: 1, title: "What did you do?") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(ExerciseType.allCases) { t in
                                ChoiceTile(title: t.displayName, systemImage: t.systemImage, tint: Theme.exercise,
                                           isSelected: type == t) {
                                    withAnimation(.snappy) { type = t }
                                }
                            }
                        }
                    }

                    if type != nil {
                        StepSection(number: 2, title: "How hard was it?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(Intensity.allCases) { i in
                                    ChoiceTile(title: i.displayName, subtitle: i.talkTest, systemImage: i.systemImage,
                                               tint: Theme.exercise, isSelected: intensity == i) {
                                        withAnimation(.snappy) { intensity = i }
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        StepSection(number: 3, title: "For how long?") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    ForEach(presets, id: \.self) { p in
                                        Button(Format.minutes(p)) { minutes = p }
                                            .buttonStyle(.bordered)
                                            .tint(minutes == p ? Theme.exercise : .secondary)
                                    }
                                }
                                Stepper(value: $minutes, in: 5...600, step: 5) {
                                    Text(Format.minutes(minutes))
                                        .font(.title3.weight(.semibold))
                                        .monospacedDigit()
                                }
                                DatePicker("When", selection: $time, in: ...Date.now.addingTimeInterval(3600),
                                           displayedComponents: [.date, .hourAndMinute])
                            }
                            .card()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        summary
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Log exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(type == nil)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        if let type {
            let credited = ExerciseMath.guidelineMinutes(type: type, intensity: intensity, minutes: minutes)
            let kcal = ExerciseMath.netCalories(type: type, intensity: intensity, weightKg: weightKg, minutes: minutes)
            HStack(spacing: 12) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(credited > 0
                         ? "Counts as \(Format.minutes(credited)) toward your 150 a week"
                         : "Great for health. Pick Moderate or Hard to count toward the weekly 150.")
                        .font(.subheadline.weight(.medium))
                    Text(profile.showCalorieNumbers
                         ? "Adds about \(Format.kcal(kcal)) to today's food budget."
                         : "Adds a little room to today's food budget.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .card(padding: 12)
        }
    }

    private func save() {
        guard let type else { return }
        context.insert(ExerciseEntry(timestamp: time, type: type, intensity: intensity, minutes: minutes, weightKg: weightKg))
        dismiss()
    }
}

#Preview {
    PreviewHost { profile in LogExerciseView(profile: profile) }
}
