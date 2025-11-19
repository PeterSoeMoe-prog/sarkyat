import SwiftUI
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

/// View to display daily statistics and progress for Thai vocabulary learning
struct DailyStatView: View {
    // MARK: - State
    @State private var isLoading = true
    @State private var showWeeklyPie = false
    @State private var showMonthlyPie = false
    @State private var showAllPie = false
    @State private var showDailyQuiz = false
    // Quiz stats stored in AppStorage (update elsewhere after quizzes)
    @AppStorage("quizDailyCount") private var quizDailyCount: Int = 0
    @AppStorage("quizWeeklyCount") private var quizWeeklyCount: Int = 0
    @AppStorage("quizMonthlyCount") private var quizMonthlyCount: Int = 0
    @AppStorage("quizTotalCount") private var quizTotalCount: Int = 0
    // Accuracy storage
    @AppStorage("correctDaily") private var correctDaily: Int = 0
    @AppStorage("attemptDaily") private var attemptDaily: Int = 0
    @AppStorage("correctWeekly") private var correctWeekly: Int = 0
    @AppStorage("attemptWeekly") private var attemptWeekly: Int = 0
    @AppStorage("correctMonthly") private var correctMonthly: Int = 0
    @AppStorage("attemptMonthly") private var attemptMonthly: Int = 0
    @AppStorage("correctTotal") private var correctTotal: Int = 0
    @AppStorage("attemptTotal") private var attemptTotal: Int = 0
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark app-style background
                Color(.black)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Loading state
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            // Top card container matching app style
                            VStack(alignment: .leading, spacing: 20) {
                                // Big page title
                                Text("Daily Stats")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.white)

