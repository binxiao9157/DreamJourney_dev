import Foundation

enum TimeMailboxDeliveryStatus: String, Codable {
    case sealed
    case delivered
    case read
}

struct TimeMailboxLetter: Codable, Identifiable, Equatable, MemoryPrivacyScoped {
    let id: String
    var recipientName: String
    var title: String
    var body: String
    var createdAt: Date
    var deliverAt: Date
    var deliveredAt: Date?
    var status: TimeMailboxDeliveryStatus
    var replyText: String?
    var echoMode: TimeMailboxEchoGenerationMode?
    var echoEvidenceLineCount: Int?
    var boundaryAcknowledged: Bool
    var privacyMetadata: MemoryPrivacyMetadata

    init(
        id: String,
        recipientName: String,
        title: String,
        body: String,
        createdAt: Date,
        deliverAt: Date,
        deliveredAt: Date?,
        status: TimeMailboxDeliveryStatus,
        replyText: String?,
        echoMode: TimeMailboxEchoGenerationMode? = nil,
        echoEvidenceLineCount: Int? = nil,
        boundaryAcknowledged: Bool,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.id = id
        self.recipientName = recipientName
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.deliverAt = deliverAt
        self.deliveredAt = deliveredAt
        self.status = status
        self.replyText = replyText
        self.echoMode = echoMode
        self.echoEvidenceLineCount = echoEvidenceLineCount
        self.boundaryAcknowledged = boundaryAcknowledged
        self.privacyMetadata = privacyMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case recipientName
        case title
        case body
        case createdAt
        case deliverAt
        case deliveredAt
        case status
        case replyText
        case echoMode
        case echoEvidenceLineCount
        case boundaryAcknowledged
        case privacyMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        recipientName = try container.decode(String.self, forKey: .recipientName)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deliverAt = try container.decode(Date.self, forKey: .deliverAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        status = try container.decode(TimeMailboxDeliveryStatus.self, forKey: .status)
        replyText = try container.decodeIfPresent(String.self, forKey: .replyText)
        echoMode = try container.decodeIfPresent(TimeMailboxEchoGenerationMode.self, forKey: .echoMode)
        echoEvidenceLineCount = try container.decodeIfPresent(Int.self, forKey: .echoEvidenceLineCount)
        boundaryAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .boundaryAcknowledged) ?? false
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: .localOnly)
    }
}

struct TimeMailboxLetterMetadata: Equatable {
    let id: String
    let recipientName: String
    let title: String
    let createdAt: Date
    let deliverAt: Date
    let deliveredAt: Date?
    let status: TimeMailboxDeliveryStatus
    let boundaryAcknowledged: Bool
    let privacyMetadata: MemoryPrivacyMetadata
}

struct TimeMailboxEchoEvidence: Equatable {
    var people: [String] = []
    var places: [String] = []
    var events: [String] = []
    var facts: [String] = []

    static let empty = TimeMailboxEchoEvidence()

    var isEmpty: Bool {
        people.isEmpty && places.isEmpty && events.isEmpty && facts.isEmpty
    }

    var lines: [String] {
        var result: [String] = []
        result.append(contentsOf: people.prefix(2).map { "人物：\($0)" })
        result.append(contentsOf: places.prefix(2).map { "地点：\($0)" })
        result.append(contentsOf: events.prefix(2).map { "事件：\($0)" })
        result.append(contentsOf: facts.prefix(3).map { "事实：\($0)" })
        return result
    }
}
