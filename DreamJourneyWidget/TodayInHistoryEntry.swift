import WidgetKit
import Foundation

struct TodayInHistoryEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]  // 最多 3 条
    let isEmpty: Bool
}

struct WidgetEvent: Identifiable {
    let id: String
    let title: String
    let year: Int
    let description: String?
}
