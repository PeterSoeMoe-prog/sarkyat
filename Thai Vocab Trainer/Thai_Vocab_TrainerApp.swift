import SwiftUI
import UserNotifications

@main
struct Thai_Vocab_TrainerApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var vocabStore = VocabStore()
    @StateObject private var router = AppRouter.shared

    init() {
        // Reset paused flag each launch so pause is temporary
        UserDefaults.standard.set(false, forKey: "sessionPaused")
        // Request notification permission and schedule daily reminder
        let center = UNUserNotificationCenter.current()
        // Set delegate to handle notification taps
        center.delegate = NotificationCenterDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                Self.scheduleDailyReminders()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.destination {
                case .intro:
                    let items = vocabStore.items
                    IntroView(
                        totalCount: items.reduce(0) { $0 + $1.count },
                        vocabCount: items.count,
                        queueCount: items.filter { $0.status == .queue }.count,
                        drillCount: items.filter { $0.status == .drill }.count,
                        readyCount: items.filter { $0.status == .ready }.count
                    )
                case .content:
                    ContentView()
                }
            }
            .environmentObject(themeManager)
            .environmentObject(vocabStore)
            .environmentObject(router)
        }
    }

    // MARK: - Notification Scheduling
    private static func scheduleDailyReminders() {
        let center = UNUserNotificationCenter.current()
        // Remove previous reminders with same identifiers
        center.removePendingNotificationRequests(withIdentifiers: ["daily09", "daily13", "daily17", "daily20", "daily22"])

        let notifications: [(id: String, hour: Int, minute: Int, title: String)] = [
            ("daily09", 9, 0, "Hey Peter, Let's Start Study!"),
            ("daily13", 13, 0, "Good Afternoon, Let's Go Further!"),
            ("daily17", 17, 0, "Hey, One Step at A Time!"),
            ("daily20", 20, 0, "You Did Very Well Today And you are not Stopping!"),
            ("daily22", 22, 0, "Let's Make New Record Before Going Bed")
        ]

        for notif in notifications {
            var date = DateComponents()
            date.hour = notif.hour
            date.minute = notif.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = notif.title
            content.sound = .default

            let request = UNNotificationRequest(identifier: notif.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // Debug helper – call manually to fire in 10 seconds
    // One-off test helper (unused)
    private static func scheduleTestNotification() {
        // Remove older test if any
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["testStudyReminder"])
        var date = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        date.hour = 13
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "Test: Hey Peter, Let's Study!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "testStudyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func scheduleDebugNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test: Thai Vocab Trainer"
        content.body = "Notifications are working 🎉"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "debugNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
