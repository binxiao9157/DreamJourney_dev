import UIKit
import UniformTypeIdentifiers

// MARK: - KBSyncViewController

/// 家族知识库同步页面
/// 功能：导出/导入知识库分享包，查看同步历史
final class KBSyncViewController: UIViewController {

    // MARK: - UI Elements

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .warmBackground
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "SyncCell")
        tv.register(KBSyncUserInfoCell.self, forCellReuseIdentifier: "UserInfoCell")
        tv.register(KBSyncActionCell.self, forCellReuseIdentifier: "ActionCell")
        tv.register(KBSyncHistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        tv.register(KBSyncFooterCell.self, forCellReuseIdentifier: "FooterCell")
        return tv
    }()

    // MARK: - Data

    private var syncHistory: [KBSyncRecord] {
        KBLiteMultiUser.shared.syncHistory
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家族知识库同步"
        view.backgroundColor = .warmBackground
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    private func exportKnowledgeBase() {
        guard let package = KBLiteMultiUser.shared.generateSharePackage() else {
            showToast("导出失败，请稍后重试", type: .error)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(package),
              let jsonString = String(data: data, encoding: .utf8) else {
            showToast("序列化失败", type: .error)
            return
        }

        // 创建临时文件用于分享
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "知识库_\(package.sourceNickname)_\(formatDateForFile(package.exportDate)).json"
        let tempFile = tempDir.appendingPathComponent(fileName)

        do {
            try jsonString.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            print("[KBMultiUser] 写入临时文件失败: \(error.localizedDescription)")
            showToast("导出失败", type: .error)
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [tempFile],
            applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }

    private func importKnowledgeBase() {
        let alert = UIAlertController(title: "导入家人的知识库", message: "选择导入方式", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "从剪贴板粘贴", style: .default) { [weak self] _ in
            self?.importFromClipboard()
        })

        alert.addAction(UIAlertAction(title: "从文件选择", style: .default) { [weak self] _ in
            self?.importFromFile()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    private func importFromClipboard() {
        guard let clipText = UIPasteboard.general.string, !clipText.isEmpty else {
            showToast("剪贴板为空", type: .error)
            return
        }

        processImportJSON(clipText)
    }

    private func importFromFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func processImportJSON(_ jsonString: String) {
        // 尝试解析为 SharePackage
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = jsonString.data(using: .utf8) else {
            showToast("数据格式错误", type: .error)
            return
        }

        if let package = try? decoder.decode(SharePackage.self, from: data) {
            // 确认导入
            let alert = UIAlertController(
                title: "确认导入",
                message: "来源：\(package.sourceNickname)\n导出时间：\(formatDate(package.exportDate))\n\n确定要合并这份知识库吗？",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self] _ in
                let count = KBLiteMultiUser.shared.importSharePackage(package)
                self?.showToast("导入成功，新增 \(count) 条知识", type: .success)
                self?.tableView.reloadData()
            })
            present(alert, animated: true)
        } else {
            // 尝试作为裸 graph JSON 导入
            if let _ = try? decoder.decode(KBLiteGraph.self, from: data) {
                let alert = UIAlertController(
                    title: "确认导入",
                    message: "检测到知识库数据（无元信息），确定要合并吗？",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self] _ in
                    let count = KBLiteMultiUser.shared.mergeFromFamilyMember(json: jsonString, sourceUserId: "unknown")
                    self?.showToast("导入成功，新增 \(count) 条知识", type: .success)
                    self?.tableView.reloadData()
                })
                present(alert, animated: true)
            } else {
                showToast("无法识别的文件格式", type: .error)
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateForFile(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
    }
}

// MARK: - UITableViewDataSource

extension KBSyncViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        // 0: 用户信息卡片
        // 1: 操作按钮
        // 2: 同步历史
        // 3: 底部说明
        return 4
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1  // 用户信息卡片
        case 1: return 2  // 导出 + 导入
        case 2: return max(syncHistory.count, 1)  // 同步历史
        case 3: return 1  // 底部说明
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserInfoCell", for: indexPath) as! KBSyncUserInfoCell
            let user = UserManager.shared.currentUser
            let stats = KBLiteManager.shared.stats
            cell.configure(nickname: user?.nickname ?? "未登录", avatarName: user?.avatarName, stats: stats)
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! KBSyncActionCell
            if indexPath.row == 0 {
                cell.configure(title: "导出我的知识库", icon: "square.and.arrow.up", color: .warmAccent)
            } else {
                cell.configure(title: "导入家人的知识库", icon: "square.and.arrow.down", color: .warmPrimary)
            }
            return cell

        case 2:
            if syncHistory.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SyncCell", for: indexPath)
                cell.textLabel?.text = "暂无同步记录"
                cell.textLabel?.textColor = .warmSubtitle
                cell.textLabel?.textAlignment = .center
                cell.selectionStyle = .none
                cell.backgroundColor = .warmSurface
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! KBSyncHistoryCell
                let record = syncHistory[indexPath.row]
                cell.configure(record: record, dateFormatter: formatDate)
                return cell
            }

        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FooterCell", for: indexPath) as! KBSyncFooterCell
            cell.configure(text: "与家人各自跟寻梦环游聊天，然后互相同步知识库，家族记忆会越来越完整")
            return cell

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return nil
        case 1: return "操作"
        case 2: return "最近同步记录"
        case 3: return nil
        default: return nil
        }
    }
}

