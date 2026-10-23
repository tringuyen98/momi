import Foundation
import UserNotifications
import Observation
import MomiCore

@MainActor @Observable final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var permission = "Chưa kiểm tra"
    var coverage: Date?
    var truncated = false
    var lastError: String?
    var onAction: ((String, IntakeOccurrence?) -> Void)?
    private var tail: Task<Void, Never>?
    private var generation = 0
    private let center = UNUserNotificationCenter.current()
    override init() {
        super.init()
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: "taken", title: "Đã uống", options: [.authenticationRequired]),
            UNNotificationAction(identifier: "snooze", title: "Nhắc lại sau 15 phút", options: [.authenticationRequired])
        ]
        center.setNotificationCategories([UNNotificationCategory(identifier: "INTAKE", actions: actions, intentIdentifiers: [])])
    }
    func requestPermission() async -> Bool {
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await readPermission(); return allowed
        } catch { lastError = error.localizedDescription; return false }
    }
    func readPermission() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: permission = "Đã bật"
        case .denied: permission = "Đang tắt trong Cài đặt iPhone"
        default: permission = "Chưa cấp quyền"
        }
    }
    func refresh(_ snapshot: Snapshot) {
        generation += 1
        let revision = generation
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self, revision == self.generation else { return }
            await self.apply(snapshot)
        }
    }
    private func apply(_ snapshot: Snapshot) async {
        await readPermission()
        center.removeAllPendingNotificationRequests()
        let plan = ReminderPlanner.make(snapshot: snapshot, now: Date())
        coverage = nil; truncated = plan.truncated; lastError = nil
        guard permission == "Đã bật" else { return }
        do {
            for item in plan.requests {
                let content = UNMutableNotificationContent()
                content.title = snapshot.profile.hideNotificationDetails ? "Momi" : item.title
                content.body = snapshot.profile.hideNotificationDetails ? "Bạn có một lời nhắc." : item.body
                content.sound = .default
                content.userInfo["route"] = item.route
                if let occurrence = item.occurrence {
                    content.categoryIdentifier = "INTAKE"
                    content.userInfo["occurrence"] = try JSONEncoder().encode(occurrence)
                }
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
                components.timeZone = .current
                try await center.add(UNNotificationRequest(identifier: item.id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            }
            coverage = plan.intakeCoverageThrough
        } catch { lastError = "Chưa xếp đủ lời nhắc: " + error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let data = response.notification.request.content.userInfo["occurrence"] as? Data
        let route = response.notification.request.content.userInfo["route"] as? String ?? "today"
        let occurrence = data.flatMap { try? JSONDecoder().decode(IntakeOccurrence.self, from: $0) }
        await MainActor.run {
            self.onAction?(action == UNNotificationDefaultActionIdentifier ? route : action, occurrence)
        }
    }
}
