import SwiftUI
import WidgetKit

// MARK: - Color Constants

private extension Color {
    /// 暖色米白背景
    static let warmBackground = Color(red: 0.98, green: 0.96, blue: 0.93)
    /// 深棕标题色
    static let warmTitle = Color(red: 0.15, green: 0.12, blue: 0.10)
    /// 橙色强调色（年份标签）
    static let warmAccent = Color(red: 0.93, green: 0.58, blue: 0.22)
    /// 次要文字色
    static let warmSecondary = Color(red: 0.45, green: 0.40, blue: 0.35)
}

// MARK: - Main View

struct TodayInHistoryView: View {
    var entry: TodayInHistoryEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.isEmpty {
                emptyStateView
            } else {
                switch family {
                case .systemSmall:
                    smallView
                case .systemMedium:
                    mediumView
                default:
                    smallView
                }
            }
        }
        .containerBackground(Color.warmBackground, for: .widget)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("📅")
                .font(.system(size: 32))
            Text("暂无历史记忆")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.warmTitle)
            Text("与寻梦环游多聊聊吧")
                .font(.system(size: 12))
                .foregroundColor(.warmSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Small Widget (1 event)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("历史上的今天")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.warmSecondary)
                Spacer()
            }

            Spacer()

            if let event = entry.events.first {
                // Year badge
                if event.year > 0 {
                    Text("\(String(event.year))年")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.warmAccent)
                        .cornerRadius(4)
                }

                // Title
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.warmTitle)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Medium Widget (2-3 events)

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("历史上的今天")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.warmSecondary)
                Spacer()
                Text(monthText)
                    .font(.system(size: 11))
                    .foregroundColor(.warmAccent)
            }

            Divider()
                .background(Color.warmSecondary.opacity(0.3))

            // Events list
            ForEach(entry.events) { event in
                eventRow(event: event)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Event Row

    private func eventRow(event: WidgetEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Year badge
            if event.year > 0 {
                Text("\(String(event.year))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.warmAccent)
                    .cornerRadius(3)
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.warmTitle)
                    .lineLimit(1)

                // Description snippet
                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.warmSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private var monthText: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: entry.date)
        return "\(month)月"
    }
}
