import SwiftUI
import AudioToolbox
import ConfettiSwiftUI
import AVFoundation

struct CounterView: View {
    @Binding var item: VocabularyEntry
    @Binding var isPresented: Bool

    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    @State private var selectedIncrement: Int = 5
    let increments = [10, 5, 2, 1]
    
    
    @State private var confettiTrigger: Int = 0
    
    
    @State private var bigCircleScale: CGFloat = 1.0
    @StateObject private var sessionTimer = SessionTimer()
    @State private var sessionCount: Int = 0

    @State private var smallCircleScale: CGFloat = 1.0
    @State private var bigCircleRotation: Double = 0
    @State private var smallCircleRotation: Double = 0
    @State private var bigCircleColor: Color = .blue
    @State private var smallCircleColor: Color = .blue

    @State private var previousCount: Int = 0

    @State private var sessionTextScale: CGFloat = 1.0
    @State private var sessionTextOpacity: Double = 1.0

    @State private var selectedStatusIndex: Int = 1 // Default to 🔥
    
    @State private var showMenu: Bool = true
    @State private var menuOffset: CGSize = .zero
    @State private var dragStartLocation: CGSize = .zero


    private var sessionDurationFormatted: String {
        let minutes = sessionTimer.sessionDurationSeconds / 60
        let seconds = sessionTimer.sessionDurationSeconds % 60 // <-- Change this line
        return String(format: "%02d:%02d", minutes, seconds)
    }
  

    let statusOptions = ["😫", "🔥", "💎"]
    let statusMapping: [VocabularyStatus] = [.queue, .drill, .ready]

    private let synthesizer = AVSpeechSynthesizer()

    init(item: Binding<VocabularyEntry>, isPresented: Binding<Bool>) {
        _item = item
        _isPresented = isPresented
        if let index = VocabularyStatus.allCases.firstIndex(of: item.wrappedValue.status) {
            _selectedStatusIndex = State(initialValue: index)
        }
        
       
    }
    

    var body: some View {
        NavigationStack {
            // MARK: - Root ZStack for Fixed Positioning
            ZStack {
                // Background color (moved here for full coverage)
                appTheme.backgroundColor.ignoresSafeArea()
                
                // Floating menu button at the top right
                
                
                
                // MARK: - 1. Thai Vocab & Burmese Text Block
                VStack(spacing: 8) {
                    Text(item.thai)
                        .font(.system(size: 33, weight: .regular))
                        .foregroundColor(appTheme.primaryTextColor)
                        .lineLimit(2) // Allow up to 2 lines
                        .minimumScaleFactor(0.5) // Shrink to 50% if needed
                        .fixedSize(horizontal: false, vertical: true) // Allow text to take necessary height
                        .onTapGesture {
                            speakThai(item.thai)
                        }

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
                VStack(spacing: 2) {
                    Text("\(item.count)")
                        .font(.system(size: 48, weight: .black, design: .default))
                        .italic()
                        .foregroundColor(appTheme.primaryTextColor)

                    Text("counts")
                        .font(.system(size: 12, weight: .thin))
                        .foregroundColor(.gray)
                }
                .offset(y: -200) // Position below Thai text

                // MARK: - 3. Big Circle & Pickers
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 6)
                        .background(Circle().fill(bigCircleColor))
                        .frame(width: 350, height: 350)
                        .scaleEffect(bigCircleScale)
                        .rotationEffect(.degrees(bigCircleRotation))
                        .overlay(
                            Text("↑")
                                .font(.system(size: 180))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            // Sound for the primary tap (like a click or confirmation)
                            AudioServicesPlaySystemSound(1104)
                            
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
                            item.count += selectedIncrement
                            sessionCount += selectedIncrement

                            // Animations for session count text
                            withAnimation(.easeOut(duration: 0.2)) {
                                sessionTextScale = 1.3
                                sessionTextOpacity = 1.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    sessionTextScale = 1.0
                                    sessionTextOpacity = 0.6
                                }
                            }

                            // Play the system cheer sound (1025) if a new hundred count is reached
                            if item.count / 100 > oldTotalCount / 100 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    AudioServicesPlaySystemSound(1025) // This is for the hundred milestone
                                }
                            }
                            
                            previousCount = item.count
                        }

