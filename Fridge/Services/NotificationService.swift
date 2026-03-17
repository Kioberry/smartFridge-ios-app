import Foundation
import UserNotifications

struct NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func scheduleExpirationNotifications(for items: [FoodItem]) {
        let center = UNUserNotificationCenter.current()
        // Remove old expiration notifications before scheduling new ones
        center.removePendingNotificationRequests(withIdentifiers: items.map { "expiration-\($0.persistentModelID)" })

        for item in items {
            guard let days = item.daysUntilExpiration, days >= 0 else { continue }

            let thresholds = [3, 1, 0]
            for threshold in thresholds {
                guard days >= threshold else { continue }
                let daysUntilNotification = days - threshold

                let content = UNMutableNotificationContent()
                content.sound = .default

                switch threshold {
                case 3:
                    content.title = String(localized: "食材即将过期")
                    content.body = String(localized: "\(item.name) 将在3天后过期，请尽快使用。")
                case 1:
                    content.title = String(localized: "食材明天过期")
                    content.body = String(localized: "\(item.name) 明天就要过期了！")
                case 0:
                    content.title = String(localized: "食材今天过期")
                    content.body = String(localized: "\(item.name) 今天过期，请立即处理。")
                default:
                    break
                }

                let trigger: UNNotificationTrigger
                if daysUntilNotification == 0 {
                    // Fire in 1 second for items expiring today
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                } else {
                    var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    if let day = dateComponents.day {
                        dateComponents.day = day + daysUntilNotification
                    }
                    dateComponents.hour = 9
                    dateComponents.minute = 0
                    trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                }

                let identifier = "expiration-\(item.name)-\(threshold)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
