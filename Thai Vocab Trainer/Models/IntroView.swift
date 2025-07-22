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
    @AppStorage("remainingSeconds") private var remainingSeconds: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    // Stats injected by the caller
    let totalCount: Int     // total repetitions logged
    let vocabCount: Int     // number of vocabulary entries
    let queueCount: Int
    let drillCount: Int
    let readyCount: Int

    // Theme & navigation
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var navigateToContent = false
    @State private var showSettings = false
    @State private var showCategories = false
    @State private var showQuiz = false
    @State private var showDailyStats = false
    // Boost selection
    @AppStorage("boostType") private var boostTypeRaw: String = BoostType.mins.rawValue
    @AppStorage("boostValue") private var boostValue: Int = 0

    @State private var selectedBoostType: BoostType? = nil
    @State private var selectedMins: Int = 60
    @State private var selectedCounts: Int = 5000
    @State private var selectedVocabs: Int = 10
    @State private var statPage: Int = 0

    // Study-start date (you can expose this later in Settings)
    private let startDate: Date = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()

    // Derived numbers
    private var daysStudied: Int {
        (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1
    }
    @AppStorage("todayCount") private var todayCount: Int = 0
    private var averagePerDay: Int { max(1, totalCount / daysStudied) }

    // ---------------------------------------------------------
    // MARK: Body
    // ---------------------------------------------------------
    var body: some View {
        NavigationStack {
        ZStack {
            appTheme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 40) {
                // -------------------------------------------------
                // 1. Hero Header
                // -------------------------------------------------
                VStack(spacing: 6) {
                    Text("Thai Vocab Trainer")
                        .font(.largeTitle.bold())
                        .foregroundColor(appTheme.primaryTextColor)


                    Text("Daily drill in minutes")
                        .font(.title3.weight(.light))
                        .foregroundColor(appTheme.welcomeMessageColor)
                }

                // -------------------------------------------------
                // 2. Quick-Start Card
                // -------------------------------------------------
                VStack(spacing: 20) {
                    // Segmented picker for boost type
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

                    // Wheel pickers (only active one fully opaque)
                    HStack(spacing: 24) {
                        pickerColumn(label: "Mins", values: [60,40,30,20], binding: $selectedMins, type: .mins)
                        pickerColumn(label: "Hits", values: [9000,7000,5000,3000], binding: $selectedCounts, type: .counts)
                        pickerColumn(label: "Vocabs", values: [20,15,10,5], binding: $selectedVocabs, type: .vocabs)
                    }
                    .frame(height: 80)

                    // Start & Resume buttons
                    HStack(spacing: 12) {
                        // both buttons share horizontal padding
                    
                        Button {
                            playConfirmFeedback()
                            // Persist boost selections
                            boostTypeRaw = (selectedBoostType ?? .mins).rawValue
                        switch (selectedBoostType ?? .mins) {
                        case .mins:    boostValue = selectedMins * 60
                        case .counts:  boostValue = selectedCounts
                        case .vocabs:  boostValue = selectedVocabs
                        }
                        remainingSeconds = boostValue
                        remainingTimestamp = Date().timeIntervalSince1970
                        if selectedBoostType != nil {
                            navigateToContent = true
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
                            navigateToContent = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: .nextVocabulary, object: nil)
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
                                .shadow(radius: 6)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 15, y: 5)
                .padding(.horizontal, 20)

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

                // -------------------------------------------------
                // 4. Secondary Actions
                // -------------------------------------------------
                HStack(spacing: 20) {
                    actionButton(icon: "book.fill", title: "All Vocab")
                        .onTapGesture {
                            playTapSound()
                            navigateToContent = true // open list screen
                        }
                    actionButton(icon: "square.grid.2x2.fill", title: "Categories")
                        .onTapGesture {
                            playTapSound()
                            showCategories = true
                        }
                    actionButton(icon: "bolt.fill", title: "Daily Quiz")
                        .onTapGesture {
                            playTapSound()
                            showQuiz = true
                        }
                    actionButton(icon: "chart.bar.fill", title: "Daily Stats")
                        .onTapGesture {
                            playTapSound()
                            showDailyStats = true
                        }
                    actionButton(icon: "gearshape.fill", title: "Settings")
                        .onTapGesture {
                            playTapSound()
                            showSettings = true
                        }
                }
                .foregroundColor(appTheme.primaryTextColor)
                .font(.title3)
                .padding(.top, -15)
                .padding(.bottom, 20)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fullScreenCover(isPresented: $navigateToContent) {
            ContentView()
                .preferredColorScheme(appTheme.colorScheme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCategories) {
            VocabCategoryView()
        }
        .sheet(isPresented: $showQuiz) {
            DailyQuizView()
        }
        .sheet(isPresented: $showDailyStats) {
            DailyStatView()
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
                navigateToContent = true
            } else if remainingSeconds != 0 {
                // Session actually finished while the app wasn’t running
                remainingSeconds = 0
            }
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption2)
        }
    }

    private func playTapSound() {
        SoundManager.playSound(1104)
        SoundManager.playVibration()
    }

    private struct StatCard: View {
        let title: String
        let value: Int
        var big: Bool = false

        // Neon gradient colours
        private let neonColors: [Color] = [
            Color(red:0.99, green:0.24, blue:0.38),
            Color(red:0.91, green:0.13, blue:0.49),
            Color(red:0.55, green:0.17, blue:0.98),
            Color(red:0.2, green:0.56, blue:0.93),
            Color(red:0.96, green:0.76, blue:0.27),
            Color(red:0.99, green:0.24, blue:0.38)
        ]

        // Count-up animation state
        @State private var progress: Double = 0
        @AppStorage("hasAnimatedStats") private var hasAnimatedStats: Bool = false

        var body: some View {
            VStack(spacing: -2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                // Display animated number
                let displayValue = Int(Double(value) * progress)
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
            .onAppear {
                if !hasAnimatedStats {
                    hasAnimatedStats = true
                    progress = 0
                    withAnimation(.easeOut(duration: 1.8)) {
                        progress = 1
                    }
                } else {
                    progress = 1 // immediate (animation already done previously)
                }
            }
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
                ForEach(values.indices, id: \ .self) { i in
                    let start = angle(at: i)/360
                    let end = angle(at: i+1)/360
                    Circle()
                        .trim(from: CGFloat(start), to: CGFloat(animate ? end : start))
                        .stroke(
                            i == 0 ? AnyShapeStyle(Color.red) : (i == 1 ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(AngularGradient(gradient: Gradient(colors: [Color.green, Color.mint]), center: .center))),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
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
