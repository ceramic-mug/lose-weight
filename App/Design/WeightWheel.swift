import SwiftUI
import LoseWeightCore

/// Scroll-wheel weight picker: whole number + tenths, in the user's units. Always shows
/// the full number and can't produce a typo like 1800 lb.
struct WeightWheel: View {
    @Binding var kg: Double
    let units: UnitSystem

    private var range: ClosedRange<Int> { units == .metric ? 30...280 : 70...600 }
    private var tenths: Int { Int((units.displayWeight(fromKg: kg) * 10).rounded()) }

    var body: some View {
        #if os(iOS)
        let whole = Binding<Int>(
            get: { min(max(tenths / 10, range.lowerBound), range.upperBound) },
            set: { set(whole: $0, tenth: tenths % 10) }
        )
        let tenth = Binding<Int>(
            get: { tenths % 10 },
            set: { set(whole: tenths / 10, tenth: $0) }
        )
        HStack(spacing: 0) {
            Picker("Weight", selection: whole) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
            .clipped()
            Text(".").font(.title2.weight(.semibold))
            Picker("Tenths", selection: tenth) {
                ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 56)
            .clipped()
            Text(units.weightSymbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        #else
        // Mac: type it, or nudge with the stepper. Values are kept in a sensible range,
        // so a stray extra digit can't turn 182 into 1820.
        let display = Binding<Double>(
            get: { (units.displayWeight(fromKg: kg) * 10).rounded() / 10 },
            set: { kg = units.kg(fromDisplay: min(max($0, Double(range.lowerBound)), Double(range.upperBound))) }
        )
        HStack(spacing: 8) {
            TextField("Weight", value: display, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .font(.title3.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 96)
            Text(units.weightSymbol).foregroundStyle(.secondary)
            Stepper("Adjust", value: display, in: Double(range.lowerBound)...Double(range.upperBound), step: units.weightStep)
                .labelsHidden()
            Spacer(minLength: 0)
        }
        #endif
    }

    private func set(whole: Int, tenth: Int) {
        kg = units.kg(fromDisplay: Double(whole) + Double(tenth) / 10)
    }
}

/// A Settings row that shows a weight and opens the wheel to change it.
struct WeightRow: View {
    let title: String
    @Binding var kg: Double
    let units: UnitSystem

    var body: some View {
        NavigationLink {
            Form {
                WeightWheel(kg: $kg, units: units)
            }
            .formStyle(.grouped)
            .navigationTitle(title)
        } label: {
            LabeledContent(title, value: units.formatWeight(kg))
        }
    }
}
