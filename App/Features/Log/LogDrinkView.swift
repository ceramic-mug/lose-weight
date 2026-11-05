import SwiftUI
import SwiftData
import LoseWeightCore

/// What → (which) → how big. The size tap saves. Usuals log in one tap.
struct LogDrinkView: View {
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DrinkEntry.timestamp, order: .reverse) private var history: [DrinkEntry]

    @State private var kind: DrinkKind?
    @State private var style: DrinkStyle?
    @State private var time = Date.now
    @State private var saved = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private let threeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        DatePicker("Time", selection: $time, in: ...Date.now.addingTimeInterval(3600),
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    usuals

                    StepSection(title: "What?") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(DrinkKind.allCases) { k in
                                ChoiceTile(title: k.displayName, systemImage: k.systemImage, tint: Theme.drink,
                                           isSelected: kind == k) { select(k) }
                            }
                        }
                    }

                    if let kind, kind.styles.count > 1 {
                        StepSection(title: "Which?") {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(kind.styles) { s in
                                    ChoiceTile(title: s.displayName, systemImage: kind.systemImage, tint: Theme.drink,
                                               isSelected: style == s) {
                                        withAnimation(.snappy) { style = s }
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if let style {
                        StepSection(title: "How big?") {
                            LazyVGrid(columns: threeColumns, spacing: 10) {
                                ForEach(DrinkSize.allCases) { size in
                                    ChoiceTile(title: style.sizeName(size),
                                               subtitle: subtitle(style, size),
                                               systemImage: sizeIcon(size), tint: Theme.drink,
                                               isSelected: false) { save(style, size) }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Drink")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { ExplainButton(topic: .drinks) }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    /// The most-logged drinks recently, one tap each.
    @ViewBuilder
    private var usuals: some View {
        let picks = usualPicks
        if !picks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(picks, id: \.comboKey) { e in
                        Button { save(e.style, e.size) } label: {
                            Label("\(e.style.shortName) · \(e.style == .espresso ? e.style.sizeName(e.size) : e.size.letter)",
                                  systemImage: e.kind.systemImage)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.drink)
                    }
                }
            }
        }
    }

    private var usualPicks: [DrinkEntry] {
        var counts: [String: (DrinkEntry, Int)] = [:]
        for e in history.prefix(60) {
            counts[e.comboKey] = (counts[e.comboKey]?.0 ?? e, (counts[e.comboKey]?.1 ?? 0) + 1)
        }
        return counts.values.sorted { $0.1 > $1.1 }.prefix(4).map(\.0)
    }

    private func subtitle(_ style: DrinkStyle, _ size: DrinkSize) -> String {
        let spec = style.spec
        let volume = DrinkMath.formatVolume(spec.ml(size), units: profile.units)
        let mg = spec.caffeine(size)
        return mg > 0 ? "\(volume) · \(Int(mg)) mg" : volume
    }

    private func sizeIcon(_ size: DrinkSize) -> String {
        switch size {
        case .small: "s.circle.fill"
        case .medium: "m.circle.fill"
        case .large: "l.circle.fill"
        }
    }

    private func select(_ k: DrinkKind) {
        withAnimation(.snappy) {
            kind = k
            style = k.styles.count == 1 ? k.styles[0] : nil
        }
    }

    private func save(_ style: DrinkStyle, _ size: DrinkSize) {
        context.insert(DrinkEntry(timestamp: time, style: style, size: size))
        saved.toggle()
        dismiss()
    }
}

#Preview {
    PreviewHost { profile in LogDrinkView(profile: profile) }
}
