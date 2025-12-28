import Foundation
import UserNotifications
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Cross-platform group background colors
#if canImport(UIKit)
private let groupBackgroundColor: Color = Color(UIColor.systemGroupedBackground)
private let secondaryGroupBackgroundColor: Color = Color(UIColor.secondarySystemGroupedBackground)
#elseif canImport(AppKit)
private let groupBackgroundColor: Color = Color(NSColor.windowBackgroundColor)
private let secondaryGroupBackgroundColor: Color = Color(NSColor.underPageBackgroundColor)
#else
private let groupBackgroundColor: Color = Color.gray.opacity(0.06)
private let secondaryGroupBackgroundColor: Color = Color.gray.opacity(0.09)
#endif

/// Manages local notifications for vocabulary learning reminders
class NotificationEngine: ObservableObject {
    static let shared = NotificationEngine()
    
    @Published var pendingNotifications: [VocabNotification] = []
    @Published var hasPermission: Bool = false
    
    private let storageKey = "pendingVocabNotifications"
    
    struct VocabNotification: Codable, Identifiable {
        let id: UUID
        let vocabID: UUID
        let thaiWord: String
        let burmeseTranslation: String?
        let targetCount: Int
        let createdAt: Date
        let scheduledFor: Date
        var isDelivered: Bool
        
        init(vocabID: UUID, thaiWord: String, burmeseTranslation: String?, targetCount: Int = 100) {
            self.id = UUID()
            self.vocabID = vocabID
            self.thaiWord = thaiWord
            self.burmeseTranslation = burmeseTranslation
            self.targetCount = targetCount
            self.createdAt = Date()
            // Schedule notification for 1 hour from now
            self.scheduledFor = Date().addingTimeInterval(3600)
            self.isDelivered = false
        }
    }
    
    private init() {
        loadPendingNotifications()
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // Convert an integer into Myanmar numerals (e.g., 300 -> ၃၀၀)
    private func toMyanmarNumerals(_ number: Int) -> String {
        let map: [Character: Character] = [
            "0": "၀", "1": "၁", "2": "၂", "3": "၃", "4": "၄",
            "5": "၅", "6": "၆", "7": "၇", "8": "၈", "9": "၉"
        ]
        let s = String(number)
        return String(s.map { map[$0] ?? $0 })
    }
    
    // MARK: - Schedule Notification for Failed Quiz
    
    /// Schedule a notification when user fails to select correct vocab in quiz
    func scheduleFailedQuizNotification(vocabID: UUID, thaiWord: String, burmeseTranslation: String?) {
        // Check if notification already exists for this vocab
        if pendingNotifications.contains(where: { $0.vocabID == vocabID && !$0.isDelivered }) {
            print("⚠️ Notification already scheduled for \(thaiWord)")
            return
        }
        
        let notification = VocabNotification(
            vocabID: vocabID,
            thaiWord: thaiWord,
            burmeseTranslation: burmeseTranslation,
            targetCount: 100
        )
        
        pendingNotifications.append(notification)
        savePendingNotifications()
        
        // Schedule the actual system notification
        scheduleSystemNotification(for: notification)
        
        print("✅ Scheduled notification for '\(thaiWord)' - practice 100 counts")
    }
    
    private func scheduleSystemNotification(for notification: VocabNotification) {
        let content = UNMutableNotificationContent()
        content.title = "📚 Practice Queue"
        let myanmarCount = toMyanmarNumerals(notification.targetCount)
        content.body = "'\(notification.thaiWord)' ကို ကျွမ်းကျင်ဖို့ အခေါက် (\(myanmarCount)) ရွတ်ပါ။"
        if let burmese = notification.burmeseTranslation {
            content.subtitle = burmese
        }
        content.sound = .default
        content.badge = NSNumber(value: pendingNotifications.filter { !$0.isDelivered }.count)
        
        // Attach vocab ID to notification for deep linking
        content.userInfo = [
            "vocabID": notification.vocabID.uuidString,
            "thaiWord": notification.thaiWord,
            "targetCount": notification.targetCount,
            "notificationID": notification.id.uuidString
        ]
        
        // Trigger after 1 hour
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("✅ System notification scheduled for '\(notification.thaiWord)'")
            }
        }
    }
    
    // MARK: - Handle Notification Tap
    
    /// Mark notification as delivered and return vocab ID for opening
    func handleNotificationTap(notificationID: String) -> UUID? {
        guard let index = pendingNotifications.firstIndex(where: { $0.id.uuidString == notificationID }) else {
            return nil
        }
        
        pendingNotifications[index].isDelivered = true
        savePendingNotifications()
        
        return pendingNotifications[index].vocabID
    }
    
    // MARK: - Clear Notifications
    
    func clearDeliveredNotifications() {
        pendingNotifications.removeAll { $0.isDelivered }
        savePendingNotifications()
    }
    
    func cancelNotification(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        pendingNotifications.removeAll { $0.id == id }
        savePendingNotifications()
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotifications.removeAll()
        savePendingNotifications()
    }
    
    // MARK: - Persistence
    
    private func savePendingNotifications() {
        if let encoded = try? JSONEncoder().encode(pendingNotifications) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadPendingNotifications() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VocabNotification].self, from: data) else {
            return
        }
        pendingNotifications = decoded
    }
    
    // MARK: - Badge Count
    
    func updateBadgeCount() {
        let undelivered = pendingNotifications.filter { !$0.isDelivered }.count
        UNUserNotificationCenter.current().setBadgeCount(undelivered)
    }
}

