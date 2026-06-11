import Foundation

enum TimeMailboxDeliveryStatus: String, Codable {
    case sealed
    case delivered
    case read
}

struct TimeMailboxLetter: Codable, Identifiable, Equatable {
    let id: String
    var recipientName: String
    var title: String
    var body: String
    var createdAt: Date
    var deliverAt: Date
    var deliveredAt: Date?
    var status: TimeMailboxDeliveryStatus
    var replyText: String?
    var boundaryAcknowledged: Bool
}
