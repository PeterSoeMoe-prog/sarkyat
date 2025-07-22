import SwiftUI

/// Simple Settings page presented from IntroView.
/// Add more options here as the app grows.
struct SettingsView: View {
    // Persisted theme selection shared with the rest of the app
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    // Dismiss environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appTheme == .dark },
                            set: { newValue in
                                appTheme = newValue ? .dark : .light
                            }
                        ))
                        .tint(.accentColor)
                    }
                    HStack {
                        Text("Sound")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
                            set: { newValue in
                                UserDefaults.standard.set(newValue, forKey: "soundEnabled")
                            }
                        ))
                        .tint(.accentColor)
                    }
                }

                // Data management
                Section("Data") {
                    // Import CSV button with pre-import logic
                    Button("Import CSV") {
                        // Add your pre-import logic here:
                        print("User tapped Import CSV button. Preparing to show file picker...")
                        // You could also show a confirmation alert here if desired.
                        NotificationCenter.default.post(name: Notification.Name("showImportPicker"), object: nil)
                    }
                    Button("Export CSV") {
                        NotificationCenter.default.post(name: Notification.Name("exportCSV"), object: nil)
                    }
                    Button("Clean Duplicates") {
                        NotificationCenter.default.post(name: Notification.Name("cleanDuplicates"), object: nil)
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
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
