import Foundation

struct FactsFormatter {
    static func makeFacts(from summary: String?, growthInfo: String?) -> [String] {
        var facts: [String] = []
        if let summary {
            // Remove parentheses content
            let noParens = summary.replacingOccurrences(of: "\\([^\\)]*\\)", with: "", options: .regularExpression)
            // Split into sentences
            let sentences = noParens.components(separatedBy: ". ")
            for sentence in sentences.prefix(3) {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    facts.append(trimmed + (trimmed.hasSuffix(".") ? "" : "."))
                }
            }
        }
        if let growth = growthInfo, !growth.isEmpty, growth.lowercased() != "no data" {
            facts.append("Growth habit: \(growth).")
        }
        return facts
    }
} 