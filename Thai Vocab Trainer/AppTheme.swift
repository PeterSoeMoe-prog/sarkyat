import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light, dark // Only light and dark themes
    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .light: return .black
        case .dark: return .white
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .dark: return .black
        }
    }

    var accentArrowColor: Color {
        switch self {
        case .light: return Color.gray.opacity(0.6)
        case .dark: return .white
        }
    }

    var welcomeMessageColor: Color {
        switch self {
        case .light: return Color.gray.opacity(0.7)
        case .dark: return .white
        }
    }
}
