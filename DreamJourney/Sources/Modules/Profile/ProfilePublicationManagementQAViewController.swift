import UIKit

/// Owner publication management surface. It exposes only server-redacted
/// previews and ShareGrant lifecycle state, and never routes into private Echo
/// or a visitor session. Internal UIQA reuses the same view through QA gates.
final class ProfilePublicationManagementQAViewController: UIViewController {

    private struct PendingWithdrawalConfirmation {
        let publication: PublicationManagementPublication
        let accountLease: AccountLease
    }

    private enum LoadState {
        case idle
        case loading
        case loaded(PublicationManagementSnapshot)
        case empty
        case failed(String)
    }

    private let useCase: PublicationManagementReadUseCase
    private let versionAuditUseCase: PublicationVersionAuditUseCase
    private let lifecycleUseCase: PublicationLifecycleUseCase
    private let publicationClient: PublicationDraftWriterClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let accountLeaseProvider: () -> AccountLease?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var loadState: LoadState = .idle
    private var lifecycleReceipts: [String: PublicationLifecycleReceipt] = [:]
    private var lifecycleFailures: [String: String] = [:]
    private var lifecyclePendingPublicationIDs: Set<String> = []
    private var pendingWithdrawalConfirmation: PendingWithdrawalConfirmation?
    private var versionAudits: [String: PublicationOwnerVersionAudit] = [:]
    private var versionAuditFailures: [String: String] = [:]
    private var versionAuditPendingPublicationIDs: Set<String> = []

