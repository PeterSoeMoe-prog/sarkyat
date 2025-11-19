import SwiftUI

/// Compact bar that floats at the bottom of the screen, showing the current word and playback controls.
struct MiniPlayerBarView: View {
    let thaiWord: String
    let positionText: String
    let burmeseWord: String?
    @Binding var rate: Double       // speech rate (0.3 - 1.0)
    let isPlaying: Bool
    let isPaused: Bool
    let hasPrevious: Bool
    let hasNext: Bool
    let previousAction: () -> Void
    let togglePlayPauseAction: () -> Void
    let nextAction: () -> Void
    let repeatAllAction: () -> Void
    let isRepeating: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Tiny grab indicator for aesthetics
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 4)

            VStack {
                
                VStack(alignment: .center, spacing: 4) {
                    // Current word label
                    Text(thaiWord)
                        .font(.title3)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if let burmese = burmeseWord, !burmese.isEmpty {
                        Text(burmese)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    Text(positionText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                

                // Playback controls
                
                HStack(spacing: 28) {
                    TTSControlsView(
                        isPlaying: isPlaying,
                        isPaused: isPaused,
                        hasPrevious: hasPrevious,
                        hasNext: hasNext,
                        previousAction: previousAction,
                        togglePlayPauseAction: togglePlayPauseAction,
                        nextAction: nextAction
                    )
                    Button(action: repeatAllAction) {
                        Image(systemName: isRepeating ? "repeat.circle.fill" : "repeat.circle")
                            .font(.system(size: 34))
                            .foregroundColor(isRepeating ? .blue : .gray)
                            .accessibilityLabel("Repeat All")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Speed buttons
            HStack(spacing: 12) {
                ForEach([0.3, 0.5, 0.8, 1.0], id: \.self) { val in
                    Button {
                        rate = val
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        Text(val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val))
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 32, height: 24)
                            .foregroundColor(rate == val ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(rate == val ? Color.blue : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set speed to \(val)")
                }
            }
            .padding(.horizontal, 16)

        }
        .background(.ultraThinMaterial) // blurred backdrop
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

#if DEBUG
struct MiniPlayerBarView_Previews: PreviewProvider {
    static var previews: some View {
        MiniPlayerBarView(
            thaiWord: "สวัสดีครับ",
            positionText: "1 of 10",
            burmeseWord: "မင်္ဂလာပါ",
            rate: .constant(0.5),
            isPlaying: true,
            isPaused: false,
            hasPrevious: true,
            hasNext: true,
            previousAction: {},
            togglePlayPauseAction: {},
            nextAction: {},
            repeatAllAction: {},
            isRepeating: false
        )
    }
}
#endif
