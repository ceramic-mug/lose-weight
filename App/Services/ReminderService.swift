import Foundation
import UserNotifications

/// One gentle daily nudge. No streak-shaming, no spam.
enum ReminderService {
    private static let id = "daily-log-reminder"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Quick check-in"
        content.body = "Take 20 seconds to log today's meals, movement, or weight."
        content.sound = .default
        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        )
        try? await center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
