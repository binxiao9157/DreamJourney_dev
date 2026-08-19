import UIKit

struct OwnerPublicationDraftEditorItem: Equatable {
    let memoryVersionID: String
    let memoryKindTitle: String
    let sensitivityTitle: String
    var publicTitle: String
    var publicBody: String

    init(memory: OwnerTruthFormalMemoryListItem) {
        let summary = memory.currentVersion.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        memoryVersionID = memory.currentVersion.id.rawValue.uuidString.lowercased()
        memoryKindTitle = memory.memoryKind.publicationTitle
        sensitivityTitle = memory.sensitivity.publicationTitle
        publicTitle = String(summary.prefix(36))
        publicBody = summary
    }

    init(
        memoryVersionID: String,
        memoryKindTitle: String,
        sensitivityTitle: String,
        publicTitle: String,
        publicBody: String
    ) {
        self.memoryVersionID = memoryVersionID
        self.memoryKindTitle = memoryKindTitle
        self.sensitivityTitle = sensitivityTitle
        self.publicTitle = publicTitle
        self.publicBody = publicBody
    }
}

struct OwnerPublicationDraftEditorState: Equatable {
    private(set) var items: [OwnerPublicationDraftEditorItem]

    init(items: [OwnerPublicationDraftEditorItem]) throws {
        guard !items.isEmpty,
              items.count <= PublicationDraftCreateCommand.maximumItemCount,
              Set(items.map(\.memoryVersionID)).count == items.count else {
            throw PublicationDraftAccessError.invalidInput
        }
        self.items = items
    }

    mutating func move(from source: Int, to destination: Int) {
        guard items.indices.contains(source),
              destination >= 0,
              destination <= items.count,
              source != destination else { return }
        let item = items.remove(at: source)
        items.insert(item, at: min(destination, items.count))
    }

    mutating func update(_ item: OwnerPublicationDraftEditorItem, at index: Int) {
        guard items.indices.contains(index), item.memoryVersionID == items[index].memoryVersionID else {
            return
        }
        items[index] = item
    }

    func makeCommand() throws -> PublicationDraftCreateCommand {
        try PublicationDraftCreateCommand(items: items.map { item in
            try PublicationDraftItemInput(
                memoryVersionID: item.memoryVersionID,
                publicTitle: item.publicTitle,
                publicBody: item.publicBody
            )
        })
    }
}

final class OwnerPublicationDraftComposerViewController: UIViewController {
    private let accountLease: AccountLease
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let useCase: PublicationDraftUseCase
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private lazy var previewButton = UIBarButtonItem(
        title: "预览",
        style: .done,
        target: self,
        action: #selector(previewTapped)
    )

    private var editorState: OwnerPublicationDraftEditorState
    private var isSubmitting = false
    private var requestGeneration: UInt64 = 0
    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    private var didTriggerPreviewForUIQA = false
    #endif
    var onPublicationConfirmed: ((PublicationDraftConfirmReceipt) -> Void)?