// (Removed NotificationCenter-based routing; we now route via AppRouter directly)

// MARK: - Notification View

struct NotificationListView: View {
    @ObservedObject var engine = NotificationEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let pending = engine.pendingNotifications.filter { !$0.isDelivered }
                    if pending.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No practice reminders")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Failed quiz words will appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(pending) { notification in
                            SwipeToDeleteCard(notification: notification) {
                                withAnimation {
                                    engine.cancelNotification(id: notification.id)
                                }
                            }
                            .onTapGesture {
                                // Mark delivered and update badge
                                _ = NotificationEngine.shared.handleNotificationTap(notificationID: notification.id.uuidString)
                                NotificationEngine.shared.updateBadgeCount()
                                // Dismiss notifications page first, then route via AppRouter
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    AppRouter.shared.openCounter(id: notification.vocabID)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(groupBackgroundColor)
            .navigationTitle("Next Kick-off")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Swipe to Delete Wrapper
struct SwipeToDeleteCard: View {
    let notification: NotificationEngine.VocabNotification
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @GestureState private var dragState: CGFloat = 0
    
    private let deleteThreshold: CGFloat = -80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 80)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .cornerRadius(16)
            }
            
            // Card content
            NotificationCard(notification: notification)
                .offset(x: offset + dragState)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .updating($dragState) { value, state, _ in
                            // Only update for left swipe
                            if value.translation.width < 0 {
                                state = value.translation.width
                            }
                        }
                        .onChanged { gesture in
                            // Only allow left swipe (negative offset)
                            if gesture.translation.width < 0 {
                                isSwiping = true
                            }
                        }
                        .onEnded { gesture in
                            let finalOffset = offset + gesture.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if finalOffset < deleteThreshold {
                                    // Swipe far enough - delete
                                    offset = -500 // Slide off screen
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onDelete()
                                    }
                                } else {
                                    // Snap back
                                    offset = 0
                                }
                                isSwiping = false
                            }
                        }
                )
        }
    }
}

struct NotificationCard: View {
    let notification: NotificationEngine.VocabNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.thaiWord)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let burmese = notification.burmeseTranslation {
                        Text(burmese)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if notification.isDelivered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Text("100")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: notification.isDelivered ? "checkmark.circle.fill" : "flame.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(notification.isDelivered ? "Completed" : "Drill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(secondaryGroupBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func timeUntilString(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval < 0 {
            return "Ready now"
        }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}
