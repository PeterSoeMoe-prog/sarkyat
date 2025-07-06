import SwiftUI

struct BottomSheetView: View {
    @Binding var offset: CGFloat
    @Binding var dragOffset: CGFloat
    let maxHeight: CGFloat

    let queueCount: Int
    let drillCount: Int
    let readyCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .frame(width: 50, height: 8)
                .foregroundColor(Color.secondary.opacity(0.8))
                .padding(.top, 8)

            Text("Vocabulary Status Summary")
                .font(.headline)
                .padding(.bottom, 8)

            HStack(spacing: 24) {
                StatColumnView(label: "😫 Queue", count: queueCount, color: .red, total: totalCount)
                StatColumnView(label: "🔥 Drill", count: drillCount, color: .yellow, total: totalCount)
                StatColumnView(label: "💎 Ready", count: readyCount, color: .green, total: totalCount)
                StatColumnView(label: "🚀 Total", count: totalCount, color: .primary, total: nil)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight)
        .background(.regularMaterial)
        .cornerRadius(16)
        .offset(y: offset + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation.height
                    if offset + dragOffset < 0 {
                        dragOffset = -offset
                    }
                }
                .onEnded { _ in
                    withAnimation(.interactiveSpring()) {
                        offset = (offset + dragOffset > maxHeight / 2) ? maxHeight : 0
                        dragOffset = 0
                    }
                }
        )
        .onAppear {
            offset = maxHeight
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct StatColumnView: View {
    let label: String
    let count: Int
    let color: Color
    let total: Int?

    var body: some View {
        VStack {
            Text(label)
                .font(.subheadline)

            Text("\(count)")
                .font(.title2)
                .bold()
                .foregroundColor(color)

            if let total = total, total > 0 {
                Text("(\(Int((Double(count) / Double(total)) * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
