import SwiftUI
import SwiftData
import LoseWeightCore

/// Type → (effort, pre-set to Moderate) → minutes. Tapping a minutes button saves.
struct LogExerciseView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \ExerciseEntry.timestamp, order: .reverse) private var history: [ExerciseEntry]

    @State private var type: ExerciseType?
    @State private var intensity: Intensity = .moderate
    @State private var customMinutes: Double = 30
    @State private var showCustom = false
    @State private var time = Date.now
    @State private var saved = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let presets: [Double] = [10, 20, 30, 45, 60, 90]

    private var weightKg: Double { weights.first?.kg ?? profile.startWeightKg }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        DatePicker("When", selection: $time, in: ...Date.now.addingTimeInterval(3600),
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    StepSection(title: "What?") {
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
                        StepSection(title: "Effort") {
                            Picker("Effort", selection: $intensity) {
                                ForEach(Intensity.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .transition(.opacity)

                        StepSection(title: "Minutes") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(presets, id: \.self) { m in
                                    ChoiceTile(title: "\(Int(m))", systemImage: "timer", tint: Theme.exercise,
                                               isSelected: false) { save(minutes: m) }
                                }
                            }
                            if showCustom {
                                HStack {
                                    Stepper(value: $customMinutes, in: 5...600, step: 5) {
                                        Text(Format.minutes(customMinutes)).font(.title3.weight(.semibold)).monospacedDigit()
                                    }
                                    Button("Save") { save(minutes: customMinutes) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Theme.exercise)
                                }
                                .card(padding: 12)
                            } else {
                                Button("Other…") { withAnimation(.snappy) { showCustom = true } }
                                    .font(.subheadline)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .effort) }
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear {
                // Start from the last effort level used for this kind of thing.
                if let last = history.first { intensity = last.intensity }
            }
            .onChange(of: type) { _, newType in
                if let match = history.first(where: { $0.type == newType }) { intensity = match.intensity }
            }
        }
    }

    private func save(minutes: Double) {
        guard let type else { return }
        context.insert(ExerciseEntry(timestamp: time, type: type, intensity: intensity, minutes: minutes, weightKg: weightKg))
        saved.toggle()
        dismiss()
    }
}

#Preview {
    PreviewHost { profile in LogExerciseView(profile: profile) }
}
