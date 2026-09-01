import Foundation

enum NarrativeReaderFontScale: String, CaseIterable, Codable, Sendable {
    case extraSmall, small, standard, large, extraLarge

    var pointSize: Double {
        switch self {
        case .extraSmall: return 16
        case .small: return 18
        case .standard: return 20
        case .large: return 23
        case .extraLarge: return 27
        }
    }
}

enum NarrativeReaderBackground: String, CaseIterable, Codable, Sendable {
    case paper, warm, green, night
}

struct NarrativeSemanticAnchor: Codable, Equatable, Sendable {
    let chapterKey: String
    let chapterVersionId: String
    let paragraphId: String
    let characterOffset: Int

    init(chapterKey: String, chapterVersionId: String, paragraphId: String, characterOffset: Int) {
        self.chapterKey = chapterKey
        self.chapterVersionId = chapterVersionId
        self.paragraphId = paragraphId
        self.characterOffset = max(0, characterOffset)
    }
}

struct NarrativeReadingState: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    var anchor: NarrativeSemanticAnchor?
    var fontScale: NarrativeReaderFontScale
    var background: NarrativeReaderBackground

    init(
        anchor: NarrativeSemanticAnchor? = nil,
        fontScale: NarrativeReaderFontScale = .standard,
        background: NarrativeReaderBackground = .paper
    ) {
        schemaVersion = Self.schemaVersion
        self.anchor = anchor
        self.fontScale = fontScale
        self.background = background
    }
}
