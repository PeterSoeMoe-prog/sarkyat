import Foundation
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Destination: Equatable {
        case intro
        case content
    }

    enum Sheet: Identifiable, Equatable {
        case settings
        case addWord
        case dailyQuiz
        case editWord(UUID)
        case counter(UUID)

        var id: String {
            switch self {
            case .settings: return "settings"
            case .addWord: return "addWord"
            case .dailyQuiz: return "dailyQuiz"
            case .editWord(let id): return "editWord_\(id.uuidString)"
            case .counter(let id): return "counter_\(id.uuidString)"
            }
        }
    }

    @Published var destination: Destination = .intro
    @Published var sheet: Sheet? = nil

    // ContentView-specific UI commands
    @Published var shouldActivateSearch: Bool = false
    @Published var categoryToOpen: String? = nil
    @Published var tabCategoryToOpen: String? = nil

    func openContent(activateSearch: Bool = false) {
        destination = .content
        if activateSearch { shouldActivateSearch = true }
    }

    func openIntro() {
        destination = .intro
        sheet = nil
        categoryToOpen = nil
        tabCategoryToOpen = nil
        shouldActivateSearch = false
    }

    func openCategory(_ category: String) {
        destination = .content
        categoryToOpen = category
    }

    func openTabCategory(_ category: String) {
        destination = .intro
        sheet = nil
        categoryToOpen = nil
        shouldActivateSearch = false
        tabCategoryToOpen = category
    }

    func openCounter(id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: "lastVocabID")
        destination = .content
        sheet = .counter(id)
    }

    func openEdit(id: UUID) {
        destination = .content
        sheet = .editWord(id)
    }

    func openSettings() {
        sheet = .settings
    }

    func openAddWord() {
        destination = .content
        sheet = .addWord
    }

    func openDailyQuiz() {
        destination = .content
        sheet = .dailyQuiz
    }

    func dismissSheet() {
        sheet = nil
    }

    private init() {}
}
