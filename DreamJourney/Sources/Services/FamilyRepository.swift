import Foundation

// MARK: - FamilyRepository 单例：亲属关系存储
final class FamilyRepository {

    static let shared = FamilyRepository()
    private init() {
        seedMockData()
        NotificationCenter.default.addObserver(self, selector: #selector(onKBUpdated), name: .kbLiteDidUpdate, object: nil)
        // 延迟首次同步（等知识库加载完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.syncFromKnowledgeBase()
        }
    }

    @objc private func onKBUpdated() {
        syncFromKnowledgeBase()
    }

    private var members: [FamilyMember] = []

    func getAll() -> [FamilyMember] { return members }

    func add(_ member: FamilyMember) {
        // 去重
        if !members.contains(where: { $0.name == member.name }) {
            members.append(member)
        }
    }

    func remove(id: String) {
        members.removeAll { $0.id == id }
    }

    func get(by id: String) -> FamilyMember? {
        return members.first { $0.id == id }
    }

    // MARK: - KBLite 同步：从知识库中提取人物 → 亲属圈

    /// 供外部按需调用的公开同步方法
    func refreshFromKnowledgeBase() {
        syncFromKnowledgeBase()
    }

    /// 将知识库中识别到的人物自动同步到亲属圈列表
    private func syncFromKnowledgeBase() {
        let graph = KBLiteManager.shared.graph
        guard !graph.people.isEmpty else { return }

        // 常见关系映射
        let relationKeywords: [(keyword: String, relation: String)] = [
            ("祖父", "grandfather"), ("爷爷", "grandfather"),
            ("祖母", "grandmother"), ("奶奶", "grandmother"),
            ("外公", "grandfather"), ("外婆", "grandmother"),
            ("爸爸", "father"), ("父亲", "father"),
            ("妈妈", "mother"), ("母亲", "mother"),
            ("老伴", "spouse"), ("老公", "husband"), ("老婆", "wife"),
            ("哥哥", "brother"), ("姐姐", "sister"),
            ("弟弟", "brother"), ("妹妹", "sister"),
            ("儿子", "son"), ("女儿", "daughter"),
            ("叔叔", "uncle"), ("阿姨", "aunt"),
            ("老师", "teacher"), ("师傅", "mentor"),
            ("同学", "classmate"), ("战友", "comrade"),
        ]

        for person in graph.people {
            // 检查是否已存在
            if members.contains(where: { $0.name == person.name || person.aliases.contains($0.name) }) {
                continue
            }

            // 推断关系
            let relation: String
            if let rel = person.relation {
                relation = rel
            } else {
                // 从名字推断关系
                var guessed = "亲属"
                for (keyword, rel) in relationKeywords {
                    if person.name.contains(keyword) {
                        guessed = rel
                        break
                    }
                }
                // 从特征推断
                if guessed == "亲属", !person.traits.isEmpty {
                    guessed = person.traits.first!
                }
                relation = guessed
            }

            // 在线状态：最近 24 小时内有会话更新的人物标记为"在线"
            let isRecent = person.sourceSessionIds.last.map { $0 >= KBLiteManager.shared.graph.sessionCount - 1 } ?? false

            let lastUpdated: String
            if isRecent {
                lastUpdated = "刚刚聊到"
            } else if let lastSession = person.sourceSessionIds.last {
                lastUpdated = "第\(lastSession)次会话"
            } else {
                lastUpdated = "未知"
            }

            let member = FamilyMember(
                id: "kb_\(person.id.prefix(8))",
                name: person.name,
                relation: relation,
                isOnline: isRecent,
                lastUpdated: lastUpdated
            )
            members.append(member)
        }

        print("[FamilyRepo] 🔄 已从知识库同步 \(graph.people.count) 人 → 亲属圈 (总数: \(members.count))")
    }

    // MARK: - Mock 数据
    private func seedMockData() {
        members = [
            FamilyMember(id: "fm_001", name: "林静文", relation: "祖母",  phone: nil, isOnline: false, lastUpdated: "2小时前"),
            FamilyMember(id: "fm_002", name: "张国强", relation: "父亲",  phone: nil, isOnline: false, lastUpdated: "昨天"),
            FamilyMember(id: "fm_003", name: "周美芳", relation: "母亲",  phone: nil, isOnline: true,  lastUpdated: "刚刚")
        ]
    }
}
