import SwiftUI

@dynamicMemberLookup
final class ThemeManager: ObservableObject {
    // Persist the selected theme in UserDefaults so it survives app restarts
    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "appTheme"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppTheme(rawValue: raw) {
            current = saved
        } else {
            current = .dark
        }
    }

    // Forward any AppTheme properties via dynamic member lookup
    subscript<T>(dynamicMember keyPath: KeyPath<AppTheme, T>) -> T {
        current[keyPath: keyPath]
    }

    // Convenience toggle
    func toggle() {
        current = current == .dark ? .light : .dark
    }
}
