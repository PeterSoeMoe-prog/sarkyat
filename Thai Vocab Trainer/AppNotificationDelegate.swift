import Foundation
import UserNotifications
import SwiftUI

// Handles system notification taps and routes to the appropriate vocab counter
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let notificationID = info["notificationID"] as? String
        let vocabIDString = info["vocabID"] as? String
        let thaiWord = info["thaiWord"] as? String
        #if DEBUG
        print("🔔 didReceive notification tap: notificationID=\(notificationID ?? "nil"), vocabID=\(vocabIDString ?? "nil"), thai=\(thaiWord ?? "nil")")
        #endif

        var targetID: UUID? = nil
        if let notificationID {
            targetID = NotificationEngine.shared.handleNotificationTap(notificationID: notificationID)
        }
        if targetID == nil, let vocabIDString, let uuid = UUID(uuidString: vocabIDString) {
            targetID = uuid
        }

        if let id = targetID {
            NotificationEngine.shared.updateBadgeCount()
            Task { @MainActor in
                #if DEBUG
                print("➡️ Routing to Counter via AppRouter id=\(id) thai=\(thaiWord ?? "nil")")
                #endif
                AppRouter.shared.openCounter(id: id)
            }
        }
        completionHandler()
    }

    // Present banner/sound even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
