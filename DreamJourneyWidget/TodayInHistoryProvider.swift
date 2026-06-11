import WidgetKit
import Foundation

struct TodayInHistoryProvider: TimelineProvider {

    // MARK: - App Group Identifier

    private let appGroupIdentifier = "group.com.dreamjourney.shared"
    private let widgetDataFileName = "kb_widget_data.json"

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> TodayInHistoryEntry {
        TodayInHistoryEntry(
            date: Date(),
            events: [
                WidgetEvent(id: "placeholder", title: "全家去外滩合影", year: 1985, description: "那年夏天一家人去上海玩")
            ],
            isEmpty: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayInHistoryEntry) -> Void) {
        let entry = buildEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayInHistoryEntry>) -> Void) {
        let currentDate = Date()
        let entry = buildEntry(for: currentDate)

        // 计算明天凌晨 00:00 作为下次更新时间
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    // MARK: - Private

    /// 从 App Group 共享容器读取数据并构建 Entry
    private func buildEntry(for date: Date) -> TodayInHistoryEntry {
        let events = loadEventsForCurrentMonth(date: date)

        if events.isEmpty {
            return TodayInHistoryEntry(date: date, events: [], isEmpty: true)
        }

        // 最多取 3 条
        let displayEvents = Array(events.prefix(3))
        return TodayInHistoryEntry(date: date, events: displayEvents, isEmpty: false)
    }

    /// 从 App Group 共享容器读取 kb_widget_data.json 并筛选当月事件
    private func loadEventsForCurrentMonth(date: Date) -> [WidgetEvent] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return []
        }

        let fileURL = containerURL.appendingPathComponent(widgetDataFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        guard let graph = try? JSONDecoder().decode(WidgetKBGraph.self, from: data) else {
            return []
        }

        // 获取当前月份
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: date)

        // 筛选与当前月份相同的事件
        let matchingEvents = graph.events.compactMap { event -> WidgetEvent? in
            guard event.month == currentMonth else { return nil }
            return WidgetEvent(
                id: event.id,
                title: event.title,
                year: event.year ?? 0,
                description: event.description
            )
        }

        // 按年份排序（从远到近）
        return matchingEvents.sorted { $0.year < $1.year }
    }
}