    init(
        client: PublicationManagementReaderClient = DreamJourneyBackendClient.shared,
        versionClient: PublicationVersionAuditReaderClient? = nil,
        publicationClient: PublicationDraftWriterClient = DreamJourneyBackendClient.shared,
        lifecycleClient: PublicationLifecycleClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        accountLeaseProvider: @escaping () -> AccountLease? = {
            AccountLeaseRuntime.shared.capture(forSubjectId: UserManager.shared.currentUser?.id)
        }
    ) {
        useCase = PublicationManagementReadUseCase(
            client: client,
            accountLeaseRuntime: accountLeaseRuntime
        )
        versionAuditUseCase = PublicationVersionAuditUseCase(
            client: versionClient
                ?? (client as? PublicationVersionAuditReaderClient)
                ?? DreamJourneyBackendClient.shared,
            accountLeaseRuntime: accountLeaseRuntime
        )
        lifecycleUseCase = PublicationLifecycleUseCase(
            client: lifecycleClient,
            accountLeaseRuntime: accountLeaseRuntime
        )
        self.publicationClient = publicationClient
        self.accountLeaseRuntime = accountLeaseRuntime
        self.accountLeaseProvider = accountLeaseProvider
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "发布管理"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-publication-management-qa-shell"
        configureScrollView()
        render(.idle)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: DJDesignTokens.Color.textPrimary,
            .font: DJDesignTokens.Font.title(18),
        ]
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            // The server response is intentionally page-memory-only.
            loadState = .idle
            lifecycleReceipts.removeAll()
            lifecycleFailures.removeAll()
            lifecyclePendingPublicationIDs.removeAll()
            pendingWithdrawalConfirmation = nil
            versionAudits.removeAll()
            versionAuditFailures.removeAll()
            versionAuditPendingPublicationIDs.removeAll()
        }
    }

    private func configureScrollView() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 36,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func reload() {
        guard PublicationManagementM2AccessGate.isManagementRouteAllowed else {
            render(.failed(PublicationManagementAccessError.disabled.localizedDescription))
            return
        }
        guard let accountLease = accountLeaseProvider() else {
            render(.failed(PublicationManagementAccessError.accountLeaseInvalid.localizedDescription))
            return
        }

        render(.loading)
        useCase.load(accountLease: accountLease) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let snapshot):
                if snapshot.publications.isEmpty, snapshot.grants.isEmpty {
                    self.render(.empty)
                } else {
                    self.render(.loaded(snapshot))
                }
            case .failure(let error):
                self.render(.failed(self.displayMessage(for: error)))
            }
        }
    }

    private func displayMessage(for error: Error) -> String {
        if let accessError = error as? PublicationManagementAccessError {
            return accessError.localizedDescription
        }
        return "发布管理暂时不可用"
    }

    private func displayLifecycleMessage(for error: Error) -> String {
        if let accessError = error as? PublicationLifecycleAccessError {
            return accessError.localizedDescription
        }
        return "发布撤回暂时不可用"
    }

    private func render(_ state: LoadState) {
        loadState = state
        contentStack.arrangedSubviews.forEach { subview in
            contentStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        contentStack.addArrangedSubview(makeHeader())

        switch state {
        case .idle, .loading:
            contentStack.addArrangedSubview(makeStatusCard(
                title: "正在读取发布状态",
                message: "",
                style: .neutral,
                showsSpinner: true
            ))
        case .empty:
            contentStack.addArrangedSubview(makeStatusCard(
                title: "暂时没有可管理的发布内容",
                message: "发布与授权状态会在这里集中显示。",
                style: .neutral
            ))
        case .failed(let message):
            contentStack.addArrangedSubview(makeStatusCard(
                title: "发布管理读取失败",
                message: message,
                style: .failure,
                showsRetry: true
            ))
        case .loaded(let snapshot):
            contentStack.addArrangedSubview(makePublicationSection(snapshot.publications))
            contentStack.addArrangedSubview(makeGrantSection(snapshot.grants))
        }
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6

        let titleLabel = makeLabel(
            text: "发布管理",
            font: DJDesignTokens.Font.title(24),
            color: DJDesignTokens.Color.textPrimary
        )
        titleLabel.accessibilityIdentifier = "profile-publication-management-qa-title"
        let subtitleLabel = makeLabel(
            text: "查看已确认的公开预览与授权状态。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makePublicationSection(_ publications: [PublicationManagementPublication]) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-management-qa-publications"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.addArrangedSubview(makeSectionTitle("已确认发布"))

        if publications.isEmpty {
            stack.addArrangedSubview(makeEmptyLabel("暂时没有已确认的发布内容。"))
        } else {
            for publication in publications {
                stack.addArrangedSubview(makePublicationRow(publication))
            }
        }

        pin(stack, to: card)
        return card
    }

    private func makeGrantSection(_ grants: [PublicationManagementGrant]) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-management-qa-grants"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.addArrangedSubview(makeSectionTitle("授权状态"))

        if grants.isEmpty {
            stack.addArrangedSubview(makeEmptyLabel("暂时没有生效中的授权记录。"))
        } else {
            for grant in grants {
                stack.addArrangedSubview(makeGrantRow(grant))
            }
        }

        pin(stack, to: card)
        return card
    }

    private func makePublicationRow(_ publication: PublicationManagementPublication) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 7
        stack.accessibilityIdentifier = "profile-publication-management-qa-publication-row"

        stack.addArrangedSubview(makeLabel(
            text: publication.previewTitle,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        ))
        stack.addArrangedSubview(makeLabel(
            text: publication.previewBody,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        ))

        let states = [
            "发布：\(displayState(publication.publicationState))",
            "预览：\(displayState(publication.projectionState ?? "unknown"))",
        ]
        stack.addArrangedSubview(makePillRow(states))

        if publication.requiresSecondConfirmation || publication.thirdPartyReviewRequired || publication.aiDisclosureRequired {
            let disclosures = [
                publication.requiresSecondConfirmation ? "需二次确认" : nil,
                publication.thirdPartyReviewRequired ? "需第三方复核" : nil,
                publication.aiDisclosureRequired ? "含 AI 说明" : nil,
            ].compactMap { $0 }
            stack.addArrangedSubview(makePillRow(disclosures))
        }

        if PublicationManagementM2AccessGate.isPublicationRouteAllowed {
            stack.addArrangedSubview(makeVersionAuditControl(for: publication))
        }
        if let audit = versionAudits[publication.publicationID] {
            stack.addArrangedSubview(makeVersionAudit(audit))
        }
        if let message = versionAuditFailures[publication.publicationID] {
            let label = makeLabel(
                text: message,
                font: DJDesignTokens.Font.body(13),
                color: DJDesignTokens.Color.danger
            )
            label.accessibilityIdentifier = "profile-publication-management-version-failure"
            stack.addArrangedSubview(label)
        }

        if PublicationWithdrawalPresentationPolicy.isAvailable(
            for: publication,
            routeAllowed: PublicationManagementM2AccessGate.isLifecycleRouteAllowed
        ) {
            stack.addArrangedSubview(makeWithdrawalControl(for: publication))
        }
        if let receipt = lifecycleReceipts[publication.publicationID] {
            stack.addArrangedSubview(makeLifecycleReceipt(receipt))
        }
        if let message = lifecycleFailures[publication.publicationID] {
            let label = makeLabel(
                text: message,
                font: DJDesignTokens.Font.body(13),
                color: DJDesignTokens.Color.danger
            )
            label.accessibilityIdentifier = "profile-publication-management-qa-withdraw-failure"
            stack.addArrangedSubview(label)
        }
        return stack
    }

    private func makeVersionAuditControl(for publication: PublicationManagementPublication) -> UIView {
        let button = UIButton(type: .system)
        let isPending = versionAuditPendingPublicationIDs.contains(publication.publicationID)
        let isExpanded = versionAudits[publication.publicationID] != nil
        button.setTitle(
            isPending ? "正在读取版本记录" : (isExpanded ? "收起版本记录" : "查看版本记录"),
            for: .normal
        )
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.contentHorizontalAlignment = .leading
        button.isEnabled = !isPending
        button.accessibilityIdentifier = "profile-publication-management-version-audit"
        button.addAction(UIAction { [weak self] _ in
            self?.toggleVersionAudit(for: publication)
        }, for: .touchUpInside)
        return button
    }

    private func makeVersionAudit(_ audit: PublicationOwnerVersionAudit) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.accessibilityIdentifier = "profile-publication-management-version-list"

        if audit.versions.isEmpty {
            stack.addArrangedSubview(makeEmptyLabel("尚未生成已确认版本。"))
            return stack
        }

        if let currentVersion = audit.versions.first(where: {
            $0.isCurrent && $0.projectionState == "active"
        }) {
            stack.addArrangedSubview(makeRevisionControl(
                audit: audit,
                currentVersion: currentVersion
            ))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        for (index, version) in audit.versions.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.45)
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
            let heading = version.isCurrent
                ? "版本 \(version.versionNumber) · 当前版本"
                : "版本 \(version.versionNumber)"
            stack.addArrangedSubview(makeLabel(
                text: heading,
                font: DJDesignTokens.Font.label(15),
                color: DJDesignTokens.Color.textPrimary
            ))
            stack.addArrangedSubview(makeLabel(
                text: "确认于 \(formatter.string(from: version.confirmedAt)) · \(displayState(version.projectionState ?? "unknown"))",
                font: DJDesignTokens.Font.body(12),
                color: DJDesignTokens.Color.textSecondary
            ))
            for item in version.items {
                stack.addArrangedSubview(makeLabel(
                    text: item.publicTitle,
                    font: DJDesignTokens.Font.label(14),
                    color: DJDesignTokens.Color.textPrimary
                ))
                stack.addArrangedSubview(makeLabel(
                    text: item.publicBody,
                    font: DJDesignTokens.Font.body(13),
                    color: DJDesignTokens.Color.textSecondary
                ))
            }
        }
        return stack
    }

    private func makeRevisionControl(
        audit: PublicationOwnerVersionAudit,
        currentVersion: PublicationOwnerVersion
    ) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("基于当前版本创建新版本", for: .normal)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "profile-publication-management-create-revision"
        button.accessibilityValue = "version-\(currentVersion.versionNumber)"
        button.addAction(UIAction { [weak self] _ in
            self?.openRevisionComposer(audit: audit, currentVersion: currentVersion)
        }, for: .touchUpInside)
        return button
    }

    private func openRevisionComposer(
        audit: PublicationOwnerVersionAudit,
        currentVersion: PublicationOwnerVersion
    ) {
        guard let accountLease = accountLeaseProvider(),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            versionAuditFailures[audit.publicationID] = "当前账户状态已变更"
            if case let .loaded(snapshot) = loadState {
                render(.loaded(snapshot))
            }
            return
        }
        do {
            let composer = try OwnerPublicationDraftComposerViewController(
                accountLease: accountLease,
                publicationID: audit.publicationID,
                baseVersion: currentVersion,
                client: publicationClient,
                accountLeaseRuntime: accountLeaseRuntime
            )
            composer.onPublicationConfirmed = { [weak self] _ in
                guard let self else { return }
                self.versionAudits.removeValue(forKey: audit.publicationID)
                self.versionAuditFailures.removeValue(forKey: audit.publicationID)
                self.reload()
                self.navigationController?.popToViewController(self, animated: true)
            }
            navigationController?.pushViewController(composer, animated: true)
        } catch {
            versionAuditFailures[audit.publicationID] = error.localizedDescription
            if case let .loaded(snapshot) = loadState {
                render(.loaded(snapshot))
            }
        }
    }

    private func toggleVersionAudit(for publication: PublicationManagementPublication) {
        if versionAudits.removeValue(forKey: publication.publicationID) != nil {
            if case let .loaded(snapshot) = loadState {
                render(.loaded(snapshot))
            }
            return
        }
        guard !versionAuditPendingPublicationIDs.contains(publication.publicationID),
              let accountLease = accountLeaseProvider() else {
            return
        }
        versionAuditFailures.removeValue(forKey: publication.publicationID)
        versionAuditPendingPublicationIDs.insert(publication.publicationID)
        if case let .loaded(snapshot) = loadState {
            render(.loaded(snapshot))
        }
        versionAuditUseCase.load(
            publicationID: publication.publicationID,
            accountLease: accountLease
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.versionAuditPendingPublicationIDs.remove(publication.publicationID)
                switch result {
                case .success(let audit):
                    self.versionAudits[publication.publicationID] = audit
                case .failure(let error):
                    self.versionAuditFailures[publication.publicationID] = self.displayMessage(for: error)
                }
                if case let .loaded(snapshot) = self.loadState {
                    self.render(.loaded(snapshot))
                }
            }
        }
    }

    private func makeWithdrawalControl(for publication: PublicationManagementPublication) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6

        stack.addArrangedSubview(makeLabel(
            text: "撤回会立即阻断现有受邀访问；外部索引与运行时清理仍由服务端后续处理。",
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textSecondary
        ))

        let button = UIButton(type: .system)
        let isPending = lifecyclePendingPublicationIDs.contains(publication.publicationID)
        button.setTitle(isPending ? "正在撤回" : "撤回公开预览", for: .normal)
        button.setTitleColor(DJDesignTokens.Color.danger, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.contentHorizontalAlignment = .leading
        button.isEnabled = !isPending
        button.accessibilityIdentifier = "profile-publication-management-qa-withdraw"
        button.addAction(UIAction { [weak self] _ in
            self?.requestWithdrawalConfirmation(publication)
        }, for: .touchUpInside)
        stack.addArrangedSubview(button)
        return stack
    }

    private func requestWithdrawalConfirmation(_ publication: PublicationManagementPublication) {
        guard PublicationWithdrawalPresentationPolicy.isAvailable(
            for: publication,
            routeAllowed: PublicationManagementM2AccessGate.isLifecycleRouteAllowed
        ), !lifecyclePendingPublicationIDs.contains(publication.publicationID),
           let accountLease = accountLeaseProvider() else {
            return
        }

        pendingWithdrawalConfirmation = PendingWithdrawalConfirmation(
            publication: publication,
            accountLease: accountLease
        )

        let alert = UIAlertController(
            title: "确认撤回公开内容？",
            message: "撤回后，现有受邀访问会立即停止。公开索引会继续清理，但已经保存、截图或转发的外部副本无法收回。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.pendingWithdrawalConfirmation = nil
        })
        alert.addAction(UIAlertAction(title: "确认撤回", style: .destructive) { [weak self] _ in
            self?.completePendingWithdrawalConfirmation()
        })
        present(alert, animated: true)
    }

    private func completePendingWithdrawalConfirmation() {
        guard let pendingWithdrawalConfirmation else { return }
        self.pendingWithdrawalConfirmation = nil
        withdrawConfirmed(
            pendingWithdrawalConfirmation.publication,
            accountLease: pendingWithdrawalConfirmation.accountLease
        )
    }

    func confirmPendingWithdrawalForUIQA() {
        guard PublicationLifecycleM2QAGate.isEnabled,
              pendingWithdrawalConfirmation != nil else {
            return
        }
        presentedViewController?.dismiss(animated: false)
        completePendingWithdrawalConfirmation()
    }

    private func makeLifecycleReceipt(_ receipt: PublicationLifecycleReceipt) -> UIView {
        let label = makeLabel(
            text: "已撤回：访问阻断已完成；公开索引清理待处理。",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )
        label.accessibilityIdentifier = "profile-publication-management-qa-withdraw-receipt"
        label.accessibilityValue = receipt.receiptID
        return label
    }

    private func withdrawConfirmed(
        _ publication: PublicationManagementPublication,
        accountLease: AccountLease
    ) {
        guard PublicationWithdrawalPresentationPolicy.isAvailable(
            for: publication,
            routeAllowed: PublicationManagementM2AccessGate.isLifecycleRouteAllowed
        ), !lifecyclePendingPublicationIDs.contains(publication.publicationID) else {
            return
        }

        lifecycleFailures.removeValue(forKey: publication.publicationID)
        lifecyclePendingPublicationIDs.insert(publication.publicationID)
        if case let .loaded(snapshot) = loadState {
            render(.loaded(snapshot))
        }

        lifecycleUseCase.withdraw(publication: publication, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lifecyclePendingPublicationIDs.remove(publication.publicationID)
                switch result {
                case .success(let receipt):
                    self.lifecycleReceipts[publication.publicationID] = receipt
                    self.reload()
                case .failure(let error):
                    self.lifecycleFailures[publication.publicationID] = self.displayLifecycleMessage(for: error)
                    if case let .loaded(snapshot) = self.loadState {
                        self.render(.loaded(snapshot))
                    }
                }
            }
        }
    }

    private func makeGrantRow(_ grant: PublicationManagementGrant) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 7
        stack.accessibilityIdentifier = "profile-publication-management-qa-grant-row"
        stack.accessibilityValue = "\(grant.state):\(grant.useRemaining)"

        let state = grant.isUsable ? "有效" : displayState(grant.state)
        stack.addArrangedSubview(makeLabel(
            text: "授权状态：\(state)",
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        ))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        stack.addArrangedSubview(makeLabel(
            text: "到期：\(dateFormatter.string(from: grant.expiresAt)) · 剩余 \(grant.useRemaining) 次",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        ))
        return stack
    }

    private enum StatusStyle: Equatable {
        case neutral
        case failure
    }

    private func makeStatusCard(
        title: String,
        message: String,
        style: StatusStyle,
        showsSpinner: Bool = false,
        showsRetry: Bool = false
    ) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-management-qa-status"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let color = style == .failure ? DJDesignTokens.Color.danger : DJDesignTokens.Color.textPrimary
        stack.addArrangedSubview(makeLabel(
            text: title,
            font: DJDesignTokens.Font.title(17),
            color: color
        ))
        if !message.isEmpty {
            stack.addArrangedSubview(makeLabel(
                text: message,
                font: DJDesignTokens.Font.body(14),
                color: DJDesignTokens.Color.textSecondary
            ))
        }
        if showsSpinner {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = DJDesignTokens.Color.accentDeep
            spinner.startAnimating()
            spinner.accessibilityIdentifier = "profile-publication-management-qa-loading"
            stack.addArrangedSubview(spinner)
        }
        if showsRetry {
            let retryButton = UIButton(type: .system)
            retryButton.setTitle("重新读取", for: .normal)
            retryButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
            retryButton.titleLabel?.font = DJDesignTokens.Font.label(15)
            retryButton.contentHorizontalAlignment = .leading
            retryButton.accessibilityIdentifier = "profile-publication-management-qa-retry"
            retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
            stack.addArrangedSubview(retryButton)
        }

        pin(stack, to: card)
        return card
    }

    @objc private func retryTapped() {
        reload()
    }

    private func makeCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        return card
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        makeLabel(text: text, font: DJDesignTokens.Font.title(18), color: DJDesignTokens.Color.textPrimary)
    }

    private func makeEmptyLabel(_ text: String) -> UILabel {
        makeLabel(text: text, font: DJDesignTokens.Font.body(14), color: DJDesignTokens.Color.textSecondary)
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makePillRow(_ titles: [String]) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .leading
        stack.spacing = 7
        stack.distribution = .fillProportionally
        for title in titles {
            let label = PublicationManagementPillLabel(
                insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            )
            label.text = title
            label.font = DJDesignTokens.Font.label(12)
            label.textColor = DJDesignTokens.Color.textSecondary
            label.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.55)
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            stack.addArrangedSubview(label)
        }
        return stack
    }

    private func pin(_ stack: UIStackView, to card: UIView) {
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
    }

    private func displayState(_ rawValue: String) -> String {
        switch rawValue {
        case "confirmed", "active":
            return "已生效"
        case "draft":
            return "草稿"
        case "revoked":
            return "已撤回"
        case "withdrawn":
            return "已撤回"
        case "suspended":
            return "已冻结"
        case "expired":
            return "已过期"
        default:
            return "未知状态"
        }
    }
}

private final class PublicationManagementPillLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
