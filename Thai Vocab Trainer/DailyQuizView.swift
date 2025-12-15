import SwiftUI
import AVFoundation
import AudioToolbox
#if canImport(ConfettiSwiftUI)
import ConfettiSwiftUI
#endif

/// Simple daily quiz – shows 5 Thai vocab questions with three Burmese options each (one correct).
/// This is an **MVP placeholder**; scoring & persistence can be refined later.
struct DailyQuizView: View {
    // Speech handling
    private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
        var onDone: (() -> Void)?
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onDone?()
            onDone = nil
        }
    }
    private let speechDelegate = SpeechDelegate()
    private let synthesizer = AVSpeechSynthesizer()

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vocabStore: VocabStore
    @EnvironmentObject private var router: AppRouter
    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""

    init() {
        synthesizer.delegate = speechDelegate
    }

    private func speakThai(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        synthesizer.speak(utterance)
    }

    private func resumeSession() {
        @AppStorage("sessionPaused") var sessionPaused: Bool = false
        if sessionPaused {
            sessionPaused = false
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if let uuid = UUID(uuidString: storedLastVocabID),
                   vocabStore.items.contains(where: { $0.id == uuid }) {
                    router.openCounter(id: uuid)
                } else if let next = vocabStore.items.first(where: { $0.status != .ready }) ?? vocabStore.items.first {
                    router.openCounter(id: next.id)
                }
            }
        }
    }

    private struct QuizQuestion: Identifiable {
        let id = UUID()
        let vocabID: UUID  // Track the vocabulary entry ID
        let thai: String
        let correctBurmese: String
        let options: [String]  // shuffled, contains correctBurmese
    }

    // MARK: - State
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedAnswer: String? = nil
    @State private var score: Int = 0
    @State private var showResult: Bool = false
    @State private var currentQuestion: QuizQuestion? = nil
    @State private var confettiTrigger: Int = 0
    @State private var feedbackText: String? = nil
    @State private var timeRemaining: Int = 5
    @State private var timer: Timer? = nil
    @State private var skipNextIndexSpeak: Bool = false
    // Quiz stats storage
    @AppStorage("quizDailyCount") private var quizDailyCount: Int = 0
    @AppStorage("quizYesterdayCount") private var quizYesterdayCount: Int = 0
    @AppStorage("quizWeeklyCount") private var quizWeeklyCount: Int = 0
    @AppStorage("quizPrevWeekCount") private var quizPrevWeekCount: Int = 0
    @AppStorage("quizMonthlyCount") private var quizMonthlyCount: Int = 0
    @AppStorage("quizTotalCount") private var quizTotalCount: Int = 0
    @AppStorage("quizLastDate") private var quizLastDate: Double = 0
    // Accuracy storage
    @AppStorage("correctDaily") private var correctDaily: Int = 0
    @AppStorage("attemptDaily") private var attemptDaily: Int = 0
    @AppStorage("correctWeekly") private var correctWeekly: Int = 0
    @AppStorage("attemptWeekly") private var attemptWeekly: Int = 0
    @AppStorage("correctMonthly") private var correctMonthly: Int = 0
    @AppStorage("attemptMonthly") private var attemptMonthly: Int = 0
    @AppStorage("correctTotal") private var correctTotal: Int = 0
    @AppStorage("attemptTotal") private var attemptTotal: Int = 0
    // Quiz category inclusion map (JSON encoded in Settings)
    @AppStorage("quizCategoryMapJSON") private var quizCategoryMapJSON: String = ""
    @AppStorage("dailyQuizCoveredIDsJSON") private var dailyQuizCoveredIDsJSON: String = ""

    private func decodeCoveredIDs() -> Set<UUID> {
        guard !dailyQuizCoveredIDsJSON.isEmpty,
              let data = dailyQuizCoveredIDsJSON.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return Set(raw.compactMap { UUID(uuidString: $0) })
    }

    private func encodeCoveredIDs(_ set: Set<UUID>) {
        let raw = set.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(raw),
           let s = String(data: data, encoding: .utf8) {
            dailyQuizCoveredIDsJSON = s
        } else {
            dailyQuizCoveredIDsJSON = ""
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
            if questions.isEmpty {
                ProgressView().onAppear(perform: generateQuiz)
            } else if showResult {
                resultView
            } else {
                Group {
                    quizCard(for: questions[currentIndex])
                }
            }
                // Popup overlay - centered with higher zIndex
                if let fb = feedbackText {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        Text(fb)
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundColor(fb == "TRUE" || fb == "TRUE" ? .green : .red)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemBackground).opacity(0.95))
                            )
                            .shadow(radius: 20)
                    }
                    .zIndex(100)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onChange(of: currentIndex) { _ in
            // Restart the 5s countdown when the question index changes
            if !showResult && !questions.isEmpty {
                startTimer()
                if skipNextIndexSpeak {
                    // This transition will be handled manually (e.g., timeout path)
                    skipNextIndexSpeak = false
                } else {
                    // Speak current question Thai after a brief delay to allow UI transition
                    let idx = currentIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if idx < questions.count {
                            speakThai(questions[idx].thai)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: feedbackText)
        #if canImport(ConfettiSwiftUI)
                .confettiCannon(trigger: $confettiTrigger, 
                        num: 100, 
                        confettis: [.shape(.triangle), .shape(.circle)], 
                        colors: [.yellow, .orange], 
                        repetitions: 1, 
                        repetitionInterval: 0.1)
        #endif
        .withNotificationBell()
    }

    // MARK: - Views
    private func quizCard(for question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<questions.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index <= currentIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            HStack {
                Text("Question \(currentIndex + 1) / \(questions.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Countdown timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text("\(timeRemaining)s")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundColor(timeRemaining <= 2 ? .red : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(timeRemaining <= 2 ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
            
            // Thai word card with speaker icon
            VStack(spacing: 12) {
                ThaiQuestionText(text: question.thai)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    speakThai(question.thai)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Tap to hear")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 20)
            .onAppear {
                // Start timer (TTS is driven by currentIndex change)
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }

            Spacer()

            VStack(spacing: 16) {
                ForEach(question.options, id: \.self) { option in
                    Button(action: {
                        // Play tap sound
                        playTapSound()
                        answerSelected(option, for: question)
                    }) {
                        HStack {
                            Text(option.isEmpty ? "—" : option)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            if selectedAnswer != nil && option == question.correctBurmese {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    selectedAnswer != nil && option == question.correctBurmese
                                        ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : selectedAnswer != nil && option == selectedAnswer
                                            ? LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                    .disabled(selectedAnswer != nil) // lock after choose
                    .scaleEffect(selectedAnswer != nil && option != question.correctBurmese && option != selectedAnswer ? 0.95 : 1.0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .animation(.spring(response: 0.3), value: selectedAnswer)

            Spacer()
        }
        .padding()
        .navigationTitle("Daily Quiz")
    }

    private struct ThaiQuestionText: View {
        let text: String

        var body: some View {
            ViewThatFits(in: .vertical) {
                Text(text)
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(text)
                    .font(.system(size: 38, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    Text(text)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 24) {
            Text("Daily Quiz")
                .font(.title)
            Text("Score: \(score) / \(questions.count)")
                .font(.largeTitle)
                .bold()
            VStack(spacing: 20) {
                Button(action: {
                    playTapSound()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        router.dismissSheet()
                        router.openContent()
                    }
                }) {
                    Text("All Vocabs")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }
                .padding(.horizontal, 30)
                
                // moved More Quiz button to bottom
                
                Button(action: {
                    playTapSound()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        router.dismissSheet()
                        router.openContent()
                        router.openCategory("")
                        router.openContent()
                        router.openSettings()
                    }
                }) {
                    Text("See Stats")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }
                .padding(.horizontal, 30)
                
                Button(action: {
                    // Resume the counter/boost session
                    resumeSession()
                    playTapSound()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .imageScale(.medium)
                        Text("Resume Study")
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(radius: 6)
                }
                .padding(.horizontal, 30)
                
                Button(action: {
                    // Reset the quiz state and start again
                    self.showResult = false
                    self.score = 0
                    self.currentIndex = 0
                    self.selectedAnswer = nil
                    self.generateQuiz()
                    playTapSound()
                }) {
                    Text("More Quiz")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }
                .padding(.horizontal, 30)
            }
            .onAppear {
                // Trigger confetti and sound when result page appears
                confettiTrigger += 1
                AudioServicesPlaySystemSound(1025) // Congrat sound
                // Save quiz stats to CSV
                let stat = QuizStat(
                    date: Date(),
                    quizType: "thai to burmese",
                    score: score,
                    totalQuestions: questions.count,
                    correctAnswers: score
                )
                QuizStatsManager.shared.append(stat: stat)
            }
        }
    }

    // MARK: - Logic
    private func decodeCategoryMap() -> [String: Bool] {
        guard !quizCategoryMapJSON.isEmpty, let data = quizCategoryMapJSON.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    private func generateQuiz() {
        // Base pool: valid entries (have Burmese). Category inclusion is controlled via Quiz Settings.
        let base = loadCSV().filter {
            !($0.burmese ?? "").isEmpty
        }
        // Apply category inclusion from Quiz Settings
        let map = decodeCategoryMap()
        var items: [VocabularyEntry]
        if map.isEmpty {
            items = base
        } else {
            items = base.filter { entry in
                if let c = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                    return map[c] ?? false
                }
                // If categories are configured, exclude uncategorized by default
                return false
            }
            // Fallback to full pool if selection yields too few items
            if items.count < 3 { items = base }
        }
        guard items.count >= 3 else { return }

        let covered = decodeCoveredIDs()
        let eligibleIDs = Set(items.map { $0.id })
        var remaining = items.filter { !covered.contains($0.id) }
        if !eligibleIDs.isEmpty, covered.isSuperset(of: eligibleIDs) {
            encodeCoveredIDs([])
            remaining = items
        }
        if remaining.count < 3 {
            encodeCoveredIDs([])
            remaining = items
        }

        var qs: [QuizQuestion] = []
        let pool = remaining.shuffled()

        for item in pool.prefix(5) {
            let correct = item.burmese ?? ""
            let correctLen = correct.count
            // Try to find distractors of similar length (±30%)
            var distractors = items.compactMap { $0.burmese }
                .filter { $0 != correct && abs($0.count - correctLen) <= max(2, Int(Double(correctLen) * 0.3)) }
                .shuffled().prefix(2)

            // If not enough, relax to ±50%
            if distractors.count < 2 {
                distractors = items.compactMap { $0.burmese }
                    .filter { $0 != correct && abs($0.count - correctLen) <= max(3, Int(Double(correctLen) * 0.5)) }
                    .shuffled().prefix(2)
            }
            // If still not enough, just pick any that aren't the correct answer
            if distractors.count < 2 {
                distractors = items.compactMap { $0.burmese }
                    .filter { $0 != correct }
                    .shuffled().prefix(2)
            }

            var opts = Array(distractors)
            opts.append(correct)
            opts.shuffle()
            qs.append(QuizQuestion(vocabID: item.id, thai: item.thai, correctBurmese: correct, options: opts))
        }
        self.questions = qs
        // Speak first question after a short delay once questions are ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if !self.questions.isEmpty {
                self.speakThai(self.questions[0].thai)
            }
        }
    }

    private func answerSelected(_ option: String, for question: QuizQuestion) {
        stopTimer() // Stop the countdown
        let isCorrect = option == question.correctBurmese
        feedbackText = isCorrect ? "TRUE" : "FALSE"
        selectedAnswer = option
        
        // Play sound based on answer correctness
        if !isCorrect {
            SoundManager.playSound(1052) // Play sound for wrong answer
            
            // Schedule notification for failed quiz question
            NotificationEngine.shared.scheduleFailedQuizNotification(
                vocabID: question.vocabID,
                thaiWord: question.thai,
                burmeseTranslation: question.correctBurmese
            )

            // If this vocab was previously "Ready", downgrade back to "Drill"
            downgradeReadyToDrill(for: question.vocabID, thai: question.thai)
        }
        
        if option == question.correctBurmese {
            score += 1
            var covered = decodeCoveredIDs()
            covered.insert(question.vocabID)
            encodeCoveredIDs(covered)
            // Play cheer sound after 0.25s delay for correct answer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                SoundManager.playSound(1025) // Cheer sound for correct answer
            }
        }
        // proceed to next after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            feedbackText = nil
            selectedAnswer = nil
            if currentIndex + 1 < questions.count {
                currentIndex += 1 // TTS will be triggered by .onChange(of: currentIndex)
            } else {
                updateQuizStats(correct: score, attempts: questions.count)
                showResult = true
            }
        }
    }

    // MARK: - Stats update
    // MARK: - Sound
    private func playTapSound() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1104) // tap pop
        #endif
    }

    private func updateQuizStats(correct: Int = 0, attempts: Int = 0) {
        let now = Date()
        let cal = Calendar.current
        let last = Date(timeIntervalSince1970: quizLastDate)
        // Reset counters when boundaries passed
        if !cal.isDate(now, inSameDayAs: last) {
            quizYesterdayCount = quizDailyCount
            quizDailyCount = 0
            correctDaily = 0
            attemptDaily = 0
        }
        if cal.component(.weekOfYear, from: now) != cal.component(.weekOfYear, from: last) ||
            cal.component(.yearForWeekOfYear, from: now) != cal.component(.yearForWeekOfYear, from: last) {
            quizPrevWeekCount = quizWeeklyCount
            quizWeeklyCount = 0
            correctWeekly = 0
            attemptWeekly = 0
        }
        if cal.component(.month, from: now) != cal.component(.month, from: last) ||
            cal.component(.year, from: now) != cal.component(.year, from: last) {
            quizMonthlyCount = 0
            correctMonthly = 0
            attemptMonthly = 0
        }
        // Increment quiz session counts
        quizDailyCount += 1
        quizWeeklyCount += 1
        quizMonthlyCount += 1
        quizTotalCount += 1
        // Increment accuracy counts
        correctDaily += correct
        attemptDaily += attempts
        correctWeekly += correct
        attemptWeekly += attempts
        correctMonthly += correct
        attemptMonthly += attempts
        correctTotal += correct
        attemptTotal += attempts
        quizLastDate = now.timeIntervalSince1970
    }

    private func buttonColor(option: String, question: QuizQuestion) -> Color {
        guard let selected = selectedAnswer else { return Color(.systemGray6) }
        if option == question.correctBurmese {
            return option == selected ? .green.opacity(0.4) : .green.opacity(0.15)
        } else if option == selected {
            return .red.opacity(0.4)
        } else {
            return Color(.systemGray6)
        }
    }
    
    // MARK: - Timer Functions
    private func startTimer() {
        timeRemaining = 5
        stopTimer() // Clear any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Time's up - auto-select wrong answer
                handleTimeout()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func handleTimeout() {
        stopTimer()
        // Mark as wrong answer (no selection)
        let question = questions[currentIndex]
        selectedAnswer = "" // Empty selection indicates timeout
        
        // Show feedback
        feedbackText = "TIME'S UP"
        AudioServicesPlaySystemSound(1053) // Error sound
        
        // Schedule notification for failed word
        NotificationEngine.shared.scheduleFailedQuizNotification(
            vocabID: question.vocabID,
            thaiWord: question.thai,
            burmeseTranslation: question.correctBurmese
        )
        // Downgrade Ready -> Drill on timeout as well
        downgradeReadyToDrill(for: question.vocabID, thai: question.thai)
        
        // Move to next question after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            feedbackText = nil
            selectedAnswer = nil
            if currentIndex + 1 < questions.count {
                currentIndex += 1
            } else {
                showResult = true
                updateQuizStats(correct: score, attempts: questions.count)
            }
        }
    }

    // MARK: - Downgrade Ready -> Drill when a quiz is failed
    private func downgradeReadyToDrill(for id: UUID, thai: String) {
        // Update via VocabStore directly instead of NotificationCenter/UserDefaults
        // Try by ID first
        if let idx = vocabStore.items.firstIndex(where: { $0.id == id }) {
            var entry = vocabStore.items[idx]
            if entry.status == .ready {
                entry.status = .drill
                vocabStore.update(entry)
            }
            return
        }
        // Fallback: match by normalized Thai text (in case IDs differ)
        let norm: (String) -> String = { s in
            s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
        }
        let target = norm(thai)
        if let idx2 = vocabStore.items.firstIndex(where: { norm($0.thai) == target }) {
            var entry = vocabStore.items[idx2]
            if entry.status == .ready {
                entry.status = .drill
                vocabStore.update(entry)
            }
        }
    }
}

#Preview {
    DailyQuizView()
}
