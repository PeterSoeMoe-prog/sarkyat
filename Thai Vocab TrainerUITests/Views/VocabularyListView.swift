import SwiftUI
import AudioToolbox
import UIKit

struct VocabularyListView: View {
    @Binding var items: [VocabularyEntry]
    @Binding var filteredItems: [VocabularyEntry]
    @Binding var showBurmeseForID: UUID?
    @Binding var selectedStatus: VocabularyStatus?
    var playTapSound: () -> Void
    var saveItems: () -> Void
    var showThaiPrimary: Bool

    @State private var showCounterSheet = false
    @State private var counterItem: VocabularyEntry? = nil

    private func color(for status: VocabularyStatus) -> Color {
        switch status {
        case .queue: return Color.red.opacity(0.5)
        case .drill: return Color.yellow.opacity(0.5)
        case .ready: return Color.green.opacity(0.5)
        }
    }

    var body: some View {
        List {
            ForEach(filteredItems) { item in
                if let realIndex = items.firstIndex(where: { $0.id == item.id }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: item.status))
                                    .frame(width: 14, height: 14)

                                Text(showThaiPrimary ? item.thai : (item.burmese ?? "No Burmese translation available"))
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playTapSound()
                                counterItem = item
                                showCounterSheet = true
                            }

                            Spacer()
                            Text("\(items[realIndex].count)")
                                .foregroundColor(.gray)
                        }

                        if showBurmeseForID == item.id {
                            Text(showThaiPrimary ? (item.burmese ?? "No Burmese translation available") : item.thai)
                                .foregroundColor(.yellow)
                                .padding(.leading, 28)
                        }
                    }
                    .padding(.vertical, 8)
                    .contextMenu {
                        Button("Queue") { updateStatus(for: item.id, to: .queue) }
                        Button("Drill") { updateStatus(for: item.id, to: .drill) }
                        Button("Ready") { updateStatus(for: item.id, to: .ready) }
                        Button("Edit") {
                            NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            UIPasteboard.general.string = showThaiPrimary ? item.thai : (item.burmese ?? "")
                            playTapSound()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(id: item.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .sheet(isPresented: $showCounterSheet) {
            if let binding = bindingForCounterItem() {
                CounterView(item: binding, isPresented: $showCounterSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                Text("Error loading item")
            }
        }
    }

    private func bindingForCounterItem() -> Binding<VocabularyEntry>? {
        guard let id = counterItem?.id, let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return $items[index]
    }

    private func deleteItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            saveItems()
            playTapSound()
        }
    }

    private func updateStatus(for id: UUID, to newStatus: VocabularyStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = newStatus
            saveItems()
            playTapSound()
        }
    }
}
