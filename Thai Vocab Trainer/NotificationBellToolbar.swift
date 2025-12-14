import SwiftUI

struct NotificationBellButton: View {
    @ObservedObject var engine = NotificationEngine.shared
    var action: () -> Void

    var unreadCount: Int { engine.pendingNotifications.filter { !$0.isDelivered }.count }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                if unreadCount > 0 {
                    Text("\(min(unreadCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 8, y: -10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }
}

struct NotificationBellToolbar: ViewModifier {
    @State private var showNotifications = false
    @ObservedObject private var router = AppRouter.shared

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Centered + button in the navigation bar
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        router.openAddWord()
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                // Notification bell remains on the trailing side
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotificationBellButton {
                        showNotifications = true
                        // Optional haptic/sound handled elsewhere globally
                    }
                }
            }
            .fullScreenCover(isPresented: $showNotifications) {
                NotificationListView()
            }
    }
}

extension View {
    func withNotificationBell() -> some View {
        self.modifier(NotificationBellToolbar())
    }
}
