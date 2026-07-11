import WidgetKit
import Foundation

struct TodayInHistoryProvider: TimelineProvider {

    // MARK: - App Group Identifier

    private var appGroupIdentifier: String {
        let configured = Bundle.main.object(
            forInfoDictionaryKey: "DreamJourneyAppGroupIdentifier"
        ) as? String
        let normalized = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? "group.com.dreamjourney.shared" : normalized
    }

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> TodayInHistoryEntry {
        TodayInHistoryEntry(
            date: Date(),
            events: [
                WidgetEvent(id: "placeholder", title: "一段已授权的记忆摘要", year: 0)
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

    /// 只读取当前账号已授权的 schema v2 最小摘要。
    private func loadEventsForCurrentMonth(date: Date) -> [WidgetEvent] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ), let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return []
        }

        let fileURL = containerURL.appendingPathComponent(
            WidgetKnowledgeSnapshotReader.snapshotFileName
        )

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        let summaries = WidgetKnowledgeSnapshotReader.acceptedEvents(
            from: data,
            activeOwnerDigest: defaults.string(
                forKey: WidgetKnowledgeSnapshotReader.activeOwnerDigestKey
            )
        )

        // 获取当前月份
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: date)

        // 筛选与当前月份相同的事件
        let matchingEvents = summaries.compactMap { event -> WidgetEvent? in
            guard event.month == currentMonth else { return nil }
            return WidgetEvent(
                id: event.idDigest,
                title: event.title,
                year: event.year ?? 0
            )
        }

        // 按年份排序（从远到近）
        return matchingEvents.sorted { $0.year < $1.year }
    }
}
