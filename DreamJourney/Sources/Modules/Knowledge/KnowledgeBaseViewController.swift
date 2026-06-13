import UIKit

// MARK: - KnowledgeBaseViewController

/// 知识库浏览首页 — 展示所有 AI 提取到的结构化知识
/// 五个 Tab：人物 · 地点 · 事件 · 事实 · 图谱
final class KnowledgeBaseViewController: UIViewController {

    // MARK: - Segmented Control

    private lazy var segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["人物", "地点", "事件", "事实", "图谱"])
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return sc
    }()

    // MARK: - Table View

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.separatorStyle = .singleLine
        tv.backgroundColor = .warmBackground
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "KBDetailCell")
        tv.register(KBStatsCell.self, forCellReuseIdentifier: "KBStatsCell")
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    // MARK: - Data

    private enum Tab: Int, CaseIterable {
        case people, places, events, facts
    }

    private var currentTab: Tab { Tab(rawValue: segmentedControl.selectedSegmentIndex) ?? .people }

    /// 数据源（从 KBLiteManager 获取）
    private var people: [KBPerson] {
        KBLiteManager.shared.graph.people.filter {
            !KBLiteManager.isGenericKinshipDisplayName($0.name)
        }
    }
    private var places: [KBPlace] { KBLiteManager.shared.graph.places }
    private var events: [KBEvent] { KBLiteManager.shared.graph.events }
    private var facts: [KBFact] { KBLiteManager.shared.graph.facts }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "知识库"
        view.backgroundColor = .warmBackground
        setupNavigationBar()
        setupLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(onKBUpdated), name: .kbLiteDidUpdate, object: nil)
    }

    @objc private func onKBUpdated() {
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )
    }

    private func setupLayout() {
        view.addSubview(segmentedControl)
        view.addSubview(tableView)

        [segmentedControl, tableView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        if segmentedControl.selectedSegmentIndex == 4 {
            // 图谱 Tab — push 图谱视图
            let graphVC = KBGraphViewController()
            navigationController?.pushViewController(graphVC, animated: true)
            // 切回上一个 tab，以便返回时不停留在"图谱"
            segmentedControl.selectedSegmentIndex = 0
            return
        }
        tableView.reloadData()
    }

    @objc private func shareTapped() {
        let alert = UIAlertController(title: "知识库操作", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "生成家谱 PDF", style: .default) { [weak self] _ in
            self?.generateFamilyPDF()
        })

        alert.addAction(UIAlertAction(title: "导出备份", style: .default) { [weak self] _ in
            self?.exportKnowledgeBase()
        })

        alert.addAction(UIAlertAction(title: "家族同步", style: .default) { [weak self] _ in
            let syncVC = KBSyncViewController()
            self?.navigationController?.pushViewController(syncVC, animated: true)
        })

        alert.addAction(UIAlertAction(title: "重置知识库", style: .destructive) { [weak self] _ in
            self?.confirmReset()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func exportKnowledgeBase() {
        guard let json = Stage1MemoryFacade.shared.exportKnowledgeJSON() else {
            showToast("导出失败", type: .error)
            return
        }
        let activityVC = UIActivityViewController(activityItems: [json], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }

    private func confirmReset() {
        let alert = UIAlertController(
            title: "重置知识库？",
            message: "这将删除所有 AI 提取的人物、地点、事件和事实。此操作不可恢复。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { _ in
            KBLiteManager.shared.reset()
            self.tableView.reloadData()
            self.showToast("知识库已重置", type: .success)
        })
        present(alert, animated: true)
    }

    private func generateFamilyPDF() {
        let hud = UIActivityIndicatorView(style: .large)
        hud.center = view.center
        hud.startAnimating()
        view.addSubview(hud)

        KBLitePDFExporter.generateFamilyBook { [weak self] url in
            hud.removeFromSuperview()
            guard let self = self, let pdfURL = url else {
                self?.showToast("PDF 生成失败", type: .error)
                return
            }
            let previewVC = KBExportPreviewViewController(pdfURL: pdfURL)
            self.navigationController?.pushViewController(previewVC, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension KnowledgeBaseViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        // Section 0: 统计摘要
        // Section 1: 数据列表
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        switch currentTab {
        case .people:  return max(people.count, 1)
        case .places:  return max(places.count, 1)
        case .events:  return max(events.count, 1)
        case .facts:   return max(facts.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "KBStatsCell", for: indexPath) as! KBStatsCell
            cell.configure(
                peopleCount: people.count,
                placesCount: places.count,
                eventsCount: events.count,
                factsCount: facts.count,
                sessionCount: KBLiteManager.shared.graph.sessionCount,
                depositStatus: KBLiteDepositStatusBuilder.build(from: KBLiteManager.shared.graph)
            )
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "KBDetailCell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 15)

        switch currentTab {
        case .people:
            if people.isEmpty {
                cell.textLabel?.text = "暂无人物数据\n\n与寻梦环游多聊聊您认识的人，AI 会自动提取。"
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                let p = people[indexPath.row]
                let traits = p.traits.isEmpty ? "" : " [" + p.traits.joined(separator: " · ") + "]"
                cell.textLabel?.text = "\(p.name)\(traits)"
                cell.textLabel?.textColor = .label
                cell.detailTextLabel?.text = p.briefBio ?? p.relation ?? ""
                cell.accessoryType = .disclosureIndicator
            }

        case .places:
            if places.isEmpty {
                cell.textLabel?.text = "暂无地点数据\n\n聊天中提到的地点会自动记录。"
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                let p = places[indexPath.row]
                let cat = p.category.map { " [\($0)]" } ?? ""
                cell.textLabel?.text = "\(p.name)\(cat)"
                cell.textLabel?.textColor = .label
                cell.detailTextLabel?.text = p.description ?? ""
            }

        case .events:
            if events.isEmpty {
                cell.textLabel?.text = "暂无事件数据\n\n聊天中提到的往事会自动记录。"
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                let e = events[indexPath.row]
                let date = e.formattedDate.isEmpty ? "" : "\(e.formattedDate) · "
                cell.textLabel?.text = "\(date)\(e.title)"
                cell.textLabel?.textColor = .label
                cell.detailTextLabel?.text = e.description ?? ""
            }

        case .facts:
            if facts.isEmpty {
                cell.textLabel?.text = "暂无事实数据\n\nAI 会在聊天中自动提取关键事实。"
                cell.textLabel?.textColor = .secondaryLabel
            } else {
                let f = facts[indexPath.row]
                let confidenceMarker: String = {
                    switch f.confidence {
                    case "confirmed": return "已确认 · "
                    case "high": return "高可信 · "
                    case "medium": return "中可信 · "
                    case "low": return "低可信 · "
                    default: return ""
                    }
                }()
                cell.textLabel?.text = "\(confidenceMarker)\(f.statement)"
                cell.textLabel?.textColor = .label
                cell.detailTextLabel?.text = "置信度: \(f.confidence)"
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension KnowledgeBaseViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return nil }
        let count: Int = {
            switch currentTab {
            case .people: return people.count
            case .places: return places.count
            case .events: return events.count
            case .facts: return facts.count
            }
        }()
        let name: String = {
            switch currentTab {
            case .people: return "人物"
            case .places: return "地点"
            case .events: return "事件"
            case .facts: return "事实"
            }
        }()
        return "\(name)（\(count)）"
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 164 }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 164 }
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }

        switch currentTab {
        case .people:
            guard !people.isEmpty else { return }
            let detailVC = KBEntityDetailViewController(entity: .person(people[indexPath.row]))
            navigationController?.pushViewController(detailVC, animated: true)

        case .events:
            guard !events.isEmpty else { return }
            let detailVC = KBEntityDetailViewController(entity: .event(events[indexPath.row]))
            navigationController?.pushViewController(detailVC, animated: true)

        case .places, .facts:
            break // 暂不提供详情页
        }
    }
}

// MARK: - KBStatsCell

final class KBStatsCell: UITableViewCell {

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1.0)
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 0.3)
        contentView.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statsLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(
        peopleCount: Int,
        placesCount: Int,
        eventsCount: Int,
        factsCount: Int,
        sessionCount: Int,
        depositStatus: KBLiteDepositStatus
    ) {
        let updatedText = Self.updatedText(for: depositStatus.lastUpdated)
        statsLabel.text = """
        \(peopleCount) 人 · \(placesCount) 地 · \(eventsCount) 事 · \(factsCount) 实
        沉淀状态：\(depositStatus.totalEntityCount) 条 · 共 \(sessionCount) 次会话
        \(depositStatus.sourceSummary)
        \(depositStatus.privacySummary)
        最近更新：\(updatedText)
        """
    }

    private static func updatedText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - KBEntityDetailViewController

/// 实体详情页（人物 / 事件）
final class KBEntityDetailViewController: UIViewController {

    enum Entity {
        case person(KBPerson)
        case event(KBEvent)
    }

    private let entity: Entity

    init(entity: Entity) {
        self.entity = entity
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .systemFont(ofSize: 16)
        tv.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        tv.backgroundColor = .clear
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground

        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        switch entity {
        case .person(let p):
            title = p.name
            var text = "【姓名】\(p.name)\n"
            if !p.aliases.isEmpty { text += "【别名】\(p.aliases.joined(separator: "、"))\n" }
            if let rel = p.relation { text += "【关系】\(rel)\n" }
            if !p.traits.isEmpty { text += "【特征】\(p.traits.joined(separator: "、"))\n" }
            if let bio = p.briefBio { text += "\n\(bio)\n" }

            // 关联事实
            let relatedFacts = KBLiteManager.shared.graph.facts.filter { $0.relatedPersonIds.contains(p.id) }
            if !relatedFacts.isEmpty {
                text += "\n【相关事实】\n"
                for f in relatedFacts {
                    text += "· \(f.statement)\n"
                }
            }

            // 关联事件
            let relatedEvents = KBLiteManager.shared.graph.events.filter { $0.participantIds.contains(p.id) }
            if !relatedEvents.isEmpty {
                text += "\n【相关事件】\n"
                for e in relatedEvents {
                    text += "· \(e.formattedDate)\(e.title)\n"
                }
            }

            text += "\n来源：第 \(p.sourceSessionIds.map(String.init).joined(separator: "、")) 次会话"

            textView.text = text

        case .event(let e):
            title = e.title
            var text = "【标题】\(e.title)\n"
            if !e.formattedDate.isEmpty { text += "【时间】\(e.formattedDate)\n" }
            if let desc = e.description { text += "\n\(desc)\n" }

            // 关联人物
            let relatedPersons = KBLiteManager.shared.graph.people.filter {
                e.participantIds.contains($0.id) &&
                    !KBLiteManager.isGenericKinshipDisplayName($0.name)
            }
            if !relatedPersons.isEmpty {
                text += "\n【参与人物】\n"
                for p in relatedPersons { text += "· \(p.name)\n" }
            }

            text += "\n来源：第 \(e.sourceSessionIds.map(String.init).joined(separator: "、")) 次会话"
            textView.text = text
        }
    }
}
