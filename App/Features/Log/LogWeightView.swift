import SwiftUI
import SwiftData
import LoseWeightCore

struct LogWeightView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(HealthKitService.self) private var health
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weights: [WeightEntry]

    @State private var kg: Double = 0
    @State private var date = Date.now
    @State private var didLoad = false

    private var units: UnitSystem { profile.units }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                WeightWheel(kg: $kg, units: units)

                if let last = weights.first {
                    Text("\(units.formatWeightChange(kg - last.kg)) vs \(last.timestamp.formatted(.dateTime.weekday(.abbreviated)))")
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
                let start = weights.first?.kg ?? profile.startWeightKg
                kg = units.kg(fromDisplay: (units.displayWeight(fromKg: start) * 10).rounded() / 10)
            }
        }
    }

    private var isValid: Bool { kg > 25 && kg < 350 }

    private func save() {
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
