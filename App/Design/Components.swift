import SwiftUI
import LoseWeightCore

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }
}

struct CardHeader: View {
    let title: String
    var systemImage: String?
    var tint: Color = .secondary
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(tint)
            }
            Text(title).font(.headline)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Ring

/// A single progress ring. Past 100% it keeps going with a second, darker lap.
struct ProgressRing: View {
    var fraction: Double
    var tint: Color
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: min(1, fraction - 1))
                    .stroke(tint.mix(with: .black, by: 0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.spring(duration: 0.6), value: fraction)
    }
}

// MARK: - Linear progress

struct GoalBar: View {
    var value: Double
    var goal: Double
    var tint: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(1, goal > 0 ? value / goal : 0))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5), value: value)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    var caption: String?
    var systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card(padding: 14)
    }
}

// MARK: - Selection tiles

/// A big, tappable tile used for every choice in the logging sheets.
struct ChoiceTile: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var tint: Color = Theme.accent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 28)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.9)) : AnyShapeStyle(.secondary))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 74 : 92)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint : Theme.subtleFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct TierDot: View {
    let healthiness: Healthiness
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(healthiness.color)
            .frame(width: size, height: size)
            .accessibilityLabel(healthiness.displayName)
    }
}

struct QuickLogButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundStyle(.white)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyHint: View {
    let text: String
    var systemImage: String = "sparkles"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

// MARK: - Formatting

enum Format {
    static func kcal(_ value: Double) -> String {
        "\(Int((value / 10).rounded() * 10).formatted()) kcal"
    }

    static func kcalRange(_ r: CalorieRange) -> String {
        let lo = Int((r.low / 10).rounded() * 10)
        let hi = Int((r.high / 10).rounded() * 10)
        return lo == hi ? "\(lo.formatted()) kcal" : "\(lo.formatted())–\(hi.formatted()) kcal"
    }

    static func minutes(_ m: Double) -> String {
        let total = Int(m.rounded())
        if total < 60 { return "\(total) min" }
        let h = total / 60, r = total % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    static func percent(_ x: Double) -> String {
        x.formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Log row

/// One logged entry: used on Today and in History.
struct LogRow: View {
    let icon: String
    let title: String
    let detail: String
    var dot: Healthiness?
    let time: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let dot { TierDot(healthiness: dot) }
            Text(time, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

extension FoodEntry {
    func row(showNumbers: Bool) -> LogRow {
        LogRow(icon: category.systemImage,
               title: category.displayName,
               detail: "\(healthiness.displayName) · \(portion.displayName)" + (showNumbers ? " · \(Format.kcalRange(calories))" : ""),
               dot: healthiness,
               time: timestamp)
    }
}

extension ExerciseEntry {
    var row: LogRow {
        LogRow(icon: type.systemImage,
               title: type.displayName,
               detail: "\(Format.minutes(minutes)) · \(intensity.displayName)" + (isFromHealth ? " · Health" : ""),
               time: timestamp)
    }
}

extension WeightEntry {
    func row(units: UnitSystem) -> LogRow {
        LogRow(icon: "scalemass",
               title: units.formatWeight(kg),
               detail: isImported ? "Apple Health" : "Weigh-in",
               time: timestamp)
    }
}

extension DrinkEntry {
    func row(showNumbers: Bool) -> LogRow {
        var parts = [style.sizeName(size)]
        if caffeineMg > 0 { parts.append("\(Int(caffeineMg)) mg") }
        if showNumbers && kcal > 0 { parts.append(Format.kcal(kcal)) }
        return LogRow(icon: kind.systemImage, title: style.displayName,
                      detail: parts.joined(separator: " · "), time: timestamp)
    }
}
