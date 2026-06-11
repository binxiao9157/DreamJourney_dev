import Foundation

// MARK: - Widget 与主 App 共享的简化数据模型

struct WidgetKBGraph: Codable {
    let events: [WidgetKBEvent]
}

struct WidgetKBEvent: Codable {
    let id: String
    let title: String
    let description: String?
    let year: Int?
    let month: Int?
}
