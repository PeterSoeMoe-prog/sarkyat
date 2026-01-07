import SwiftUI
import AVFoundation

// Shared model type used for CSV export
// Ensure VocabularyEntry is visible via import or same module

/// Simple Settings page presented from IntroView.
/// Add more options here as the app grows.
struct SettingsView: View {
    // Persisted theme selection shared with the rest of the app
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @AppStorage("studyStartDateTimestamp") private var studyStartDateTimestamp: Double = 0
    @AppStorage("dailyTargetHits") private var dailyTargetHits: Int = 5000
    @EnvironmentObject private var vocabStore: VocabStore

    // Dismiss environment
    @Environment(\.dismiss) private var dismiss
    // Share sheet state
    @State private var shareURL: ShareItem?
    // File importer state
    @State private var isImporting = false
    // Alerts
    @State private var exportError: String?
    @State private var importMessage: String?

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { appTheme == .dark },
            set: { newValue in appTheme = newValue ? .dark : .light }
        )
    }

    private var startDateBinding: Binding<Date> {
        let fallback = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        return Binding(
            get: {
                if studyStartDateTimestamp > 0 {
                    return Date(timeIntervalSince1970: studyStartDateTimestamp)
                }
                return fallback
            },
            set: { newValue in
                studyStartDateTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
            set: { newValue in UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
        )
    }

    private var isShowingExportError: Binding<Bool> {
        Binding<Bool>(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )
    }

    private var isShowingImportMessage: Binding<Bool> {
        Binding<Bool>(
            get: { importMessage != nil },
            set: { _ in importMessage = nil }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: darkModeBinding)
                        .tint(.accentColor)
                    }
                    HStack {
                        Text("Sound")
                        Spacer()
                        Toggle("", isOn: soundEnabledBinding)
                        .tint(.accentColor)
                    }
                }

                Section("Study") {
                    DatePicker(
                        "Starting Date",
                        selection: startDateBinding,
                        displayedComponents: [.date]
                    )

                    HStack {
                        Text("Daily Target")
                        Spacer()
                        TextField("5000", value: $dailyTargetHits, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                        Text("Hits")
                            .foregroundColor(.secondary)
                    }
                }

                // Data management
                Section("Data") {
                    // Import CSV button with pre-import logic
                    Button("Import CSV") {
                        isImporting = true
                    }
                    Button("Export CSV") {
                        Task.detached(priority: .userInitiated) {
                            do {
                                let snapshot = await MainActor.run { vocabStore.items }
                                let url = try CSVManager.makeTempCSV(from: snapshot)
                                await MainActor.run {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                await MainActor.run {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Export Quiz Stats") {
                        Task.detached(priority: .userInitiated) {
                            do {
                                let url = try QuizStatsManager.shared.exportQuizStatsToDocuments()
                                await MainActor.run {
                                    shareURL = ShareItem(url: url)
                                }
                            } catch {
                                await MainActor.run {
                                    exportError = error.localizedDescription
                                }
                            }
                        }
                    }
                    NavigationLink {
                        AudioRecordingView()
                    } label: {
                        Text("Notes")
                            .foregroundColor(.accentColor)
                    }
                    Button("Clean Duplicates") {
                        vocabStore.cleanDuplicates()
                    }
                }

                // Quiz settings placeholder
                Section("Quiz Setting") {
                    NavigationLink {
                        QuizSettingsView()
                    } label: {
                        Text("Quiz Settings")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Respect selected colour scheme
        .preferredColorScheme(appTheme.colorScheme)
        // Share sheet driven by item binding
        .sheet(item: $shareURL) { item in
            ActivityView(activityItems: [item.url])
        }
        // File importer for CSV
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            defer { isImporting = false }
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        if String(data: data, encoding: .utf8) != nil {
                            // Parse CSV on background queue to avoid blocking UI
                            DispatchQueue.global(qos: .userInitiated).async {
                                let importedItems: [VocabularyEntry] = [] // CSV parsing disabled for now
                                DispatchQueue.main.async {
                                    if importedItems.isEmpty {
                                        importMessage = "Imported 0 items (functionality not implemented yet)."
                                    } else {
                                        // CSV-only persistence: apply to store
                                        vocabStore.setItems(importedItems)
                                        importMessage = "Imported \(importedItems.count) items."
                                    }
                                }
                            }
                        }
                    } catch {
                        importMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                importMessage = "Import cancelled: \(error.localizedDescription)"
            }
        }
        // Export error alert
        .alert("Failed to export CSV", isPresented: isShowingExportError) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        // Import result alert
        .alert("Import CSV", isPresented: isShowingImportMessage) {
            Button("OK", role: .cancel) { importMessage = nil }
        } message: {
            Text(importMessage ?? "-")
        }
    }
}

struct AudioRecordingView: View {
    private struct RecordingItem: Identifiable, Equatable {
        let id: UUID
        let filename: String
        let createdAt: Date
        let fileName: String
        let isDone: Bool
    }

    private struct RecordingDraft {
        let id: UUID
        let filename: String
        let createdAt: Date
        let fileName: String
    }

    private final class PlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
        @Published var playingRecordingID: UUID?
        @Published var isPaused: Bool = false
        @Published var waveformHeights: [CGFloat] = Array(repeating: 0.18, count: 48)
        private var player: AVAudioPlayer?
        private var meterTimer: Timer?
        var onFinish: (() -> Void)?

        func stop() {
            meterTimer?.invalidate()
            meterTimer = nil
            player?.stop()
            player = nil
            playingRecordingID = nil
            isPaused = false
            waveformHeights = Array(repeating: 0.18, count: 48)
        }

        func pause() {
            meterTimer?.invalidate()
            meterTimer = nil
            player?.pause()
            isPaused = true
            waveformHeights = Array(repeating: 0.18, count: 48)
        }

        func resume() {
            guard let player else { return }
            if player.isPlaying { return }
            isPaused = false
            player.play()
            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.player else { return }
                player.updateMeters()
                let power = player.averagePower(forChannel: 0)
                let normalized = max(0, min(1, (power + 60) / 60))

                let next = CGFloat(0.12 + (normalized * 0.88))
                var updated = self.waveformHeights
                if !updated.isEmpty {
                    updated.removeFirst()
                }
                updated.append(next)

                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.06)) {
                        self.waveformHeights = updated
                    }
                }
            }
        }

        func play(url: URL, id: UUID) {
            stop()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true, options: [])

                let p = try AVAudioPlayer(contentsOf: url)
                p.delegate = self
                p.isMeteringEnabled = true
                p.prepareToPlay()
                p.play()
                player = p
                playingRecordingID = id
                isPaused = false

                meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    guard let self = self, let player = self.player else { return }
                    player.updateMeters()
                    let power = player.averagePower(forChannel: 0)
                    let normalized = max(0, min(1, (power + 60) / 60))

                    let next = CGFloat(0.12 + (normalized * 0.88))
                    var updated = self.waveformHeights
                    if !updated.isEmpty {
                        updated.removeFirst()
                    }
                    updated.append(next)

                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.06)) {
                            self.waveformHeights = updated
                        }
                    }
                }
            } catch {
                stop()
            }
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            DispatchQueue.main.async {
                self.stop()
                self.onFinish?()
            }
        }
    }

    private struct WaveformBarsView: View {
        let heights: [CGFloat]
        let isActive: Bool

        var body: some View {
            GeometryReader { geo in
                let count = max(1, heights.count)
                let spacing: CGFloat = 2
                let barWidth = max(2, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

                HStack(alignment: .center, spacing: spacing) {
                    ForEach(heights.indices, id: \.self) { i in
                        let barHeight = max(4, geo.size.height * heights[i])
                        Capsule()
                            .fill(
                                isActive
                                    ? LinearGradient(
                                        colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.35)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                    : LinearGradient(
                                        colors: [Color.secondary.opacity(0.35), Color.secondary.opacity(0.12)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                            )
                            .frame(width: barWidth, height: barHeight)
                            .frame(height: geo.size.height, alignment: .center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private struct WaveformFullWidthView: View {
        let isPlaying: Bool
        let activeHeights: [CGFloat]
        let idleHeights: [CGFloat]

        var body: some View {
            WaveformBarsView(heights: isPlaying ? activeHeights : idleHeights, isActive: isPlaying)
                .frame(height: 44)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.secondary.opacity(isPlaying ? 0.16 : 0.08))
                )
                .frame(maxWidth: .infinity)
        }
    }

    private struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1.0))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    private struct SecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(configuration.isPressed ? 0.16 : 0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: 1)
                )
                .foregroundColor(.primary)
        }
    }

    private struct PersistedRecordingItem: Codable {
        let id: String
        let filename: String
        let createdAt: Double
        let fileName: String?
        let isDone: Bool?
    }

    @State private var isRecording = false
    @State private var secondsElapsed: Int = 0
    @State private var recordings: [RecordingItem] = []
    @StateObject private var playback = PlaybackController()
    @AppStorage("audioRecordingsJSON") private var audioRecordingsJSON: String = "[]"

    @State private var recorder: AVAudioRecorder?
    @State private var micPermissionError: String?
    @State private var isPreparingToRecord = false
    @State private var recordingDraft: RecordingDraft?
    @State private var isShowingResetConfirm = false
    @State private var isAutoPlayingAll = false
    @State private var autoPlayQueueIDs: [UUID] = []
    @State private var autoPlayIndex: Int = 0

    private let minRecordingSeconds: TimeInterval = 0.5

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private var timeString: String {
        let m = secondsElapsed / 60
        let s = secondsElapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func recordingsDirectoryURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func safeBaseName(from displayName: String) -> String {
        displayName
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func fnv1a64(_ input: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for b in input.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        return hash
    }

    private func idleWaveformHeights(for id: UUID, count: Int) -> [CGFloat] {
        let seed = fnv1a64(id.uuidString)
        var state = seed
        func nextUnit() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1
            let v = Double((state >> 33) & 0xFFFF) / Double(0xFFFF)
            return CGFloat(v)
        }

        let n = max(8, count)
        return (0..<n).map { i in
            let t = CGFloat(i) / CGFloat(max(1, n - 1))
            let envelope = 1.0 - abs(2.0 * t - 1.0)
            let noise = 0.35 + (nextUnit() * 0.65)
            let h = (0.18 + envelope * 0.62 * noise)
            return max(0.12, min(0.95, h))
        }
    }

    private func fileURL(for item: RecordingItem) -> URL {
        recordingsDirectoryURL().appendingPathComponent(item.fileName)
    }

    private func audioDurationSeconds(url: URL) -> TimeInterval {
        let assetSeconds = AVURLAsset(url: url).duration.seconds
        if assetSeconds.isFinite, assetSeconds > 0 {
            return assetSeconds
        }
        if let player = try? AVAudioPlayer(contentsOf: url), player.duration.isFinite, player.duration > 0 {
            return player.duration
        }
        return 0
    }

    private func playRecording(id: UUID) {
        guard let item = recordings.first(where: { $0.id == id }) else { return }
        let url = fileURL(for: item)
        guard FileManager.default.fileExists(atPath: url.path) else {
            micPermissionError = "Audio file not found. Please record again."
            return
        }
        playback.play(url: url, id: id)
    }

    private func playNextInQueue() {
        guard isAutoPlayingAll else { return }
        while autoPlayIndex < autoPlayQueueIDs.count {
            let id = autoPlayQueueIDs[autoPlayIndex]
            autoPlayIndex += 1
            if orderedActiveRecordingsOldestFirst.contains(where: { $0.id == id }) {
                playRecording(id: id)
                return
            }
        }
        isAutoPlayingAll = false
        autoPlayQueueIDs = []
        autoPlayIndex = 0
    }

    private func toggleAutoPlayAll() {
        if !isAutoPlayingAll {
            let ordered = orderedActiveRecordingsOldestFirst
            guard !ordered.isEmpty else { return }

            isAutoPlayingAll = true
            autoPlayQueueIDs = ordered.map { $0.id }
            autoPlayIndex = 0
            playback.onFinish = { [weak playback] in
                _ = playback
                DispatchQueue.main.async { self.playNextInQueue() }
            }
            playNextInQueue()
            return
        }

        if playback.isPaused {
            playback.resume()
        } else {
            playback.pause()
        }
    }

    private var doneCount: Int {
        recordings.filter { $0.isDone }.count
    }

    private var activeRecordings: [RecordingItem] {
        recordings.filter { !$0.isDone }
    }

    private var orderedActiveRecordingsOldestFirst: [RecordingItem] {
        activeRecordings.sorted { a, b in
            if a.createdAt != b.createdAt {
                return a.createdAt < b.createdAt
            }
            return a.filename < b.filename
        }
    }

    private var toolbarPlaybackNumber: Int? {
        if let id = playback.playingRecordingID {
            let n = activeRecordingNumberByID[id] ?? 0
            return n > 0 ? n : nil
        }
        if isAutoPlayingAll, autoPlayIndex < autoPlayQueueIDs.count {
            let id = autoPlayQueueIDs[autoPlayIndex]
            let n = activeRecordingNumberByID[id] ?? 0
            return n > 0 ? n : nil
        }
        return nil
    }

    private var activeRecordingNumberByID: [UUID: Int] {
        let sorted = activeRecordings.sorted { a, b in
            if a.createdAt != b.createdAt {
                return a.createdAt < b.createdAt
            }
            return a.filename < b.filename
        }
        var map: [UUID: Int] = [:]
        for (idx, item) in sorted.enumerated() {
            map[item.id] = idx + 1
        }
        return map
    }

    private func markDone(_ item: RecordingItem) {
        if playback.playingRecordingID == item.id {
            playback.stop()
        }
        if let idx = recordings.firstIndex(where: { $0.id == item.id }) {
            let current = recordings[idx]
            if !current.isDone {
                SoundManager.playQuizSuccess()
            }
            recordings[idx] = RecordingItem(
                id: current.id,
                filename: current.filename,
                createdAt: current.createdAt,
                fileName: current.fileName,
                isDone: true
            )
        }
    }

    private func deleteActiveRecordings(at offsets: IndexSet) {
        let snapshot = activeRecordings
        for index in offsets {
            guard snapshot.indices.contains(index) else { continue }
            let item = snapshot[index]

            if playback.playingRecordingID == item.id {
                playback.stop()
            }

            let url = fileURL(for: item)
            try? FileManager.default.removeItem(at: url)
            recordings.removeAll { $0.id == item.id }
        }
    }

    private func resetAll() {
        playback.stop()
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPreparingToRecord = false
        recordingDraft = nil

        for item in recordings {
            let url = fileURL(for: item)
            try? FileManager.default.removeItem(at: url)
        }
        recordings = []
        audioRecordingsJSON = "[]"
    }

    var body: some View {
        VStack(spacing: 0) {
            if !activeRecordings.isEmpty {
                List {
                    Section {
                        ForEach(activeRecordings, id: \.id) { item in
                            Button {
                                guard !(isRecording || isPreparingToRecord) else { return }
                                isAutoPlayingAll = false
                                autoPlayQueueIDs = []
                                autoPlayIndex = 0
                                playback.onFinish = nil

                                let url = fileURL(for: item)

                                guard FileManager.default.fileExists(atPath: url.path) else {
                                    micPermissionError = "Audio file not found. Please record again."
                                    return
                                }

                                if playback.playingRecordingID == item.id {
                                    if playback.isPaused {
                                        playback.resume()
                                    } else {
                                        playback.pause()
                                    }
                                } else {
                                    playback.play(url: url, id: item.id)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    WaveformFullWidthView(
                                        isPlaying: playback.playingRecordingID == item.id,
                                        activeHeights: playback.waveformHeights,
                                        idleHeights: idleWaveformHeights(for: item.id, count: playback.waveformHeights.count)
                                    )

                                    HStack {
                                        Text("\(activeRecordingNumberByID[item.id] ?? 0)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 22, alignment: .trailing)

                                        Text(item.filename)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Spacer()
                                    }
                                }
                                .frame(minHeight: 104)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isRecording || isPreparingToRecord)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markDone(item)
                                } label: {
                                    Text("Done")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete(perform: deleteActiveRecordings)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Text(timeString)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                if isRecording {
                    HStack(spacing: 12) {
                        Button {
                            recorder?.stop()
                            recorder = nil
                            isRecording = false
                            secondsElapsed = 0

                            if let draft = recordingDraft {
                                let url = recordingsDirectoryURL().appendingPathComponent(draft.fileName)
                                try? FileManager.default.removeItem(at: url)
                            }
                            recordingDraft = nil
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .foregroundColor(.red)

                        Button {
                            let draft = recordingDraft
                            let url: URL? = draft.map { recordingsDirectoryURL().appendingPathComponent($0.fileName) }

                            let durationFromRecorder = recorder?.currentTime ?? 0
                            recorder?.stop()
                            recorder = nil
                            isRecording = false

                            let durationFromFile: TimeInterval = url.map(audioDurationSeconds(url:)) ?? 0
                            let duration = max(durationFromFile, durationFromRecorder)
                            secondsElapsed = 0

                            if duration < minRecordingSeconds {
                                if let url {
                                    try? FileManager.default.removeItem(at: url)
                                }
                                recordingDraft = nil
                                micPermissionError = "Recording too short."
                                return
                            }

                            if let draft {
                                recordings.insert(
                                    RecordingItem(id: draft.id, filename: draft.filename, createdAt: draft.createdAt, fileName: draft.fileName, isDone: false),
                                    at: 0
                                )
                            }
                            recordingDraft = nil
                        } label: {
                            Label("Save", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    Button {
                        playback.stop()

                        isPreparingToRecord = true

                        let session = AVAudioSession.sharedInstance()
                        session.requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                defer { isPreparingToRecord = false }
                                guard granted else {
                                    micPermissionError = "Microphone permission is required to record notes."
                                    return
                                }
                                do {
                                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                                    try session.setActive(true, options: [])

                                    let now = Date()
                                    let displayName = Self.filenameFormatter.string(from: now)
                                    let fileName = safeBaseName(from: displayName) + ".m4a"
                                    let url = recordingsDirectoryURL().appendingPathComponent(fileName)

                                    recordingDraft = RecordingDraft(id: UUID(), filename: displayName, createdAt: now, fileName: fileName)

                                    let settings: [String: Any] = [
                                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                        AVSampleRateKey: 44100,
                                        AVNumberOfChannelsKey: 1,
                                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                                    ]

                                    let r = try AVAudioRecorder(url: url, settings: settings)
                                    r.prepareToRecord()
                                    r.record()
                                    recorder = r

                                    isRecording = true
                                    secondsElapsed = 0
                                } catch {
                                    recordingDraft = nil
                                    micPermissionError = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Label("Record", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPreparingToRecord)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !recordings.isEmpty {
                    Text("\(doneCount)/\(recordings.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleAutoPlayAll()
                } label: {
                    HStack(spacing: 6) {
                        if let n = toolbarPlaybackNumber {
                            Text("\(n)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 14, alignment: .trailing)
                        }
                        Image(systemName: (isAutoPlayingAll && !playback.isPaused) ? "pause.fill" : "play.fill")
                    }
                }
                .disabled(isRecording || isPreparingToRecord || orderedActiveRecordingsOldestFirst.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    isShowingResetConfirm = true
                }
                .foregroundColor(.red)
                .disabled(isRecording || isPreparingToRecord)
            }
        }
        .alert("Reset Notes", isPresented: $isShowingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetAll() }
        } message: {
            Text("This will delete all recorded voice rows and their audio files.")
        }
        .onAppear {
            playback.onFinish = { DispatchQueue.main.async { self.playNextInQueue() } }
            guard let data = audioRecordingsJSON.data(using: .utf8) else { return }
            guard let decoded = try? JSONDecoder().decode([PersistedRecordingItem].self, from: data) else { return }
            recordings = decoded.map { dto in
                let uuid = UUID(uuidString: dto.id) ?? UUID()
                let derivedFileName = safeBaseName(from: dto.filename) + ".m4a"
                return RecordingItem(
                    id: uuid,
                    filename: dto.filename,
                    createdAt: Date(timeIntervalSince1970: dto.createdAt),
                    fileName: dto.fileName ?? derivedFileName,
                    isDone: dto.isDone ?? false
                )
            }
        }
        .onChange(of: recordings) { newValue in
            let encoded: [PersistedRecordingItem] = newValue.map {
                PersistedRecordingItem(
                    id: $0.id.uuidString,
                    filename: $0.filename,
                    createdAt: $0.createdAt.timeIntervalSince1970,
                    fileName: $0.fileName,
                    isDone: $0.isDone
                )
            }
            if let data = try? JSONEncoder().encode(encoded),
               let json = String(data: data, encoding: .utf8) {
                audioRecordingsJSON = json
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRecording else { return }
            secondsElapsed += 1
        }
        .alert("Audio", isPresented: Binding(
            get: { micPermissionError != nil },
            set: { _ in micPermissionError = nil }
        )) {
            Button("OK", role: .cancel) { micPermissionError = nil }
        } message: {
            Text(micPermissionError ?? "")
        }
    }
}

#if DEBUG
// Simple wrapper to make URL identifiable for .sheet(item:)
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
