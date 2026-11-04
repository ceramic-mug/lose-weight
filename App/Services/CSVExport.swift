import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A plain CSV of everything, so people own their data (and can share it with a dietitian).
struct CSVExport: Transferable {
    /// Built up front on the main actor so no database objects cross threads.
    let text: String

    @MainActor
    init(foods: [FoodEntry], exercises: [ExerciseEntry], weights: [WeightEntry]) {
        text = Self.csv(foods: foods, exercises: exercises, weights: weights)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("sensible-export.csv")
            try export.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    @MainActor
    static func csv(foods: [FoodEntry], exercises: [ExerciseEntry], weights: [WeightEntry]) -> String {
        let iso = ISO8601DateFormatter()
        var rows = ["date,kind,item,detail,amount,unit,kcal_low,kcal_high"]
        for f in foods {
            rows.append([
                iso.string(from: f.timestamp), "food", f.category.displayName, "\(f.healthiness.displayName) / \(f.meal.displayName)",
                f.portion.displayName, "portion", String(Int(f.kcalLow)), String(Int(f.kcalHigh)),
            ].map(escape).joined(separator: ","))
        }
        for e in exercises {
            rows.append([
                iso.string(from: e.timestamp), "exercise", e.type.displayName, e.intensity.displayName,
                String(Int(e.minutes)), "min", String(Int(e.netKcal)), String(Int(e.netKcal)),
            ].map(escape).joined(separator: ","))
        }
        for w in weights {
            rows.append([
                iso.string(from: w.timestamp), "weight", "Weight", w.isImported ? "Apple Health" : "Manual",
                String(format: "%.2f", w.kg), "kg", "", "",
            ].map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }
}