// MARK: - UITableViewDelegate

extension KBSyncViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                exportKnowledgeBase()
            } else {
                importKnowledgeBase()
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 100
        case 1: return 52
        case 3: return 80
        default: return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 100
        case 1: return 52
        case 3: return 80
        default: return 50
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension KBSyncViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else {
            showToast("无法访问文件", type: .error)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                showToast("文件编码错误", type: .error)
                return
            }
            processImportJSON(jsonString)
        } catch {
            print("[KBMultiUser] 读取文件失败: \(error.localizedDescription)")
            showToast("读取文件失败", type: .error)
        }
    }
}

// MARK: - KBSyncUserInfoCell

/// 当前用户信息卡片
final class KBSyncUserInfoCell: UITableViewCell {

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .warmPrimary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let nicknameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .warmPrimary
        return l
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .warmSubtitle
        l.numberOfLines = 0
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .warmSurface

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nicknameLabel)
        contentView.addSubview(statsLabel)

        [avatarImageView, nicknameLabel, statsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 50),
            avatarImageView.heightAnchor.constraint(equalToConstant: 50),

            nicknameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 14),
            nicknameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nicknameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),

            statsLabel.leadingAnchor.constraint(equalTo: nicknameLabel.leadingAnchor),
            statsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statsLabel.topAnchor.constraint(equalTo: nicknameLabel.bottomAnchor, constant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(nickname: String, avatarName: String?, stats: String) {
        nicknameLabel.text = nickname
        statsLabel.text = "我的知识库：\(stats)"
        let symbolName = avatarName ?? "person.circle.fill"
        avatarImageView.image = UIImage(systemName: symbolName)?.withRenderingMode(.alwaysTemplate)
    }
}

// MARK: - KBSyncActionCell

/// 操作按钮 cell
final class KBSyncActionCell: UITableViewCell {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .warmSurface
        accessoryType = .disclosureIndicator

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)

        [iconView, titleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, icon: String, color: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = color
        iconView.image = UIImage(systemName: icon)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = color
    }
}

// MARK: - KBSyncHistoryCell

/// 同步历史记录 cell
final class KBSyncHistoryCell: UITableViewCell {

    private let sourceLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .warmPrimary
        return l
    }()

    private let detailLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .warmSubtitle
        return l
    }()

    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .warmAccent
        l.textAlignment = .right
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .warmSurface

        contentView.addSubview(sourceLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(countLabel)

        [sourceLabel, detailLabel, countLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            sourceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sourceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            sourceLabel.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -8),

            detailLabel.leadingAnchor.constraint(equalTo: sourceLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 4),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(record: KBSyncRecord, dateFormatter: (Date) -> String) {
        sourceLabel.text = "来自：\(record.sourceNickname)"
        detailLabel.text = dateFormatter(record.syncDate)
        countLabel.text = "+\(record.addedCount) 条"
    }
}

// MARK: - KBSyncFooterCell

/// 底部说明 cell
final class KBSyncFooterCell: UITableViewCell {

    private let noteLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .warmSubtitle
        l.numberOfLines = 0
        l.textAlignment = .center
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(noteLabel)
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            noteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            noteLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        noteLabel.text = text
    }
}
