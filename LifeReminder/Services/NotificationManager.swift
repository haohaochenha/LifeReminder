import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "life.task."

    private override init() {
        super.init()
        center.delegate = self
    }

    /// App 在前台时也把提醒弹出来。
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    func status(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    /// 重新同步所有待触发提醒：先清掉旧的，再按当前任务重新排期。
    func sync(tasks: [TaskItem], enabled: Bool) {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self = self else { return }
            let ids = pending.map { $0.identifier }.filter { $0.hasPrefix(self.prefix) }
            if !ids.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            guard enabled else { return }

            let now = Date()
            let calendar = Calendar.current

            for task in tasks where !task.isDone {
                guard let fireDate = calendar.date(byAdding: .minute, value: -task.leadMinutes, to: task.dueDate),
                      fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                if task.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    content.body = "该做这件事啦 · \(Fmt.due(task.dueDate))"
                } else {
                    content.body = task.note
                }
                content.sound = .default
                content.userInfo = ["taskID": task.id.uuidString]

                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                components.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: self.prefix + task.notificationID,
                                                    content: content,
                                                    trigger: trigger)
                self.center.add(request)
            }
        }
    }
}
