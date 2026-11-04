import SwiftUI
import SwiftData
import LoseWeightCore

struct LogWeightView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(HealthKitService.self) private var health
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weights: [WeightEntry]

    /// In the user's display unit (lb or kg).
    @State private var value: Double = 0
    @State private var date = Date.now
    @State private var didLoad = false

    private var units: UnitSystem { profile.units }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    TextField("Weight", value: $value, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text(units.weightSymbol).font(.title3).foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    nudge(-1, "minus")
                    nudge(1, "plus")
                }

                if let last = weights.first {
                    Text("\(units.formatWeightChange(units.kg(fromDisplay: value) - last.kg)) vs \(last.timestamp.formatted(.dateTime.weekday(.abbreviated)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()

                Button(action: save) {
                    Text("Save").font(.headline).frame(maxWidth: 320, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.weight)
                .controlSize(.large)
                .disabled(!isValid)
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.pageBackground)
            .navigationTitle("Weight")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .trend) }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                value = units.displayWeight(fromKg: weights.first?.kg ?? profile.startWeightKg)
                value = (value * 10).rounded() / 10
            }
        }
    }

    private var isValid: Bool {
        let kg = units.kg(fromDisplay: value)
        return kg > 25 && kg < 350
    }

    private func nudge(_ direction: Double, _ symbol: String) -> some View {
        Button {
            value = ((value + direction * units.weightStep) * 10).rounded() / 10
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 64, height: 48)
        }
        .buttonStyle(.bordered)
        .tint(Theme.weight)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(direction > 0 ? "Increase" : "Decrease")
    }

    private func save() {
        let kg = units.kg(fromDisplay: value)
        // One reading per day: replace any manual entry for the same day.
        for existing in weights where Calendar.current.isDate(existing.timestamp, inSameDayAs: date) && !existing.isImported {
            context.delete(existing)
        }
        let entry = WeightEntry(timestamp: date, kg: kg)
        context.insert(entry)
        if profile.useHealth {
            Task {
                entry.healthKitID = await health.saveWeight(kg: kg, date: date)
            }
        }
        dismiss()
    }
}

#Preview {
    PreviewHost { profile in LogWeightView(profile: profile) }
}
