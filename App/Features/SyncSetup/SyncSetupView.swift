import SwiftUI
import SwiftData
import LoseWeightCore

#if SYNC_SETUP
/// Only in the one-time "Sync setup" Mac build. Saves one of every record type with every
/// field filled, waits for iCloud to accept them (which creates the database layout in the
/// Development environment), then deletes them. After that, the layout is deployed to
/// Production in CloudKit Console and the TestFlight apps start syncing.
struct SyncSetupView: View {
    @Environment(\.modelContext) private var context
    @State private var status = "Preparing iCloud…"
    @State private var done = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: done ? "checkmark.icloud.fill" : (failed ? "exclamationmark.icloud" : "icloud"))
                .font(.system(size: 64))
                .foregroundStyle(done ? Theme.lighter : (failed ? Theme.indulgent : Theme.accent))
            Text("Sensible sync setup").font(.title.weight(.semibold))
            Text(status)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            if !done && !failed { ProgressView() }
            if done {
                Link("Open CloudKit Console", destination: URL(string: "https://icloud.developer.apple.com/dashboard/")!)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(48)
        .frame(minWidth: 620, minHeight: 440)
        .task { await run() }
    }

    private func run() async {
        guard AppContainer.isCloudSynced else {
            fail("This Mac isn't signed in to iCloud. Sign in under System Settings › your name, then reopen this app.")
            return
        }
        let old = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01, out of the way
        let profile = UserProfile()
        profile.hasOnboarded = false
        let food = FoodEntry(timestamp: old, category: .homeCooked, healthiness: .balanced, portion: .regular,
                             meal: .lunch, note: "sync setup")
        let drink = DrinkEntry(timestamp: old, style: .latte, size: .medium)
        let exercise = ExerciseEntry(timestamp: old, type: .walk, intensity: .moderate, minutes: 1,
                                     weightKg: 70, healthKitID: "sync-setup")
        let weight = WeightEntry(timestamp: old, kg: 70, healthKitID: "sync-setup", isImported: true)
        let samples: [any PersistentModel] = [profile, food, drink, exercise, weight]
        samples.forEach { context.insert($0) }

        status = "Uploading sample records to iCloud…"
        guard save(), await waitForSync(seconds: 120) else { return }

        status = "Cleaning up…"
        samples.forEach { context.delete($0) }
        guard save(), await waitForSync(seconds: 60) else { return }

        done = true
        status = "Done. Last step: in CloudKit Console open the container iCloud.com.ceramicmug.loseweight, choose Deploy Schema Changes, then Deploy. After that the iPhone and Mac apps sync. You can delete this app."
    }

    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            fail("Couldn't save: \(error.localizedDescription)")
            return false
        }
    }

    /// Waits for a sync event that finishes after now, then reports any error.
    private func waitForSync(seconds: Int) async -> Bool {
        let start = Date.now
        for _ in 0..<seconds {
            try? await Task.sleep(for: .seconds(1))
            let monitor = SyncMonitor.shared
            if let error = monitor.lastError, let at = monitor.lastErrorAt, at > start, !monitor.isSyncing {
                fail("iCloud said: \(error)")
                return false
            }
            if let last = monitor.lastSuccess, last > start, !monitor.isSyncing {
                try? await Task.sleep(for: .seconds(3))
                return true
            }
        }
        fail("iCloud didn't respond in time. Check this Mac is online and signed in to iCloud, then reopen the app to try again.")
        return false
    }

    private func fail(_ message: String) {
        failed = true
        status = message
    }
}
#endif
