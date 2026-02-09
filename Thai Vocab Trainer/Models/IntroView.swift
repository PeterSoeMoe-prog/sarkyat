//  IntroView.swift
//  Thai Vocab Trainer
//
//  A minimal, compile-safe landing screen.
//  Replace the file’s contents with this.

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import AudioToolbox

struct IntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var vocabStore: VocabStore
    @AppStorage("remainingSeconds") private var remainingSeconds: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""
    @AppStorage("counterPreferredStatsPage") private var counterPreferredStatsPage: Int = -1
    // Stats injected by the caller
    let totalCount: Int     // total repetitions logged
    let vocabCount: Int     // number of vocabulary entries
    let queueCount: Int
    let drillCount: Int
    let readyCount: Int
    // Theme & navigation
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var showNotes = false
    @State private var showDailyListCalendar = false
    @State private var showAllVocabsSheet: Bool = false
    @State private var showNotificationsFromTab: Bool = false
    @State private var selectedTabCategory: String? = nil
    @State private var tabCounterItem: VocabularyEntry? = nil
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

    private enum TabStatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case queue = "Queue"
        case drill = "Drill"
        case ready = "Ready"
        var id: String { rawValue }
    }

    private enum TabSortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case count = "Count"
        var id: String { rawValue }
    }

    @State private var tabSearchQuery: String = ""
    @State private var tabStatusFilter: TabStatusFilter = .all
    @State private var tabSortOption: TabSortOption = .name

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

    private var oldestMissedTargetRemainingHits: Int? {
        let target = max(1, dailyTargetHits)
        guard let d = oldestMissedTargetDate else { return nil }
        let hits = decodedStudyHistory[dayKey(from: d)] ?? 0
        return max(0, target - hits)
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
                                counterPreferredStatsPage = 1
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

                        // Neon gradient colors (same as StatCard)
                        let neonColors: [Color] = [
                            Color(red:0.99, green:0.24, blue:0.38),
                            Color(red:0.91, green:0.13, blue:0.49),
                            Color(red:0.55, green:0.17, blue:0.98),
                            Color(red:0.2, green:0.56, blue:0.93),
                            Color(red:0.96, green:0.76, blue:0.27),
                            Color(red:0.99, green:0.24, blue:0.38)
                        ]

                        let hitsNumber = formatWithComma(oldestMissedTargetRemainingHits ?? dailyTargetHits)
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
                                    .offset(x: (hitsNumberWidth / 2) + (hitsSuperscriptWidth / 2) + 2, y: -16)
                            }
                            .multilineTextAlignment(.center)
                            .shadow(color: Color(red:0.99, green:0.24, blue:0.38).opacity(0.7), radius: 18, x: 0, y: 0)
                            .shadow(color: Color(red:0.2, green:0.56, blue:0.93).opacity(0.35), radius: 26, x: 0, y: 0)

                            Text(dateLine)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack {
                                        let dateGradient = LinearGradient(
                                            gradient: Gradient(colors: [neonColors[0], neonColors[2], neonColors[3]]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )

                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(dateGradient)
                                            .opacity(0.18)

                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(dateGradient.opacity(0.8), lineWidth: 1)
                                    }
                                )
                                .shadow(color: neonColors[0].opacity(0.25), radius: 10, x: 0, y: 0)
                                .shadow(color: neonColors[3].opacity(0.18), radius: 14, x: 0, y: 0)

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
                    .frame(height: 310)
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
                    actionButton(icon: "square.split.2x1", title: "Tab")
                        .onTapGesture {
                            playTapSound()
                            showAllVocabsSheet = true
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
        .fullScreenCover(isPresented: $showAllVocabsSheet) {
            NavigationStack {
                let tabCategories: [String] = {
                    let raw = vocabStore.items.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let cleaned = raw.filter { !$0.isEmpty }
                    return Array(Set(cleaned)).sorted()
                }()

                let tabCategoryCounts: [String: Int] = {
                    var acc: [String: Int] = [:]
                    for entry in vocabStore.items {
                        guard let cat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty else { continue }
                        acc[cat, default: 0] += 1
                    }
                    return acc
                }()

                let tabCategoryStats: [String: (ready: Int, total: Int)] = {
                    var acc: [String: (ready: Int, total: Int)] = [:]
                    for entry in vocabStore.items {
                        guard let cat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty else { continue }
                        var cur = acc[cat, default: (ready: 0, total: 0)]
                        cur.total += 1
                        if entry.status == .ready { cur.ready += 1 }
                        acc[cat] = cur
                    }
                    return acc
                }()

                let tabItems: [VocabularyEntry] = {
                    guard let selected = selectedTabCategory, !selected.isEmpty else { return [] }
                    return vocabStore.items.filter { ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == selected }
                }()

                let filteredTabItems: [VocabularyEntry] = {
                    guard selectedTabCategory != nil else { return tabItems }

                    let q = tabSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    var items = tabItems

                    if tabStatusFilter != .all {
                        items = items.filter {
                            switch tabStatusFilter {
                            case .all:
                                return true
                            case .queue:
                                return $0.status == .queue
                            case .drill:
                                return $0.status == .drill
                            case .ready:
                                return $0.status == .ready
                            }
                        }
                    }

                    if !q.isEmpty {
                        items = items.filter { item in
                            let thai = item.thai.lowercased()
                            let burmese = item.burmese?.lowercased() ?? ""
                            return thai.contains(q) || burmese.contains(q)
                        }
                    }

                    items.sort {
                        switch tabSortOption {
                        case .name:
                            return $0.thai.localizedCaseInsensitiveCompare($1.thai) == .orderedAscending
                        case .count:
                            if $0.count != $1.count { return $0.count > $1.count }
                            return $0.thai.localizedCaseInsensitiveCompare($1.thai) == .orderedAscending
                        }
                    }
                    return items
                }()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("Category")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(colors: [.pink, .purple, .blue], startPoint: .leading, endPoint: .trailing)
                                    .mask(
                                        Text("Category")
                                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    )
                            )
                            .shadow(color: Color.pink.opacity(0.20), radius: 10, x: 0, y: 0)
                            .shadow(color: Color.blue.opacity(0.18), radius: 14, x: 0, y: 0)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

                        let gridPadding: CGFloat = 16
                        let gridSpacing: CGFloat = 14
                        let availableWidth = UIScreen.main.bounds.width - (gridPadding * 2) - (gridSpacing * 2)
                        let badgeSize = max(96, min(128, availableWidth / 3))
                        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: gridSpacing, alignment: .top), count: 3)
                        if selectedTabCategory == nil {
                            LazyVGrid(columns: columns, spacing: gridSpacing) {
                                ForEach(tabCategories, id: \.self) { cat in
                                    Button {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                            selectedTabCategory = cat
                                        }
                                    } label: {
                                        let stats = tabCategoryStats[cat, default: (ready: 0, total: tabCategoryCounts[cat, default: 0])]
                                        let ready = stats.ready
                                        let total = stats.total
                                        let pct = total > 0 ? Int(round(Double(ready) / Double(total) * 100)) : 0
                                        let isSelected = selectedTabCategory == cat
                                        let palette: [[Color]] = [
                                            [.blue, .cyan],
                                            [.orange, .yellow],
                                            [.pink, .purple],
                                            [.green, .mint]
                                        ]
                                        let ringColors = palette[abs(cat.hashValue) % palette.count]

                                        ZStack {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                                )

                                            Circle()
                                                .stroke(Color.primary.opacity(0.10), lineWidth: 6)

                                            Circle()
                                                .trim(from: 0, to: CGFloat(pct) / 100.0)
                                                .stroke(
                                                    AngularGradient(gradient: Gradient(colors: ringColors + ringColors), center: .center),
                                                    style: StrokeStyle(lineWidth: (isSelected ? 7 : 6), lineCap: .round)
                                                )
                                                .rotationEffect(.degrees(-90))
                                                .shadow(color: ringColors.first?.opacity(pct == 100 ? 0.35 : 0.20) ?? Color.white.opacity(0.2), radius: 10, x: 0, y: 0)
                                                .shadow(color: ringColors.last?.opacity(pct == 100 ? 0.25 : 0.14) ?? Color.white.opacity(0.2), radius: 14, x: 0, y: 0)

                                            VStack(spacing: 6) {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(pct == 100 ? .yellow : .secondary)
                                                    .shadow(color: (pct == 100 ? Color.yellow.opacity(0.55) : Color.clear), radius: 10, x: 0, y: 0)

                                                Text(cat)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)

                                                Text("\(ready)/\(total)")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.primary.opacity(0.85))

                                                Text("\(pct)% Done")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.top, 2)
                                        }
                                        .frame(width: badgeSize, height: badgeSize)
                                        .scaleEffect(isSelected ? 1.05 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, gridPadding)
                            .padding(.bottom, 10)
                        }

                        if let selected = selectedTabCategory {
                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    Text(selected)
                                        .font(.headline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedTabCategory = nil
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                )
                                .padding(.horizontal, 16)

                                LazyVStack(spacing: 0) {
                                    ForEach(filteredTabItems) { item in
                                        Button {
                                            tabCounterItem = item
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.thai)
                                                    if let burmese = item.burmese?.trimmingCharacters(in: .whitespacesAndNewlines),
                                                       !burmese.isEmpty {
                                                        Text(burmese)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                Text("\(item.count)")
                                                    .foregroundColor(.secondary)
                                            }
                                            .contentShape(Rectangle())
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        if item.id != filteredTabItems.last?.id {
                                            Divider()
                                                .opacity(0.35)
                                                .padding(.leading, 14)
                                        }
                                    }
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(appTheme.backgroundColor.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Button(action: {
                            showAllVocabsSheet = false
                            selectedTabCategory = nil
                        }) {
                            Image(systemName: "house.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            showAllVocabsSheet = false
                            router.openAddWord()
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        NotificationBellButton {
                            showNotificationsFromTab = true
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(.ultraThinMaterial)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    let stats: (ready: Int, total: Int) = {
                        if let selected = selectedTabCategory,
                           let s = tabCategoryStats[selected] {
                            return s
                        }
                        let total = vocabStore.items.count
                        let ready = vocabStore.items.filter { $0.status == .ready }.count
                        return (ready: ready, total: total)
                    }()

                    let ready = stats.ready
                    let total = stats.total
                    let pct = total > 0 ? Int(round(Double(ready) / Double(total) * 100)) : 0

                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Menu {
                                ForEach(TabSortOption.allCases) { opt in
                                    Button {
                                        tabSortOption = opt
                                    } label: {
                                        Text(opt.rawValue)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption)
                                    Text(tabSortOption.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.primary)
                            }

                            Menu {
                                ForEach(TabStatusFilter.allCases) { filter in
                                    Button {
                                        tabStatusFilter = filter
                                    } label: {
                                        Text(filter.rawValue)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.caption)
                                    Text(tabStatusFilter.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search", text: $tabSearchQuery)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        HStack(spacing: 0) {
                            Spacer(minLength: 0)

                            VStack(spacing: 6) {
                                Text("\(ready)")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.green)
                                Text("COMPLETED")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 6) {
                                Text("\(total)")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.blue)
                                Text("TOTAL")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 6) {
                                Text("\(pct)%")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.purple)
                                Text("PROGRESS")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                    .padding(.top, 8)
                }
                .sheet(item: $tabCounterItem) { item in
                    let itemsBinding = Binding<[VocabularyEntry]>(
                        get: { vocabStore.items },
                        set: { vocabStore.setItems($0) }
                    )
                    if let binding = vocabStore.binding(for: item.id) {
                        CounterView(item: binding, allItems: itemsBinding, totalVocabCount: vocabStore.items.count)
                    } else {
                        Text("Error loading item")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showNotificationsFromTab) {
            NotificationListView()
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
        .onChange(of: router.tabCategoryToOpen) { _, newValue in
            guard let cat = newValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !cat.isEmpty else { return }
            showAllVocabsSheet = true
            selectedTabCategory = cat
            router.tabCategoryToOpen = nil
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
