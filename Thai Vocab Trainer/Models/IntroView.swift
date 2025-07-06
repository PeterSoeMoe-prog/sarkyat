import SwiftUI
import AudioToolbox // For tap sound

struct IntroView: View {
    let totalCount: Int
    let vocabCount: Int

    @State private var navigateToVocab = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    @State private var selectedStartDate: Date = {
        var comp = DateComponents()
        comp.year = 2023
        comp.month = 6
        comp.day = 19
        return Calendar.current.date(from: comp) ?? Date()
    }()
    @State private var arrowVisible = false
    @State private var arrowOffset: CGFloat = 0 // This is for the animation

    // MARK: - NEW: State variables for Boost options
    @State private var selectedMins: Int = 30
    @State private var selectedCounts: Int = 5000
    @State private var selectedVocabs: Int = 10
    
    @State private var welcomeTextScale: CGFloat = 0.8 // Start slightly smaller than normal size
    @State private var welcomeTextOpacity: Double = 0 // Start invisible


    var daysCount: Int {
        let calendar = Calendar.current
        let today = Date()
        let daysPassed = calendar.dateComponents([.day], from: selectedStartDate, to: today).day ?? 0
        return daysPassed + 1
    }

    var averagePerDay: Int {
        daysCount > 0 ? Int(Double(totalCount) / Double(daysCount)) : 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 5) {
                
                
                Text("Welcome, Peter")
                                    .font(.title2)
                                    .fontWeight(.light)
                                    .foregroundColor(appTheme.welcomeMessageColor)
                                    .padding(.top, 14)
                                    .scaleEffect(welcomeTextScale)   // <<< PASTE/ENSURE THIS LINE IS HERE
                                    .opacity(welcomeTextOpacity)     // <<< PASTE/ENSURE THIS LINE IS HERE
                                    
                
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Add a tiny delay
                                            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                                                welcomeTextScale = 1.0
                                                welcomeTextOpacity = 1.0
                                            }
                                        }
                                    }

                
                VStack(spacing: 14) { // This VStack holds the StatViews and the Button
                                                       // The "Days Studied" StatView is moved from here.

                                    StatView(title: "Total Vocab Count", value: "\(totalCount)")

                                    // MARK: - NEW: HStack for side-by-side stats
                                    HStack {
                                        Spacer() // Optional: Helps with centering or distributing space

                                        StatView(title: "Days Studied", value: "\(daysCount)") // Moved here
                                        
                                        Spacer() // Provides space between the two StatViews

                                        StatView(title: "Number of Words", value: "\(vocabCount)") // Moved here
                                        
                                        Spacer() // Optional: Helps with centering or distributing space
                                    }
                                    .padding(.horizontal) // Add some horizontal padding to the HStack

                                    // The "Number of Words" StatView is moved from here.
                                    StatView(title: "Average Per Day", value: "\(averagePerDay)")

                                    // MARK: - Existing "Choose Your Boost" section
                                    Text("Choose Your Boost")
                                        .font(.title) // Or your chosen font size
                                        .padding(.top, 20)
                                        // .padding(.bottom, 0) // Keep this line if you want it very close

                                    HStack {
                                        // Mins Picker Column
                                        VStack(spacing: 0) {
                                            Text("Mins")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Picker("Mins", selection: $selectedMins) {
                                                ForEach([60, 40, 30, 20], id: \.self) { value in
                                                    // >>> MODIFIED HERE <<<
                                                    GlowingPickerText(value: value, textColor: .blue, glowColor: .blue)
                                                        .tag(value)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 100)
                                            .clipped()
                                        }

                                        Spacer()

                                        // Counts Picker Column
                                        VStack(spacing: 0) {
                                            Text("Counts")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Picker("Counts", selection: $selectedCounts) {
                                                ForEach([10000, 8000, 5000, 3000], id: \.self) { value in
                                                    // >>> MODIFIED HERE <<<
                                                    GlowingPickerText(value: value, textColor: .blue, glowColor: .blue)
                                                        .tag(value)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                        }

                                        Spacer()

                                        // Vocabs Picker Column
                                        VStack(spacing: 0) {
                                            Text("Vocabs")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Picker("Vocabs", selection: $selectedVocabs) {
                                                ForEach([20, 15, 10, 5], id: \.self) { value in
                                                    // >>> MODIFIED HERE <<<
                                                    GlowingPickerText(value: value, textColor: .blue, glowColor: .blue)
                                                        .tag(value)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 100)
                                            .clipped()
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 30) // Adjust this value (e.g., 20, 40) for more/less space.

                                    Button {
                                        AudioServicesPlaySystemSound(1104)
                                        navigateToVocab = true
                                    } label: {
                                        Text("↓")
                                            .font(.system(size: 180))
                                            .foregroundColor(appTheme.accentArrowColor)
                                            .opacity(arrowVisible ? 1 : 0.2)
                                            .offset(y: arrowOffset)
                                            .padding(.top, -0.4)
                                            .contentShape(Rectangle())
                                    }
                                    .offset(y: -50)
                                    .onAppear {
                                        withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                                            arrowVisible = true
                                            arrowOffset = 20
                                        }
                                    }
                                }
                
                
                Spacer()
            }
            
            .offset(y: 40)
            .padding()
            .background(appTheme.backgroundColor.ignoresSafeArea())
            .foregroundColor(appTheme.primaryTextColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        AudioServicesPlaySystemSound(1104)
                        // Simple toggle between light and dark
                        appTheme = (appTheme == .light) ? .dark : .light
                    }) {
                        Image(systemName: appTheme.iconName)
                            .imageScale(.large)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 1) {
                        Text("started on")
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.trailing, 1)

                        DatePicker("", selection: $selectedStartDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accentColor(.yellow)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .fullScreenCover(isPresented: $navigateToVocab) {
                ContentView()
                    .preferredColorScheme(appTheme.colorScheme)
            }
        }
    }

    func loadCSVEntries() -> [VocabularyEntry] {
        guard let filepath = Bundle.main.path(forResource: "vocab", ofType: "csv") else { return [] }
        do {
            let content = try String(contentsOfFile: filepath, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            var entries: [VocabularyEntry] = []
            for (index, line) in lines.enumerated() {
                if index == 0 { continue }
                let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if cols.count >= 4 {
                    let status = VocabularyStatus(rawValue: cols[3].capitalized) ?? .queue
                    let count = Int(cols[2]) ?? 0
                    let burmese = cols[1].isEmpty ? nil : cols[1]
                    entries.append(VocabularyEntry(thai: cols[0], burmese: burmese, count: count, status: status))
                }
            }
            return entries
        } catch {
            print("CSV load error: \(error)")
            return []
        }
    }
}

struct GlowingPickerText: View {
    let value: Int // The number to display
    let textColor: Color // The main color of the text
    let glowColor: Color // The color of the glow effect

    @State private var glow = false // State to control the animation

    var body: some View {
        Text("\(value)")
            .font(.title2)      // Keeping the font size from our previous step
            .fontWeight(.bold) // Keeping it bold
            .foregroundColor(textColor) // Apply the main text color (will be blue)
            .shadow(color: glowColor.opacity(glow ? 0.8 : 0.2), radius: glow ? 5 : 4, x: 0, y: 0) // Glow shadow 1
            .shadow(color: glowColor.opacity(glow ? 0.5 : 0.1), radius: glow ? 25 : 6, x: 0, y: 0) // Glow shadow 2
            .onAppear {
                // Animate the glow when the view appears
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

// MAKE SURE YOUR StatView IS DEFINED. If you get "Cannot find 'StatView' in scope",
// you'll need to add its definition. Here's a common one, you can put this
// in a new file named StatView.swift or at the bottom of this file.
/*
struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text(value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}
*/

// Ensure GlowingText is also defined if used elsewhere.
struct GlowingText: View {
    @State private var glow = false

    var body: some View {
        Text("Update Stat")
            .font(.subheadline)
            .foregroundColor(.blue)
            .shadow(color: .blue.opacity(glow ? 0.8 : 0.2), radius: glow ? 5 : 4, x: 0, y: 0)
            .shadow(color: .blue.opacity(glow ? 0.5 : 0.1), radius: glow ? 25 : 6, x: 0, y: 0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

// Don't forget your PreviewProvider, if it's in this file:
/*
struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView(totalCount: 150, vocabCount: 100) // Adjust if you had more parameters
    }
}
*/
