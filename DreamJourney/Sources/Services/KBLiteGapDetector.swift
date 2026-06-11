import Foundation

// MARK: - KBLiteGapDetector

/// 知识缺口检测器 — 识别知识库中人物/事件缺失的字段，生成引导性问题
final class KBLiteGapDetector {

    // MARK: - Singleton

    static let shared = KBLiteGapDetector()
    private init() {}

    // MARK: - Data Models

    /// 一个知识缺口
    struct KnowledgeGap {
        let entityType: String       // "person", "event", "place"
        let entityName: String
        let entityId: String
        let missingField: String     // "birthYear", "bio", "relation", "description", etc.
        let priority: Int            // 1=高（核心信息缺失）, 2=中, 3=低（nice-to-have）
        let suggestedQuestion: String

        /// 注入 system_prompt 的提示文本
        var promptHint: String {
            "\(entityName)的\(missingField)还未知。\(suggestedQuestion)"
        }
    }

    /// 缺口检测结果
    struct GapReport {
        let gaps: [KnowledgeGap]
        let totalGaps: Int
        let highPriorityGaps: Int

        /// 是否值得主动追问
        var shouldAskFollowup: Bool { highPriorityGaps > 0 && gaps.count <= 5 }

        /// 注入 system_prompt 的完整上下文
        func buildContextString(maxGaps: Int = 3) -> String {
            guard !gaps.isEmpty else { return "" }
            let top = gaps.prefix(maxGaps)
            let lines = top.map { "· \($0.promptHint)" }
            return "\n\n【知识缺口】以下信息尚未收集，请在合适的时机自然地引导长辈补充：\n" + lines.joined(separator: "\n") +
                   "\n不要连珠炮追问，每次只提一个缺口。如果长辈不愿意回答，不要勉强。"
        }
    }

    // MARK: - Public API

    /// 检测所有知识缺口
    func detectAllGaps() -> GapReport {
        let graph = KBLiteManager.shared.graph
        var gaps: [KnowledgeGap] = []

        // 1. 人物缺口
        for person in graph.people {
            // 缺少关系 → 高优先级
            if person.relation == nil {
                gaps.append(KnowledgeGap(
                    entityType: "person", entityName: person.name, entityId: person.id,
                    missingField: "关系", priority: 1,
                    suggestedQuestion: "\(person.name)是您的什么人呀？"
                ))
            }

            // 缺少简介
            if person.briefBio == nil {
                gaps.append(KnowledgeGap(
                    entityType: "person", entityName: person.name, entityId: person.id,
                    missingField: "简介", priority: 2,
                    suggestedQuestion: "能多跟我讲讲\(person.name)是一个什么样的人吗？"
                ))
            }

            // 特征少于 2 个
            if person.traits.count < 2 {
                gaps.append(KnowledgeGap(
                    entityType: "person", entityName: person.name, entityId: person.id,
                    missingField: "特征", priority: 3,
                    suggestedQuestion: "\(person.name)有什么特别的爱好或者性格特点吗？"
                ))
            }
        }

        // 2. 事件缺口
        for event in graph.events {
            // 缺少年份
            if event.year == nil {
                gaps.append(KnowledgeGap(
                    entityType: "event", entityName: event.title, entityId: event.id,
                    missingField: "时间", priority: 1,
                    suggestedQuestion: "您还记得\(event.title)具体是哪一年的事吗？"
                ))
            }

            // 缺少描述
            if event.description == nil {
                gaps.append(KnowledgeGap(
                    entityType: "event", entityName: event.title, entityId: event.id,
                    missingField: "详情", priority: 2,
                    suggestedQuestion: "\(event.title)这件事能再多讲一些细节吗？"
                ))
            }
        }

        // 3. 地点缺口
        for place in graph.places {
            // 缺少分类
            if place.category == nil {
                gaps.append(KnowledgeGap(
                    entityType: "place", entityName: place.name, entityId: place.id,
                    missingField: "类型", priority: 3,
                    suggestedQuestion: "\(place.name)是您的家乡、曾经住过的地方，还是去过的地方呀？"
                ))
            }

            // 缺少描述
            if place.description == nil {
                gaps.append(KnowledgeGap(
                    entityType: "place", entityName: place.name, entityId: place.id,
                    missingField: "描述", priority: 2,
                    suggestedQuestion: "\(place.name)是一个什么样的地方？有什么让您印象特别深的吗？"
                ))
            }
        }

        let highPriority = gaps.filter { $0.priority == 1 }.count
        return GapReport(gaps: gaps, totalGaps: gaps.count, highPriorityGaps: highPriority)
    }

    /// 获取最重要的 N 个缺口（按优先级排序）
    func topGaps(_ n: Int = 5) -> [KnowledgeGap] {
        let report = detectAllGaps()
        return report.gaps.sorted { $0.priority < $1.priority }.prefix(n).map { $0 }
    }

    /// 生成适合注入 system_prompt 的缺口上下文
    func buildGapContext() -> String {
        let report = detectAllGaps()
        return report.buildContextString()
    }
}