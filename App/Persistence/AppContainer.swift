import Foundation
import SwiftData

enum AppContainer {
    static let schema = Schema([
        FoodEntry.self,
        DrinkEntry.self,
        ExerciseEntry.self,
        WeightEntry.self,
        UserProfile.self,
    ])

    /// iCloud-synced store. `.automatic` uses the CloudKit container from the entitlements;
    /// if iCloud isn't available (signed out, no entitlement in a dev build) we fall back to local only.
    @MainActor
    static func make(inMemory: Bool = false) -> ModelContainer {
        if !inMemory {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                return container
            }
        }
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }
}