    init(
        accountLease: AccountLease,
        memories: [OwnerTruthFormalMemoryListItem],
        client: PublicationDraftWriterClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) throws {
        self.accountLease = accountLease
        self.accountLeaseRuntime = accountLeaseRuntime
        editorState = try OwnerPublicationDraftEditorState(
            items: memories.map(OwnerPublicationDraftEditorItem.init(memory:))
        )
        useCase = PublicationDraftUseCase(
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            isEnabled: { PublicationManagementM2AccessGate.isPublicationRouteAllowed }
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑公开副本"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = previewButton
        previewButton.tintColor = DJDesignTokens.Color.accentDeep
        previewButton.accessibilityIdentifier = "owner-publication-preview"
        configureTable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains(
            OwnerTruthFormalMemoryUIQASmoke.holdAtPublicationComposerArgument
        ) {
            OwnerTruthFormalMemoryUIQASmoke.finishPublicationComposer()
        } else if ProcessInfo.processInfo.arguments.contains(
            OwnerTruthFormalMemoryUIQASmoke.holdAtPublicationPreviewArgument
        ), !didTriggerPreviewForUIQA {
            didTriggerPreviewForUIQA = true
            previewTapped()
        }
        #endif
    }

    private func configureTable() {
        tableView.backgroundColor = DJDesignTokens.Color.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.dragInteractionEnabled = false
        tableView.allowsSelectionDuringEditing = true
        tableView.setEditing(true, animated: false)
        tableView.accessibilityIdentifier = "owner-publication-draft-editor"

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.textColor = DJDesignTokens.Color.danger
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.accessibilityIdentifier = "owner-publication-draft-error"

        view.addSubview(tableView)
        view.addSubview(statusLabel)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    @objc private func previewTapped() {
        guard !isSubmitting,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            failClosedForAccountChange()
            return
        }
        let command: PublicationDraftCreateCommand
        do {
            command = try editorState.makeCommand()
        } catch {
            showError(error.localizedDescription)
            return
        }
        view.endEditing(true)
        requestGeneration &+= 1
        let generation = requestGeneration
        isSubmitting = true
        previewButton.isEnabled = false
        previewButton.title = "整理中"
        statusLabel.isHidden = true
        useCase.create(command: command, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                self.isSubmitting = false
                self.previewButton.isEnabled = true
                self.previewButton.title = "预览"
                switch result {
                case .success(let draft):
                    let preview = OwnerPublicationDraftPreviewViewController(
                        accountLease: self.accountLease,
                        draft: draft,
                        useCase: self.useCase,
                        accountLeaseRuntime: self.accountLeaseRuntime
                    )
                    preview.onPublicationConfirmed = self.onPublicationConfirmed
                    self.navigationController?.pushViewController(preview, animated: true)
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        isSubmitting = false
        tableView.isUserInteractionEnabled = false
        previewButton.isEnabled = false
        showError("账号已变化，本次公开副本不会提交。请返回后重新进入。")
    }
}

extension OwnerPublicationDraftComposerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        editorState.items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "公开内容与顺序"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "拖动调整展示顺序。访客只会看到这里确认的标题和正文，不会看到原始资料、私人标识或历史版本。"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = editorState.items[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DJDesignTokens.Color.surface
        cell.textLabel?.text = item.publicTitle
        cell.textLabel?.font = DJDesignTokens.Font.body(16)
        cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
        cell.detailTextLabel?.text = "\(item.memoryKindTitle) · \(item.sensitivityTitle) · \(item.publicBody)"
        cell.detailTextLabel?.font = DJDesignTokens.Font.body(12)
        cell.detailTextLabel?.textColor = DJDesignTokens.Color.textTertiary
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "owner-publication-draft-item"
        cell.accessibilityLabel = "第 \(indexPath.row + 1) 项，\(item.publicTitle)，\(item.sensitivityTitle)"
        return cell
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        editorState.move(from: sourceIndexPath.row, to: destinationIndexPath.row)
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let editor = OwnerPublicationDraftItemEditorViewController(item: editorState.items[indexPath.row])
        editor.onSave = { [weak self] updated in
            self?.editorState.update(updated, at: indexPath.row)
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        navigationController?.pushViewController(editor, animated: true)
    }
}

private final class OwnerPublicationDraftItemEditorViewController: UIViewController, UITextViewDelegate {
    private var item: OwnerPublicationDraftEditorItem
    private let titleField = UITextField()
    private let bodyView = UITextView()
    private let errorLabel = UILabel()
    var onSave: ((OwnerPublicationDraftEditorItem) -> Void)?

    init(item: OwnerPublicationDraftEditorItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑公开内容"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "owner-publication-item-save"
        configureContent()
    }

    private func configureContent() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(label("公开标题", font: DJDesignTokens.Font.label(13)))
        titleField.text = item.publicTitle
        titleField.placeholder = "公开标题"
        titleField.borderStyle = .roundedRect
        titleField.clearButtonMode = .whileEditing
        titleField.accessibilityIdentifier = "owner-publication-item-title"
        stack.addArrangedSubview(titleField)

        stack.addArrangedSubview(label("公开正文", font: DJDesignTokens.Font.label(13)))
        bodyView.text = item.publicBody
        bodyView.font = DJDesignTokens.Font.body(16)
        bodyView.textColor = DJDesignTokens.Color.textPrimary
        bodyView.backgroundColor = DJDesignTokens.Color.surface
        bodyView.layer.cornerRadius = DJDesignTokens.Radius.small
        bodyView.layer.borderWidth = 1
        bodyView.layer.borderColor = DJDesignTokens.Color.divider.cgColor
        bodyView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        bodyView.accessibilityIdentifier = "owner-publication-item-body"
        stack.addArrangedSubview(bodyView)
        bodyView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let scope = label(
            "\(item.memoryKindTitle) · \(item.sensitivityTitle)",
            font: DJDesignTokens.Font.body(13)
        )
        scope.textColor = DJDesignTokens.Color.textTertiary
        stack.addArrangedSubview(scope)

        errorLabel.font = DJDesignTokens.Font.body(13)
        errorLabel.textColor = DJDesignTokens.Color.danger
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.accessibilityIdentifier = "owner-publication-item-error"
        stack.addArrangedSubview(errorLabel)

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
        ])
    }