                    // Status Picker (positioned relative to the ZStack, not the circle)
                    Picker("", selection: $selectedStatusIndex) {
                        ForEach(0..<statusOptions.count, id: \.self) { index in
                            Text(statusOptions[index])
                        }
                    }
                    
                    .onChange(of: selectedStatusIndex) { _, newValue in
                        if newValue < statusMapping.count {
                            item.status = statusMapping[newValue]
                            if item.status == .ready {
                                // Play system sound 1027 for "ready" status
                                AudioServicesPlaySystemSound(1027) // <-- CHANGE THIS LINE
                                confettiTrigger += 1
                            }
                        }
                    }
                    
                    
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    .offset(x: -145, y: -200) // Adjusted offset for new ZStack
                    
                    // Increment Picker
                    Picker("", selection: $selectedIncrement) {
                        ForEach(increments, id: \.self) { value in
                            Text("+\(value)")
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    .offset(x: 160, y: -200) // Adjusted offset for new ZStack
                }
                .offset(y: 30) // Position the entire big circle block

                // MARK: - 4. Small Circle with Section Count Text
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                        .background(Circle().fill(smallCircleColor))
                        .frame(width: 100, height: 100)
                        .scaleEffect(smallCircleScale)
                        .rotationEffect(.degrees(smallCircleRotation))
                        .overlay(
                            Text("↓")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            AudioServicesPlaySystemSound(1052) // Small circle's primary tap sound
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
                            
                            // Update counts (decrementing)
                            item.count = max(0, item.count - selectedIncrement)
                            sessionCount = max(0, sessionCount - selectedIncrement)

                            // Play the system cheer sound (1025) if a new hundred count is crossed downwards
                            if item.count / 100 < oldTotalCount / 100 { // Note the '<' for decrement
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    AudioServicesPlaySystemSound(1025) // This is for the hundred milestone
                                }
                            }
                            
                            previousCount = item.count
                        }

                   
                }
                .offset(y: 270) // Position the entire small circle block

                // MARK: - 5. Session "Hits Now" (Bottom Left Overlay)
                VStack(alignment: .center, spacing: 2) {
                    Text("Hits Now")
                        .font(.system(size: 14, weight: .thin, design: .default))
                        .foregroundColor(.secondary)

                    Text("+\(sessionCount)")
                        .font(.system(size: 40, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                        .scaleEffect(sessionTextScale)
                        .opacity(sessionTextOpacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, 20)
                .offset(x: 35, y: -95)

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
                .offset(x: -8, y: -95)
                
                if showMenu {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .allowsHitTesting(false) // <-- THIS lets touches pass through
                        //.onTapGesture {
                         //   withAnimation {
                          //      showMenu = false
                         //   }
                       // }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showMenu = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text("Total Vocab Count")
                            .font(.system(size: 12, weight: .thin))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }

                    .frame(width: 140)
                    .padding()
                    .background(Color.gray.opacity(0.9))
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .position(x: UIScreen.main.bounds.width - 100 + menuOffset.width, y: 90 + menuOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                menuOffset = CGSize(width: dragStartLocation.width + value.translation.width,
                                                    height: dragStartLocation.height + value.translation.height)
                            }
                            .onEnded { _ in
                                dragStartLocation = menuOffset
                            }
                    )
                    .transition(.scale)
                }


            } // End of Root ZStack
            
            .confettiCannon(trigger: $confettiTrigger, num: 100, confettis: [.shape(.triangle), .shape(.circle)], colors: [.yellow, .orange], repetitions: 1, repetitionInterval: 0.1)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
                        isPresented = false
                    }
                }
            }
        } // End of NavigationStack
        .onAppear {
            previousCount = item.count
            sessionTimer.reset()
            sessionCount = 0 // Reset session count on appear for a fresh session
        }
        
        .preferredColorScheme(appTheme.colorScheme)
    }

    private func speakThai(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = 0.45
        synthesizer.stopSpeaking(at: .immediate) // Stop previous speech
        synthesizer.speak(utterance)
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
                CounterView(item: $sampleItem, isPresented: $show)
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
