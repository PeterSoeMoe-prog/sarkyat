import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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
        #if canImport(UIKit)
        return Color(UIColor.label)
        #else
        return Color.primary
        #endif
    }

    var backgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }

    var accentArrowColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondaryLabel)
        #else
        return Color.secondary
        #endif
    }

    var welcomeMessageColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.tertiaryLabel)
        #else
        return Color.secondary.opacity(0.85)
        #endif
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

    var titleGradient: LinearGradient {
        switch self {
        case .light:
            return LinearGradient(colors: [
                Color(red: 0.55, green: 0.50, blue: 0.98),
                Color(red: 0.96, green: 0.48, blue: 0.90),
                Color(red: 0.38, green: 0.84, blue: 0.98)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark:
            return LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var cardFill: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }
}