    @objc private func saveTapped() {
        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = bodyView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120, !body.isEmpty, body.count <= 12_000 else {
            errorLabel.text = "公开标题和正文不能为空；标题最多 120 字。"
            errorLabel.isHidden = false
            return
        }
        item.publicTitle = title
        item.publicBody = body
        onSave?(item)
        navigationController?.popViewController(animated: true)
    }

    private func label(_ text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = DJDesignTokens.Color.textPrimary
        return label
    }
}

private final class OwnerPublicationDraftPreviewViewController: UIViewController {
    private let accountLease: AccountLease
    private let draft: PublicationDraftReceipt
    private let useCase: PublicationDraftUseCase
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let confirmButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var isSubmitting = false
    private var requestGeneration: UInt64 = 0
    var onPublicationConfirmed: ((PublicationDraftConfirmReceipt) -> Void)?

    init(
        accountLease: AccountLease,
        draft: PublicationDraftReceipt,
        useCase: PublicationDraftUseCase,
        accountLeaseRuntime: AccountLeaseRuntimePort
    ) {
        self.accountLease = accountLease
        self.draft = draft
        self.useCase = useCase
        self.accountLeaseRuntime = accountLeaseRuntime
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "确认公开内容"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = DJDesignTokens.Color.textPrimary
        navigationItem.leftBarButtonItem?.accessibilityLabel = "返回编辑公开副本"
        configureContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains(
            OwnerTruthFormalMemoryUIQASmoke.holdAtPublicationPreviewArgument
        ) {
            OwnerTruthFormalMemoryUIQASmoke.finishPublicationPreview()
        }
        #endif
    }

