import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// View to display daily statistics and progress for Thai vocabulary learning
struct DailyStatView: View {
 
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter

    // MARK: - State
    @State private var isLoading = true
    // Quiz stats stored in AppStorage (update elsewhere after quizzes)
    @AppStorage("quizDailyCount") private var quizDailyCount: Int = 0
    @AppStorage("quizYesterdayCount") private var quizYesterdayCount: Int = 0
    @AppStorage("quizWeeklyCount") private var quizWeeklyCount: Int = 0
    @AppStorage("quizPrevWeekCount") private var quizPrevWeekCount: Int = 0
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
    // Quiz completion storage
    @AppStorage("quizCompletedTotal") private var quizCompletedTotal: Int = 0
    
    // Total vocabulary count (stored in AppStorage for persistence)
    @AppStorage("totalVocabCount") private var totalVocabCount: Int = 0
    
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

                                HStack(spacing: 12) {
                                    HeroStatCard(
                                        title: "Today",
                                        value: "\(quizDailyCount)",
                                        subText: percentOnlyString(correct: correctDaily, attempts: attemptDaily),
                                        deltaText: todayDeltaText,
                                        deltaColor: todayDeltaColor,
                                        deltaSymbolName: todayDeltaSymbolName
                                    )
                                    HeroStatCard(
                                        title: "This Week",
                                        value: "\(quizWeeklyCount)",
                                        subText: percentOnlyString(correct: correctWeekly, attempts: attemptWeekly),
                                        deltaText: weekDeltaText,
                                        deltaColor: weekDeltaColor,
                                        deltaSymbolName: weekDeltaSymbolName
                                    )
                                }

                                HStack(spacing: 12) {
                                    HeroStatCard(
                                        title: "This Month",
                                        value: "\(quizMonthlyCount)",
                                        subText: percentOnlyString(correct: correctMonthly, attempts: attemptMonthly)
                                    )
                                    HeroStatCard(
                                        title: "All Time",
                                        value: "\(quizTotalCount)",
                                        subText: percentOnlyString(correct: correctTotal, attempts: attemptTotal)
                                    )
                                }
                                
                                HStack(spacing: 12) {
                                    HeroStatCard(
                                        title: "Quiz Done",
                                        value: overallCompletionPercentString(),
                                        subText: nil
                                    )
                                }
                                Button(action: {
                                    router.openDailyQuiz()
                                }) {
                                    Text("Quiz")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(LinearGradient(colors: [Color.blue, Color.purple, Color.pink, Color.orange], startPoint: .leading, endPoint: .trailing))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemBackground))
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        router.openIntro()
                        dismiss()
                    }) {
                        Image(systemName: "house")
                    }
                }
            }
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

    private func statRow(label: String, value: String) -> some View {
        // Determine platform-safe background color
        #if canImport(UIKit)
        let bgColor = Color(UIColor.systemGray6)
        #else
        let bgColor = Color.gray.opacity(0.15)
        #endif

        return HStack {
            Text(label)
            Spacer()
            Text(value)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bgColor)
        )
    }

    private func accuracyPercent(correct: Int, attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return (Double(correct) / Double(attempts)) * 100
    }

    private func percentString(correct: Int, attempts: Int) -> String {
        let p = accuracyPercent(correct: correct, attempts: attempts)
        return String(format: "%.0f%% (%d/%d)", p, correct, attempts)
    }

    private func percentOnlyString(correct: Int, attempts: Int) -> String {
        let p = accuracyPercent(correct: correct, attempts: attempts)
        return String(format: "%.0f%%", p)
    }
    
    private func overallCompletionPercentString() -> String {
        let total = totalVocabCount > 0 ? totalVocabCount : 1950
        guard total > 0 else { return "0%" }
        // Estimate passed quizzes based on accuracy and 5 items per quiz.
        // A quiz is considered failed if it has 2+ wrong answers (i.e. <80% in a 5-item quiz).
        let accPercent = accuracyPercent(correct: correctTotal, attempts: attemptTotal)
        let wrongAnswers = Int(floor(Double(quizTotalCount) * 5.0 * max(0.0, 1.0 - accPercent / 100.0)))
        let maxFailedQuizzes = min(quizTotalCount, wrongAnswers / 2)
        let passedQuizzesEstimate = max(0, quizTotalCount - maxFailedQuizzes)
        let passedVocabsEstimate = passedQuizzesEstimate * 5
        let percentage = (Double(passedVocabsEstimate) / Double(total)) * 100.0
        return String(format: "%.0f%%", percentage)
    }

    private var todayDeltaText: String? {
        let today = quizDailyCount
        let yday = quizYesterdayCount
        if yday == 0 {
            return today > 0 ? "100%" : nil
        }
        let pct = Int(round((Double(today - yday) / Double(yday)) * 100))
        if pct == 0 { return "0%" }
        return "\(abs(pct))%"
    }

    private var todayDeltaColor: Color {
        let today = quizDailyCount
        let yday = quizYesterdayCount
        if yday == 0 {
            return today > 0 ? .green : .secondary
        }
        if today > yday { return .green }
        if today < yday { return .red }
        return .secondary
    }

    private var todayDeltaSymbolName: String? {
        let today = quizDailyCount
        let yday = quizYesterdayCount
        if yday == 0 {
            return today > 0 ? "arrowtriangle.up.fill" : nil
        }
        if today > yday { return "arrowtriangle.up.fill" }
        if today < yday { return "arrowtriangle.down.fill" }
        return nil
    }

    private var weekDeltaText: String? {
        let now = quizWeeklyCount
        let prev = quizPrevWeekCount
        if prev == 0 {
            return now > 0 ? "100%" : nil
        }
        let pct = Int(round((Double(now - prev) / Double(prev)) * 100))
        if pct == 0 { return "0%" }
        return "\(abs(pct))%"
    }

    private var weekDeltaColor: Color {
        let now = quizWeeklyCount
        let prev = quizPrevWeekCount
        if prev == 0 {
            return now > 0 ? .green : .secondary
        }
        if now > prev { return .green }
        if now < prev { return .red }
        return .secondary
    }

    private var weekDeltaSymbolName: String? {
        let now = quizWeeklyCount
        let prev = quizPrevWeekCount
        if prev == 0 {
            return now > 0 ? "arrowtriangle.up.fill" : nil
        }
        if now > prev { return "arrowtriangle.up.fill" }
        if now < prev { return "arrowtriangle.down.fill" }
        return nil
    }
}

private struct HeroStatCard: View {
    let title: String
    let value: String
    var subText: String? = nil
    var deltaText: String? = nil
    var deltaColor: Color = .secondary
    var deltaSymbolName: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundColor(.clear)
                    .overlay(
                        LinearGradient(
                            colors: [Color.blue, Color.purple, Color.pink, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text(value)
                                .font(.system(size: 72, weight: .heavy, design: .rounded))
                        )
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .overlay(alignment: .topTrailing) {
                        if let deltaText {
                            VStack(spacing: 2) {
                                Text(deltaText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(deltaColor)

                                if let deltaSymbolName {
                                    Image(systemName: deltaSymbolName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(deltaColor)
                                }
                            }
                            .offset(x: 18, y: -10)
                        }
                    }

                if let subText {
                    Text("accu. rate \(subText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    DailyStatView()
        .environmentObject(AppRouter.shared)
}
