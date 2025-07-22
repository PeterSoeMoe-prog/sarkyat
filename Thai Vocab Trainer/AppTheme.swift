import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case dark // Dark theme
    case light // Light gradient theme
    var id: String { rawValue }

    var iconName: String { "paintbrush.fill" }

    /// Human-readable name shown in Settings
    var displayName: String {
        switch self {
        case .dark:     return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        default: return nil
        }
    }

    var primaryTextColor: Color {
        Color(.label)
    }

    var backgroundColor: Color {
        Color(.systemBackground)
    }

    var accentArrowColor: Color {
        Color(.secondaryLabel)
    }

    var welcomeMessageColor: Color {
        Color(.tertiaryLabel)
    }

    // MARK: - Light theme helpers
    var gradient: LinearGradient {
        switch self {
        case .light:
            return LinearGradient(colors: [
                Color(red: 0.71, green: 0.60, blue: 0.98),
                Color(red: 0.95, green: 0.62, blue: 0.93),
                Color(red: 0.70, green: 0.85, blue: 1.00)
            ], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [backgroundColor, backgroundColor], startPoint: .top, endPoint: .bottom)
        }
    }

    var cardFill: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }
}
