import Foundation
import SwiftData

enum AppContainer {
    /// Whether this launch is syncing through iCloud (shown in Settings).
    @MainActor static private(set) var isCloudSynced = false

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
            _ = SyncMonitor.shared // start listening before the store loads
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                isCloudSynced = FileManager.default.ubiquityIdentityToken != nil
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
