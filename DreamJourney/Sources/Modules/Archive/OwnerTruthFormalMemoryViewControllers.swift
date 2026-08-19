import UIKit

final class OwnerTruthFormalMemoryListViewController: UIViewController {
    private let accountLease: AccountLease
    private let client: OwnerTruthFormalMemoryClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private lazy var filterButton = UIBarButtonItem(
        image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
        style: .plain,
        target: self,
        action: #selector(filterTapped)
    )
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var items: [OwnerTruthFormalMemoryListItem] = []
    private var nextCursor: String?
    private var selectedKind: OwnerTruthMemoryKind?
    private var selectedFacet: OwnerTruthFormalMemoryFacetFilter?
    private var requestGeneration: UInt64 = 0
    private var searchWorkItem: DispatchWorkItem?
    private var isLoading = false
    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var onPageRenderedForUIQA: ((OwnerTruthFormalMemoryListViewController) -> Void)?
    #endif

    init(
        accountLease: AccountLease,
        client: OwnerTruthFormalMemoryClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.accountLease = accountLease
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "正式记忆"
        view.backgroundColor = DJDesignTokens.Color.background
        configureNavigation()
        configureTable()
        load(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    private var vaultID: OwnerTruthVaultID? {
        OwnerTruthVaultID(accountLease.vaultId)
    }

    private func configureNavigation() {
        filterButton.accessibilityIdentifier = "owner-truth-formal-memory-filter"
        filterButton.accessibilityLabel = "筛选正式记忆"
        refreshButton.accessibilityIdentifier = "owner-truth-formal-memory-refresh"
        navigationItem.rightBarButtonItems = [refreshButton, filterButton]

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜索正式记忆"
        searchController.searchBar.accessibilityIdentifier = "owner-truth-formal-memory-search"
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureTable() {
        tableView.backgroundColor = DJDesignTokens.Color.background
        tableView.separatorStyle = .singleLine
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "owner-truth-formal-memory-list"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FormalMemoryCell")

        statusLabel.font = DJDesignTokens.Font.body(15)
        statusLabel.textColor = DJDesignTokens.Color.textTertiary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-formal-memory-status"

        view.addSubview(tableView)
        view.addSubview(statusLabel)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: DJDesignTokens.Spacing.page
            ),
            statusLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -DJDesignTokens.Spacing.page
            ),
        ])
    }

    @objc private func refreshTapped() {
        load(reset: true)
    }

    @objc private func filterTapped() {
        let sheet = UIAlertController(title: "筛选正式记忆", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "全部类型", style: selectedKind == nil ? .destructive : .default) { [weak self] _ in
            self?.selectedKind = nil
            self?.load(reset: true)
        })
        for kind in OwnerTruthMemoryKind.allCases {
            sheet.addAction(UIAlertAction(title: kind.formalMemoryTitle, style: kind == selectedKind ? .destructive : .default) { [weak self] _ in
                self?.selectedKind = kind
                self?.load(reset: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "按线索筛选", style: .default) { [weak self] _ in
            self?.chooseFacetKind()
        })
        if selectedFacet != nil {
            sheet.addAction(UIAlertAction(title: "清除线索筛选", style: .destructive) { [weak self] _ in
                self?.selectedFacet = nil
                self?.load(reset: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = filterButton
        }
        present(sheet, animated: true)
    }

    private func chooseFacetKind() {
        let choices: [(String, String)] = [
            ("people", "人物"), ("time", "时间"), ("places", "地点"),
            ("relationships", "关系"), ("emotions", "情绪"),
            ("values", "价值观"), ("personality", "性格"),
        ]
        let sheet = UIAlertController(title: "选择线索类型", message: nil, preferredStyle: .actionSheet)
        for choice in choices {
            sheet.addAction(UIAlertAction(title: choice.1, style: .default) { [weak self] _ in
                self?.askFacetValue(name: choice.0, title: choice.1)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = filterButton
        }
        present(sheet, animated: true)
    }

    private func askFacetValue(name: String, title: String) {
        let alert = UIAlertController(
            title: "筛选\(title)线索",
            message: "请输入已确认的线索名称。",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = title
            field.accessibilityIdentifier = "owner-truth-formal-memory-facet-input"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "筛选", style: .default) { [weak self, weak alert] _ in
            guard let rawValue = alert?.textFields?.first?.text,
                  let filter = try? OwnerTruthFormalMemoryFacetFilter(name: name, value: rawValue) else {
                return
            }
            self?.selectedFacet = filter
            self?.load(reset: true)
        })
        present(alert, animated: true)
    }

    private func load(reset: Bool) {
        guard !isLoading,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let vaultID else {
            failClosedForAccountChange()
            return
        }
        let cursor = reset ? nil : nextCursor
        guard reset || cursor != nil else { return }
        let query: OwnerTruthFormalMemoryQuery
        do {
            query = try OwnerTruthFormalMemoryQuery(
                kind: selectedKind,
                text: searchController.searchBar.text,
                facets: selectedFacet.map { [$0] } ?? [],
                cursor: cursor,
                limit: 20
            )
        } catch {
            statusLabel.text = error.localizedDescription
            statusLabel.isHidden = false
            return
        }
        if reset {
            requestGeneration &+= 1
            items = []
            nextCursor = nil
            tableView.reloadData()
        }
        let generation = requestGeneration
        isLoading = true
        refreshButton.isEnabled = false
        statusLabel.text = reset ? "正在读取正式记忆..." : "正在载入更多记忆..."
        statusLabel.isHidden = false
        client.fetchOwnerTruthFormalMemories(vaultID: vaultID, query: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                self.isLoading = false
                self.refreshButton.isEnabled = true
                switch result {
                case .success(let page):
                    let knownIDs = Set(self.items.map(\.id))
                    self.items.append(contentsOf: page.memories.filter { !knownIDs.contains($0.id) })
                    self.nextCursor = page.nextCursor
                    self.statusLabel.text = self.items.isEmpty
                        ? "还没有正式记忆。候选内容经你确认后会出现在这里。"
                        : self.activeFilterSummary
                    self.statusLabel.isHidden = !self.items.isEmpty && self.activeFilterSummary == nil
                    self.tableView.reloadData()
                    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
                    self.onPageRenderedForUIQA?(self)
                    #endif
                case .failure(let error):
                    self.statusLabel.text = "正式记忆读取失败。\n\(error.localizedDescription)"
                    self.statusLabel.isHidden = false
                }
            }
        }
    }

    private var activeFilterSummary: String? {
        let kind = selectedKind?.formalMemoryTitle
        let facet = selectedFacet.map { "\($0.value)线索" }
        let values = [kind, facet].compactMap { $0 }
        return values.isEmpty ? nil : "正在查看：\(values.joined(separator: " · "))"
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        isLoading = false
        items = []
        nextCursor = nil
        tableView.reloadData()
        statusLabel.text = "账号已变化，请返回后重新进入正式记忆。"
        statusLabel.isHidden = false
        filterButton.isEnabled = false
        refreshButton.isEnabled = false
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    func openFirstMemoryForUIQA() {
        guard !items.isEmpty else { return }
        tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
    }
    #endif
}

extension OwnerTruthFormalMemoryListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.load(reset: true) }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

extension OwnerTruthFormalMemoryListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count + (nextCursor == nil ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == items.count {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = isLoading ? "正在载入..." : "载入更多"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = DJDesignTokens.Color.accentDeep
            cell.accessibilityIdentifier = "owner-truth-formal-memory-load-more"
            return cell
        }
        let item = items[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DJDesignTokens.Color.surface
        cell.textLabel?.text = item.currentVersion.summary
        cell.textLabel?.font = DJDesignTokens.Font.body(16)
        cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = "\(item.memoryKind.formalMemoryTitle) · 第 \(item.currentVersion.versionNumber) 版 · \(item.currentVersion.createdAt.formalMemoryDateText)"
        cell.detailTextLabel?.font = DJDesignTokens.Font.label(12)
        cell.detailTextLabel?.textColor = DJDesignTokens.Color.textTertiary
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "owner-truth-formal-memory-row"
        cell.accessibilityLabel = "\(item.currentVersion.summary)，\(item.memoryKind.formalMemoryTitle)，第 \(item.currentVersion.versionNumber) 版"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == items.count {
            load(reset: false)
            return
        }
        let item = items[indexPath.row]
        let detail = OwnerTruthFormalMemoryDetailViewController(
            accountLease: accountLease,
            memoryID: item.id,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime
        )
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains(OwnerTruthFormalMemoryUIQASmoke.holdAtDetailArgument) {
            OwnerTruthFormalMemoryUIQASmoke.connectDetailHook(detail)
        }
        #endif
        detail.onRevisionCommitted = { [weak self] in self?.load(reset: true) }
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == items.count, nextCursor != nil {
            load(reset: false)
        }
    }
}

final class OwnerTruthFormalMemoryDetailViewController: UIViewController {
    private let accountLease: AccountLease
    private let memoryID: OwnerTruthRecordID
    private let client: OwnerTruthFormalMemoryClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private var requestGeneration: UInt64 = 0
    private var detail: OwnerTruthFormalMemoryDetail?
    var onRevisionCommitted: (() -> Void)?
    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var onDetailRenderedForUIQA: ((OwnerTruthFormalMemoryDetailViewController) -> Void)?
    #endif

    init(
        accountLease: AccountLease,
        memoryID: OwnerTruthRecordID,
        client: OwnerTruthFormalMemoryClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.accountLease = accountLease
        self.memoryID = memoryID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "正式记忆详情"
        view.backgroundColor = DJDesignTokens.Color.background
        configureView()
        load()
    }

    private func configureView() {
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "owner-truth-formal-memory-detail"
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 20,
            leading: DJDesignTokens.Spacing.page,
            bottom: 30,
            trailing: DJDesignTokens.Spacing.page
        )
        statusLabel.font = DJDesignTokens.Font.body(15)
        statusLabel.textColor = DJDesignTokens.Color.textTertiary
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.accessibilityIdentifier = "owner-truth-formal-memory-detail-status"
        stackView.addArrangedSubview(statusLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func load() {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            failClosedForAccountChange()
            return
        }
        requestGeneration &+= 1
        let generation = requestGeneration
        statusLabel.text = "正在读取正式记忆..."
        client.fetchOwnerTruthFormalMemory(vaultID: vaultID, memoryID: memoryID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                switch result {
                case .success(let detail):
                    self.detail = detail
                    self.render(detail)
                case .failure(let error):
                    self.statusLabel.text = "正式记忆读取失败。\n\(error.localizedDescription)"
                }
            }
        }
    }

    private func render(_ detail: OwnerTruthFormalMemoryDetail) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stackView.addArrangedSubview(sectionCard(
            title: detail.memory.currentVersion.summary,
            lines: [
                "\(detail.memory.memoryKind.formalMemoryTitle) · 当前第 \(detail.memory.currentVersion.versionNumber) 版",
                "\(detail.memory.currentVersion.sourceCount) 项来源依据 · \(detail.memory.currentVersion.createdAt.formalMemoryDateText)",
            ],
            accessibilityIdentifier: "owner-truth-formal-memory-current"
        ))
        let facetLines = ["people", "time", "places", "relationships", "emotions", "values", "personality"]
            .flatMap { detail.memory.currentVersion.facetValues(named: $0) }
        if !facetLines.isEmpty {
            stackView.addArrangedSubview(sectionCard(
                title: "已确认线索",
                lines: [facetLines.joined(separator: "、")],
                accessibilityIdentifier: "owner-truth-formal-memory-facets"
            ))
        }
        let history = detail.versions.dropFirst()
        if !history.isEmpty {
            let historyStack = UIStackView()
            historyStack.axis = .vertical
            historyStack.spacing = 10
            let heading = UILabel()
            heading.text = "历史快照"
            heading.font = DJDesignTokens.Font.title(18)
            heading.textColor = DJDesignTokens.Color.textPrimary
            historyStack.addArrangedSubview(heading)
            for version in history {
                historyStack.addArrangedSubview(sectionCard(
                    title: "第 \(version.versionNumber) 版",
                    lines: [version.summary, version.createdAt.formalMemoryDateText],
                    accessibilityIdentifier: "owner-truth-formal-memory-history-version"
                ))
            }
            if detail.historyTruncated {
                let note = UILabel()
                note.text = "仅展示最近 3 个历史快照。"
                note.font = DJDesignTokens.Font.label(12)
                note.textColor = DJDesignTokens.Color.textTertiary
                note.numberOfLines = 0
                historyStack.addArrangedSubview(note)
            }
            stackView.addArrangedSubview(historyStack)
        }
        let editButton = UIButton(type: .system)
        editButton.setTitle("更正正式记忆", for: .normal)
        editButton.setTitleColor(.white, for: .normal)
        editButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        editButton.backgroundColor = DJDesignTokens.Color.accentDeep
        editButton.layer.cornerRadius = 8
        editButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        editButton.accessibilityIdentifier = "owner-truth-formal-memory-edit"
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        stackView.addArrangedSubview(editButton)
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        onDetailRenderedForUIQA?(self)
        #endif
    }

    private func sectionCard(title: String, lines: [String], accessibilityIdentifier: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.title(18)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        let views: [UIView] = [titleLabel] + lines.map { value in
            let label = UILabel()
            label.text = value
            label.font = DJDesignTokens.Font.body(14)
            label.textColor = DJDesignTokens.Color.textSecondary
            label.numberOfLines = 0
            return label
        }
        let content = UIStackView(arrangedSubviews: views)
        content.axis = .vertical
        content.spacing = 8
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.15).cgColor
        card.accessibilityIdentifier = accessibilityIdentifier
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    @objc private func editTapped() {
        guard let detail,
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
            failClosedForAccountChange()
            return
        }
        let editor = OwnerTruthFormalMemoryEditViewController(
            accountLease: accountLease,
            detail: detail,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime
        )
        editor.onRevisionCommitted = { [weak self] in
            self?.onRevisionCommitted?()
            self?.load()
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        detail = nil
        statusLabel.text = "账号已变化，请返回后重新进入正式记忆。"
        navigationItem.rightBarButtonItems = []
    }
}

final class OwnerTruthFormalMemoryEditViewController: UIViewController, UITextViewDelegate {
    private let accountLease: AccountLease
    private let detail: OwnerTruthFormalMemoryDetail
    private let client: OwnerTruthFormalMemoryClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let textView = UITextView()
    private let diffCard = UIView()
    private let oldValueLabel = UILabel()
    private let newValueLabel = UILabel()
    private let errorLabel = UILabel()
    private let reviewButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private var requestGeneration: UInt64 = 0
    private var isSubmitting = false
    var onRevisionCommitted: (() -> Void)?

    init(
        accountLease: AccountLease,
        detail: OwnerTruthFormalMemoryDetail,
        client: OwnerTruthFormalMemoryClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.accountLease = accountLease
        self.detail = detail
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "更正正式记忆"
        view.backgroundColor = DJDesignTokens.Color.background
        configureView()
    }

    private var currentVersion: OwnerTruthFormalMemoryVersion {
        detail.memory.currentVersion
    }

    private func configureView() {
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 20,
            leading: DJDesignTokens.Spacing.page,
            bottom: 30,
            trailing: DJDesignTokens.Spacing.page
        )
        let explanation = UILabel()
        explanation.text = "更正不会覆盖旧记录。再次确认后，系统会生成新的正式记忆版本并保留最近 3 个历史快照。"
        explanation.font = DJDesignTokens.Font.body(14)
        explanation.textColor = DJDesignTokens.Color.textSecondary
        explanation.numberOfLines = 0

        textView.text = currentVersion.summary
        textView.font = DJDesignTokens.Font.body(16)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = DJDesignTokens.Color.textPrimary
        textView.backgroundColor = DJDesignTokens.Color.surface
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.18).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        textView.accessibilityIdentifier = "owner-truth-formal-memory-edit-input"
        textView.delegate = self

        configureDiffCard()
        configureButton(
            reviewButton,
            title: "查看修改并确认",
            identifier: "owner-truth-formal-memory-edit-review",
            selector: #selector(reviewTapped),
            primary: false
        )
        configureButton(
            confirmButton,
            title: "再次确认并保存",
            identifier: "owner-truth-formal-memory-edit-confirm",
            selector: #selector(confirmTapped),
            primary: true
        )
        confirmButton.isHidden = true

        errorLabel.font = DJDesignTokens.Font.label(13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.accessibilityIdentifier = "owner-truth-formal-memory-edit-error"

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        [explanation, textView, diffCard, errorLabel, reviewButton, confirmButton].forEach(stackView.addArrangedSubview)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func configureDiffCard() {
        oldValueLabel.font = DJDesignTokens.Font.body(14)
        oldValueLabel.textColor = DJDesignTokens.Color.textSecondary
        oldValueLabel.numberOfLines = 0
        newValueLabel.font = DJDesignTokens.Font.body(14)
        newValueLabel.textColor = DJDesignTokens.Color.textPrimary
        newValueLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [oldValueLabel, newValueLabel])
        stack.axis = .vertical
        stack.spacing = 10
        diffCard.backgroundColor = DJDesignTokens.Color.surface
        diffCard.layer.cornerRadius = 8
        diffCard.layer.borderWidth = 1
        diffCard.layer.borderColor = DJDesignTokens.Color.accent.withAlphaComponent(0.24).cgColor
        diffCard.isHidden = true
        diffCard.accessibilityIdentifier = "owner-truth-formal-memory-edit-diff"
        diffCard.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: diffCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: diffCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: diffCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: diffCard.bottomAnchor, constant: -14),
        ])
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        identifier: String,
        selector: Selector,
        primary: Bool
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(primary ? .white : DJDesignTokens.Color.accentDeep, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.backgroundColor = primary ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.surface
        button.layer.cornerRadius = 8
        button.layer.borderWidth = primary ? 0 : 1
        button.layer.borderColor = DJDesignTokens.Color.accent.withAlphaComponent(0.25).cgColor
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    func textViewDidChange(_ textView: UITextView) {
        diffCard.isHidden = true
        confirmButton.isHidden = true
        reviewButton.isHidden = false
        errorLabel.isHidden = true
    }

    @objc private func reviewTapped() {
        let replacement = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty, replacement != currentVersion.summary else {
            errorLabel.text = replacement.isEmpty ? "更正内容不能为空。" : "内容没有变化，无需生成新版本。"
            errorLabel.isHidden = false
            return
        }
        view.endEditing(true)
        oldValueLabel.text = "修改前\n\(currentVersion.summary)"
        newValueLabel.text = "修改后\n\(replacement)"
        diffCard.isHidden = false
        reviewButton.isHidden = true
        confirmButton.isHidden = false
        errorLabel.isHidden = true
        UIAccessibility.post(notification: .layoutChanged, argument: diffCard)
    }

    @objc private func confirmTapped() {
        guard !isSubmitting,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            failClosedForAccountChange()
            return
        }
        let replacement = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let command: OwnerTruthFormalMemoryRevisionCommand
        do {
            command = try OwnerTruthFormalMemoryRevisionCommand(
                expectedVersion: currentVersion.versionNumber,
                expectedContentHash: currentVersion.contentHash,
                expectedContentSchemaVersion: currentVersion.contentSchemaVersion,
                contentSchemaVersion: currentVersion.contentSchemaVersion,
                correctedContent: currentVersion.content(replacingEditableText: replacement),
                secondConfirmation: true
            )
        } catch {
            errorLabel.text = error.localizedDescription
            errorLabel.isHidden = false
            return
        }
        requestGeneration &+= 1
        let generation = requestGeneration
        isSubmitting = true
        textView.isEditable = false
        confirmButton.isEnabled = false
        confirmButton.setTitle("正在保存...", for: .normal)
        errorLabel.isHidden = true
        client.reviseOwnerTruthFormalMemory(
            vaultID: vaultID,
            memoryID: detail.memory.id,
            command: command
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                self.isSubmitting = false
                self.textView.isEditable = true
                self.confirmButton.isEnabled = true
                self.confirmButton.setTitle("再次确认并保存", for: .normal)
                switch result {
                case .success:
                    self.onRevisionCommitted?()
                    self.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self.errorLabel.text = "保存失败，记忆可能已更新。请返回刷新后再试。\n\(error.localizedDescription)"
                    self.errorLabel.isHidden = false
                }
            }
        }
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        isSubmitting = false
        textView.isEditable = false
        reviewButton.isEnabled = false
        confirmButton.isEnabled = false
        errorLabel.text = "账号已变化，本次草稿不会保存。请返回后重新进入。"
        errorLabel.isHidden = false
    }
}

