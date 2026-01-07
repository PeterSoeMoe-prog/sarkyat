import SwiftUI
import AudioToolbox
#if canImport(ConfettiSwiftUI)
import ConfettiSwiftUI
#endif
import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CoreText

// Shared formatter cache to avoid repeated allocations on hot paths
fileprivate enum Formatters {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// Measure Thai text height to adapt the tappable area for 1-line vs 2-line cases
private struct ThaiTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TodayCountWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TodayDeltaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CounterView: View {
    @Binding var item: VocabularyEntry
    @Binding var allItems: [VocabularyEntry] // shared array
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    let totalVocabCount: Int

    private static var bundledItimFontPostScriptName: String? = nil
    private static var didAttemptRegisterBundledItimFont: Bool = false

    private static var bundledThaiFontPostScriptName: String? = nil
    private static var didAttemptRegisterBundledThaiFont: Bool = false

    private static func resolveBundledItimFontPostScriptName() -> String? {
        if didAttemptRegisterBundledItimFont { return bundledItimFontPostScriptName }
        didAttemptRegisterBundledItimFont = true

        guard let url = Bundle.main.url(forResource: "Itim Regular", withExtension: "otf") else {
            return nil
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider),
              let ps = cgFont.postScriptName as String? else {
            return nil
        }
        bundledItimFontPostScriptName = ps
        return ps
    }

    private static func resolveBundledThaiFontPostScriptName() -> String? {
        if didAttemptRegisterBundledThaiFont { return bundledThaiFontPostScriptName }
        didAttemptRegisterBundledThaiFont = true

        guard let url = Bundle.main.url(forResource: "GMCfnTaffibunDemo", withExtension: "ttf") else {
            return nil
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider),
              let ps = cgFont.postScriptName as String? else {
            return nil
        }
        bundledThaiFontPostScriptName = ps
        return ps
    }

    private let thaiCartoonFontCandidates: [String] = [
        "Mali-Bold",
        "Mali-Regular",
        "Sriracha-Regular",
        "Itim-Regular"
    ]

    private func thaiTitleFont(size: CGFloat) -> Font {
        #if canImport(UIKit)
        if let psName = Self.resolveBundledItimFontPostScriptName(), UIFont(name: psName, size: size) != nil {
            return .custom(psName, size: size)
        }
        if let psName = Self.resolveBundledThaiFontPostScriptName(), UIFont(name: psName, size: size) != nil {
            return .custom(psName, size: size)
        }
        for name in thaiCartoonFontCandidates {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        #endif
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    private func thaiRainbowPalette() -> [Color] {
        if appTheme == .dark {
            return [.cyan, .purple, .pink, .yellow, .green]
        }
        return [
            Color(red: 0.55, green: 0.50, blue: 0.98),
            Color(red: 0.96, green: 0.48, blue: 0.90),
            Color(red: 0.38, green: 0.84, blue: 0.98),
            Color(red: 0.98, green: 0.78, blue: 0.24),
            Color(red: 0.38, green: 0.78, blue: 0.42)
        ]
    }

    private func rainbowAttributedThai(_ text: String) -> AttributedString {
        var out = AttributedString()
        let palette = thaiRainbowPalette()
        var i = 0
        for ch in text {
            var part = AttributedString(String(ch))
            part.foregroundColor = palette.isEmpty ? appTheme.primaryTextColor : palette[i % palette.count]
            out.append(part)
            i += 1
        }
        return out
    }

    @ViewBuilder
    private func outlinedText(_ text: String, font: Font, color: Color, thickness: CGFloat) -> some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .shadow(color: color, radius: 0, x: thickness, y: 0)
            .shadow(color: color, radius: 0, x: -thickness, y: 0)
            .shadow(color: color, radius: 0, x: 0, y: thickness)
            .shadow(color: color, radius: 0, x: 0, y: -thickness)
            .shadow(color: color, radius: 0, x: thickness, y: thickness)
            .shadow(color: color, radius: 0, x: -thickness, y: thickness)
            .shadow(color: color, radius: 0, x: thickness, y: -thickness)
            .shadow(color: color, radius: 0, x: -thickness, y: -thickness)
    }

    @ViewBuilder
    private func thaiTitleView(_ text: String, size: CGFloat) -> some View {
        let font = thaiTitleFont(size: size)
        return Text(rainbowAttributedThai(text))
            .font(font)
    }

    @State private var statsCardPage: Int = 0
    @State private var todayCountTextWidth: CGFloat = 0
    @State private var todayDeltaWidth: CGFloat = 0
    @State private var recentVocabs: [VocabularyEntry] = []
    // Flag to toggle Settings sheet
    @State private var showSettings: Bool = false

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
    let increments = [1, 2, 5]
    // Manage auto-speak scheduling so we can cancel it on user taps
    @State private var autoSpeakWork: DispatchWorkItem? = nil
    // Measured Thai text height to adapt the tap zone for 1-line content
    @State private var thaiTextHeight: CGFloat = 0
    // Fixed Thai area height to keep Burmese in a constant position while Thai baseline stays aligned
    private let thaiAreaHeight: CGFloat = 100

    // Cycle through increments on each tap
    private func cycleIncrement() {
        if let index = increments.firstIndex(of: selectedIncrement) {
            let nextIndex = (index + 1) % increments.count
            selectedIncrement = increments[nextIndex]
            updateInactivityThreshold()
            SoundManager.playSound(1104)
            SoundManager.playVibration()
            UserDefaults.standard.set(selectedIncrement, forKey: incrementKey(for: item.id))
        }
    }
    
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

    private func pickNextID() -> UUID? {
        // Prefer drill -> queue globally; avoid ready items
        if let drill = allItems.first(where: { $0.status == .drill }) { return drill.id }
        if let queue = allItems.first(where: { $0.status == .queue }) { return queue.id }
        return nil
    }

    private func pickPrevID() -> UUID? {
        // Best-effort previous: scan backwards from current index for non-ready items.
        if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            if idx > 0 {
                for j in stride(from: idx - 1, through: 0, by: -1) {
                    if allItems[j].status != .ready { return allItems[j].id }
                }
            }
        }
        return nil
    }

    private func syncBackfillActiveDayKeyIfNeeded() {
        let history = loadStudyHistory()
        let resolved = resolveBackfillActiveDayKey(history: history) ?? ""
        if backfillActiveDayKey != resolved {
            backfillActiveDayKey = resolved
        }
    }

    private func routeToCounter(id: UUID) {
        // Keep the current sheet open; ContentView will swap the sheet item.
        router.openCounter(id: id)
    }
    
    
    @State private var bigCircleScale: CGFloat = 1.0
    @State private var bigCircleGlow: Bool = false
    @StateObject private var sessionTimer = SessionTimer()
    // GIF playback control
    @State private var isGifPlaying: Bool = false
    @State private var lastGifActivity: Date = Date()
    private let gifInactivityInterval: TimeInterval = 10
    @State private var sessionCount: Int = 0
    @State private var sessionTimerVisible: Bool = false
    @AppStorage("todayCount") private var todayCount: Int = 0
    @AppStorage("studyStartDateTimestamp") private var studyStartDateTimestamp: Double = 0
    @AppStorage("studyHistoryJSON") private var studyHistoryJSON: String = ""
    @AppStorage("dailyTargetHits") private var dailyTargetHits: Int = 5000
    @AppStorage("backfillActiveDayKey") private var backfillActiveDayKey: String = ""
    @AppStorage("todayWorkHistoryJSON") private var todayWorkHistoryJSON: String = ""
    @AppStorage("counterPreferredStatsPage") private var counterPreferredStatsPage: Int = -1
    // Leave default empty to avoid constructing a formatter at property init
    @AppStorage("todayDate") private var todayDate: String = ""

    private var startDate: Date {
        let fallback = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        if studyStartDateTimestamp > 0 {
            return Date(timeIntervalSince1970: studyStartDateTimestamp)
        }
        return fallback
    }

    // Comparison vs previous day for the bottom Stat card
    private var yesterdayCount: Int {
        let history = loadTodayWorkHistory()
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return history[dayKey(from: prev)] ?? 0
    }
    private var statPercentString: String {
        let prev = yesterdayCount
        guard prev > 0 else { return "" }
        let change = ((Double(todayCount) - Double(prev)) / Double(prev)) * 100
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.0f%%", sign, change)
    }

    private var missedTargetDaysCount: Int {
        let history = loadStudyHistory()
        let target = max(1, dailyTargetHits)
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: Date())
        guard start <= end else { return 0 }

        var missed = 0
        var current = start
        while current <= end {
            let key = dayKey(from: current)
            let hits = history[key] ?? 0
            if hits < target { missed += 1 }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return missed
    }

    private var missedTargetQty: Int {
        let history = loadStudyHistory()
        let target = max(1, dailyTargetHits)
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: Date())
        guard start <= end else { return 0 }

        var totalMissing = 0
        var current = start
        while current <= end {
            let key = dayKey(from: current)
            let hits = history[key] ?? 0
            if hits < target {
                totalMissing += (target - hits)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return totalMissing
    }

    private var oldestMissedTargetInfo: (key: String?, dateLine: String, remaining: Int?) {
        let history = loadStudyHistory()
        let target = max(1, dailyTargetHits)

        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"

        let resolvedKey = resolveBackfillActiveDayKey(history: history)
        guard let key = resolvedKey else {
            return (key: nil, dateLine: "-", remaining: nil)
        }

        let hits = history[key] ?? 0
        let remaining = max(0, target - hits)
        let dateLine: String
        if let d = Formatters.day.date(from: key) {
            dateLine = f.string(from: d)
        } else {
            dateLine = key
        }
        return (key: key, dateLine: dateLine, remaining: remaining)
    }
    private var statTitle: String {
        if statPercentString.hasPrefix("+") { return "More than Prev Day" }
        if statPercentString.hasPrefix("-") { return "Less than Prev Day" }
        return "Same as Prev Day"
    }

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
    // Daily Quiz sheet flag
    @State private var showQuiz: Bool = false
    @State private var showCalendar: Bool = false
    @State private var showNotes: Bool = false
    @State private var showCongrats: Bool = false
    @State private var congratsTargetDayKey: String? = nil
    @State private var trophyScale: CGFloat = 1.0
    @State private var nextGlowPulse: Bool = false

    @State private var menuOffset: CGSize = CGSize(width: 0, height: 0)
    @State private var dragStartLocation: CGSize = .zero
    
    // Volume control state
    @State private var volumeLevel: Int = 2 // 0: muted, 1: low, 2: medium (default), 3: high
    @State private var lastTTSTriggerSecond: Int = -1 // track last second when TTS fired


    private var sessionDurationFormatted: String {
        let minutes = sessionTimer.sessionDurationSeconds / 60
        let seconds = sessionTimer.sessionDurationSeconds % 60 // <-- Change this line
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 70% screen width for popup buttons
    private var buttonWidth: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width * 0.7
        #else
        return 320
        #endif
    }
  

    private var congratsTargetDateLine: String? {
        guard let key = congratsTargetDayKey else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        if let d = Formatters.day.date(from: key) {
            return f.string(from: d)
        }
        return key
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
        
        // Initialize selected increment: check stored value first, then default based on text length
        let storedIncrement = UserDefaults.standard.integer(forKey: "increment_\(item.wrappedValue.id.uuidString)")
        _selectedIncrement = State(initialValue: storedIncrement != 0 ? storedIncrement : defaultIncrement(for: item.wrappedValue.thai))
        
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
        // Ensure audio session is ready for immediate TTS playback
        configureAudioSession()
    }
    
    // Helper to create small lettered circles with same design as big circle
    private func letterCircle(_ letter: String, size: CGFloat, offset: CGSize, colors: [Color]? = nil, useLinear: Bool = false, action: (() -> Void)? = nil) -> some View {
        let gradientColors = colors ?? [.pink, .purple, .blue, .pink]
        let fillStyle = useLinear ? AnyShapeStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(AngularGradient(gradient: Gradient(colors: gradientColors), center: .center))
        return Circle()
            .stroke(Color.white, lineWidth: 4)
            .background(
                Circle().fill(fillStyle)
            )
            .shadow(color: .pink.opacity(0.6), radius: 10)
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundColor(.white)
            )
            .offset(offset)
            .onTapGesture {
                SoundManager.playSound(1104)
                SoundManager.playVibration()
                action?()
            }
    }

    // MARK: - Category Count Helpers (to keep type-checker happy)
    private func countTotal(in category: String) -> Int {
        allItems.filter { $0.category == category }.count
    }

    private func countQueueDrill(in category: String) -> Int {
        allItems.filter { $0.category == category && ($0.status == .queue || $0.status == .drill) }.count
    }

    private func categoryHeaderText(_ category: String) -> String {
        let qd = countQueueDrill(in: category)
        let total = countTotal(in: category)
        return "\(category) (\(qd)/\(total))"
    }

    // MARK: - Card Component
    private struct StatCard<Content: View>: View {
        let title: String
        let titleColor: Color
        let content: Content
        init(title: String, titleColor: Color = .white, @ViewBuilder content: () -> Content) {
            self.title = title
            self.titleColor = titleColor
            self.content = content()
        }
        var body: some View {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .thin))
                    .foregroundColor(titleColor)
                content
            }
            .padding(12)
            .frame(width: 260, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private func statsMainFontSize(for text: String) -> CGFloat {
        let digitCount = text.filter { $0.isNumber }.count
        return digitCount <= 3 ? 62 : (digitCount == 4 ? 52 : 45)
    }

    private let statsSubtitleHeight: CGFloat = 14

    private var statsCardsRow: some View {
        TabView(selection: $statsCardPage) {
            HStack {
                Spacer(minLength: 0)
                StatCard(title: "To Hit", titleColor: appTheme.primaryTextColor) {
                    VStack(spacing: 4) {
                        ZStack {
                            let countString = oldestMissedTargetInfo.remaining.map { "\($0)" } ?? "-"
                            let fontSize = statsMainFontSize(for: countString)

                            Text(countString)
                                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                .foregroundColor(.clear)
                                .fixedSize()
                                .overlay(
                                    LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .mask(
                                            Text(countString)
                                                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                        )
                                )
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(key: TodayCountWidthKey.self, value: proxy.size.width)
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .onPreferenceChange(TodayCountWidthKey.self) { todayCountTextWidth = $0 }
                        .onPreferenceChange(TodayDeltaWidthKey.self) { todayDeltaWidth = $0 }

                        VStack(spacing: 1) {
                            Text(oldestMissedTargetInfo.key == nil ? "-" : "For \(oldestMissedTargetInfo.dateLine)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .frame(height: statsSubtitleHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .tag(0)

            HStack {
                Spacer(minLength: 0)
                StatCard(title: "Today Hits", titleColor: appTheme.primaryTextColor) {
                    VStack(spacing: 4) {
                        ZStack {
                            let countString = "\(todayCount)"
                            let fontSize = statsMainFontSize(for: countString)

                            Text(countString)
                                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                .foregroundColor(.clear)
                                .fixedSize()
                                .overlay(
                                    LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .mask(
                                            Text(countString)
                                                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                        )
                                )
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(key: TodayCountWidthKey.self, value: proxy.size.width)
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .center)

                            if yesterdayCount > 0 {
                                let isUp = statPercentString.hasPrefix("+")
                                let percentColor: Color = isUp ? .green : .red
                                let numberOnly = statPercentString.replacingOccurrences(of: "%", with: "")

                                VStack(spacing: 0) {
                                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                                        Text(numberOnly)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(percentColor)
                                            .fixedSize()
                                        Text("%")
                                            .font(.system(size: 12, weight: .bold))
                                            .baselineOffset(4)
                                            .foregroundColor(percentColor)
                                    }
                                    Image(systemName: isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(percentColor)
                                }
                                .offset(y: 2)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(key: TodayDeltaWidthKey.self, value: proxy.size.width)
                                    }
                                )
                                .offset(x: (todayCountTextWidth / 2) + (todayDeltaWidth / 2) + 6)
                            }
                        }
                        .onPreferenceChange(TodayCountWidthKey.self) { todayCountTextWidth = $0 }
                        .onPreferenceChange(TodayDeltaWidthKey.self) { todayDeltaWidth = $0 }

                        let lifetimeTotal = allItems.reduce(0) { $0 + $1.count }
                        Text("\(lifetimeTotal.formatted())")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(height: statsSubtitleHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .tag(1)

            HStack {
                Spacer(minLength: 0)
                StatCard(title: "Missed Days", titleColor: appTheme.primaryTextColor) {
                    VStack(spacing: 4) {
                        let countString = "\(missedTargetDaysCount)"
                        let fontSize = statsMainFontSize(for: countString)
                        let effectiveTarget = max(1, dailyTargetHits)

                        Text(countString)
                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                            .foregroundColor(.clear)
                            .fixedSize()
                            .overlay(
                                LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .mask(
                                        Text(countString)
                                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                    )
                            )
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 1) {
                            Text("\(missedTargetQty.formatted()) Hits (\(effectiveTarget.formatted())/Day)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .frame(height: statsSubtitleHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .tag(2)

            HStack {
                Spacer(minLength: 0)
                StatCard(title: remainingLabel, titleColor: appTheme.primaryTextColor) {
                    VStack(spacing: 4) {
                        let fontSize = statsMainFontSize(for: remainingFormatted)
                        Text(remainingFormatted)
                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .mask(
                                        Text(remainingFormatted)
                                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                    )
                            )
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(" ")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.clear)
                            .frame(height: statsSubtitleHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .tag(3)

            HStack {
                Spacer(minLength: 0)
                StatCard(title: "Session", titleColor: appTheme.primaryTextColor) {
                    VStack(spacing: 4) {
                        let fontSize = statsMainFontSize(for: sessionDurationFormatted)
                        Text(sessionDurationFormatted)
                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .mask(
                                        Text(sessionDurationFormatted)
                                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                                    )
                            )
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(" ")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.clear)
                            .frame(height: statsSubtitleHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 140)
        .onAppear {
            if counterPreferredStatsPage >= 0 {
                statsCardPage = counterPreferredStatsPage
                counterPreferredStatsPage = -1
            } else {
                statsCardPage = 0
            }
        }
    }

    @ViewBuilder
    private var congratsOverlayView: some View {
        if showCongrats {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(10)
                .onAppear {
                    print("🎉 DEBUG: Congratulations popup appeared!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        #if os(iOS)
                        SoundManager.playSound(1027)
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.prepare()
                        generator.impactOccurred()
                        print("📳 DEBUG: Heavy vibration triggered")
                        #endif
                    }
                }
            VStack(spacing: 15) {
                HStack {
                    Spacer(minLength: 10)
                    Button(action: { showCongrats = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 20)
                }
                #if canImport(UIKit)
                if let img = UIImage(named: "trophy") {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 286, height: 286)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .shadow(color: .yellow.opacity(0.55), radius: 22, x: 0, y: 0)
                        .shadow(color: .orange.opacity(0.35), radius: 40, x: 0, y: 0)
                        .transition(.scale.combined(with: .opacity))
                        .scaleEffect(trophyScale)
                } else {
                    Image(systemName: "trophy.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 208, height: 208)
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .shadow(color: .yellow.opacity(0.55), radius: 20, x: 0, y: 0)
                        .shadow(color: .orange.opacity(0.35), radius: 36, x: 0, y: 0)
                        .transition(.scale.combined(with: .opacity))
                        .scaleEffect(trophyScale)
                }
                #else
                Image("trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 286, height: 286)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .shadow(color: .yellow.opacity(0.55), radius: 22, x: 0, y: 0)
                    .shadow(color: .orange.opacity(0.35), radius: 40, x: 0, y: 0)
                    .transition(.scale.combined(with: .opacity))
                    .scaleEffect(trophyScale)
                #endif
                VStack(spacing: 10) {
                    if let dateLine = congratsTargetDateLine {
                        Text("You Hit Target for \(dateLine)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 16)
                            .multilineTextAlignment(.center)
                    }
                    Text("Congratulations!")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 4)
                    VStack(spacing: 12) {
                        Button(action: {
                            SoundManager.playSound(1104)
                            SoundManager.playVibration()
                            showCongrats = false
                            showCalendar = true
                        }) {
                            Text("Check Daily Stat")
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: buttonWidth)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(radius: 8)
                        }
                        Button(action: {
                            showCongrats = false
                        }) {
                            Text("Continue")
                                .font(.system(size: 28, weight: .bold))
                                .frame(width: buttonWidth)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.purple.opacity(nextGlowPulse ? 0.9 : 0.3), radius: nextGlowPulse ? 22 : 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                        .blur(radius: nextGlowPulse ? 10 : 2)
                                        .opacity(nextGlowPulse ? 0.9 : 0.35)
                                        .scaleEffect(nextGlowPulse ? 1.03 : 1.0)
                                )
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { nextGlowPulse.toggle() }
                        }
                        .onDisappear { nextGlowPulse = false }
                    }
                }
                .offset(y: 10)
            }
            .offset(y: -40)
            .onAppear {
                trophyScale = 0.92
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { trophyScale = 1.12 }
            }
            .onDisappear { withAnimation(.easeOut(duration: 0.2)) { trophyScale = 1.0 } }
            #if canImport(ConfettiSwiftUI)
            .confettiCannon(trigger: $confettiTrigger, num: 100, confettis: [.shape(.circle), .shape(.square)], colors: [.yellow, .orange], repetitions: 1, repetitionInterval: 0.1)
            #endif
            .zIndex(11)
        }
    }

    private var bottomNavigationOverlay: some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .center, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    statsCardsRow
                        .frame(maxWidth: .infinity)
                    Button(action: {
                        SoundManager.playSound(1104)
                        SoundManager.playVibration()
                        showNotes = true
                    }) {
                        Image(systemName: "note.text")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(11)
                            .background(
                                LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 20)
        .offset(y: 4)
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if showMenu {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 8) {
                HStack {
                    Spacer(minLength: 10)
                    Button(action: { withAnimation { showMenu = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer(minLength: 10)
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
    }

    // MARK: - Extracted UI Blocks
    @ViewBuilder
    private func categoryHeader(geo: GeometryProxy, category: String?) -> some View {
        let trimmed = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasCategory = !trimmed.isEmpty
        HStack(spacing: 8) {
            if hasCategory {
                Button(action: {
                    let cat = trimmed
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        router.openCategory(cat)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryHeaderText(trimmed))
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(appTheme.primaryTextColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Category")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(appTheme.primaryTextColor)
                }
            }
            Spacer()
            Button("Edit") {
                let targetID = item.id
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    router.openEdit(id: targetID)
                }
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.cyan)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, geo.safeAreaInsets.top + 10)
        .zIndex(2000)
    }

    @ViewBuilder
    private func thaiVocabBlock(geo: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Button(action: {
                autoSpeakWork?.cancel()
                speakThaiNow(item.thai)
            }) {
                VStack(spacing: 0) {
                    let baseSize: CGFloat = item.thai.count > 22 ? 34 : (item.thai.count > 14 ? 38 : 44)
                    thaiTitleView(item.thai, size: baseSize)
                        .lineLimit(2)
                        .minimumScaleFactor(0.32)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ThaiTextHeightKey.self, value: geo.size.height)
                            }
                        )
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .frame(width: nil, height: thaiAreaHeight, alignment: .bottom)
                .contentShape(Rectangle())
                .background(Color.white.opacity(0.001))
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(1000)
            .onPreferenceChange(ThaiTextHeightKey.self) { h in
                thaiTextHeight = h
            }
        }
        .padding(.horizontal, 20)
        .multilineTextAlignment(.center)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .zIndex(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, geo.safeAreaInsets.top + 32)
    }

    @ViewBuilder
    private func burmeseLine(geo: GeometryProxy) -> some View {
        if let burmese = item.burmese, !burmese.isEmpty {
            Text(burmese)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.yellow.opacity(0.95))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, geo.safeAreaInsets.top + 32 + thaiAreaHeight + 10)
                .allowsHitTesting(false)
                .zIndex(9)
        }
    }

    private var countsBlock: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
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
                Text("+\(sessionCount)")
                    .font(.system(size: 24, weight: .thin, design: .rounded))
                    .foregroundColor(.yellow)
                    .offset(x: 40, y: -6)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: -190)
        .allowsHitTesting(false)
    }

    private var dogGifOverlay: some View {
        AnimatedGifView(name: "dog", isPlaying: $isGifPlaying)
            .frame(width: 40, height: 40)
            .scaleEffect(x: -0.33, y: 0.33)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
            .zIndex(1)
            .offset(y: 35)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if isGifPlaying && Date().timeIntervalSince(lastGifActivity) > gifInactivityInterval {
                    isGifPlaying = false
                }
            }
    }

    private var bigCircleAndPickers: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 6)
                .background(
                    Circle().fill(
                        AngularGradient(gradient: Gradient(colors: [.pink, .purple, .blue, .pink]), center: .center)
                    )
                )
                .shadow(color: bigCircleGlow ? .pink.opacity(0.6) : .clear, radius: bigCircleGlow ? 15 : 0)
                .frame(width: 350, height: 350)
                .scaleEffect(bigCircleScale)
                .rotationEffect(.degrees(bigCircleRotation))
                .onTapGesture {
                    sessionTimer.registerActivity()
                    SoundManager.playSound(1104)
                    SoundManager.playVibration()
                    isGifPlaying = true
                    lastGifActivity = Date()
                    let oldTotalCount = item.count
                    withAnimation(.easeOut(duration: 0.15)) {
                        bigCircleColor = .green
                        bigCircleGlow = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            bigCircleRotation += 360
                            bigCircleColor = .blue
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        withAnimation(.easeOut(duration: 0.8)) {
                            bigCircleGlow = false
                        }
                    }
                    if item.status != .ready {
                        item.status = .drill
                        selectedStatusIndex = 1
                    }
                    item.count += selectedIncrement
                    RecentCountRecorder.shared.record(id: item.id)
                    updateTodayCount(by: selectedIncrement)
                    sessionCount += selectedIncrement
                    if boostType == .counts {
                        remaining = max(0, remaining - selectedIncrement)
                        storedRemaining = remaining
                    }
                    sessionTimerVisible = true
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
                    if item.count / 100 > oldTotalCount / 100 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            SoundManager.playSound(1025)
                        }
                    }
                    previousCount = item.count
                }
                .offset(y: -10)

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
            .offset(x: -145, y: -210)

            Button(action: { cycleIncrement() }) {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(gradient: Gradient(colors: [.yellow, .orange, .red, .yellow]), center: .center)
                        )
                    Circle()
                        .stroke(Color.white, lineWidth: 6)
                        .shadow(color: .pink.opacity(0.6), radius: 15)
                    ZStack {
                        Text("\(selectedIncrement)")
                            .font(.system(size: 40, weight: .heavy, design: .rounded)).italic()
                            .foregroundColor(.white)
                        Text("+")
                            .font(.system(size: 14, weight: .heavy, design: .rounded)).italic()
                            .foregroundColor(.white)
                            .offset(x: -14, y: -14)
                    }
                    .shadow(color: .pink.opacity(0.9), radius: 25)
                    .shadow(color: .pink.opacity(0.5), radius: 40)
                 }
                 .frame(width: 65, height: 65)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 65, height: 65)
            .offset(x: 150, y: -207)

            Button(action: {
                SoundManager.playSound(1104)
                SoundManager.playVibration()
                withAnimation { volumeLevel = (volumeLevel + 1) % 4 }
            }) {
                ZStack {
                    Circle().fill(Color.white)
                    Circle().stroke(Color.white, lineWidth: 4)
                    Text(volumeLevel == 0 ? "🔇" : volumeLevel == 1 ? "🔈" : volumeLevel == 2 ? "🔉" : "🔊")
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 35, height: 35)
            .shadow(color: .pink.opacity(0.6), radius: 15)
            .offset(x: 170, y: -150)
        }
        .offset(y: 45)
    }

    private var quickActionLogosView: some View {
        VStack(spacing: -6) {
            Button(action: { openGoogleSearch(for: item.thai) }) {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.6), radius: 6)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: { openChatGPT(for: item.thai) }) {
                Image("chatgpt")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.6), radius: 6)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: { openGoogleTranslate(for: item.thai) }) {
                Image("translate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.6), radius: 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 24)
        .padding(.bottom, 110)
        .zIndex(5)
    }

    private var smallCircleBlock: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 6)
                .background(
                    Circle().fill(
                        AngularGradient(gradient: Gradient(colors: [.yellow, .orange, .red, .yellow]), center: .center)
                    )
                )
                .shadow(color: .pink.opacity(0.6), radius: 15)
                .frame(width: 100, height: 100)
                .scaleEffect(smallCircleScale)
                .rotationEffect(.degrees(smallCircleRotation))
                .overlay(
                    Text("↓")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                )
                .onTapGesture {
                    sessionTimer.registerActivity()
                    SoundManager.playSound(1052)
                    SoundManager.playVibration()
                    let oldTotalCount = item.count
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
                    if item.status != .ready {
                        item.status = .drill
                        selectedStatusIndex = 1
                    }
                    item.count = max(0, item.count - selectedIncrement)
                    sessionCount = max(0, sessionCount - selectedIncrement)
                    updateTodayCount(by: -selectedIncrement)
                    if boostType == .counts {
                        remaining = min(boostValue, remaining + selectedIncrement)
                        storedRemaining = remaining
                    }
                    if item.count / 100 < oldTotalCount / 100 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            SoundManager.playSound(1025)
                        }
                    }
                    previousCount = item.count
                }
                .offset(y: 10)
        }
        .offset(x: 120, y: 185)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { (geo: GeometryProxy) in
            // MARK: - Root ZStack for Fixed Positioning
            ZStack {
                // Background color
                appTheme.backgroundColor.ignoresSafeArea()
                
                // Category header overlay (non-interfering with Thai tap area)
                categoryHeader(geo: geo, category: item.category)

                // MARK: - 1. Thai Vocab & Burmese Text Block
                thaiVocabBlock(geo: geo)

                // Burmese line anchored independently below the fixed Thai area
                burmeseLine(geo: geo)

                // MARK: - 2. Total Counts Number (labels removed)
                countsBlock

                // MARK: - 3. Big Circle & Pickers
                dogGifOverlay
                bigCircleAndPickers
                // MARK: - 3a. Lettered Circles (G, C, T) - arranged along circle arc
                Group {
                    letterCircle("G", size: 36, offset: CGSize(width: -164, height: 177), colors: [.green, .mint], useLinear: true) {
                        openGoogleImages(for: item.thai)
                    }
                    letterCircle("C", size: 48, offset: CGSize(width: -127, height: 212), colors: [.cyan, .teal]) {
                        openChatGPT(for: item.thai)
                    }
                    letterCircle("T", size: 40, offset: CGSize(width: -77, height: 233), colors: [.purple, .pink], useLinear: true) {
                        openGoogleTranslate(for: item.thai)
                    }
                }
                .offset(x: 10, y: 20) // moved up by 30pt (was 50)

                .offset(y: -10) // moved up by 25pt (was 15)

                // MARK: - 3b. Quick Action Logos (Google / ChatGPT / Translate)
                quickActionLogosView

                // MARK: - 4. Small Circle with Section Count Text
                smallCircleBlock

                // MARK: - Congratulations Overlay
                congratsOverlayView

                                
                
                // MARK: - Remaining / Navigation (Bottom Center Overlay)
                bottomNavigationOverlay

                
                menuOverlay
                

            } // End of Root ZStack
            } // GeometryReader
            #if canImport(ConfettiSwiftUI)
            .confettiCannon(trigger: $confettiTrigger, num: 100, confettis: [.shape(.triangle), .shape(.circle)], colors: [.yellow, .orange], repetitions: 1, repetitionInterval: 0.1)
            #endif
            .toolbar(.hidden, for: .navigationBar)

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
        .onAppear {
                        // Load stored increment for this vocab if available
                        let stored = UserDefaults.standard.integer(forKey: incrementKey(for: item.id))
                        if stored != 0 { selectedIncrement = stored }

            // Set initial inactivity threshold
            updateInactivityThreshold()

            // Initialize todayDate once to avoid empty default
            if todayDate.isEmpty {
                todayDate = Formatters.iso.string(from: Date())
            }

            syncBackfillActiveDayKeyIfNeeded()
            
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

    // Auto play Thai pronunciation after 1.2 second delay (cancellable)
    autoSpeakWork?.cancel()
    let work = DispatchWorkItem { speakThai(item.thai) }
    autoSpeakWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        }
        .preferredColorScheme(appTheme.colorScheme)
        .sheet(isPresented: $showQuiz) {
            DailyQuizView()
                .preferredColorScheme(appTheme.colorScheme)
        }
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarProgressView()
                .preferredColorScheme(appTheme.colorScheme)
        }
        .fullScreenCover(isPresented: $showNotes) {
            NavigationStack {
                AudioRecordingView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showNotes = false }
                        }
                    }
            }
        }
        .onChange(of: remaining) { oldValue, newValue in
            if newValue == 0 && boostValue > 0 {
                if !showCongrats {
                    congratsTargetDayKey = nil
                    queueCongrats(for: item.thai)
                    updateRecentVocabs(item)
                }
            }
        }
        .onChange(of: item.id) { oldValue, newValue in
            // Immediately stop any ongoing speech when switching vocabs
            synthesizer.stopSpeaking(at: .immediate)
            SoundManager.fadeOutCurrentSound()
            autoSpeakWork?.cancel()
            

            if let idx = VocabularyStatus.allCases.firstIndex(of: item.status) {
                selectedStatusIndex = idx
            }
            selectedIncrement = defaultIncrement(for: item.thai)
            showCongrats = false // hide overlay when new item loads
            congratsTargetDayKey = nil
            
            // Cancel any pending speak operations
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            
            // No need to manually trigger speakThai here as it's already handled by onAppear
            // when the view appears with the new vocab
        }
        .onChange(of: studyHistoryJSON) { _, _ in
            syncBackfillActiveDayKeyIfNeeded()
        }
        .onChange(of: dailyTargetHits) { _, _ in
            syncBackfillActiveDayKeyIfNeeded()
        }
        .onChange(of: studyStartDateTimestamp) { _, _ in
            syncBackfillActiveDayKeyIfNeeded()
        }
    }

    private func speakThai(_ text: String) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        // Stop any currently playing sounds with fade out
        SoundManager.fadeOutCurrentSound()
        
        // Use a small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Safely access synthesizer with nil check
            guard let synthesizer = self.synthesizer as AVSpeechSynthesizer? else { 
                print("Synthesizer is nil, skipping speech")
                return 
            }
            
            // If the synthesizer is already speaking, let it finish instead of interrupting.
            guard !synthesizer.isSpeaking else { return }
            
            // Only proceed if we have text to speak
            guard !text.isEmpty else { return }
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
            utterance.rate = 0.45
            
            // Start speech synthesis (non-throwing)
            synthesizer.speak(utterance)
            print("Speech synthesis started for: \(text)")
        }
    }

    // Immediate TTS for user taps: interrupts and plays right away
    private func speakThaiNow(_ text: String) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        DispatchQueue.main.async {
            guard !text.isEmpty else { return }
            // Interrupt any ongoing speech for snappy response
            self.synthesizer.stopSpeaking(at: .immediate)
            // Ensure session is active
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            #endif
            // Tiny delay avoids iOS race after stopSpeaking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
                utterance.rate = 0.45
                self.synthesizer.speak(utterance)
            }
        }
    }

    // Configure audio session for immediate, reliable TTS playback
    private func configureAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("AudioSession error: \(error.localizedDescription)")
        }
        #endif
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
let isSingleWord = !text.contains(" ") && text.count < 15 // Adjust threshold as needed
let prompt: String
if isSingleWord {
    prompt = "Please explain composition of this Thai word '\(text)'"
} else {
    prompt = "Explain '\(text)'s sentense structure."
}
UIPasteboard.general.string = prompt
let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
if let url = URL(string: "https://chat.openai.com/?model=gpt-4o&q=\(encoded)") ??
            URL(string: "https://chat.openai.com/?q=\(encoded)") ??
            URL(string: "https://chatgpt.com/?q=\(encoded)") {
    UIApplication.shared.open(url)
} else if let url = URL(string: "https://chatgpt.com/") {
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
    
    // MARK: - Google Search Helper
    private func openGoogleSearch(for text: String) {
        #if os(iOS)
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - Google Images Helper
    private func openGoogleImages(for text: String) {
        #if os(iOS)
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?tbm=isch&q=\(encoded)") {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // Queue congrats to run after pronunciation fully completes
    private func queueCongrats(for text: String) {
        // Play sound when marking as ready with slight delay (sound1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            SoundManager.playSound(1025)
            SoundManager.playVibration()
        }
        
        // 0.5-second pause before speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speechDelegate.onDone = {
                // 0.5-second pause after speech finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showCongrats = true
                    confettiTrigger += 1
                    updateRecentVocabs(item)
                }
            }
            speakThai(text)
    }
    }

    // MARK: - Study History Helpers
    private func dayKey(from date: Date) -> String {
        return Formatters.day.string(from: date)
    }

    private func loadStudyHistory() -> [String: Int] {
        if let data = studyHistoryJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        return [:]
    }

    private func loadTodayWorkHistory() -> [String: Int] {
        if let data = todayWorkHistoryJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        return [:]
    }

    private func appendStudyHistory(date: Date, increment: Int) {
        var history = loadStudyHistory()
        let key = dayKey(from: date)
        let current = history[key] ?? 0
        history[key] = max(0, current + increment)
        saveStudyHistory(history)
    }

    private func resolveBackfillActiveDayKey(history: [String: Int]) -> String? {
        let target = max(1, dailyTargetHits)
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: Date())
        guard start <= end else { return nil }

        if !backfillActiveDayKey.isEmpty {
            let hits = history[backfillActiveDayKey] ?? 0
            if hits < target {
                return backfillActiveDayKey
            }
        }

        var current = start
        while current <= end {
            let key = dayKey(from: current)
            let hits = history[key] ?? 0
            if hits < target {
                return key
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return nil
    }

    private func applyBackfillIncrement(_ increment: Int) -> String? {
        if increment == 0 { return nil }

        let target = max(1, dailyTargetHits)
        var history = loadStudyHistory()
        var completedDayKey: String? = nil

        guard let startKey = resolveBackfillActiveDayKey(history: history) else {
            return nil
        }
        backfillActiveDayKey = startKey

        if increment < 0 {
            let currentHits = history[startKey] ?? 0
            history[startKey] = max(0, currentHits + increment)
            saveStudyHistory(history)
            return nil
        }

        let cal = Calendar.current
        var remainingInc = increment
        var activeKey: String? = startKey

        while remainingInc > 0, let key = activeKey {
            let currentHits = history[key] ?? 0
            let need = max(0, target - currentHits)
            if need == 0 {
                if let d = Formatters.day.date(from: key),
                   let next = cal.date(byAdding: .day, value: 1, to: d) {
                    let nextKey = dayKey(from: next)
                    backfillActiveDayKey = nextKey
                    activeKey = resolveBackfillActiveDayKey(history: history)
                    if let ak = activeKey { backfillActiveDayKey = ak } else { backfillActiveDayKey = "" }
                } else {
                    activeKey = nil
                    backfillActiveDayKey = ""
                }
                continue
            }

            let add = min(need, remainingInc)
            let nextHits = currentHits + add
            if currentHits < target, nextHits >= target {
                if completedDayKey == nil {
                    completedDayKey = key
                }
            }
            history[key] = nextHits
            remainingInc -= add

            if (history[key] ?? 0) >= target {
                if let d = Formatters.day.date(from: key),
                   let next = cal.date(byAdding: .day, value: 1, to: d) {
                    let nextKey = dayKey(from: next)
                    backfillActiveDayKey = nextKey
                    activeKey = resolveBackfillActiveDayKey(history: history)
                    if let ak = activeKey { backfillActiveDayKey = ak } else { backfillActiveDayKey = "" }
                } else {
                    activeKey = nil
                    backfillActiveDayKey = ""
                }
            }
        }

        saveStudyHistory(history)
        return completedDayKey
    }

    // Track today's count and roll over on new day
    private func updateTodayCount(by increment: Int) {
        let now = Date()
        let storedDate = Formatters.iso.date(from: todayDate) ?? now
        let cal = Calendar.current
        if !cal.isDate(storedDate, inSameDayAs: now) {
            // New day: reset base and set first increment
            todayDate = Formatters.iso.string(from: now)
            todayCount = max(0, increment)
            appendTodayWorkHistory(date: now, increment: todayCount)
            let completedDayKey = applyBackfillIncrement(todayCount)
            if let key = completedDayKey, !showCongrats {
                congratsTargetDayKey = key
                queueCongrats(for: item.thai)
            }
        } else {
            todayCount = max(0, todayCount + increment)
            appendTodayWorkHistory(date: now, increment: increment)
            let completedDayKey = applyBackfillIncrement(increment)
            if let key = completedDayKey, !showCongrats {
                congratsTargetDayKey = key
                queueCongrats(for: item.thai)
            }
        }
    }

    private func saveStudyHistory(_ history: [String: Int]) {
        // Keep last 1200 days to support longer history views
        let now = Date()
        let cal = Calendar.current
        let keys: [String] = (0..<1200).compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: now) else { return nil }
            return dayKey(from: d)
        }
        let trimmed = history.filter { keys.contains($0.key) }
        if let data = try? JSONEncoder().encode(trimmed),
           let s = String(data: data, encoding: .utf8) {
            studyHistoryJSON = s
        }
    }

    private func saveTodayWorkHistory(_ history: [String: Int]) {
        let now = Date()
        let cal = Calendar.current
        let keys: [String] = (0..<1200).compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: now) else { return nil }
            return dayKey(from: d)
        }
        let trimmed = history.filter { keys.contains($0.key) }
        if let data = try? JSONEncoder().encode(trimmed),
           let s = String(data: data, encoding: .utf8) {
            todayWorkHistoryJSON = s
        }
    }

    private func appendTodayWorkHistory(date: Date, increment: Int) {
        var history = loadTodayWorkHistory()
        let key = dayKey(from: date)
        let current = history[key] ?? 0
        history[key] = max(0, current + increment)
        saveTodayWorkHistory(history)
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
