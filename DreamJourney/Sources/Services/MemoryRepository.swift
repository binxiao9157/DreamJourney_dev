import Foundation

// MARK: - MemoryRepository 单例：内存回忆数据存储（含持久化）
final class MemoryRepository {

    static let shared = MemoryRepository()
    private init() {
        loadPersistedMemories()
    }

    private var memories: [MemoryModel] = []

    // MARK: - 持久化
    /// UserDefaults Key（持久化用户新增回忆）
    private static let persistKey = "dj.persistedMemories"

    private func loadPersistedMemories() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistKey) else {
            print("[MemoirSync] MemoryRepository.loadPersisted: no data")
            return
        }
        do {
            let arr = try JSONDecoder().decode([MemoryModel].self, from: data)
            let cleaned = arr.filter { !Self.isLegacySeedMemory($0) }
            if cleaned.count != arr.count {
                if let cleanedData = try? JSONEncoder().encode(cleaned) {
                    UserDefaults.standard.set(cleanedData, forKey: Self.persistKey)
                }
                print("[MemoirSync] MemoryRepository.loadPersisted: removedLegacySeed=\(arr.count - cleaned.count)")
            }
            // 去重：避免与已存在的同 ID 重复
            let existing = Set(memories.map { $0.id })
            let newOnes = cleaned.filter { !existing.contains($0.id) }
            memories.insert(contentsOf: newOnes, at: 0)
            print("[MemoirSync] MemoryRepository.loadPersisted: loaded=\(newOnes.count), totalNow=\(memories.count)")
        } catch {
            print("[MemoirSync] MemoryRepository.loadPersisted: decode error=\(error)")
        }
    }

    /// 写盘
    private func savePersistedMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            UserDefaults.standard.set(data, forKey: Self.persistKey)
            print("[MemoirSync] MemoryRepository.savePersisted: count=\(memories.count)")
        } catch {
            print("[MemoirSync] MemoryRepository.savePersisted: encode error=\(error)")
        }
    }

    // MARK: - CRUD
    func getAll() -> [MemoryModel] {
        return memories.sorted { $0.createdAt > $1.createdAt }
    }

    func getAllByOwner(_ ownerId: String) -> [MemoryModel] {
        return memories.filter { $0.authorId == ownerId }.sorted { $0.createdAt > $1.createdAt }
    }

    func getPublicByOwner(_ ownerId: String) -> [MemoryModel] {
        return memories.filter { $0.authorId == ownerId && !$0.isPrivate }.sorted { $0.createdAt > $1.createdAt }
    }

    func get(by id: String) -> MemoryModel? {
        return memories.first { $0.id == id }
    }

    func add(_ memory: MemoryModel) {
        memories.insert(memory, at: 0)
        savePersistedMemories()
        print("[MemoirSync] MemoryRepository.add: id=\(memory.id), title=\(memory.title), authorId=\(memory.authorId), total=\(memories.count) → post .djNewMemoryCreated")
        NotificationCenter.default.post(name: .djNewMemoryCreated, object: memory)
    }

    func update(_ memory: MemoryModel) {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index] = memory
            savePersistedMemories()
        }
    }

    func delete(id: String) {
        memories.removeAll { $0.id == id }
        savePersistedMemories()
    }

    func resetLocalStorage() {
        memories.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.persistKey)
        print("[MemoirSync] MemoryRepository.resetLocalStorage")
    }

    func addComment(_ comment: CommentModel, to memoryId: String) {
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].comments.append(comment)
            savePersistedMemories()
        }
    }

    func toggleLike(userId: String, userName: String, on memoryId: String) -> Bool {
        guard let index = memories.firstIndex(where: { $0.id == memoryId }) else { return false }
        if let likeIndex = memories[index].likes.firstIndex(where: { $0.userId == userId }) {
            memories[index].likes.remove(at: likeIndex)
            savePersistedMemories()
            return false  // 取消点赞
        } else {
            memories[index].likes.append(LikeModel(userId: userId, userName: userName))
            savePersistedMemories()
            return true   // 点赞成功
        }
    }

    func addSupplement(_ supplement: SupplementModel, to memoryId: String) {
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].supplements.append(supplement)
            savePersistedMemories()
        }
    }

    func togglePrivacy(memoryId: String) {
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].isPrivate.toggle()
            savePersistedMemories()
        }
    }

    private static func isLegacySeedMemory(_ memory: MemoryModel) -> Bool {
        memory.id.hasPrefix("mem_") ||
            memory.id.hasPrefix("roadshow_") ||
            memory.title.contains("上海 · 1975年7月") ||
            memory.title.contains("北京 · 1988年10月") ||
            memory.title.contains("成都 · 2003年5月") ||
            memory.title.contains("杭州 · 2015年9月") ||
            memory.title.contains("广州 · 2022年2月") ||
            memory.title.contains("南京 · 1990年3月")
    }

}
