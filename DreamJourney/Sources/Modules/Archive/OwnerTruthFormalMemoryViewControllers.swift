import UIKit

final class OwnerTruthFormalMemoryListViewController: UIViewController {
    private let accountLease: AccountLease
    private let client: OwnerTruthFormalMemoryClient
    private let publicationClient: PublicationDraftWriterClient
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
    private lazy var publishButton = UIBarButtonItem(
        image: UIImage(systemName: "square.and.arrow.up"),
        style: .plain,
        target: self,
        action: #selector(publishTapped)
    )
    private lazy var continueButton = UIBarButtonItem(
        title: "下一步",
        style: .done,
        target: self,
        action: #selector(continuePublicationTapped)
    )
    private lazy var cancelSelectionButton = UIBarButtonItem(
        title: "取消",
        style: .plain,
        target: self,
        action: #selector(cancelPublicationSelection)
    )

    private var items: [OwnerTruthFormalMemoryListItem] = []
    private var nextCursor: String?
    private var selectedKind: OwnerTruthMemoryKind?
    private var selectedFacet: OwnerTruthFormalMemoryFacetFilter?
    private var requestGeneration: UInt64 = 0
    private var searchWorkItem: DispatchWorkItem?
    private var isLoading = false
    private var isSelectingForPublication = false
    private var selectedPublicationMemoryIDs: Set<OwnerTruthRecordID> = []

    private var memorySections: [(kind: OwnerTruthMemoryKind, items: [OwnerTruthFormalMemoryListItem])] {
        let kinds = selectedKind.map { [$0] } ?? OwnerTruthMemoryKind.allCases
        return kinds.compactMap { kind in
            let sectionItems = items.filter { $0.memoryKind == kind }
            return sectionItems.isEmpty ? nil : (kind, sectionItems)
        }
    }

    private func memory(at indexPath: IndexPath) -> OwnerTruthFormalMemoryListItem? {
        let sections = memorySections
        guard sections.indices.contains(indexPath.section),
              sections[indexPath.section].items.indices.contains(indexPath.row) else {
            return nil
        }
        return sections[indexPath.section].items[indexPath.row]
    }
    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var onPageRenderedForUIQA: ((OwnerTruthFormalMemoryListViewController) -> Void)?
    #endif

    init(
        accountLease: AccountLease,
        client: OwnerTruthFormalMemoryClient = DreamJourneyBackendClient.shared,
        publicationClient: PublicationDraftWriterClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.accountLease = accountLease
        self.client = client
        self.publicationClient = publicationClient
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
        if !isSelectingForPublication {
            updateNavigationItems()
        }
    }

    private var vaultID: OwnerTruthVaultID? {
        OwnerTruthVaultID(accountLease.vaultId)
    }