private extension OwnerTruthMemoryKind {
    var formalMemoryTitle: String {
        switch self {
        case .experience: return "经历"
        case .knowledge: return "知识"
        case .emotion: return "感受"
        }
    }
}

private extension Date {
    var formalMemoryDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
private struct OwnerTruthFormalMemoryUIQAResult: Codable {
    static let fileName = "owner-truth-formal-memory-uiqa-result.json"
    let completed: Bool
    let listVisible: Bool
    let detailVisible: Bool
    let currentVersionVisible: Bool
    let historyVersionCount: Int
    let userDeleteAvailable: Bool

    func write() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = documents.appendingPathComponent(Self.fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: [.atomic])
        return url
    }
}

enum OwnerTruthFormalMemoryUIQASmoke {
    static let holdAtDetailArgument = "DJOwnerTruthFormalMemoryUIQAHoldAtDetail"

    static func makeViewController(accountLease: AccountLease) -> OwnerTruthFormalMemoryListViewController {
        let client = OwnerTruthFormalMemoryUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId)!)
        let list = OwnerTruthFormalMemoryListViewController(accountLease: accountLease, client: client)
        var consumedList = false
        list.onPageRenderedForUIQA = { controller in
            guard !consumedList else { return }
            consumedList = true
            if ProcessInfo.processInfo.arguments.contains(holdAtDetailArgument) {
                controller.openFirstMemoryForUIQA()
            } else {
                finish(listVisible: true, detailVisible: false, historyVersionCount: 0)
            }
        }
        return list
    }

    static func connectDetailHook(_ controller: OwnerTruthFormalMemoryDetailViewController) {
        controller.onDetailRenderedForUIQA = { detailController in
            finish(listVisible: true, detailVisible: true, historyVersionCount: 3)
            detailController.onDetailRenderedForUIQA = nil
        }
    }

    private static func finish(
        listVisible: Bool,
        detailVisible: Bool,
        historyVersionCount: Int
    ) {
        do {
            let url = try OwnerTruthFormalMemoryUIQAResult(
                completed: true,
                listVisible: listVisible,
                detailVisible: detailVisible,
                currentVersionVisible: true,
                historyVersionCount: historyVersionCount,
                userDeleteAvailable: false
            ).write()
            print("[UI_QA] OwnerTruthFormalMemorySmoke completed result=\(url.path)")
        } catch {
            print("[UI_QA] OwnerTruthFormalMemorySmoke failed write=\(error.localizedDescription)")
        }
    }
}

