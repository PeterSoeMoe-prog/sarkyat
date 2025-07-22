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
            VStack {
                // Header
                Text("Daily Statistics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Loading state
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Main content will be added later
                    Spacer()
                    Text("Quiz Statistics")
                        .font(.title2.bold())
                        .padding(.bottom, 8)

                    // Accuracy doughnut chart
                        HStack(alignment: .center, spacing: 24) {
                            AccuracyDonutChart()
                                .frame(width: 160, height: 160)
                            if showWeeklyPie {
                                WeeklyAccuracyDonutChart()
                                    .frame(width: 112, height: 112)
                            }
                        }
                        .padding(.bottom)
                        HStack(alignment: .center, spacing: 24) {
                            if showMonthlyPie {
                                MonthlyAccuracyDonutChart()
                                    .frame(width: 112, height: 112)
                            }
                            if showAllPie {
                                AllTimeAccuracyDonutChart()
                                    .frame(width: 160, height: 160)
                            }
                        }
                        .padding(.bottom)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                                                        
                        
                        
                        
                    }
                    .padding(.horizontal)
                    // More Quiz Button
                    Button(action: {
                        // Play tap sound
                        #if canImport(UIKit)
                        AudioServicesPlaySystemSound(1104) // Standard iOS tap sound
                        #endif
                        // Show Daily Quiz
                        showDailyQuiz = true
                    }) {
                        Text("More Quiz")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Daily Stats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isLoading = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    showWeeklyPie = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                    showMonthlyPie = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    showAllPie = true
                }
            }
#endif
            
        }
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

    // Card for each metric
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
                    let lineWidth: CGFloat = 20
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
                        .font(.system(size: 45, weight: .heavy))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: correctColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(count)")
                                        .font(.system(size: 45, weight: .heavy))
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
                    let lineWidth: CGFloat = 20
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
                    let lineWidth: CGFloat = 20
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
                        .font(.system(size: 45, weight: .heavy))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(quizWeeklyCount)")
                                        .font(.system(size: 45, weight: .heavy))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text("week")
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
                    let lineWidth: CGFloat = 20
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
                        .font(.system(size: 80, weight: .heavy))
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text("\(quizDailyCount)")
                                        .font(.system(size: 80, weight: .heavy))
                                )
                        ).opacity(showNumber ? 1 : 0)
                    Text("today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(showLabel ? 1 : 0)
                }
            }
        }
    }

    // MetricCard now supports optional suffix
    private struct MetricCard: View {
        let label: String
        let value: Int
        let colors: [Color]
        var suffix: String? = nil
        var subValue: String? = nil

        var body: some View {
            VStack(spacing: 8) {
                // Value with gradient text
                Text("\(value)\(suffix ?? "")")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.clear)
                    .overlay(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .mask(
                                Text("\(value)")
                                    .font(.system(size: 40, weight: .heavy))
                            )
                    )
                if let sub = subValue {
                    Text(sub)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors.map { $0.opacity(0.2) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }
}

#Preview {
    DailyStatView()
}
