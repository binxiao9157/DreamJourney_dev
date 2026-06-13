import Foundation
import CocoaLumberjack

// MARK: - 回忆录本地持久化（文件系统）
final class MemoirRepository {

    static let shared = MemoirRepository()

    // MARK: - Properties

    /// 内存缓存
    private var memoirs: [MemoirModel] = []

    /// 存储目录
    private let storageDirectory: URL

    // MARK: - Init

    private init() {
        // Application Support/memoirs/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("memoirs", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        // 从文件加载
        loadAllFromDisk()
    }

    // MARK: - Public API

    func getAll() -> [MemoirModel] {
        return memoirs.sorted { $0.createdAt > $1.createdAt }
    }

    func get(by id: String) -> MemoirModel? {
        return memoirs.first { $0.id == id }
    }

    func save(_ memoir: MemoirModel) {
        // 更新或新增
        let isNew: Bool
        if let index = memoirs.firstIndex(where: { $0.id == memoir.id }) {
            memoirs[index] = memoir
            isNew = false
        } else {
            memoirs.insert(memoir, at: 0)
            isNew = true
        }
        // 持久化到文件
        saveToDisk(memoir)

        DDLogInfo("[MemoirSync] save memoir: id=\(memoir.id), isNew=\(isNew), title=\(memoir.title), location=\(memoir.location), year=\(memoir.year), month=\(memoir.month), lat=\(memoir.latitude), lng=\(memoir.longitude), authorId=\(memoir.authorId)")

        // 只有新建时才发"新回忆录生成"通知（更新音频/编辑内容不发）
        // 同时同步生成一条二Tab足迹回忆标签（NEW 卡片）
        if isNew {
            NotificationCenter.default.post(name: .djNewMemoirGenerated, object: memoir)
            syncToMemoryRepository(memoir)
        }
    }

    // MARK: - 一Tab → 二Tab 桥接
    /// 新生成的回忆录 → 生成一条 MemoryModel 加入 MemoryRepository，
    /// 触发二Tab 足迹页地图标注刷新，并以 NEW 标签卡片形式呈现。
    /// id 复用 memoir.id，确保同一回忆录不会重复同步。
    private func syncToMemoryRepository(_ memoir: MemoirModel) {
        // 已存在则跳过（兜底防重复）
        if MemoryRepository.shared.get(by: memoir.id) != nil {
            DDLogInfo("[MemoirSync] skip sync — memory id=\(memoir.id) already exists")
            return
        }

        // 副标题：取散文首句或前 30 字符
        let subtitle: String = {
            let prose = memoir.prose.replacingOccurrences(of: "\n", with: " ")
            if let endIdx = prose.firstIndex(where: { "。！？.!?".contains($0) }) {
                return String(prose[..<endIdx])
            }
            return String(prose.prefix(30))
        }()

        let memory = MemoryModel(
            id: memoir.id,
            title: "\(memoir.location) · \(memoir.year)年\(memoir.month)月",
            subtitle: subtitle,
            fullContent: memoir.prose,                   // 完整散文持久化进 MemoryRepository，详情页正文使用
            location: memoir.location,
            year: memoir.year,
            month: memoir.month,
            latitude: memoir.latitude,
            longitude: memoir.longitude,
            imageNames: [],
            audioName: memoir.sessionId,                  // sessionId 作为录音文件名，详情页可加载 recordings/{sessionId}.m4a
            isPrivate: memoir.isPrivate,
            authorId: memoir.authorId
        )
        DDLogInfo("[MemoirSync] bridging → MemoryRepository.add: memoryId=\(memory.id), title=\(memory.title), authorId=\(memory.authorId)")
        MemoryRepository.shared.add(memory)
    }

    func delete(id: String) {
        memoirs.removeAll { $0.id == id }
        deleteFromDisk(id: id)
        // 联动删除已合成的音频文件
        MemoirTTSService.shared.deleteAudio(for: id)
    }

    // MARK: - 录音管理

    /// 保存对话录音文件到录音目录
    /// - Parameters:
    ///   - sourceURL: 录音源文件 URL
    ///   - sessionId: 会话 ID
    func saveRecording(from sourceURL: URL, sessionId: String) -> URL? {
        let destURL = recordingsDirectory.appendingPathComponent("\(sessionId).m4a")
        do {
            // 如果目标已存在，先删除
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            DDLogInfo("[MemoirRepository] 录音已保存: \(destURL.path)")
            return destURL
        } catch {
            DDLogError("[MemoirRepository] 保存录音失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取录音文件 URL
    func getRecordingURL(sessionId: String) -> URL? {
        let url = recordingsDirectory.appendingPathComponent("\(sessionId).m4a")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 删除录音文件
    func deleteRecording(sessionId: String) {
        let url = recordingsDirectory.appendingPathComponent("\(sessionId).m4a")
        try? FileManager.default.removeItem(at: url)
    }

    /// 录音存储目录
    private var recordingsDirectory: URL {
        let dir = storageDirectory.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Disk I/O

    private func fileURL(for id: String) -> URL {
        return storageDirectory.appendingPathComponent("\(id).json")
    }

    private func loadAllFromDisk() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for fileURL in files where fileURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  let memoir = try? JSONDecoder().decode(MemoirModel.self, from: data) else {
                continue
            }
            if Self.isLegacySeedMemoir(memoir) {
                try? FileManager.default.removeItem(at: fileURL)
                DDLogInfo("[MemoirRepository] removed legacy seed memoir: \(memoir.title)")
                continue
            }
            memoirs.append(memoir)
        }
    }

    private func saveToDisk(_ memoir: MemoirModel) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(memoir) else { return }
        try? data.write(to: fileURL(for: memoir.id), options: .atomic)
    }

    private func deleteFromDisk(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    private static func isLegacySeedMemoir(_ memoir: MemoirModel) -> Bool {
        let legacyPairs: Set<String> = [
            "上海外滩的记忆|上海外滩",
            "北京故宫之行|北京故宫",
            "成都火锅的味道|成都宽窄巷子"
        ]
        if legacyPairs.contains("\(memoir.title)|\(memoir.location)") {
            return true
        }
        return memoir.id.hasPrefix("roadshow_") ||
            memoir.prose.contains("这张照片，成了全家人最珍贵的记忆") ||
            memoir.prose.contains("那盒明信片，妈妈一直收在柜子里") ||
            memoir.prose.contains("奶奶这辈子吃得最豪放的一次")
    }

}

// MARK: - Notification

extension Notification.Name {
    /// 新回忆录生成完成
    static let djNewMemoirGenerated = Notification.Name("dj.memoir.newGenerated")
    /// 回忆录音频合成完成
    static let djMemoirAudioReady = Notification.Name("dj.memoir.audioReady")
    /// 对话已开始（录音服务监听）
    static let djDialogDidStart = Notification.Name("dj.dialog.didStart")
    /// 对话已停止（录音服务监听）
    static let djDialogDidStop = Notification.Name("dj.dialog.didStop")
}
