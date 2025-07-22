import Foundation
import Combine
import SwiftUI

#if os(iOS)
import UIKit
#endif

class SessionTimer: ObservableObject {
    @Published private(set) var sessionDurationSeconds: Int = 0
    private var timerCancellable: AnyCancellable?
    private var lastInteractionTime: Date = Date()
    private var inactivityThreshold: TimeInterval = 10 // Default to 10s, will be updated
    @Published private(set) var isPaused: Bool = true
    private(set) var hasStarted: Bool = false
    #if os(iOS)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    init() {
        print("🆕 SessionTimer initialized - Timer starts paused")
        setupObservers()
        // Don't start timer yet - wait for first tap
    }
    
    private func setupObservers() {
        #if os(iOS)
        // Listen for app state changes on iOS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppMovedToBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Listen for taps anywhere in the app
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.cancelsTouchesInView = false
        
        // Get the first window scene's first window (iOS 15+ compatible)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addGestureRecognizer(tapGesture)
        }
        #else
        // On non-iOS platforms, we'll just log for now
        print("⏱️ Platform not iOS - some timer features may be limited")
        #endif
    }
    
    @objc private func handleTap() {
        // Only register activity if we've already started the timer
        if hasStarted {
            registerActivity()
        }
    }
    
    private func setupTimer() {
        // Cancel any existing timer
        stopTimer()
        
        print("\n⏱️ Setting up timer at \(Date())")
        print("   - Current thread: \(Thread.current)")
        print("   - Run loop: \(RunLoop.current)")
        print("   - Timer will fire on main thread: \(Thread.isMainThread)")
        
        // Start background task to keep timer running in background
        #if os(iOS)
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        #endif
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTimerTick()
            }
    }
    
    // Update the inactivity threshold based on TTS reading time and increment
    func updateInactivityThreshold(ttsReadingTime: TimeInterval, increment: Int) {
        let newThreshold = ttsReadingTime * Double(increment)
        print("⏱️ Updated inactivity threshold: \(newThreshold)s (TTS: \(ttsReadingTime)s × \(increment))")
        inactivityThreshold = newThreshold
    }
    
    private func handleTimerTick() {
        print("\n⏱️ Timer tick at \(Date())")
        print("   - Current state: hasStarted=\(hasStarted), isPaused=\(isPaused)")
        print("   - Inactivity threshold: \(inactivityThreshold)s")
        
        guard hasStarted else {
            print("   - ❌ Ignoring tick - timer not started yet")
            return
        }
        
        let inactiveTime = Date().timeIntervalSince(lastInteractionTime)
        let formattedTime = String(format: "%.1f", inactiveTime)
        print("   - Inactive for \(formattedTime)s")
        
        // Check if we should pause due to inactivity
        if !isPaused && inactiveTime >= inactivityThreshold {
            print("⏸️ Pausing due to inactivity (threshold: \(inactivityThreshold)s)")
            pause()
            return
        }
        
        // Only count time when not paused and within active session
        if !isPaused {
            sessionDurationSeconds += 1
            print("   - Active study time: \(sessionDurationSeconds)s")
        }
    }
    
    #if os(iOS)
    @objc private func handleAppMovedToBackground() {
        print("📱 App moved to background - pausing timer")
        pause()
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("📱 App will enter foreground - timer state preserved")
    }
    #else
    // Empty implementations for non-iOS platforms
    private func handleAppMovedToBackground() {}
    private func handleAppWillEnterForeground() {}
    #endif
    
    @objc private func resetInactivityTimer() {
        if hasStarted && !isPaused {
            lastInteractionTime = Date()
        }
        if isPaused {
            resume()
        }
    }
    
    private func pause() {
        guard !isPaused else { return }
        isPaused = true
        print("⏸ Timer paused")
    }
    
    private func resume() {
        guard isPaused else { return }
        isPaused = false
        print("▶️ Timer resumed")
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        #if os(iOS)
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        #endif
    }
    
    func registerActivity() {
        print("\n🔄 registerActivity called at \(Date())")
        print("   - Current state: hasStarted=\(hasStarted), isPaused=\(isPaused), lastInteraction=\(lastInteractionTime.timeIntervalSinceNow * -1) seconds ago")
        
        // Update last interaction time first
        lastInteractionTime = Date()
        
        // Handle first tap
        if !hasStarted {
            print("   - 🎯 FIRST TAP DETECTED - Starting timer")
            hasStarted = true
            isPaused = false
            setupTimer() // Start the timer on first tap
            print("   - Timer started successfully. New state: hasStarted=\(hasStarted), isPaused=\(isPaused)")
            return
        }
        
        // Handle resuming from pause
        if isPaused {
            print("   - ▶️ Resuming from pause")
            resume()
        } else {
            print("   - ✅ Activity registered, timer active")
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    func reset() {
        sessionDurationSeconds = 0
        isPaused = true
        hasStarted = false
        lastInteractionTime = Date()
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }
}
