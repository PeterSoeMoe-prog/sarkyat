import SwiftUI

struct CalendarProgressView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = "light"
    @AppStorage("studyStartDateTimestamp") private var studyStartDateTimestamp: Double = 0
    @AppStorage("dailyTargetHits") private var dailyTargetHits: Int = 5000
    @AppStorage("studyHistoryJSON") private var studyHistoryJSON: String = ""

    @Environment(\.dismiss) private var dismiss

    private var preferredColorScheme: ColorScheme? {
        switch appThemeRaw {
        case "light":
            return .light
        default:
            return nil
        }
    }

    private var startDate: Date {
        let fallback = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        if studyStartDateTimestamp > 0 {
            return Date(timeIntervalSince1970: studyStartDateTimestamp)
        }
        return fallback
    }

    private var today: Date { Date() }

    private var history: [String: Int] {
        guard let data = studyHistoryJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func dayKey(from date: Date) -> String {
        Formatters.day.string(from: date)
    }

    private func hits(on date: Date) -> Int {
        history[dayKey(from: date)] ?? 0
    }

    private func dotProgress(hits: Int) -> Int {
        let target = max(1, dailyTargetHits)
        let ratio = Double(hits) / Double(target)
        return min(5, max(0, Int(floor(ratio * 5.0))))
    }

    private func progressText(hits: Int) -> String {
        let target = max(1, dailyTargetHits)
        return "\(hits)/\(target)"
    }

    private func dateLabel(_ date: Date) -> String {
        RowFormatters.label.string(from: date)
    }

    private var dateRange: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: today)
        guard start <= end else { return [end] }

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return Array(dates.reversed())
    }

    private var oldestMissedTargetDayKey: String? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: today)
        guard start <= end else { return nil }

        let target = max(1, dailyTargetHits)
        var current = start
        while current <= end {
            if hits(on: current) < target {
                return dayKey(from: current)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(dateRange, id: \.self) { day in
                            let dayHits = hits(on: day)
                            let filled = dotProgress(hits: dayHits)

                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(dateLabel(day))
                                        .font(.headline)

                                    Text(progressText(hits: dayHits))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 8) {
                                    ForEach(0..<5, id: \.self) { idx in
                                        Circle()
                                            .fill(idx < filled ? Color.green : Color.gray.opacity(0.18))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .id(dayKey(from: day))
                        }
                    } header: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Starting \(dateLabel(startDate))")
                                    .font(.subheadline)
                                Text("Daily Target \(dailyTargetHits) Hits")
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                    }
                }
                .navigationTitle("Calendar")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onAppear {
                    guard let targetKey = oldestMissedTargetDayKey else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(targetKey, anchor: .top)
                    }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

fileprivate enum Formatters {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

fileprivate enum RowFormatters {
    static let label: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateStyle = .medium
        return f
    }()
}
