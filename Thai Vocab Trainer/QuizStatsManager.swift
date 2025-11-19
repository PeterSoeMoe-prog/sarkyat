import Foundation

struct QuizStat: Identifiable, Codable {
    var id: UUID { UUID() } // computed property, not stored, not part of Codable
    let date: Date
    let quizType: String
    let score: Int
    let totalQuestions: Int
    let correctAnswers: Int
    
    // CSV row representation
    var csvRow: String {
        let formatter = ISO8601DateFormatter()
        return "\(formatter.string(from: date)),\(quizType),\(score),\(totalQuestions),\(correctAnswers)"
    }
    
    static let csvHeader = "date,quiztype,score,totalQuestions,correctAnswers"
    
    static func fromCSVRow(_ row: String) -> QuizStat? {
        let comps = row.components(separatedBy: ",")
        guard comps.count == 5,
              let date = ISO8601DateFormatter().date(from: comps[0]),
              let score = Int(comps[2]),
              let totalQuestions = Int(comps[3]),
              let correctAnswers = Int(comps[4])
        else { return nil }
        return QuizStat(date: date, quizType: comps[1], score: score, totalQuestions: totalQuestions, correctAnswers: correctAnswers)
    }
}

class QuizStatsManager {
    /// Exports all quiz stats as a temporary CSV file and returns its URL
    func exportQuizStatsToDocuments() throws -> URL {
        let stats = loadAll()
        let header = QuizStat.csvHeader + "\n"
        let csvLines = stats.map { $0.csvRow }
        let csvString = header + csvLines.joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("quiz.csv")
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    static let shared = QuizStatsManager()
    private let filename = "quiz.csv"
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(filename)
    }
    
    // Append a new quiz stat
    func append(stat: QuizStat) {
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        let row = stat.csvRow + "\n"
        if !fileExists {
            try? QuizStat.csvHeader.appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            if let data = row.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            try? row.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    // Load all quiz stats
    func loadAll() -> [QuizStat] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: "\n").dropFirst().filter { !$0.isEmpty }
        return lines.compactMap { QuizStat.fromCSVRow($0) }
    }
}
