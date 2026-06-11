import WidgetKit
import SwiftUI

@main
struct DreamJourneyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayInHistoryWidget()
    }
}

struct TodayInHistoryWidget: Widget {
    let kind: String = "TodayInHistory"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayInHistoryProvider()) { entry in
            TodayInHistoryView(entry: entry)
        }
        .configurationDisplayName("历史上的今天")
        .description("展示家族知识库中与今天同月份的事件")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
