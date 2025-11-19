import SwiftUI
import UserNotifications

@main
struct Thai_Vocab_TrainerApp: App {
    @StateObject private var themeManager = ThemeManager()
    @State private var items: [VocabularyEntry] = []

    init() {
        // copyCSVToDocumentsIfNeeded() // disabled legacy CSV copy
        _items = State(initialValue: loadSavedOrCSV())
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
            IntroView(
                totalCount: totalCount(),
                vocabCount: items.count,
                queueCount: statusCount(.queue),
                drillCount: statusCount(.drill),
                readyCount: statusCount(.ready)
            )
            .environmentObject(themeManager)
        }
    }

    private func loadSavedOrCSV() -> [VocabularyEntry] {
        if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
           let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData) {
            return decoded
        } else {
            return loadCSV(from: "vocab")
        }
    }

    private func statusCount(_ status: VocabularyStatus) -> Int {
        items.filter { $0.status == status }.count
    }

    private func totalCount() -> Int {
        items.reduce(0) { $0 + $1.count }
    }

    private func daysCount() -> Int {
        let calendar = Calendar.current
        let startDateComponents = DateComponents(year: 2023, month: 6, day: 19)
        guard let startDate = calendar.date(from: startDateComponents) else { return 0 }
        let today = Date()
        let daysPassed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        return daysPassed + 1
    }

    private func loadCSV(from filename: String) -> [VocabularyEntry] {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("\(filename).csv")

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("Failed to read CSV from Documents folder")
            return []
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var entries: [VocabularyEntry] = []

        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // skip header
            let cols = line.components(separatedBy: ",")
            if cols.count >= 4 {
                let status = VocabularyStatus(rawValue: cols[3].capitalized) ?? .queue
                let count = Int(cols[2]) ?? 0
                let burmese = cols[1].isEmpty ? nil : cols[1]
                let category = cols.count > 4 ? (cols[4].isEmpty ? nil : cols[4]) : nil
                entries.append(VocabularyEntry(thai: cols[0], burmese: burmese, count: count, status: status, category: category))
            }
        }
        return entries
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
