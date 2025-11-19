import SwiftUI

/// A reusable row view for displaying a single vocabulary entry.
/// Extracted into its own file so it can be used across multiple screens
/// (e.g. `ContentView`, `CategoryWordsView`).
struct VocabularyRowView: View {
    @Binding var item: VocabularyEntry
    @Binding var showBurmeseForID: UUID?
    /// When `true`, the primary label shows the Thai word; otherwise Burmese.
    let showThaiPrimary: Bool
    /// Simple callback for triggering a tap sound from the parent view.
    let playTapSound: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                // Primary label
                Text(showThaiPrimary ? item.thai : item.burmese ?? "N/A")
                    .font(.headline)
                    .foregroundColor(item.status == .ready ? .green : .primary)

                // Secondary label (revealed when eye icon tapped)
                if showBurmeseForID == item.id {
                    Text(showThaiPrimary ? (item.burmese ?? "N/A") : item.thai)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Count & optional category
            HStack(spacing: 4) {
                Text("\(item.count)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                if let category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Toggle eye icon
            Button(action: {
                showBurmeseForID = (showBurmeseForID == item.id) ? nil : item.id
                playTapSound()
            }) {
                Image(systemName: showBurmeseForID == item.id ? "eye.slash.fill" : "eye.fill")
                    .font(.caption)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle()) // Remove default blue tint
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    let entry = VocabularyEntry(thai: "สวัสดี", burmese: "မင်္ဂလာပါ", count: 3, status: .drill, category: "Greeting")
    VocabularyRowView(
        item: .constant(entry),
        showBurmeseForID: .constant(nil),
        showThaiPrimary: true,
        playTapSound: {}
    )
    .padding()
}
#endif
