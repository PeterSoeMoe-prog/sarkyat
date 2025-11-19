import SwiftUI

// Shared model type used for CSV export
// Ensure VocabularyEntry is visible via import or same module

/// Simple Settings page presented from IntroView.
/// Add more options here as the app grows.
struct SettingsView: View {
    // Persisted theme selection shared with the rest of the app
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    // Dismiss environment
    @Environment(\.dismiss) private var dismiss
    // Share sheet state
    @State private var shareURL: ShareItem?
    // File importer state
    @State private var isImporting = false
    // Alerts
    @State private var exportError: String?
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appTheme == .dark },
                            set: { newValue in appTheme = newValue ? .dark : .light }
                        ))
                        .tint(.accentColor)
                    }
                    HStack {
                        Text("Sound")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
                            set: { newValue in UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
                        ))
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
                        DispatchQueue.global(qos: .userInitiated).async {
                            // Load current items from storage
                            var items: [VocabularyEntry] = []
                            if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
                               let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData) {
                                items = decoded
                            }
                            do {
                                let url = try CSVManager.makeTempCSV(from: items)
                                // Present on main thread after slight delay to ensure sheet is configured properly
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Export Quiz Stats") {
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                let url = try QuizStatsManager.shared.exportQuizStatsToDocuments()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Clean Duplicates") {
                        NotificationCenter.default.post(name: Notification.Name("cleanDuplicates"), object: nil)
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
                                        // Save to UserDefaults
                                        if let encoded = try? JSONEncoder().encode(importedItems) {
                                            UserDefaults.standard.set(encoded, forKey: "vocab_items")
                                        }
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
        .alert("Failed to export CSV", isPresented: Binding<Bool>(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        // Import result alert
        .alert("Import CSV", isPresented: Binding<Bool>(
            get: { importMessage != nil },
            set: { _ in importMessage = nil }
        )) {
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
