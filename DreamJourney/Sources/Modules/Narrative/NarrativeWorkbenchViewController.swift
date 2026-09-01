import UIKit

final class NarrativeWorkbenchViewController: NarrativeScreenViewController {
    private let project: NarrativeProject
    private weak var coordinator: NarrativeProjectCoordinator?

    init(project: NarrativeProject, coordinator: NarrativeProjectCoordinator) {
        self.project = project
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = project.title
        addHeading(project.title, subtitle: "章节只引用当前写作快照；新正式记忆需要由你决定是否升级写作版本。")
        if let constitution = currentConstitution() {
            let button = makeButton("查看与调整写作约定", action: #selector(constitutionTapped(_:)), emphasized: false)
            button.accessibilityIdentifier = constitution.artifactVersionId
            stackView.addArrangedSubview(button)
        }
        if project.state == .updateAvailable {
            let update = UILabel()
            update.text = "正式记忆已有更新。现有定稿不会被覆盖，你可以确认后创建新的写作快照。"
            update.numberOfLines = 0
            update.textColor = .systemOrange
            stackView.addArrangedSubview(update)
            stackView.addArrangedSubview(makeButton("将新记忆纳入后续写作", action: #selector(adoptMemoryUpdateTapped), emphasized: false))
            stackView.addArrangedSubview(makeButton("暂不纳入这批新记忆", action: #selector(ignoreMemoryUpdateTapped), emphasized: false))
        }
        let chapters = currentChapters()
        let writtenKeys = Set(chapters.map(\.artifactKey))
        let pendingOutlineNodes = outlineNodes().filter { !writtenKeys.contains($0.key) }
        if chapters.isEmpty {
            let label = UILabel()
            label.text = "还没有章节。可以从第一章开始。"
            label.textColor = .secondaryLabel
            stackView.addArrangedSubview(label)
        } else {
            chapters.forEach(addChapter)
        }
        if let next = pendingOutlineNodes.first {
            stackView.addArrangedSubview(makeButton("写下一章：\(next.title)", action: #selector(generateChapterTapped)))
        } else {
            stackView.addArrangedSubview(makeButton("补充一个新章节", action: #selector(generateChapterTapped)))
        }
        if chapters.contains(where: { $0.state == .final || $0.state == .confirmed }) {
            stackView.addArrangedSubview(makeButton("翻开阅读", action: #selector(readerTapped), emphasized: false))
            stackView.addArrangedSubview(makeButton("导出当前书稿", action: #selector(exportTapped), emphasized: false))
        }
        let management = UILabel()
        management.text = "项目管理"
        management.font = .preferredFont(forTextStyle: .headline)
        stackView.addArrangedSubview(management)
        stackView.addArrangedSubview(makeButton("暂停写作", action: #selector(pauseTapped), emphasized: false))
        stackView.addArrangedSubview(makeButton("归档这本书", action: #selector(archiveTapped), emphasized: false))
        stackView.addArrangedSubview(makeButton("删除写作项目", action: #selector(deleteTapped), emphasized: false))
    }

    private func currentChapters() -> [NarrativeArtifact] {
        let chapters = project.artifacts?.filter {
            $0.artifactType == .chapter && $0.state != .stale && $0.state != .superseded
        } ?? []
        var current: [String: NarrativeArtifact] = [:]
        chapters.forEach { item in
            if current[item.artifactKey].map({ $0.versionNumber < item.versionNumber }) ?? true {
                current[item.artifactKey] = item
            }
        }
        return current.values.sorted { order($0) < order($1) }
    }

    private func addChapter(_ artifact: NarrativeArtifact) {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        let title = UILabel()
        title.text = artifact.displayTitle
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        container.addArrangedSubview(title)
        let body = UILabel()
        body.text = artifact.contentText ?? "章节内容已生成"
        body.numberOfLines = 5
        body.font = .systemFont(ofSize: 16)
        body.textColor = .secondaryLabel
        container.addArrangedSubview(body)
        if artifact.state == .readyForReview || artifact.state == .draft {
            let finalize = makeButton("确认定稿", action: #selector(finalizeTapped(_:)), emphasized: false)
            finalize.accessibilityIdentifier = artifact.artifactVersionId
            container.addArrangedSubview(finalize)
        }
        let edit = makeButton("编辑本章", action: #selector(editTapped(_:)), emphasized: false)
        edit.accessibilityIdentifier = artifact.artifactVersionId
        container.addArrangedSubview(edit)
        let history = makeButton("版本记录与对比", action: #selector(historyTapped(_:)), emphasized: false)
        history.accessibilityIdentifier = artifact.artifactVersionId
        container.addArrangedSubview(history)
        stackView.addArrangedSubview(container)
    }

    @objc private func generateChapterTapped() {
        let writtenKeys = Set(currentChapters().map(\.artifactKey))
        if let next = outlineNodes().first(where: { !writtenKeys.contains($0.key) }) {
            coordinator?.send(.generateChapter, payload: [
                "chapterKey": .string(next.key),
                "title": .string(next.title),
                "order": .integer(next.order),
            ])
            return
        }
        let alert = UIAlertController(title: "写下一章", message: nil, preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "章节标题" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "开始写作", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let title = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return }
            let index = self.currentChapters().count + 1
            self.coordinator?.send(.generateChapter, payload: [
                "chapterKey": .string("chapter-\(index)"),
                "title": .string(title),
                "order": .integer(index),
            ])
        })
        present(alert, animated: true)
    }

    @objc private func finalizeTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        coordinator?.send(.finalizeChapter, payload: ["artifactVersionId": .string(id)])
    }
    @objc private func readerTapped() { coordinator?.openReader() }
    @objc private func adoptMemoryUpdateTapped() { coordinator?.send(.adoptMemoryUpdate) }
    @objc private func ignoreMemoryUpdateTapped() { coordinator?.send(.ignoreMemoryUpdate) }
    @objc private func exportTapped() { coordinator?.exportBook(from: self) }
    @objc private func pauseTapped() {
        confirm(
            title: "暂停写作？",
            message: "当前检查点和全部版本都会保留，之后可以继续。",
            actionTitle: "暂停"
        ) { [weak self] in self?.coordinator?.send(.pauseProject) }
    }
    @objc private func archiveTapped() {
        confirm(
            title: "归档这本书？",
            message: "归档后不再作为当前写作项目，但历史书稿仍会保留。",
            actionTitle: "归档"
        ) { [weak self] in self?.coordinator?.send(.archiveProject) }
    }
    @objc private func deleteTapped() {
        confirm(
            title: "删除写作项目？",
            message: "将删除本项目及其派生书稿，但不会删除你的正式记忆。",
            actionTitle: "删除",
            destructive: true
        ) { [weak self] in self?.coordinator?.deleteProject() }
    }

    private func confirm(
        title: String,
        message: String,
        actionTitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(
            title: actionTitle,
            style: destructive ? .destructive : .default
        ) { _ in action() })
        present(alert, animated: true)
    }

    @objc private func constitutionTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let artifact = currentConstitution(),
              artifact.artifactVersionId == id else { return }
        coordinator?.edit(artifact)
    }

    @objc private func editTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let artifact = currentChapters().first(where: { $0.artifactVersionId == id }) else { return }
        coordinator?.edit(artifact)
    }

    @objc private func historyTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let artifact = currentChapters().first(where: { $0.artifactVersionId == id }) else { return }
        coordinator?.showHistory(for: artifact)
    }

    private func order(_ artifact: NarrativeArtifact) -> Int {
        if case .integer(let value)? = artifact.payload["order"] { return value }
        return artifact.versionNumber
    }

    private func outlineNodes() -> [(key: String, title: String, order: Int)] {
        let outline = project.artifacts?
            .filter { $0.artifactType == .outline && $0.state != .stale && $0.state != .superseded }
            .max(by: { $0.versionNumber < $1.versionNumber })
        guard let outline,
              case .array(let values)? = outline.payload["nodes"] else { return [] }
        return values.compactMap { value in
            guard case .object(let object) = value,
                  case .string(let key)? = object["chapterKey"],
                  case .string(let title)? = object["title"] else { return nil }
            if case .boolean(true)? = object["hidden"] { return nil }
            let order: Int
            if case .integer(let value)? = object["order"] { order = value }
            else { order = Int.max }
            return (key, title, order)
        }.sorted { $0.order < $1.order }
    }

    private func currentConstitution() -> NarrativeArtifact? {
        project.artifacts?
            .filter {
                $0.artifactType == .writingConstitution
                    && $0.state != .stale
                    && $0.state != .superseded
            }
            .max(by: { $0.versionNumber < $1.versionNumber })
    }
}

final class NarrativeArtifactEditorViewController: NarrativeScreenViewController {
    private let artifact: NarrativeArtifact
    private weak var coordinator: NarrativeProjectCoordinator?
    private let titleField = UITextField()
    private let textView = UITextView()

    init(artifact: NarrativeArtifact, coordinator: NarrativeProjectCoordinator) {
        self.artifact = artifact
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑版本"
        addHeading(artifact.displayTitle, subtitle: "保存会创建新版本，当前版本和已定稿版本都不会被覆盖。")
        titleField.borderStyle = .roundedRect
        titleField.placeholder = "标题"
        titleField.text = artifact.displayTitle
        titleField.accessibilityLabel = "标题"
        stackView.addArrangedSubview(titleField)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        if let content = artifact.contentText {
            textView.text = content
        } else if artifact.artifactType == .writingConstitution,
                  case .array(let values)? = artifact.payload["rules"] {
            textView.text = values.compactMap {
                guard case .string(let value) = $0 else { return nil }
                return value
            }.joined(separator: "\n")
        } else {
            textView.text = ""
        }
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 6
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
        textView.accessibilityLabel = "正文"
        stackView.addArrangedSubview(textView)
        stackView.addArrangedSubview(makeButton("保存为新版本", action: #selector(saveTapped)))
    }

    @objc private func saveTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        coordinator?.send(.editArtifact, payload: [
            "artifactVersionId": .string(artifact.artifactVersionId),
            "title": .string(titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? artifact.displayTitle),
            "contentText": .string(text),
        ])
    }
}

final class NarrativeOutlineEditorViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private struct Node {
        var chapterKey: String
        var title: String
        var arrangementReason: String
        var materialGap: String
        var hidden: Bool
        var memoryVersionIds: [String]

        init?(value: NarrativeJSONValue) {
            guard case .object(let object) = value,
                  case .string(let chapterKey)? = object["chapterKey"],
                  case .string(let title)? = object["title"] else { return nil }
            self.chapterKey = chapterKey
            self.title = title
            if case .string(let value)? = object["arrangementReason"] { arrangementReason = value }
            else if case .string(let value)? = object["intent"] { arrangementReason = value }
            else { arrangementReason = "" }
            if case .string(let value)? = object["materialGap"] { materialGap = value }
            else { materialGap = "" }
            if case .boolean(let value)? = object["hidden"] { hidden = value }
            else { hidden = false }
            if case .array(let values)? = object["memoryVersionIds"] {
                memoryVersionIds = values.compactMap {
                    guard case .string(let value) = $0 else { return nil }
                    return value
                }
            } else {
                memoryVersionIds = []
            }
        }

        func payload(order: Int) -> NarrativeJSONValue {
            .object([
                "chapterKey": .string(chapterKey),
                "title": .string(title),
                "order": .integer(order),
                "hidden": .boolean(hidden),
                "arrangementReason": .string(arrangementReason),
                "materialGap": .string(materialGap),
                "memoryVersionIds": .array(memoryVersionIds.map(NarrativeJSONValue.string)),
            ])
        }
    }

    private let artifact: NarrativeArtifact
    private weak var coordinator: NarrativeProjectCoordinator?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var nodes: [Node] = []

    init(artifact: NarrativeArtifact, coordinator: NarrativeProjectCoordinator) {
        self.artifact = artifact
        self.coordinator = coordinator
        if case .array(let values)? = artifact.payload["nodes"] {
            nodes = values.compactMap(Node.init(value:))
        }
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑全书大纲"
        view.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.dragInteractionEnabled = true
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "保存新版本", style: .done, target: self, action: #selector(saveTapped)),
            editButtonItem,
        ]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { nodes.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let node = nodes[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = "\(indexPath.row + 1). \(node.title)"
        cell.textLabel?.textColor = node.hidden ? .secondaryLabel : .label
        let details = [node.arrangementReason, node.materialGap.isEmpty ? "" : "待补：\(node.materialGap)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        cell.detailTextLabel?.text = node.hidden ? "已隐藏 · \(details)" : details
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityHint = "可编辑标题；左滑可隐藏或与上一章合并"
        return cell
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = nodes.remove(at: sourceIndexPath.row)
        nodes.insert(item, at: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "章节标题", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in field.text = self?.nodes[indexPath.row].title }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return }
            self.nodes[indexPath.row].title = value
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        })
        present(alert, animated: true)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let hide = UIContextualAction(
            style: .normal,
            title: nodes[indexPath.row].hidden ? "恢复" : "隐藏"
        ) { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            self.nodes[indexPath.row].hidden.toggle()
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
            completion(true)
        }
        hide.backgroundColor = .systemOrange
        var actions = [hide]
        if indexPath.row > 0 {
            let merge = UIContextualAction(style: .destructive, title: "并入上一章") { [weak self] _, _, completion in
                guard let self else { completion(false); return }
                let removed = self.nodes.remove(at: indexPath.row)
                let target = indexPath.row - 1
                self.nodes[target].title += "与" + removed.title
                self.nodes[target].arrangementReason = [
                    self.nodes[target].arrangementReason,
                    removed.arrangementReason,
                ].filter { !$0.isEmpty }.joined(separator: "；")
                self.nodes[target].memoryVersionIds = Array(
                    Set(self.nodes[target].memoryVersionIds + removed.memoryVersionIds)
                ).sorted()
                self.tableView.reloadData()
                completion(true)
            }
            actions.append(merge)
        }
        return UISwipeActionsConfiguration(actions: actions)
    }

    @objc private func saveTapped() {
        guard !nodes.isEmpty, nodes.contains(where: { !$0.hidden }) else { return }
        coordinator?.send(.editArtifact, payload: [
            "artifactVersionId": .string(artifact.artifactVersionId),
            "nodes": .array(nodes.enumerated().map { $0.element.payload(order: $0.offset + 1) }),
            "editNote": .string("用户调整目录结构"),
        ])
    }
}

final class NarrativeVersionHistoryViewController: NarrativeScreenViewController {
    private let project: NarrativeProject?
    private let artifact: NarrativeArtifact
    private weak var coordinator: NarrativeProjectCoordinator?

    init(project: NarrativeProject?, artifact: NarrativeArtifact, coordinator: NarrativeProjectCoordinator) {
        self.project = project
        self.artifact = artifact
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版本记录"
        addHeading(artifact.displayTitle, subtitle: "历史版本只读；恢复会创建一个新版本。")
        loadVersions()
    }

    private func loadVersions() {
        coordinator?.loadArtifacts(type: artifact.artifactType) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let values):
                let versions = values
                    .filter { $0.artifactKey == self.artifact.artifactKey }
                    .sorted { $0.versionNumber > $1.versionNumber }
                versions.forEach(self.addVersion)
            case .failure(let error):
                let label = UILabel()
                label.text = error.localizedDescription
                label.numberOfLines = 0
                self.stackView.addArrangedSubview(label)
            }
        }
    }

    private func addVersion(_ version: NarrativeArtifact) {
        let button = makeButton(
            "版本 \(version.versionNumber) · \(display(version.state))",
            action: #selector(versionTapped(_:)),
            emphasized: version.artifactVersionId == artifact.artifactVersionId
        )
        button.accessibilityIdentifier = version.artifactVersionId
        stackView.addArrangedSubview(button)
    }

    @objc private func versionTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        coordinator?.loadArtifacts(type: artifact.artifactType) { [weak self] result in
            guard let self, case .success(let values) = result,
                  let selected = values.first(where: { $0.artifactVersionId == id }) else { return }
            let controller = NarrativeVersionCompareViewController(
                current: self.artifact,
                selected: selected,
                coordinator: self.coordinator
            )
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    private func display(_ state: NarrativeArtifactState) -> String {
        switch state {
        case .draft: return "草稿"
        case .readyForReview: return "待审核"
        case .confirmed: return "已确认"
        case .final: return "已定稿"
        case .stale: return "来源已变化"
        case .superseded: return "历史版本"
        }
    }
}

final class NarrativeVersionCompareViewController: NarrativeScreenViewController {
    private let current: NarrativeArtifact
    private let selected: NarrativeArtifact
    private weak var coordinator: NarrativeProjectCoordinator?

    init(current: NarrativeArtifact, selected: NarrativeArtifact, coordinator: NarrativeProjectCoordinator?) {
        self.current = current
        self.selected = selected
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版本对比"
        addHeading("版本 \(selected.versionNumber)", subtitle: "与当前版本 \(current.versionNumber) 对照")
        addText("所选版本", selected.contentText ?? "")
        addText("当前版本", current.contentText ?? "")
        if selected.artifactVersionId != current.artifactVersionId && selected.state != .stale {
            stackView.addArrangedSubview(makeButton("以此版本恢复", action: #selector(restoreTapped), emphasized: false))
        }
    }

    private func addText(_ title: String, _ text: String) {
        let heading = UILabel()
        heading.text = title
        heading.font = .preferredFont(forTextStyle: .headline)
        stackView.addArrangedSubview(heading)
        let body = UILabel()
        body.text = text
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        stackView.addArrangedSubview(body)
    }

    @objc private func restoreTapped() {
        coordinator?.send(.restoreArtifactVersion, payload: [
            "artifactVersionId": .string(selected.artifactVersionId),
        ])
    }
}
