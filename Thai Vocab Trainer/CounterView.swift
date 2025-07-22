import SwiftUI
import AudioToolbox
#if canImport(ConfettiSwiftUI)
import ConfettiSwiftUI
#endif
import AVFoundation
import Foundation

extension Notification.Name {
    static let nextVocabulary = Notification.Name("nextVocabulary")
    static let prevVocabulary = Notification.Name("prevVocabulary")
    static let selectVocabularyEntry = Notification.Name("selectVocabularyEntry")
}

struct CounterView: View {
    @Binding var item: VocabularyEntry
    @Binding var allItems: [VocabularyEntry] // shared array
    @Environment(\.dismiss) private var dismiss
    let totalVocabCount: Int
    @State private var recentVocabs: [VocabularyEntry] = []

    @AppStorage("boostType") private var boostTypeRaw: String = BoostType.mins.rawValue
    @AppStorage("boostValue") private var boostValue: Int = 0

    @State private var boostType: BoostType = .mins
    @State private var remaining: Int = 0
    @AppStorage("remainingSeconds") private var storedRemaining: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    // Pause flag persists only until next launch
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false

    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    @State private var selectedIncrement: Int = 5 // remembers per vocab
    private func incrementKey(for id: UUID) -> String { "increment_\(id.uuidString)" }
    @State private var isIncrementWheelActive: Bool = false // Start inactive (20% visible until tapped)
    let increments = [100, 5, 2, 1]
    
    // Determine default increment based on Thai text length
    private func defaultIncrement(for text: String) -> Int {
        let length = text.count
        if length < 6 {
            return 5  // Short text (<6 chars): default to +5
        } else if length <= 10 {
            return 2  // Medium text (7-10 chars): default to +2
        } else {
            return 1  // Long text (>10 chars): default to +1
        }
    }
    
    
    @State private var confettiTrigger: Int = 0
    
    
    @State private var bigCircleScale: CGFloat = 1.0
    @StateObject private var sessionTimer = SessionTimer()
    @State private var sessionCount: Int = 0
    @AppStorage("todayCount") private var todayCount: Int = 0
    @AppStorage("todayDate") private var todayDate: String = ISO8601DateFormatter().string(from: Date())

    @State private var smallCircleScale: CGFloat = 1.0
    @State private var bigCircleRotation: Double = 0
    @State private var smallCircleRotation: Double = 0
    @State private var bigCircleColor: Color = .blue
    @State private var smallCircleColor: Color = .blue

    @State private var previousCount: Int = 0

    private var remainingFormatted: String {
        if boostType == .mins {
            let mins = remaining / 60
            let secs = remaining % 60
            return String(format: "%02d:%02d", mins, secs)
        } else {
            return "\(remaining)"
        }
    }
    
    private var remainingLabel: String {
        switch boostType {
        case .mins:
            return "Time Left"
        case .vocabs:
            return "Vocabs Left"
        case .counts:
            return "Hits Left"
        }
    }

    @State private var sessionTextScale: CGFloat = 1.0
    @State private var sessionTextOpacity: Double = 1.0

    @State private var selectedStatusIndex: Int = 1 // Default to 🔥
    
    @State private var showMenu: Bool = false
    @State private var showCongrats: Bool = false

    @State private var menuOffset: CGSize = CGSize(width: 0, height: 0)
    @State private var dragStartLocation: CGSize = .zero
    
    // Volume control state
    @State private var volumeLevel: Int = 1 // 0: muted, 1: low (default), 2: medium, 3: high
    @State private var lastTTSTriggerSecond: Int = -1 // track last second when TTS fired


    private var sessionDurationFormatted: String {
        let minutes = sessionTimer.sessionDurationSeconds / 60
        let seconds = sessionTimer.sessionDurationSeconds % 60 // <-- Change this line
        return String(format: "%02d:%02d", minutes, seconds)
    }
  

    let statusOptions = ["😫", "🔥", "💎"]
    let statusMapping: [VocabularyStatus] = [.queue, .drill, .ready]

