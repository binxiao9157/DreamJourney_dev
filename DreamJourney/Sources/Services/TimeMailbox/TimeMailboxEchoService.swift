import Foundation

enum TimeMailboxEchoGenerationMode: String, Equatable {
    case safeFallbackText
}

struct TimeMailboxEchoResponse: Equatable {
    let replyText: String
    let mode: TimeMailboxEchoGenerationMode
    let evidenceLineCount: Int
}

protocol TimeMailboxEchoGenerating {
    func makeEcho(
        for letter: TimeMailboxLetter,
        evidence: TimeMailboxEchoEvidence
    ) -> TimeMailboxEchoResponse
}

final class TimeMailboxEchoService: TimeMailboxEchoGenerating {
    static let shared = TimeMailboxEchoService()

    func makeEcho(
        for letter: TimeMailboxLetter,
        evidence: TimeMailboxEchoEvidence
    ) -> TimeMailboxEchoResponse {
        let evidenceLines = Array(evidence.lines.prefix(5))
        let memoryLine = "你把这份想念认真保存了下来；信件正文仍只留在本机信箱里。"
        let evidenceLine: String
        if evidenceLines.isEmpty {
            evidenceLine = "这次没有找到足够的已授权记忆细节，所以不会替Ta编造具体经历。"
        } else {
            evidenceLine = """
            我能参考到的已授权记忆有：
            \(evidenceLines.map { "· \($0)" }.joined(separator: "\n"))
            """
        }

        let reply = """
        这段回应基于你留下的记忆整理而来，不是逝者真实回复。

        当前回声采用安全文本模式，暂不合成逝者声音。

        \(memoryLine)

        \(evidenceLine)

        愿这封信先替你收好今天的思念。你可以慢慢地把想说的话写下来，也可以在准备好的时候，把这份记忆带回现实生活里，交给还在身边的人一起珍藏。
        """

        return TimeMailboxEchoResponse(
            replyText: reply,
            mode: .safeFallbackText,
            evidenceLineCount: evidenceLines.count
        )
    }
}