private final class OwnerTruthFormalMemoryUIQAClient: OwnerTruthFormalMemoryClient {
    private let vaultID: OwnerTruthVaultID

    init(vaultID: OwnerTruthVaultID) {
        self.vaultID = vaultID
    }

    func fetchOwnerTruthFormalMemories(
        vaultID: OwnerTruthVaultID,
        query: OwnerTruthFormalMemoryQuery,
        completion: @escaping (Result<OwnerTruthFormalMemoryPage, Error>) -> Void
    ) {
        do {
            completion(.success(try OwnerTruthFormalMemoryPage(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthFormalMemoryPage.schemaVersion,
                    "vaultId": self.vaultID.rawValue,
                    "memories": [memoryObject(currentVersion: versionObject(number: 4, current: true))],
                    "nextCursor": NSNull(),
                ],
                expectedVaultID: self.vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func fetchOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthFormalMemoryDetail, Error>) -> Void
    ) {
        do {
            let versions = (1...4).reversed().map { versionObject(number: $0, current: $0 == 4) }
            completion(.success(try OwnerTruthFormalMemoryDetail(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthFormalMemoryDetail.schemaVersion,
                    "vaultId": self.vaultID.rawValue,
                    "memory": memoryObject(
                        currentVersion: versions[0],
                        versions: versions,
                        historyTruncated: true
                    ),
                ],
                expectedVaultID: self.vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func reviseOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        command: OwnerTruthFormalMemoryRevisionCommand,
        completion: @escaping (Result<OwnerTruthFormalMemoryRevisionReceipt, Error>) -> Void
    ) {
        completion(.failure(OwnerTruthFormalMemoryContractError.invalidRevision("UIQA 不执行持久写入")))
    }

    private func memoryObject(
        currentVersion: [String: Any],
        versions: [[String: Any]]? = nil,
        historyTruncated: Bool = false
    ) -> [String: Any] {
        var object: [String: Any] = [
            "memoryId": "00000000-0000-0000-0000-000000000101",
            "memoryKind": "experience",
            "perspectiveType": "firstPerson",
            "epistemicStatus": "recalled",
            "sensitivity": "standard",
            "currentVersion": currentVersion,
        ]
        if let versions {
            object["historyLimit"] = 3
            object["historyTruncated"] = historyTruncated
            object["versions"] = versions
        }
        return object
    }

    private func versionObject(number: Int, current: Bool) -> [String: Any] {
        [
            "versionId": String(format: "00000000-0000-0000-0000-%012d", number),
            "versionNumber": number,
            "status": current ? "current" : "superseded",
            "decision": number == 1 ? "accepted" : "corrected",
            "contentSchemaVersion": "owner-truth-v2",
            "contentHash": String(repeating: String(number), count: 64),
            "content": [
                "summary": number == 4
                    ? "小时候，外婆会在夏夜带我去院子里看星星。"
                    : "夏夜和外婆一起看星星的记忆（第 \(number) 版）",
                "facets": [
                    "people": [["value": "外婆"]],
                    "places": [["value": "老家院子"]],
                ],
            ],
            "sourceCount": 2,
            "createdAt": "2026-08-1\(number)T10:00:00Z",
        ]
    }
}
#endif
