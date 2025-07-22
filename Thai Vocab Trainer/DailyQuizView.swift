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

    init() {
        synthesizer.delegate = speechDelegate
    }

    private func speakThai(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        synthesizer.speak(utterance)
    }

    private func resumeSession() {
        @AppStorage("sessionPaused") var sessionPaused: Bool = false
        if sessionPaused {
            sessionPaused = false
            // Notify the counter view to resume
            NotificationCenter.default.post(name: .nextVocabulary, object: nil)
        }
    }

    private struct QuizQuestion: Identifiable {
        let id = UUID()
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
    // Quiz stats storage
    @AppStorage("quizDailyCount") private var quizDailyCount: Int = 0
    @AppStorage("quizWeeklyCount") private var quizWeeklyCount: Int = 0
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
                // Popup overlay
                if let fb = feedbackText {
                    Text(fb)
                        .font(.system(size: 60, weight: .heavy))
                        .foregroundColor(fb == "TRUE" ? .green : .red)
                        .offset(y: -150)
                        .transition(.scale)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: feedbackText)
        
                .confettiCannon(trigger: $confettiTrigger, 
                        num: 100, 
                        confettis: [.shape(.triangle), .shape(.circle)], 
                        colors: [.yellow, .orange], 
                        repetitions: 1, 
                        repetitionInterval: 0.1)
    }

    // MARK: - Views
    private func quizCard(for question: QuizQuestion) -> some View {
        VStack(spacing: 24) {
            Text("Question \(currentIndex + 1) / \(questions.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(question.thai)
                .font(.largeTitle)
                .padding(.top, 16)
                .onTapGesture {
                    speakThai(question.thai)
                }
                .onAppear {
                    // Auto-play Thai pronunciation after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        speakThai(question.thai)
                    }
                }

            Spacer()

            VStack(spacing: 12) {
                ForEach(question.options, id: \ .self) { option in
                    Button(action: {
                        // Play tap sound
                        playTapSound()
                        answerSelected(option, for: question)
                    }) {
                        Text(option.isEmpty ? "—" : option)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(radius: 6)
                    }
                    .disabled(selectedAnswer != nil) // lock after choose
                    .opacity(selectedAnswer != nil ? (option == question.correctBurmese ? 1 : 0.5) : 1)
                }
            }
            .animation(.default, value: selectedAnswer)

            Spacer()
        }
        .padding()
        .navigationTitle("Daily Quiz")
    }

    private var resultView: some View {
        VStack(spacing: 24) {
            Text("Daily Quiz")
                .font(.title)
            Text("Score: \(score) / \(questions.count)")
                .font(.largeTitle)
                .bold()
            VStack(spacing: 20) {
                NavigationLink(destination: ContentView()) {
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
                
                NavigationLink(destination: DailyStatView()) {
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
            }
            .onAppear {
                    // Trigger confetti and sound when result page appears
                    confettiTrigger += 1
                    AudioServicesPlaySystemSound(1025) // Congrat sound
                }
        }
    }

    // MARK: - Logic
    private func generateQuiz() {
        let items = loadCSV().filter { !($0.burmese ?? "").isEmpty }
        guard items.count >= 3 else { return }

        var qs: [QuizQuestion] = []
        let pool = items.shuffled()

        for item in pool.prefix(5) {
            let correct = item.burmese ?? ""
            // pick 2 other random wrong answers
            let distractors = items.compactMap { $0.burmese }.filter { $0 != correct }.shuffled().prefix(2)
            var opts = Array(distractors)
            opts.append(correct)
            opts.shuffle()
            qs.append(QuizQuestion(thai: item.thai, correctBurmese: correct, options: opts))
        }
        self.questions = qs
    }

    private func answerSelected(_ option: String, for question: QuizQuestion) {
        let isCorrect = option == question.correctBurmese
        feedbackText = isCorrect ? "TRUE" : "FALSE"
        selectedAnswer = option
        
        // Play sound based on answer correctness
        if !isCorrect {
            SoundManager.playSound(1052) // Play sound for wrong answer
        }
        
        if option == question.correctBurmese {
            score += 1
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
                currentIndex += 1
                // Play Thai pronunciation for the next question
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.speakThai(self.questions[currentIndex].thai)
                }
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
            quizDailyCount = 0
            correctDaily = 0
            attemptDaily = 0
        }
        if cal.component(.weekOfYear, from: now) != cal.component(.weekOfYear, from: last) ||
            cal.component(.yearForWeekOfYear, from: now) != cal.component(.yearForWeekOfYear, from: last) {
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
}

#Preview {
    DailyQuizView()
}
