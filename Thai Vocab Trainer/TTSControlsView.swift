import SwiftUI

/// Reusable playback control bar with Previous / Play-Pause / Next buttons.
///
/// Pass simple booleans to enable/disable edge buttons, and closure callbacks
/// for all three actions so parent views can supply their own logic.
struct TTSControlsView: View {
    let isPlaying: Bool        // true when playback has started
    let isPaused: Bool         // true when currently paused
    let hasPrevious: Bool      // enable / disable previous button
    let hasNext: Bool          // enable / disable next button
    let previousAction: () -> Void
    let togglePlayPauseAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            // Previous Button
            Button(action: previousAction) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(!hasPrevious)
            .foregroundColor(hasPrevious ? .blue : .gray)

            // Play / Pause Button
            Button(action: togglePlayPauseAction) {
                Image(systemName: playPauseIconName)
                    .font(.system(size: 44))
            }
            .foregroundColor(.blue)

            // Next Button
            Button(action: nextAction) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(!hasNext)
            .foregroundColor(hasNext ? .blue : .gray)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    private var playPauseIconName: String {
        if isPlaying {
            return isPaused ? "play.circle.fill" : "pause.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
}

#if DEBUG
struct TTSControlsView_Previews: PreviewProvider {
    static var previews: some View {
        TTSControlsView(
            isPlaying: true,
            isPaused: false,
            hasPrevious: true,
            hasNext: true,
            previousAction: {},
            togglePlayPauseAction: {},
            nextAction: {}
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
