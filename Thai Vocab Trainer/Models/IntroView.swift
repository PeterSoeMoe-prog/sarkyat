//  IntroView.swift
//  Thai Vocab Trainer
//
//  A minimal, compile-safe landing screen.
//  Replace the file’s contents with this.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import AudioToolbox

struct IntroView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("remainingSeconds") private var remainingSeconds: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""
    // Stats injected by the caller
    let totalCount: Int     // total repetitions logged
    let vocabCount: Int     // number of vocabulary entries
    let queueCount: Int
    let drillCount: Int
    let readyCount: Int
    // Theme & navigation
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var showCategories = false
    @State private var showNotes = false
    @State private var showDailyListCalendar = false
    @State private var shouldStartStudyFiltered = false
    @State private var resumeGlow = false
    @State private var hitsNumberWidth: CGFloat = 0
    @State private var hitsSuperscriptWidth: CGFloat = 0
    @ObservedObject private var notificationEngine = NotificationEngine.shared
    // Boost selection
    @AppStorage("boostType") private var boostTypeRaw: String = BoostType.mins.rawValue
    @AppStorage("boostValue") private var boostValue: Int = 0

    @State private var selectedBoostType: BoostType? = nil
    @State private var selectedMins: Int = 60
    @State private var selectedCounts: Int = 5000
    @State private var selectedVocabs: Int = 10
    @State private var statPage: Int = 0
    @State private var quickStartPage: Int = 1

    @AppStorage("studyStartDateTimestamp") private var studyStartDateTimestamp: Double = 0

    private var startDate: Date {
        let fallback = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        if studyStartDateTimestamp > 0 {
            return Date(timeIntervalSince1970: studyStartDateTimestamp)
        }
        return fallback
    }

    // Derived numbers
    private var daysStudied: Int {
        (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1
    }
    @AppStorage("todayCount") private var todayCount: Int = 0
    @AppStorage("studyHistoryJSON") private var studyHistoryJSON: String = ""
    @AppStorage("dailyTargetHits") private var dailyTargetHits: Int = 5000
    private var averagePerDay: Int { max(1, totalCount / daysStudied) }

    private var decodedStudyHistory: [String: Int] {
        guard let data = studyHistoryJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func dayKey(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func formatWithComma(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct HitsNumberWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private struct HitsSuperscriptWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private var oldestMissedTargetDate: Date? {
        let target = max(1, dailyTargetHits)

        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: Date())
        guard start <= end else { return nil }

        var current = start
        while current <= end {
            let key = dayKey(from: current)
            let hits = decodedStudyHistory[key] ?? 0
            if hits < target {
                return current
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        return nil
    }

    private var missedTargetDaysCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: Date())
        if start > end { return 0 }

        let target = max(1, dailyTargetHits)
        var current = start
        var missed = 0
        while current <= end {
            let key = dayKey(from: current)
            let hits = decodedStudyHistory[key] ?? 0
            if hits < target {
                missed += 1
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        return missed
    }
    
    // Calculate yesterday's count and percentage change
    private var yesterdayCount: Int {
        guard let data = studyHistoryJSON.data(using: .utf8),
              let history = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return 0
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: yesterday)
        return history[key] ?? 0
    }
    
    private var percentageChange: Double {
        guard yesterdayCount > 0 else { return 0 }
        return ((Double(todayCount) - Double(yesterdayCount)) / Double(yesterdayCount)) * 100
    }

    // ---------------------------------------------------------
    // MARK: Body
    // ---------------------------------------------------------
    var body: some View {
        NavigationStack {
        ZStack {
            appTheme.backgroundColor.ignoresSafeArea()
            VStack(spacing: 30) {
                // -------------------------------------------------
                // 1. Hero Header with notification bell
                // -------------------------------------------------
                VStack(spacing: 6) {
                    // Centered title text; notification bell now lives in the nav bar trailing across the app
                    Text("Thai Vocab Trainer")
                        .font(.largeTitle.bold())
                        .foregroundColor(appTheme.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    Text("Daily drill in minutes")
                        .font(.title3.weight(.light))
                        .foregroundColor(appTheme.welcomeMessageColor)
                }
                .padding(.top, -16)

                // -------------------------------------------------
                // 2. Quick-Start Card
                // -------------------------------------------------
                ZStack(alignment: .top) {
                    TabView(selection: $quickStartPage) {
                        VStack(spacing: 20) {
                        Picker("Boost Type", selection: $selectedBoostType) {
                            Text("Minutes").tag(Optional(BoostType.mins))
                            Text("Hits").tag(Optional(BoostType.counts))
                            Text("Vocabs").tag(Optional(BoostType.vocabs))
                        }
                        .pickerStyle(.segmented)
                         .tint(.white)
                         .foregroundColor(.white)
                         .background(
                             LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                 .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                         )
                        .padding(.horizontal)

                        HStack(spacing: 24) {
                            pickerColumn(label: "Mins", values: [60,40,30,20], binding: $selectedMins, type: .mins)
                            pickerColumn(label: "Hits", values: [9000,7000,5000,3000], binding: $selectedCounts, type: .counts)
                            pickerColumn(label: "Vocabs", values: [20,15,10,5], binding: $selectedVocabs, type: .vocabs)
                        }
                        .frame(height: 80)

                        HStack(spacing: 12) {
                            Button {
                                playConfirmFeedback()
                                boostTypeRaw = (selectedBoostType ?? .mins).rawValue
                                switch (selectedBoostType ?? .mins) {
                                case .mins:    boostValue = selectedMins * 60
                                case .counts:  boostValue = selectedCounts
                                case .vocabs:  boostValue = selectedVocabs
                                }
                                remainingSeconds = boostValue
                                remainingTimestamp = Date().timeIntervalSince1970
                                if selectedBoostType != nil {
                                    router.openContent()
                                }
                            } label: {
                                Text("Start Session")
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(radius: 6)
                                    .padding(.leading, 16)
                            }
                            .opacity(selectedBoostType == nil ? 0.5 : 1)

                            Button {
                                sessionPaused = false
                                if let uuid = UUID(uuidString: storedLastVocabID) {
                                    router.openCounter(id: uuid)
                                } else {
                                    router.openContent()
                                }
                            } label: {
                                Text("Resume")
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.blue.opacity(resumeGlow ? 0.7 : 0.25), radius: resumeGlow ? 16 : 6, x: 0, y: 0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                            .blur(radius: resumeGlow ? 8 : 2)
                                            .opacity(resumeGlow ? 0.9 : 0.3)
                                            .blendMode(.plusLighter)
                                    )
                                    .padding(.trailing, 16)
                            }
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                    resumeGlow = true
                                }
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(height: 280)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 15, y: 5)
                    .padding(.horizontal, 20)
                        .tag(0)

                        VStack(spacing: 6) {
                        Spacer()

                        // Neon gradient colors (same as StatCard)
                        let neonColors: [Color] = [
                            Color(red:0.99, green:0.24, blue:0.38),
                            Color(red:0.91, green:0.13, blue:0.49),
                            Color(red:0.55, green:0.17, blue:0.98),
                            Color(red:0.2, green:0.56, blue:0.93),
                            Color(red:0.96, green:0.76, blue:0.27),
                            Color(red:0.99, green:0.24, blue:0.38)
                        ]

                        let hitsNumber = formatWithComma(dailyTargetHits)
                        let dateLine = oldestMissedTargetDate.map(dayLabel) ?? "-"
                        let numberText = Text(hitsNumber)
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                        let superscriptText = Text(" Hits for")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))

                        VStack(spacing: 6) {
                            Text("Study")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)

                            ZStack {
                                numberText
                                    .foregroundColor(.clear)
                                    .overlay(
                                        AngularGradient(gradient: Gradient(colors: neonColors), center: .center)
                                            .mask(numberText)
                                    )
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: HitsNumberWidthKey.self, value: geo.size.width)
                                        }
                                    )
                                    .onPreferenceChange(HitsNumberWidthKey.self) { hitsNumberWidth = $0 }

                                superscriptText
                                    .foregroundColor(.clear)
                                    .overlay(
                                        AngularGradient(gradient: Gradient(colors: neonColors), center: .center)
                                            .mask(superscriptText)
                                    )
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: HitsSuperscriptWidthKey.self, value: geo.size.width)
                                        }
                                    )
                                    .onPreferenceChange(HitsSuperscriptWidthKey.self) { hitsSuperscriptWidth = $0 }
                                    .offset(x: (hitsNumberWidth / 2) + (hitsSuperscriptWidth / 2) + 8, y: -16)
                            }
                            .multilineTextAlignment(.center)
                            .shadow(color: Color(red:0.99, green:0.24, blue:0.38).opacity(0.7), radius: 18, x: 0, y: 0)
                            .shadow(color: Color(red:0.2, green:0.56, blue:0.93).opacity(0.35), radius: 26, x: 0, y: 0)

                            Text(dateLine)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )

                            if missedTargetDaysCount > 0 {
                                let dayWord = missedTargetDaysCount == 1 ? "day" : "days"
                                Text("\(formatWithComma(missedTargetDaysCount)) \(dayWord) you missed the target")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }

                        Color.clear.frame(height: 0)

                        HStack(spacing: 12) {
                            Text("Daily List")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(radius: 6)
                                .padding(.leading, 16)
                                .onTapGesture {
                                    showDailyListCalendar = true
                                }

                            Text("Start Study")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(radius: 6)
                                .padding(.trailing, 16)
                                .onTapGesture {
                                    sessionPaused = false
                                    if let uuid = UUID(uuidString: storedLastVocabID) {
                                        router.openCounter(id: uuid)
                                    } else {
                                        router.openContent()
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(height: 280)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 15, y: 5)
                    .padding(.horizontal, 20)
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 280)
                    .onAppear { quickStartPage = 1 }

                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { idx in
                            Circle()
                                .fill(Color.gray.opacity(idx == quickStartPage ? 0.85 : 0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .offset(y: -10)
                    .allowsHitTesting(false)
                }

                // -------------------------------------------------
                // 3. Status Breakdown – Doughnut Pie
                // -------------------------------------------------
                HStack(alignment: .center, spacing: 40) {
                    DoughnutChart(values: [Double(queueCount), Double(drillCount), Double(readyCount)],
                                  colors: [appTheme.primaryTextColor, appTheme.welcomeMessageColor, appTheme.accentArrowColor])
                        .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: 12) {
                        let totalPie = queueCount + drillCount + readyCount
                        legendRow(color: .red, label: "Queue", value: queueCount, total: totalPie)
                        legendRow(color: .yellow, label: "Drill", value: drillCount, total: totalPie)
                        legendRow(color: .green, label: "Ready", value: readyCount, total: totalPie)
                        legendRow(label: "All", value: totalPie, total: totalPie, showPercent: false)
                            .font(.system(size: 30, weight: .bold))
                    }
                    .font(.caption2)
                    .foregroundColor(appTheme.primaryTextColor)
                }
                
                VStack {
                    TabView(selection: $statPage) {
                         StatCard(title: "Total Vocab Counts", value: totalCount, big: false)
                             .tag(0)
                         StatCard(title: "Today Hits", value: todayCount, big: false)
                             .tag(1)
                         StatCard(title: "Days Total", value: daysStudied, big: false)
                             .tag(2)
                         StatCard(title: "Average Per Day", value: averagePerDay, big: false)
                             .tag(3)
                     }
                     .frame(height: 130)
                     .padding(.horizontal, 20)
                     .tabViewStyle(.page(indexDisplayMode: .automatic))
                     .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                }
                .offset(y: -4)

                // -------------------------------------------------
                // 4. Secondary Actions
                // -------------------------------------------------
                HStack(spacing: 0) {
                    actionButton(icon: "magnifyingglass.circle.fill", title: "Search")
                        .onTapGesture {
                            playTapSound()
                            router.openContent(activateSearch: true)
                        }
                    actionButton(icon: "book.fill", title: "All Vocab")
                        .onTapGesture {
                            playTapSound()
                            router.openContent()
                        }
                    actionButton(icon: "square.grid.2x2.fill", title: "Categories")
                        .onTapGesture {
                            playTapSound()
                            showCategories = true
                        }
                    Button(action: {
                        playTapSound()
                        router.openDailyQuiz()
                    }) {
                        actionButton(icon: "bolt.fill", title: "Daily Quiz")
                    }
                    actionButton(icon: "waveform", title: "Notes")
                        .onTapGesture {
                            playTapSound()
                            showNotes = true
                        }
                    Button(action: {
                        playTapSound()
                        router.openSettings()
                    }) {
                        actionButton(icon: "gearshape.fill", title: "Settings")
                    }
                }
                .foregroundColor(appTheme.primaryTextColor)
                .font(.title3)
                .padding(.top, -15)
            }
            .padding(.top, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Add a small spacer inset above the bottom safe area so the
        // home indicator does not overlap the bottom action bar.
         .safeAreaInset(edge: .bottom) {
             Color.clear.frame(height: 18)
         }
         .navigationDestination(isPresented: $showCategories) {
             VocabCategoryView()
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
        .fullScreenCover(isPresented: $showDailyListCalendar) {
            CalendarProgressView()
        }
         .fullScreenCover(
            isPresented: Binding(
                get: { router.sheet == .settings },
                set: { isPresented in
                    if !isPresented, router.sheet == .settings {
                        router.dismissSheet()
                    }
                }
            )
         ) {
            SettingsView()
         }
         .withNotificationBell()
         .navigationBarTitleDisplayMode(.inline)
         .onAppear {
             // Request notification permission on first launch
             notificationEngine.requestPermission { granted in
                 if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("⚠️ Notification permission denied")
                }
            }
            // DEBUG: Add sample notifications for testing badge
            #if DEBUG
            if notificationEngine.pendingNotifications.isEmpty {
                notificationEngine.scheduleFailedQuizNotification(
                    vocabID: UUID(),
                    thaiWord: "สวัสดี",
                    burmeseTranslation: "မင်္ဂလာပါ"
                )
                notificationEngine.scheduleFailedQuizNotification(
                    vocabID: UUID(),
                    thaiWord: "ขอบคุณ",
                    burmeseTranslation: "ကျေးဇူးတင်ပါတယ်"
                )
                notificationEngine.scheduleFailedQuizNotification(
                    vocabID: UUID(),
                    thaiWord: "ไปไหน",
                    burmeseTranslation: "ဘယ်သွားမလဲ"
                )
            }
            #endif
        }
         // Automatically resume ongoing session if countdown still active
        .onAppear {
            // Calculate effective remaining based on boost type
            var effectiveRemaining = remainingSeconds
            if boostTypeRaw == BoostType.mins.rawValue {
                let elapsed = Int(Date().timeIntervalSince1970 - remainingTimestamp)
                effectiveRemaining = max(0, remainingSeconds - elapsed)
            }
             if !sessionPaused && effectiveRemaining > 0 {
                 router.openContent()
             } else if remainingSeconds != 0 {
                 // Session actually finished while the app wasn’t running
                 remainingSeconds = 0
             }
            // Note: do not consume deep link here; VocabularyListView will consume it on appear
        }
        // Close NavigationStack
        }
    
}



    // Card view helper
    // Picker column helper
    private func playSelectFeedback() {
        SoundManager.playSound(1157) // Tock sound
        SoundManager.playVibration()
    }
    private func playConfirmFeedback() {
        SoundManager.playSound(1104) // Key press click
        SoundManager.playVibration()
    }

    private func pickerColumn(label: String, values: [Int], binding: Binding<Int>, type: BoostType) -> some View {
        let isActive = selectedBoostType == type
        return VStack(spacing: 2) {
                        Picker(label, selection: binding) {
                ForEach(values, id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 90)
            .clipped()
            .disabled(!isActive)
        }
    .opacity(isActive ? 1 : 0.35)
    .contentShape(Rectangle())
    .onTapGesture {
            selectedBoostType = type
            playSelectFeedback()
        }
    }

    // MARK: - Secondary Action Button Helper
    private func actionButton(icon: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 58)
    }

    private func playTapSound() {
        SoundManager.playSound(1104)
        SoundManager.playVibration()
    }

    private struct StatCard: View {
        let title: String
        let value: Int
        var big: Bool = false
        var percentageChange: Double? = nil

        // Neon gradient colours
        private let neonColors: [Color] = [
            Color(red:0.99, green:0.24, blue:0.38),
            Color(red:0.91, green:0.13, blue:0.49),
            Color(red:0.55, green:0.17, blue:0.98),
            Color(red:0.2, green:0.56, blue:0.93),
            Color(red:0.96, green:0.76, blue:0.27),
            Color(red:0.99, green:0.24, blue:0.38)
        ]

        var body: some View {
            VStack(spacing: -2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                let displayValue = value
                Text("\(displayValue)")
                    .font(.system(size: big ? 54 : 45, weight: .heavy))
                    .foregroundColor(.clear)
                    .overlay(
                        AngularGradient(gradient: Gradient(colors: neonColors), center: .center)
                            .mask(
                                Text("\(displayValue)")
                                    .font(.system(size: big ? 54 : 45, weight: .heavy))
                            )
                    )
                    
            }
            .frame(maxWidth: .infinity, minHeight: big ? 100 : 80)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }


// MARK: - Legend Helper
private func legendRow(color: Color? = nil, label: String, value: Int, total: Int, showPercent: Bool = true) -> some View {
    HStack(spacing: 8) {
        if let c = color {
            Circle().fill(c).frame(width: 12, height: 12)
            }
            let percent = total > 0 ? Int(round(Double(value) / Double(total) * 100)) : 0
             if showPercent {
                 Text("\(label)  \(value)  (\(percent)%)")
             } else {
                 Text("\(label)  \(value)")
             }
                
        }
    }

    // Close of IntroView struct
}

// MARK: - DoughnutChart View
struct DoughnutChart: View {
    // Data
    let values: [Double]
    let colors: [Color]
    var lineWidth: CGFloat = 30

    // Animation state
    @State private var animate = false
    @AppStorage("hasAnimatedChart") private var hasAnimatedChart: Bool = false

    private var total: Double { values.reduce(0,+) }

    func angle(at index: Int) -> Double {
        let sum = values.prefix(index).reduce(0,+)
        return sum/total * 360
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(values.indices, id: \.self) { i in
                    let start = angle(at: i)/360
                    let end = angle(at: i+1)/360
                    // Preserve existing segment stroke colors/styles
                    let strokeStyle: AnyShapeStyle = (
                        i == 0
                        ? AnyShapeStyle(Color.red)
                        : (i == 1
                           ? AnyShapeStyle(Color.yellow)
                           : AnyShapeStyle(AngularGradient(gradient: Gradient(colors: [Color.green, Color.mint]), center: .center))
                          )
                    )
                    // Choose a solid glow color approximating the stroke
                    let glowColor: Color = (i == 0 ? .red : (i == 1 ? .yellow : .green))
                    Circle()
                        .trim(from: CGFloat(start), to: CGFloat(animate ? end : start))
                        .stroke(
                            strokeStyle,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        // Soft outer glow per segment
                        .shadow(color: glowColor.opacity(0.45), radius: 8, x: 0, y: 0)
                        // Additional radiant blur to enhance glow
                        .overlay(
                            Circle()
                                .trim(from: CGFloat(start), to: CGFloat(animate ? end : start))
                                .stroke(glowColor.opacity(0.6), lineWidth: lineWidth)
                                .blur(radius: 6)
                                .opacity(0.7)
                                .blendMode(.plusLighter)
                        )
                        .animation(.easeOut(duration: 1.0).delay(Double(i) * 0.15), value: animate)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                if !hasAnimatedChart {
                    hasAnimatedChart = true
                    animate = true
                } else {
                    animate = true // ensure segments visible without animating from zero
                }
            }
        }
    }
}

// Preview
#if DEBUG
struct IntroViewSimple_Previews: PreviewProvider {
    static var previews: some View {
        IntroView(totalCount: 1500, vocabCount: 120, queueCount: 30, drillCount: 40, readyCount: 50)
            .previewDevice("iPhone 15")
    }
}
#endif