    private func configureContent() {
        tableView.backgroundColor = DJDesignTokens.Color.background
        tableView.dataSource = self
        tableView.accessibilityIdentifier = "owner-publication-draft-preview"

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = draft.thirdPartyReviewRequired ? "需要先完成隐私确认" : "确认发布"
        buttonConfiguration.baseBackgroundColor = DJDesignTokens.Color.accent
        buttonConfiguration.baseForegroundColor = .white
        buttonConfiguration.cornerStyle = .medium
        confirmButton.configuration = buttonConfiguration
        confirmButton.isEnabled = !draft.thirdPartyReviewRequired
        confirmButton.accessibilityIdentifier = "owner-publication-confirm"
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.textColor = draft.thirdPartyReviewRequired
            ? DJDesignTokens.Color.danger
            : DJDesignTokens.Color.textTertiary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = draft.thirdPartyReviewRequired
            ? "所选内容包含需要再次核对的第三方信息，本次不会发布。"
            : "发布会生成不可变版本；后续修改将创建新版本。"
        statusLabel.accessibilityIdentifier = "owner-publication-confirm-status"

        let actionStack = UIStackView(arrangedSubviews: [statusLabel, confirmButton])
        actionStack.axis = .vertical
        actionStack.spacing = 10
        view.addSubview(tableView)
        view.addSubview(actionStack)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: actionStack.topAnchor, constant: -8),
            actionStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            actionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            actionStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            confirmButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    @objc private func confirmTapped() {
        guard !isSubmitting else { return }
        let alert = UIAlertController(
            title: "确认发布",
            message: "请再次核对公开标题和正文。发布后当前版本不可直接修改或覆盖。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认发布", style: .default) { [weak self] _ in
            self?.submitConfirmation()
        })
        present(alert, animated: true)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func submitConfirmation() {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            failClosedForAccountChange()
            return
        }
        let command: PublicationDraftConfirmCommand
        do {
            command = try PublicationDraftConfirmCommand(
                expectedDraftRevision: draft.expectedDraftRevision,
                expectedDraftSnapshotHash: draft.expectedDraftSnapshotHash,
                secondConfirmation: true
            )
        } catch {
            renderFailure(error.localizedDescription)
            return
        }
        requestGeneration &+= 1
        let generation = requestGeneration
        isSubmitting = true
        confirmButton.isEnabled = false
        confirmButton.configuration?.title = "正在发布"
        useCase.confirm(draft: draft, command: command, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                self.isSubmitting = false
                switch result {
                case .success(let receipt):
                    self.statusLabel.textColor = DJDesignTokens.Color.accentDeep
                    self.statusLabel.text = "已生成第 \(receipt.publicationVersion) 个公开版本。"
                    self.onPublicationConfirmed?(receipt)
                case .failure(let error):
                    self.confirmButton.isEnabled = true
                    self.confirmButton.configuration?.title = "重新确认发布"
                    self.renderFailure(error.localizedDescription)
                }
            }
        }
    }

    private func renderFailure(_ message: String) {
        statusLabel.textColor = DJDesignTokens.Color.danger
        statusLabel.text = message
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        isSubmitting = false
        confirmButton.isEnabled = false
        renderFailure("账号已变化，本次发布已停止。请返回后重新进入。")
    }
}

extension OwnerPublicationDraftPreviewViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? draft.items.count : 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "访客将看到" : "公开说明"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DJDesignTokens.Color.surface
        cell.selectionStyle = .none
        if indexPath.section == 0 {
            let item = draft.items[indexPath.row]
            cell.textLabel?.text = item.previewTitle
            cell.textLabel?.font = DJDesignTokens.Font.title(16)
            cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
            cell.detailTextLabel?.text = item.previewBody
            cell.detailTextLabel?.font = DJDesignTokens.Font.body(14)
            cell.detailTextLabel?.textColor = DJDesignTokens.Color.textSecondary
            cell.detailTextLabel?.numberOfLines = 0
            cell.accessibilityIdentifier = "owner-publication-preview-item"
        } else {
            let values = [
                ("隐私范围", "只公开以上副本，不公开原始资料、私人标识或历史版本。"),
                ("内容来源", draft.aiDisclosureRequired ? "公开页面会说明内容由 AI 辅助整理。" : "公开页面不会增加未确认事实。"),
            ]
            cell.textLabel?.text = values[indexPath.row].0
            cell.textLabel?.font = DJDesignTokens.Font.label(13)
            cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
            cell.detailTextLabel?.text = values[indexPath.row].1
            cell.detailTextLabel?.font = DJDesignTokens.Font.body(13)
            cell.detailTextLabel?.textColor = DJDesignTokens.Color.textSecondary
            cell.detailTextLabel?.numberOfLines = 0
            cell.accessibilityIdentifier = "owner-publication-preview-disclosure"
        }
        return cell
    }
}

private extension OwnerTruthMemoryKind {
    var publicationTitle: String {
        switch self {
        case .experience: return "经历"
        case .knowledge: return "知识"
        case .emotion: return "感受"
        }
    }
}

private extension OwnerTruthSensitivityLevel {
    var publicationTitle: String {
        switch self {
        case .standard: return "普通内容"
        case .sensitive: return "敏感内容"
        case .restricted: return "受限内容"
        }
    }
}