    // Speech handling
    private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
        var onDone: (() -> Void)?
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onDone?()
            onDone = nil
        }
    }
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate = SpeechDelegate()
    
    // Calculate estimated TTS reading time for a Thai text in seconds
    private func calculateTTSReadingTime(for text: String) -> TimeInterval {
        // Average reading speed for Thai is about 5-7 characters per second
        // Using 7.2 characters per second (20% faster than 6) as a baseline
        let charactersPerSecond = 7.2
        let baseTime = Double(text.count) / charactersPerSecond
        
        // Add a minimum base time to account for setup and natural pauses
        return max(baseTime, 1.2) // Reduced minimum time to 1.2 seconds
    }
    
    // Update the session timer's inactivity threshold based on current vocab and increment
    private func updateInactivityThreshold() {
        let readingTime = calculateTTSReadingTime(for: item.thai)
        sessionTimer.updateInactivityThreshold(ttsReadingTime: readingTime, increment: selectedIncrement)
    }
    init(item: Binding<VocabularyEntry>, allItems: Binding<[VocabularyEntry]>, totalVocabCount: Int) {
        _item = item
        _allItems = allItems
        self.totalVocabCount = totalVocabCount
        
        // Initialize selected increment based on text length
        _selectedIncrement = State(initialValue: defaultIncrement(for: item.wrappedValue.thai))
        
        // Initialize boost type from stored value or default to .mins
        self._boostType = State(initialValue: BoostType(rawValue: boostTypeRaw) ?? .mins)
        
        // Only set remaining if there's an actual goal (boostValue > 0)
        if boostValue > 0 {
            if storedRemaining > 0 {
                // If we have stored remaining time, adjust for elapsed time
                let elapsed = boostType == .mins ? Int(Date().timeIntervalSince1970 - remainingTimestamp) : 0
                let adjusted = max(0, storedRemaining - elapsed)
                storedRemaining = adjusted
                self._remaining = State(initialValue: adjusted)
            } else {
                // No stored remaining, use the boost value
                self._remaining = State(initialValue: boostValue)
                storedRemaining = boostValue
            }
        } else {
            // No goal set, ensure remaining is 0
            self._remaining = State(initialValue: 0)
            storedRemaining = 0
        }
        
        // Set selected status index if valid
        if let index = VocabularyStatus.allCases.firstIndex(of: item.wrappedValue.status) {
            _selectedStatusIndex = State(initialValue: index)
        }
        
        // Set up speech synthesizer
        synthesizer.delegate = speechDelegate
    }
    

    var body: some View {
        NavigationStack {
            // MARK: - Root ZStack for Fixed Positioning
            ZStack {
                // Background color
                appTheme.backgroundColor.ignoresSafeArea()
                
                // MARK: - 1. Thai Vocab & Burmese Text Block
                VStack(spacing: 8) {
                    Text(item.thai)
                        .font(.system(size: 36, weight: .regular))
                        .foregroundColor(appTheme.primaryTextColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            speakThai(item.thai)
                        }
                        .contextMenu {
                            Button("Ask this to ChatGPT") {
                                openChatGPT(for: item.thai)
                            }
                            Button("Translate in Google Translate") {
                                openGoogleTranslate(for: item.thai)
                            }
                        }

                    Button(action: {
                        SoundManager.playSound(1104)
                        SoundManager.playVibration()
                        withAnimation {
                            volumeLevel = (volumeLevel + 1) % 4
                        }
                    }) {
                        Text(volumeLevel == 0 ? "🔇" :
                             volumeLevel == 1 ? "🔈" :
                             volumeLevel == 2 ? "🔉" : "🔊")
                            .font(.system(size: 28))
                    }
                    .buttonStyle(PlainButtonStyle())

                    if let burmese = item.burmese {
                        Text(burmese)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 20) // Add horizontal padding for text
                .multilineTextAlignment(.center) // Center align if it wraps
                .offset(y: -330) // Position near the top

                // MARK: - 2. Total Counts Text Block
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                    // Ensure counts block is always centered
                    
                    
                        Text("\(item.count)")
                            .font(.system(size: 62, weight: .heavy, design: .rounded))
                            .italic()
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(colors: [.pink, .purple, .blue, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .mask(
                                        Text("\(item.count)")
                                            .font(.system(size: 62, weight: .heavy, design: .rounded))
                                            .italic()
                                    )
                            )
                            .shadow(color: .white, radius: 0, x: 1, y: 0)
                            .shadow(color: .white, radius: 0, x: -1, y: 0)
                            .shadow(color: .white, radius: 0, x: 0, y: 1)
                            .shadow(color: .white, radius: 0, x: 0, y: -1)
                            // Drop shadow for depth
                            .shadow(color: .black.opacity(0.45), radius: 6, x: 4, y: 4)
                        
                        // Hits Now superscript
                        Text("+\(sessionCount)")
                            .font(.system(size: 24, weight: .thin, design: .rounded))
                            .foregroundColor(.yellow)
                            .offset(x: 40, y: -6)
                                        }

                    Text("counts")
                        .font(.system(size: 12, weight: .thin))
                        .foregroundColor(appTheme.primaryTextColor.opacity(0.7))
                        .offset(y: -3)
                    // Today hits label
                    Text("today \(todayCount)")
                        .font(.system(size: 12, weight: .thin))
                        .foregroundColor(appTheme.primaryTextColor.opacity(0.7))
                        .offset(y: -3)
                }
                .frame(maxWidth: .infinity)
                // Positioned relative to overall layout; adjust vertical offset if needed
                .offset(y: -200) // keep vertical positioning

                // MARK: - 3. Big Circle & Pickers
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 6)
                        .background(
                            Circle().fill(
                                AngularGradient(gradient: Gradient(colors: [.pink, .purple, .blue, .pink]), center: .center)
                            )
                        )
                        .shadow(color: .pink.opacity(0.6), radius: 15)
                        .frame(width: 350, height: 350)
                        .scaleEffect(bigCircleScale)
                        .rotationEffect(.degrees(bigCircleRotation))
                        .overlay(
                            Text("↑")
                                .font(.system(size: 180))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            // Register activity with session timer
                            sessionTimer.registerActivity()
                            
                            // Play standard click sound
                            SoundManager.playSound(1104)
                            SoundManager.playVibration()
                            
                            let oldTotalCount = item.count

                            // Animations for the big circle
                            withAnimation(.easeOut(duration: 0.15)) {
                                bigCircleScale = 1.1
                                bigCircleColor = .green
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    bigCircleScale = 1.0
                                    bigCircleRotation += 360
                                    bigCircleColor = .blue
                                }
                            }
                            
                            // Update counts
                            if item.status != .ready {
                                item.status = .drill
                                selectedStatusIndex = 1 // 🔥 index
                            }
                            item.count += selectedIncrement
                            RecentCountRecorder.shared.record(id: item.id)
                            updateTodayCount(by: selectedIncrement)
                            
                            sessionCount += selectedIncrement
                            
                            if boostType == .counts {
                                remaining = max(0, remaining - selectedIncrement)
                                storedRemaining = remaining
                            }

                            // Animations for session count text
                            withAnimation(.easeOut(duration: 0.2)) {
                                sessionTextScale = 1.3
                                sessionTextOpacity = 1.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, Double(item.thai.count) * 0.1)) {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    sessionTextScale = 1.0
                                    sessionTextOpacity = 0.6
                                }
                            }

                            // Play the system cheer sound (1025) if a new hundred count is reached
                            if item.count / 100 > oldTotalCount / 100 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    SoundManager.playSound(1025) // This is for the hundred milestone
                                }
                            }
                            
                            previousCount = item.count
                        }

                    // Status Picker (positioned relative to the ZStack, not the circle)
                    Button(action: {
                        SoundManager.playSound(1104)
                        SoundManager.playVibration()
                        selectedStatusIndex = (selectedStatusIndex + 1) % statusOptions.count
                        if selectedStatusIndex < statusMapping.count {
                            let oldStatus = item.status
                            let newStatus = statusMapping[selectedStatusIndex]
                            item.status = newStatus

                            if boostType == .vocabs {
                                if oldStatus != .ready && newStatus == .ready {
                                    if remaining > 0 { remaining -= 1; storedRemaining = remaining }
                                } else if oldStatus == .ready && newStatus != .ready {
                                    remaining += 1
                                    storedRemaining = remaining
                                }
                            }

                            if newStatus == .ready {
                                // Trigger congratulations overlay
                                queueCongrats(for: item.thai)
                            }
                        }
                    }) {
                        Text(statusOptions[selectedStatusIndex])
                            .font(.system(size: 58))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 110, height: 216)
                    .clipped()
                    .offset(x: -145, y: -200) // Adjusted offset for new ZStack
                    
                    // Increment Picker with tap-to-activate
                    ZStack {
                        // Background tap area (only active when wheel is faded)
                        if !isIncrementWheelActive {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isIncrementWheelActive = true
                                }
                        }
                        
                        // Picker with fade effect
                        Picker("", selection: $selectedIncrement) {
                            ForEach(increments, id: \.self) { value in
                                Text("+\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 110, height: 216)
                        .clipped()
                        .opacity(isIncrementWheelActive ? 1.0 : 0.2)
                        .animation(.easeInOut, value: isIncrementWheelActive)
                        .onChange(of: selectedIncrement) { _, newVal in
                            isIncrementWheelActive = false
                            updateInactivityThreshold()
                            SoundManager.playSound(1104)
                            SoundManager.playVibration()
                            UserDefaults.standard.set(newVal, forKey: incrementKey(for: item.id))
                        }
                    }
                    .frame(width: 110, height: 216)
                    .offset(x: 150, y: -200) // Aligned within parent
                }
                .offset(y: 30) // Position big circle block (unchanged)

                // MARK: - 4. Small Circle with Section Count Text
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                        .background(
                            Circle().fill(
                                AngularGradient(gradient: Gradient(colors: [.yellow, .orange, .red, .yellow]), center: .center)
                            )
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 10)
                        .frame(width: 100, height: 100)
                        .scaleEffect(smallCircleScale)
                        .rotationEffect(.degrees(smallCircleRotation))
                        .overlay(
                            Text("↓")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            // Register activity to prevent auto-pause
                            sessionTimer.registerActivity()
                            
                            SoundManager.playSound(1052)
                            SoundManager.playVibration()
                            let oldTotalCount = item.count

                            // Animations for the small circle
                            withAnimation(.easeOut(duration: 0.15)) {
                                smallCircleScale = 1.1
                                smallCircleColor = .red
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    smallCircleScale = 1.0
                                    smallCircleRotation += 360
                                    smallCircleColor = .blue
                                }
                            }
                            
                            // Transition status to .drill when practising (unless already .ready)
                            if item.status != .ready {
                                item.status = .drill
                                selectedStatusIndex = 1 // 🔥 index
                            }
                            // Update counts (decrementing)
                            item.count = max(0, item.count - selectedIncrement)
                            sessionCount = max(0, sessionCount - selectedIncrement)
                             updateTodayCount(by: -selectedIncrement)

                             if boostType == .counts {
                                 remaining = min(boostValue, remaining + selectedIncrement)
                                 storedRemaining = remaining
                             }

                            // Play the system cheer sound (1025) if a new hundred count is crossed downwards
                            if item.count / 100 < oldTotalCount / 100 { // Note the '<' for decrement
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    SoundManager.playSound(1025) // This is for the hundred milestone
                                }
                            }
                            
                            previousCount = item.count
                        }

                   
                }
                .offset(x: 120, y: 155) // Move small circle 400px further down

                // MARK: - Congratulations Overlay
                if showCongrats {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(10)
                    VStack(spacing: 30) {
                        HStack {
                            Spacer()
                            Button(action: {
                                showCongrats = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 20)
                        }
                        Text("🎉 Congratulations!")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 4)
                        HStack(spacing: 20) {
                            Button(action: {
                                // Intentionally left blank – functionality removed per user request.
                            }) {
                                Text("10X Play")
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(radius: 8)
                            }
                            
                            Button(action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, Double(item.thai.count) * 0.1)) {
                                    NotificationCenter.default.post(name: .nextVocabulary, object: nil)
                                }
                                showCongrats = false
                            }) {
                                Text("Next »")
                                    .font(.system(size: 28, weight: .bold))
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(radius: 8)
                            }
                        }
                    }
                    .confettiCannon(trigger: $confettiTrigger, num: 100, confettis: [.shape(.circle), .shape(.square)], colors: [.yellow, .orange], repetitions: 1, repetitionInterval: 0.1)
                    .zIndex(11)
                }

                                
                
                // MARK: - Remaining (Bottom Center Overlay)
                VStack(alignment: .center, spacing: 2) {
                    Text(remainingLabel)
                        .font(.system(size: 14, weight: .thin))
                        .foregroundColor(.secondary)

                    // Gradient-masked remaining value
                    Text(remainingFormatted)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: [.pink, .purple, .blue, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text(remainingFormatted)
                                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                                )
                        )
                        .padding(.bottom, 4)

                        // Prev / Next icons
                        HStack(spacing: 40) {
                            // Prev icon – go to previous vocabulary
                            Button(action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: .prevVocabulary, object: nil)
                                }
                            }) {
                                Image(systemName: "arrow.backward")
                                    .font(.system(size: 56))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .offset(x: 20, y: 10)
                            }

                            // Next icon – cycles to another vocab
                            Button(action: {
                                dismiss()
                                // Allow UI dismiss animation before switching
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: .nextVocabulary, object: nil)
                                }
                            }) {
                                Image(systemName: "arrow.forward")
                                    .font(.system(size: 56))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .offset(x: -20, y: -5)
                            }
                        }
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 20)
                .offset(y: -6)

                // MARK: - 6. Session "Duration" (Bottom Right Overlay)
                VStack(alignment: .center, spacing: 2) {
                    Text("Duration")
                        .font(.system(size: 14, weight: .thin))
                        .foregroundColor(.secondary)
                    Text(sessionDurationFormatted)
                        .font(.system(size: 40, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.horizontal, 20)
                .offset(x: -8, y: -61)
                
                if showMenu {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Button(action: { withAnimation { showMenu = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        Text(boostType == .mins ? "Minutes Left" : boostType == .counts ? "Counts Left" : "Vocabs Left")
                            .font(.system(size: 14, weight: .thin))
                            .foregroundColor(.white)
                            .padding(.bottom, -20)
                        Text(remainingFormatted)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(width: 170)
                    .padding(3)
                    .background(
                        LinearGradient(colors: [.cyan, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.9)
                    )
                    .mask(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
                  //  .position(x: UIScreen.main.bounds.width - 80 + menuOffset.width, y: 60 + menuOffset.height)
                    .position(
                        x: UIScreen.main.bounds.width / 2 + menuOffset.width,
                        y: UIScreen.main.bounds.height - 143 + menuOffset.height
                    )

                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                menuOffset = CGSize(width: dragStartLocation.width + value.translation.width,
                                                    height: dragStartLocation.height + value.translation.height)
                            }
                            .onEnded { _ in dragStartLocation = menuOffset }
                    )
                    .transition(.scale)
                    }
                

            } // End of Root ZStack
            .confettiCannon(trigger: $confettiTrigger, num: 100, confettis: [.shape(.triangle), .shape(.circle)], colors: [.yellow, .orange], repetitions: 1, repetitionInterval: 0.1)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    if let category = item.category, !category.isEmpty {
                        HStack(spacing: 8) {
                            NavigationLink(destination: CategoryListView(items: $allItems, category: category)) {
                                let count = allItems.filter { $0.category == category }.count
                                Text("\(category) (\(count))")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(appTheme.primaryTextColor)
                            }
                            
                            Button(action: {
                                let categoryItems = allItems.filter { $0.category == category }
                                NotificationCenter.default.post(
                                    name: .playCategory,
                                    object: nil,
                                    userInfo: ["items": categoryItems]
                                )
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    } else {
                        Text("No Category")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(appTheme.primaryTextColor)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
                        dismiss()
                    }
                }

            }
            // End of NavigationStack content
        .onReceive(sessionTimer.$sessionDurationSeconds) { seconds in
            guard volumeLevel != 0 else { return }
            let interval: Int
            switch volumeLevel {
            case 3: interval = 1   // 🔊 every 1 second
            case 2: interval = 10  // 🔉 every 10 seconds
            case 1: interval = 30  // 🔈 every 30 seconds
            default: interval = Int.max
            }
            if seconds != lastTTSTriggerSecond && seconds > 0 && seconds % interval == 0 {
                lastTTSTriggerSecond = seconds
                if !synthesizer.isSpeaking {
                    speakThai(item.thai)
                }
            }
        }
        .onChange(of: volumeLevel) { _, _ in
            // Reset tracker when user changes the speaker level
            lastTTSTriggerSecond = -1
        }
        } // End of NavigationStack
        // Listen for category selection switching OUTSIDE rebuildable ZStack
        .onReceive(NotificationCenter.default.publisher(for: .selectVocabularyEntry)) { notification in
            if let newEntry = notification.object as? VocabularyEntry {
                // Replace the bound item entirely so the ID matches the selected entry
                item = newEntry
            }
        }
        .onAppear {
                        // Load stored increment for this vocab if available
                        let stored = UserDefaults.standard.integer(forKey: incrementKey(for: item.id))
                        if stored != 0 { selectedIncrement = stored }

            // Set initial inactivity threshold
            updateInactivityThreshold()
            
            if boostType == .mins && boostValue > 0 {
                // start 1-sec timer only if a goal is set
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                    if sessionPaused {
                        timer.invalidate()
                        return
                    }
                    if remaining > 0 {
                        remaining -= 1
                        storedRemaining = remaining
                        remainingTimestamp = Date().timeIntervalSince1970
                    } else {
                        storedRemaining = 0
                        timer.invalidate()
                    }
                }
            }

            previousCount = item.count
            // Only reset session count on appear for a fresh session
            if let idx = VocabularyStatus.allCases.firstIndex(of: item.status) {
                selectedStatusIndex = idx
            }
            sessionCount = 0

    // Auto play Thai pronunciation after 1.2 second delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        speakThai(item.thai)
    }
        }
        .preferredColorScheme(appTheme.colorScheme)
        .onChange(of: remaining) { oldValue, newValue in
            if newValue == 0 && boostValue > 0 {
                if !showCongrats {
                    queueCongrats(for: item.thai)
                    updateRecentVocabs(item)
                }
            }
        }
        .onChange(of: item.id) { oldValue, newValue in
            // Immediately stop any ongoing speech when switching vocabs
            synthesizer.stopSpeaking(at: .immediate)
            SoundManager.fadeOutCurrentSound()
            

            if let idx = VocabularyStatus.allCases.firstIndex(of: item.status) {
                selectedStatusIndex = idx
            }
            selectedIncrement = defaultIncrement(for: item.thai)
            showCongrats = false // hide overlay when new item loads
            
            // Cancel any pending speak operations
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            
            // No need to manually trigger speakThai here as it's already handled by onAppear
            // when the view appears with the new vocab
        }
    }

    private func speakThai(_ text: String) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        // Stop any currently playing sounds with fade out
        SoundManager.fadeOutCurrentSound()
        
        // Store a strong reference to the synthesizer to prevent deallocation
        let synthesizer = self.synthesizer
        
        // Use a small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // If the synthesizer is already speaking, let it finish instead of interrupting.
            guard !synthesizer.isSpeaking else { return }
            
            // Only proceed if we have text to speak
            guard !text.isEmpty else { return }
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
            utterance.rate = 0.45
            
            synthesizer.speak(utterance)
            
            // Debug log – can hook inactivity timer update here
            print("Would update inactivity threshold here")
        }
    }
    
    private func play10XTimes() {
        // Play the last 10 studied vocabs in sequence
        let vocabsToPlay = Array(recentVocabs.prefix(10))
        
        // Play each vocab with appropriate delay
        for (index, vocab) in vocabsToPlay.enumerated() {
            let delay = Double(vocab.thai.count) * 0.1 * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.speakThai(vocab.thai)
                // Add a small pause between vocabs
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(vocab.thai.count) * 0.1) {
                    if index < vocabsToPlay.count - 1 {
                        self.speakThai("") // Small pause
                    }
                }
            }
        }
    }
    
    // Add this function to track recent vocabs
    private func updateRecentVocabs(_ vocab: VocabularyEntry) {
        // Remove duplicates of this vocab
        recentVocabs.removeAll { $0.id == vocab.id }
        // Add to front
        recentVocabs.insert(vocab, at: 0)
        // Keep only last 10
        recentVocabs = Array(recentVocabs.prefix(10))
    }
    
    // MARK: - ChatGPT Helper
    private func openChatGPT(for text: String) {
        #if os(iOS)
        let prompt = "Please explain the Thai word '\(text)' and give usage examples."
        if let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?model=gpt-4o&prompt=\(encoded)") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // MARK: - Google Translate Helper
    private func openGoogleTranslate(for text: String) {
        #if os(iOS)
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://translate.google.com/?sl=th&tl=en&text=\(encoded)&op=translate") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // Queue congrats to run after pronunciation fully completes
    private func queueCongrats(for text: String) {
        // 0.5-second pause before speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speechDelegate.onDone = {
                // 0.5-second pause after speech finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    SoundManager.playSound(1027)
                    SoundManager.playVibration()
                    showCongrats = true
                    confettiTrigger += 1
                    updateRecentVocabs(item)
                }
            }
            speakThai(text)
        }
    }

    // MARK: - Today Count Helper
    private func updateTodayCount(by increment: Int) {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let storedDate = formatter.date(from: todayDate) ?? now
        if !Calendar.current.isDateInToday(storedDate) {
            todayCount = 0
            todayDate = formatter.string(from: now)
        }
        todayCount += increment
    }

  

    // MARK: - Preview Provider (ESSENTIAL FOR XCODE CANVAS)
    struct CounterView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            @State var sampleItem = VocabularyEntry(
                thai: "สวัสดีภาษาไทยยาวมากๆ", // Long Thai text for testing
                burmese: "มิงกะลาบา",
                count: 8100,
                status: .drill
            )
            @State var show = true

            var body: some View {
                CounterView(item: $sampleItem, allItems: .constant([sampleItem]), totalVocabCount: 12345)
                    .frame(width: 350, height: 700)
                    .preferredColorScheme(.dark)
            }
        }

        static var previews: some View {
            PreviewWrapper()
        }
    }
}

// NOTE: Ensure your AppTheme and VocabularyEntry/VocabularyStatus definitions are correct and accessible.
// For example:
// enum AppTheme: String, CaseIterable, Identifiable, Codable {
//     case light, dark
//     var id: String { self.rawValue }
//     var colorScheme: ColorScheme {
//         switch self {
//         case .light: return .light
//         case .dark: return .dark
//         }
//     }
//     var backgroundColor: Color {
//         switch self {
//         case .light: return .white
//         case .dark: return .black
//         }
//     }
//     var primaryTextColor: Color {
//         switch self {
//         case .light: return .black
//         case .dark: return .white
//         }
//     }
// }
//
// struct VocabularyEntry: Identifiable, Codable, Equatable {
//     let id = UUID()
//     var thai: String
//     var burmese: String?
//     var count: Int
//     var status: VocabularyStatus
// }
//
// enum VocabularyStatus: String, Codable, CaseIterable, Equatable {
//     case queue = "😫" // Queue
//     case drill = "🔥" // Drill
//     case ready = "💎" // Ready
// }
//
// extension Notification.Name {
//     static let editVocabularyEntry = Notification.Name("editVocabularyEntry")
// }
