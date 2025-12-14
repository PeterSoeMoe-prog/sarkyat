import SwiftUI

// Shared model type used for CSV export
// Ensure VocabularyEntry is visible via import or same module

/// Simple Settings page presented from IntroView.
/// Add more options here as the app grows.
struct SettingsView: View {
    // Persisted theme selection shared with the rest of the app
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @EnvironmentObject private var vocabStore: VocabStore

    // Dismiss environment
    @Environment(\.dismiss) private var dismiss
    // Share sheet state
    @State private var shareURL: ShareItem?
    // File importer state
    @State private var isImporting = false
    // Alerts
    @State private var exportError: String?
    @State private var importMessage: String?

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { appTheme == .dark },
            set: { newValue in appTheme = newValue ? .dark : .light }
        )
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
            set: { newValue in UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
        )
    }

    private var isShowingExportError: Binding<Bool> {
        Binding<Bool>(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )
    }

    private var isShowingImportMessage: Binding<Bool> {
        Binding<Bool>(
            get: { importMessage != nil },
            set: { _ in importMessage = nil }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: darkModeBinding)
                        .tint(.accentColor)
                    }
                    HStack {
                        Text("Sound")
                        Spacer()
                        Toggle("", isOn: soundEnabledBinding)
                        .tint(.accentColor)
                    }
                }

                // Data management
                Section("Data") {
                    // Import CSV button with pre-import logic
                    Button("Import CSV") {
                        isImporting = true
                    }
                    Button("Export CSV") {
                        Task.detached(priority: .userInitiated) {
                            do {
                                let snapshot = await MainActor.run { vocabStore.items }
                                let url = try CSVManager.makeTempCSV(from: snapshot)
                                await MainActor.run {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                await MainActor.run {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Export Quiz Stats") {
                        Task.detached(priority: .userInitiated) {
                            do {
                                let url = try QuizStatsManager.shared.exportQuizStatsToDocuments()
                                await MainActor.run {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                await MainActor.run {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Clean Duplicates") {
                        vocabStore.cleanDuplicates()
                    }
                }

                // Quiz settings placeholder
                Section("Quiz Setting") {
                    NavigationLink {
                        QuizSettingsView()
                    } label: {
                        Text("Quiz Settings")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Respect selected colour scheme
        .preferredColorScheme(appTheme.colorScheme)
        // Share sheet driven by item binding
        .sheet(item: $shareURL) { item in
            ActivityView(activityItems: [item.url])
        }
        // File importer for CSV
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            defer { isImporting = false }
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        if String(data: data, encoding: .utf8) != nil {
                            // Parse CSV on background queue to avoid blocking UI
                            DispatchQueue.global(qos: .userInitiated).async {
                                let importedItems: [VocabularyEntry] = [] // CSV parsing disabled for now
                                DispatchQueue.main.async {
                                    if importedItems.isEmpty {
                                        importMessage = "Imported 0 items (functionality not implemented yet)."
                                    } else {
                                        // CSV-only persistence: apply to store
                                        vocabStore.setItems(importedItems)
                                        importMessage = "Imported \(importedItems.count) items."
                                    }
                                }
                            }
                        }
                    } catch {
                        importMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                importMessage = "Import cancelled: \(error.localizedDescription)"
            }
        }
        // Export error alert
        .alert("Failed to export CSV", isPresented: isShowingExportError) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        // Import result alert
        .alert("Import CSV", isPresented: isShowingImportMessage) {
            Button("OK", role: .cancel) { importMessage = nil }
        } message: {
            Text(importMessage ?? "-")
        }
    }
}

#if DEBUG
// Simple wrapper to make URL identifiable for .sheet(item:)
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
