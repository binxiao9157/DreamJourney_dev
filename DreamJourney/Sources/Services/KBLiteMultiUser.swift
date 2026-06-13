import Foundation

// MARK: - SharePackage

/// 知识库分享包，包含元数据和 graph JSON
struct SharePackage: Codable {
    let sourceUserId: String
    let sourceNickname: String
    let exportDate: Date
    let graphJSON: String  // kb_graph.json 内容
}

// MARK: - SyncRecord

/// 同步历史记录
struct KBSyncRecord: Codable {
    let sourceUserId: String
    let sourceNickname: String
    let syncDate: Date
    let addedCount: Int
}

// MARK: - KBLiteMultiUser

/// 多用户知识库管理
/// 每个用户有独立的 kb_graph_{userId}.json
/// 支持将其他家庭成员的知识库合并到自己的
final class KBLiteMultiUser {

    static let shared = KBLiteMultiUser()
    private init() {
        loadSyncHistory()
    }

    /// 同步历史记录
    private(set) var syncHistory: [KBSyncRecord] = []

    // MARK: - File Paths

    /// 获取知识库存放目录
    private var kbDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kbDir = docs.appendingPathComponent("knowledge_base")
        try? FileManager.default.createDirectory(at: kbDir, withIntermediateDirectories: true)
        return kbDir
    }

    /// 获取当前用户的知识库文件路径
    func currentUserGraphPath() -> URL {
        let userId = UserManager.shared.currentUser?.id ?? "default"
        return kbDirectory.appendingPathComponent("kb_graph_\(userId).json")
    }

    /// 获取所有家庭成员的知识库文件列表
    func allFamilyGraphFiles() -> [(userId: String, path: URL, lastModified: Date)] {
        let fm = FileManager.default
        var results: [(userId: String, path: URL, lastModified: Date)] = []

        do {
            let files = try fm.contentsOfDirectory(at: kbDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            for file in files {
                let name = file.lastPathComponent
                // 匹配 kb_graph_*.json 格式
                guard name.hasPrefix("kb_graph_") && name.hasSuffix(".json") else { continue }
                // 排除旧版无用户 ID 的文件
                guard name != "kb_graph.json" else { continue }

                let userId = String(name.dropFirst("kb_graph_".count).dropLast(".json".count))
                let attrs = try fm.attributesOfItem(atPath: file.path)
                let modDate = (attrs[.modificationDate] as? Date) ?? Date.distantPast

                results.append((userId: userId, path: file, lastModified: modDate))
            }
        } catch {
            print("[KBMultiUser] 读取知识库目录失败: \(error.localizedDescription)")
        }

        return results.sorted { $0.lastModified > $1.lastModified }
    }

    // MARK: - Merge

    /// 从另一个用户的知识库合并（去重）
    /// - Parameters:
    ///   - json: 对方导出的 JSON（KBLiteGraph 格式）
    ///   - sourceUserId: 对方的 userId
    /// - Returns: 新增实体数
    func mergeFromFamilyMember(json: String, sourceUserId: String) -> Int {
        guard let data = json.data(using: .utf8) else {
            print("[KBMultiUser] JSON 转 Data 失败")
            return 0
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let decodedGraph = try? decoder.decode(KBLiteGraph.self, from: data) else {
            print("[KBMultiUser] JSON 解码为 KBLiteGraph 失败")
            return 0
        }

        let manager = KBLiteManager.shared
        let importedGraph = manager.sanitizedIncomingGraph(decodedGraph)
        var addedCount = 0

        manager.writeGraph { graph in
            // 1. 合并人物：同名 + 同关系 → 合并 traits/facts（取并集），不同关系 → 新增
            for importedPerson in importedGraph.people {
                let existingMatch = graph.people.first { p in
                    (p.name == importedPerson.name || p.aliases.contains(importedPerson.name) ||
                     importedPerson.aliases.contains(p.name)) &&
                    p.relation == importedPerson.relation
                }

                if let existing = existingMatch,
                   let idx = graph.people.firstIndex(where: { $0.id == existing.id }) {
                    // 合并 traits（取并集）
                    for trait in importedPerson.traits where !graph.people[idx].traits.contains(trait) {
                        graph.people[idx].traits.append(trait)
                    }
                    // 合并 aliases（取并集）
                    for alias in importedPerson.aliases where !graph.people[idx].aliases.contains(alias) && alias != graph.people[idx].name {
                        graph.people[idx].aliases.append(alias)
                    }
                    // 补充 briefBio
                    if graph.people[idx].briefBio == nil {
                        graph.people[idx].briefBio = importedPerson.briefBio
                    }
                    // 标记来源
                    if !graph.people[idx].sourceSessionIds.contains(-1) {
                        graph.people[idx].sourceSessionIds.append(-1)
                    }
                    graph.people[idx].updatedAt = Date()
                    print("[KBMultiUser] 合并人物: \(existing.name)")
                } else {
                    // 新增人物
                    var newPerson = importedPerson
                    newPerson.sourceSessionIds.append(-1)
                    graph.people.append(newPerson)
                    addedCount += 1
                    print("[KBMultiUser] 新增人物: \(importedPerson.name)")
                }
            }

            // 2. 合并地点：同名 → 合并 description
            for importedPlace in importedGraph.places {
                let existingMatch = graph.places.first { p in
                    p.name == importedPlace.name || p.name.contains(importedPlace.name) || importedPlace.name.contains(p.name)
                }

                if let existing = existingMatch,
                   let idx = graph.places.firstIndex(where: { $0.id == existing.id }) {
                    // 合并 description
                    if graph.places[idx].description == nil {
                        graph.places[idx].description = importedPlace.description
                    }
                    // 补充 category
                    if graph.places[idx].category == nil {
                        graph.places[idx].category = importedPlace.category
                    }
                    // 标记来源
                    if !graph.places[idx].sourceSessionIds.contains(-1) {
                        graph.places[idx].sourceSessionIds.append(-1)
                    }
                    print("[KBMultiUser] 合并地点: \(existing.name)")
                } else {
                    var newPlace = importedPlace
                    newPlace.sourceSessionIds.append(-1)
                    graph.places.append(newPlace)
                    addedCount += 1
                    print("[KBMultiUser] 新增地点: \(importedPlace.name)")
                }
            }

            // 3. 合并事件：同 title + 同 year → 合并 participantIds
            for importedEvent in importedGraph.events {
                let existingMatch = graph.events.first { e in
                    e.title == importedEvent.title && e.year == importedEvent.year
                }

                if let existing = existingMatch,
                   let idx = graph.events.firstIndex(where: { $0.id == existing.id }) {
                    // 合并 participantIds
                    for pid in importedEvent.participantIds where !graph.events[idx].participantIds.contains(pid) {
                        graph.events[idx].participantIds.append(pid)
                    }
                    // 补充 description
                    if graph.events[idx].description == nil {
                        graph.events[idx].description = importedEvent.description
                    }
                    // 标记来源
                    if !graph.events[idx].sourceSessionIds.contains(-1) {
                        graph.events[idx].sourceSessionIds.append(-1)
                    }
                    print("[KBMultiUser] 合并事件: \(existing.title)")
                } else {
                    var newEvent = importedEvent
                    newEvent.sourceSessionIds.append(-1)
                    graph.events.append(newEvent)
                    addedCount += 1
                    print("[KBMultiUser] 新增事件: \(importedEvent.title)")
                }
            }

            // 4. 合并事实：statement 完全匹配或包含关系 → 去重
            for importedFact in importedGraph.facts {
                let stmt = importedFact.statement.trimmingCharacters(in: .whitespaces)
                guard !stmt.isEmpty else { continue }

                let isDuplicate = graph.facts.contains { existing in
                    existing.statement == stmt ||
                    (existing.statement.count >= 10 && stmt.count >= 10 &&
                     (existing.statement.contains(stmt) || stmt.contains(existing.statement)))
                }

                if !isDuplicate {
                    var newFact = importedFact
                    newFact.sourceSessionIds.append(-1)
                    graph.facts.append(newFact)
                    addedCount += 1
                    print("[KBMultiUser] 新增事实: \(stmt.prefix(40))...")
                }
            }

            graph.lastUpdated = Date()
        }

        print("[KBMultiUser] 合并完成: 新增 \(addedCount) 实体，来源用户: \(sourceUserId)")
        return addedCount
    }

    // MARK: - Share Package

    /// 生成当前知识库的分享包（包含 userId 和 nickname 元数据）
    func generateSharePackage(forFamilyMemberID familyMemberID: String? = nil) -> SharePackage? {
        guard let graphJSON = KBLiteManager.shared.exportJSON(surface: .familySync, familyMemberID: familyMemberID) else {
            print("[KBMultiUser] 导出 graph JSON 失败")
            return nil
        }

        let userId = UserManager.shared.currentUser?.id ?? "default"
        let nickname = UserManager.shared.currentUser?.nickname ?? "未知用户"

        let package = SharePackage(
            sourceUserId: userId,
            sourceNickname: nickname,
            exportDate: Date(),
            graphJSON: graphJSON
        )

        print("[KBMultiUser] 生成分享包: 用户=\(nickname), 大小=\(graphJSON.count)字节")
        return package
    }

    /// 从分享包导入
    /// - Returns: 新增实体数
    func importSharePackage(_ package: SharePackage) -> Int {
        print("[KBMultiUser] 开始导入分享包: 来源=\(package.sourceNickname)(\(package.sourceUserId)), 日期=\(package.exportDate)")

        let addedCount = mergeFromFamilyMember(json: package.graphJSON, sourceUserId: package.sourceUserId)

        // 记录同步历史
        let record = KBSyncRecord(
            sourceUserId: package.sourceUserId,
            sourceNickname: package.sourceNickname,
            syncDate: Date(),
            addedCount: addedCount
        )
        syncHistory.insert(record, at: 0)
        saveSyncHistory()

        return addedCount
    }

    // MARK: - Sync History Persistence

    private var syncHistoryPath: URL {
        kbDirectory.appendingPathComponent("sync_history.json")
    }

    private func loadSyncHistory() {
        guard FileManager.default.fileExists(atPath: syncHistoryPath.path) else { return }
        do {
            let data = try Data(contentsOf: syncHistoryPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            syncHistory = try decoder.decode([KBSyncRecord].self, from: data)
            print("[KBMultiUser] 加载同步历史: \(syncHistory.count) 条记录")
        } catch {
            print("[KBMultiUser] 加载同步历史失败: \(error.localizedDescription)")
        }
    }

    private func saveSyncHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(syncHistory)
            try data.write(to: syncHistoryPath, options: .atomic)
            print("[KBMultiUser] 同步历史已保存")
        } catch {
            print("[KBMultiUser] 保存同步历史失败: \(error.localizedDescription)")
        }
    }

}
