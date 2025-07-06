import Foundation
import Combine // Import Combine for the timer publisher

class SessionTimer: ObservableObject {
    // @Published makes this property observable by SwiftUI views
    @Published var sessionDurationSeconds: Int = 0

    // This is the timer publisher. .autoconnect() starts it immediately.
    private var timerCancellable: AnyCancellable?

    init() {
        // We set up the subscription when the object is initialized
        startTimer()
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Increment the duration every second
                self?.sessionDurationSeconds += 1
            }
    }

    // You can add a method to stop the timer if needed, e.g., when the view disappears
    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // Method to reset the timer duration
    func reset() {
        sessionDurationSeconds = 0
    }
}
