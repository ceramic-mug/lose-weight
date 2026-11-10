import Foundation
import CoreData
import Observation

/// Watches the iCloud sync events that SwiftData's CloudKit mirroring posts, so Settings
/// can show whether sync is actually working (not just whether iCloud is signed in).
@MainActor
@Observable
final class SyncMonitor {
    static let shared = SyncMonitor()

    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var lastErrorAt: Date?
    private(set) var isSyncing = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let finished = event.endDate
            let succeeded = event.succeeded
            let error = event.error.map { Self.describe($0) }
            MainActor.assumeIsolated {
                SyncMonitor.shared.record(finished: finished, succeeded: succeeded, error: error)
            }
        }
    }

    private func record(finished: Date?, succeeded: Bool, error: String?) {
        guard let finished else { isSyncing = true; return }
        isSyncing = false
        if succeeded {
            lastSuccess = finished
            lastError = nil
        } else if let error {
            lastError = error
            lastErrorAt = finished
        }
    }

    /// Plain-language versions of the errors people actually hit.
    nonisolated static func describe(_ error: Error) -> String {
        let text = "\(error)"
        if text.contains("production schema") || text.contains("Cannot create or modify field")
            || text.contains("Cannot create new type") {
            return "iCloud isn't set up for this app yet (the sync schema needs deploying)."
        }
        if text.contains("quota") || text.contains("QuotaExceeded") { return "Your iCloud storage is full." }
        if text.contains("NotAuthenticated") || text.contains("not authenticated") {
            return "Sign in to iCloud to sync."
        }
        if text.contains("NetworkUnavailable") || text.contains("network") { return "Offline — will sync when connected." }
        return (error as NSError).localizedDescription
    }
}