                                // Section header
                                HStack(spacing: 12) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.title2.bold())
                                        .foregroundStyle(
                                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Statistics")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                        Text("Your learning progress")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }

                                // Donut charts grid (2x2)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                    CardContainer {
                                        AccuracyDonutChart()
                                            .frame(width: 120, height: 120)
                                    }
                                    CardContainer {
                                        WeeklyAccuracyDonutChart()
                                            .frame(width: 120, height: 120)
                                    }
                                    CardContainer {
                                        MonthlyAccuracyDonutChart()
                                            .frame(width: 120, height: 120)
                                    }
                                    CardContainer {
                                        AllTimeAccuracyDonutChart()
                                            .frame(width: 120, height: 120)
                                    }
                                }

                                // Study Activity block
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "chart.xyaxis.line")
                                            .font(.title3)
                                            .foregroundColor(.green)
                                        Text("Study Activity")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }

                                    CardContainer {
                                        DailyStudyBarChart()
                                            .frame(height: 220)
                                    }
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                            Spacer(minLength: 20)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .withNotificationBell()
        }
        .onAppear { isLoading = false }
    }
    // Helper to render a stat row
    private func statRow(label: String, value: Int) -> some View {
        // Determine platform-safe background color
        #if canImport(UIKit)
        let bgColor = Color(UIColor.systemGray6)
        #else
        let bgColor = Color.gray.opacity(0.15)
        #endif

        return HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bgColor)
        )
    }

    // Enhanced card container with better shadows and spacing
    private struct CardContainer<Content: View>: View {
        let content: () -> Content
        init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
        var body: some View {
            VStack { content() }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }

    private func accuracyPercent(correct: Int, attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return (Double(correct) / Double(attempts)) * 100
    }

    // Monthly Accuracy Donut Chart
    private struct MonthlyAccuracyDonutChart: View {
        @State private var animatePie = false
        @State private var showNumber = false
        @State private var showLabel = false
        @State private var rotateGradient = false
        @AppStorage("correctMonthly") private var correctMonthly: Int = 0
        @AppStorage("attemptMonthly") private var attemptMonthly: Int = 0
        @AppStorage("quizMonthlyCount") private var quizMonthlyCount: Int = 0
        private var wrong: Double { max(Double(attemptMonthly - correctMonthly), 0) }
        private var values: [Double] { [Double(correctMonthly), wrong] }
        private var colors: [Color] { [Color.clear, Color.gray] }
        var body: some View {
            donutBody(correctColors: [.orange, .yellow], count: quizMonthlyCount, label: "month")
        }
        private func donutBody(correctColors: [Color], count: Int, label: String) -> some View {
            ZStack {
                GeometryReader { geo in
                    let lineWidth: CGFloat = 24
                    let totalValue = max(values.reduce(0,+), 1)
                    ForEach(values.indices, id: \.self) { i in
                        let startFraction = values.prefix(i).reduce(0,+) / totalValue
                        let endFraction = values.prefix(i+1).reduce(0,+) / totalValue
                        let trimEnd = animatePie ? endFraction : startFraction
                        if i == 0 {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(AngularGradient(gradient: Gradient(colors: correctColors), center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90 + (rotateGradient ? 360 : 0)))
                                .animation(.easeOut(duration: 1.2), value: rotateGradient)
                        } else {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(colors[i].gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: correctColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(count)")
                                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .opacity(showLabel ? 1 : 0)
                }
            }
            .onAppear {
                let dur = 1.0
                withAnimation(.easeOut(duration: dur)) { animatePie = true }
                rotateGradient = true
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.1) {
                    withAnimation(.easeIn(duration: 0.3)) { showNumber = true }
                #if os(iOS)
                AudioServicesPlaySystemSound(1104)
                #endif
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) { showLabel = true }
                }
            }
        }
    }

    // All Time Accuracy Donut Chart
    private struct AllTimeAccuracyDonutChart: View {
        @State private var animatePie = false
        @State private var showNumber = false
        @State private var showLabel = false
        @State private var rotateGradient = false
        @AppStorage("correctTotal") private var correctTotal: Int = 0
        @AppStorage("attemptTotal") private var attemptTotal: Int = 0
        @AppStorage("quizTotalCount") private var quizTotalCount: Int = 0
        private var wrong: Double { max(Double(attemptTotal - correctTotal), 0) }
        private var values: [Double] { [Double(correctTotal), wrong] }
        private var colors: [Color] { [Color.clear, Color.gray] }
        var body: some View {
            donutBody(correctColors: [.mint, .green], count: quizTotalCount, label: "all")
        }
        private func donutBody(correctColors: [Color], count: Int, label: String) -> some View {
            ZStack {
                GeometryReader { geo in
                    let lineWidth: CGFloat = 24
                    let totalValue = max(values.reduce(0,+), 1)
                    ForEach(values.indices, id: \.self) { i in
                        let startFraction = values.prefix(i).reduce(0,+) / totalValue
                        let endFraction = values.prefix(i+1).reduce(0,+) / totalValue
                        let trimEnd = animatePie ? endFraction : startFraction
                        if i == 0 {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(AngularGradient(gradient: Gradient(colors: correctColors), center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90 + (rotateGradient ? 360 : 0)))
                                .animation(.easeOut(duration: 1.2), value: rotateGradient)
                        } else {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(colors[i].gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 80, weight: .heavy))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: correctColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(count)")
                                        .font(.system(size: 80, weight: .heavy))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(showLabel ? 1 : 0)
                }
            }
            .onAppear {
                let dur = 1.0
                withAnimation(.easeOut(duration: dur)) { animatePie = true }
                rotateGradient = true
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.1) {
                    withAnimation(.easeIn(duration: 0.3)) { showNumber = true }
                #if os(iOS)
                AudioServicesPlaySystemSound(1104)
                #endif
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) { showLabel = true }
                }
            }
        }
    }

    // Weekly Accuracy Donut Chart
    private struct WeeklyAccuracyDonutChart: View {
        @State private var animatePie = false
        @State private var showNumber = false
        @State private var showLabel = false
        @State private var rotateGradient = false
        // Bind weekly storage
        @AppStorage("correctWeekly") private var correctWeekly: Int = 0
        @AppStorage("attemptWeekly") private var attemptWeekly: Int = 0
        @AppStorage("quizWeeklyCount") private var quizWeeklyCount: Int = 0
        
        private var wrong: Double { max(Double(attemptWeekly - correctWeekly), 0) }
        private var values: [Double] { [Double(correctWeekly), wrong] }
        private var colors: [Color] { [Color.clear, Color.gray] }
        
        var body: some View {
            ZStack {
                GeometryReader { geo in
                    let lineWidth: CGFloat = 24
                    let totalValue = max(values.reduce(0,+), 1)
                    ForEach(values.indices, id: \.self) { i in
                        let startFraction = values.prefix(i).reduce(0,+) / totalValue
                        let endFraction = values.prefix(i+1).reduce(0,+) / totalValue
                        let trimEnd = animatePie ? endFraction : startFraction
                        if i == 0 {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(AngularGradient(gradient: Gradient(colors: [.blue, .teal]), center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90 + (rotateGradient ? 360 : 0)))
                                .animation(.easeOut(duration: 1.2), value: rotateGradient)
                        } else {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(colors[i].gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                VStack(spacing: 4) {
                    Text("\(quizWeeklyCount)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(quizWeeklyCount)")
                                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text("week")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .opacity(showLabel ? 1 : 0)
                }
            }
            .onAppear {
                let dur = 1.0
                withAnimation(.easeOut(duration: dur)) { animatePie = true }
                rotateGradient = true
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.1) {
                    withAnimation(.easeIn(duration: 0.3)) { showNumber = true }
                #if os(iOS)
                AudioServicesPlaySystemSound(1104)
                #endif
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) { showLabel = true }
                }
            }
        }
    }

    // Accuracy Donut Chart
    private struct AccuracyDonutChart: View {
        // Animation state
        @State private var animatePie = false
        @State private var showNumber = false
        @State private var showLabel = false
        @State private var rotateGradient = false
        // Bind directly to stored values so chart updates live
        @AppStorage("correctDaily") private var correctDaily: Int = 0
        @AppStorage("attemptDaily") private var attemptDaily: Int = 0
        @AppStorage("quizDailyCount") private var quizDailyCount: Int = 0
        
        private var wrong: Double { max(Double(attemptDaily - correctDaily), 0) }
        private var values: [Double] { [Double(correctDaily), wrong] }
        private var colors: [Color] { [Color.clear, Color.gray] }
        
        var body: some View {
            ZStack {
                // wrapper to attach appear
            
                // Doughnut slices
                GeometryReader { geo in
                    let lineWidth: CGFloat = 24
                    let totalValue = max(values.reduce(0, +), 1) // avoid division by zero
                    ForEach(values.indices, id: \.self) { i in
                        // cumulative start fraction
                        let startFraction = values.prefix(i).reduce(0,+) / totalValue
                        let endFraction   = values.prefix(i+1).reduce(0,+) / totalValue
                        let trimEnd = animatePie ? endFraction : startFraction
                        if i == 0 {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(AngularGradient(gradient: Gradient(colors: [.pink, .purple]), center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90 + (rotateGradient ? 360 : 0)))
                                .animation(.easeOut(duration: 1.2), value: rotateGradient)
                        } else {
                            Circle()
                                .trim(from: CGFloat(startFraction), to: CGFloat(trimEnd))
                                .stroke(colors[i].gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                // Center label
                VStack(spacing: 4) {
                    // Animation trigger
                }
                .onAppear {
                    let animationDuration = 1.0
                    withAnimation(.easeOut(duration: animationDuration)) { animatePie = true }
                    rotateGradient = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.1) {
                        withAnimation(.easeIn(duration: 0.3)) { showNumber = true }
                #if os(iOS)
                AudioServicesPlaySystemSound(1104)
                #endif
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.5) {
                        withAnimation(.easeIn(duration: 0.3)) { showLabel = true }
                    }
                }
                // Center content
                VStack(spacing: 4) {
                    Text("\(quizDailyCount)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(quizDailyCount)")
                                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text("today")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .opacity(showLabel ? 1 : 0)
                }
            }
        }
    }

    // (removed unused MetricCard variants)

    // MARK: - Wave Chart Component
    private struct WaveChart: View {
        let series: [(label: String, value: Int)]
        let maxValue: Int
        
        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Area fill with gradient
                    WavePath(series: series, maxValue: maxValue, height: geo.size.height - 40)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.6),
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Line stroke
                    WavePath(series: series, maxValue: maxValue, height: geo.size.height - 40)
                        .stroke(Color.green, lineWidth: 2.5)
                    
                    // Labels at bottom
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(series.indices, id: \.self) { i in
                            let showLabel = series.count <= 7 || i % 3 == 0
                            if showLabel {
                                Text(series[i].label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else if series.count > 7 {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: 30)
                }
            }
        }
    }
    
    // MARK: - Wave Path Shape
    private struct WavePath: Shape {
        let series: [(label: String, value: Int)]
        let maxValue: Int
        let height: CGFloat
        
        func path(in rect: CGRect) -> Path {
            guard !series.isEmpty else { return Path() }
            
            var path = Path()
            let width = rect.width
            let stepX = width / CGFloat(max(series.count - 1, 1))
            
            // Calculate points
            var points: [CGPoint] = []
            for (index, item) in series.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedValue = maxValue > 0 ? CGFloat(item.value) / CGFloat(maxValue) : 0
                let y = height * (1 - normalizedValue)
                points.append(CGPoint(x: x, y: y))
            }
            
            // Start from bottom-left
            path.move(to: CGPoint(x: 0, y: height))
            
            // Draw smooth curve through points
            if points.count == 1 {
                path.addLine(to: points[0])
            } else if points.count == 2 {
                path.addLine(to: points[0])
                path.addLine(to: points[1])
            } else {
                // Move to first point
                path.addLine(to: points[0])
                
                // Draw smooth curves between points
                for i in 0..<(points.count - 1) {
                    let current = points[i]
                    let next = points[i + 1]
                    
                    // Control points for smooth curve
                    let controlPointX = (current.x + next.x) / 2
                    path.addQuadCurve(
                        to: next,
                        control: CGPoint(x: controlPointX, y: current.y)
                    )
                }
            }
            
            // Close path at bottom-right
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
            
            return path
        }
    }

    // MARK: - Daily Study Wave Chart
    private struct DailyStudyBarChart: View {
        @AppStorage("studyHistoryJSON") private var historyJSON: String = ""
        @AppStorage("todayCount") private var todayCount: Int = 0
        @AppStorage("todayDate") private var todayDate: String = ISO8601DateFormatter().string(from: Date())

        private enum RangeOption: String, CaseIterable, Identifiable {
            case d7 = "7D"
            case d30 = "30D"
            case y1 = "1Y"
            case all = "All"
            var id: String { rawValue }
        }

        @State private var selectedRange: RangeOption = .d7
        @State private var series: [(label: String, value: Int)] = []
        @State private var maxValue: Int = 1
        // Selected bar index for showing on-demand tooltip
        @State private var selectedIndex: Int? = nil

        var body: some View {
            VStack(spacing: 10) {
                // Range selector
                Picker("Range", selection: $selectedRange) {
                    ForEach(RangeOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.secondary)
                .padding(.bottom, 6)
                .padding(.top, 6)
                // Wave/Area Chart
                WaveChart(series: series, maxValue: maxValue)
                    .frame(height: 180)

                // Empty-state hint
                if !series.contains(where: { $0.value > 0 }) {
                    Text("No study hits yet today. Open Counter and tap + to record hits.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .onAppear { loadAndBuildSeries() }
            .onChange(of: todayCount) { _, _ in
                loadAndBuildSeries()
            }
            .onChange(of: todayDate) { _, _ in
                loadAndBuildSeries()
            }
            .onChange(of: selectedRange) { _, _ in
                loadAndBuildSeries()
            }
        }

        private func loadAndBuildSeries() {
            // Decode stored history { dateKey(yyyy-MM-dd) : Int }
            var history: [String: Int] = [:]
            if let data = historyJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
                history = decoded
            }

            // Migrate any old ISO8601 timestamp keys to date-only keys (yyyy-MM-dd)
            let isoForMigration = ISO8601DateFormatter()
            let dayFmtForMigration = DateFormatter()
            dayFmtForMigration.calendar = Calendar(identifier: .gregorian)
            dayFmtForMigration.locale = Locale(identifier: "en_US_POSIX")
            dayFmtForMigration.dateFormat = "yyyy-MM-dd"
            var migrated: [String: Int] = [:]
            for (k, v) in history {
                if let d = isoForMigration.date(from: k) {
                    let dayKey = dayFmtForMigration.string(from: d)
                    migrated[dayKey] = max(migrated[dayKey] ?? 0, v)
                } else {
                    // assume it's already a day key
                    migrated[k] = max(migrated[k] ?? 0, v)
                }
            }
            history = migrated

            // Ensure today is present and up to date
            let iso = ISO8601DateFormatter()
            let dayFormatter = DateFormatter()
            dayFormatter.calendar = Calendar(identifier: .gregorian)
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.dateFormat = "yyyy-MM-dd"

            let now = Date()
            let stored = iso.date(from: todayDate) ?? now
            let todayKey = dayFormatter.string(from: stored)
            let current = history[todayKey] ?? 0
            if todayCount > current { history[todayKey] = todayCount }

            // Keep a rolling window of recent days (extend to support yearly/all)
            let cal = Calendar.current
            let retentionDays = 400
            let recentKeys: [String] = (0..<retentionDays).compactMap { offset in
                if let d = cal.date(byAdding: .day, value: -offset, to: now) { return dayFormatter.string(from: d) }
                return nil
            }
            history = history.filter { recentKeys.contains($0.key) }

            // Persist back
            if let data = try? JSONEncoder().encode(history),
               let str = String(data: data, encoding: .utf8) {
                historyJSON = str
            }

            // Build series based on selected range
            var out: [(String, Int)] = []
            var localMax = 1

            switch selectedRange {
            case .d7, .d30:
                let days = selectedRange == .d7 ? 7 : 30
                let dayLabelFmt = DateFormatter()
                dayLabelFmt.locale = Locale.current
                dayLabelFmt.setLocalizedDateFormatFromTemplate(days == 7 ? "E" : "d MMM")
                for delta in stride(from: days - 1, through: 0, by: -1) {
                    guard let d = cal.date(byAdding: .day, value: -delta, to: now) else { continue }
                    let key = dayFormatter.string(from: d)
                    let val = history[key] ?? 0
                    localMax = max(localMax, val)
                    let label = dayLabelFmt.string(from: d)
                    out.append((label, val))
                }
            case .y1, .all:
                // Aggregate daily history into months
                var monthly: [(year: Int, month: Int, label: String, value: Int)] = []
                let monthFmt = DateFormatter()
                monthFmt.locale = Locale.current
                if selectedRange == .y1 {
                    monthFmt.setLocalizedDateFormatFromTemplate("MMM")
                } else {
                    monthFmt.setLocalizedDateFormatFromTemplate("MMM yy")
                }

                // Build last 12 months or all months present
                let monthsBack = selectedRange == .y1 ? 12 : retentionDays / 30
                for m in stride(from: monthsBack - 1, through: 0, by: -1) {
                    guard let start = cal.date(byAdding: .month, value: -m, to: now),
                          let range = cal.range(of: .day, in: .month, for: start),
                          let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: start))
                    else { continue }

                    // Sum this month's daily keys
                    var sum = 0
                    var comp = cal.dateComponents([.year, .month], from: monthStart)
                    for day in 0..<(range.count) {
                        if let d = cal.date(byAdding: .day, value: day, to: monthStart) {
                            let key = dayFormatter.string(from: d)
                            sum += history[key] ?? 0
                        }
                    }
                    comp.day = 1
                    let label = monthFmt.string(from: monthStart)
                    monthly.append((comp.year ?? 0, comp.month ?? 0, label, sum))
                }

                for m in monthly {
                    localMax = max(localMax, m.value)
                    out.append((m.label, m.value))
                }
            }
            series = out
            maxValue = localMax
            // Default selection: prefer the latest non-zero day, otherwise the last bar
            if !series.isEmpty {
                if let lastNZ = series.indices.last(where: { series[$0].value > 0 }) {
                    selectedIndex = lastNZ
                } else {
                    selectedIndex = series.count - 1
                }
            } else {
                selectedIndex = nil
            }
        }

        // Compact count formatter: 1200 -> 1.2k, 44000 -> 44k
        private func shortCount(_ n: Int) -> String {
            if n < 1000 { return "\(n)" }
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            let d = Double(n)
            if n < 1_000_000 {
                let v = d / 1_000.0
                return "\(formatter.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v))k"
            } else if n < 1_000_000_000 {
                let v = d / 1_000_000.0
                return "\(formatter.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v))m"
            } else {
                let v = d / 1_000_000_000.0
                return "\(formatter.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v))b"
            }
        }
    }
}

#Preview {
    DailyStatView()
}