    private func configureNavigation() {
        filterButton.accessibilityIdentifier = "owner-truth-formal-memory-filter"
        filterButton.accessibilityLabel = "筛选正式记忆"
        refreshButton.accessibilityIdentifier = "owner-truth-formal-memory-refresh"
        publishButton.accessibilityIdentifier = "owner-publication-start"
        publishButton.accessibilityLabel = "选择正式记忆并发布"
        continueButton.accessibilityIdentifier = "owner-publication-selection-next"
        cancelSelectionButton.accessibilityIdentifier = "owner-publication-selection-cancel"
        updateNavigationItems()

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

    @objc private func publishTapped() {
        guard PublicationManagementAccessGate.isPublicationRouteAllowed else {
            showPublicationAlert(title: "暂不可用", message: "记忆发布当前未启用。")
            return
        }
        guard !items.isEmpty else {
            showPublicationAlert(title: "还没有可发布内容", message: "正式记忆生成后，可从这里选择公开副本。")
            return
        }
        isSelectingForPublication = true
        selectedPublicationMemoryIDs.removeAll()
        tableView.allowsMultipleSelection = true
        searchController.isActive = false
        searchController.searchBar.isUserInteractionEnabled = false
        updateNavigationItems()
        tableView.reloadData()
        UIAccessibility.post(notification: .announcement, argument: "请选择要发布的正式记忆")
    }

    @objc private func cancelPublicationSelection() {
        finishPublicationSelection()
    }

    @objc private func continuePublicationTapped() {
        guard isSelectingForPublication,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            failClosedForAccountChange()
            return
        }
        let selected = items.filter { selectedPublicationMemoryIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        do {
            let composer = try OwnerPublicationDraftComposerViewController(
                accountLease: accountLease,
                memories: selected,
                client: publicationClient,
                accountLeaseRuntime: accountLeaseRuntime
            )
            composer.onPublicationConfirmed = { [weak self] receipt in
                guard let self else { return }
                self.finishPublicationSelection()
                self.navigationController?.popToViewController(self, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showPublicationAlert(
                        title: "发布完成",
                        message: "已生成不可变公开版本，共 \(receipt.itemCount) 项。"
                    )
                }
            }
            navigationController?.pushViewController(composer, animated: true)
        } catch {
            showPublicationAlert(title: "无法继续", message: error.localizedDescription)
        }
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

    private func updateNavigationItems() {
        if isSelectingForPublication {
            navigationItem.leftBarButtonItem = cancelSelectionButton
            continueButton.isEnabled = !selectedPublicationMemoryIDs.isEmpty
            continueButton.title = selectedPublicationMemoryIDs.isEmpty
                ? "下一步"
                : "下一步（\(selectedPublicationMemoryIDs.count)）"
            navigationItem.rightBarButtonItems = [continueButton]
            refreshButton.isEnabled = false
            filterButton.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem = nil
            var buttons = [refreshButton, filterButton]
            if PublicationManagementAccessGate.isPublicationRouteAllowed {
                buttons.insert(publishButton, at: 0)
            }
            navigationItem.rightBarButtonItems = buttons
            refreshButton.isEnabled = !isLoading
            filterButton.isEnabled = true
            searchController.searchBar.isUserInteractionEnabled = true
        }
    }

    private func finishPublicationSelection() {
        isSelectingForPublication = false
        selectedPublicationMemoryIDs.removeAll()
        tableView.allowsMultipleSelection = false
        for indexPath in tableView.indexPathsForSelectedRows ?? [] {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        updateNavigationItems()
        tableView.reloadData()
    }

    private func updatePublicationSelection() {
        continueButton.isEnabled = !selectedPublicationMemoryIDs.isEmpty
        continueButton.title = selectedPublicationMemoryIDs.isEmpty
            ? "下一步"
            : "下一步（\(selectedPublicationMemoryIDs.count)）"
    }

    private func showPublicationAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
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
        publishButton.isEnabled = false
        continueButton.isEnabled = false
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    func openFirstMemoryForUIQA() {
        guard !items.isEmpty else { return }
        tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
    }

    func openPublicationComposerForUIQA() {
        guard items.count >= 2 else { return }
        publishTapped()
        selectedPublicationMemoryIDs = Set(items.prefix(2).map(\.id))
        updatePublicationSelection()
        continuePublicationTapped()
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
    func numberOfSections(in tableView: UITableView) -> Int {
        memorySections.count + (nextCursor == nil ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sections = memorySections
        return sections.indices.contains(section) ? sections[section].items.count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sections = memorySections
        guard sections.indices.contains(section) else { return nil }
        return sections[section].kind.formalMemorySectionTitle
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = memory(at: indexPath) else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = isLoading ? "正在载入..." : "载入更多"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = DJDesignTokens.Color.accentDeep
            cell.accessibilityIdentifier = "owner-truth-formal-memory-load-more"
            return cell
        }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DJDesignTokens.Color.surface
        cell.textLabel?.text = item.currentVersion.summary
        cell.textLabel?.font = DJDesignTokens.Font.body(16)
        cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = "\(item.memoryKind.formalMemoryTitle) · 第 \(item.currentVersion.versionNumber) 版 · \(item.currentVersion.createdAt.formalMemoryDateText)"
        cell.detailTextLabel?.font = DJDesignTokens.Font.label(12)
        cell.detailTextLabel?.textColor = DJDesignTokens.Color.textTertiary
        cell.accessoryType = isSelectingForPublication && selectedPublicationMemoryIDs.contains(item.id)
            ? .checkmark
            : (isSelectingForPublication ? .none : .disclosureIndicator)
        cell.accessibilityIdentifier = "owner-truth-formal-memory-row"
        cell.accessibilityLabel = "\(item.currentVersion.summary)，\(item.memoryKind.formalMemoryTitle)，第 \(item.currentVersion.versionNumber) 版"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = memory(at: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            load(reset: false)
            return
        }
        if isSelectingForPublication {
            guard selectedPublicationMemoryIDs.count < PublicationDraftCreateCommand.maximumItemCount
                    || selectedPublicationMemoryIDs.contains(item.id) else {
                tableView.deselectRow(at: indexPath, animated: false)
                showPublicationAlert(
                    title: "已达到上限",
                    message: "一次最多选择 \(PublicationDraftCreateCommand.maximumItemCount) 条正式记忆。"
                )
                return
            }
            selectedPublicationMemoryIDs.insert(item.id)
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            updatePublicationSelection()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
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

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard isSelectingForPublication, let item = memory(at: indexPath) else { return }
        selectedPublicationMemoryIDs.remove(item.id)
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        updatePublicationSelection()
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if memory(at: indexPath) == nil, nextCursor != nil {
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

final class OwnerTruthSourceRecordListViewController: UIViewController {
    private let accountLease: AccountLease
    private let client: OwnerTruthSourceRecordClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )
    private var records: [OwnerTruthSourceRecord] = []
    private var nextCursor: String?
    private var requestGeneration: UInt64 = 0
    private var isLoading = false

    init(
        accountLease: AccountLease,
        client: OwnerTruthSourceRecordClient = DreamJourneyBackendClient.shared,
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
        title = "内容记录"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        configureView()
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

    private func configureView() {
        tableView.backgroundColor = DJDesignTokens.Color.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "owner-truth-source-record-list"

        statusLabel.font = DJDesignTokens.Font.body(15)
        statusLabel.textColor = DJDesignTokens.Color.textTertiary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-source-record-status"

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

    private func load(reset: Bool) {
        guard !isLoading,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let vaultID else {
            failClosedForAccountChange()
            return
        }
        let cursor = reset ? nil : nextCursor
        guard reset || cursor != nil else { return }
        let query: OwnerTruthSourceRecordQuery
        do {
            query = try OwnerTruthSourceRecordQuery(cursor: cursor, limit: 20)
        } catch {
            statusLabel.text = error.localizedDescription
            statusLabel.isHidden = false
            return
        }
        if reset {
            requestGeneration &+= 1
            records = []
            nextCursor = nil
            tableView.reloadData()
        }
        let generation = requestGeneration
        isLoading = true
        refreshButton.isEnabled = false
        statusLabel.text = reset ? "正在读取内容记录..." : "正在载入更多记录..."
        statusLabel.isHidden = false
        client.fetchOwnerTruthSourceRecords(vaultID: vaultID, query: query) { [weak self] result in
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
                    let knownIDs = Set(self.records.map(\.id))
                    self.records.append(contentsOf: page.records.filter { !knownIDs.contains($0.id) })
                    self.nextCursor = page.nextCursor
                    self.statusLabel.text = self.records.isEmpty
                        ? "还没有内容记录。你提交的文字或媒体素材会按次保留在这里。"
                        : nil
                    self.statusLabel.isHidden = !self.records.isEmpty
                    self.tableView.reloadData()
                case .failure(let error):
                    self.statusLabel.text = "内容记录读取失败。\n\(error.localizedDescription)"
                    self.statusLabel.isHidden = false
                }
            }
        }
    }

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        isLoading = false
        records = []
        nextCursor = nil
        tableView.reloadData()
        statusLabel.text = "账号已变化，请返回后重新进入内容记录。"
        statusLabel.isHidden = false
        refreshButton.isEnabled = false
    }
}

extension OwnerTruthSourceRecordListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records.count + (nextCursor == nil ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard records.indices.contains(indexPath.row) else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = isLoading ? "正在载入..." : "载入更多"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = DJDesignTokens.Color.accentDeep
            cell.accessibilityIdentifier = "owner-truth-source-record-load-more"
            return cell
        }
        let record = records[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DJDesignTokens.Color.surface
        cell.textLabel?.text = record.displayPreview
        cell.textLabel?.font = DJDesignTokens.Font.body(16)
        cell.textLabel?.textColor = DJDesignTokens.Color.textPrimary
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = "\(record.organizationStatus.title) · \(record.createdAt.formalMemoryDateText)"
        cell.detailTextLabel?.font = DJDesignTokens.Font.label(12)
        cell.detailTextLabel?.textColor = record.organizationStatus == .failed
            ? .systemRed
            : DJDesignTokens.Color.textTertiary
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "owner-truth-source-record-row"
        cell.accessibilityLabel = "\(record.displayPreview)，\(record.organizationStatus.title)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard records.indices.contains(indexPath.row) else {
            load(reset: false)
            return
        }
        navigationController?.pushViewController(
            OwnerTruthSourceRecordDetailViewController(
                accountLease: accountLease,
                sourceID: records[indexPath.row].id,
                client: client,
                accountLeaseRuntime: accountLeaseRuntime
            ),
            animated: true
        )
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == records.count, nextCursor != nil {
            load(reset: false)
        }
    }
}

final class OwnerTruthSourceRecordDetailViewController: UIViewController {
    private let accountLease: AccountLease
    private let sourceID: OwnerTruthRecordID
    private let client: OwnerTruthSourceRecordClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private var requestGeneration: UInt64 = 0

    init(
        accountLease: AccountLease,
        sourceID: OwnerTruthRecordID,
        client: OwnerTruthSourceRecordClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.accountLease = accountLease
        self.sourceID = sourceID
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
        title = "内容记录详情"
        view.backgroundColor = DJDesignTokens.Color.background
        configureView()
        load()
    }

    private func configureView() {
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "owner-truth-source-record-detail"
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
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
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
        statusLabel.text = "正在读取内容记录..."
        client.fetchOwnerTruthSourceRecord(vaultID: vaultID, sourceID: sourceID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.requestGeneration,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .ui).allowed else {
                    return
                }
                switch result {
                case .success(let detail):
                    self.render(detail)
                case .failure(let error):
                    self.statusLabel.text = "内容记录读取失败。\n\(error.localizedDescription)"
                }
            }
        }
    }

    private func render(_ detail: OwnerTruthSourceRecordDetail) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stackView.addArrangedSubview(sectionCard(
            title: detail.record.organizationStatus.title,
            lines: [
                "提交时间：\(detail.record.createdAt.formalMemoryDateText)",
                "候选 \(detail.record.candidateCount) 条 · 待确认 \(detail.record.pendingCount) 条 · 已写入 \(detail.record.confirmedCount) 条 · 已拒绝 \(detail.record.rejectedCount) 条",
            ],
            identifier: "owner-truth-source-record-organization"
        ))
        stackView.addArrangedSubview(sectionCard(
            title: "本次原始内容",
            lines: [detail.text.isEmpty ? "该条记录不包含可显示的文字内容。" : detail.text],
            identifier: "owner-truth-source-record-original-text"
        ))
        var technicalLines = [
            "素材类型：\(detail.record.sourceKind)",
            "素材版本：\(detail.record.sourceVersion)",
        ]
        if let failureCode = detail.record.failureCode {
            technicalLines.append("失败原因：\(failureCode)")
        }
        stackView.addArrangedSubview(sectionCard(
            title: "处理信息",
            lines: technicalLines,
            identifier: "owner-truth-source-record-processing"
        ))
    }

    private func sectionCard(title: String, lines: [String], identifier: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.title(18)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        let bodyLabel = UILabel()
        bodyLabel.text = lines.joined(separator: "\n")
        bodyLabel.font = DJDesignTokens.Font.body(14)
        bodyLabel.textColor = DJDesignTokens.Color.textSecondary
        bodyLabel.numberOfLines = 0
        let content = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        content.axis = .vertical
        content.spacing = 8
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.accent.withAlphaComponent(0.18).cgColor
        card.accessibilityIdentifier = identifier
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

    private func failClosedForAccountChange() {
        requestGeneration &+= 1
        statusLabel.text = "账号已变化，请返回后重新进入内容记录。"
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

    var formalMemorySectionTitle: String {
        switch self {
        case .experience: return "经历记忆"
        case .knowledge: return "知识记忆"
        case .emotion: return "情感记忆"
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
    let publicationComposerVisible: Bool
    let publicationPreviewVisible: Bool

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
    static let holdAtPublicationComposerArgument = "DJOwnerPublicationUIQAHoldAtComposer"
    static let holdAtPublicationPreviewArgument = "DJOwnerPublicationUIQAHoldAtPreview"

    static func makeViewController(accountLease: AccountLease) -> OwnerTruthFormalMemoryListViewController {
        let client = OwnerTruthFormalMemoryUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId)!)
        let list = OwnerTruthFormalMemoryListViewController(
            accountLease: accountLease,
            client: client,
            publicationClient: OwnerPublicationDraftUIQAClient()
        )
        var consumedList = false
        list.onPageRenderedForUIQA = { controller in
            guard !consumedList else { return }
            consumedList = true
            if ProcessInfo.processInfo.arguments.contains(holdAtDetailArgument) {
                controller.openFirstMemoryForUIQA()
            } else if ProcessInfo.processInfo.arguments.contains(holdAtPublicationComposerArgument)
                        || ProcessInfo.processInfo.arguments.contains(holdAtPublicationPreviewArgument) {
                controller.openPublicationComposerForUIQA()
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

    static func finishPublicationComposer() {
        finish(
            listVisible: true,
            detailVisible: false,
            historyVersionCount: 0,
            publicationComposerVisible: true,
            publicationPreviewVisible: false
        )
    }

    static func finishPublicationPreview() {
        finish(
            listVisible: true,
            detailVisible: false,
            historyVersionCount: 0,
            publicationComposerVisible: true,
            publicationPreviewVisible: true
        )
    }

    private static func finish(
        listVisible: Bool,
        detailVisible: Bool,
        historyVersionCount: Int,
        publicationComposerVisible: Bool = false,
        publicationPreviewVisible: Bool = false
    ) {
        do {
            let url = try OwnerTruthFormalMemoryUIQAResult(
                completed: true,
                listVisible: listVisible,
                detailVisible: detailVisible,
                currentVersionVisible: true,
                historyVersionCount: historyVersionCount,
                userDeleteAvailable: false,
                publicationComposerVisible: publicationComposerVisible,
                publicationPreviewVisible: publicationPreviewVisible
            ).write()
            print("[UI_QA] OwnerTruthFormalMemorySmoke completed result=\(url.path)")
        } catch {
            print("[UI_QA] OwnerTruthFormalMemorySmoke failed write=\(error.localizedDescription)")
        }
    }
}

private final class OwnerPublicationDraftUIQAClient: PublicationDraftWriterClient {
    func createPublicationDraft(
        vaultID: String,
        command: PublicationDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    ) {
        let publicationID = "00000000-0000-0000-0000-000000000201"
        let draftID = "00000000-0000-0000-0000-000000000202"
        let items: [[String: Any]] = command.items.enumerated().map { index, item in
            [
                "itemIndex": index,
                "memoryVersionId": item.memoryVersionID,
                "itemSnapshotHash": String(repeating: String(index + 1), count: 64),
                "preview": ["title": item.publicTitle, "body": item.publicBody],
                "thirdPartyReviewRequired": false,
            ]
        }
        let object: [String: Any] = [
            "schemaVersion": "publication-authority-v2",
            "vaultId": vaultID,
            "publicationId": publicationID,
            "draftId": draftID,
            "outcome": "created",
            "state": "draft",
            "expectedDraftRevision": 1,
            "expectedDraftSnapshotHash": String(repeating: "a", count: 64),
            "itemCount": items.count,
            "items": items,
            "requiresSecondConfirmation": true,
            "thirdPartyReviewRequired": false,
            "aiDisclosureRequired": true,
        ]
        guard let receipt = PublicationDraftReceipt(json: object) else {
            completion(.failure(PublicationDraftAccessError.malformedResponse))
            return
        }
        completion(.success(receipt))
    }

    func createPublicationRevisionDraft(
        vaultID: String,
        publicationID: String,
        command: PublicationRevisionDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    ) {
        completion(.failure(PublicationDraftAccessError.unavailable))
    }

    func confirmPublicationDraft(
        vaultID: String,
        publicationID: String,
        draftID: String,
        command: PublicationDraftConfirmCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftConfirmReceipt, Error>) -> Void
    ) {
        completion(.failure(PublicationDraftAccessError.unavailable))
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
                    "memories": [
                        memoryObject(
                            memoryID: "00000000-0000-0000-0000-000000000101",
                            currentVersion: versionObject(number: 4, current: true)
                        ),
                        memoryObject(
                            memoryID: "00000000-0000-0000-0000-000000000102",
                            currentVersion: versionObject(number: 5, current: true)
                        ),
                    ],
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
                        memoryID: "00000000-0000-0000-0000-000000000101",
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
        memoryID: String,
        currentVersion: [String: Any],
        versions: [[String: Any]]? = nil,
        historyTruncated: Bool = false
    ) -> [String: Any] {
        var object: [String: Any] = [
            "memoryId": memoryID,
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
