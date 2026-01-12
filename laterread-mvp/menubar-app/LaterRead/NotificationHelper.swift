import Foundation
import UserNotifications

// ============== 通知助手 ==============
class NotificationHelper {
    static let shared = NotificationHelper()

    private init() {}

    // 检查是否在有效的 app bundle 中运行
    var isRunningInBundle: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    /// 发送本地通知
    func send(title: String, body: String) {
        // 如果不在 bundle 中运行（开发模式），只打印日志
        guard isRunningInBundle else {
            print("[Notification] \(title): \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    /// 请求通知权限
    func requestPermission() {
        guard isRunningInBundle else {
            print("[LaterRead] Running without bundle - notifications disabled")
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}

