import UIKit

// MARK: - KBGraphLayoutEngine

/// 力导向布局引擎 — 计算家族知识图谱中每个人物节点的坐标
/// 算法：库仑斥力 + 弹簧引力，迭代 50 次收敛
final class KBGraphLayoutEngine {

    // MARK: - Constants

    /// 斥力系数
    private let repulsionK: CGFloat = 8000.0

    /// 引力系数
    private let attractionK: CGFloat = 0.02

    /// 理想弹簧距离
    private let idealDistance: CGFloat = 160.0

    /// 最小节点间距
    private let minDistance: CGFloat = 100.0

    /// 迭代次数
    private let iterations: Int = 50

    /// 每次迭代最大位移（阻尼）
    private let maxDisplacement: CGFloat = 30.0

    // MARK: - Public

    /// 计算布局
    /// - Parameter people: 所有人物数据
    /// - Returns: personId → 坐标 的映射
    func computeLayout(for people: [KBPerson], graph: KBLiteGraph) -> [String: CGPoint] {
        guard !people.isEmpty else { return [:] }

        // 初始化位置：按关系分层放置
        var positions = initialPositions(for: people)

        // 构建关系边集合
        let edges = buildEdges(from: people, graph: graph)

        // 力导向迭代
        for _ in 0..<iterations {
            var forces: [String: CGPoint] = [:]
            for p in people { forces[p.id] = .zero }

            // 计算斥力（所有节点对之间）
            for i in 0..<people.count {
                for j in (i + 1)..<people.count {
                    let idA = people[i].id
                    let idB = people[j].id
                    guard let posA = positions[idA], let posB = positions[idB] else { continue }

                    let dx = posA.x - posB.x
                    let dy = posA.y - posB.y
                    let dist = max(sqrt(dx * dx + dy * dy), 1.0)

                    let force = repulsionK / (dist * dist)
                    let fx = force * dx / dist
                    let fy = force * dy / dist

                    forces[idA] = CGPoint(x: (forces[idA]?.x ?? 0) + fx,
                                          y: (forces[idA]?.y ?? 0) + fy)
                    forces[idB] = CGPoint(x: (forces[idB]?.x ?? 0) - fx,
                                          y: (forces[idB]?.y ?? 0) - fy)
                }
            }

            // 计算引力（有关系的节点对之间）
            for edge in edges {
                guard let posA = positions[edge.0], let posB = positions[edge.1] else { continue }

                let dx = posA.x - posB.x
                let dy = posA.y - posB.y
                let dist = max(sqrt(dx * dx + dy * dy), 1.0)

                let force = -attractionK * (dist - idealDistance)
                let fx = force * dx / dist
                let fy = force * dy / dist

                forces[edge.0] = CGPoint(x: (forces[edge.0]?.x ?? 0) + fx,
                                         y: (forces[edge.0]?.y ?? 0) + fy)
                forces[edge.1] = CGPoint(x: (forces[edge.1]?.x ?? 0) - fx,
                                         y: (forces[edge.1]?.y ?? 0) - fy)
            }

            // 应用力（带阻尼）
            for p in people {
                guard let f = forces[p.id], let pos = positions[p.id] else { continue }

                let disp = sqrt(f.x * f.x + f.y * f.y)
                let scale = disp > maxDisplacement ? maxDisplacement / disp : 1.0

                positions[p.id] = CGPoint(x: pos.x + f.x * scale,
                                          y: pos.y + f.y * scale)
            }
        }

        // 确保最小距离
        enforceMinDistance(&positions, people: people)

        return positions
    }

    // MARK: - Private

    /// 根据关系分层设置初始位置
    private func initialPositions(for people: [KBPerson]) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]

        var tier1: [KBPerson] = [] // 祖辈
        var tier2: [KBPerson] = [] // 父辈
        var tier3: [KBPerson] = [] // 其他
        var focalPerson: KBPerson?

        for p in people {
            if isGrandparentRelation(p.relation) {
                tier1.append(p)
            } else if isParentRelation(p.relation) {
                tier2.append(p)
            } else if p.relation == nil || p.relation == "自己" || p.name == "我" {
                if focalPerson == nil {
                    focalPerson = p
                } else {
                    tier3.append(p)
                }
            } else {
                tier3.append(p)
            }
        }

        if let s = focalPerson {
            positions[s.id] = .zero
        }

        // 分层环形放置
        placeTier(tier1, radius: 150, into: &positions)
        placeTier(tier2, radius: 250, into: &positions)
        placeTier(tier3, radius: 350, into: &positions)

        return positions
    }

    /// 在指定半径的圆上均匀放置节点
    private func placeTier(_ people: [KBPerson], radius: CGFloat, into positions: inout [String: CGPoint]) {
        guard !people.isEmpty else { return }
        let angleStep = 2.0 * CGFloat.pi / CGFloat(people.count)
        for (i, p) in people.enumerated() {
            let angle = angleStep * CGFloat(i) - CGFloat.pi / 2
            positions[p.id] = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
    }

    /// 判断关系是否为祖辈
    private func isGrandparentRelation(_ relation: String?) -> Bool {
        guard let r = relation else { return false }
        let keywords = ["祖父", "祖母", "外公", "外婆", "爷爷", "奶奶", "姥姥", "姥爷"]
        return keywords.contains(where: { r.contains($0) })
    }

    /// 判断关系是否为父辈
    private func isParentRelation(_ relation: String?) -> Bool {
        guard let r = relation else { return false }
        let keywords = ["父", "母", "爸", "妈", "叔", "伯", "姑", "舅", "姨"]
        return keywords.contains(where: { r.contains($0) })
    }

    /// 构建关系边
    private func buildEdges(from people: [KBPerson], graph: KBLiteGraph) -> [(String, String)] {
        var edges: Set<String> = []
        var result: [(String, String)] = []

        for p in people {
            for relatedId in p.relatedPersonIds {
                let key = [p.id, relatedId].sorted().joined(separator: "-")
                if !edges.contains(key) {
                    edges.insert(key)
                    result.append((p.id, relatedId))
                }
            }
        }

        // 如果没有显式关系，根据事件参与者推断
        if result.isEmpty {
            let allIds = Set(people.map { $0.id })
            for event in graph.events {
                let participants = event.participantIds.filter { allIds.contains($0) }
                for i in 0..<participants.count {
                    for j in (i + 1)..<participants.count {
                        let key = [participants[i], participants[j]].sorted().joined(separator: "-")
                        if !edges.contains(key) {
                            edges.insert(key)
                            result.append((participants[i], participants[j]))
                        }
                    }
                }
            }
        }

        return result
    }

    /// 强制最小距离
    private func enforceMinDistance(_ positions: inout [String: CGPoint], people: [KBPerson]) {
        for i in 0..<people.count {
            for j in (i + 1)..<people.count {
                let idA = people[i].id
                let idB = people[j].id
                guard let posA = positions[idA], let posB = positions[idB] else { continue }

                let dx = posA.x - posB.x
                let dy = posA.y - posB.y
                let dist = sqrt(dx * dx + dy * dy)

                if dist < minDistance && dist > 0 {
                    let overlap = (minDistance - dist) / 2.0
                    let nx = dx / dist
                    let ny = dy / dist

                    positions[idA] = CGPoint(x: posA.x + nx * overlap, y: posA.y + ny * overlap)
                    positions[idB] = CGPoint(x: posB.x - nx * overlap, y: posB.y - ny * overlap)
                }
            }
        }
    }
}
