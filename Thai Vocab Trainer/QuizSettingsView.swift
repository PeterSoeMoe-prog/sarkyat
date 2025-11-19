import SwiftUI

struct QuizSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    // Persist a map of category -> included (true/false) as JSON string
    @AppStorage("quizCategoryMapJSON") private var categoryMapJSON: String = ""
    @State private var categories: [String] = []

    var body: some View {
        Form {
            if categories.isEmpty {
                Section {
                    Text("No categories found.")
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Include categories in quiz") {
                    ForEach(categories, id: \.self) { cat in
                        Toggle(isOn: bindingForCategory(cat)) {
                            Text(cat)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quiz Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear(perform: loadCategories)
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !categories.isEmpty {
                    Button("All") { setAll(true) }
                    Button("None") { setAll(false) }
                }
            }
            #endif
        }
    }

    // MARK: - Load categories
    private func loadCategories() {
        // Prefer persisted items from UserDefaults; decode only category field
        struct MinimalEntry: Decodable { let category: String? }
        var cats: [String] = []
        if let data = UserDefaults.standard.data(forKey: "vocab_items"),
           let decoded = try? JSONDecoder().decode([MinimalEntry].self, from: data) {
            cats = decoded
                .compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        categories = Array(Set(cats)).sorted()
        // If no saved map yet, default all included
        if decodeMap().isEmpty {
            setAll(true)
        }
    }

    // MARK: - Persistence helpers
    private func decodeMap() -> [String: Bool] {
        guard let data = categoryMapJSON.data(using: .utf8), !categoryMapJSON.isEmpty else { return [:] }
        if let dict = try? JSONDecoder().decode([String: Bool].self, from: data) {
            return dict
        }
        return [:]
    }

    private func encodeMap(_ map: [String: Bool]) {
        if let data = try? JSONEncoder().encode(map), let s = String(data: data, encoding: .utf8) {
            categoryMapJSON = s
        }
    }

    private func bindingForCategory(_ cat: String) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                let map = decodeMap()
                return map[cat] ?? true // default include
            },
            set: { newValue in
                var map = decodeMap()
                map[cat] = newValue
                encodeMap(map)
            }
        )
    }

    private func setAll(_ value: Bool) {
        var map: [String: Bool] = [:]
        for c in categories { map[c] = value }
        encodeMap(map)
    }
}

#if DEBUG
struct QuizSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { QuizSettingsView() }
    }
}
#endif
