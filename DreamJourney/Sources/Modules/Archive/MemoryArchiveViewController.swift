import UIKit

private enum ArchiveLayout {
    static let contentTopMargin: CGFloat = 8
    static let contentBottomMargin: CGFloat = 32
    static let contentStackSpacing: CGFloat = 18
    static let headerStackSpacing: CGFloat = 6
    static let headerTitleFontSize: CGFloat = 32
    static let headerSubtitleFontSize: CGFloat = 14
    static let afterHeaderSpacing: CGFloat = 24
    static let afterFeatureGridSpacing: CGFloat = 8
    static let afterRemoteCaptionSpacing: CGFloat = 24
    static let afterListSpacing: CGFloat = 32
    static let bookEntryCornerRadius: CGFloat = 26
    static let materialsHeaderSpacing: CGFloat = 6
    static let featureGridHeight: CGFloat = 140
    static let featureGridGap: CGFloat = 16
    static let featureLargeIconSize: CGFloat = 38
    static let featureSmallIconSize: CGFloat = 32
    static let featureLargePadding: CGFloat = 18
    static let featureSmallPadding: CGFloat = 14
    static let featureTileStackSpacing: CGFloat = 12
    static let primaryCTAHeight: CGFloat = 120
    static let primaryCTAIconSize: CGFloat = 56
    static let primaryCTAIconSymbolSize: CGFloat = 26
    static let primaryCTAHorizontalSafety: CGFloat = 24
    static let primaryCTAStackSpacing: CGFloat = 10
    static let primaryCTATextSpacing: CGFloat = 4
    static let primaryCTATitleFontSize: CGFloat = 17
    static let primaryCTASubtitleFontSize: CGFloat = 13
    static let timelineItemSpacing: CGFloat = 18
    static let timelineCardRadius: CGFloat = DJDesignTokens.Radius.extraLarge
    static let timelineCardInset: CGFloat = 18
    static let timelineCardTextSpacing: CGFloat = 8
    static let timelineCardBodySpacing: CGFloat = 14
    static let timelineMediaHeight: CGFloat = 132
    static let timelineMediaScrimHeight: CGFloat = 72
    static let timelinePreviewWidth: CGFloat = 54
    static let timelinePreviewHeight: CGFloat = 64
    static let timelineAudioIconSize: CGFloat = 40
    static let timelineAudioPlayerHeight: CGFloat = 44
    static let timelineAudioPlayButtonSize: CGFloat = 28
    static let timelineAudioPlayIconSize: CGFloat = 12
    static let timelinePlayerTrackHeight: CGFloat = 4
    static let timelineBadgeSpacing: CGFloat = 6
    static let chapterHeaderSpacing: CGFloat = 10
    static let chapterPlaceholderHeight: CGFloat = 96
}

private enum ArchiveKindFilter {
    case photo
    case audio
    case text
    case timeLetter
    case video

    var kind: MemoryArchiveItemKind {
        switch self {
        case .photo:
            return .photo
        case .audio:
            return .audio
        case .text:
            return .text
        case .timeLetter:
            return .timeLetter
        case .video:
            return .video
        }
    }

    var title: String {
        switch self {
        case .photo:
            return "相册影像"
        case .audio:
            return "语音档案"
        case .text:
            return "文字记忆"
        case .timeLetter:
            return "时间信件"
        case .video:
            return "视频片段"
        }
    }

    var emptyTitle: String {
        switch self {
        case .photo:
            return "还没有相册影像"
        case .audio:
            return "还没有语音档案"
        case .text:
            return "还没有文字记忆"
        case .timeLetter:
            return "还没有时间信件"
        case .video:
            return "还没有视频片段"
        }
    }

    var emptyDetail: String {
        switch self {
        case .photo:
            return "点按封存新记忆，再选择照片。"
        case .audio:
            return "语音档案入口已就位，录音创建会在真机录音验收后开放。"
        case .text:
            return "点按封存新记忆，写下一段文字描述。"
        case .timeLetter:
            return "点按封存新记忆，选择时间信件，写给未来的自己或家人。"
        case .video:
            return "视频片段仍在确认压缩、缩略图和存储策略。"
        }
    }
}

private final class InAppMessageCenterViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case inbox
        case archived

        var title: String {
            switch self {
            case .inbox:
                return "收件箱"
            case .archived:
                return "已归档"
            }
        }
    }

    private let repository: MemoryArchiveRepository
    private let accountLease: AccountLease
    private let snapshotProvider: (AccountLease) -> InAppMessageCenterSnapshot?
    private var messages: [InAppMessage]
    private let onOpenMessage: (InAppMessage, AccountLease) -> Void
    private let onShowAllTimeLetters: (AccountLease) -> Void
    private let onMessageStateChanged: (AccountLease) -> Void

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private lazy var archiveReadButton = UIBarButtonItem(
        title: "归档已读",
        style: .plain,
        target: self,
        action: #selector(archiveReadRemindersTapped)
    )

    init(
        snapshot: InAppMessageCenterSnapshot,
        repository: MemoryArchiveRepository,
        accountLease: AccountLease,
        snapshotProvider: @escaping (AccountLease) -> InAppMessageCenterSnapshot?,
        onOpenMessage: @escaping (InAppMessage, AccountLease) -> Void,
        onShowAllTimeLetters: @escaping (AccountLease) -> Void,
        onMessageStateChanged: @escaping (AccountLease) -> Void
    ) {
        self.repository = repository
        self.accountLease = accountLease
        self.snapshotProvider = snapshotProvider
        self.messages = snapshot.messages
        self.onOpenMessage = onOpenMessage
        self.onShowAllTimeLetters = onShowAllTimeLetters
        self.onMessageStateChanged = onMessageStateChanged
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息中心"
        view.backgroundColor = DJDesignTokens.Color.background
        let allLettersButton = UIBarButtonItem(
            title: "全部信件",
            style: .plain,
            target: self,
            action: #selector(showAllTimeLettersTapped)
        )
        navigationItem.rightBarButtonItems = [allLettersButton, archiveReadButton]
        configureHeader()
        configureTableView()
        updateEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: DJDesignTokens.Color.textPrimary,
            .font: DJDesignTokens.Font.title(18),
        ]
        refreshMessagesFromRepository()
    }

    private func configureHeader() {
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 6
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 18,
            leading: DJDesignTokens.Spacing.page,
            bottom: 14,
            trailing: DJDesignTokens.Spacing.page
        )

        titleLabel.text = "全部消息"
        titleLabel.font = DJDesignTokens.Font.title(24)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(InAppMessageCell.self, forCellReuseIdentifier: InAppMessageCell.reuseIdentifier)
        tableView.accessibilityIdentifier = "in-app-message-center-list"

        emptyStateLabel.text = "还没有新的应用内提醒"
        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0

        view.addSubview(headerStack)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)

        headerStack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -24),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
        ])
    }

    @discardableResult
    private func refreshMessagesFromRepository() -> Bool {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed,
              let snapshot = snapshotProvider(accountLease),
              AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            failClosedForStaleAccountLease()
            return false
        }
        messages = snapshot.messages
        tableView.reloadData()
        updateEmptyState()
        return true
    }

    private func failClosedForStaleAccountLease() {
        messages = []
        tableView.reloadData()
        updateEmptyState()
        subtitleLabel.text = "账号状态已变化，请重新打开消息中心。"
        emptyStateLabel.text = "当前消息已停止显示"
    }

    private func updateEmptyState() {
        emptyStateLabel.text = "还没有新的应用内提醒"
        let inboxCount = messages.filter { !$0.isArchived }.count
        let unreadCount = messages.filter { !$0.isArchived && $0.isUnread }.count
        subtitleLabel.text = unreadCount > 0
            ? "\(unreadCount) 条未读，点按消息查看详情。"
            : "所有消息都已读，可归档收起。"
        emptyStateLabel.isHidden = !messages.isEmpty
        tableView.isHidden = messages.isEmpty
        archiveReadButton.isEnabled = inboxCount > unreadCount
    }

    @objc private func showAllTimeLettersTapped() {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            failClosedForStaleAccountLease()
            showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        onShowAllTimeLetters(accountLease)
    }

    @objc private func archiveReadRemindersTapped() {
        let readMessages = messages.filter { !$0.isArchived && !$0.isUnread }
        guard !readMessages.isEmpty else {
            showToast("暂无已读消息可归档", type: .info)
            return
        }
        readMessages.forEach { archiveMessage($0) }
    }

    private func messages(in section: Section) -> [InAppMessage] {
        switch section {
        case .inbox:
            return messages.filter { !$0.isArchived }
        case .archived:
            return messages.filter(\.isArchived)
        }
    }

    private func message(at indexPath: IndexPath) -> InAppMessage {
        let section = Section(rawValue: indexPath.section) ?? .inbox
        return messages(in: section)[indexPath.row]
    }

    private func archiveMessage(
        _ message: InAppMessage,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            failClosedForStaleAccountLease()
            showToast("账号已切换，请重新打开消息中心", type: .info)
            completion?(false)
            return
        }
        repository.archiveInAppMessage(message, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion?(false)
                    return
                }
                guard AccountLeaseRuntime.shared.validate(self.accountLease, at: .ui).allowed else {
                    self.failClosedForStaleAccountLease()
                    completion?(false)
                    return
                }
                switch result {
                case .success:
                    guard self.refreshMessagesFromRepository() else {
                        completion?(false)
                        return
                    }
                    self.onMessageStateChanged(self.accountLease)
                    completion?(true)
                case .failure:
                    self.showToast("归档失败，请稍后重试", type: .info)
                    completion?(false)
                }
            }
        }
    }

    private func markMessageReadAndOpen(_ message: InAppMessage) {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            failClosedForStaleAccountLease()
            showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        guard message.isUnread else {
            onOpenMessage(message, accountLease)
            return
        }

        repository.markInAppMessageRead(message, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard AccountLeaseRuntime.shared.validate(self.accountLease, at: .ui).allowed else {
                    self.failClosedForStaleAccountLease()
                    return
                }
                switch result {
                case .success(let updated):
                    guard self.refreshMessagesFromRepository() else { return }
                    self.onMessageStateChanged(self.accountLease)
                    self.onOpenMessage(updated, self.accountLease)
                case .failure:
                    self.showToast("标记已读失败，请稍后重试", type: .info)
                }
            }
        }
    }
}

extension InAppMessageCenterViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages(in: Section(rawValue: section) ?? .inbox).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: InAppMessageCell.reuseIdentifier,
            for: indexPath
        ) as? InAppMessageCell ?? InAppMessageCell(style: .default, reuseIdentifier: InAppMessageCell.reuseIdentifier)
        cell.configure(with: message(at: indexPath))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            failClosedForStaleAccountLease()
            showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        let message = message(at: indexPath)
        markMessageReadAndOpen(message)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = Section(rawValue: section) ?? .inbox
        return messages(in: section).isEmpty ? nil : section.title
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let message = message(at: indexPath)
        guard !message.isArchived else {
            return nil
        }
        let archiveAction = UIContextualAction(style: .normal, title: "归档") { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            self.archiveMessage(message, completion: completion)
        }
        archiveAction.backgroundColor = DJDesignTokens.Color.textTertiary
        archiveAction.image = UIImage(systemName: "archivebox")
        return UISwipeActionsConfiguration(actions: [archiveAction])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        92
    }
}

private final class InAppMessageCell: UITableViewCell {
    static let reuseIdentifier = "InAppMessageCell"

    private let cardView = UIView()
    private let statusLabel = PaddingLabel(horizontalInset: 8, verticalInset: 4)
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let chevronImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: InAppMessage) {
        titleLabel.text = message.title
        metaLabel.text = [
            message.kindLabel,
            message.summary,
            Self.formattedDeliveredAt(message.deliveredAt),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        statusLabel.text = message.isUnread ? "未读" : "已读"
        if message.isArchived {
            statusLabel.text = "已归档"
        }
        statusLabel.backgroundColor = message.isUnread
            ? DJDesignTokens.Color.accent.withAlphaComponent(0.18)
            : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.8)
        statusLabel.textColor = message.isUnread
            ? DJDesignTokens.Color.accentDeep
            : DJDesignTokens.Color.textTertiary
        titleLabel.textColor = message.isUnread
            ? DJDesignTokens.Color.textPrimary
            : DJDesignTokens.Color.textSecondary
        accessibilityIdentifier = "in-app-message-row-\(message.kind.rawValue)-\(message.id)"
    }

    private func configure() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = DJDesignTokens.Color.surface
        cardView.layer.cornerRadius = DJDesignTokens.Radius.large
        cardView.layer.borderWidth = 0.6
        cardView.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42).cgColor
        DJDesignTokens.applySoftShadow(to: cardView)

        titleLabel.font = DJDesignTokens.Font.title(17)
        titleLabel.numberOfLines = 2

        metaLabel.font = DJDesignTokens.Font.body(13)
        metaLabel.textColor = DJDesignTokens.Color.textTertiary
        metaLabel.numberOfLines = 1

        statusLabel.font = DJDesignTokens.Font.label(12)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.masksToBounds = true

        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.55)
        chevronImageView.contentMode = .scaleAspectFit

        contentView.addSubview(cardView)
        [statusLabel, titleLabel, metaLabel, chevronImageView].forEach {
            cardView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            statusLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            titleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private static func formattedDeliveredAt(_ rawValue: String) -> String {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let date = ISO8601DateFormatter().date(from: rawValue) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

final class MemoryArchiveViewController: UIViewController {
    private let repository: MemoryArchiveRepository
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let mediaStore = ArchiveMediaStore.shared
    private lazy var delayedReplyInboxAnswerReader = EchoDelayedReplyInboxAnswerReader(
        client: DreamJourneyBackendClient.shared,
        accountLeaseRuntime: accountLeaseRuntime
    )

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()
    private let featureCardsStack = UIStackView()
    private let listStack = UIStackView()
    private let archiveFilterButton = UIButton(type: .system)

    private weak var headerTitleLabel: UILabel?
    private weak var headerSubtitleLabel: UILabel?
    private weak var bookEntryControl: UIControl?
    private weak var bookEntryTitleLabel: UILabel?
    private weak var primaryCTAControl: UIControl?
    private weak var primaryCTAEyebrowLabel: UILabel?
    private weak var primaryCTATitleLabel: UILabel?
    private weak var primaryCTASubtitleLabel: UILabel?
    private weak var materialsTitleLabel: UILabel?
    private weak var materialsSubtitleLabel: UILabel?

    private let summaryLabel = UILabel()
    private let progressLabel = UILabel()
    private let remoteSyncCaptionLabel = PaddingLabel(horizontalInset: 12, verticalInset: 8)
    private let analysisPrivacyDisclaimerLabel = PaddingLabel(horizontalInset: 12, verticalInset: 8)
    private let timeLetterReminderButton = UIButton(type: .system)
    private let candidateConfirmationButton = UIButton(type: .system)
    private let candidateMemoryActivationButton = UIButton(type: .system)
    private let candidateReviewQAButton = UIButton(type: .system)
    private var isRefreshingFromBackend = false
    private var isRefreshingTimeLetterMailbox = false
    private var activeKindFilter: ArchiveKindFilter?
    private var photoPickerAccountLease: AccountLease?
    private var photoPickerArchiveContext: DigitalHumanContext?

    private var creationOptions: [MemoryArchiveCreationOption] {
        guard isSelfAutobiographyMode else {
            return []
        }
        return MemoryArchiveCreationOption.availableOptions(
            isAudioUploadEnabled: false,
            isVideoUploadEnabled: false,
            isTimeLettersEnabled: false
        )
    }

    private var currentArchiveContext: DigitalHumanContext {
        DigitalHumanContextStore.shared.current
    }

    private var isSelfAutobiographyMode: Bool {
        currentArchiveContext.isSelfAssistant
    }

    private var archivePersonaName: String {
        currentArchiveContext.resolvedDisplayName
    }

    private var isArchiveAudioCreationEnabled: Bool {
        isArchiveCreationVisible(for: .audio)
    }

    private var isArchiveVideoCreationEnabled: Bool {
        isArchiveCreationVisible(for: .video)
    }

    private var isTimeLetterCreationEnabled: Bool {
        isArchiveCreationVisible(for: .timeLetter)
    }

    private var isPersonaSettingsVisible: Bool {
        FeatureGateService.shared.isRouteAllowed(
            .personaSettings,
            localEnabled: FeatureFlagService.shared.isEnabled(.personaSettings),
            qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
        )
    }

    private var isUIQAArchiveHiddenBranchesEnabled: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains(MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument)
        #else
        return false
        #endif
    }

    private func isArchiveCreationVisible(for kind: MemoryArchiveItemKind) -> Bool {
        MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: kind,
            isAudioUploadEnabled: FeatureGateService.shared.isRouteAllowed(
                .archiveAudioUpload,
                localEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
                qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
            ),
            isVideoUploadEnabled: FeatureGateService.shared.isRouteAllowed(
                .archiveVideoUpload,
                localEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
                qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
            ),
            isTimeLettersEnabled: FeatureGateService.shared.isRouteAllowed(
                .timeLetters,
                localEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
                qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
            ),
            isHiddenBranchesEnabled: isUIQAArchiveHiddenBranchesEnabled
        )
    }

    private static let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    private static let timelineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let warmTabBarFloatingBottomInset: CGFloat = 16
    private static let systemNoticeInboxOperationId = "compatibility-current-inbox"

    private static func archiveListBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat {
        DJDesignTokens.Spacing.tabBarHeight + warmTabBarFloatingBottomInset + safeAreaBottomInset + DJDesignTokens.Spacing.page
    }

    init(repository: MemoryArchiveRepository = .shared) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = nil
        view.backgroundColor = DJDesignTokens.Color.background
        observeDigitalHumanContext()
        setupLayout()
        refreshContent()
        loadRuntimeCapabilitySnapshots()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshContent()
        retryPendingPublicArchiveSyncIfNeeded()
        refreshRemoteArchiveIfNeeded()
        refreshTimeLetterMailboxRemindersIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateArchiveListScrollInsets()
    }

    private func setupLayout() {
        scrollView.backgroundColor = DJDesignTokens.Color.background
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .onDrag
        scrollView.showsVerticalScrollIndicator = false
        updateArchiveListScrollInsets()

        mainStack.axis = .vertical
        mainStack.spacing = ArchiveLayout.contentStackSpacing
        mainStack.layoutMargins = UIEdgeInsets(
            top: ArchiveLayout.contentTopMargin,
            left: DJDesignTokens.Spacing.page,
            bottom: ArchiveLayout.contentBottomMargin,
            right: DJDesignTokens.Spacing.page
        )
        mainStack.isLayoutMarginsRelativeArrangement = true

        featureCardsStack.axis = .vertical
        featureCardsStack.spacing = 0

        listStack.axis = .vertical
        listStack.spacing = ArchiveLayout.timelineItemSpacing

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)

        [scrollView, contentView, mainStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let header = makeHeader()
        configureAnalysisPrivacyDisclaimerLabel()
        configureRemoteSyncCaptionLabel()
        configureTimeLetterReminderButton()
        configureCandidateConfirmationButton()
        configureCandidateMemoryActivationButton()
        configureCandidateReviewQAButton()
        configureArchiveFilterButton()
        let bookEntry = makeBookEntryCard()
        let materialsHeader = makeMaterialsHeader()
        let primaryCTA = makePrimaryCTA()
        mainStack.addArrangedSubview(header)
        mainStack.addArrangedSubview(featureCardsStack)
        mainStack.addArrangedSubview(analysisPrivacyDisclaimerLabel)
        mainStack.addArrangedSubview(remoteSyncCaptionLabel)
        mainStack.addArrangedSubview(timeLetterReminderButton)
        mainStack.addArrangedSubview(candidateConfirmationButton)
        mainStack.addArrangedSubview(candidateMemoryActivationButton)
        mainStack.addArrangedSubview(candidateReviewQAButton)
        mainStack.addArrangedSubview(bookEntry)
        mainStack.addArrangedSubview(materialsHeader)
        mainStack.addArrangedSubview(primaryCTA)
        mainStack.addArrangedSubview(archiveFilterButton)
        mainStack.addArrangedSubview(listStack)
        mainStack.setCustomSpacing(ArchiveLayout.afterHeaderSpacing, after: header)
        mainStack.setCustomSpacing(ArchiveLayout.afterFeatureGridSpacing, after: featureCardsStack)
        mainStack.setCustomSpacing(ArchiveLayout.afterFeatureGridSpacing, after: analysisPrivacyDisclaimerLabel)
        mainStack.setCustomSpacing(8, after: remoteSyncCaptionLabel)
        mainStack.setCustomSpacing(ArchiveLayout.afterRemoteCaptionSpacing, after: timeLetterReminderButton)
        mainStack.setCustomSpacing(ArchiveLayout.afterRemoteCaptionSpacing, after: candidateConfirmationButton)
        mainStack.setCustomSpacing(ArchiveLayout.afterRemoteCaptionSpacing, after: candidateMemoryActivationButton)
        mainStack.setCustomSpacing(ArchiveLayout.afterRemoteCaptionSpacing, after: candidateReviewQAButton)
        mainStack.setCustomSpacing(22, after: bookEntry)
        mainStack.setCustomSpacing(10, after: materialsHeader)
        mainStack.setCustomSpacing(18, after: primaryCTA)
        mainStack.setCustomSpacing(8, after: archiveFilterButton)
        mainStack.setCustomSpacing(ArchiveLayout.afterListSpacing, after: listStack)
    }

    private func updateArchiveListScrollInsets() {
        let bottomInset = Self.archiveListBottomInset(safeAreaBottomInset: view.safeAreaInsets.bottom)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func observeDigitalHumanContext() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(digitalHumanContextDidChange),
            name: .djDigitalHumanContextDidChange,
            object: nil
        )
    }

    @objc private func digitalHumanContextDidChange() {
        activeKindFilter = nil
        refreshContent()
        retryPendingPublicArchiveSyncIfNeeded()
        refreshRemoteArchiveIfNeeded()
        refreshTimeLetterMailboxRemindersIfNeeded()
    }

    private func refreshContent() {
        let summary = repository.summary()
        let archiveLabel = isSelfAutobiographyMode ? "我的自传" : "\(archivePersonaName)的故事"
        summaryLabel.text = "\(archiveLabel) · \(summary.total) 段片段 · 图片 \(summary.photos) · 文字 \(summary.text)"
        progressLabel.text = isSelfAutobiographyMode
            ? "你主动上传的图片和文字会沉淀为个人数据库，后续由 AI 助手陪你继续补全。"
            : "当前正在阅读家人档案，内容仅用于回响上下文，不在此处编辑或新增。"

        updateAutobiographyPageCopy()
        reloadFeatureCards(summary: summary)
        updateTimeLetterReminderButton()
        updateCandidateConfirmationButton()
        updateCandidateMemoryActivationButton()
        updateCandidateReviewQAButton()
        updateArchiveFilterButton()
        reloadArchiveList()
    }

    private func loadRuntimeCapabilitySnapshots() {
        DreamJourneyBackendClient.shared.fetchRuntimeConfig { [weak self] result in
            guard case .success = result else { return }
            DispatchQueue.main.async {
                self?.refreshContent()
            }
        }
    }

    private func updateAutobiographyPageCopy() {
        let isSelfMode = isSelfAutobiographyMode
        let bookTitle = isSelfMode ? "我的自传" : "\(archivePersonaName)的故事"
        view.backgroundColor = DJDesignTokens.Color.background
        scrollView.backgroundColor = DJDesignTokens.Color.background

        headerTitleLabel?.text = "记忆档案"
        headerSubtitleLabel?.text = isSelfMode
            ? "上方进入完整自传，下方管理你记录的记忆素材。"
            : "上方翻阅 \(archivePersonaName) 的故事，下方查看已沉淀的素材。"

        bookEntryTitleLabel?.text = bookTitle
        bookEntryControl?.accessibilityLabel = "\(bookTitle)，点击翻开书本"

        materialsTitleLabel?.text = isSelfMode ? "我记录的记忆" : "\(archivePersonaName)的记忆素材"
        materialsSubtitleLabel?.text = isSelfMode
            ? "这些素材会成为自传里的正文、照片和声音线索。"
            : "家人档案当前只读，可点开素材查看详情。"

        primaryCTAEyebrowLabel?.text = "添加"
        primaryCTATitleLabel?.text = "记录新的记忆素材"
        primaryCTASubtitleLabel?.text = isSelfMode
            ? "上传图片或写一段文字，成为自传的下一页"
            : "当前切换为家人，只可阅读已有档案"
        primaryCTAControl?.isEnabled = isSelfMode
        primaryCTAControl?.isHidden = !isSelfMode
        primaryCTAControl?.alpha = isSelfMode ? 1 : 0
        primaryCTAControl?.accessibilityTraits = isSelfMode ? .button : .staticText
        primaryCTAControl?.accessibilityLabel = isSelfMode
            ? "记录新的记忆素材，添加文字或图片"
            : "ta的故事，只读"
    }

    private func refreshRemoteArchiveIfNeeded() {
        guard FeatureGateService.shared.isRouteAllowed(
                .archiveRemoteFetch,
                risk: .providerEffect,
                localEnabled: FeatureFlagService.shared.isEnabled(.archiveRemoteFetch),
                qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
              ),
              DreamJourneyBackendClient.shared.isArchiveSyncConfigured,
              !isRefreshingFromBackend else {
            return
        }

        isRefreshingFromBackend = true
        repository.syncPendingPublicArchiveItemsToBackend()
        setArchiveRemoteSyncStatus(.syncing)
        repository.refreshFromBackend { [weak self] result in
            guard let self else { return }
            isRefreshingFromBackend = false
            switch result {
            case .success:
                refreshContent()
                setArchiveRemoteSyncStatus(.synced)
            case .failure:
                setArchiveRemoteSyncStatus(.fallback)
            }
        }
    }

    private func refreshTimeLetterMailboxRemindersIfNeeded() {
        guard isSelfAutobiographyMode,
              isTimeLetterCreationEnabled,
              DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured,
              !isRefreshingTimeLetterMailbox else {
            return
        }

        isRefreshingTimeLetterMailbox = true
        repository.refreshTimeLetterMailboxReminders { [weak self] _ in
            guard let self else { return }
            isRefreshingTimeLetterMailbox = false
            refreshContent()
        }
    }

    private func retryPendingPublicArchiveSyncIfNeeded() {
        repository.syncPendingPublicArchiveItemsToBackend()
    }

    private func configureAnalysisPrivacyDisclaimerLabel() {
        analysisPrivacyDisclaimerLabel.text = "基于照片说明和本地规则整理；后端仅同步元数据，我们不会人为查看你的记忆内容。"
        analysisPrivacyDisclaimerLabel.font = DJDesignTokens.Font.label(12)
        analysisPrivacyDisclaimerLabel.textColor = DJDesignTokens.Color.textTertiary
        analysisPrivacyDisclaimerLabel.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.58)
        analysisPrivacyDisclaimerLabel.layer.cornerRadius = 14
        analysisPrivacyDisclaimerLabel.layer.masksToBounds = true
        analysisPrivacyDisclaimerLabel.numberOfLines = 0
        analysisPrivacyDisclaimerLabel.lineBreakMode = .byWordWrapping
        analysisPrivacyDisclaimerLabel.accessibilityIdentifier = "archive-analysis-privacy-disclaimer"
        analysisPrivacyDisclaimerLabel.accessibilityLabel = analysisPrivacyDisclaimerLabel.text
    }

    private func configureRemoteSyncCaptionLabel() {
        remoteSyncCaptionLabel.font = DJDesignTokens.Font.label(12)
        remoteSyncCaptionLabel.textColor = DJDesignTokens.Color.textSecondary
        remoteSyncCaptionLabel.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        remoteSyncCaptionLabel.layer.cornerRadius = 14
        remoteSyncCaptionLabel.layer.masksToBounds = true
        remoteSyncCaptionLabel.numberOfLines = 0
        remoteSyncCaptionLabel.accessibilityIdentifier = "archiveRemoteSyncStatus"
        remoteSyncCaptionLabel.isHidden = true
    }

    private func configureTimeLetterReminderButton() {
        timeLetterReminderButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        timeLetterReminderButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        timeLetterReminderButton.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.16)
        timeLetterReminderButton.layer.cornerRadius = 14
        timeLetterReminderButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        timeLetterReminderButton.contentHorizontalAlignment = .leading
        timeLetterReminderButton.accessibilityIdentifier = "archive-in-app-message-center"
        timeLetterReminderButton.isHidden = true
        timeLetterReminderButton.addTarget(self, action: #selector(timeLetterReminderTapped), for: .touchUpInside)
    }

    private func configureCandidateReviewQAButton() {
        candidateReviewQAButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        candidateReviewQAButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        candidateReviewQAButton.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        candidateReviewQAButton.layer.cornerRadius = 14
        candidateReviewQAButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        candidateReviewQAButton.contentHorizontalAlignment = .leading
        candidateReviewQAButton.accessibilityIdentifier = "archive-owner-truth-candidate-inbox-qa"
        candidateReviewQAButton.accessibilityLabel = "审核候选记忆，仅 QA"
        candidateReviewQAButton.isHidden = true
        candidateReviewQAButton.addTarget(
            self,
            action: #selector(ownerTruthCandidateReviewQATapped),
            for: .touchUpInside
        )
    }

    private func configureCandidateConfirmationButton() {
        candidateConfirmationButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        candidateConfirmationButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        candidateConfirmationButton.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        candidateConfirmationButton.layer.cornerRadius = 14
        candidateConfirmationButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        candidateConfirmationButton.contentHorizontalAlignment = .leading
        candidateConfirmationButton.accessibilityIdentifier = "archive-owner-truth-candidate-confirmation"
        candidateConfirmationButton.accessibilityLabel = "待确认记忆"
        candidateConfirmationButton.isHidden = true
        candidateConfirmationButton.addTarget(
            self,
            action: #selector(ownerTruthCandidateConfirmationTapped),
            for: .touchUpInside
        )
    }

    private func configureCandidateMemoryActivationButton() {
        candidateMemoryActivationButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        candidateMemoryActivationButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        candidateMemoryActivationButton.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        candidateMemoryActivationButton.layer.cornerRadius = 14
        candidateMemoryActivationButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        candidateMemoryActivationButton.contentHorizontalAlignment = .leading
        candidateMemoryActivationButton.accessibilityIdentifier = "owner-truth-memory-activation-inbox-entry"
        candidateMemoryActivationButton.accessibilityLabel = "待纳入正式记忆"
        candidateMemoryActivationButton.isHidden = true
        candidateMemoryActivationButton.addTarget(
            self,
            action: #selector(ownerTruthCandidateMemoryActivationTapped),
            for: .touchUpInside
        )
    }

    private func configureArchiveFilterButton() {
        archiveFilterButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        archiveFilterButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        archiveFilterButton.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        archiveFilterButton.layer.cornerRadius = 14
        archiveFilterButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        archiveFilterButton.contentHorizontalAlignment = .leading
        archiveFilterButton.accessibilityIdentifier = "archiveKindFilter"
        archiveFilterButton.isHidden = true
        archiveFilterButton.addTarget(self, action: #selector(clearArchiveKindFilterTapped), for: .touchUpInside)
    }

    private func updateArchiveFilterButton() {
        guard let activeKindFilter else {
            archiveFilterButton.setTitle(nil, for: .normal)
            archiveFilterButton.accessibilityLabel = nil
            archiveFilterButton.isHidden = true
            return
        }

        let title = "正在查看：\(activeKindFilter.title) · 查看全部"
        archiveFilterButton.setTitle(title, for: .normal)
        archiveFilterButton.accessibilityLabel = title
        archiveFilterButton.isHidden = false
    }

    private func setArchiveRemoteSyncStatus(_ status: ArchiveRemoteSyncStatus) {
        switch status {
        case .idle:
            remoteSyncCaptionLabel.text = nil
            remoteSyncCaptionLabel.isHidden = true
        case .syncing:
            remoteSyncCaptionLabel.text = "正在同步远端档案..."
            remoteSyncCaptionLabel.isHidden = false
        case .synced:
            remoteSyncCaptionLabel.text = "已同步远端档案"
            remoteSyncCaptionLabel.isHidden = false
        case .fallback:
            remoteSyncCaptionLabel.text = "远端暂不可用，已保留本地档案，可稍后自动重试"
            remoteSyncCaptionLabel.isHidden = false
        }
        remoteSyncCaptionLabel.accessibilityLabel = remoteSyncCaptionLabel.text
    }

    private func updateTimeLetterReminderButton() {
        guard isSelfAutobiographyMode, isTimeLetterCreationEnabled else {
            timeLetterReminderButton.setTitle(nil, for: .normal)
            timeLetterReminderButton.accessibilityLabel = nil
            timeLetterReminderButton.isHidden = true
            return
        }

        guard let accountLease = captureInAppMessageCenterAccountLease(at: .request),
              let snapshot = currentInAppMessageCenterSnapshot(accountLease: accountLease) else {
            timeLetterReminderButton.setTitle(nil, for: .normal)
            timeLetterReminderButton.accessibilityLabel = nil
            timeLetterReminderButton.isHidden = true
            return
        }
        let reminderCount = repository.timeLetterReminderCount()
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed,
              let title = snapshot.entryButtonTitle(timeLetterReminderCount: reminderCount) else {
            timeLetterReminderButton.setTitle(nil, for: .normal)
            timeLetterReminderButton.accessibilityLabel = nil
            timeLetterReminderButton.isHidden = true
            return
        }

        timeLetterReminderButton.setTitle(title, for: .normal)
        timeLetterReminderButton.accessibilityLabel = title
        timeLetterReminderButton.isHidden = false
    }

    private func updateCandidateReviewQAButton() {
        let isVisible = isSelfAutobiographyMode && OwnerTruthCandidateReviewQAGate.isEnabled
        candidateReviewQAButton.setTitle(isVisible ? "审核候选记忆（QA）" : nil, for: .normal)
        candidateReviewQAButton.isHidden = !isVisible
        candidateReviewQAButton.isUserInteractionEnabled = isVisible
    }

    private func updateCandidateConfirmationButton() {
        let isVisible = isSelfAutobiographyMode && FeatureGateService.shared.isRouteAllowed(
            .ownerTruthCandidateReview,
            localEnabled: FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview)
        )
        candidateConfirmationButton.setTitle(isVisible ? "待确认记忆" : nil, for: .normal)
        candidateConfirmationButton.accessibilityLabel = isVisible ? "待确认记忆" : nil
        candidateConfirmationButton.isHidden = !isVisible
        candidateConfirmationButton.isUserInteractionEnabled = isVisible
    }

    private func updateCandidateMemoryActivationButton() {
        let isVisible = isSelfAutobiographyMode && FeatureGateService.shared.isRouteAllowed(
            .ownerTruthCandidateReview,
            localEnabled: FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview)
        )
        candidateMemoryActivationButton.setTitle(isVisible ? "待纳入正式记忆" : nil, for: .normal)
        candidateMemoryActivationButton.accessibilityLabel = isVisible ? "待纳入正式记忆" : nil
        candidateMemoryActivationButton.isHidden = !isVisible
        candidateMemoryActivationButton.isUserInteractionEnabled = isVisible
    }

    private func reloadFeatureCards(summary: (total: Int, photos: Int, audio: Int, text: Int)) {
        featureCardsStack.removeAllArrangedSubviews()
        featureCardsStack.isHidden = true
        analysisPrivacyDisclaimerLabel.isHidden = true
    }

    private func reloadArchiveList() {
        listStack.removeAllArrangedSubviews()
        let allItems = repository.allItems()
        let items: [MemoryArchiveItem]
        if let activeKindFilter {
            items = allItems.filter { $0.kind == activeKindFilter.kind }
        } else {
            items = allItems
        }

        if items.isEmpty {
            #if UI_QA_SIMULATOR && targetEnvironment(simulator)
            if activeKindFilter == nil {
                listStack.addArrangedSubview(makeStitchPhotoMemoryCard())
                listStack.addArrangedSubview(makeStitchAudioMemoryCard())
                listStack.addArrangedSubview(makeAutobiographyPlaceholderChapter())
            } else {
                listStack.addArrangedSubview(makeEmptyStateCard(filter: activeKindFilter))
            }
            #else
            listStack.addArrangedSubview(makeEmptyStateCard(filter: activeKindFilter))
            #endif
            return
        }

        items.forEach { item in
            listStack.addArrangedSubview(makeArchiveTimelineCard(item))
        }
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 22, left: 0, bottom: 4, right: 0)
        stack.isLayoutMarginsRelativeArrangement = true

        let titleLabel = UILabel()
        titleLabel.text = "记忆档案"
        titleLabel.font = DJDesignTokens.Font.display(34)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = isSelfAutobiographyMode
            ? "上方进入完整自传，下方管理你记录的记忆素材。"
            : "上方翻阅 \(archivePersonaName) 的故事，下方查看已沉淀的素材。"
        subtitleLabel.font = UIFont.italicSystemFont(ofSize: ArchiveLayout.headerSubtitleFontSize)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.48)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(divider)
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 42),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])

        headerTitleLabel = titleLabel
        headerSubtitleLabel = subtitleLabel
        return stack
    }

    private func makeBookEntryCard() -> UIControl {
        let control = UIControl()
        control.backgroundColor = .clear
        control.layer.cornerRadius = ArchiveLayout.bookEntryCornerRadius
        control.addTarget(self, action: #selector(autobiographyBookTapped), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let imageContainer = UIView()
        imageContainer.backgroundColor = UIColor(red: 0.16, green: 0.11, blue: 0.17, alpha: 1)
        imageContainer.layer.cornerRadius = ArchiveLayout.bookEntryCornerRadius
        imageContainer.layer.masksToBounds = true

        let imageView = UIImageView(image: UIImage(named: "archive_magic_book_entry"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let softVeil = UIView()
        softVeil.backgroundColor = UIColor.black.withAlphaComponent(0.08)

        let bottomOverlay = UIView()
        bottomOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        bottomOverlay.layer.cornerRadius = 18
        bottomOverlay.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let titleLabel = UILabel()
        titleLabel.text = isSelfAutobiographyMode ? "我的自传" : "\(archivePersonaName)的故事"
        titleLabel.font = DJDesignTokens.Font.title(24)
        titleLabel.textColor = .white
        titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.40)
        titleLabel.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        let enterLabel = UILabel()
        enterLabel.text = "翻开阅读"
        enterLabel.font = DJDesignTokens.Font.label(13)
        enterLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.48, alpha: 1)

        let enterIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
        enterIcon.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.48, alpha: 1)
        enterIcon.contentMode = .scaleAspectFit

        let enterRow = UIStackView(arrangedSubviews: [enterLabel, enterIcon])
        enterRow.alignment = .center
        enterRow.spacing = 6

        let titleStack = UIStackView(arrangedSubviews: [titleLabel])
        titleStack.axis = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 4

        let bottomRow = UIStackView(arrangedSubviews: [titleStack, enterRow])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 14
        bottomRow.isUserInteractionEnabled = false

        titleStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        enterRow.setContentHuggingPriority(.required, for: .horizontal)

        [
            imageContainer,
            imageView,
            softVeil,
            bottomOverlay,
            titleLabel,
            titleStack,
            bottomRow,
            enterRow,
            enterLabel,
            enterIcon,
        ].forEach { $0.isUserInteractionEnabled = false }

        control.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(softVeil)
        imageContainer.addSubview(bottomOverlay)
        imageContainer.addSubview(bottomRow)

        [
            imageContainer,
            imageView,
            softVeil,
            bottomOverlay,
            titleStack,
            bottomRow,
            enterRow,
            enterLabel,
            enterIcon,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: 238),

            imageContainer.topAnchor.constraint(equalTo: control.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            softVeil.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            softVeil.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            softVeil.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            softVeil.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            bottomOverlay.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            bottomOverlay.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            bottomOverlay.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            bottomOverlay.heightAnchor.constraint(equalToConstant: 56),

            bottomRow.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 18),
            bottomRow.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -18),
            bottomRow.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -14),

            enterIcon.widthAnchor.constraint(equalToConstant: 13),
            enterIcon.heightAnchor.constraint(equalToConstant: 13),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = isSelfAutobiographyMode ? "我的自传，点击进入完整书本" : "\(archivePersonaName)的故事，点击进入完整书本"
        bookEntryControl = control
        bookEntryTitleLabel = titleLabel
        return control
    }

    private func makeMaterialsHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveLayout.materialsHeaderSpacing
        stack.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        stack.isLayoutMarginsRelativeArrangement = true

        let titleLabel = UILabel()
        titleLabel.text = isSelfAutobiographyMode ? "我记录的记忆" : "\(archivePersonaName)的记忆素材"
        titleLabel.font = DJDesignTokens.Font.title(22)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.84

        let subtitleLabel = UILabel()
        subtitleLabel.text = isSelfAutobiographyMode
            ? "这些素材会成为自传里的正文、照片和声音线索。"
            : "家人档案当前只读，可点开素材查看详情。"
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)

        materialsTitleLabel = titleLabel
        materialsSubtitleLabel = subtitleLabel
        return stack
    }

    private func makePrimaryCTA() -> UIControl {
        let control = UIControl()
        control.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.10)
        control.layer.cornerRadius = DJDesignTokens.Radius.large
        control.layer.borderWidth = 1
        control.layer.borderColor = DJDesignTokens.Color.accent.withAlphaComponent(0.20).cgColor
        control.addTarget(self, action: #selector(archiveNewMemoryTapped(_:)), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let iconContainer = makeIconContainer(iconName: "plus", tintColor: DJDesignTokens.Color.accentDeep)
        iconContainer.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.86)
        iconContainer.isUserInteractionEnabled = false

        let eyebrowLabel = UILabel()
        eyebrowLabel.text = "添加"
        eyebrowLabel.font = DJDesignTokens.Font.label(11)
        eyebrowLabel.textColor = DJDesignTokens.Color.accentDeep

        let titleLabel = UILabel()
        titleLabel.text = "记录新的记忆素材"
        titleLabel.font = DJDesignTokens.Font.title(17)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        let subtitleLabel = UILabel()
        subtitleLabel.text = "上传图片或写一段文字，成为自传的下一页"
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.isUserInteractionEnabled = false

        let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronView.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.72)
        chevronView.contentMode = .scaleAspectFit

        control.addSubview(iconContainer)
        control.addSubview(textStack)
        control.addSubview(chevronView)
        [iconContainer, textStack, chevronView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: 88),

            iconContainer.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 42),
            iconContainer.heightAnchor.constraint(equalToConstant: 42),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: control.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: control.bottomAnchor, constant: -12),

            chevronView.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -18),
            chevronView.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = "记录新的记忆素材，添加文字或图片"
        primaryCTAControl = control
        primaryCTAEyebrowLabel = eyebrowLabel
        primaryCTATitleLabel = titleLabel
        primaryCTASubtitleLabel = subtitleLabel
        return control
    }

    private func makeArchiveCTASubtitle() -> String {
        "文字、图片"
    }

    private func makeSummaryCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let eyebrowLabel = UILabel()
        eyebrowLabel.text = "数字人格成长"
        eyebrowLabel.font = DJDesignTokens.Font.label(12)
        eyebrowLabel.textColor = DJDesignTokens.Color.accentDeep

        summaryLabel.font = DJDesignTokens.Font.title(18)
        summaryLabel.textColor = DJDesignTokens.Color.textPrimary
        summaryLabel.numberOfLines = 0

        progressLabel.font = DJDesignTokens.Font.body(14)
        progressLabel.textColor = DJDesignTokens.Color.textSecondary
        progressLabel.numberOfLines = 0

        card.addSubview(stack)
        [stack, eyebrowLabel, summaryLabel, progressLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stack.addArrangedSubview(eyebrowLabel)
        stack.addArrangedSubview(summaryLabel)
        stack.addArrangedSubview(progressLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeTimelineHeader() -> UIView {
        let header = makeChapterHeader(
            indexText: "CHAPTER I",
            title: isSelfAutobiographyMode ? "家族根基" : "记忆片段",
            subtitle: isSelfAutobiographyMode ? "Family Roots" : "Stories"
        )
        return header.view
    }

    private func makeChapterHeader(
        indexText: String,
        title: String,
        subtitle: String
    ) -> (view: UIView, titleLabel: UILabel, subtitleLabel: UILabel) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveLayout.chapterHeaderSpacing
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 2, right: 0)
        stack.isLayoutMarginsRelativeArrangement = true

        let topLine = UIStackView()
        topLine.alignment = .center
        topLine.spacing = 10

        let indexLabel = UILabel()
        indexLabel.text = indexText
        indexLabel.font = DJDesignTokens.Font.label(12)
        indexLabel.textColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.82)
        indexLabel.setContentHuggingPriority(.required, for: .horizontal)

        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.38)

        let titleLine = UIStackView()
        titleLine.alignment = .lastBaseline
        titleLine.spacing = 10

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.title(22)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(12)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 1

        topLine.addArrangedSubview(indexLabel)
        topLine.addArrangedSubview(divider)
        titleLine.addArrangedSubview(titleLabel)
        titleLine.addArrangedSubview(subtitleLabel)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(topLine)
        stack.addArrangedSubview(titleLine)

        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])

        return (stack, titleLabel, subtitleLabel)
    }

    private func makeFeatureGrid(summary: (total: Int, photos: Int, audio: Int, text: Int)) -> UIView {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        let photoDetail = summary.photos == 0 ? "128 个瞬间" : "\(summary.photos) 个瞬间"
        #else
        let photoDetail = "\(summary.photos) 个瞬间"
        #endif

        let photoCard = makeFeatureTile(
            iconName: "photo.on.rectangle.angled",
            title: "相册影像",
            detail: photoDetail,
            isLarge: true,
            action: #selector(photoCardTapped)
        )

        let secondaryTiles = makeSecondaryFeatureTiles(summary: summary)
        guard !secondaryTiles.isEmpty else {
            NSLayoutConstraint.activate([
                photoCard.heightAnchor.constraint(equalToConstant: ArchiveLayout.featureGridHeight),
            ])
            return photoCard
        }

        let rightColumn = UIStackView(arrangedSubviews: secondaryTiles)
        rightColumn.axis = .vertical
        rightColumn.spacing = ArchiveLayout.featureGridGap
        rightColumn.distribution = .fillEqually

        let grid = UIStackView(arrangedSubviews: [photoCard, rightColumn])
        grid.axis = .horizontal
        grid.spacing = ArchiveLayout.featureGridGap
        grid.distribution = .fillEqually

        NSLayoutConstraint.activate([
            photoCard.heightAnchor.constraint(equalToConstant: ArchiveLayout.featureGridHeight),
        ])

        return grid
    }

    private func makeSecondaryFeatureTiles(summary: (total: Int, photos: Int, audio: Int, text: Int)) -> [UIView] {
        var tiles: [UIView] = []

        if isArchiveAudioCreationEnabled {
            tiles.append(makeFeatureTile(
                iconName: "waveform",
                title: "语音档案",
                detail: "\(summary.audio) 段声音",
                isLarge: false,
                action: #selector(audioCardTapped)
            ))
        }

        if isPersonaSettingsVisible {
            tiles.append(makeFeatureTile(
                iconName: "slider.horizontal.3",
                title: "人格设定",
                detail: "称呼偏好",
                isLarge: false,
                action: #selector(personaCardTapped)
            ))
        }

        return tiles
    }

    private func makeFeatureTile(
        iconName: String,
        title: String,
        detail: String?,
        isLarge: Bool,
        action: Selector?
    ) -> UIControl {
        let control = UIControl()
        control.backgroundColor = DJDesignTokens.Color.surface
        control.layer.cornerRadius = DJDesignTokens.Radius.large
        control.layer.borderWidth = 1
        control.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.48).cgColor
        control.addTarget(self, action: action ?? #selector(disabledFeatureTapped), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let iconContainer = makeIconContainer(iconName: iconName, tintColor: DJDesignTokens.Color.accentDeep)
        iconContainer.backgroundColor = isLarge
            ? DJDesignTokens.Color.surfaceContainer
            : DJDesignTokens.Color.surfaceLow

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = isLarge ? DJDesignTokens.Font.title(18) : DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        let textStack = UIStackView(arrangedSubviews: [titleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = DJDesignTokens.Font.label(12)
            detailLabel.textColor = DJDesignTokens.Color.textSecondary
            detailLabel.numberOfLines = 1
            textStack.addArrangedSubview(detailLabel)
        }

        let stack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        stack.axis = isLarge ? .vertical : .horizontal
        stack.alignment = isLarge ? .leading : .center
        stack.spacing = ArchiveLayout.featureTileStackSpacing
        stack.isUserInteractionEnabled = false

        control.addSubview(stack)
        [stack, iconContainer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: isLarge ? ArchiveLayout.featureLargeIconSize : ArchiveLayout.featureSmallIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: isLarge ? ArchiveLayout.featureLargeIconSize : ArchiveLayout.featureSmallIconSize),

            stack.topAnchor.constraint(equalTo: control.topAnchor, constant: isLarge ? ArchiveLayout.featureLargePadding : ArchiveLayout.featureSmallPadding),
            stack.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: isLarge ? ArchiveLayout.featureLargePadding : ArchiveLayout.featureSmallPadding),
            stack.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: isLarge ? -ArchiveLayout.featureLargePadding : -ArchiveLayout.featureSmallPadding),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: control.bottomAnchor, constant: isLarge ? -ArchiveLayout.featureLargePadding : -ArchiveLayout.featureSmallPadding),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = detail == nil ? title : "\(title)，\(detail ?? "")"
        return control
    }

    private func makeArchiveTimelineCard(_ item: MemoryArchiveItem) -> UIView {
        let presentation = item.archivePresentation
        switch item.kind {
        case .photo:
            return makePhotoTimelineCard(item, presentation: presentation)
        case .audio:
            return makeAudioTimelineCard(item, presentation: presentation)
        case .text, .timeLetter, .video:
            return makeCompactTimelineCard(item, presentation: presentation)
        }
    }

    private func makePhotoTimelineCard(
        _ item: MemoryArchiveItem,
        presentation: MemoryArchiveItemPresentation
    ) -> UIView {
        let control = makeArchiveTimelineControl(item, presentation: presentation)
        let card = makeArchiveTimelineBaseCard()
        let contentView = UIView()
        contentView.backgroundColor = DJDesignTokens.Color.surface
        contentView.layer.cornerRadius = ArchiveLayout.timelineCardRadius
        contentView.layer.masksToBounds = true

        let imageContainer = UIView()
        imageContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer
        imageContainer.clipsToBounds = true

        let image = item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }
        let hasImage = image != nil
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.alpha = hasImage ? 0.92 : 0
        imageView.clipsToBounds = true

        let placeholderIcon = UIImageView(image: UIImage(systemName: presentation.previewIconName))
        placeholderIcon.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.38)
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.isHidden = hasImage

        let scrimView = UIView()
        scrimView.backgroundColor = hasImage
            ? UIColor.black.withAlphaComponent(0.24)
            : DJDesignTokens.Color.surface.withAlphaComponent(0.74)

        let tagLabel: UIView = hasImage
            ? makeOverlayBadge(text: presentation.kindLabel, iconName: item.kind.archiveIconName)
            : makeBadge(text: presentation.kindLabel)
        let dateLabel = makeOverlayDateLabel(Self.timelineDateFormatter.string(from: item.createdAt))
        dateLabel.textColor = hasImage
            ? UIColor.white.withAlphaComponent(0.92)
            : DJDesignTokens.Color.textTertiary

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = ArchiveLayout.timelineCardTextSpacing
        textStack.layoutMargins = UIEdgeInsets(
            top: 12,
            left: ArchiveLayout.timelineCardInset,
            bottom: 14,
            right: ArchiveLayout.timelineCardInset
        )
        textStack.isLayoutMarginsRelativeArrangement = true

        let titleLabel = makeTimelineTitleLabel(presentation.title)
        let noteLabel = makeTimelineNoteLabel(presentation.note, numberOfLines: 2)

        control.addSubview(card)
        card.addSubview(contentView)
        contentView.addSubview(imageContainer)
        contentView.addSubview(textStack)
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(placeholderIcon)
        imageContainer.addSubview(scrimView)
        imageContainer.addSubview(tagLabel)
        imageContainer.addSubview(dateLabel)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(noteLabel)

        [
            card,
            contentView,
            imageContainer,
            textStack,
            imageView,
            placeholderIcon,
            scrimView,
            tagLabel,
            dateLabel,
            titleLabel,
            noteLabel,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: control.topAnchor),
            card.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: card.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageContainer.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineMediaHeight),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor, constant: hasImage ? 0 : -16),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 48),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 48),

            scrimView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            scrimView.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineMediaScrimHeight),

            tagLabel.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 16),
            tagLabel.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -16),

            dateLabel.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -16),
            dateLabel.centerYAnchor.constraint(equalTo: tagLabel.centerYAnchor),

            textStack.topAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        return control
    }

    private func makeAudioTimelineCard(
        _ item: MemoryArchiveItem,
        presentation: MemoryArchiveItemPresentation
    ) -> UIView {
        let control = makeArchiveTimelineControl(item, presentation: presentation)
        let card = makeArchiveTimelineBaseCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveLayout.timelineCardBodySpacing
        stack.layoutMargins = UIEdgeInsets(
            top: ArchiveLayout.timelineCardInset,
            left: ArchiveLayout.timelineCardInset,
            bottom: ArchiveLayout.timelineCardInset,
            right: ArchiveLayout.timelineCardInset
        )
        stack.isLayoutMarginsRelativeArrangement = true

        let header = UIStackView()
        header.alignment = .center

        let iconContainer = makeIconContainer(iconName: presentation.previewIconName, tintColor: DJDesignTokens.Color.textSecondary)
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceLow

        let dateLabel = UILabel()
        dateLabel.text = Self.timelineDateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.label(12)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary
        dateLabel.textAlignment = .right

        let titleLabel = makeTimelineTitleLabel(presentation.title)
        let noteLabel = makeTimelineNoteLabel(presentation.note, numberOfLines: 3)

        let playerView = makeTimelineAudioPlayer(durationText: item.metadata["durationText"] ?? "01:42")

        control.addSubview(card)
        card.addSubview(stack)
        header.addArrangedSubview(iconContainer)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(dateLabel)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(noteLabel)
        stack.addArrangedSubview(playerView)

        [card, stack, header, iconContainer, dateLabel, titleLabel, noteLabel, playerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: control.topAnchor),
            card.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            iconContainer.widthAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioIconSize),

            playerView.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayerHeight),
        ])

        return control
    }

    private func makeCompactTimelineCard(
        _ item: MemoryArchiveItem,
        presentation: MemoryArchiveItemPresentation
    ) -> UIView {
        let control = makeArchiveTimelineControl(item, presentation: presentation)
        let card = makeArchiveTimelineBaseCard()
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = ArchiveLayout.timelineCardBodySpacing

        let previewView = makeArchiveItemPreview(item, presentation: presentation)
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 7

        let titleLabel = makeTimelineTitleLabel(presentation.title)
        let badgeStack = makeTimelineBadgeStack(presentation)
        let noteLabel = makeTimelineNoteLabel(presentation.note, numberOfLines: 3)

        let metadataLabel = UILabel()
        metadataLabel.text = presentation.metadataSummary
        metadataLabel.font = DJDesignTokens.Font.label(11)
        metadataLabel.textColor = DJDesignTokens.Color.textTertiary
        metadataLabel.numberOfLines = 1
        metadataLabel.isHidden = presentation.metadataSummary == nil
        if item.kind == .video {
            control.accessibilityIdentifier = "archive-video-timeline-card"
            metadataLabel.accessibilityIdentifier = "archive-video-timeline-metadata"
        }

        let dateLabel = UILabel()
        dateLabel.text = Self.itemDateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.label(11)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        control.addSubview(card)
        card.addSubview(stack)
        [card, stack, previewView, textStack, titleLabel, badgeStack, noteLabel, metadataLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(badgeStack)
        textStack.addArrangedSubview(noteLabel)
        textStack.addArrangedSubview(metadataLabel)
        textStack.addArrangedSubview(dateLabel)
        stack.addArrangedSubview(previewView)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: control.topAnchor),
            card.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveLayout.timelineCardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveLayout.timelineCardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveLayout.timelineCardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveLayout.timelineCardInset),

            previewView.widthAnchor.constraint(equalToConstant: ArchiveLayout.timelinePreviewWidth),
            previewView.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelinePreviewHeight),
        ])

        return control
    }

    private func makeArchiveTimelineBaseCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: ArchiveLayout.timelineCardRadius)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.30).cgColor
        card.isUserInteractionEnabled = false
        return card
    }

    private func makeArchiveTimelineControl(
        _ item: MemoryArchiveItem,
        presentation: MemoryArchiveItemPresentation
    ) -> MemoryArchiveItemRowControl {
        let control = MemoryArchiveItemRowControl(item: item)
        control.addTarget(self, action: #selector(archiveItemTapped(_:)), for: .touchUpInside)
        control.accessibilityTraits = .button
        control.accessibilityLabel = presentation.accessibilityLabel
        return control
    }

    private func makeTimelineTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.title(18)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 0
        return label
    }

    private func makeTimelineNoteLabel(_ text: String, numberOfLines: Int) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.body(14)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.numberOfLines = numberOfLines
        return label
    }

    private func makeTimelineBadgeStack(_ presentation: MemoryArchiveItemPresentation) -> UIStackView {
        let stack = UIStackView()
        stack.spacing = ArchiveLayout.timelineBadgeSpacing
        stack.alignment = .center
        stack.addArrangedSubview(makeBadge(text: presentation.kindLabel))
        stack.addArrangedSubview(makeStatusBadge(text: presentation.statusLabel))
        return stack
    }

    private func makeTimelineAudioPlayer(durationText: String) -> UIView {
        let playerView = UIView()
        playerView.backgroundColor = DJDesignTokens.Color.surfaceContainer
        playerView.layer.cornerRadius = ArchiveLayout.timelineAudioPlayerHeight / 2

        let playButton = UIView()
        playButton.backgroundColor = DJDesignTokens.Color.accentDeep
        playButton.layer.cornerRadius = ArchiveLayout.timelineAudioPlayButtonSize / 2

        let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit

        let trackView = UIView()
        trackView.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.35)
        trackView.layer.cornerRadius = ArchiveLayout.timelinePlayerTrackHeight / 2

        let progressView = UIView()
        progressView.backgroundColor = DJDesignTokens.Color.accentDeep
        progressView.layer.cornerRadius = ArchiveLayout.timelinePlayerTrackHeight / 2

        let durationLabel = UILabel()
        durationLabel.text = durationText
        durationLabel.font = DJDesignTokens.Font.label(11)
        durationLabel.textColor = DJDesignTokens.Color.textTertiary
        durationLabel.textAlignment = .right

        playerView.addSubview(playButton)
        playButton.addSubview(playIcon)
        playerView.addSubview(trackView)
        trackView.addSubview(progressView)
        playerView.addSubview(durationLabel)

        [playButton, playIcon, trackView, progressView, durationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 8),
            playButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayButtonSize),
            playButton.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayButtonSize),

            playIcon.centerXAnchor.constraint(equalTo: playButton.centerXAnchor, constant: 1),
            playIcon.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayIconSize),
            playIcon.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelineAudioPlayIconSize),

            trackView.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            trackView.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: ArchiveLayout.timelinePlayerTrackHeight),

            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            progressView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0.34),

            durationLabel.leadingAnchor.constraint(equalTo: trackView.trailingAnchor, constant: 12),
            durationLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -14),
            durationLabel.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 38),
        ])

        return playerView
    }

    private func makeArchiveItemRow(_ item: MemoryArchiveItem) -> UIView {
        let presentation = item.archivePresentation
        let control = MemoryArchiveItemRowControl(item: item)
        control.addTarget(self, action: #selector(archiveItemTapped(_:)), for: .touchUpInside)

        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42).cgColor
        card.isUserInteractionEnabled = false
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = 14

        let previewView = makeArchiveItemPreview(item, presentation: presentation)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6

        let topLine = UIStackView()
        topLine.alignment = .center
        topLine.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = presentation.title
        titleLabel.font = DJDesignTokens.Font.title(17)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let statusStack = UIStackView()
        statusStack.spacing = 6
        statusStack.alignment = .center

        let kindBadge = makeBadge(text: presentation.kindLabel)
        let analysisBadge = makeStatusBadge(text: presentation.statusLabel)
        statusStack.addArrangedSubview(kindBadge)
        statusStack.addArrangedSubview(analysisBadge)

        let noteLabel = UILabel()
        noteLabel.text = presentation.note
        noteLabel.font = DJDesignTokens.Font.body(15)
        noteLabel.textColor = DJDesignTokens.Color.textSecondary
        noteLabel.numberOfLines = 3

        let metadataLabel = UILabel()
        metadataLabel.text = presentation.metadataSummary
        metadataLabel.font = DJDesignTokens.Font.label(11)
        metadataLabel.textColor = DJDesignTokens.Color.textTertiary
        metadataLabel.numberOfLines = 1
        metadataLabel.isHidden = presentation.metadataSummary == nil

        let dateLabel = UILabel()
        dateLabel.text = Self.itemDateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.label(11)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        control.addSubview(card)
        card.addSubview(stack)
        [card, stack, previewView, textStack, topLine, titleLabel, statusStack, kindBadge, analysisBadge, noteLabel, metadataLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topLine.addArrangedSubview(titleLabel)
        topLine.addArrangedSubview(statusStack)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusStack.setContentHuggingPriority(.required, for: .horizontal)

        textStack.addArrangedSubview(topLine)
        textStack.addArrangedSubview(noteLabel)
        textStack.addArrangedSubview(metadataLabel)
        textStack.addArrangedSubview(dateLabel)

        stack.addArrangedSubview(previewView)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: control.topAnchor),
            card.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            previewView.widthAnchor.constraint(equalToConstant: 54),
            previewView.heightAnchor.constraint(equalToConstant: 64),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = presentation.accessibilityLabel
        return control
    }

    private func makeArchiveItemPreview(
        _ item: MemoryArchiveItem,
        presentation: MemoryArchiveItemPresentation
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.76)
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true
        container.isUserInteractionEnabled = false

        switch item.kind {
        case .photo:
            let image = item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }
            if let image {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                container.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: container.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                let iconView = UIImageView(image: UIImage(systemName: presentation.previewIconName))
                iconView.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.52)
                iconView.contentMode = .scaleAspectFit
                container.addSubview(iconView)
                iconView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    iconView.widthAnchor.constraint(equalToConstant: 26),
                    iconView.heightAnchor.constraint(equalToConstant: 26),
                ])
            }
        case .audio:
            let waveform = makeArchiveItemPreviewWaveform()
            container.addSubview(waveform)
            waveform.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                waveform.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9),
                waveform.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
                waveform.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                waveform.heightAnchor.constraint(equalToConstant: 34),
            ])
        case .video:
            if let thumbnailPath = item.resolvedThumbnailPath,
               let image = UIImage(contentsOfFile: thumbnailPath) {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.accessibilityIdentifier = "archive-video-timeline-thumbnail"
                container.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: container.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                let iconView = UIImageView(image: UIImage(systemName: presentation.previewIconName))
                iconView.tintColor = DJDesignTokens.Color.accentDeep
                iconView.contentMode = .scaleAspectFit
                iconView.accessibilityIdentifier = "archive-video-timeline-placeholder"
                container.addSubview(iconView)
                iconView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    iconView.widthAnchor.constraint(equalToConstant: 25),
                    iconView.heightAnchor.constraint(equalToConstant: 25),
                ])
            }
        case .timeLetter:
            if let imagePath = item.resolvedLocalFilePath,
               let image = UIImage(contentsOfFile: imagePath) {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.accessibilityIdentifier = "archive-time-letter-timeline-image"
                container.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: container.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                let iconView = UIImageView(image: UIImage(systemName: presentation.previewIconName))
                iconView.tintColor = DJDesignTokens.Color.accentDeep
                iconView.contentMode = .scaleAspectFit
                container.addSubview(iconView)
                iconView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    iconView.widthAnchor.constraint(equalToConstant: 25),
                    iconView.heightAnchor.constraint(equalToConstant: 25),
                ])
            }
        case .text:
            let iconView = UIImageView(image: UIImage(systemName: presentation.previewIconName))
            iconView.tintColor = DJDesignTokens.Color.accentDeep
            iconView.contentMode = .scaleAspectFit
            container.addSubview(iconView)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 25),
                iconView.heightAnchor.constraint(equalToConstant: 25),
            ])
        }

        return container
    }

    private func makeArchiveItemPreviewWaveform() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 3

        [10, 18, 14, 28, 22, 12, 26].forEach { height in
            let bar = UIView()
            bar.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.46)
            bar.layer.cornerRadius = 1.5
            stack.addArrangedSubview(bar)
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.heightAnchor.constraint(equalToConstant: CGFloat(height)).isActive = true
        }

        return stack
    }

    private func makeStitchPhotoMemoryCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.extraLarge)
        let contentView = UIView()
        contentView.backgroundColor = DJDesignTokens.Color.surface
        contentView.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        contentView.layer.masksToBounds = true

        let imageContainer = UIView()
        imageContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer
        imageContainer.clipsToBounds = true

        let imageView = UIImageView(image: UIImage(named: "default_memory_1"))
        imageView.contentMode = .scaleAspectFill
        imageView.alpha = 0.92
        imageView.clipsToBounds = true

        let scrimView = UIView()
        scrimView.backgroundColor = UIColor.black.withAlphaComponent(0.24)

        let tagLabel = makeOverlayBadge(text: "照片", iconName: "photo")
        let dateLabel = makeOverlayDateLabel("2019.02.04")

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.layoutMargins = UIEdgeInsets(top: 12, left: 18, bottom: 14, right: 18)
        textStack.isLayoutMarginsRelativeArrangement = true

        let titleLabel = UILabel()
        titleLabel.text = "2019年春节的回忆"
        titleLabel.font = DJDesignTokens.Font.title(18)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1

        let noteLabel = UILabel()
        noteLabel.text = "那天晚上大家都喝了点酒，爷爷破天荒地讲起了他年轻时候去南方修铁路的故事..."
        noteLabel.font = DJDesignTokens.Font.body(14)
        noteLabel.textColor = DJDesignTokens.Color.textSecondary
        noteLabel.numberOfLines = 1

        card.addSubview(contentView)
        contentView.addSubview(imageContainer)
        contentView.addSubview(textStack)
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(scrimView)
        imageContainer.addSubview(tagLabel)
        imageContainer.addSubview(dateLabel)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(noteLabel)

        [
            contentView,
            imageContainer,
            textStack,
            imageView,
            scrimView,
            tagLabel,
            dateLabel,
            titleLabel,
            noteLabel,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: card.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageContainer.heightAnchor.constraint(equalToConstant: 132),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            scrimView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            scrimView.heightAnchor.constraint(equalToConstant: 72),

            tagLabel.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 16),
            tagLabel.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -16),

            dateLabel.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -16),
            dateLabel.centerYAnchor.constraint(equalTo: tagLabel.centerYAnchor),

            textStack.topAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        return card
    }

    private func makeStitchAudioMemoryCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.extraLarge)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.isLayoutMarginsRelativeArrangement = true

        let header = UIStackView()
        header.alignment = .center

        let iconContainer = makeIconContainer(iconName: "waveform", tintColor: DJDesignTokens.Color.textSecondary)
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceLow

        let dateLabel = UILabel()
        dateLabel.text = "2022.08.15"
        dateLabel.font = DJDesignTokens.Font.label(12)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary
        dateLabel.textAlignment = .right

        header.addArrangedSubview(iconContainer)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(dateLabel)

        let titleLabel = UILabel()
        titleLabel.text = "老家的菜园"
        titleLabel.font = DJDesignTokens.Font.title(20)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        let noteLabel = UILabel()
        noteLabel.text = "记录了一段午后在院子里，外婆浇水时断断续续哼唱的不知名小调，伴随着夏末蝉鸣。"
        noteLabel.font = DJDesignTokens.Font.body(15)
        noteLabel.textColor = DJDesignTokens.Color.textSecondary
        noteLabel.numberOfLines = 3

        let playerView = UIView()
        playerView.backgroundColor = DJDesignTokens.Color.surfaceContainer
        playerView.layer.cornerRadius = 22

        let playButton = UIView()
        playButton.backgroundColor = DJDesignTokens.Color.accentDeep
        playButton.layer.cornerRadius = 14

        let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit

        let trackView = UIView()
        trackView.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.35)
        trackView.layer.cornerRadius = 2

        let progressView = UIView()
        progressView.backgroundColor = DJDesignTokens.Color.accentDeep
        progressView.layer.cornerRadius = 2

        let durationLabel = UILabel()
        durationLabel.text = "01:42"
        durationLabel.font = DJDesignTokens.Font.label(11)
        durationLabel.textColor = DJDesignTokens.Color.textTertiary
        durationLabel.textAlignment = .right

        card.addSubview(stack)
        playerView.addSubview(playButton)
        playButton.addSubview(playIcon)
        playerView.addSubview(trackView)
        trackView.addSubview(progressView)
        playerView.addSubview(durationLabel)

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(noteLabel)
        stack.addArrangedSubview(playerView)

        [
            stack,
            header,
            iconContainer,
            dateLabel,
            titleLabel,
            noteLabel,
            playerView,
            playButton,
            playIcon,
            trackView,
            progressView,
            durationLabel,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            playerView.heightAnchor.constraint(equalToConstant: 44),

            playButton.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 8),
            playButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 28),
            playButton.heightAnchor.constraint(equalToConstant: 28),

            playIcon.centerXAnchor.constraint(equalTo: playButton.centerXAnchor, constant: 1),
            playIcon.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 12),
            playIcon.heightAnchor.constraint(equalToConstant: 12),

            trackView.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            trackView.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 4),

            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            progressView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0.34),

            durationLabel.leadingAnchor.constraint(equalTo: trackView.trailingAnchor, constant: 12),
            durationLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -14),
            durationLabel.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 38),
        ])

        return card
    }

    private func makeEmptyStateCard(filter: ArchiveKindFilter? = nil) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: "archivebox"))
        iconView.tintColor = DJDesignTokens.Color.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = filter?.emptyTitle ?? (isSelfAutobiographyMode ? "还没有写下自传片段" : "还没有可阅读的故事")
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = filter?.emptyDetail ?? (isSelfAutobiographyMode ? "先写下一段文字，或从相册选择一张照片。" : "切换到自己时可管理我的自传；家人故事页只读。")
        detailLabel.font = DJDesignTokens.Font.body(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        card.addSubview(stack)
        [stack, iconView, titleLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
        ])

        return card
    }

    private func makeAutobiographyPlaceholderChapter() -> UIView {
        makeUnstartedChapterCard()
    }

    private func makeUnstartedChapterCard() -> UIView {
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.24)
        card.layer.cornerRadius = DJDesignTokens.Radius.large
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.28).cgColor

        let label = UILabel()
        label.text = isSelfAutobiographyMode ? "尚未开启此章节的书写..." : "这一章还没有可阅读的故事。"
        label.font = UIFont.italicSystemFont(ofSize: 14)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0

        card.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: ArchiveLayout.chapterPlaceholderHeight),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        return card
    }

    private func makeOverlayBadge(text: String, iconName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.24)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        container.layer.masksToBounds = true

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = .white

        container.addSubview(iconView)
        container.addSubview(label)
        [iconView, label].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        return container
    }

    private func makeOverlayDateLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        return label
    }

    private func makeIconContainer(iconName: String, tintColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let imageView = UIImageView(image: UIImage(systemName: iconName))
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit

        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    private func makeBadge(text: String) -> UILabel {
        let label = PaddingLabel(horizontalInset: 8, verticalInset: 4)
        label.text = text
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.backgroundColor = DJDesignTokens.Color.surfaceLow
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }

    private func makeStatusBadge(text: String) -> UILabel {
        let label = makeBadge(text: text)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.backgroundColor = DJDesignTokens.Color.surfaceContainer
        return label
    }

    @objc private func archiveNewMemoryTapped(_ sender: UIControl) {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        let sheet = MemoryArchiveCreationSheetViewController(options: creationOptions)
        sheet.delegate = self
        present(sheet, animated: true)
    }

    @objc private func autobiographyBookTapped() {
        let viewController = AutobiographyBookViewController(
            repository: repository,
            context: currentArchiveContext
        )
        viewController.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc private func disabledFeatureTapped() {
        showToast("该入口将在后续开放", type: .info)
    }

    @objc private func archiveItemTapped(_ sender: MemoryArchiveItemRowControl) {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(
            MemoryArchiveDetailViewController(item: sender.item, isReadOnly: !isSelfAutobiographyMode),
            animated: true
        )
    }

    @objc private func photoCardTapped() {
        applyArchiveKindFilter(.photo)
    }

    @objc private func selectPhotoTapped() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }
        presentPhotoEntry()
    }

    @objc private func audioCardTapped() {
        applyArchiveKindFilter(.audio)
    }

    @objc private func personaCardTapped() {
        guard FeatureGateService.shared.isRouteAllowed(
            .personaSettings,
            localEnabled: FeatureFlagService.shared.isEnabled(.personaSettings),
            qaSyntheticOverride: isUIQAArchiveHiddenBranchesEnabled
        ) else {
            showToast("人格设定将在后续开放", type: .info)
            return
        }
        navigationController?.pushViewController(KnowledgeBaseViewController(), animated: true)
    }

    @objc private func clearArchiveKindFilterTapped() {
        activeKindFilter = nil
        refreshContent()
    }

    @objc private func timeLetterReminderTapped() {
        guard let accountLease = captureInAppMessageCenterAccountLease(at: .request) else {
            showToast("账号状态已变化，请稍后重试", type: .info)
            return
        }
        let snapshotProvider: (AccountLease) -> InAppMessageCenterSnapshot? = { [weak self] lease in
            self?.currentInAppMessageCenterSnapshot(accountLease: lease)
        }
        guard let snapshot = snapshotProvider(accountLease),
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
            showToast("账号状态已变化，请稍后重试", type: .info)
            return
        }
        guard !snapshot.messages.isEmpty else {
            applyArchiveKindFilter(.timeLetter)
            return
        }
        presentInAppMessageCenter(
            snapshot,
            accountLease: accountLease,
            snapshotProvider: snapshotProvider
        )
    }

    @objc private func ownerTruthCandidateConfirmationTapped() {
        guard isSelfAutobiographyMode,
              FeatureGateService.shared.isRouteAllowed(
                  .ownerTruthCandidateReview,
                  localEnabled: FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview)
              ),
              let accountLease = captureOwnerTruthCandidateReviewAccountLease() else {
            return
        }
        navigationController?.pushViewController(
            OwnerTruthInterviewCandidateConfirmationInboxViewController(accountLease: accountLease),
            animated: true
        )
    }

    @objc private func ownerTruthCandidateMemoryActivationTapped() {
        guard isSelfAutobiographyMode,
              FeatureGateService.shared.isRouteAllowed(
                  .ownerTruthCandidateReview,
                  localEnabled: FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview)
              ),
              let accountLease = captureOwnerTruthCandidateReviewAccountLease() else {
            return
        }
        navigationController?.pushViewController(
            OwnerTruthInterviewCandidateMemoryActivationInboxViewController(
                accountLease: accountLease
            ),
            animated: true
        )
    }

    @objc private func ownerTruthCandidateReviewQATapped() {
        guard OwnerTruthCandidateReviewQAGate.isEnabled,
              isSelfAutobiographyMode,
              let accountLease = captureOwnerTruthCandidateReviewAccountLease() else {
            return
        }
        navigationController?.pushViewController(
            OwnerTruthCandidateInboxViewController(accountLease: accountLease),
            animated: true
        )
    }

    private func captureOwnerTruthCandidateReviewAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLease.subjectId == userId,
              OwnerTruthVaultID(accountLease.vaultId) != nil,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            showToast("账号状态已变化，请稍后重试", type: .info)
            return nil
        }
        return accountLease
    }

    private func captureInAppMessageCenterAccountLease(
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else {
            return nil
        }
        return accountLease
    }

    private func currentInAppMessageCenterSnapshot(
        accountLease: AccountLease
    ) -> InAppMessageCenterSnapshot? {
        guard accountLease.subjectId == UserManager.shared.currentUser?.id,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        let familyInvitationSources = FamilyRepository.shared.getAll().map {
            $0 as FamilyInvitationMessageSource
        }
        let careSignalSources = currentCareSignalMessageSources(accountLease: accountLease)
        let echoReplySources = EchoReplyMessageStore.shared.inboxSources(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId
        )
        let systemNoticeSources = SystemNoticeMessageStore.shared.sources(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.systemNoticeInboxOperationId
        )

        guard accountLease.subjectId == UserManager.shared.currentUser?.id,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        let snapshot = repository.inAppMessageCenterSnapshot(
            accountLease: accountLease,
            familyInvitationSources: familyInvitationSources,
            careSignalSources: careSignalSources,
            echoReplySources: echoReplySources,
            systemNoticeSources: systemNoticeSources
        )
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return nil }
        return snapshot
    }

    private func currentCareSignalMessageSources(
        accountLease: AccountLease
    ) -> [CareSignalMessageSource] {
        let contextOwnerId = DigitalHumanContextStore.shared.current.ownerId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = contextOwnerId.isEmpty ? accountLease.subjectId : contextOwnerId
        guard let signal = ProfileCareSignalMessageStore.shared.cachedSignal(userId: userId) else {
            return []
        }
        return [
            StaticCareSignalMessageSource(
                careSignalId: signal.id,
                careSignalTitle: signal.title,
                careSignalSummary: signal.summary,
                careSignalStatus: signal.status,
                careSignalSeverity: signal.severity,
                careSignalUpdatedAt: signal.updatedAt,
                careSignalOwnerUserId: signal.ownerUserId
            ),
        ]
    }

    private func presentInAppMessageCenter(
        _ snapshot: InAppMessageCenterSnapshot,
        accountLease: AccountLease,
        snapshotProvider: @escaping (AccountLease) -> InAppMessageCenterSnapshot?
    ) {
        guard accountLease.subjectId == UserManager.shared.currentUser?.id,
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
            showToast("账号状态已变化，请稍后重试", type: .info)
            return
        }
        let center = InAppMessageCenterViewController(
            snapshot: snapshot,
            repository: repository,
            accountLease: accountLease,
            snapshotProvider: snapshotProvider,
            onOpenMessage: { [weak self] message, capturedLease in
                self?.openInAppMessage(message, accountLease: capturedLease)
            },
            onShowAllTimeLetters: { [weak self] capturedLease in
                guard AccountLeaseRuntime.shared.validate(capturedLease, at: .ui).allowed else {
                    return
                }
                self?.navigationController?.popViewController(animated: true)
                self?.applyArchiveKindFilter(.timeLetter)
            },
            onMessageStateChanged: { [weak self] capturedLease in
                guard AccountLeaseRuntime.shared.validate(capturedLease, at: .ui).allowed else {
                    return
                }
                self?.refreshContent()
            }
        )
        if let navigationController {
            navigationController.pushViewController(center, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: center)
            present(navigationController, animated: true)
        }
    }

    private func openInAppMessage(_ message: InAppMessage, accountLease: AccountLease) {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        switch message.kind {
        case .timeLetter:
            guard let reminder = repository.timeLetterMailboxReminder(
                for: message,
                accountLease: accountLease
            ) else {
                showToast("时间信件暂不可打开", type: .error)
                return
            }
            openTimeLetterReminder(reminder, accountLease: accountLease)
        case .familyInvitation:
            openFamilyInvitationMessage(message)
        case .careSignal:
            openCareSignalMessage()
        case .systemNotice:
            openSystemNoticeMessage(message)
        case .echoReply:
            openEchoReplyMessage(message, accountLease: accountLease)
        }
    }

    private func openFamilyInvitationMessage(_ message: InAppMessage) {
        if let familyMemberId = message.familyMemberId,
           let member = FamilyRepository.shared.get(by: familyMemberId) {
            let detailViewController = FamilyMemberDetailViewController(member: member)
            navigationController?.pushViewController(detailViewController, animated: true)
            return
        }
        navigationController?.pushViewController(FamilyCircleViewController(), animated: true)
    }

    private func openCareSignalMessage() {
        guard let tabBarController else {
            navigationController?.pushViewController(ProfileViewController(), animated: true)
            return
        }
        tabBarController.selectedIndex = min(2, (tabBarController.viewControllers?.count ?? 1) - 1)
    }

    private func openSystemNoticeMessage(_ message: InAppMessage) {
        let alert = UIAlertController(
            title: message.title,
            message: message.summary,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func openEchoReplyMessage(
        _ message: InAppMessage,
        accountLease: AccountLease
    ) {
        guard EchoDelayedReplyAnswerReconciliationQAGate.isEnabled,
              DreamJourneyBackendClient.shared.isEchoDelayedReplyAnswerReconciliationQAConfigured,
              let reference = EchoReplyMessageStore.shared.inboxAnswerReference(
                  for: message,
                  accountLease: accountLease,
                  resourceOwnerId: accountLease.subjectId
              ) else {
            openEchoReplyMessage()
            return
        }

        delayedReplyInboxAnswerReader.read(reference, accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                    return
                }
                switch result {
                case .success(let contract):
                    self.presentQADelayedReplyAnswer(contract.answer.body)
                case .failure:
                    self.showToast("回响回信暂不可读取，请稍后重试", type: .info)
                }
            }
        }
    }

    private func presentQADelayedReplyAnswer(_ body: String) {
        let alert = UIAlertController(
            title: "回响回信",
            message: body,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "继续回响", style: .default) { [weak self] _ in
            self?.openEchoReplyMessage()
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        let presenter = navigationController?.topViewController ?? self
        presenter.present(alert, animated: true)
    }

    private func openEchoReplyMessage() {
        guard let tabBarController else {
            navigationController?.pushViewController(EchoViewController(), animated: true)
            return
        }
        tabBarController.selectedIndex = min(1, (tabBarController.viewControllers?.count ?? 1) - 1)
    }

    private func openTimeLetterReminder(
        _ reminder: TimeLetterMailboxReminder,
        accountLease: AccountLease
    ) {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            showToast("账号已切换，请重新打开消息中心", type: .info)
            return
        }
        showToast("正在打开时间信件", type: .info)
        repository.resolveTimeLetterReminderDetail(reminder) { [weak self] result in
            guard let self else { return }
            guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
                showToast("账号已切换，请重新打开消息中心", type: .info)
                return
            }
            switch result {
            case .success(let item):
                let detailViewController = MemoryArchiveDetailViewController(item: item, repository: repository, isReadOnly: true)
                navigationController?.pushViewController(detailViewController, animated: true)
            case .failure(let error):
                showToast(error.localizedDescription.isEmpty ? "时间信件暂不可打开" : error.localizedDescription, type: .error)
                applyArchiveKindFilter(.timeLetter)
            }
        }
    }

    private func applyArchiveKindFilter(_ filter: ArchiveKindFilter) {
        activeKindFilter = filter
        refreshContent()
        scrollToArchiveList()
    }

    private func scrollToArchiveList() {
        view.layoutIfNeeded()
        let targetRect = listStack.convert(listStack.bounds, to: scrollView)
        scrollView.scrollRectToVisible(
            targetRect.insetBy(dx: 0, dy: -24),
            animated: true
        )
    }

    @objc private func mapFootprintTapped() {
        guard isTimeLetterCreationEnabled,
              let currentUser = UserManager.shared.currentUser else {
            showToast("请先登录后查看足迹", type: .info)
            return
        }
        let viewController = MapFootprintViewController(
            viewMode: .host,
            ownerId: currentUser.id,
            ownerName: currentUser.nickname
        )
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func presentTextEntry(kind: MemoryArchiveItemKind) {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }
        guard let accountLease = captureMediaAccountLease() else {
            showToast("账号状态已变化，请重新进入档案馆", type: .error)
            return
        }
        let archiveContext = currentArchiveContext

        let isTimeLetter = kind == .timeLetter
        let entryViewController = MemoryArchiveTextEntryViewController(
            kind: kind,
            accountLease: accountLease
        )
        if isTimeLetter {
            entryViewController.onSaveTimeLetter = { [weak self] payload in
                guard let self,
                      self.validateMediaOperation(
                        accountLease,
                        archiveContext: archiveContext,
                        at: .commit
                      ) else {
                    if let imageMediaMetadata = payload.imageMediaMetadata {
                        self?.removeArchiveMedia(imageMediaMetadata, accountLease: accountLease)
                    }
                    return
                }
                let item = MemoryArchiveItemFactory.makeTimeLetter(
                    note: payload.note,
                    openAt: payload.openAt,
                    recipients: payload.recipients,
                    imageLocalPath: payload.imageLocalPath,
                    imageMediaMetadata: payload.imageMediaMetadata,
                    ownerUserId: accountLease.subjectId
                )
                guard self.repository.add(item) else {
                    if let imageMediaMetadata = payload.imageMediaMetadata {
                        self.removeArchiveMedia(imageMediaMetadata, accountLease: accountLease)
                    }
                    self.showToast("时间信件保存失败，请稍后重试", type: .error)
                    return
                }
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .ui
                ) else { return }
                self.refreshContent()
                self.showToast("时间信件已封存", type: .success)
            }
            entryViewController.onSaveDraftTimeLetter = { [weak self] payload in
                guard let self,
                      self.validateMediaOperation(
                        accountLease,
                        archiveContext: archiveContext,
                        at: .commit
                      ) else {
                    if let imageMediaMetadata = payload.imageMediaMetadata {
                        self?.removeArchiveMedia(imageMediaMetadata, accountLease: accountLease)
                    }
                    return
                }
                let item = MemoryArchiveItemFactory.makeTimeLetterDraft(
                    note: payload.note,
                    openAt: payload.openAt,
                    recipients: payload.recipients,
                    imageLocalPath: payload.imageLocalPath,
                    imageMediaMetadata: payload.imageMediaMetadata,
                    ownerUserId: accountLease.subjectId
                )
                guard self.repository.add(item) else {
                    if let imageMediaMetadata = payload.imageMediaMetadata {
                        self.removeArchiveMedia(imageMediaMetadata, accountLease: accountLease)
                    }
                    self.showToast("草稿保存失败，请稍后重试", type: .error)
                    return
                }
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .ui
                ) else { return }
                self.refreshContent()
                self.showToast("时间信件草稿已保存", type: .success)
            }
        } else {
            entryViewController.onSave = { [weak self] rawText in
                guard let self,
                      self.validateMediaOperation(
                        accountLease,
                        archiveContext: archiveContext,
                        at: .commit
                      ) else { return }
                let item = MemoryArchiveItemFactory.makeTextItem(
                    note: rawText,
                    ownerUserId: accountLease.subjectId
                )
                guard self.repository.add(item) else {
                    self.showToast("文字记忆保存失败，请稍后重试", type: .error)
                    return
                }
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .ui
                ) else { return }
                self.refreshContent()
                self.showToast("已封存", type: .success)
            }
        }
        present(entryViewController, animated: true)
    }

    private func presentAudioEntry() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }
        guard let accountLease = captureMediaAccountLease() else {
            showToast("账号状态已变化，请重新进入档案馆", type: .error)
            return
        }
        let archiveContext = currentArchiveContext

        let entryViewController = MemoryArchiveAudioRecorderViewController(accountLease: accountLease)
        entryViewController.onSave = { [weak self] mediaMetadata, duration, note in
            guard let self,
                  self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .commit
                  ) else {
                self?.removeArchiveMedia(mediaMetadata, accountLease: accountLease)
                return
            }
            let item = MemoryArchiveItemFactory.makeAudioItem(
                localPath: mediaMetadata.relativePath,
                duration: duration,
                note: note,
                mediaMetadata: mediaMetadata,
                ownerUserId: accountLease.subjectId
            )
            guard self.repository.add(item) else {
                self.removeArchiveMedia(mediaMetadata, accountLease: accountLease)
                self.showToast("语音保存失败，请稍后重试", type: .error)
                return
            }
            guard self.validateMediaOperation(
                accountLease,
                archiveContext: archiveContext,
                at: .ui
            ) else { return }
            self.refreshContent()
            self.showToast("语音已封存", type: .success)
        }
        present(entryViewController, animated: true)
    }

    private func presentVideoEntry() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }
        guard let accountLease = captureMediaAccountLease() else {
            showToast("账号状态已变化，请重新进入档案馆", type: .error)
            return
        }
        let archiveContext = currentArchiveContext

        let entryViewController = MemoryArchiveVideoEntryViewController()
        entryViewController.onCreateMockVideoArchive = { [weak self] in
            guard let self,
                  self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .commit
                  ) else { return }
            do {
                let item = try self.makeHiddenQAMockVideoArchiveItem(accountLease: accountLease)
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .commit
                ) else {
                    self.removeArchiveMedia(for: item, accountLease: accountLease)
                    return
                }
                guard self.repository.add(item) else {
                    self.removeArchiveMedia(for: item, accountLease: accountLease)
                    self.showToast("测试视频档案保存失败", type: .error)
                    return
                }
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .ui
                ) else { return }
                self.refreshContent()
                self.showToast("测试视频档案已生成", type: .success)
            } catch {
                self.showToast("测试视频档案生成失败", type: .error)
            }
        }
        present(entryViewController, animated: true)
    }

    private func makeHiddenQAMockVideoArchiveItem(
        accountLease: AccountLease
    ) throws -> MemoryArchiveItem {
        guard validateMediaAccountLease(accountLease, at: .commit) else {
            throw ArchiveImageSaveError.accountSessionChanged
        }
        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        guard scope.isValid else { throw ArchiveImageSaveError.accountSessionChanged }
        let mockVideoData = Data("DreamJourney hidden QA mock video placeholder".utf8)
        let videoMetadata = try mediaStore.write(
            mockVideoData,
            fileExtension: "mov",
            scope: scope,
            storageClass: .original
        )

        let thumbnailImage = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 96)).image { context in
            DJDesignTokens.Color.surfaceContainer.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 96))
            DJDesignTokens.Color.accentDeep.setFill()
            context.fill(CGRect(x: 56, y: 28, width: 48, height: 40))
        }
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.72) else {
            try? mediaStore.remove(videoMetadata, scope: scope, storageClass: .original)
            throw NSError(
                domain: "DreamJourney.Archive.VideoShell",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode mock thumbnail"]
            )
        }
        let thumbnailMetadata: ArchiveMediaMetadata
        do {
            thumbnailMetadata = try mediaStore.write(
                thumbnailData,
                fileExtension: "jpg",
                scope: scope,
                storageClass: .thumbnail
            )
        } catch {
            try? mediaStore.remove(videoMetadata, scope: scope, storageClass: .original)
            throw error
        }
        guard validateMediaAccountLease(accountLease, at: .commit) else {
            try? mediaStore.remove(videoMetadata, scope: scope, storageClass: .original)
            try? mediaStore.remove(thumbnailMetadata, scope: scope, storageClass: .thumbnail)
            throw ArchiveImageSaveError.accountSessionChanged
        }

        return MemoryArchiveItemFactory.makeVideoItem(
            localPath: videoMetadata.relativePath,
            thumbnailPath: thumbnailMetadata.relativePath,
            fileSizeBytes: videoMetadata.sizeBytes,
            note: "隐藏 QA 生成的 mock 视频档案。",
            mediaMetadata: videoMetadata,
            thumbnailMetadata: thumbnailMetadata,
            ownerUserId: accountLease.subjectId
        )
    }

    private func presentPhotoEntry() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        let entryViewController = MemoryArchivePhotoEntryViewController()
        entryViewController.onChoosePhoto = { [weak self] in
            self?.presentPhotoPicker()
        }
        entryViewController.onUseSamplePhoto = { [weak self] in
            self?.saveSamplePhotoToArchive()
        }
        present(entryViewController, animated: true)
    }

    private func presentPhotoPicker() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showToast("无法打开相册", type: .error)
            return
        }

        guard let accountLease = captureMediaAccountLease() else {
            showToast("账号状态已变化，请重新进入档案馆", type: .error)
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        photoPickerAccountLease = accountLease
        photoPickerArchiveContext = currentArchiveContext
        present(picker, animated: true)
    }

    private func captureMediaAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              validateMediaAccountLease(accountLease, at: .request) else {
            return nil
        }
        return accountLease
    }

    private func validateMediaAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func validateMediaOperation(
        _ accountLease: AccountLease,
        archiveContext: DigitalHumanContext,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        validateMediaAccountLease(accountLease, at: checkpoint)
            && archiveContext == currentArchiveContext
    }

    private func validatePhotoPickerOperation(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        validateMediaAccountLease(accountLease, at: checkpoint)
            && photoPickerAccountLease == accountLease
            && photoPickerArchiveContext == currentArchiveContext
            && isSelfAutobiographyMode
    }

    private func clearPhotoPickerOperation() {
        photoPickerAccountLease = nil
        photoPickerArchiveContext = nil
    }

    private func removeArchiveMedia(
        _ mediaMetadata: ArchiveMediaMetadata,
        accountLease: AccountLease,
        storageClass: ArchiveMediaStorageClass = .original
    ) {
        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        try? mediaStore.remove(
            mediaMetadata,
            scope: scope,
            storageClass: storageClass
        )
    }

    private func removeArchiveMedia(
        for item: MemoryArchiveItem,
        accountLease: AccountLease
    ) {
        if let mediaMetadata = item.localMediaMetadata {
            removeArchiveMedia(mediaMetadata, accountLease: accountLease)
        }
        if let thumbnailMetadata = item.localThumbnailMetadata {
            removeArchiveMedia(
                thumbnailMetadata,
                accountLease: accountLease,
                storageClass: .thumbnail
            )
        }
    }

    private func saveImageToArchive(
        _ image: UIImage,
        accountLease: AccountLease
    ) throws -> ArchiveMediaMetadata {
        guard validateMediaAccountLease(accountLease, at: .commit) else {
            throw ArchiveImageSaveError.accountSessionChanged
        }
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw ArchiveImageSaveError.jpegEncodingFailed
        }

        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        guard scope.isValid else { throw ArchiveImageSaveError.accountSessionChanged }
        let mediaMetadata = try mediaStore.write(
            data,
            fileExtension: "jpg",
            scope: scope,
            storageClass: .original
        )
        guard validateMediaAccountLease(accountLease, at: .commit) else {
            try? mediaStore.remove(mediaMetadata, scope: scope, storageClass: .original)
            throw ArchiveImageSaveError.accountSessionChanged
        }
        return mediaMetadata
    }

    private func imageBase64ForArchiveAnalysis(_ image: UIImage) -> String? {
        image.jpegData(compressionQuality: 0.72)?.base64EncodedString()
    }

    private func savePhotoArchiveItem(
        _ item: MemoryArchiveItem,
        image: UIImage,
        successMessage: String,
        accountLease: AccountLease,
        archiveContext: DigitalHumanContext
    ) {
        guard isSelfAutobiographyMode,
              validateMediaOperation(
                accountLease,
                archiveContext: archiveContext,
                at: .commit
              ) else {
            removeArchiveMedia(for: item, accountLease: accountLease)
            return
        }

        guard repository.add(item) else {
            removeArchiveMedia(for: item, accountLease: accountLease)
            showToast("照片保存失败，请稍后重试", type: .error)
            return
        }
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .ui
        ) else { return }
        refreshContent()
        showToast(successMessage, type: .success)
        analyzePhotoArchiveItemIfPossible(
            item,
            image: image,
            accountLease: accountLease,
            archiveContext: archiveContext
        )
    }

    private func analyzePhotoArchiveItemIfPossible(
        _ item: MemoryArchiveItem,
        image: UIImage,
        accountLease: AccountLease,
        archiveContext: DigitalHumanContext
    ) {
        guard validateMediaOperation(
                accountLease,
                archiveContext: archiveContext,
                at: .request
              ),
              DreamJourneyBackendClient.shared.isArchiveImageAnalysisConfigured else {
            return
        }

        DreamJourneyBackendClient.shared.fetchArchiveImageAnalysisRuntimeCapability { [weak self] result in
            guard let self,
                  self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .runtime
                  ) else { return }
            switch result {
            case .success(let capability):
                guard capability.canRunVisionAnalysis else {
                    markArchiveImageAnalysisUnavailable(
                        item,
                        capability: capability,
                        accountLease: accountLease,
                        archiveContext: archiveContext
                    )
                    return
                }
                requestRemoteArchiveImageAnalysis(
                    item,
                    image: image,
                    accountLease: accountLease,
                    archiveContext: archiveContext
                )
            case .failure(let error):
                markArchiveImageAnalysisFailed(
                    item,
                    reason: archiveAnalysisFailureReason(error),
                    accountLease: accountLease,
                    archiveContext: archiveContext
                )
            }
        }
    }

    private func requestRemoteArchiveImageAnalysis(
        _ item: MemoryArchiveItem,
        image: UIImage,
        accountLease: AccountLease,
        archiveContext: DigitalHumanContext
    ) {
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .request
        ) else {
            return
        }
        guard let imageBase64 = imageBase64ForArchiveAnalysis(image) else {
            guard validateMediaOperation(
                accountLease,
                archiveContext: archiveContext,
                at: .commit
            ) else { return }
            var updatedItem = item
            updatedItem.markAnalysisFailed(reason: "image_encoding_failed")
            repository.update(updatedItem, syncToBackend: true)
            guard validateMediaOperation(
                accountLease,
                archiveContext: archiveContext,
                at: .ui
            ) else { return }
            refreshContent()
            showToast("照片分析失败，可稍后重试", type: .error)
            return
        }

        DreamJourneyBackendClient.shared.requestArchiveImageAnalysis(
            userId: accountLease.subjectId,
            archiveItemId: item.id,
            imageBase64: imageBase64
        ) { [weak self] result in
            guard let self,
                  self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .runtime
                  ) else { return }
            var updatedItem = item
            switch result {
            case .success(let object):
                updatedItem.applyRemoteImageAnalysisResult(object)
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .commit
                ) else { return }
                repository.update(updatedItem, syncToBackend: true)
                guard self.validateMediaOperation(
                    accountLease,
                    archiveContext: archiveContext,
                    at: .ui
                ) else { return }
                refreshContent()
                if updatedItem.analysisStatus.isRetryableFailureLike {
                    showToast("AI 分析暂不可用，可稍后重试", type: .error)
                } else {
                    showToast("已生成图像分析", type: .success)
                }
            case .failure(let error):
                markArchiveImageAnalysisFailed(
                    item,
                    reason: archiveAnalysisFailureReason(error),
                    accountLease: accountLease,
                    archiveContext: archiveContext
                )
            }
        }
    }

    private func markArchiveImageAnalysisUnavailable(
        _ item: MemoryArchiveItem,
        capability: ArchiveImageAnalysisRuntimeCapability,
        accountLease: AccountLease,
        archiveContext: DigitalHumanContext
    ) {
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .commit
        ) else { return }
        var updatedItem = item
        updatedItem.markAnalysisUnavailableFromRuntime(
            provider: capability.provider,
            fallbackMode: capability.fallbackMode,
            message: capability.availabilityDisplayText
        )
        repository.update(updatedItem, syncToBackend: true)
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .ui
        ) else { return }
        refreshContent()
        showToast(capability.availabilityDisplayText, type: .error)
    }

    private func markArchiveImageAnalysisFailed(
        _ item: MemoryArchiveItem,
        reason: String,
        accountLease: AccountLease,
        archiveContext: DigitalHumanContext
    ) {
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .commit
        ) else { return }
        var updatedItem = item
        updatedItem.markAnalysisFailed(reason: reason)
        repository.update(updatedItem, syncToBackend: true)
        guard validateMediaOperation(
            accountLease,
            archiveContext: archiveContext,
            at: .ui
        ) else { return }
        refreshContent()
        showToast("AI 分析暂不可用，可稍后重试", type: .error)
    }

    private func archiveAnalysisFailureReason(_ error: Error) -> String {
        let normalized = error.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "backend_image_analysis_failed" : String(normalized.prefix(80))
    }

    private func saveSamplePhotoToArchive() {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        let image = UIImage(named: "default_memory_1") ?? makeFallbackArchiveImage()
        let archiveContext = currentArchiveContext
        guard let accountLease = captureMediaAccountLease() else {
            showToast("账号状态已变化，请重新进入档案馆", type: .error)
            return
        }
        do {
            let mediaMetadata = try saveImageToArchive(image, accountLease: accountLease)
            let item = MemoryArchiveItemFactory.makePhotoItem(
                localPath: mediaMetadata.relativePath,
                source: .samplePhoto,
                mediaMetadata: mediaMetadata,
                ownerUserId: accountLease.subjectId
            )
            savePhotoArchiveItem(
                item,
                image: image,
                successMessage: "照片已封存",
                accountLease: accountLease,
                archiveContext: archiveContext
            )
        } catch {
            showToast("照片保存失败", type: .error)
        }
    }

    private func makeFallbackArchiveImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 640))
        return renderer.image { context in
            DJDesignTokens.Color.surfaceContainer.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 640))
            DJDesignTokens.Color.accent.withAlphaComponent(0.28).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 620, y: 80, width: 180, height: 180))
            DJDesignTokens.Color.accentDeep.withAlphaComponent(0.20).setFill()
            context.cgContext.fill(CGRect(x: 0, y: 440, width: 900, height: 200))
        }
    }

    private func showReadOnlyArchiveToast() {
        showToast("家人故事仅可阅读，切回自己后可管理我的自传", type: .info)
    }
}

// MARK: - Default-off formal candidate confirmation

final class OwnerTruthInterviewCandidateMemoryActivationInboxViewController: UIViewController {
    private let accountLease: AccountLease
    private let useCase: OwnerTruthInterviewCandidateMemoryActivationInboxUseCase
    private let projectionRecoveryUseCase: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase
    private let activationClient: OwnerTruthInterviewCandidateMemoryActivationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let projectionRecoverySummaryLabel = UILabel()
    private var projectionRecoverySummaryHeightConstraint: NSLayoutConstraint!
    private let emptyStateLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState = OwnerTruthInterviewCandidateMemoryActivationInboxViewState.idle
    private var activationUseCase: OwnerTruthInterviewCandidateMemoryActivationUseCase?

    init(
        accountLease: AccountLease,
        inboxClient: OwnerTruthInterviewCandidateMemoryActivationInboxClient = DreamJourneyBackendClient.shared,
        projectionRecoveryInboxClient: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient = DreamJourneyBackendClient.shared,
        activationClient: OwnerTruthInterviewCandidateMemoryActivationClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = {
            FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview).allowed
        }
    ) {
        self.accountLease = accountLease
        self.activationClient = activationClient
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        useCase = OwnerTruthInterviewCandidateMemoryActivationInboxUseCase(
            accountLease: accountLease,
            client: inboxClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        projectionRecoveryUseCase = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase(
            accountLease: accountLease,
            client: projectionRecoveryInboxClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "纳入正式记忆"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "owner-truth-memory-activation-inbox"
        navigationItem.rightBarButtonItem = refreshButton
        configureHeader()
        configureTableView()
        configureUseCase()
        configureProjectionRecoveryUseCase()
        render(useCase.viewState)
        renderProjectionRecovery(projectionRecoveryUseCase.viewState)
        useCase.send(.refresh)
        projectionRecoveryUseCase.send(.refresh)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    private func configureHeader() {
        statusLabel.font = DJDesignTokens.Font.body(14)
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        statusLabel.numberOfLines = 0
        statusLabel.text = "已确认的记忆线索，等待你明确纳入正式记忆。"
        statusLabel.accessibilityIdentifier = "owner-truth-memory-activation-inbox-status"
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        projectionRecoverySummaryLabel.font = DJDesignTokens.Font.body(14)
        projectionRecoverySummaryLabel.textColor = DJDesignTokens.Color.textSecondary
        projectionRecoverySummaryLabel.numberOfLines = 0
        projectionRecoverySummaryLabel.isHidden = true
        projectionRecoverySummaryLabel.accessibilityIdentifier = "owner-truth-memory-projection-recovery-summary"
        view.addSubview(projectionRecoverySummaryLabel)
        projectionRecoverySummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        projectionRecoverySummaryHeightConstraint = projectionRecoverySummaryLabel.heightAnchor.constraint(equalToConstant: 0)
        projectionRecoverySummaryHeightConstraint.isActive = true
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            OwnerTruthCandidateMemoryActivationInboxCell.self,
            forCellReuseIdentifier: OwnerTruthCandidateMemoryActivationInboxCell.reuseIdentifier
        )
        tableView.accessibilityIdentifier = "owner-truth-memory-activation-inbox-list"

        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.accessibilityIdentifier = "owner-truth-memory-activation-inbox-empty"
        tableView.backgroundView = emptyStateLabel

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            projectionRecoverySummaryLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            projectionRecoverySummaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            projectionRecoverySummaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            tableView.topAnchor.constraint(equalTo: projectionRecoverySummaryLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func configureProjectionRecoveryUseCase() {
        projectionRecoveryUseCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                renderProjectionRecovery(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.renderProjectionRecovery(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewCandidateMemoryActivationInboxViewState) {
        renderedState = state
        let isActivating = activationUseCase?.viewState.phase == .activating
        refreshButton.isEnabled = state.phase != .loading && !isActivating
        if !isActivating {
            statusLabel.text = statusText(for: state)
        }
        emptyStateLabel.text = emptyText(for: state)
        emptyStateLabel.isHidden = emptyStateLabel.text == nil
        tableView.isUserInteractionEnabled = state.phase == .ready && !isActivating
        tableView.reloadData()
    }

    /// This read is intentionally non-blocking: failure or absence of the
    /// server-side materialization summary must never alter activation actions.
    private func renderProjectionRecovery(
        _ state: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState
    ) {
        guard state.phase == .ready,
              let itemCount = state.inbox?.items.count,
              itemCount > 0 else {
            projectionRecoverySummaryLabel.text = nil
            projectionRecoverySummaryLabel.isHidden = true
            projectionRecoverySummaryHeightConstraint.isActive = true
            return
        }
        projectionRecoverySummaryLabel.text = "\(itemCount) 项正式记忆正在整理，完成后将自动可用。"
        projectionRecoverySummaryLabel.isHidden = false
        projectionRecoverySummaryHeightConstraint.isActive = false
    }

    private func statusText(for state: OwnerTruthInterviewCandidateMemoryActivationInboxViewState) -> String {
        switch state.phase {
        case .idle:
            return "正在准备待纳入的正式记忆。"
        case .unavailable:
            return "待纳入正式记忆暂未开放。"
        case .loading:
            return "正在读取待纳入的正式记忆。"
        case .ready:
            return "已确认的记忆线索，等待你明确纳入正式记忆。"
        case .empty:
            return "当前没有等待纳入正式记忆的线索。"
        case .failed:
            return "暂时无法读取待纳入的正式记忆，请稍后重试。"
        }
    }

    private func emptyText(for state: OwnerTruthInterviewCandidateMemoryActivationInboxViewState) -> String? {
        switch state.phase {
        case .empty:
            return "你确认的记忆线索会在这里等待你明确纳入正式记忆。"
        case .unavailable:
            return "该功能仅会在获准的发布策略下开放。"
        case .failed:
            return "请点右上角重新载入。"
        default:
            return nil
        }
    }

    private func presentActivationConfirmation(
        item: OwnerTruthInterviewCandidateMemoryActivationInboxItem,
        inbox: OwnerTruthInterviewCandidateMemoryActivationInbox
    ) {
        let alert = UIAlertController(
            title: "纳入正式记忆",
            message: "这项已确认的记忆线索将被明确纳入正式记忆。请确认后继续。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认纳入", style: .default) { [weak self] _ in
            self?.activate(item: item, from: inbox)
        })
        present(alert, animated: true)
    }

    private func activate(
        item: OwnerTruthInterviewCandidateMemoryActivationInboxItem,
        from inbox: OwnerTruthInterviewCandidateMemoryActivationInbox
    ) {
        guard releasePolicyAvailable(),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              inbox.isBound(to: accountLease),
              inbox.items.contains(item) else {
            failClosedForUnavailableState()
            return
        }

        let activationUseCase = OwnerTruthInterviewCandidateMemoryActivationUseCase(
            accountLease: accountLease,
            activationInbox: inbox,
            item: item,
            client: activationClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        self.activationUseCase = activationUseCase
        activationUseCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                handleActivationState(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.handleActivationState(state)
                }
            }
        }
        activationUseCase.send(.activate)
    }

    private func handleActivationState(_ state: OwnerTruthInterviewCandidateMemoryActivationViewState) {
        switch state.phase {
        case .idle:
            break
        case .activating:
            refreshButton.isEnabled = false
            tableView.isUserInteractionEnabled = false
            statusLabel.text = "正在纳入正式记忆。"
        case .activated:
            activationUseCase = nil
            refreshButton.isEnabled = false
            tableView.isUserInteractionEnabled = false
            statusLabel.text = "已纳入正式记忆，正在刷新待办。"
            useCase.send(.refresh)
        case .failed:
            activationUseCase = nil
            statusLabel.text = "暂时无法纳入正式记忆，请稍后重试。"
            refreshButton.isEnabled = renderedState.phase != .loading
            tableView.isUserInteractionEnabled = renderedState.phase == .ready
        case .unavailable:
            activationUseCase = nil
            failClosedForUnavailableState()
        }
    }

    private func failClosedForUnavailableState() {
        activationUseCase = nil
        refreshButton.isEnabled = false
        tableView.isUserInteractionEnabled = false
        statusLabel.text = "当前无法纳入正式记忆。"
        useCase.send(.refresh)
    }

    @objc private func refreshTapped() {
        guard activationUseCase == nil else { return }
        useCase.send(.refresh)
        projectionRecoveryUseCase.send(.refresh)
    }
}

extension OwnerTruthInterviewCandidateMemoryActivationInboxViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        renderedState.inbox?.items.count ?? 0
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OwnerTruthCandidateMemoryActivationInboxCell.reuseIdentifier,
            for: indexPath
        ) as! OwnerTruthCandidateMemoryActivationInboxCell
        if let item = renderedState.inbox?.items[indexPath.row] {
            cell.configure(item)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard releasePolicyAvailable(),
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed,
              let inbox = renderedState.inbox,
              inbox.isBound(to: accountLease),
              inbox.items.indices.contains(indexPath.row),
              activationUseCase == nil else {
            failClosedForUnavailableState()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        presentActivationConfirmation(item: inbox.items[indexPath.row], inbox: inbox)
    }
}

private final class OwnerTruthCandidateMemoryActivationInboxCell: UITableViewCell {
    static let reuseIdentifier = "OwnerTruthCandidateMemoryActivationInboxCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = DJDesignTokens.Color.surface
        selectionStyle = .default
        titleLabel.font = DJDesignTokens.Font.body(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        detailLabel.font = DJDesignTokens.Font.label(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
        accessibilityIdentifier = "owner-truth-memory-activation-inbox-item"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_: OwnerTruthInterviewCandidateMemoryActivationInboxItem) {
        titleLabel.text = "已确认的记忆线索"
        detailLabel.text = "等待你明确纳入正式记忆"
        accessibilityLabel = "已确认的记忆线索，等待你明确纳入正式记忆"
    }
}

final class OwnerTruthInterviewCandidateConfirmationInboxViewController: UIViewController {
    private let accountLease: AccountLease
    private let focusedReviewBatchID: OwnerTruthRecordID?
    private let useCase: OwnerTruthInterviewCandidateConfirmationInboxUseCase
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState = OwnerTruthInterviewCandidateConfirmationInboxViewState.idle
    private var visibleItems: [OwnerTruthInterviewCandidateConfirmationInboxItem] = []

    /// Simulator-only observation for the focused handoff smoke. It exposes
    /// opaque review-batch handles only, never Candidate content or decisions.
    var focusedReviewBatchIDForUIQA: OwnerTruthRecordID? { focusedReviewBatchID }
    var visibleReviewBatchIDsForUIQA: [OwnerTruthRecordID] {
        visibleItems.map(\.reviewBatchID)
    }

    init(
        accountLease: AccountLease,
        focusedReviewBatchID: OwnerTruthRecordID? = nil,
        client: OwnerTruthInterviewCandidateConfirmationInboxClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = {
            FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview).allowed
        }
    ) {
        self.accountLease = accountLease
        self.focusedReviewBatchID = focusedReviewBatchID
        useCase = OwnerTruthInterviewCandidateConfirmationInboxUseCase(
            accountLease: accountLease,
            focusedReviewBatchID: focusedReviewBatchID,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = focusedReviewBatchID == nil ? "待确认记忆" : "本次待确认记忆"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        configureHeader()
        configureTableView()
        configureUseCase()
        render(useCase.viewState)
        useCase.send(.refresh)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    private func configureHeader() {
        statusLabel.font = DJDesignTokens.Font.body(14)
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        statusLabel.numberOfLines = 0
        statusLabel.text = "确认后只记录审核结果，暂不会写入正式记忆。"
        statusLabel.accessibilityIdentifier = "owner-truth-candidate-confirmation-inbox-status"
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            OwnerTruthCandidateConfirmationInboxCell.self,
            forCellReuseIdentifier: OwnerTruthCandidateConfirmationInboxCell.reuseIdentifier
        )
        tableView.accessibilityIdentifier = "owner-truth-candidate-confirmation-inbox-list"

        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        tableView.backgroundView = emptyStateLabel

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewCandidateConfirmationInboxViewState) {
        renderedState = state
        visibleItems = visibleItems(for: state)
        refreshButton.isEnabled = state.phase != .loading
            && (state.phase != .unavailable || state.notice == .contextChanged)
        statusLabel.text = statusText(for: state)
        emptyStateLabel.text = emptyText(for: state)
        emptyStateLabel.isHidden = emptyStateLabel.text == nil
        tableView.reloadData()
    }

    private func statusText(for state: OwnerTruthInterviewCandidateConfirmationInboxViewState) -> String {
        switch state.phase {
        case .idle:
            return "正在准备待确认记忆。"
        case .unavailable:
            switch state.notice {
            case .contentUnavailable:
                return focusedReviewBatchID == nil
                    ? "待确认内容已更新，当前不可用。"
                    : "本次待确认内容已失效，无法继续确认。"
            case .contextChanged:
                return "待确认内容已更新，请重新载入。"
            case .releasePolicyDisabled:
                return "待确认记忆暂未开放。"
            case .invalidVault, .accountUnavailable, .staleAccountLease, .requestFailed, nil:
                return "待确认记忆暂未开放。"
            }
        case .loading:
            return "正在读取待确认记忆。"
        case .ready:
            return focusedReviewBatchID == nil || !visibleItems.isEmpty
                ? "确认后只记录审核结果，暂不会写入正式记忆。"
                : "本次整理尚未准备好待确认内容。"
        case .empty:
            return "当前没有需要你确认的记忆。"
        case .failed:
            return "暂时无法读取待确认记忆，请稍后重试。"
        }
    }

    private func emptyText(for state: OwnerTruthInterviewCandidateConfirmationInboxViewState) -> String? {
        switch state.phase {
        case .empty:
            return focusedReviewBatchID == nil
                ? "你的访谈线索确认完成后，会在这里等待你确认。"
                : "本次整理完成后，待确认内容会出现在这里。"
        case .ready where focusedReviewBatchID != nil && visibleItems.isEmpty:
            return "本次整理尚未准备好待确认内容。"
        case .unavailable:
            switch state.notice {
            case .contentUnavailable, .contextChanged:
                return nil
            case .releasePolicyDisabled, .invalidVault, .accountUnavailable, .staleAccountLease,
                 .requestFailed, nil:
                return "该功能仅会在获准的发布策略下开放。"
            }
        case .failed:
            return "请点右上角重新载入。"
        default:
            return nil
        }
    }

    private func visibleItems(
        for state: OwnerTruthInterviewCandidateConfirmationInboxViewState
    ) -> [OwnerTruthInterviewCandidateConfirmationInboxItem] {
        guard let focusedReviewBatchID else {
            return state.inbox?.items ?? []
        }
        return (state.inbox?.items ?? []).filter {
            $0.reviewBatchID == focusedReviewBatchID && $0.readiness == .reviewReady
        }
    }

    @objc private func refreshTapped() {
        useCase.send(.refresh)
    }
}

extension OwnerTruthInterviewCandidateConfirmationInboxViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleItems.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OwnerTruthCandidateConfirmationInboxCell.reuseIdentifier,
            for: indexPath
        ) as! OwnerTruthCandidateConfirmationInboxCell
        if visibleItems.indices.contains(indexPath.row) {
            let item = visibleItems[indexPath.row]
            cell.configure(item)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let inbox = renderedState.inbox,
              inbox.isBound(to: accountLease),
              visibleItems.indices.contains(indexPath.row) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            OwnerTruthInterviewCandidateConfirmationViewController(
                accountLease: accountLease,
                reviewBatchID: visibleItems[indexPath.row].reviewBatchID
            ),
            animated: true
        )
    }
}

private final class OwnerTruthCandidateConfirmationInboxCell: UITableViewCell {
    static let reuseIdentifier = "OwnerTruthCandidateConfirmationInboxCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = DJDesignTokens.Color.surface
        accessoryType = .disclosureIndicator
        titleLabel.font = DJDesignTokens.Font.body(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        detailLabel.font = DJDesignTokens.Font.label(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ item: OwnerTruthInterviewCandidateConfirmationInboxItem) {
        titleLabel.text = "一组待确认线索"
        let readiness: String
        switch item.readiness {
        case .reviewReady: readiness = "可确认"
        case .noCandidates: readiness = "暂无候选"
        case .awaitingExtraction: readiness = "整理中"
        case .extractionFailed: readiness = "整理失败"
        case .extractionQuarantined: readiness = "等待处理"
        }
        detailLabel.text = "普通线索 \(item.batchCandidateCount) 条 · 逐条确认 \(item.singleCandidateCount) 条 · \(readiness)"
        accessibilityLabel = "\(titleLabel.text ?? "")，\(detailLabel.text ?? "")"
    }
}

final class OwnerTruthInterviewCandidateConfirmationViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case batch
        case single

        var title: String {
            switch self {
            case .batch: return "可确认的普通线索"
            case .single: return "需要逐条确认"
            }
        }
    }

    private let accountLease: AccountLease
    private let readUseCase: OwnerTruthInterviewCandidateConfirmationUseCase
    private let batchActionClient: OwnerTruthInterviewCandidateConfirmationActionClient
    private let singleActionClient: OwnerTruthInterviewCandidateConfirmationSingleActionClient
    private let confirmationClient: OwnerTruthInterviewCandidateConfirmationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private let confirmSelectionButton = UIButton(type: .system)
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState = OwnerTruthInterviewCandidateConfirmationViewState.idle
    private var selectedBatchCandidateIDs = Set<OwnerTruthRecordID>()
    private var batchActionUseCase: OwnerTruthInterviewCandidateConfirmationActionUseCase?
    private var singleActionUseCase: OwnerTruthInterviewCandidateConfirmationSingleActionUseCase?
    private var isRefreshingAfterCandidateAction = false
    private var isCandidateActionInFlight = false
    private var actionConfigurationGeneration: UInt = 0
    private var candidateActionReloadStatusText: String?

    init(
        accountLease: AccountLease,
        reviewBatchID: OwnerTruthRecordID,
        confirmationClient: OwnerTruthInterviewCandidateConfirmationClient = DreamJourneyBackendClient.shared,
        batchActionClient: OwnerTruthInterviewCandidateConfirmationActionClient = DreamJourneyBackendClient.shared,
        singleActionClient: OwnerTruthInterviewCandidateConfirmationSingleActionClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = {
            FeatureGateService.shared.requestDecision(for: .ownerTruthCandidateReview).allowed
        }
    ) {
        self.accountLease = accountLease
        self.confirmationClient = confirmationClient
        self.batchActionClient = batchActionClient
        self.singleActionClient = singleActionClient
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        readUseCase = OwnerTruthInterviewCandidateConfirmationUseCase(
            accountLease: accountLease,
            reviewBatchID: reviewBatchID,
            client: confirmationClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "确认记忆线索"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        configureViews()
        configureReadUseCase()
        render(readUseCase.viewState)
        readUseCase.send(.refresh)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    private func configureViews() {
        statusLabel.font = DJDesignTokens.Font.body(14)
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-candidate-confirmation-status"

        confirmSelectionButton.titleLabel?.font = DJDesignTokens.Font.body(15)
        confirmSelectionButton.setTitleColor(.white, for: .normal)
        confirmSelectionButton.setTitleColor(DJDesignTokens.Color.textTertiary, for: .disabled)
        confirmSelectionButton.backgroundColor = DJDesignTokens.Color.accentDeep
        confirmSelectionButton.layer.cornerRadius = 12
        confirmSelectionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        confirmSelectionButton.accessibilityIdentifier = "owner-truth-candidate-confirmation-batch-submit"
        confirmSelectionButton.addTarget(self, action: #selector(confirmSelectionTapped), for: .touchUpInside)

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            OwnerTruthCandidateConfirmationCell.self,
            forCellReuseIdentifier: OwnerTruthCandidateConfirmationCell.reuseIdentifier
        )
        tableView.accessibilityIdentifier = "owner-truth-candidate-confirmation-list"

        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        tableView.backgroundView = emptyStateLabel

        view.addSubview(statusLabel)
        view.addSubview(confirmSelectionButton)
        view.addSubview(tableView)
        [statusLabel, confirmSelectionButton, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            confirmSelectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            confirmSelectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            confirmSelectionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: confirmSelectionButton.topAnchor, constant: -8),
        ])
    }

    private func configureReadUseCase() {
        readUseCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewCandidateConfirmationViewState) {
        renderedState = state
        if state.phase != .loading {
            isRefreshingAfterCandidateAction = false
            candidateActionReloadStatusText = nil
        }
        refreshButton.isEnabled = canManuallyRefresh(state)
        if let confirmation = state.confirmation {
            let validBatchIDs = Set(confirmation.batchCandidates.map(\.id))
            selectedBatchCandidateIDs.formIntersection(validBatchIDs)
            configureActionUseCases(confirmation)
        } else {
            selectedBatchCandidateIDs.removeAll()
            invalidateActionConfiguration()
        }
        tableView.isUserInteractionEnabled = isCandidateInteractionAllowed
        statusLabel.text = candidateActionReloadStatusText ?? statusText(for: state)
        emptyStateLabel.text = emptyText(for: state)
        emptyStateLabel.isHidden = emptyStateLabel.text == nil
        updateBatchButton()
        tableView.reloadData()
    }

    private func configureActionUseCases(_ confirmation: OwnerTruthInterviewCandidateConfirmation) {
        actionConfigurationGeneration &+= 1
        let configurationGeneration = actionConfigurationGeneration
        batchActionUseCase = OwnerTruthInterviewCandidateConfirmationActionUseCase(
            accountLease: accountLease,
            confirmation: confirmation,
            client: batchActionClient,
            confirmationReader: confirmationClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        batchActionUseCase?.onViewStateChange = { [weak self] state in
            self?.handleBatchActionState(state, configurationGeneration: configurationGeneration)
        }
        singleActionUseCase = OwnerTruthInterviewCandidateConfirmationSingleActionUseCase(
            accountLease: accountLease,
            confirmation: confirmation,
            client: singleActionClient,
            confirmationReader: confirmationClient,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        singleActionUseCase?.onViewStateChange = { [weak self] state in
            self?.handleSingleActionState(state, configurationGeneration: configurationGeneration)
        }
    }

    private func handleBatchActionState(
        _ state: OwnerTruthInterviewCandidateConfirmationActionViewState,
        configurationGeneration: UInt
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.actionConfigurationGeneration == configurationGeneration else { return }
            switch state.phase {
            case .submitting, .reconciling:
                self.isCandidateActionInFlight = true
                self.refreshButton.isEnabled = false
                confirmSelectionButton.isEnabled = false
                tableView.isUserInteractionEnabled = false
                statusLabel.text = "正在确认所选普通线索。"
            case .confirmed:
                self.refreshAfterCandidateAction(
                    statusText: "已记录确认结果，正在刷新待确认线索。"
                )
            case .unavailable:
                self.refreshAfterCandidateAction(
                    statusText: batchActionText(for: state.notice)
                )
            case .failed:
                if self.requiresCandidateConfirmationReload(for: state.notice) {
                    self.refreshAfterCandidateAction(
                        statusText: batchActionText(for: state.notice)
                    )
                } else {
                    self.isCandidateActionInFlight = false
                    statusLabel.text = batchActionText(for: state.notice)
                    tableView.isUserInteractionEnabled = self.isCandidateInteractionAllowed
                    self.updateBatchButton()
                    self.refreshButton.isEnabled = self.canManuallyRefresh(self.renderedState)
                }
            case .idle:
                break
            }
        }
    }

    private func handleSingleActionState(
        _ state: OwnerTruthInterviewCandidateConfirmationSingleActionViewState,
        configurationGeneration: UInt
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.actionConfigurationGeneration == configurationGeneration else { return }
            switch state.phase {
            case .submitting, .reconciling:
                self.isCandidateActionInFlight = true
                self.refreshButton.isEnabled = false
                tableView.isUserInteractionEnabled = false
                confirmSelectionButton.isEnabled = false
                statusLabel.text = "正在记录逐条确认结果。"
            case .confirmed:
                self.refreshAfterCandidateAction(
                    statusText: singleActionText(for: state.notice)
                )
            case .unavailable:
                self.refreshAfterCandidateAction(
                    statusText: singleActionText(for: state.notice)
                )
            case .failed:
                if self.requiresCandidateConfirmationReload(for: state.notice) {
                    self.refreshAfterCandidateAction(
                        statusText: singleActionText(for: state.notice)
                    )
                } else {
                    self.isCandidateActionInFlight = false
                    tableView.isUserInteractionEnabled = self.isCandidateInteractionAllowed
                    statusLabel.text = singleActionText(for: state.notice)
                    self.updateBatchButton()
                    self.refreshButton.isEnabled = self.canManuallyRefresh(self.renderedState)
                }
            case .idle:
                break
            }
        }
    }

    private func refreshAfterCandidateAction(statusText: String) {
        guard !isRefreshingAfterCandidateAction else { return }
        isRefreshingAfterCandidateAction = true
        candidateActionReloadStatusText = statusText
        invalidateActionConfiguration()
        render(
            OwnerTruthInterviewCandidateConfirmationViewState(
                phase: .loading,
                confirmation: nil,
                notice: nil
            )
        )
        self.statusLabel.text = statusText
        readUseCase.send(.refresh)
    }

    private func invalidateActionConfiguration() {
        actionConfigurationGeneration &+= 1
        isCandidateActionInFlight = false
        batchActionUseCase?.onViewStateChange = nil
        singleActionUseCase?.onViewStateChange = nil
        batchActionUseCase = nil
        singleActionUseCase = nil
    }

    private func requiresCandidateConfirmationReload(
        for notice: OwnerTruthInterviewCandidateConfirmationActionNotice?
    ) -> Bool {
        switch notice {
        case .responseMismatch, .reconciliationFailed:
            return true
        default:
            return false
        }
    }

    private func requiresCandidateConfirmationReload(
        for notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice?
    ) -> Bool {
        switch notice {
        case .responseMismatch, .reconciliationFailed:
            return true
        default:
            return false
        }
    }

    private func canManuallyRefresh(
        _ state: OwnerTruthInterviewCandidateConfirmationViewState
    ) -> Bool {
        guard !isCandidateActionInFlight else { return false }
        guard state.phase != .loading else { return false }
        guard state.phase == .unavailable else { return true }
        return state.notice == .contextChanged
    }

    private var isCandidateInteractionAllowed: Bool {
        !isCandidateActionInFlight
            && renderedState.phase == .ready
            && renderedState.confirmation != nil
    }

    private func statusText(for state: OwnerTruthInterviewCandidateConfirmationViewState) -> String {
        switch state.phase {
        case .idle:
            return "正在准备确认线索。"
        case .unavailable:
            switch state.notice {
            case .contentUnavailable:
                return "本次待确认内容已失效，无法继续确认。"
            case .contextChanged:
                return "待确认内容已更新，请重新载入。"
            case .releasePolicyDisabled:
                return "待确认记忆当前未开放。"
            case .invalidVault, .accountUnavailable, .staleAccountLease, .requestFailed, nil:
                return "当前无法确认这些线索。"
            }
        case .loading:
            return "正在读取确认线索。"
        case .ready:
            return "确认只会记录审核结果，正式记忆仍需后续明确激活。"
        case .empty:
            return "这一组线索已经没有待确认内容。"
        case .failed:
            return "暂时无法读取确认线索，请稍后重试。"
        }
    }

    private func emptyText(for state: OwnerTruthInterviewCandidateConfirmationViewState) -> String? {
        switch state.phase {
        case .empty:
            return "当前没有需要确认的线索。"
        case .unavailable:
            switch state.notice {
            case .contentUnavailable:
                return "本次待确认内容已失效，旧线索已清除。"
            case .contextChanged:
                return "旧线索已清除，请点右上角重新载入。"
            case .releasePolicyDisabled:
                return "该功能仅会在获准的发布策略下开放。"
            case .invalidVault, .accountUnavailable, .staleAccountLease, .requestFailed, nil:
                return "当前无法继续确认这些线索。"
            }
        case .failed:
            return "请点右上角重新载入。"
        default:
            return nil
        }
    }

    private func updateBatchButton() {
        let batchCount = renderedState.confirmation?.batchCandidates.count ?? 0
        let isSubmitting = isCandidateActionInFlight
            || batchActionUseCase?.viewState.phase == .submitting
            || batchActionUseCase?.viewState.phase == .reconciling
        guard isCandidateInteractionAllowed, batchCount > 0 else {
            confirmSelectionButton.isHidden = true
            return
        }
        confirmSelectionButton.isHidden = false
        let selectedCount = selectedBatchCandidateIDs.count
        confirmSelectionButton.setTitle(
            selectedCount == 0 ? "选择普通线索后确认" : "确认所选普通线索（\(selectedCount)）",
            for: .normal
        )
        confirmSelectionButton.isEnabled = selectedCount > 0 && !isSubmitting
        confirmSelectionButton.alpha = confirmSelectionButton.isEnabled ? 1 : 0.5
    }

    private var visibleSections: [Section] {
        guard let confirmation = renderedState.confirmation else { return [] }
        return Section.allCases.filter { section in
            switch section {
            case .batch: return !confirmation.batchCandidates.isEmpty
            case .single: return !confirmation.singleCandidates.isEmpty
            }
        }
    }

    private func candidate(
        at indexPath: IndexPath
    ) -> (item: OwnerTruthInterviewCandidateReviewItem, section: Section)? {
        let sections = visibleSections
        guard sections.indices.contains(indexPath.section),
              let confirmation = renderedState.confirmation else {
            return nil
        }
        let section = sections[indexPath.section]
        let items: [OwnerTruthInterviewCandidateReviewItem]
        switch section {
        case .batch: items = confirmation.batchCandidates
        case .single: items = confirmation.singleCandidates
        }
        guard items.indices.contains(indexPath.row) else { return nil }
        return (items[indexPath.row], section)
    }

    @objc private func refreshTapped() {
        guard canManuallyRefresh(renderedState) else { return }
        readUseCase.send(.refresh)
    }

    @objc private func confirmSelectionTapped() {
        guard isCandidateInteractionAllowed, !isCandidateActionInFlight else { return }
        let candidateIDs = selectedBatchCandidateIDs.sorted {
            $0.rawValue.uuidString < $1.rawValue.uuidString
        }
        guard !candidateIDs.isEmpty else { return }
        let alert = UIAlertController(
            title: "确认普通线索",
            message: "确认后将生成审核回执，不会直接写入正式记忆。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
            self?.submitBatchConfirmation(candidateIDs: candidateIDs)
        })
        present(alert, animated: true)
    }

    func submitBatchConfirmation(candidateIDs: [OwnerTruthRecordID]) {
        guard let batchActionUseCase,
              beginCandidateActionSubmission() else {
            return
        }
        batchActionUseCase.send(.confirmBatch(candidateIDs: candidateIDs))
    }

    func submitSingleConfirmation(_ intent: OwnerTruthInterviewCandidateConfirmationSingleActionIntent) {
        guard let singleActionUseCase,
              beginCandidateActionSubmission() else {
            return
        }
        singleActionUseCase.send(intent)
    }

    @discardableResult
    private func beginCandidateActionSubmission() -> Bool {
        guard isCandidateInteractionAllowed else { return false }
        isCandidateActionInFlight = true
        refreshButton.isEnabled = false
        tableView.isUserInteractionEnabled = false
        confirmSelectionButton.isEnabled = false
        return true
    }

    private func showSingleActions(
        for item: OwnerTruthInterviewCandidateReviewItem,
        sourceView: UIView
    ) {
        let alert = UIAlertController(
            title: "逐条确认线索",
            message: "敏感线索需要你单独确认、更正或拒绝；操作不会直接写入正式记忆。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
            self?.submitSingleConfirmation(.accept(candidateID: item.id))
        })
        alert.addAction(UIAlertAction(title: "更正后确认", style: .default) { [weak self] _ in
            guard let self, self.isCandidateInteractionAllowed else { return }
            self.presentCorrectionAlert(for: item)
        })
        alert.addAction(UIAlertAction(title: "拒绝", style: .destructive) { [weak self] _ in
            self?.submitSingleConfirmation(.reject(candidateID: item.id))
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(alert, animated: true)
    }

    private func presentCorrectionAlert(for item: OwnerTruthInterviewCandidateReviewItem) {
        let alert = UIAlertController(
            title: "更正线索",
            message: "更正只会保存为本次审核结果。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = Self.proposalPreview(for: item)
            textField.clearButtonMode = .whileEditing
            textField.accessibilityIdentifier = "owner-truth-candidate-confirmation-correction-input"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "提交更正", style: .default) { [weak self, weak alert] _ in
            self?.submitSingleConfirmation(.correct(
                candidateID: item.id,
                correctedSummary: alert?.textFields?.first?.text ?? ""
            ))
        })
        present(alert, animated: true)
    }

    private func batchActionText(
        for notice: OwnerTruthInterviewCandidateConfirmationActionNotice?
    ) -> String {
        switch notice {
        case .contentUnavailable: return "本次待确认内容已失效，正在重新读取。"
        case .contextChanged: return "待确认内容已更新，正在重新读取。"
        case .releasePolicyDisabled: return "待确认记忆当前未开放。"
        case .invalidVault, .accountUnavailable, .staleAccountLease: return "账号状态已变化，请重新进入。"
        case .invalidSelection: return "所选线索已变化，请重新选择。"
        case .responseMismatch, .reconciliationFailed: return "确认结果尚未核对完成，请重新载入。"
        case .requestFailed: return "确认失败，请稍后重试。"
        case .batchConfirmed: return "已确认所选普通线索。"
        case .none: return "确认失败，请稍后重试。"
        }
    }

    private func singleActionText(
        for notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice?
    ) -> String {
        switch notice {
        case .contentUnavailable: return "本次待确认内容已失效，正在重新读取。"
        case .contextChanged: return "待确认内容已更新，正在重新读取。"
        case .releasePolicyDisabled: return "待确认记忆当前未开放。"
        case .invalidVault, .accountUnavailable, .staleAccountLease: return "账号状态已变化，请重新进入。"
        case .invalidSelection: return "该线索已变化，请重新载入。"
        case .correctionRequired: return "请填写更正后的线索。"
        case .responseMismatch, .reconciliationFailed: return "确认结果尚未核对完成，请重新载入。"
        case .requestFailed: return "确认失败，请稍后重试。"
        case .singleAccepted: return "已确认该线索。"
        case .singleCorrected: return "已保存更正后的线索。"
        case .singleRejected: return "已拒绝该线索。"
        case .none: return "确认失败，请稍后重试。"
        }
    }

    static func proposalPreview(for item: OwnerTruthInterviewCandidateReviewItem) -> String {
        for key in ["summary", "title", "text"] {
            guard case .string(let rawValue)? = item.candidate.content[key] else { continue }
            let normalized = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return String(normalized.prefix(160))
            }
        }
        return "待确认访谈线索"
    }
}

extension OwnerTruthInterviewCandidateConfirmationViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        visibleSections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard visibleSections.indices.contains(section) else { return nil }
        return visibleSections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard visibleSections.indices.contains(section),
              let confirmation = renderedState.confirmation else {
            return 0
        }
        switch visibleSections[section] {
        case .batch: return confirmation.batchCandidates.count
        case .single: return confirmation.singleCandidates.count
        }
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OwnerTruthCandidateConfirmationCell.reuseIdentifier,
            for: indexPath
        ) as! OwnerTruthCandidateConfirmationCell
        if let candidate = candidate(at: indexPath) {
            cell.configure(
                candidate.item,
                isSelectedForBatch: candidate.section == .batch && selectedBatchCandidateIDs.contains(candidate.item.id)
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isCandidateInteractionAllowed,
              let candidate = candidate(at: indexPath),
              let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        switch candidate.section {
        case .batch:
            if selectedBatchCandidateIDs.contains(candidate.item.id) {
                selectedBatchCandidateIDs.remove(candidate.item.id)
            } else {
                selectedBatchCandidateIDs.insert(candidate.item.id)
            }
            updateBatchButton()
            tableView.reloadRows(at: [indexPath], with: .none)
        case .single:
            showSingleActions(for: candidate.item, sourceView: cell)
        }
    }
}

private final class OwnerTruthCandidateConfirmationCell: UITableViewCell {
    static let reuseIdentifier = "OwnerTruthCandidateConfirmationCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = DJDesignTokens.Color.surface
        titleLabel.font = DJDesignTokens.Font.body(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        detailLabel.font = DJDesignTokens.Font.label(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 6
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -34),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        _ item: OwnerTruthInterviewCandidateReviewItem,
        isSelectedForBatch: Bool
    ) {
        titleLabel.text = OwnerTruthInterviewCandidateConfirmationViewController.proposalPreview(for: item)
        let pathText = item.reviewPath == .single ? "需逐条确认" : "普通线索"
        detailLabel.text = "\(pathText) · \(item.candidate.sensitivity.rawValue) · 来源 \(item.candidate.sourceReferences.count) 条"
        accessoryType = item.reviewPath == .single ? .disclosureIndicator : (isSelectedForBatch ? .checkmark : .none)
        tintColor = DJDesignTokens.Color.accentDeep
        accessibilityLabel = "\(titleLabel.text ?? "")，\(detailLabel.text ?? "")"
    }
}

// MARK: - QA candidate inbox

/// QA-only Archive page for reviewing Owner Truth candidates. The page consumes
/// a lease-fenced Intent/ViewState use case and deliberately has no direct
/// archive, KBLite or legacy-writer authority.
final class OwnerTruthCandidateInboxViewController: UIViewController {
    private let accountLease: AccountLease
    private let useCase: OwnerTruthCandidateReviewUseCase
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState: OwnerTruthCandidateInboxViewState = .idle
    var onViewStateRendered: ((OwnerTruthCandidateInboxViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthCandidateReviewClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.useCase = OwnerTruthCandidateReviewUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "候选记忆审核"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        refreshButton.accessibilityIdentifier = "owner-truth-candidate-inbox-refresh"
        configureHeader()
        configureTableView()
        configureUseCase()
        render(useCase.viewState)
        useCase.send(.refresh)
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

    private func configureHeader() {
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 6
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 18,
            leading: DJDesignTokens.Spacing.page,
            bottom: 14,
            trailing: DJDesignTokens.Spacing.page
        )

        titleLabel.text = "待确认记忆"
        titleLabel.font = DJDesignTokens.Font.title(24)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        subtitleLabel.text = "仅用于 QA 审核；候选内容不会直接写入档案。"
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        statusLabel.font = DJDesignTokens.Font.label(12)
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-candidate-inbox-status"

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
        headerStack.addArrangedSubview(statusLabel)
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            OwnerTruthCandidateInboxCell.self,
            forCellReuseIdentifier: OwnerTruthCandidateInboxCell.reuseIdentifier
        )
        tableView.accessibilityIdentifier = "owner-truth-candidate-inbox-list"

        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.accessibilityIdentifier = "owner-truth-candidate-inbox-empty"
        tableView.backgroundView = emptyStateLabel

        view.addSubview(headerStack)
        view.addSubview(tableView)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthCandidateInboxViewState) {
        renderedState = state
        let isSubmitting: Bool
        if case .submitting = state.phase {
            isSubmitting = true
        } else {
            isSubmitting = false
        }
        tableView.isUserInteractionEnabled = !isSubmitting
        refreshButton.isEnabled = !isSubmitting
        statusLabel.text = statusText(for: state)
        statusLabel.accessibilityLabel = statusLabel.text
        emptyStateLabel.text = emptyText(for: state)
        emptyStateLabel.isHidden = emptyStateLabel.text == nil
        tableView.reloadData()
        onViewStateRendered?(state)
    }

    private func statusText(for state: OwnerTruthCandidateInboxViewState) -> String {
        switch state.phase {
        case .idle:
            return "准备审核入口"
        case .unavailable:
            return noticeText(state.notice) ?? "审核入口暂不可用"
        case .loading:
            return "正在读取待确认候选记忆"
        case .ready:
            return "已加载 \(state.items.count) 条候选记忆"
        case .empty:
            return noticeText(state.notice) ?? "没有待确认候选记忆"
        case .submitting:
            return "正在提交审核结果"
        case .failed:
            return noticeText(state.notice) ?? "读取失败，可重新载入"
        }
    }

    private func emptyText(for state: OwnerTruthCandidateInboxViewState) -> String? {
        guard state.items.isEmpty else { return nil }
        switch state.phase {
        case .empty:
            return "当前没有需要你确认的候选记忆。"
        case .unavailable:
            return "审核入口仅在受控 QA 环境可用。"
        case .failed:
            return "暂时无法读取候选记忆，请点右上角重新载入。"
        default:
            return nil
        }
    }

    private func noticeText(_ notice: OwnerTruthCandidateInboxNotice?) -> String? {
        guard let notice else { return nil }
        switch notice {
        case .qaOnlyDisabled:
            return "审核入口仅在受控 QA 环境可用"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入审核入口"
        case .invalidVault:
            return "当前档案空间不可用于候选审核"
        case .candidateUnavailable:
            return "该候选记忆已不可用，请重新载入"
        case .correctionRequired:
            return "请填写更正后的记忆描述"
        case .reviewResultMismatch:
            return "审核回执不匹配，未更新候选状态"
        case .requestFailed:
            return "读取或提交失败，可重新载入后重试"
        case .candidateAccepted:
            return "已确认并生成记忆版本"
        case .candidateCorrected:
            return "已按更正内容生成记忆版本"
        case .candidateRejected:
            return "已拒绝该候选记忆"
        }
    }

    @objc private func refreshTapped() {
        useCase.send(.refresh)
    }

    private func showActions(for item: OwnerTruthCandidateInboxItemViewState, sourceView: UIView) {
        let alert = UIAlertController(
            title: "审核候选记忆",
            message: "操作会通过受控 QA 合同提交；不会直接写入旧档案链路。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
            self?.useCase.send(.accept(candidateID: item.id))
        })
        if item.supportsCorrection {
            alert.addAction(UIAlertAction(title: "更正后确认", style: .default) { [weak self] _ in
                self?.presentCorrectionAlert(for: item)
            })
        }
        alert.addAction(UIAlertAction(title: "拒绝", style: .destructive) { [weak self] _ in
            self?.useCase.send(.reject(candidateID: item.id))
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(alert, animated: true)
    }

    private func presentCorrectionAlert(for item: OwnerTruthCandidateInboxItemViewState) {
        let alert = UIAlertController(
            title: "更正候选记忆",
            message: "确认后将保留原候选内容并以更正后的摘要生成新版本。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = item.proposalPreview
            textField.clearButtonMode = .whileEditing
            textField.accessibilityIdentifier = "owner-truth-candidate-correction-input"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "提交更正", style: .default) { [weak self, weak alert] _ in
            self?.useCase.send(.correct(
                candidateID: item.id,
                correctedSummary: alert?.textFields?.first?.text ?? ""
            ))
        })
        present(alert, animated: true)
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    func runUIQAAcceptFirstCandidate() {
        guard OwnerTruthCandidateReviewQAGate.isEnabled,
              let candidateID = renderedState.items.first?.id else {
            return
        }
        useCase.send(.accept(candidateID: candidateID))
    }
    #endif
}

extension OwnerTruthCandidateInboxViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        renderedState.items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OwnerTruthCandidateInboxCell.reuseIdentifier,
            for: indexPath
        ) as! OwnerTruthCandidateInboxCell
        cell.configure(renderedState.items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard renderedState.items.indices.contains(indexPath.row),
              let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: renderedState.items[indexPath.row], sourceView: cell)
    }
}

private final class OwnerTruthCandidateInboxCell: UITableViewCell {
    static let reuseIdentifier = "OwnerTruthCandidateInboxCell"

    private let cardView = UIView()
    private let summaryLabel = UILabel()
    private let metadataLabel = UILabel()
    private let evidenceLabel = UILabel()
    private let reviewBadgeLabel = PaddingLabel(horizontalInset: 8, verticalInset: 4)
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = DJDesignTokens.Color.surface
        cardView.layer.cornerRadius = 18
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.16).cgColor

        summaryLabel.font = DJDesignTokens.Font.body(16)
        summaryLabel.textColor = DJDesignTokens.Color.textPrimary
        summaryLabel.numberOfLines = 3

        metadataLabel.font = DJDesignTokens.Font.label(12)
        metadataLabel.textColor = DJDesignTokens.Color.textSecondary
        metadataLabel.numberOfLines = 2

        evidenceLabel.font = DJDesignTokens.Font.label(12)
        evidenceLabel.textColor = DJDesignTokens.Color.textTertiary

        reviewBadgeLabel.font = DJDesignTokens.Font.label(11)
        reviewBadgeLabel.textColor = DJDesignTokens.Color.accentDeep
        reviewBadgeLabel.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.16)
        reviewBadgeLabel.layer.cornerRadius = 10
        reviewBadgeLabel.layer.masksToBounds = true

        chevronImageView.tintColor = DJDesignTokens.Color.textTertiary
        chevronImageView.contentMode = .scaleAspectFit

        contentView.addSubview(cardView)
        [summaryLabel, metadataLabel, evidenceLabel, reviewBadgeLabel, chevronImageView].forEach {
            cardView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            reviewBadgeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            reviewBadgeLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),

            summaryLabel.topAnchor.constraint(equalTo: reviewBadgeLabel.bottomAnchor, constant: 10),
            summaryLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),

            metadataLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
            metadataLabel.leadingAnchor.constraint(equalTo: summaryLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: summaryLabel.trailingAnchor),

            evidenceLabel.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 6),
            evidenceLabel.leadingAnchor.constraint(equalTo: summaryLabel.leadingAnchor),
            evidenceLabel.trailingAnchor.constraint(equalTo: summaryLabel.trailingAnchor),
            evidenceLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ item: OwnerTruthCandidateInboxItemViewState) {
        summaryLabel.text = item.proposalPreview
        metadataLabel.text = "\(memoryKindText(item.memoryKind)) · \(perspectiveText(item.perspective)) · \(epistemicText(item.epistemicStatus))"
        evidenceLabel.text = "\(item.evidenceCount) 条证据 · \(sensitivityText(item.sensitivity))"
        reviewBadgeLabel.text = item.reviewMode == "single" ? "待本人确认" : "待确认"
        accessibilityIdentifier = "owner-truth-candidate-inbox-item"
        accessibilityLabel = "候选记忆，\(item.proposalPreview)，\(item.evidenceCount) 条证据"
    }

    private func memoryKindText(_ value: OwnerTruthMemoryKind) -> String {
        switch value {
        case .experience: return "经历"
        case .knowledge: return "知识"
        case .emotion: return "感受"
        }
    }

    private func perspectiveText(_ value: OwnerTruthPerspectiveType) -> String {
        switch value {
        case .firstPerson: return "本人视角"
        case .reported: return "转述"
        case .inferred: return "推断"
        }
    }

    private func epistemicText(_ value: OwnerTruthEpistemicStatus) -> String {
        switch value {
        case .observed: return "观察"
        case .recalled: return "回忆"
        case .reported: return "转述"
        case .inferred: return "推断"
        case .uncertain: return "待核实"
        }
    }

    private func sensitivityText(_ value: OwnerTruthSensitivityLevel) -> String {
        switch value {
        case .standard: return "普通敏感度"
        case .sensitive: return "敏感内容"
        case .restricted: return "受限内容"
        }
    }
}

/// QA-only review surface for the M0-A interview lane.  It intentionally uses
/// a separate use case and client contract from the generic Candidate Inbox:
/// its terminal actions only consume interview DecisionReceipts and never
/// create a MemoryVersion.
final class OwnerTruthInterviewCandidateReviewViewController: UIViewController {
    private let accountLease: AccountLease
    private let useCase: OwnerTruthInterviewCandidateReviewUseCase
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState: OwnerTruthInterviewCandidateReviewViewState = .idle
    var onViewStateRendered: ((OwnerTruthInterviewCandidateReviewViewState) -> Void)?

    init(
        accountLease: AccountLease,
        reviewBatchID: OwnerTruthRecordID,
        client: OwnerTruthInterviewCandidateReviewClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.useCase = OwnerTruthInterviewCandidateReviewUseCase(
            accountLease: accountLease,
            reviewBatchID: reviewBatchID,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "访谈候选审核"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        refreshButton.accessibilityIdentifier = "owner-truth-interview-candidate-review-refresh"
        configureHeader()
        configureTableView()
        configureUseCase()
        render(useCase.viewState)
        useCase.send(.refresh)
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

    private func configureHeader() {
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 6
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 18,
            leading: DJDesignTokens.Spacing.page,
            bottom: 10,
            trailing: DJDesignTokens.Spacing.page
        )

        titleLabel.text = "访谈后的待确认线索"
        titleLabel.font = DJDesignTokens.Font.title(23)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        subtitleLabel.text = "仅用于受控 QA 审核；操作只生成审核回执，不会写入记忆版本或公开档案。"
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        statusLabel.font = DJDesignTokens.Font.label(12)
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-interview-candidate-review-status"

        [titleLabel, subtitleLabel, statusLabel].forEach(headerStack.addArrangedSubview)
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = DJDesignTokens.Color.divider.withAlphaComponent(0.55)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            OwnerTruthInterviewCandidateReviewCell.self,
            forCellReuseIdentifier: OwnerTruthInterviewCandidateReviewCell.reuseIdentifier
        )
        tableView.accessibilityIdentifier = "owner-truth-interview-candidate-review-list"

        emptyStateLabel.font = DJDesignTokens.Font.body(15)
        emptyStateLabel.textColor = DJDesignTokens.Color.textTertiary
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.accessibilityIdentifier = "owner-truth-interview-candidate-review-empty"
        tableView.backgroundView = emptyStateLabel

        view.addSubview(headerStack)
        view.addSubview(tableView)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewCandidateReviewViewState) {
        renderedState = state
        let isSubmitting = state.phase == .submitting
        tableView.isUserInteractionEnabled = !isSubmitting
        refreshButton.isEnabled = !isSubmitting
        statusLabel.text = statusText(for: state)
        statusLabel.accessibilityLabel = statusLabel.text
        emptyStateLabel.text = emptyText(for: state)
        emptyStateLabel.isHidden = emptyStateLabel.text == nil
        tableView.reloadData()
        onViewStateRendered?(state)
    }

    private func statusText(for state: OwnerTruthInterviewCandidateReviewViewState) -> String {
        switch state.phase {
        case .idle:
            return "准备读取访谈候选"
        case .unavailable:
            return noticeText(state.notice) ?? "审核入口暂不可用"
        case .loading:
            return "正在读取待确认访谈线索"
        case .ready:
            return "普通候选 \(state.batchItems.count) 条 · 需要逐条确认 \(state.singleItems.count) 条"
        case .submitting:
            return "正在提交审核回执"
        case .empty:
            return noticeText(state.notice) ?? "当前批次没有待确认线索"
        case .failed:
            return noticeText(state.notice) ?? "读取或提交失败，可重新载入"
        }
    }

    private func emptyText(for state: OwnerTruthInterviewCandidateReviewViewState) -> String? {
        guard state.batchItems.isEmpty, state.singleItems.isEmpty else { return nil }
        switch state.phase {
        case .empty:
            return "当前没有需要确认的访谈线索。"
        case .unavailable:
            return "审核入口仅在受控 QA 环境可用。"
        case .failed:
            return "暂时无法读取访谈线索，请点右上角重新载入。"
        default:
            return nil
        }
    }

    private func noticeText(_ notice: OwnerTruthInterviewCandidateReviewNotice?) -> String? {
        guard let notice else { return nil }
        switch notice {
        case .qaOnlyDisabled:
            return "审核入口仅在受控 QA 环境可用"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入审核入口"
        case .invalidVault:
            return "当前档案空间不可用于访谈审核"
        case .invalidSelection, .candidateUnavailable:
            return "候选状态已变化，请重新载入"
        case .correctionRequired:
            return "请填写更正后的线索描述"
        case .reviewResultMismatch:
            return "审核回执不匹配，未更新候选状态"
        case .requestFailed:
            return "读取或提交失败，可重新载入后重试"
        case .batchAccepted:
            return "已确认所选普通线索；未创建记忆版本"
        case .singleAccepted:
            return "已确认该线索；未创建记忆版本"
        case .singleCorrected:
            return "已记录更正审核回执；未创建记忆版本"
        case .singleRejected:
            return "已拒绝该线索；未创建记忆版本"
        }
    }

    private func item(at indexPath: IndexPath) -> OwnerTruthInterviewCandidateReviewItemViewState? {
        let sections = visibleSections
        guard sections.indices.contains(indexPath.section),
              sections[indexPath.section].items.indices.contains(indexPath.row) else {
            return nil
        }
        return sections[indexPath.section].items[indexPath.row]
    }

    private var visibleSections: [(title: String, items: [OwnerTruthInterviewCandidateReviewItemViewState])] {
        var sections: [(String, [OwnerTruthInterviewCandidateReviewItemViewState])] = []
        if !renderedState.batchItems.isEmpty {
            sections.append(("可批量确认", renderedState.batchItems))
        }
        if !renderedState.singleItems.isEmpty {
            sections.append(("需要逐条确认", renderedState.singleItems))
        }
        return sections
    }

    @objc private func refreshTapped() {
        useCase.send(.refresh)
    }

    private func showActions(
        for item: OwnerTruthInterviewCandidateReviewItemViewState,
        sourceView: UIView
    ) {
        switch item.reviewPath {
        case .batch:
            let alert = UIAlertController(
                title: "确认普通线索",
                message: "这会将本条加入当前批量审核回执；不会生成记忆版本。",
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: "确认本条", style: .default) { [weak self] _ in
                self?.useCase.send(.acceptBatch(candidateIDs: [item.id]))
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
            present(alert, animated: true)
        case .single:
            let alert = UIAlertController(
                title: "逐条审核线索",
                message: "敏感或需要明确确认的线索必须单独审核；不会生成记忆版本。",
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
                self?.useCase.send(.acceptSingle(candidateID: item.id))
            })
            if item.supportsCorrection {
                alert.addAction(UIAlertAction(title: "更正后确认", style: .default) { [weak self] _ in
                    self?.presentCorrectionAlert(for: item)
                })
            }
            alert.addAction(UIAlertAction(title: "拒绝", style: .destructive) { [weak self] _ in
                self?.useCase.send(.rejectSingle(candidateID: item.id))
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
            present(alert, animated: true)
        }
    }

    private func presentCorrectionAlert(for item: OwnerTruthInterviewCandidateReviewItemViewState) {
        let alert = UIAlertController(
            title: "更正访谈线索",
            message: "更正内容只随审核回执保存，仍不会创建记忆版本。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = item.proposalPreview
            textField.clearButtonMode = .whileEditing
            textField.accessibilityIdentifier = "owner-truth-interview-candidate-review-correction-input"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "提交更正", style: .default) { [weak self, weak alert] _ in
            self?.useCase.send(.correctSingle(
                candidateID: item.id,
                correctedSummary: alert?.textFields?.first?.text ?? ""
            ))
        })
        present(alert, animated: true)
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    func runUIQAAcceptFirstBatchCandidate() {
        guard OwnerTruthCandidateReviewQAGate.isEnabled,
              let candidateID = renderedState.batchItems.first?.id else {
            return
        }
        useCase.send(.acceptBatch(candidateIDs: [candidateID]))
    }

    func runUIQARejectFirstSingleCandidate() {
        guard OwnerTruthCandidateReviewQAGate.isEnabled,
              let candidateID = renderedState.singleItems.first?.id else {
            return
        }
        useCase.send(.rejectSingle(candidateID: candidateID))
    }
    #endif
}

extension OwnerTruthInterviewCandidateReviewViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        max(1, visibleSections.count)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard visibleSections.indices.contains(section) else { return nil }
        return visibleSections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard visibleSections.indices.contains(section) else { return 0 }
        return visibleSections[section].items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OwnerTruthInterviewCandidateReviewCell.reuseIdentifier,
            for: indexPath
        ) as! OwnerTruthInterviewCandidateReviewCell
        if let item = item(at: indexPath) {
            cell.configure(item)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = item(at: indexPath),
              let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: item, sourceView: cell)
    }
}

private final class OwnerTruthInterviewCandidateReviewCell: UITableViewCell {
    static let reuseIdentifier = "OwnerTruthInterviewCandidateReviewCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        backgroundColor = DJDesignTokens.Color.surface
        selectionStyle = .default
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ item: OwnerTruthInterviewCandidateReviewItemViewState) {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.proposalPreview
        content.textProperties.font = DJDesignTokens.Font.body(16)
        content.textProperties.color = DJDesignTokens.Color.textPrimary
        content.secondaryText = "\(memoryKindText(item.memoryKind)) · \(sensitivityText(item.sensitivity)) · \(item.evidenceCount) 条证据"
        content.secondaryTextProperties.font = DJDesignTokens.Font.label(12)
        content.secondaryTextProperties.color = DJDesignTokens.Color.textSecondary
        content.image = UIImage(systemName: item.reviewPath == .batch ? "checklist" : "exclamationmark.bubble")
        content.imageProperties.tintColor = item.reviewPath == .batch
            ? DJDesignTokens.Color.accentDeep
            : DJDesignTokens.Color.textSecondary
        contentConfiguration = content
        accessibilityIdentifier = "owner-truth-interview-candidate-review-item-\(item.reviewPath.rawValue)"
        accessibilityLabel = "\(item.reviewPath == .batch ? "可批量确认" : "需要逐条确认")，\(item.proposalPreview)"
    }

    private func memoryKindText(_ value: OwnerTruthMemoryKind) -> String {
        switch value {
        case .experience: return "经历"
        case .knowledge: return "知识"
        case .emotion: return "感受"
        }
    }

    private func sensitivityText(_ value: OwnerTruthSensitivityLevel) -> String {
        switch value {
        case .standard: return "普通"
        case .sensitive: return "敏感"
        case .restricted: return "受限"
        }
    }
}

/// Default-off ending-summary surface for one Owner interview. The request
/// path carries the private session identifier, while this view only renders
/// the value-minimized presentation contract.
final class OwnerTruthInterviewOutcomeViewController: UIViewController {
    private let useCase: OwnerTruthInterviewOutcomePresentationUseCase
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let introductionLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let thisSessionCard = UIStackView()
    private let laterContinueCard = UIStackView()
    private let thisSessionDetailLabel = UILabel()
    private let laterContinueDetailLabel = UILabel()

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewOutcomePresentationClient = DreamJourneyBackendClient.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        useCase = OwnerTruthInterviewOutcomePresentationUseCase(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "本次回顾"
        view.backgroundColor = DJDesignTokens.Color.background
        configureView()
        configureUseCase()
        render(useCase.viewState)
        useCase.refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
    }

    private func configureView() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 24,
            trailing: DJDesignTokens.Spacing.page
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        introductionLabel.font = DJDesignTokens.Font.body(15)
        introductionLabel.textColor = DJDesignTokens.Color.textSecondary
        introductionLabel.numberOfLines = 0
        introductionLabel.text = "这里只呈现本次真实确认的变化，不把推测当作事实。"

        statusLabel.font = DJDesignTokens.Font.title(20)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-interview-outcome-status"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-interview-outcome-detail"

        configureSection(
            thisSessionCard,
            title: "本次补充",
            detailLabel: thisSessionDetailLabel,
            accessibilityIdentifier: "owner-truth-interview-outcome-this-session"
        )
        configureSection(
            laterContinueCard,
            title: "以后可续",
            detailLabel: laterContinueDetailLabel,
            accessibilityIdentifier: "owner-truth-interview-outcome-later-continue"
        )

        [
            introductionLabel,
            statusLabel,
            detailLabel,
            thisSessionCard,
            laterContinueCard,
        ].forEach(stackView.addArrangedSubview)

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

    private func configureSection(
        _ container: UIStackView,
        title: String,
        detailLabel: UILabel,
        accessibilityIdentifier: String
    ) {
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 6
        container.isLayoutMarginsRelativeArrangement = true
        container.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14,
            leading: 14,
            bottom: 14,
            trailing: 14
        )
        container.backgroundColor = DJDesignTokens.Color.surface
        container.layer.cornerRadius = 10
        container.accessibilityIdentifier = accessibilityIdentifier

        let titleLabel = UILabel()
        titleLabel.font = DJDesignTokens.Font.label(13)
        titleLabel.textColor = DJDesignTokens.Color.textTertiary
        titleLabel.text = title

        detailLabel.font = DJDesignTokens.Font.body(16)
        detailLabel.textColor = DJDesignTokens.Color.textPrimary
        detailLabel.numberOfLines = 0

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(detailLabel)
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            if Thread.isMainThread {
                self?.render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewOutcomePresentationViewState) {
        let isLoading = state.phase == .loading
        navigationItem.rightBarButtonItem?.isEnabled = !isLoading
        thisSessionCard.isHidden = false
        laterContinueCard.isHidden = false

        switch state.phase {
        case .idle:
            statusLabel.text = "整理本次回顾"
            detailLabel.text = "完成本轮访谈后，这里会显示已确认的变化。"
            thisSessionDetailLabel.text = "本次暂无可确认的内容。"
            laterContinueDetailLabel.text = "想继续时，可以再回来。"
        case .loading:
            statusLabel.text = "正在整理本次回顾"
            detailLabel.text = "请稍候。"
            thisSessionCard.isHidden = true
            laterContinueCard.isHidden = true
        case .ready:
            guard let presentation = state.presentation else {
                renderUnavailable()
                return
            }
            statusLabel.text = "本次回顾已整理"
            detailLabel.text = "只统计当前已确认的内容。"
            if presentation.confirmedMemoryCount > 0 {
                thisSessionDetailLabel.text = "已确认 \(presentation.confirmedMemoryCount) 条内容。"
            } else {
                thisSessionDetailLabel.text = "本次暂无可确认的内容。"
            }
            if presentation.pendingReviewBatchCount > 0 {
                thisSessionDetailLabel.text? += " 有 \(presentation.pendingReviewBatchCount) 批内容等待确认。"
            }
            if presentation.canContinueLater {
                laterContinueDetailLabel.text = "想继续时，可以再回来。"
                if presentation.eligibleCueCount > 0 {
                    laterContinueDetailLabel.text? += " 已保留 \(presentation.eligibleCueCount) 条可继续线索。"
                }
            } else {
                laterContinueDetailLabel.text = "本次暂不保留继续线索。"
            }
        case .rebuilding:
            statusLabel.text = "正在整理本次回顾"
            detailLabel.text = "整理完成后，会显示当前已确认的变化。"
            thisSessionCard.isHidden = true
            laterContinueCard.isHidden = true
        case .unavailable:
            renderUnavailable()
        case .failed:
            statusLabel.text = "暂时无法整理本次回顾"
            detailLabel.text = "请稍后重试。"
            thisSessionCard.isHidden = true
            laterContinueCard.isHidden = true
        }
    }

    private func renderUnavailable() {
        statusLabel.text = "本次回顾暂不可用"
        detailLabel.text = "当前不会显示不完整或不属于你的访谈结果。"
        thisSessionCard.isHidden = true
        laterContinueCard.isHidden = true
    }

    @objc private func refreshTapped() {
        useCase.refresh()
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var renderedStatusForUIQA: String {
        statusLabel.text ?? ""
    }

    var renderedDetailForUIQA: String {
        detailLabel.text ?? ""
    }

    var renderedThisSessionForUIQA: String {
        thisSessionDetailLabel.text ?? ""
    }

    var renderedLaterContinueForUIQA: String {
        laterContinueDetailLabel.text ?? ""
    }
    #endif
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
struct OwnerTruthCandidateInboxUIQASmokeResult: Codable {
    static let fileName = "owner-truth-candidate-inbox-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let candidateVisible: Bool
    let candidatePreviewVisible: Bool
    let reviewActionsAvailable: Bool
    let reviewSubmitted: Bool
    let reviewAction: String?
    let terminalDecision: String?
    let receiptConsumed: Bool
    let memoryVersionCreated: Bool
    let candidateRemovedAfterReview: Bool
    let launchArgument: String
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthCandidateInboxUIQASmoke {
    static func makeViewController(accountLease: AccountLease) -> OwnerTruthCandidateInboxViewController {
        let client = CandidateInboxUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId))
        let controller = OwnerTruthCandidateInboxViewController(
            accountLease: accountLease,
            client: client,
            qaGateEnabled: { OwnerTruthCandidateReviewQAGate.isEnabled }
        )
        let scenario = CandidateInboxUIQAScenario()
        controller.onViewStateRendered = { [weak controller] state in
            scenario.consume(state, controller: controller)
        }
        return controller
    }

    static func writeFailure(_ reason: String) {
        let result = OwnerTruthCandidateInboxUIQASmokeResult(
            completed: false,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            candidateVisible: false,
            candidatePreviewVisible: false,
            reviewActionsAvailable: false,
            reviewSubmitted: false,
            reviewAction: nil,
            terminalDecision: nil,
            receiptConsumed: false,
            memoryVersionCreated: false,
            candidateRemovedAfterReview: false,
            launchArgument: OwnerTruthCandidateReviewQAGate.launchArgument,
            failureReason: reason
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthCandidateInboxSmoke failed result=\(resultURL.path) reason=\(reason)")
        } catch {
            print("[UI_QA] OwnerTruthCandidateInboxSmoke failed reason=\(reason) write=\(error.localizedDescription)")
        }
    }
}

private final class CandidateInboxUIQAScenario {
    private var didWrite = false
    private var didSubmit = false
    private var candidateVisible = false
    private var candidatePreviewVisible = false
    private var reviewActionsAvailable = false

    func consume(
        _ state: OwnerTruthCandidateInboxViewState,
        controller: OwnerTruthCandidateInboxViewController?
    ) {
        if case .ready = state.phase,
           let firstItem = state.items.first,
           !didSubmit {
            candidateVisible = true
            candidatePreviewVisible = !firstItem.proposalPreview.isEmpty
            reviewActionsAvailable = firstItem.supportsCorrection
            didSubmit = true
            DispatchQueue.main.async { [weak controller] in
                controller?.runUIQAAcceptFirstCandidate()
            }
            return
        }

        guard !didWrite else { return }
        guard case .empty = state.phase,
              let receipt = state.latestReceipt,
              receipt.decision == .accepted,
              receipt.createdMemoryVersion,
              state.items.isEmpty else {
            return
        }

        didWrite = true
        let result = OwnerTruthCandidateInboxUIQASmokeResult(
            completed: OwnerTruthCandidateReviewQAGate.isEnabled
                && didSubmit
                && candidateVisible
                && candidatePreviewVisible
                && reviewActionsAvailable,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            candidateVisible: candidateVisible,
            candidatePreviewVisible: candidatePreviewVisible,
            reviewActionsAvailable: reviewActionsAvailable,
            reviewSubmitted: didSubmit,
            reviewAction: OwnerTruthCandidateReviewAction.accept.rawValue,
            terminalDecision: receipt.decision.rawValue,
            receiptConsumed: true,
            memoryVersionCreated: receipt.createdMemoryVersion,
            candidateRemovedAfterReview: state.items.isEmpty,
            launchArgument: OwnerTruthCandidateReviewQAGate.launchArgument,
            failureReason: nil
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthCandidateInboxSmoke completed result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthCandidateInboxSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}

private final class CandidateInboxUIQAClient: OwnerTruthCandidateReviewClient {
    private let vaultID: OwnerTruthVaultID?
    private var candidateIsPending = true

    init(vaultID: OwnerTruthVaultID?) {
        self.vaultID = vaultID
    }

    func fetchOwnerTruthCandidateInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthCandidateInbox, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(CandidateInboxUIQAClientError.invalidVault))
            return
        }
        do {
            let inbox = try OwnerTruthCandidateInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthCandidateInbox.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "candidates": candidateIsPending ? [[
                        "candidateId": "00000000-0000-0000-0000-000000000151",
                        "sourceId": "00000000-0000-0000-0000-000000000152",
                        "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                        "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                        "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                        "sensitivity": OwnerTruthSensitivityLevel.standard.rawValue,
                        "contentSchemaVersion": "owner-truth-candidate-content-v1",
                        "content": [
                            "summary": "小时候在院子里听家人讲故事",
                            "confidence": 0.92,
                        ],
                        "contentHash": "uiqa-owner-truth-candidate-hash",
                        "sourceRefs": [[
                            "sourceId": "00000000-0000-0000-0000-000000000152",
                            "sourceVersion": 1,
                        ]],
                        "reviewMode": "single",
                        "candidateVersion": 1,
                    ]] : [],
                ],
                expectedVaultID: vaultID
            )
            completion(.success(inbox))
        } catch {
            completion(.failure(error))
        }
    }

    func reviewOwnerTruthCandidate(
        vaultID: OwnerTruthVaultID,
        candidateID: OwnerTruthRecordID,
        command: OwnerTruthCandidateReviewCommand,
        completion: @escaping (Result<OwnerTruthCandidateDecisionResult, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              candidateIsPending,
              candidateID.rawValue.uuidString.lowercased() == "00000000-0000-0000-0000-000000000151",
              command.action == .accept,
              command.expectedCandidateVersion == 1 else {
            completion(.failure(CandidateInboxUIQAClientError.invalidReview))
            return
        }

        candidateIsPending = false
        do {
            let result = try OwnerTruthCandidateDecisionResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthCandidateDecisionResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "receipt": [
                        "receiptId": "00000000-0000-0000-0000-000000000153",
                        "candidateId": candidateID.rawValue.uuidString,
                        "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                        "candidateVersion": 2,
                        "candidateBeforeHash": "uiqa-owner-truth-candidate-hash",
                        "candidateAfterHash": "uiqa-owner-truth-candidate-reviewed-hash",
                        "correctedValueId": NSNull(),
                    ],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.created.rawValue,
                        "memoryId": "00000000-0000-0000-0000-000000000154",
                        "memoryVersionId": "00000000-0000-0000-0000-000000000155",
                        "contentHash": "uiqa-owner-truth-memory-version-hash",
                    ],
                ],
                expectedCandidateID: candidateID
            )
            completion(.success(result))
        } catch {
            completion(.failure(error))
        }
    }
}

private enum CandidateInboxUIQAClientError: Error {
    case invalidVault
    case invalidReview
}

struct OwnerTruthInterviewCandidateReviewUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-candidate-review-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let batchCandidateVisible: Bool
    let singleCandidateVisible: Bool
    let batchReceiptConsumed: Bool
    let singleReceiptConsumed: Bool
    let memoryVersionCreated: Bool
    let allCandidatesRemoved: Bool
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewCandidateReviewUIQASmoke {
    static let reviewBatchID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000261")!
    )

    static func makeViewController(
        accountLease: AccountLease
    ) -> OwnerTruthInterviewCandidateReviewViewController {
        let client = InterviewCandidateReviewUIQAClient(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            reviewBatchID: reviewBatchID
        )
        let controller = OwnerTruthInterviewCandidateReviewViewController(
            accountLease: accountLease,
            reviewBatchID: reviewBatchID,
            client: client,
            qaGateEnabled: { OwnerTruthCandidateReviewQAGate.isEnabled }
        )
        let scenario = InterviewCandidateReviewUIQAScenario()
        controller.onViewStateRendered = { [weak controller] state in
            scenario.consume(state, controller: controller)
        }
        return controller
    }

    static func writeFailure(_ reason: String) {
        let result = OwnerTruthInterviewCandidateReviewUIQASmokeResult(
            completed: false,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            batchCandidateVisible: false,
            singleCandidateVisible: false,
            batchReceiptConsumed: false,
            singleReceiptConsumed: false,
            memoryVersionCreated: false,
            allCandidatesRemoved: false,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewCandidateReviewSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: reason
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewCandidateReviewSmoke failed result=\(resultURL.path) reason=\(reason)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewCandidateReviewSmoke failed reason=\(reason) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewCandidateReviewUIQAScenario {
    private var didWrite = false
    private var didSubmitBatch = false
    private var didSubmitSingle = false
    private var batchCandidateVisible = false
    private var singleCandidateVisible = false
    private var batchReceiptConsumed = false
    private var singleReceiptConsumed = false
    private var memoryVersionCreated = false

    func consume(
        _ state: OwnerTruthInterviewCandidateReviewViewState,
        controller: OwnerTruthInterviewCandidateReviewViewController?
    ) {
        if case .ready = state.phase,
           !didSubmitBatch,
           let firstBatchItem = state.batchItems.first {
            batchCandidateVisible = !firstBatchItem.proposalPreview.isEmpty
            singleCandidateVisible = !state.singleItems.isEmpty
            didSubmitBatch = true
            DispatchQueue.main.async { [weak controller] in
                controller?.runUIQAAcceptFirstBatchCandidate()
            }
            return
        }

        if case .ready = state.phase,
           state.notice == .batchAccepted,
           !didSubmitSingle,
           let receipt = state.latestReceipt,
           !receipt.memoryVersionCreated,
           !state.singleItems.isEmpty {
            batchReceiptConsumed = true
            memoryVersionCreated = memoryVersionCreated || receipt.memoryVersionCreated
            didSubmitSingle = true
            DispatchQueue.main.async { [weak controller] in
                controller?.runUIQARejectFirstSingleCandidate()
            }
            return
        }

        guard !didWrite,
              case .empty = state.phase,
              state.notice == .singleRejected,
              let receipt = state.latestReceipt,
              !receipt.memoryVersionCreated,
              state.batchItems.isEmpty,
              state.singleItems.isEmpty else {
            return
        }

        didWrite = true
        singleReceiptConsumed = true
        memoryVersionCreated = memoryVersionCreated || receipt.memoryVersionCreated
        let result = OwnerTruthInterviewCandidateReviewUIQASmokeResult(
            completed: OwnerTruthCandidateReviewQAGate.isEnabled
                && didSubmitBatch
                && didSubmitSingle
                && batchCandidateVisible
                && singleCandidateVisible
                && batchReceiptConsumed
                && singleReceiptConsumed
                && !memoryVersionCreated,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            batchCandidateVisible: batchCandidateVisible,
            singleCandidateVisible: singleCandidateVisible,
            batchReceiptConsumed: batchReceiptConsumed,
            singleReceiptConsumed: singleReceiptConsumed,
            memoryVersionCreated: memoryVersionCreated,
            allCandidatesRemoved: state.batchItems.isEmpty && state.singleItems.isEmpty,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewCandidateReviewSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: nil
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewCandidateReviewSmoke completed result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewCandidateReviewSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}

private final class InterviewCandidateReviewUIQAClient: OwnerTruthInterviewCandidateReviewClient {
    private let vaultID: OwnerTruthVaultID?
    private let reviewBatchID: OwnerTruthRecordID
    private let batchCandidateID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000262")!
    )
    private let singleCandidateID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000263")!
    )
    private var batchCandidatePending = true
    private var singleCandidatePending = true

    init(vaultID: OwnerTruthVaultID?, reviewBatchID: OwnerTruthRecordID) {
        self.vaultID = vaultID
        self.reviewBatchID = reviewBatchID
    }

    func fetchOwnerTruthInterviewCandidateReview(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateReviewBatch, Error>) -> Void
    ) {
        guard self.vaultID == vaultID, self.reviewBatchID == reviewBatchID else {
            completion(.failure(InterviewCandidateReviewUIQAClientError.invalidVault))
            return
        }
        do {
            let batchCandidates: [[String: Any]] = batchCandidatePending ? [candidateJSONObject(
                candidateID: batchCandidateID,
                reviewPath: .batch,
                sensitivity: .standard,
                summary: "在院子里听家人讲故事"
            )] : []
            let singleCandidates: [[String: Any]] = singleCandidatePending ? [candidateJSONObject(
                candidateID: singleCandidateID,
                reviewPath: .single,
                sensitivity: .sensitive,
                summary: "需要明确确认的家庭往事"
            )] : []
            let readiness = batchCandidates.isEmpty && singleCandidates.isEmpty
                ? OwnerTruthInterviewCandidateReviewReadiness.noCandidates
                : .reviewReady
            let batch = try OwnerTruthInterviewCandidateReviewBatch(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "review": [
                        "schemaVersion": OwnerTruthInterviewCandidateReviewBatch.compositionSchemaVersion,
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "admissionId": "00000000-0000-0000-0000-000000000264",
                        "sourceId": "00000000-0000-0000-0000-000000000265",
                        "sourceVersion": 1,
                        "authorityEpoch": 0,
                        "readiness": readiness.rawValue,
                        "latestExtractionStatus": "succeeded",
                        "batchCandidateCount": batchCandidates.count,
                        "singleCandidateCount": singleCandidates.count,
                    ],
                    "batchCandidates": batchCandidates,
                    "singleCandidates": singleCandidates,
                ],
                expectedVaultID: vaultID,
                expectedReviewBatchID: reviewBatchID
            )
            completion(.success(batch))
        } catch {
            completion(.failure(error))
        }
    }

    func acceptOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateBatchAcceptCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateBatchAcceptResult, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              command.reviewBatchID == reviewBatchID,
              batchCandidatePending,
              command.selections.count == 1,
              command.selections.first?.candidateID == batchCandidateID,
              command.selections.first?.expectedCandidateVersion == 1 else {
            completion(.failure(InterviewCandidateReviewUIQAClientError.invalidBatchDecision))
            return
        }
        batchCandidatePending = false
        do {
            let result = try OwnerTruthInterviewCandidateBatchAcceptResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateBatchAcceptResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-000000000266",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "acceptedCandidateCount": 1,
                    "receipts": [[
                        "receiptId": "00000000-0000-0000-0000-000000000267",
                        "candidateId": batchCandidateID.rawValue.uuidString,
                        "decision": OwnerTruthCandidateDecision.accepted.rawValue,
                        "candidateVersion": 2,
                        "correctedValueId": NSNull(),
                    ]],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": false,
                    ],
                ],
                expectedCommand: command
            )
            completion(.success(result))
        } catch {
            completion(.failure(error))
        }
    }

    func reviewOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateSingleReviewCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateSingleReviewResult, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              command.reviewBatchID == reviewBatchID,
              singleCandidatePending,
              command.candidateID == singleCandidateID,
              command.review.action == .reject,
              command.review.expectedCandidateVersion == 1 else {
            completion(.failure(InterviewCandidateReviewUIQAClientError.invalidSingleDecision))
            return
        }
        singleCandidatePending = false
        do {
            let result = try OwnerTruthInterviewCandidateSingleReviewResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateSingleReviewResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-000000000268",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "receipt": [
                        "receiptId": "00000000-0000-0000-0000-000000000269",
                        "candidateId": singleCandidateID.rawValue.uuidString,
                        "decision": OwnerTruthCandidateDecision.rejected.rawValue,
                        "candidateVersion": 2,
                        "correctedValueId": NSNull(),
                    ],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": false,
                    ],
                ],
                expectedCommand: command
            )
            completion(.success(result))
        } catch {
            completion(.failure(error))
        }
    }

    private func candidateJSONObject(
        candidateID: OwnerTruthRecordID,
        reviewPath: OwnerTruthInterviewCandidateReviewPath,
        sensitivity: OwnerTruthSensitivityLevel,
        summary: String
    ) -> [String: Any] {
        [
            "candidateId": candidateID.rawValue.uuidString,
            "sourceId": "00000000-0000-0000-0000-000000000265",
            "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
            "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
            "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
            "sensitivity": sensitivity.rawValue,
            "contentSchemaVersion": "owner-truth-candidate-content-v1",
            "content": ["summary": summary],
            "contentHash": "uiqa-interview-candidate-\(candidateID.rawValue.uuidString)",
            "sourceRefs": [[
                "sourceId": "00000000-0000-0000-0000-000000000265",
                "sourceVersion": 1,
            ]],
            "reviewMode": reviewPath.rawValue,
            "candidateVersion": 1,
            "extractionId": "00000000-0000-0000-0000-000000000270",
            "reviewPath": reviewPath.rawValue,
        ]
    }
}

private enum InterviewCandidateReviewUIQAClientError: Error {
    case invalidVault
    case invalidBatchDecision
    case invalidSingleDecision
}
#endif

/// Default-off, read-only M0-B navigation surface. It deliberately renders
/// only confirmed aggregate counts; raw memory, Source, thread and policy data
/// remain inside the Owner Truth boundary.
final class OwnerTruthLifeMapViewController: UIViewController {
    private let useCase: OwnerTruthLifeMapPresentationUseCase
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let summaryLabel = UILabel()
    private let detailLabel = UILabel()
    private let dimensionStack = UIStackView()

    init(
        accountLease: AccountLease,
        client: OwnerTruthLifeMapPresentationClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        useCase = OwnerTruthLifeMapPresentationUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "人生地图"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "刷新人生地图"
        configureView()
        configureUseCase()
        render(useCase.viewState)
        useCase.refresh()
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

    private func configureView() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 28,
            trailing: DJDesignTokens.Spacing.page
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        summaryLabel.font = DJDesignTokens.Font.title(22)
        summaryLabel.textColor = DJDesignTokens.Color.textPrimary
        summaryLabel.numberOfLines = 0
        summaryLabel.accessibilityIdentifier = "owner-truth-life-map-summary"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-life-map-detail"

        dimensionStack.axis = .vertical
        dimensionStack.alignment = .fill
        dimensionStack.spacing = 10
        dimensionStack.accessibilityIdentifier = "owner-truth-life-map-dimensions"

        stackView.addArrangedSubview(summaryLabel)
        stackView.addArrangedSubview(detailLabel)
        stackView.addArrangedSubview(dimensionStack)

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

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            if Thread.isMainThread {
                self?.render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthLifeMapPresentationViewState) {
        clearDimensionRows()
        navigationItem.rightBarButtonItem?.isEnabled = state.phase != .loading

        switch state.phase {
        case .idle, .loading:
            summaryLabel.text = "正在整理已确认的故事线索"
            detailLabel.text = "这里只回顾你已确认的内容，不展示完成度。"
        case .ready:
            guard let presentation = state.presentation else {
                renderUnavailable()
                return
            }
            if presentation.storyCount == 0 {
                summaryLabel.text = "还没有可回顾的故事线索"
                detailLabel.text = "当你确认新的故事片段后，它会在这里形成清晰的脉络。"
            } else {
                summaryLabel.text = "已整理 \(presentation.storyCount) 条故事线索"
                detailLabel.text = presentation.associatedStoryCount > 0
                    ? "其中 \(presentation.associatedStoryCount) 处关联帮助你回顾不同阶段的故事。"
                    : "你可以从不同方面回顾已经确认的故事。"
            }
            presentation.dimensions.forEach { dimensionStack.addArrangedSubview(dimensionRow(for: $0)) }
        case .rebuilding:
            summaryLabel.text = "正在更新人生地图"
            detailLabel.text = "已确认的内容整理完成后会显示在这里。"
        case .unavailable:
            renderUnavailable()
        case .failed:
            summaryLabel.text = "暂时无法读取人生地图"
            detailLabel.text = "请稍后刷新重试。"
        }
    }

    private func renderUnavailable() {
        summaryLabel.text = "人生地图暂不可用"
        detailLabel.text = "当前不会显示不完整或过期的故事线索。"
    }

    private func dimensionRow(for dimension: OwnerTruthLifeMapDimension) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 4
        container.isLayoutMarginsRelativeArrangement = true
        container.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14,
            leading: 14,
            bottom: 14,
            trailing: 14
        )
        container.backgroundColor = DJDesignTokens.Color.surface
        container.layer.cornerRadius = 10

        let title = UILabel()
        title.font = DJDesignTokens.Font.body(16)
        title.textColor = DJDesignTokens.Color.textPrimary
        title.text = dimension.dimension.lifeMapTitle

        let detail = UILabel()
        detail.font = DJDesignTokens.Font.body(14)
        detail.textColor = DJDesignTokens.Color.textSecondary
        detail.numberOfLines = 0
        detail.text = dimension.confirmedEvidenceCount == 0
            ? "还没有已确认的线索"
            : "已确认 \(dimension.confirmedEvidenceCount) 条线索"

        container.addArrangedSubview(title)
        container.addArrangedSubview(detail)
        return container
    }

    private func clearDimensionRows() {
        dimensionStack.arrangedSubviews.forEach { view in
            dimensionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    @objc private func refreshTapped() {
        useCase.refresh()
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var renderedSummaryForUIQA: String {
        summaryLabel.text ?? ""
    }

    var renderedDetailForUIQA: String {
        detailLabel.text ?? ""
    }

    var renderedDimensionCountForUIQA: Int {
        dimensionStack.arrangedSubviews.count
    }
    #endif
}

private extension OwnerTruthKnowledgeRecommendationDimension {
    var lifeMapTitle: String {
        switch self {
        case .lifeStage:
            return "人生阶段"
        case .importantPeople:
            return "重要的人"
        case .keyDecisions:
            return "关键决定"
        case .professionalExperience:
            return "职业经历"
        case .values:
            return "价值与感受"
        case .aspirationsAndBoundaries:
            return "愿望与边界"
        }
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)

/// In-memory preview only. It verifies the default-off read surface without
/// granting a release policy, reading a backend response, or showing raw
/// Owner Truth fields in a simulator screenshot.
enum OwnerTruthLifeMapPresentationUIQASmoke {
    static func run(
        accountLease: AccountLease,
        navigationController: UINavigationController,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            completion([
                "completed": false,
                "failureReason": "invalidVault",
            ])
            return
        }

        let client = FixtureClient(vaultID: vaultID)
        let controller = OwnerTruthLifeMapViewController(
            accountLease: accountLease,
            client: client,
            releasePolicyAvailable: { true }
        )
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let visibleText = [
                controller.renderedSummaryForUIQA,
                controller.renderedDetailForUIQA,
            ].joined(separator: " ")
            let privateFieldsRendered = visibleText.localizedCaseInsensitiveContains("source")
                || visibleText.localizedCaseInsensitiveContains("thread")
                || visibleText.localizedCaseInsensitiveContains("policy")
                || visibleText.contains("memoryVersionId")
            let dimensionCount = controller.renderedDimensionCountForUIQA
            let completed = client.requestCount == 1
                && controller.title == "人生地图"
                && controller.renderedSummaryForUIQA == "已整理 2 条故事线索"
                && dimensionCount == OwnerTruthKnowledgeRecommendationDimension.allCases.count
                && !privateFieldsRendered
                && !visibleText.contains("%")

            completion([
                "completed": completed,
                "requestCount": client.requestCount,
                "storyCount": 2,
                "dimensionCount": dimensionCount,
                "privateFieldsRendered": privateFieldsRendered,
                "completionPercentageRendered": visibleText.contains("%"),
                "inMemoryPreview": true,
                "releasePolicyBypassedForPreview": true,
                "backendNetworkStarted": false,
                "persistentInterviewWriteStarted": false,
                "publicRouteChanged": false,
                "launchArguments": [
                    QALaunchScenario.ownerTruthLifeMapPresentationSmoke.rawValue,
                ],
            ])
        }
    }

    private final class FixtureClient: OwnerTruthLifeMapPresentationClient {
        private let vaultID: OwnerTruthVaultID
        private(set) var requestCount = 0

        init(vaultID: OwnerTruthVaultID) {
            self.vaultID = vaultID
        }

        func fetchOwnerTruthLifeMapPresentation(
            vaultID: OwnerTruthVaultID,
            completion: @escaping (Result<OwnerTruthLifeMapPresentation, Error>) -> Void
        ) {
            guard vaultID == self.vaultID else {
                completion(.failure(OwnerTruthRemoteContractError.invalidLifeMapPresentation("vault mismatch")))
                return
            }
            requestCount += 1
            do {
                completion(.success(try OwnerTruthLifeMapPresentation(
                    backendJSONObject: [
                        "schemaVersion": OwnerTruthLifeMapPresentation.schemaVersion,
                        "vaultId": vaultID.rawValue,
                        "lifeMap": [
                            "state": "ready",
                            "storyCount": 2,
                            "associatedStoryCount": 1,
                            "dimensions": OwnerTruthKnowledgeRecommendationDimension.allCases.enumerated().map {
                                index,
                                dimension in
                                [
                                    "dimension": dimension.rawValue,
                                    "confirmedEvidenceCount": dimension == .keyDecisions ? 1 : 0,
                                    "coveredFacetCount": index == 0 ? 1 : 0,
                                    "unfilledFacetCount": max(0, dimension.facetOrder.count - (index == 0 ? 1 : 0)),
                                    "relatedStoryCount": index == 0 ? 1 : 0,
                                ]
                            },
                        ],
                    ],
                    expectedVaultID: vaultID
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

#endif

/// Default-off, Owner-only recall tool. It is intentionally a secondary
/// reader: users can revisit confirmed memory previews without creating a
/// parallel editable memory store or exposing internal retrieval evidence.
final class OwnerTruthMemorySearchViewController: UIViewController {
    private let useCase: OwnerTruthMemorySearchPresentationUseCase
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let introductionLabel = UILabel()
    private let queryTextField = UITextField()
    private let searchButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let resultsStack = UIStackView()

    init(
        accountLease: AccountLease,
        client: OwnerTruthMemorySearchPresentationClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        useCase = OwnerTruthMemorySearchPresentationUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: releasePolicyAvailable
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "回顾检索"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "重新检索"
        configureView()
        configureUseCase()
        render(useCase.viewState)
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

    private func configureView() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 28,
            trailing: DJDesignTokens.Spacing.page
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        introductionLabel.text = "输入一个词或一句回忆，只回顾你已确认的内容。"
        introductionLabel.font = DJDesignTokens.Font.body(15)
        introductionLabel.textColor = DJDesignTokens.Color.textSecondary
        introductionLabel.numberOfLines = 0

        queryTextField.placeholder = "例如：童年、第一次工作"
        queryTextField.font = DJDesignTokens.Font.body(16)
        queryTextField.textColor = DJDesignTokens.Color.textPrimary
        queryTextField.backgroundColor = DJDesignTokens.Color.surface
        queryTextField.layer.cornerRadius = 10
        queryTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        queryTextField.leftViewMode = .always
        queryTextField.returnKeyType = .search
        queryTextField.autocorrectionType = .no
        queryTextField.accessibilityIdentifier = "owner-truth-memory-search-query"
        queryTextField.addTarget(self, action: #selector(searchSubmitted), for: .editingDidEndOnExit)

        var searchConfiguration = UIButton.Configuration.filled()
        searchConfiguration.title = "检索"
        searchConfiguration.baseBackgroundColor = DJDesignTokens.Color.accent
        searchConfiguration.baseForegroundColor = .white
        searchConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 11,
            leading: 16,
            bottom: 11,
            trailing: 16
        )
        searchButton.configuration = searchConfiguration
        searchButton.layer.cornerRadius = 10
        searchButton.accessibilityIdentifier = "owner-truth-memory-search-submit"
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)

        let searchRow = UIStackView(arrangedSubviews: [queryTextField, searchButton])
        searchRow.axis = .horizontal
        searchRow.alignment = .fill
        searchRow.spacing = 8
        searchButton.widthAnchor.constraint(equalToConstant: 76).isActive = true
        queryTextField.heightAnchor.constraint(equalToConstant: 46).isActive = true

        statusLabel.font = DJDesignTokens.Font.title(20)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-memory-search-status"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-memory-search-detail"

        resultsStack.axis = .vertical
        resultsStack.alignment = .fill
        resultsStack.spacing = 10
        resultsStack.accessibilityIdentifier = "owner-truth-memory-search-results"

        [introductionLabel, searchRow, statusLabel, detailLabel, resultsStack].forEach {
            stackView.addArrangedSubview($0)
        }

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

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            if Thread.isMainThread {
                self?.render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthMemorySearchPresentationViewState) {
        clearResultRows()
        let isLoading = state.phase == .loading
        searchButton.isEnabled = !isLoading
        queryTextField.isEnabled = !isLoading
        navigationItem.rightBarButtonItem?.isEnabled = !isLoading

        switch state.phase {
        case .idle:
            statusLabel.text = "回顾已确认的记忆"
            detailLabel.text = "检索结果只用于帮助你回顾，不会创建或修改任何记忆。"
        case .loading:
            statusLabel.text = "正在回顾已确认的故事线索"
            detailLabel.text = "请稍候。"
        case .ready:
            guard let presentation = state.presentation else {
                renderUnavailable()
                return
            }
            if presentation.results.isEmpty {
                statusLabel.text = "没有找到相关的已确认记忆"
                detailLabel.text = "可以换一个词，或在回响中继续补充新的故事。"
            } else {
                statusLabel.text = "找到 \(presentation.results.count) 条已确认线索"
                detailLabel.text = "以下内容仅供你回顾已经确认的记忆。"
                presentation.results.forEach { resultsStack.addArrangedSubview(resultRow(for: $0)) }
            }
        case .rebuilding:
            statusLabel.text = "正在整理回顾索引"
            detailLabel.text = "已确认的内容整理完成后，可再次检索。"
        case .unavailable:
            renderUnavailable()
        case .failed:
            statusLabel.text = "暂时无法完成回顾检索"
            detailLabel.text = "请稍后重试。"
        }
    }

    private func renderUnavailable() {
        statusLabel.text = "回顾检索暂不可用"
        detailLabel.text = "当前不会显示不完整或不属于你的记忆线索。"
    }

    private func resultRow(for result: OwnerTruthMemorySearchPresentationResult) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 6
        container.isLayoutMarginsRelativeArrangement = true
        container.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14,
            leading: 14,
            bottom: 14,
            trailing: 14
        )
        container.backgroundColor = DJDesignTokens.Color.surface
        container.layer.cornerRadius = 10

        let title = UILabel()
        title.font = DJDesignTokens.Font.label(13)
        title.textColor = DJDesignTokens.Color.textTertiary
        title.text = "已确认线索 \(result.rank)"

        let preview = UILabel()
        preview.font = DJDesignTokens.Font.body(16)
        preview.textColor = DJDesignTokens.Color.textPrimary
        preview.numberOfLines = 0
        preview.text = result.preview

        container.addArrangedSubview(title)
        container.addArrangedSubview(preview)
        return container
    }

    private func clearResultRows() {
        resultsStack.arrangedSubviews.forEach { view in
            resultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func performSearch() {
        useCase.search(query: queryTextField.text ?? "")
    }

    @objc private func searchTapped() {
        performSearch()
    }

    @objc private func searchSubmitted() {
        performSearch()
    }

    @objc private func refreshTapped() {
        performSearch()
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var renderedStatusForUIQA: String {
        statusLabel.text ?? ""
    }

    var renderedDetailForUIQA: String {
        detailLabel.text ?? ""
    }

    var renderedResultCountForUIQA: Int {
        resultsStack.arrangedSubviews.count
    }

    func submitQueryForUIQA(_ query: String) {
        queryTextField.text = query
        performSearch()
    }
    #endif
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)

/// In-memory only. The smoke proves the presentation is bounded and readable
/// without opening a release route or sending any Owner Truth request.
enum OwnerTruthMemorySearchPresentationUIQASmoke {
    static func run(
        accountLease: AccountLease,
        navigationController: UINavigationController,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            completion([
                "completed": false,
                "failureReason": "invalidVault",
            ])
            return
        }

        let client = FixtureClient(vaultID: vaultID)
        let controller = OwnerTruthMemorySearchViewController(
            accountLease: accountLease,
            client: client,
            releasePolicyAvailable: { true }
        )
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()
        controller.submitQueryForUIQA("童年")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let visibleText = [
                controller.renderedStatusForUIQA,
                controller.renderedDetailForUIQA,
            ].joined(separator: " ")
            let privateFieldsRendered = visibleText.localizedCaseInsensitiveContains("source")
                || visibleText.localizedCaseInsensitiveContains("thread")
                || visibleText.localizedCaseInsensitiveContains("policy")
                || visibleText.localizedCaseInsensitiveContains("memoryVersionId")
                || visibleText.localizedCaseInsensitiveContains("checkpoint")
            let resultCount = controller.renderedResultCountForUIQA
            let completed = client.requestCount == 1
                && controller.title == "回顾检索"
                && controller.renderedStatusForUIQA == "找到 1 条已确认线索"
                && resultCount == 1
                && !privateFieldsRendered

            completion([
                "completed": completed,
                "requestCount": client.requestCount,
                "resultCount": resultCount,
                "privateFieldsRendered": privateFieldsRendered,
                "inMemoryPreview": true,
                "releasePolicyBypassedForPreview": true,
                "backendNetworkStarted": false,
                "persistentInterviewWriteStarted": false,
                "publicRouteChanged": false,
                "launchArguments": [
                    QALaunchScenario.ownerTruthMemorySearchPresentationSmoke.rawValue,
                ],
            ])
        }
    }

    private final class FixtureClient: OwnerTruthMemorySearchPresentationClient {
        private let vaultID: OwnerTruthVaultID
        private(set) var requestCount = 0

        init(vaultID: OwnerTruthVaultID) {
            self.vaultID = vaultID
        }

        func searchOwnerTruthMemoryPresentation(
            vaultID: OwnerTruthVaultID,
            query: String,
            completion: @escaping (Result<OwnerTruthMemorySearchPresentation, Error>) -> Void
        ) {
            guard vaultID == self.vaultID, query == "童年" else {
                completion(.failure(OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                    "fixture request mismatch"
                )))
                return
            }
            requestCount += 1
            do {
                completion(.success(try OwnerTruthMemorySearchPresentation(
                    backendJSONObject: [
                        "schemaVersion": OwnerTruthMemorySearchPresentation.schemaVersion,
                        "vaultId": vaultID.rawValue,
                        "memorySearch": [
                            "state": "ready",
                            "retrievalMode": "deterministicTextFallback",
                            "resultCount": 1,
                            "results": [[
                                "rank": 1,
                                "preview": "小时候在院子里听外婆讲故事。",
                                "memoryKind": "knowledge",
                                "perspectiveType": "firstPerson",
                                "sensitivity": "standard",
                                "matchKind": "searchText",
                            ]],
                        ],
                    ],
                    expectedVaultID: vaultID
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

/// In-memory only. This smoke exercises the display-safe ending summary
/// without opening a release route, reading a real interview or writing data.
enum OwnerTruthInterviewOutcomePresentationUIQASmoke {
    static func run(
        accountLease: AccountLease,
        navigationController: UINavigationController,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            completion([
                "completed": false,
                "failureReason": "invalidVault",
            ])
            return
        }
        let sessionID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        )
        let client = FixtureClient(vaultID: vaultID, sessionID: sessionID)
        let controller = OwnerTruthInterviewOutcomeViewController(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            releasePolicyAvailable: { true }
        )
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let visibleText = [
                controller.renderedStatusForUIQA,
                controller.renderedDetailForUIQA,
                controller.renderedThisSessionForUIQA,
                controller.renderedLaterContinueForUIQA,
            ].joined(separator: " ")
            let privateFieldsRendered = visibleText.localizedCaseInsensitiveContains("source")
                || visibleText.localizedCaseInsensitiveContains("thread")
                || visibleText.localizedCaseInsensitiveContains("policy")
                || visibleText.localizedCaseInsensitiveContains("memoryVersionId")
                || visibleText.localizedCaseInsensitiveContains("candidate")
                || visibleText.localizedCaseInsensitiveContains("sessionId")
            let completed = client.requestCount == 1
                && controller.title == "本次回顾"
                && controller.renderedStatusForUIQA == "本次回顾已整理"
                && controller.renderedThisSessionForUIQA
                    == "已确认 2 条内容。 有 1 批内容等待确认。"
                && controller.renderedLaterContinueForUIQA
                    == "想继续时，可以再回来。 已保留 1 条可继续线索。"
                && !privateFieldsRendered

            completion([
                "completed": completed,
                "requestCount": client.requestCount,
                "confirmedCount": 2,
                "pendingReviewBatchCount": 1,
                "eligibleCueCount": 1,
                "privateFieldsRendered": privateFieldsRendered,
                "inMemoryPreview": true,
                "releasePolicyBypassedForPreview": true,
                "backendNetworkStarted": false,
                "persistentInterviewWriteStarted": false,
                "publicRouteChanged": false,
                "launchArguments": [
                    QALaunchScenario.ownerTruthInterviewOutcomePresentationSmoke.rawValue,
                ],
            ])
        }
    }

    private final class FixtureClient: OwnerTruthInterviewOutcomePresentationClient {
        private let vaultID: OwnerTruthVaultID
        private let sessionID: OwnerTruthRecordID
        private(set) var requestCount = 0

        init(vaultID: OwnerTruthVaultID, sessionID: OwnerTruthRecordID) {
            self.vaultID = vaultID
            self.sessionID = sessionID
        }

        func fetchOwnerTruthInterviewOutcomePresentation(
            vaultID: OwnerTruthVaultID,
            sessionID: OwnerTruthRecordID,
            completion: @escaping (Result<OwnerTruthInterviewOutcomePresentation, Error>) -> Void
        ) {
            guard vaultID == self.vaultID, sessionID == self.sessionID else {
                completion(.failure(OwnerTruthRemoteContractError.invalidInterviewOutcomePresentation(
                    "fixture request mismatch"
                )))
                return
            }
            requestCount += 1
            do {
                completion(.success(try OwnerTruthInterviewOutcomePresentation(
                    backendJSONObject: [
                        "schemaVersion": OwnerTruthInterviewOutcomePresentation.schemaVersion,
                        "vaultId": vaultID.rawValue,
                        "sessionOutcome": [
                            "state": "ready",
                            "thisSession": [
                                "confirmedMemoryCount": 2,
                                "pendingReviewBatchCount": 1,
                            ],
                            "laterContinue": [
                                "canContinueLater": true,
                                "eligibleCueCount": 1,
                            ],
                        ],
                    ],
                    expectedVaultID: vaultID
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

#endif

private enum AutobiographyBookLayout {
    static let pageCornerRadius: CGFloat = 12
    static let pageInset: CGFloat = 24
    static let pageSpacing: CGFloat = 22
    static let photoHeight: CGFloat = 176
    static let itemSpacing: CGFloat = 16
    static let pageNumberTopSpacing: CGFloat = 18
}

private struct AutobiographyBookChapter {
    let indexText: String
    let title: String
    let subtitle: String
    let emptyText: String
    let items: [MemoryArchiveItem]
}

private final class AutobiographyBookViewController: UIViewController {
    private let repository: MemoryArchiveRepository
    private let context: DigitalHumanContext
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()

    private var isSelfMode: Bool {
        context.isSelfAssistant
    }

    private var personaName: String {
        context.resolvedDisplayName
    }

    private var bookTitle: String {
        isSelfMode ? "我的自传" : "\(personaName)的故事"
    }

    private static let bookDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    init(repository: MemoryArchiveRepository, context: DigitalHumanContext) {
        self.repository = repository
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = bookTitle
        view.backgroundColor = DJDesignTokens.Color.background
        setupLayout()
        reloadBook()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupLayout() {
        scrollView.backgroundColor = DJDesignTokens.Color.background
        scrollView.showsVerticalScrollIndicator = false

        mainStack.axis = .vertical
        mainStack.spacing = AutobiographyBookLayout.pageSpacing
        mainStack.layoutMargins = UIEdgeInsets(
            top: 18,
            left: DJDesignTokens.Spacing.page,
            bottom: 42,
            right: DJDesignTokens.Spacing.page
        )
        mainStack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)

        [scrollView, contentView, mainStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func reloadBook() {
        let items = repository.allItems().sorted { $0.createdAt < $1.createdAt }
        let chapters = makeChapters(from: items)

        mainStack.removeAllArrangedSubviews()
        mainStack.addArrangedSubview(makeOpeningPage(itemCount: items.count, pageNumber: 1))
        for (index, chapter) in chapters.enumerated() {
            mainStack.addArrangedSubview(makeChapterPage(chapter, pageNumber: index + 2))
        }
    }

    private func makeChapters(from items: [MemoryArchiveItem]) -> [AutobiographyBookChapter] {
        let rootItems = items.filter { $0.kind == .photo || $0.kind == .text }
        let growthItems = items.filter { $0.kind == .audio || $0.kind == .video }
        let wisdomItems = items.filter { $0.kind == .timeLetter }

        return [
            AutobiographyBookChapter(
                indexText: "CHAPTER I",
                title: isSelfMode ? "家族根基" : "记忆片段",
                subtitle: isSelfMode ? "Family Roots" : "Stories",
                emptyText: isSelfMode ? "还没有写入第一章的照片或文字。" : "这一章还没有可阅读的故事。",
                items: rootItems
            ),
            AutobiographyBookChapter(
                indexText: "CHAPTER II",
                title: "成长之旅",
                subtitle: "Growth Journey",
                emptyText: isSelfMode ? "声音和视频片段会在这里汇成旅程。" : "这一章暂时没有声音或影像。",
                items: growthItems
            ),
            AutobiographyBookChapter(
                indexText: "CHAPTER III",
                title: "人生智慧",
                subtitle: "Life Wisdom",
                emptyText: isSelfMode ? "时间信件会在这里成为写给未来的页。" : "这一章还在等待被打开。",
                items: wisdomItems
            ),
        ]
    }

    private func makeOpeningPage(itemCount: Int, pageNumber: Int) -> UIView {
        let page = makePaperPage()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.layoutMargins = UIEdgeInsets(
            top: 34,
            left: AutobiographyBookLayout.pageInset,
            bottom: 22,
            right: AutobiographyBookLayout.pageInset
        )
        stack.isLayoutMarginsRelativeArrangement = true

        let modeLabel = PaddingLabel(horizontalInset: 12, verticalInset: 5)
        modeLabel.text = isSelfMode ? "LIFE BOOK" : "FAMILY MEMORY"
        modeLabel.font = DJDesignTokens.Font.label(11)
        modeLabel.textColor = DJDesignTokens.Color.accentDeep
        modeLabel.backgroundColor = DJDesignTokens.Color.surfaceLow
        modeLabel.layer.cornerRadius = 12
        modeLabel.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = bookTitle
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = isSelfMode
            ? "这不是素材列表，而是把你记录下来的片段整理成一本可以翻阅的书。"
            : "把 \(personaName) 留下的片段整理成一本安静可读的故事。"
        subtitleLabel.font = UIFont.italicSystemFont(ofSize: 14)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42)

        let statsLabel = UILabel()
        statsLabel.text = "3 个章节 · \(max(1, itemCount + 1)) 页线索 · \(itemCount) 段素材"
        statsLabel.font = DJDesignTokens.Font.body(13)
        statsLabel.textColor = DJDesignTokens.Color.textTertiary
        statsLabel.textAlignment = .center
        statsLabel.numberOfLines = 0

        let quoteLabel = UILabel()
        quoteLabel.text = isSelfMode
            ? "所有记忆都先被好好收下，再慢慢长成故事。"
            : "愿每一页都保留原本的温度。"
        quoteLabel.font = DJDesignTokens.Font.title(17)
        quoteLabel.textColor = DJDesignTokens.Color.textPrimary
        quoteLabel.textAlignment = .center
        quoteLabel.numberOfLines = 0

        stack.addArrangedSubview(modeLabel)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(statsLabel)
        stack.addArrangedSubview(quoteLabel)
        stack.addArrangedSubview(makePageNumberLabel(pageNumber))
        page.addSubview(stack)

        [stack, divider].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: page.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 48),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])

        return page
    }

    private func makeChapterPage(_ chapter: AutobiographyBookChapter, pageNumber: Int) -> UIView {
        let page = makePaperPage()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.layoutMargins = UIEdgeInsets(
            top: 28,
            left: AutobiographyBookLayout.pageInset,
            bottom: 20,
            right: AutobiographyBookLayout.pageInset
        )
        stack.isLayoutMarginsRelativeArrangement = true

        stack.addArrangedSubview(makeChapterHeader(chapter))

        if chapter.items.isEmpty {
            stack.addArrangedSubview(makeChapterEmptyView(chapter.emptyText))
        } else {
            chapter.items.forEach { item in
                stack.addArrangedSubview(makeBookMemoryView(item))
            }
        }

        stack.addArrangedSubview(makePageNumberLabel(pageNumber))
        page.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: page.bottomAnchor),
        ])

        return page
    }

    private func makePaperPage() -> UIView {
        let page = UIView()
        page.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)
        page.layer.cornerRadius = AutobiographyBookLayout.pageCornerRadius
        page.layer.borderWidth = 1
        page.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.34).cgColor
        DJDesignTokens.applySoftShadow(to: page)
        return page
    }

    private func makeChapterHeader(_ chapter: AutobiographyBookChapter) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let indexLine = UIStackView()
        indexLine.alignment = .center
        indexLine.spacing = 10

        let indexLabel = UILabel()
        indexLabel.text = chapter.indexText
        indexLabel.font = DJDesignTokens.Font.label(12)
        indexLabel.textColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.86)
        indexLabel.setContentHuggingPriority(.required, for: .horizontal)

        let line = UIView()
        line.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42)

        indexLine.addArrangedSubview(indexLabel)
        indexLine.addArrangedSubview(line)

        let titleLine = UIStackView()
        titleLine.alignment = .lastBaseline
        titleLine.spacing = 10

        let titleLabel = UILabel()
        titleLabel.text = chapter.title
        titleLabel.font = DJDesignTokens.Font.title(23)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        let subtitleLabel = UILabel()
        subtitleLabel.text = chapter.subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(12)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary

        titleLine.addArrangedSubview(titleLabel)
        titleLine.addArrangedSubview(subtitleLabel)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(indexLine)
        stack.addArrangedSubview(titleLine)

        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.heightAnchor.constraint(equalToConstant: 1),
        ])

        return stack
    }

    private func makeChapterEmptyView(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        container.layer.cornerRadius = 18
        container.layer.borderWidth = 1
        container.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.26).cgColor

        let label = UILabel()
        label.text = text
        label.font = UIFont.italicSystemFont(ofSize: 14)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0

        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    private func makeBookMemoryView(_ item: MemoryArchiveItem) -> UIView {
        switch item.kind {
        case .photo:
            return makePhotoMemoryView(item)
        case .audio:
            return makeAudioMemoryView(item)
        case .text, .timeLetter, .video:
            return makeTextualMemoryView(item)
        }
    }

    private func makePhotoMemoryView(_ item: MemoryArchiveItem) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let imageContainer = UIView()
        imageContainer.backgroundColor = UIColor.white.withAlphaComponent(0.48)
        imageContainer.layer.cornerRadius = 8
        imageContainer.layer.borderWidth = 1
        imageContainer.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.24).cgColor
        imageContainer.clipsToBounds = true

        let image = item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }
        if let image {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageContainer.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            ])
        } else {
            let iconView = UIImageView(image: UIImage(systemName: "photo"))
            iconView.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.44)
            iconView.contentMode = .scaleAspectFit
            imageContainer.addSubview(iconView)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 36),
                iconView.heightAnchor.constraint(equalToConstant: 36),
            ])
        }

        let captionLabel = makeBookItemMetaLabel("\(Self.bookDateFormatter.string(from: item.createdAt)) · 照片")
        captionLabel.textAlignment = .right

        stack.addArrangedSubview(imageContainer)
        stack.addArrangedSubview(captionLabel)
        stack.addArrangedSubview(makeBookItemTitleLabel(item.archivePresentation.title))
        stack.addArrangedSubview(makeBookItemBodyLabel(item.archivePresentation.note))

        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageContainer.heightAnchor.constraint(equalToConstant: AutobiographyBookLayout.photoHeight),
        ])

        return stack
    }

    private func makeAudioMemoryView(_ item: MemoryArchiveItem) -> UIView {
        let card = makeBookItemCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        let header = UIStackView()
        header.alignment = .center
        header.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: "waveform"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let metaLabel = makeBookItemMetaLabel("\(Self.bookDateFormatter.string(from: item.createdAt)) · 声音")
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(metaLabel)
        header.addArrangedSubview(UIView())

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(makeBookItemTitleLabel(item.archivePresentation.title))
        stack.addArrangedSubview(makeBookItemBodyLabel(item.archivePresentation.note))
        stack.addArrangedSubview(makeBookWaveformView(durationText: item.metadata["durationText"] ?? "声音片段"))

        card.addSubview(stack)
        [stack, iconView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])

        return card
    }

    private func makeTextualMemoryView(_ item: MemoryArchiveItem) -> UIView {
        let card = makeBookItemCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 9
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        let kindText: String
        switch item.kind {
        case .photo:
            kindText = "照片"
        case .audio:
            kindText = "声音"
        case .text:
            kindText = "文字"
        case .timeLetter:
            kindText = "信件"
        case .video:
            kindText = "视频"
        }

        stack.addArrangedSubview(makeBookItemMetaLabel("\(Self.bookDateFormatter.string(from: item.createdAt)) · \(kindText)"))
        stack.addArrangedSubview(makeBookItemTitleLabel(item.archivePresentation.title))
        stack.addArrangedSubview(makeBookItemBodyLabel(item.archivePresentation.note))
        if let metadata = item.archivePresentation.metadataSummary {
            stack.addArrangedSubview(makeBookItemMetaLabel(metadata))
        }

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeBookItemCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.20).cgColor
        return card
    }

    private func makeBookWaveformView(durationText: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.52)
        container.layer.cornerRadius = 18

        let bars = UIStackView()
        bars.axis = .horizontal
        bars.alignment = .center
        bars.spacing = 4

        [10, 20, 14, 28, 18, 24, 12, 22, 16].forEach { height in
            let bar = UIView()
            bar.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.48)
            bar.layer.cornerRadius = 1.5
            bars.addArrangedSubview(bar)
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.widthAnchor.constraint(equalToConstant: 3).isActive = true
            bar.heightAnchor.constraint(equalToConstant: CGFloat(height)).isActive = true
        }

        let durationLabel = UILabel()
        durationLabel.text = durationText
        durationLabel.font = DJDesignTokens.Font.label(11)
        durationLabel.textColor = DJDesignTokens.Color.textTertiary
        durationLabel.textAlignment = .right

        container.addSubview(bars)
        container.addSubview(durationLabel)
        [bars, durationLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            bars.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            bars.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            bars.heightAnchor.constraint(equalToConstant: 30),

            durationLabel.leadingAnchor.constraint(equalTo: bars.trailingAnchor, constant: 10),
            durationLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            durationLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    private func makeBookItemTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.title(18)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 0
        return label
    }

    private func makeBookItemBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.body(15)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.numberOfLines = 0
        return label
    }

    private func makeBookItemMetaLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 0
        return label
    }

    private func makePageNumberLabel(_ number: Int) -> UILabel {
        let label = UILabel()
        label.text = "- \(String(format: "%02d", number)) -"
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }
}

extension MemoryArchiveViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        defer { clearPhotoPickerOperation() }

        guard let accountLease = photoPickerAccountLease,
              let archiveContext = photoPickerArchiveContext,
              validatePhotoPickerOperation(accountLease, at: .ui) else {
            return
        }

        guard let image = info[.originalImage] as? UIImage else {
            showToast("照片读取失败", type: .error)
            return
        }

        do {
            let mediaMetadata = try saveImageToArchive(image, accountLease: accountLease)
            let item = MemoryArchiveItemFactory.makePhotoItem(
                localPath: mediaMetadata.relativePath,
                mediaMetadata: mediaMetadata,
                ownerUserId: accountLease.subjectId
            )
            savePhotoArchiveItem(
                item,
                image: image,
                successMessage: "照片已封存",
                accountLease: accountLease,
                archiveContext: archiveContext
            )
        } catch {
            if validateMediaAccountLease(accountLease, at: .ui) {
                showToast("照片保存失败", type: .error)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        clearPhotoPickerOperation()
    }
}

extension MemoryArchiveViewController: MemoryArchiveCreationSheetViewControllerDelegate {
    func memoryArchiveCreationSheet(
        _ viewController: MemoryArchiveCreationSheetViewController,
        didSelect option: MemoryArchiveCreationOption
    ) {
        guard isSelfAutobiographyMode else {
            viewController.dismiss(animated: true) { [weak self] in
                self?.showReadOnlyArchiveToast()
            }
            return
        }

        switch option.archiveKind {
        case .text:
            presentTextEntry(kind: .text)
        case .photo:
            presentPhotoEntry()
        case .audio:
            guard isArchiveAudioCreationEnabled else {
                showToast(MemoryArchiveMediaReleaseReadiness.unavailableCopy(for: .audio), type: .info)
                return
            }
            presentAudioEntry()
        case .timeLetter:
            guard isTimeLetterCreationEnabled else { return }
            presentTextEntry(kind: .timeLetter)
        case .video:
            guard isArchiveVideoCreationEnabled else {
                showToast(MemoryArchiveMediaReleaseReadiness.unavailableCopy(for: .video), type: .info)
                return
            }
            presentVideoEntry()
        }
    }
}

private enum ArchiveImageSaveError: LocalizedError {
    case jpegEncodingFailed
    case accountSessionChanged

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "照片编码失败"
        case .accountSessionChanged:
            return "账号状态已变化"
        }
    }
}

private enum ArchiveRemoteSyncStatus {
    case idle
    case syncing
    case synced
    case fallback
}

private extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { subview in
            removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}

private final class MemoryArchiveItemRowControl: UIControl {
    let item: MemoryArchiveItem

    init(item: MemoryArchiveItem) {
        self.item = item
        super.init(frame: .zero)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PaddingLabel: UILabel {
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat

    init(horizontalInset: CGFloat, verticalInset: CGFloat) {
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        super.drawText(in: rect.inset(by: insets))
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insets = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        let insetBounds = bounds.inset(by: insets)
        let textRect = super.textRect(forBounds: insetBounds, limitedToNumberOfLines: numberOfLines)
        return textRect.inset(by: UIEdgeInsets(
            top: -verticalInset,
            left: -horizontalInset,
            bottom: -verticalInset,
            right: -horizontalInset
        ))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + horizontalInset * 2,
            height: size.height + verticalInset * 2
        )
    }
}

// MARK: - Default-off interview session state QA

#if UI_QA_SIMULATOR && targetEnvironment(simulator)

/// This controller has no product navigation entry. It exists only for the
/// UI-QA launch scenario and renders the value-minimized state returned by the
/// private interview session read contract.
final class OwnerTruthInterviewSessionStateViewController: UIViewController {
    private let useCase: OwnerTruthInterviewSessionStateUseCase
    private let stackView = UIStackView()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState: OwnerTruthInterviewSessionStateViewState = .idle
    var onViewStateRendered: ((OwnerTruthInterviewSessionStateViewState) -> Void)?

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewSessionStateClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.useCase = OwnerTruthInterviewSessionStateUseCase(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "访谈会话状态（QA）"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        refreshButton.accessibilityIdentifier = "owner-truth-interview-session-state-refresh"
        configureView()
        configureUseCase()
        render(useCase.viewState)
        useCase.send(.refresh)
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

    private func configureView() {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 24,
            trailing: DJDesignTokens.Spacing.page
        )

        subtitleLabel.text = "仅用于受控 QA 读取；不展示对话内容，也不会生成记忆、候选或审核回执。"
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        statusLabel.font = DJDesignTokens.Font.title(20)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-interview-session-state-status"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-interview-session-state-detail"

        [subtitleLabel, statusLabel, detailLabel].forEach(stackView.addArrangedSubview)
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func render(_ state: OwnerTruthInterviewSessionStateViewState) {
        renderedState = state
        refreshButton.isEnabled = state.phase != .loading
        statusLabel.text = statusText(for: state)
        detailLabel.text = detailText(for: state)
        onViewStateRendered?(state)
    }

    private func statusText(for state: OwnerTruthInterviewSessionStateViewState) -> String {
        switch state.phase {
        case .idle:
            return "准备读取会话状态"
        case .loading:
            return "正在读取会话状态"
        case .ready:
            return lifecycleText(state.session?.lifecycle)
        case .unavailable:
            return unavailableText(state.notice)
        case .failed:
            return "会话状态读取失败"
        }
    }

    private func detailText(for state: OwnerTruthInterviewSessionStateViewState) -> String {
        guard let session = state.session else {
            switch state.phase {
            case .failed:
                return "未保留旧状态，可在受控 QA 环境重新读取。"
            case .unavailable:
                return "此入口只在 QA 开关和当前账号租约有效时可用。"
            default:
                return ""
            }
        }
        return [
            "边界：\(boundaryText(session.boundary))",
            "疲劳：\(fatigueText(session.fatigue))",
            "轮次：\(session.ownerTurnCount) · 深入：\(session.deepeningTurnCount) · 候选批次：\(session.candidateBatchTurnCount)",
            "待确认审核：\(session.hasPendingReviewBatch ? "有" : "无")",
            "会话版本：\(session.rowVersion) · 线程版本：\(session.threadVersion) · 权威纪元：\(session.authorityEpoch)",
        ].joined(separator: "\n")
    }

    @objc private func refreshTapped() {
        useCase.send(.refresh)
    }

    private func lifecycleText(_ lifecycle: OwnerTruthInterviewSessionLifecycle?) -> String {
        switch lifecycle {
        case .active:
            return "会话进行中"
        case .paused:
            return "会话已暂停"
        case .ended:
            return "会话已结束"
        case nil:
            return "会话状态暂不可用"
        }
    }

    private func boundaryText(_ boundary: OwnerTruthInterviewSessionBoundary) -> String {
        switch boundary {
        case .open: return "可继续"
        case .skipOnce: return "本轮跳过"
        case .cooldown: return "冷却中"
        case .doNotAsk: return "不再追问"
        }
    }

    private func fatigueText(_ fatigue: OwnerTruthInterviewSessionFatigue) -> String {
        switch fatigue {
        case .normal: return "正常"
        case .guarded: return "谨慎"
        case .exhausted: return "疲劳"
        }
    }

    private func unavailableText(_ notice: OwnerTruthInterviewSessionStateNotice?) -> String {
        switch notice {
        case .qaOnlyDisabled:
            return "QA 开关未启用"
        case .invalidVault:
            return "当前档案空间不可用"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入"
        case .requestFailed, nil:
            return "会话状态暂不可用"
        }
    }
}

struct OwnerTruthInterviewSessionStateUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-session-state-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let stateRendered: Bool
    let lifecycle: String?
    let boundary: String?
    let fatigue: String?
    let hasPendingReviewBatch: Bool
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewSessionStateUIQASmoke {
    static let sessionID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000266")!
    )

    static func makeViewController(
        accountLease: AccountLease
    ) -> OwnerTruthInterviewSessionStateViewController {
        let client = InterviewSessionStateUIQAClient(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            sessionID: sessionID
        )
        let controller = OwnerTruthInterviewSessionStateViewController(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            qaGateEnabled: { OwnerTruthCandidateReviewQAGate.isEnabled }
        )
        let scenario = InterviewSessionStateUIQAScenario()
        controller.onViewStateRendered = { state in
            scenario.consume(state)
        }
        return controller
    }

    static func writeFailure(_ reason: String) {
        let result = OwnerTruthInterviewSessionStateUIQASmokeResult(
            completed: false,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            stateRendered: false,
            lifecycle: nil,
            boundary: nil,
            fatigue: nil,
            hasPendingReviewBatch: false,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewSessionStateSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: reason
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewSessionStateSmoke failed result=\(resultURL.path) reason=\(reason)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewSessionStateSmoke failed reason=\(reason) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewSessionStateUIQAScenario {
    private var didWrite = false

    func consume(_ state: OwnerTruthInterviewSessionStateViewState) {
        guard !didWrite,
              case .ready = state.phase,
              let session = state.session else {
            return
        }
        didWrite = true
        let result = OwnerTruthInterviewSessionStateUIQASmokeResult(
            completed: OwnerTruthCandidateReviewQAGate.isEnabled
                && session.lifecycle == .active
                && session.boundary == .open
                && session.fatigue == .normal
                && !session.hasPendingReviewBatch,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            stateRendered: true,
            lifecycle: session.lifecycle.rawValue,
            boundary: session.boundary.rawValue,
            fatigue: session.fatigue.rawValue,
            hasPendingReviewBatch: session.hasPendingReviewBatch,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewSessionStateSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: nil
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewSessionStateSmoke completed result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewSessionStateSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}

private final class InterviewSessionStateUIQAClient: OwnerTruthInterviewSessionStateClient {
    private let vaultID: OwnerTruthVaultID?
    private let sessionID: OwnerTruthRecordID

    init(vaultID: OwnerTruthVaultID?, sessionID: OwnerTruthRecordID) {
        self.vaultID = vaultID
        self.sessionID = sessionID
    }

    func fetchOwnerTruthInterviewSessionState(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewSessionState, Error>) -> Void
    ) {
        guard self.vaultID == vaultID, self.sessionID == sessionID else {
            completion(.failure(InterviewSessionStateUIQAClientError.invalidRequest))
            return
        }
        do {
            let session = try OwnerTruthInterviewSessionState(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewSessionState.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "session": [
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                        "rowVersion": 1,
                        "threadVersion": 1,
                        "ownerTurnCount": 0,
                        "deepeningTurnCount": 0,
                        "candidateBatchTurnCount": 0,
                        "fatigue": OwnerTruthInterviewSessionFatigue.normal.rawValue,
                        "hasPendingReviewBatch": false,
                        "authorityEpoch": 0,
                    ],
                ],
                expectedVaultID: vaultID
            )
            completion(.success(session))
        } catch {
            completion(.failure(error))
        }
    }
}

private enum InterviewSessionStateUIQAClientError: Error {
    case invalidRequest
}

// MARK: - Default-off interview orchestration QA

/// This simulator-only page renders the bounded, value-free orchestration
/// decision. It intentionally has no navigation entry in the product UI.
final class OwnerTruthInterviewOrchestrationViewController: UIViewController {
    private let useCase: OwnerTruthInterviewOrchestrationUseCase
    private let stackView = UIStackView()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private lazy var refreshButton = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refreshTapped)
    )

    private var renderedState: OwnerTruthInterviewOrchestrationViewState = .idle
    var onViewStateRendered: ((OwnerTruthInterviewOrchestrationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewOrchestrationClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        useCase = OwnerTruthInterviewOrchestrationUseCase(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "访谈编排（QA）"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.rightBarButtonItem = refreshButton
        refreshButton.accessibilityIdentifier = "owner-truth-interview-orchestration-refresh"
        configureView()
        configureUseCase()
        render(useCase.viewState)
        refresh()
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

    private func configureView() {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 24,
            trailing: DJDesignTokens.Spacing.page
        )

        subtitleLabel.text = "仅用于受控 QA：只读取策略动作和计数，不展示主题、对话内容或记忆标识，也不会写入会话。"
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        statusLabel.font = DJDesignTokens.Font.title(20)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-interview-orchestration-status"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-interview-orchestration-detail"

        [subtitleLabel, statusLabel, detailLabel].forEach(stackView.addArrangedSubview)
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
    }

    private func refresh() {
        useCase.send(.refresh(OwnerTruthInterviewOrchestrationUIQASmoke.signals))
    }

    private func render(_ state: OwnerTruthInterviewOrchestrationViewState) {
        renderedState = state
        refreshButton.isEnabled = state.phase != .loading
        statusLabel.text = statusText(for: state)
        detailLabel.text = detailText(for: state)
        onViewStateRendered?(state)
    }

    private func statusText(for state: OwnerTruthInterviewOrchestrationViewState) -> String {
        switch state.phase {
        case .idle:
            return "准备读取引导策略"
        case .loading:
            return "正在读取引导策略"
        case .ready:
            return "策略动作：\(actionText(state.orchestration?.decision.action))"
        case .unavailable:
            return unavailableText(state.notice)
        case .failed:
            return "引导策略暂不可用"
        }
    }

    private func detailText(for state: OwnerTruthInterviewOrchestrationViewState) -> String {
        guard let read = state.orchestration else {
            switch state.phase {
            case .failed:
                return "未保留旧策略，可在受控 QA 环境重新读取。"
            case .unavailable:
                return "此入口只在 QA 开关和当前账号租约有效时可用。"
            default:
                return ""
            }
        }
        let decision = read.decision
        let session = read.persistedSession
        return [
            "原因：\(decision.reasonCode) · 后续追问余量：\(decision.maxFollowupsRemaining)",
            "下个会话建议：\(lifecycleText(decision.nextSessionState)) · 待审核：\(decision.reviewBatchDue ? "是" : "否")",
            "当前会话：\(lifecycleText(session.lifecycle)) · \(boundaryText(session.boundary)) · \(fatigueText(session.fatigue))",
            "轮次：\(session.ownerTurnCount) · 深入：\(session.deepeningTurnCount) · 候选批次：\(session.candidateBatchTurnCount)",
        ].joined(separator: "\n")
    }

    @objc private func refreshTapped() {
        refresh()
    }

    private func actionText(_ action: OwnerTruthInterviewOrchestrationAction?) -> String {
        switch action {
        case .listen: return "先聆听"
        case .deepen: return "继续深入"
        case .clarify: return "先澄清"
        case .broaden: return "换个角度"
        case .summarize: return "先总结"
        case .pause: return "暂停本话题"
        case nil: return "暂不可用"
        }
    }

    private func lifecycleText(_ lifecycle: OwnerTruthInterviewOrchestrationNextSessionState) -> String {
        switch lifecycle {
        case .active: return "进行中"
        case .paused: return "已暂停"
        case .ending: return "准备结束"
        case .ended: return "已结束"
        case .invalid: return "无效"
        }
    }

    private func lifecycleText(_ lifecycle: OwnerTruthInterviewSessionLifecycle) -> String {
        switch lifecycle {
        case .active: return "进行中"
        case .paused: return "已暂停"
        case .ended: return "已结束"
        }
    }

    private func boundaryText(_ boundary: OwnerTruthInterviewSessionBoundary) -> String {
        switch boundary {
        case .open: return "可继续"
        case .skipOnce: return "本轮跳过"
        case .cooldown: return "冷却中"
        case .doNotAsk: return "不再追问"
        }
    }

    private func fatigueText(_ fatigue: OwnerTruthInterviewSessionFatigue) -> String {
        switch fatigue {
        case .normal: return "正常"
        case .guarded: return "谨慎"
        case .exhausted: return "疲劳"
        }
    }

    private func unavailableText(_ notice: OwnerTruthInterviewOrchestrationNotice?) -> String {
        switch notice {
        case .qaOnlyDisabled:
            return "QA 开关未启用"
        case .invalidVault:
            return "当前档案空间不可用"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入"
        case .requestFailed, nil:
            return "引导策略暂不可用"
        }
    }
}

struct OwnerTruthInterviewOrchestrationUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-orchestration-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let stateRendered: Bool
    let action: String?
    let reasonCode: String?
    let nextSessionState: String?
    let persistedLifecycle: String?
    let persistedBoundary: String?
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewOrchestrationUIQASmoke {
    static let sessionID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000267")!
    )
    static let signals = OwnerTruthInterviewOrchestrationSignals(userChangedTopic: true)

    static func makeViewController(
        accountLease: AccountLease
    ) -> OwnerTruthInterviewOrchestrationViewController {
        let client = InterviewOrchestrationUIQAClient(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            sessionID: sessionID
        )
        let controller = OwnerTruthInterviewOrchestrationViewController(
            accountLease: accountLease,
            sessionID: sessionID,
            client: client,
            qaGateEnabled: { OwnerTruthCandidateReviewQAGate.isEnabled }
        )
        let scenario = InterviewOrchestrationUIQAScenario()
        controller.onViewStateRendered = { state in
            scenario.consume(state)
        }
        return controller
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthInterviewOrchestrationUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                stateRendered: false,
                action: nil,
                reasonCode: nil,
                nextSessionState: nil,
                persistedLifecycle: nil,
                persistedBoundary: nil,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewOrchestrationSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            ),
            logPrefix: "failed"
        )
    }

    fileprivate static func writeCompleted(_ read: OwnerTruthInterviewOrchestrationRead) {
        let decision = read.decision
        let persisted = read.persistedSession
        let completed = OwnerTruthCandidateReviewQAGate.isEnabled
            && decision.action == .pause
            && decision.reasonCode == "topicChanged"
            && decision.nextSessionState == .paused
            && !decision.reviewBatchDue
            && persisted.lifecycle == .active
            && persisted.boundary == .open
            && persisted.ownerTurnCount == 1
        write(
            OwnerTruthInterviewOrchestrationUIQASmokeResult(
                completed: completed,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                stateRendered: true,
                action: decision.action.rawValue,
                reasonCode: decision.reasonCode,
                nextSessionState: decision.nextSessionState.rawValue,
                persistedLifecycle: persisted.lifecycle.rawValue,
                persistedBoundary: persisted.boundary.rawValue,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewOrchestrationSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: completed ? nil : "unexpectedOrchestrationRead"
            ),
            logPrefix: completed ? "completed" : "failed"
        )
    }

    private static func write(_ result: OwnerTruthInterviewOrchestrationUIQASmokeResult, logPrefix: String) {
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewOrchestrationSmoke \(logPrefix) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewOrchestrationSmoke \(logPrefix) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewOrchestrationUIQAScenario {
    private var didWrite = false

    func consume(_ state: OwnerTruthInterviewOrchestrationViewState) {
        guard !didWrite,
              case .ready = state.phase,
              let read = state.orchestration else {
            return
        }
        didWrite = true
        OwnerTruthInterviewOrchestrationUIQASmoke.writeCompleted(read)
    }
}

private final class InterviewOrchestrationUIQAClient: OwnerTruthInterviewOrchestrationClient {
    private let vaultID: OwnerTruthVaultID?
    private let sessionID: OwnerTruthRecordID

    init(vaultID: OwnerTruthVaultID?, sessionID: OwnerTruthRecordID) {
        self.vaultID = vaultID
        self.sessionID = sessionID
    }

    func fetchOwnerTruthInterviewOrchestration(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        signals: OwnerTruthInterviewOrchestrationSignals,
        completion: @escaping (Result<OwnerTruthInterviewOrchestrationRead, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              self.sessionID == sessionID,
              signals == OwnerTruthInterviewOrchestrationUIQASmoke.signals else {
            completion(.failure(InterviewOrchestrationUIQAClientError.invalidRequest))
            return
        }
        do {
            let read = try OwnerTruthInterviewOrchestrationRead(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewOrchestrationRead.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "orchestration": [
                        "schemaVersion": OwnerTruthInterviewOrchestrationRead.orchestrationSchemaVersion,
                        "policySchemaVersion": OwnerTruthInterviewOrchestrationRead.policySchemaVersion,
                        "decision": [
                            "schemaVersion": OwnerTruthInterviewOrchestrationRead.policySchemaVersion,
                            "action": OwnerTruthInterviewOrchestrationAction.pause.rawValue,
                            "reasonCode": "topicChanged",
                            "maxFollowupsRemaining": 0,
                            "reviewBatchDue": false,
                            "nextSessionState": OwnerTruthInterviewOrchestrationNextSessionState.paused.rawValue,
                            "consumesOneShotBoundary": false,
                        ],
                        "persistedSession": [
                            "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                            "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                            "ownerTurnCount": 1,
                            "deepeningTurnCount": 0,
                            "candidateBatchTurnCount": 1,
                            "fatigue": OwnerTruthInterviewSessionFatigue.normal.rawValue,
                        ],
                        "transientSignals": OwnerTruthInterviewOrchestrationRead.transientSignalsDescriptor,
                    ],
                ],
                expectedVaultID: vaultID
            )
            completion(.success(read))
        } catch {
            completion(.failure(error))
        }
    }
}

private enum InterviewOrchestrationUIQAClientError: Error {
    case invalidRequest
}

#endif

// MARK: - Default-off interview natural-input QA

enum OwnerTruthInterviewNaturalInputPresentation: Equatable {
    case qa
    case product

    var navigationTitle: String {
        switch self {
        case .qa:
            return "自然输入（QA）"
        case .product:
            return "今天想聊点什么？"
        }
    }

    var subtitle: String {
        switch self {
        case .qa:
            return "仅用于受控 QA：提交内容不在回执中回显，不会生成记忆、候选或审核结果。"
        case .product:
            return "写下此刻想分享的故事。"
        }
    }

    var submitTitle: String {
        switch self {
        case .qa:
            return "提交受控输入"
        case .product:
            return "发送"
        }
    }
}

/// The QA presentation remains isolated behind its launch gate. The product
/// presentation is reached only through Echo's fresh release-policy gate.
final class OwnerTruthInterviewNaturalInputViewController: UIViewController {
    private let useCase: OwnerTruthInterviewNaturalInputUseCase
    private let guidedRecommendationUseCase: OwnerTruthGuidedRecommendationPresentationUseCase?
    private let presentation: OwnerTruthInterviewNaturalInputPresentation
    private let accountLease: AccountLease
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lifeMapClient: OwnerTruthLifeMapPresentationClient
    private let lifeMapPolicyAvailable: () -> Bool
    private let memorySearchClient: OwnerTruthMemorySearchPresentationClient
    private let memorySearchPolicyAvailable: () -> Bool
    private let interviewOutcomeClient: OwnerTruthInterviewOutcomePresentationClient
    private let interviewOutcomePolicyAvailable: () -> Bool
    private let reviewBatchInboxClient: OwnerTruthInterviewPendingReviewBatchInboxClient
    private let reviewBatchAcknowledgementClient: OwnerTruthInterviewReviewBatchAcknowledgementClient
    private let reviewBatchAcknowledgementPolicyAvailable: () -> Bool
    private let candidateProposalAdmissionClient: OwnerTruthInterviewCandidateProposalAdmissionClient
    private let candidateProposalAdmissionPolicyAvailable: () -> Bool
    private let candidateProposalStatusClient: OwnerTruthInterviewCandidateProposalStatusClient
    private let candidateProposalStatusPolicyAvailable: () -> Bool
    private let candidateProposalConfirmationInboxControllerProvider: (AccountLease, OwnerTruthRecordID) -> UIViewController
    private let stackView = UIStackView()
    private let subtitleLabel = UILabel()
    private let guidedRecommendationStack = UIStackView()
    private let guidedRecommendationTitleLabel = UILabel()
    private let guidedRecommendationPromptStack = UIStackView()
    private let guidedRecommendationActivePromptLabel = UILabel()
    private let lifeMapButton = UIButton(type: .system)
    private let memorySearchButton = UIButton(type: .system)
    private let interviewOutcomeButton = UIButton(type: .system)
    private let reviewBatchAcknowledgementEntryButton = UIButton(type: .system)
    private let candidateProposalAdmissionEntryButton = UIButton(type: .system)
    private let candidateProposalStatusEntryButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let inputTextView = UITextView()
    private let submitButton = UIButton(type: .system)
    private let endSessionButton = UIButton(type: .system)
    private let boundaryActionsStack = UIStackView()
    private let productBoundaryActionsRow = UIStackView()
    private let skipOnceButton = UIButton(type: .system)
    private let cooldownButton = UIButton(type: .system)
    private let doNotAskButton = UIButton(type: .system)
    private let topicSwitchButton = UIButton(type: .system)
    private let deepeningCompletedButton = UIButton(type: .system)
    private let summaryCompletedButton = UIButton(type: .system)
    private let restoreDoNotAskButton = UIButton(type: .system)
    private let restoreCooldownButton = UIButton(type: .system)

    private var renderedState: OwnerTruthInterviewNaturalInputViewState = .idle
    private var guidedRecommendationPrompts: [OwnerTruthGuidedRecommendationPrompt] = []
    private var isSubmittingGuidedRecommendationFeedback = false
    private var lastGuidedRecommendationFeedbackNotice: OwnerTruthGuidedRecommendationPresentationNotice?
    private var isActivatingGuidedRecommendation = false
    private var lastGuidedRecommendationActivationNotice: OwnerTruthGuidedRecommendationPresentationNotice?
    private var reviewBatchAcknowledgementUseCase: OwnerTruthInterviewReviewBatchAcknowledgementUseCase?
    private var reviewBatchAcknowledgementThreadID: OwnerTruthRecordID?
    private var reviewBatchAcknowledgementSessionID: OwnerTruthRecordID?
    private var reviewBatchAcknowledgementState: OwnerTruthInterviewReviewBatchAcknowledgementViewState = .idle
    private var candidateProposalAdmissionUseCase: OwnerTruthInterviewCandidateProposalAdmissionUseCase?
    private var candidateProposalAdmissionReviewBatchID: OwnerTruthRecordID?
    private var candidateProposalAdmissionState: OwnerTruthInterviewCandidateProposalAdmissionViewState = .idle
    private var candidateProposalStatusUseCase: OwnerTruthInterviewCandidateProposalStatusUseCase?
    private var candidateProposalStatusReviewBatchID: OwnerTruthRecordID?
    private var candidateProposalStatusState: OwnerTruthInterviewCandidateProposalStatusViewState = .idle
    var onViewStateRendered: ((OwnerTruthInterviewNaturalInputViewState) -> Void)?

    var isTranscriptClearForQA: Bool {
        inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var renderedStatusTextForUIQA: String {
        statusLabel.text ?? ""
    }

    var renderedDetailTextForUIQA: String {
        detailLabel.text ?? ""
    }

    var renderedStateForUIQA: OwnerTruthInterviewNaturalInputViewState {
        renderedState
    }

    var reviewBatchAcknowledgementStateForUIQA: OwnerTruthInterviewReviewBatchAcknowledgementViewState {
        reviewBatchAcknowledgementState
    }

    var candidateProposalAdmissionStateForUIQA: OwnerTruthInterviewCandidateProposalAdmissionViewState {
        candidateProposalAdmissionState
    }

    var candidateProposalStatusStateForUIQA: OwnerTruthInterviewCandidateProposalStatusViewState {
        candidateProposalStatusState
    }

    var areBoundaryActionsVisibleForQA: Bool {
        presentation == .qa
            && boundaryActionsStack.superview != nil
            && !boundaryActionsStack.isHidden
    }

    var areProductBoundaryActionsVisibleForUIQA: Bool {
        presentation == .product
            && boundaryActionsStack.superview != nil
            && !boundaryActionsStack.isHidden
            && [skipOnceButton, cooldownButton, doNotAskButton].allSatisfy {
                $0.superview != nil && !$0.isHidden && $0.isEnabled
            }
    }

    var areQAOnlyBoundaryActionsHiddenForProductUIQA: Bool {
        presentation == .product
            && [
                topicSwitchButton,
                deepeningCompletedButton,
                summaryCompletedButton,
                restoreCooldownButton,
            ].allSatisfy { $0.superview == nil || $0.isHidden }
    }

    var isReviewBatchAcknowledgementEntryVisibleForUIQA: Bool {
        presentation == .product
            && reviewBatchAcknowledgementEntryButton.superview != nil
            && !reviewBatchAcknowledgementEntryButton.isHidden
            && reviewBatchAcknowledgementEntryButton.isEnabled
    }

    var isCandidateProposalAdmissionEntryVisibleForUIQA: Bool {
        presentation == .product
            && candidateProposalAdmissionEntryButton.superview != nil
            && !candidateProposalAdmissionEntryButton.isHidden
            && candidateProposalAdmissionEntryButton.isEnabled
    }

    var isCandidateProposalStatusEntryVisibleForUIQA: Bool {
        presentation == .product
            && candidateProposalStatusEntryButton.superview != nil
            && !candidateProposalStatusEntryButton.isHidden
            && candidateProposalStatusEntryButton.isEnabled
    }

    var candidateProposalStatusEntryTitleForUIQA: String {
        candidateProposalStatusEntryButton.configuration?.title
            ?? candidateProposalStatusEntryButton.currentTitle
            ?? ""
    }

    var isEndSessionActionVisibleForUIQA: Bool {
        presentation == .product
            && endSessionButton.superview != nil
            && !endSessionButton.isHidden
            && endSessionButton.isEnabled
    }

    var isDoNotAskRestoreActionVisibleForQA: Bool {
        presentation == .qa
            && restoreDoNotAskButton.superview != nil
            && !restoreDoNotAskButton.isHidden
    }

    var isCooldownRestoreActionVisibleForQA: Bool {
        presentation == .qa
            && restoreCooldownButton.superview != nil
            && !restoreCooldownButton.isHidden
    }

    var isTopicSwitchActionVisibleForQA: Bool {
        presentation == .qa
            && topicSwitchButton.superview != nil
            && !topicSwitchButton.isHidden
            && topicSwitchButton.isEnabled
    }

    var arePacingActionsVisibleForQA: Bool {
        presentation == .qa
            && deepeningCompletedButton.superview != nil
            && summaryCompletedButton.superview != nil
            && !deepeningCompletedButton.isHidden
            && !summaryCompletedButton.isHidden
            && deepeningCompletedButton.isEnabled
            && summaryCompletedButton.isEnabled
    }

    init(
        accountLease: AccountLease,
        client: OwnerTruthInterviewNaturalInputClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        presentation: OwnerTruthInterviewNaturalInputPresentation = .qa,
        guidedRecommendationClient: OwnerTruthGuidedRecommendationPresentationClient = DreamJourneyBackendClient.shared,
        guidedRecommendationPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.echoGuidedRecommendations) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .echoGuidedRecommendations)
                .allowed
        },
        lifeMapClient: OwnerTruthLifeMapPresentationClient = DreamJourneyBackendClient.shared,
        lifeMapPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.ownerTruthLifeMap) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .ownerTruthLifeMap)
                .allowed
        },
        memorySearchClient: OwnerTruthMemorySearchPresentationClient = DreamJourneyBackendClient.shared,
        memorySearchPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.ownerTruthMemorySearch) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .ownerTruthMemorySearch)
                .allowed
        },
        interviewOutcomeClient: OwnerTruthInterviewOutcomePresentationClient = DreamJourneyBackendClient.shared,
        interviewOutcomePolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.ownerTruthInterviewOutcome) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .ownerTruthInterviewOutcome)
                .allowed
        },
        reviewBatchInboxClient: OwnerTruthInterviewPendingReviewBatchInboxClient = DreamJourneyBackendClient.shared,
        reviewBatchAcknowledgementClient: OwnerTruthInterviewReviewBatchAcknowledgementClient = DreamJourneyBackendClient.shared,
        reviewBatchAcknowledgementPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.echoTextInput) else {
                return false
            }
            return FeatureGateService.shared.requestDecision(for: .echoTextInput).allowed
        },
        candidateProposalAdmissionClient: OwnerTruthInterviewCandidateProposalAdmissionClient = DreamJourneyBackendClient.shared,
        candidateProposalAdmissionPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .ownerTruthCandidateReview)
                .allowed
        },
        candidateProposalStatusClient: OwnerTruthInterviewCandidateProposalStatusClient = DreamJourneyBackendClient.shared,
        candidateProposalStatusPolicyAvailable: @escaping () -> Bool = {
            guard FeatureFlagService.shared.isEnabled(.ownerTruthCandidateReview) else {
                return false
            }
            return FeatureGateService.shared
                .requestDecision(for: .ownerTruthCandidateReview)
                .allowed
        },
        candidateProposalConfirmationInboxControllerProvider: @escaping (AccountLease, OwnerTruthRecordID) -> UIViewController = {
            accountLease,
            reviewBatchID in
            OwnerTruthInterviewCandidateConfirmationInboxViewController(
                accountLease: accountLease,
                focusedReviewBatchID: reviewBatchID
            )
        },
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.presentation = presentation
        self.accountLease = accountLease
        self.accountLeaseRuntime = accountLeaseRuntime
        self.lifeMapClient = lifeMapClient
        self.lifeMapPolicyAvailable = lifeMapPolicyAvailable
        self.memorySearchClient = memorySearchClient
        self.memorySearchPolicyAvailable = memorySearchPolicyAvailable
        self.interviewOutcomeClient = interviewOutcomeClient
        self.interviewOutcomePolicyAvailable = interviewOutcomePolicyAvailable
        self.reviewBatchInboxClient = reviewBatchInboxClient
        self.reviewBatchAcknowledgementClient = reviewBatchAcknowledgementClient
        self.reviewBatchAcknowledgementPolicyAvailable = reviewBatchAcknowledgementPolicyAvailable
        self.candidateProposalAdmissionClient = candidateProposalAdmissionClient
        self.candidateProposalAdmissionPolicyAvailable = candidateProposalAdmissionPolicyAvailable
        self.candidateProposalStatusClient = candidateProposalStatusClient
        self.candidateProposalStatusPolicyAvailable = candidateProposalStatusPolicyAvailable
        self.candidateProposalConfirmationInboxControllerProvider = candidateProposalConfirmationInboxControllerProvider
        self.useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
        self.guidedRecommendationUseCase = presentation == .product
            ? OwnerTruthGuidedRecommendationPresentationUseCase(
                accountLease: accountLease,
                client: guidedRecommendationClient,
                accountLeaseRuntime: accountLeaseRuntime,
                releasePolicyAvailable: guidedRecommendationPolicyAvailable
            )
            : nil
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = presentation.navigationTitle
        view.backgroundColor = DJDesignTokens.Color.background
        configureView()
        configureUseCase()
        render(useCase.viewState)
        useCase.send(.start)
        guidedRecommendationUseCase?.refresh()
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

    func submitQAFixture(_ text: String) {
        inputTextView.text = text
        submitInput()
    }

    func endQAFixture() {
        guard isEndSessionActionVisibleForUIQA else { return }
        endSessionTapped()
    }

    private func configureView() {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 24,
            trailing: DJDesignTokens.Spacing.page
        )

        subtitleLabel.text = presentation.subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        configureGuidedRecommendations()
        configureLifeMapEntry()
        configureMemorySearchEntry()
        configureInterviewOutcomeEntry()
        configureReviewBatchAcknowledgementEntry()
        configureCandidateProposalAdmissionEntry()
        configureCandidateProposalStatusEntry()

        statusLabel.font = DJDesignTokens.Font.title(20)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "owner-truth-interview-natural-input-status"

        detailLabel.font = DJDesignTokens.Font.body(15)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.accessibilityIdentifier = "owner-truth-interview-natural-input-detail"

        inputTextView.font = DJDesignTokens.Font.body(16)
        inputTextView.textColor = DJDesignTokens.Color.textPrimary
        inputTextView.backgroundColor = DJDesignTokens.Color.surface
        inputTextView.layer.cornerRadius = 12
        inputTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        inputTextView.accessibilityIdentifier = "owner-truth-interview-natural-input-text"
        inputTextView.heightAnchor.constraint(equalToConstant: 108).isActive = true

        submitButton.setTitle(presentation.submitTitle, for: .normal)
        submitButton.titleLabel?.font = DJDesignTokens.Font.body(16)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = DJDesignTokens.Color.accent
        submitButton.layer.cornerRadius = 10
        submitButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.accessibilityIdentifier = "owner-truth-interview-natural-input-submit"

        endSessionButton.setTitle("结束这次分享", for: .normal)
        endSessionButton.titleLabel?.font = DJDesignTokens.Font.body(14)
        endSessionButton.setTitleColor(DJDesignTokens.Color.textSecondary, for: .normal)
        endSessionButton.backgroundColor = .clear
        endSessionButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        endSessionButton.addTarget(self, action: #selector(endSessionTapped), for: .touchUpInside)
        endSessionButton.accessibilityIdentifier = "owner-truth-interview-natural-input-end"
        endSessionButton.isHidden = true

        configureBoundaryControls()
        stackView.addArrangedSubview(subtitleLabel)
        if presentation == .product {
            stackView.addArrangedSubview(guidedRecommendationStack)
            stackView.addArrangedSubview(lifeMapButton)
            stackView.addArrangedSubview(memorySearchButton)
            stackView.addArrangedSubview(interviewOutcomeButton)
            stackView.addArrangedSubview(reviewBatchAcknowledgementEntryButton)
            stackView.addArrangedSubview(candidateProposalAdmissionEntryButton)
            stackView.addArrangedSubview(candidateProposalStatusEntryButton)
        }
        [statusLabel, detailLabel, inputTextView, submitButton].forEach(stackView.addArrangedSubview)
        if presentation == .product {
            stackView.addArrangedSubview(endSessionButton)
        }
        if presentation == .qa || presentation == .product {
            stackView.addArrangedSubview(boundaryActionsStack)
        }
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureUseCase() {
        useCase.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                render(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.render(state)
                }
            }
        }
        guidedRecommendationUseCase?.onViewStateChange = { [weak self] state in
            guard let self else { return }
            if Thread.isMainThread {
                renderGuidedRecommendations(state)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.renderGuidedRecommendations(state)
                }
            }
        }
        if let guidedRecommendationUseCase {
            renderGuidedRecommendations(guidedRecommendationUseCase.viewState)
        }
    }

    private func configureGuidedRecommendations() {
        guidedRecommendationStack.axis = .vertical
        guidedRecommendationStack.alignment = .fill
        guidedRecommendationStack.spacing = 8
        guidedRecommendationStack.isHidden = true
        guidedRecommendationStack.accessibilityIdentifier = "owner-truth-guided-recommendations"

        guidedRecommendationTitleLabel.text = "可以从这里开始"
        guidedRecommendationTitleLabel.font = DJDesignTokens.Font.label(13)
        guidedRecommendationTitleLabel.textColor = DJDesignTokens.Color.textTertiary

        guidedRecommendationPromptStack.axis = .vertical
        guidedRecommendationPromptStack.alignment = .fill
        guidedRecommendationPromptStack.spacing = 8

        guidedRecommendationActivePromptLabel.font = DJDesignTokens.Font.body(16)
        guidedRecommendationActivePromptLabel.textColor = DJDesignTokens.Color.textPrimary
        guidedRecommendationActivePromptLabel.numberOfLines = 0
        guidedRecommendationActivePromptLabel.accessibilityIdentifier =
            "owner-truth-guided-recommendation-active-prompt"
        guidedRecommendationActivePromptLabel.isHidden = true

        guidedRecommendationStack.addArrangedSubview(guidedRecommendationTitleLabel)
        guidedRecommendationStack.addArrangedSubview(guidedRecommendationPromptStack)
        guidedRecommendationStack.addArrangedSubview(guidedRecommendationActivePromptLabel)
    }

    private func configureLifeMapEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "人生地图"
        configuration.image = UIImage(systemName: "map")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        lifeMapButton.configuration = configuration
        lifeMapButton.contentHorizontalAlignment = .leading
        lifeMapButton.layer.cornerRadius = 10
        lifeMapButton.accessibilityIdentifier = "owner-truth-life-map-entry"
        lifeMapButton.accessibilityLabel = "查看人生地图"
        lifeMapButton.addTarget(self, action: #selector(lifeMapTapped), for: .touchUpInside)
        lifeMapButton.isHidden = presentation != .product || !lifeMapPolicyAvailable()
    }

    private func configureMemorySearchEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "回顾检索"
        configuration.image = UIImage(systemName: "magnifyingglass")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        memorySearchButton.configuration = configuration
        memorySearchButton.contentHorizontalAlignment = .leading
        memorySearchButton.layer.cornerRadius = 10
        memorySearchButton.accessibilityIdentifier = "owner-truth-memory-search-entry"
        memorySearchButton.accessibilityLabel = "回顾已确认的记忆"
        memorySearchButton.addTarget(self, action: #selector(memorySearchTapped), for: .touchUpInside)
        memorySearchButton.isHidden = presentation != .product || !memorySearchPolicyAvailable()
    }

    private func configureInterviewOutcomeEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "本次回顾"
        configuration.image = UIImage(systemName: "text.badge.checkmark")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        interviewOutcomeButton.configuration = configuration
        interviewOutcomeButton.contentHorizontalAlignment = .leading
        interviewOutcomeButton.layer.cornerRadius = 10
        interviewOutcomeButton.accessibilityIdentifier = "owner-truth-interview-outcome-entry"
        interviewOutcomeButton.accessibilityLabel = "查看本次回顾"
        interviewOutcomeButton.addTarget(
            self,
            action: #selector(interviewOutcomeTapped),
            for: .touchUpInside
        )
        interviewOutcomeButton.isHidden = presentation != .product || !interviewOutcomePolicyAvailable()
        interviewOutcomeButton.isEnabled = false
        interviewOutcomeButton.alpha = 0.45
    }

    private func configureReviewBatchAcknowledgementEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "确认进入整理"
        configuration.image = UIImage(systemName: "tray.and.arrow.down")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        reviewBatchAcknowledgementEntryButton.configuration = configuration
        reviewBatchAcknowledgementEntryButton.contentHorizontalAlignment = .leading
        reviewBatchAcknowledgementEntryButton.layer.cornerRadius = 10
        reviewBatchAcknowledgementEntryButton.accessibilityIdentifier =
            "owner-truth-interview-review-batch-acknowledgement-entry"
        reviewBatchAcknowledgementEntryButton.accessibilityLabel = "确认进入整理"
        reviewBatchAcknowledgementEntryButton.isHidden = true
        reviewBatchAcknowledgementEntryButton.addTarget(
            self,
            action: #selector(reviewBatchAcknowledgementEntryTapped),
            for: .touchUpInside
        )
    }

    private func configureCandidateProposalAdmissionEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "开始整理"
        configuration.image = UIImage(systemName: "sparkles")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        candidateProposalAdmissionEntryButton.configuration = configuration
        candidateProposalAdmissionEntryButton.contentHorizontalAlignment = .leading
        candidateProposalAdmissionEntryButton.layer.cornerRadius = 10
        candidateProposalAdmissionEntryButton.accessibilityIdentifier =
            "owner-truth-interview-candidate-proposal-admission-entry"
        candidateProposalAdmissionEntryButton.accessibilityLabel = "开始整理"
        candidateProposalAdmissionEntryButton.isHidden = true
        candidateProposalAdmissionEntryButton.addTarget(
            self,
            action: #selector(candidateProposalAdmissionEntryTapped),
            for: .touchUpInside
        )
    }

    private func configureCandidateProposalStatusEntry() {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "查看整理进度"
        configuration.image = UIImage(systemName: "clock.arrow.circlepath")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 14,
            bottom: 12,
            trailing: 14
        )
        candidateProposalStatusEntryButton.configuration = configuration
        candidateProposalStatusEntryButton.contentHorizontalAlignment = .leading
        candidateProposalStatusEntryButton.layer.cornerRadius = 10
        candidateProposalStatusEntryButton.accessibilityIdentifier =
            "owner-truth-interview-candidate-proposal-status-entry"
        candidateProposalStatusEntryButton.accessibilityLabel = "查看整理进度"
        candidateProposalStatusEntryButton.isHidden = true
        candidateProposalStatusEntryButton.addTarget(
            self,
            action: #selector(candidateProposalStatusEntryTapped),
            for: .touchUpInside
        )
    }

    private func renderGuidedRecommendations(
        _ state: OwnerTruthGuidedRecommendationPresentationViewState
    ) {
        renderGuidedRecommendationFeedbackNoticeIfNeeded(state)
        renderGuidedRecommendationActivationNoticeIfNeeded(state)
        guard presentation == .product else {
            guidedRecommendationPrompts = []
            clearGuidedRecommendationPromptButtons()
            guidedRecommendationActivePromptLabel.isHidden = true
            guidedRecommendationStack.isHidden = true
            return
        }
        if let activePrompt = state.activePrompt {
            guidedRecommendationPrompts = []
            clearGuidedRecommendationPromptButtons()
            guidedRecommendationTitleLabel.text = "想听你说说"
            guidedRecommendationActivePromptLabel.text = activePrompt.question
            guidedRecommendationActivePromptLabel.isHidden = false
            guidedRecommendationStack.isHidden = false
            return
        }
        guard presentation == .product,
              state.phase == .ready,
              !state.prompts.isEmpty else {
            guidedRecommendationPrompts = []
            clearGuidedRecommendationPromptButtons()
            guidedRecommendationActivePromptLabel.isHidden = true
            guidedRecommendationStack.isHidden = true
            return
        }

        guidedRecommendationPrompts = state.prompts
        clearGuidedRecommendationPromptButtons()
        guidedRecommendationTitleLabel.text = "可以从这里开始"
        guidedRecommendationActivePromptLabel.isHidden = true
        for (index, prompt) in state.prompts.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 8

            let button = UIButton(type: .system)
            button.tag = index
            button.contentHorizontalAlignment = .leading
            button.contentVerticalAlignment = .center
            button.titleLabel?.font = DJDesignTokens.Font.body(15)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.textAlignment = .left
            button.setTitle("\(prompt.label)\n\(prompt.question)", for: .normal)
            button.setTitleColor(DJDesignTokens.Color.textPrimary, for: .normal)
            button.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            button.addTarget(
                self,
                action: #selector(guidedRecommendationTapped(_:)),
                for: .touchUpInside
            )
            button.accessibilityIdentifier = "owner-truth-guided-recommendation-\(prompt.slot.rawValue)"
            row.addArrangedSubview(button)

            let actionsButton = UIButton(type: .system)
            actionsButton.tag = index
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: "ellipsis")
            configuration.baseForegroundColor = DJDesignTokens.Color.textSecondary
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            actionsButton.configuration = configuration
            actionsButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
            actionsButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
            actionsButton.accessibilityLabel = "调整引导问题"
            actionsButton.accessibilityIdentifier = "owner-truth-guided-recommendation-actions-\(prompt.slot.rawValue)"
            actionsButton.addTarget(
                self,
                action: #selector(guidedRecommendationActionsTapped(_:)),
                for: .touchUpInside
            )
            row.addArrangedSubview(actionsButton)
            guidedRecommendationPromptStack.addArrangedSubview(row)
        }
        guidedRecommendationStack.isHidden = false
    }

    private func renderGuidedRecommendationFeedbackNoticeIfNeeded(
        _ state: OwnerTruthGuidedRecommendationPresentationViewState
    ) {
        guard isSubmittingGuidedRecommendationFeedback else { return }

        guard let notice = state.notice else {
            if state.phase == .ready {
                isSubmittingGuidedRecommendationFeedback = false
                lastGuidedRecommendationFeedbackNotice = nil
            }
            return
        }
        guard notice == .feedbackRequestFailed || notice == .contractMismatch,
              notice != lastGuidedRecommendationFeedbackNotice else {
            return
        }

        isSubmittingGuidedRecommendationFeedback = false
        lastGuidedRecommendationFeedbackNotice = notice
        let message: String
        switch notice {
        case .contractMismatch:
            message = "这些引导问题已经更新，请重新选择。"
        case .feedbackRequestFailed:
            message = "暂时无法更新问题，请稍后重试。"
        default:
            return
        }
        let alert = UIAlertController(
            title: "暂时无法调整问题",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func renderGuidedRecommendationActivationNoticeIfNeeded(
        _ state: OwnerTruthGuidedRecommendationPresentationViewState
    ) {
        guard isActivatingGuidedRecommendation else { return }

        guard let notice = state.notice else {
            if state.phase == .ready, state.activePrompt != nil {
                isActivatingGuidedRecommendation = false
                lastGuidedRecommendationActivationNotice = nil
            }
            return
        }
        guard notice == .activationRequestFailed || notice == .contractMismatch,
              notice != lastGuidedRecommendationActivationNotice else {
            return
        }

        isActivatingGuidedRecommendation = false
        lastGuidedRecommendationActivationNotice = notice
        let message: String
        switch notice {
        case .contractMismatch:
            message = "这个引导已经更新，请重新选择。"
        case .activationRequestFailed:
            message = "暂时无法开始这个引导，请稍后重试。"
        default:
            return
        }
        let alert = UIAlertController(
            title: "暂时无法开始",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func clearGuidedRecommendationPromptButtons() {
        guidedRecommendationPromptStack.arrangedSubviews.forEach { view in
            guidedRecommendationPromptStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func render(_ state: OwnerTruthInterviewNaturalInputViewState) {
        renderedState = state
        let canContinue = state.continuation?.canContinue ?? true
        let canSubmit = state.phase == .ready && canContinue
        let canSetBoundary = (presentation == .qa || presentation == .product)
            && state.phase == .ready
            && state.latestReceipt?.boundary == .open
            && canContinue
        let canRestoreDoNotAsk = (presentation == .qa || presentation == .product)
            && state.phase == .ready
            && state.latestReceipt?.boundary == .doNotAsk
        let canRestoreCooldown = presentation == .qa
            && state.phase == .ready
            && state.latestReceipt?.boundary == .cooldown
        let canSwitchTopic = presentation == .qa
            && state.phase == .ready
            && state.latestReceipt?.lifecycle == .active
            && canContinue
        let canRecordPacing = presentation == .qa
            && state.phase == .ready
            && state.latestReceipt?.lifecycle == .active
            && state.latestReceipt?.boundary == .open
            && canContinue
        let canEnd = presentation == .product
            && state.phase == .ready
            && state.latestReceipt?.lifecycle == .active
            && state.latestReceipt?.boundary == .open
            && state.latestReceipt?.messageSequence != nil
            && canContinue
        inputTextView.isEditable = canSubmit
        submitButton.isEnabled = canSubmit
        submitButton.alpha = canSubmit ? 1 : 0.45
        endSessionButton.isHidden = !canEnd
        endSessionButton.isEnabled = canEnd
        endSessionButton.alpha = canEnd ? 1 : 0
        [skipOnceButton, cooldownButton, doNotAskButton].forEach { button in
            button.isEnabled = canSetBoundary
            button.alpha = canSetBoundary ? 1 : 0.45
        }
        topicSwitchButton.isEnabled = canSwitchTopic
        topicSwitchButton.alpha = canSwitchTopic ? 1 : 0.45
        [deepeningCompletedButton, summaryCompletedButton].forEach { button in
            button.isEnabled = canRecordPacing
            button.alpha = canRecordPacing ? 1 : 0.45
        }
        restoreDoNotAskButton.isHidden = !canRestoreDoNotAsk
        restoreDoNotAskButton.isEnabled = canRestoreDoNotAsk
        restoreDoNotAskButton.alpha = canRestoreDoNotAsk ? 1 : 0.45
        restoreCooldownButton.isHidden = !canRestoreCooldown
        restoreCooldownButton.isEnabled = canRestoreCooldown
        restoreCooldownButton.alpha = canRestoreCooldown ? 1 : 0.45
        let canReadInterviewOutcome = presentation == .product
            && interviewOutcomePolicyAvailable()
            && state.latestReceipt != nil
        interviewOutcomeButton.isHidden = presentation != .product || !interviewOutcomePolicyAvailable()
        interviewOutcomeButton.isEnabled = canReadInterviewOutcome
        interviewOutcomeButton.alpha = canReadInterviewOutcome ? 1 : 0.45
        resetReviewBatchAcknowledgementIfNeeded(for: state)
        updateReviewBatchAcknowledgementEntry(for: state)
        resetCandidateProposalAdmissionIfNeeded()
        updateCandidateProposalAdmissionEntry(for: state)
        resetCandidateProposalStatusIfNeeded()
        updateCandidateProposalStatusEntry(for: state)
        statusLabel.text = statusText(for: state)
        detailLabel.text = detailText(for: state)
        onViewStateRendered?(state)
    }

    @objc private func submitTapped() {
        submitInput()
    }

    @objc private func endSessionTapped() {
        guard presentation == .product,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.lifecycle == .active,
              renderedState.latestReceipt?.boundary == .open,
              renderedState.latestReceipt?.messageSequence != nil,
              renderedState.continuation?.canContinue ?? true else {
            return
        }
        useCase.send(.end)
    }

    @objc private func guidedRecommendationTapped(_ sender: UIButton) {
        guard guidedRecommendationPrompts.indices.contains(sender.tag) else { return }
        let prompt = guidedRecommendationPrompts[sender.tag]
        isActivatingGuidedRecommendation = true
        lastGuidedRecommendationActivationNotice = nil
        guidedRecommendationUseCase?.activate(slot: prompt.slot)
    }

    @objc private func guidedRecommendationActionsTapped(_ sender: UIButton) {
        guard guidedRecommendationPrompts.indices.contains(sender.tag) else { return }
        let prompt = guidedRecommendationPrompts[sender.tag]
        let alert = UIAlertController(
            title: "调整引导",
            message: "可换一个问题、调整方向，或稍后再聊。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "换一个问题", style: .default) { [weak self] _ in
            self?.submitGuidedRecommendationFeedback(
                slot: prompt.slot,
                action: .replace,
                reason: .questionWording
            )
        })
        alert.addAction(UIAlertAction(title: "不想聊这个方向", style: .default) { [weak self] _ in
            self?.submitGuidedRecommendationFeedback(
                slot: prompt.slot,
                action: .notInterested,
                reason: .topicPreference
            )
        })
        alert.addAction(UIAlertAction(title: "以后再聊", style: .default) { [weak self] _ in
            self?.submitGuidedRecommendationFeedback(
                slot: prompt.slot,
                action: .defer,
                reason: .timing
            )
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(alert, animated: true)
    }

    private func submitGuidedRecommendationFeedback(
        slot: OwnerTruthKnowledgeRecommendationSlot,
        action: OwnerTruthGuidedRecommendationFeedbackAction,
        reason: OwnerTruthGuidedRecommendationFeedbackReason
    ) {
        guard let guidedRecommendationUseCase else { return }
        isSubmittingGuidedRecommendationFeedback = true
        lastGuidedRecommendationFeedbackNotice = nil
        guidedRecommendationUseCase.submitFeedback(
            slot: slot,
            action: action,
            reason: reason
        )
    }

    private func submitInput() {
        let text = inputTextView.text ?? ""
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isBoundedInput = !normalizedText.isEmpty
            && normalizedText.count <= OwnerTruthInterviewNaturalInputAppendCommand.maximumCharacterCount

        // Clear an accepted private input before issuing the command so a
        // synchronous fake client cannot race the UI back to `.ready` first.
        if isBoundedInput {
            inputTextView.text = ""
        }
        useCase.send(.submit(text: text))
    }

    @objc private func lifeMapTapped() {
        guard presentation == .product, lifeMapPolicyAvailable() else {
            lifeMapButton.isHidden = true
            return
        }
        let controller = OwnerTruthLifeMapViewController(
            accountLease: accountLease,
            client: lifeMapClient,
            releasePolicyAvailable: lifeMapPolicyAvailable
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func memorySearchTapped() {
        guard presentation == .product, memorySearchPolicyAvailable() else {
            memorySearchButton.isHidden = true
            return
        }
        let controller = OwnerTruthMemorySearchViewController(
            accountLease: accountLease,
            client: memorySearchClient,
            releasePolicyAvailable: memorySearchPolicyAvailable
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func interviewOutcomeTapped() {
        guard presentation == .product,
              interviewOutcomePolicyAvailable(),
              let sessionID = renderedState.latestReceipt?.sessionID else {
            interviewOutcomeButton.isHidden = true
            return
        }
        let controller = OwnerTruthInterviewOutcomeViewController(
            accountLease: accountLease,
            sessionID: sessionID,
            client: interviewOutcomeClient,
            releasePolicyAvailable: interviewOutcomePolicyAvailable
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    private func resetReviewBatchAcknowledgementIfNeeded(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) {
        guard state.continuation?.state == .reviewPending,
              let receipt = state.latestReceipt else {
            reviewBatchAcknowledgementUseCase = nil
            reviewBatchAcknowledgementThreadID = nil
            reviewBatchAcknowledgementSessionID = nil
            reviewBatchAcknowledgementState = .idle
            return
        }

        guard let acknowledgedThreadID = reviewBatchAcknowledgementThreadID,
              let acknowledgedSessionID = reviewBatchAcknowledgementSessionID,
              acknowledgedThreadID != receipt.threadID
                || acknowledgedSessionID != receipt.sessionID else {
            return
        }
        reviewBatchAcknowledgementUseCase = nil
        reviewBatchAcknowledgementThreadID = nil
        reviewBatchAcknowledgementSessionID = nil
        reviewBatchAcknowledgementState = .idle
    }

    private func resetCandidateProposalAdmissionIfNeeded() {
        guard reviewBatchAcknowledgementState.phase == .acknowledged,
              let acknowledgementReceipt = reviewBatchAcknowledgementState.receipt else {
            candidateProposalAdmissionUseCase = nil
            candidateProposalAdmissionReviewBatchID = nil
            candidateProposalAdmissionState = .idle
            resetCandidateProposalStatus()
            return
        }

        guard let admittedReviewBatchID = candidateProposalAdmissionReviewBatchID,
              admittedReviewBatchID != acknowledgementReceipt.reviewBatchID else {
            return
        }
        candidateProposalAdmissionUseCase = nil
        candidateProposalAdmissionReviewBatchID = nil
        candidateProposalAdmissionState = .idle
        resetCandidateProposalStatus()
    }

    private func resetCandidateProposalStatusIfNeeded() {
        guard candidateProposalAdmissionState.phase == .admitted,
              let reviewBatchID = candidateProposalAdmissionState.receipt?.reviewBatchID else {
            resetCandidateProposalStatus()
            return
        }
        guard let observedReviewBatchID = candidateProposalStatusReviewBatchID,
              observedReviewBatchID != reviewBatchID else {
            return
        }
        resetCandidateProposalStatus()
    }

    private func resetCandidateProposalStatus() {
        candidateProposalStatusUseCase = nil
        candidateProposalStatusReviewBatchID = nil
        candidateProposalStatusState = .idle
    }

    private func updateReviewBatchAcknowledgementEntry(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) {
        let canOffer = canOfferReviewBatchAcknowledgement(for: state)
        let isInFlight = reviewBatchAcknowledgementState.phase == .discovering
            || reviewBatchAcknowledgementState.phase == .acknowledging
        let isAcknowledged = reviewBatchAcknowledgementState.phase == .acknowledged
        let isVisible = canOffer && !isAcknowledged
        reviewBatchAcknowledgementEntryButton.isHidden = !isVisible
        reviewBatchAcknowledgementEntryButton.isEnabled = isVisible && !isInFlight
        reviewBatchAcknowledgementEntryButton.alpha = isVisible ? (isInFlight ? 0.45 : 1) : 0
        var configuration = reviewBatchAcknowledgementEntryButton.configuration
        configuration?.title = reviewBatchAcknowledgementState.phase == .failed
            ? "重新确认整理"
            : "确认进入整理"
        reviewBatchAcknowledgementEntryButton.configuration = configuration
    }

    private func canOfferReviewBatchAcknowledgement(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) -> Bool {
        presentation == .product
            && state.phase == .ready
            && state.continuation?.state == .reviewPending
            && state.latestReceipt?.lifecycle == .ended
            && reviewBatchAcknowledgementPolicyAvailable()
            && accountLeaseRuntime.validate(accountLease, at: .ui).allowed
    }

    private func updateCandidateProposalAdmissionEntry(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) {
        let canOffer = canOfferCandidateProposalAdmission(for: state)
        let isInFlight = candidateProposalAdmissionState.phase == .admitting
        let isAdmitted = candidateProposalAdmissionState.phase == .admitted
        let isVisible = canOffer && !isAdmitted
        candidateProposalAdmissionEntryButton.isHidden = !isVisible
        candidateProposalAdmissionEntryButton.isEnabled = isVisible && !isInFlight
        candidateProposalAdmissionEntryButton.alpha = isVisible ? (isInFlight ? 0.45 : 1) : 0
        var configuration = candidateProposalAdmissionEntryButton.configuration
        configuration?.title = candidateProposalAdmissionState.phase == .failed
            ? "重新开始整理"
            : "开始整理"
        candidateProposalAdmissionEntryButton.configuration = configuration
    }

    private func canOfferCandidateProposalAdmission(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) -> Bool {
        presentation == .product
            && state.phase == .ready
            && state.continuation?.state == .reviewPending
            && state.latestReceipt?.lifecycle == .ended
            && reviewBatchAcknowledgementState.phase == .acknowledged
            && reviewBatchAcknowledgementState.receipt != nil
            && candidateProposalAdmissionPolicyAvailable()
            && accountLeaseRuntime.validate(accountLease, at: .ui).allowed
    }

    private func canOfferCandidateProposalStatus(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) -> Bool {
        presentation == .product
            && state.phase == .ready
            && state.continuation?.state == .reviewPending
            && state.latestReceipt?.lifecycle == .ended
            && candidateProposalAdmissionState.phase == .admitted
            && candidateProposalAdmissionState.receipt != nil
            && candidateProposalStatusPolicyAvailable()
            && accountLeaseRuntime.validate(accountLease, at: .ui).allowed
            && !isCandidateProposalStatusContentUnavailable
    }

    private var isCandidateProposalStatusContentUnavailable: Bool {
        candidateProposalStatusState.phase == .unavailable
            && candidateProposalStatusState.notice == .contentUnavailable
    }

    private func updateCandidateProposalStatusEntry(
        for state: OwnerTruthInterviewNaturalInputViewState
    ) {
        let canOffer = canOfferCandidateProposalStatus(for: state)
        let isLoading = candidateProposalStatusState.phase == .loading
        let isReviewReady = candidateProposalStatusState.status?.candidateReviewState == .reviewReady
            && candidateProposalStatusState.status?.isBound(to: accountLease) == true
        candidateProposalStatusEntryButton.isHidden = !canOffer
        candidateProposalStatusEntryButton.isEnabled = canOffer && !isLoading
        candidateProposalStatusEntryButton.alpha = canOffer ? (isLoading ? 0.45 : 1) : 0
        var configuration = candidateProposalStatusEntryButton.configuration
        if isReviewReady {
            configuration?.title = "查看待确认内容"
            candidateProposalStatusEntryButton.accessibilityLabel = "查看待确认内容"
        } else if candidateProposalStatusState.phase == .failed
                    || (candidateProposalStatusState.phase == .unavailable
                        && candidateProposalStatusState.notice == .contextChanged) {
            configuration?.title = "重新查看整理状态"
            candidateProposalStatusEntryButton.accessibilityLabel = "重新查看整理状态"
        } else {
            configuration?.title = "查看整理进度"
            candidateProposalStatusEntryButton.accessibilityLabel = "查看整理进度"
        }
        candidateProposalStatusEntryButton.configuration = configuration
    }

    @objc private func reviewBatchAcknowledgementEntryTapped() {
        guard canOfferReviewBatchAcknowledgement(for: renderedState),
              reviewBatchAcknowledgementState.phase != .discovering,
              reviewBatchAcknowledgementState.phase != .acknowledging,
              reviewBatchAcknowledgementState.phase != .acknowledged else {
            return
        }
        let alert = UIAlertController(
            title: "确认本次分享",
            message: "确认后，本次分享会保留为待整理边界。之后可再选择是否开始整理。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "暂不整理", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认进入整理", style: .default) { [weak self] _ in
            self?.acknowledgeCurrentReviewBatch()
        })
        present(alert, animated: true)
    }

    @objc private func candidateProposalAdmissionEntryTapped() {
        guard canOfferCandidateProposalAdmission(for: renderedState),
              candidateProposalAdmissionState.phase != .admitting,
              candidateProposalAdmissionState.phase != .admitted else {
            return
        }
        let alert = UIAlertController(
            title: "开始整理本次分享",
            message: "系统会依据这次已确认的分享生成待你确认的记忆建议，不会直接保存为正式记忆。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "暂不整理", style: .cancel))
        alert.addAction(UIAlertAction(title: "开始整理", style: .default) { [weak self] _ in
            self?.startCandidateProposalAdmission()
        })
        present(alert, animated: true)
    }

    @objc private func candidateProposalStatusEntryTapped() {
        guard canOfferCandidateProposalStatus(for: renderedState),
              let reviewBatchID = candidateProposalAdmissionState.receipt?.reviewBatchID else {
            return
        }
        if candidateProposalStatusState.phase == .ready,
           candidateProposalStatusState.status?.candidateReviewState == .reviewReady,
           candidateProposalStatusState.status?.reviewBatchID == reviewBatchID,
           candidateProposalStatusState.status?.isBound(to: accountLease) == true {
            navigationController?.pushViewController(
                candidateProposalConfirmationInboxControllerProvider(accountLease, reviewBatchID),
                animated: true
            )
            return
        }
        refreshCandidateProposalStatus()
    }

    private func acknowledgeCurrentReviewBatch() {
        guard canOfferReviewBatchAcknowledgement(for: renderedState),
              let receipt = renderedState.latestReceipt else {
            return
        }

        let useCase: OwnerTruthInterviewReviewBatchAcknowledgementUseCase
        if let existingUseCase = reviewBatchAcknowledgementUseCase,
           reviewBatchAcknowledgementThreadID == receipt.threadID,
           reviewBatchAcknowledgementSessionID == receipt.sessionID {
            useCase = existingUseCase
        } else {
            let createdUseCase = OwnerTruthInterviewReviewBatchAcknowledgementUseCase(
                accountLease: accountLease,
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                inboxClient: reviewBatchInboxClient,
                acknowledgementClient: reviewBatchAcknowledgementClient,
                accountLeaseRuntime: accountLeaseRuntime,
                releasePolicyAvailable: reviewBatchAcknowledgementPolicyAvailable
            )
            createdUseCase.onViewStateChange = { [weak self] acknowledgementState in
                if Thread.isMainThread {
                    self?.renderReviewBatchAcknowledgement(acknowledgementState)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.renderReviewBatchAcknowledgement(acknowledgementState)
                    }
                }
            }
            reviewBatchAcknowledgementUseCase = createdUseCase
            reviewBatchAcknowledgementThreadID = receipt.threadID
            reviewBatchAcknowledgementSessionID = receipt.sessionID
            useCase = createdUseCase
        }
        useCase.send(.acknowledge)
    }

    private func startCandidateProposalAdmission() {
        guard canOfferCandidateProposalAdmission(for: renderedState),
              let acknowledgementReceipt = reviewBatchAcknowledgementState.receipt else {
            return
        }

        let useCase: OwnerTruthInterviewCandidateProposalAdmissionUseCase
        if let existingUseCase = candidateProposalAdmissionUseCase,
           candidateProposalAdmissionReviewBatchID == acknowledgementReceipt.reviewBatchID {
            useCase = existingUseCase
        } else {
            let createdUseCase = OwnerTruthInterviewCandidateProposalAdmissionUseCase(
                accountLease: accountLease,
                acknowledgementReceipt: acknowledgementReceipt,
                client: candidateProposalAdmissionClient,
                accountLeaseRuntime: accountLeaseRuntime,
                releasePolicyAvailable: candidateProposalAdmissionPolicyAvailable
            )
            createdUseCase.onViewStateChange = { [weak self] admissionState in
                if Thread.isMainThread {
                    self?.renderCandidateProposalAdmission(admissionState)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.renderCandidateProposalAdmission(admissionState)
                    }
                }
            }
            candidateProposalAdmissionUseCase = createdUseCase
            candidateProposalAdmissionReviewBatchID = acknowledgementReceipt.reviewBatchID
            useCase = createdUseCase
        }
        useCase.send(.admit)
    }

    private func refreshCandidateProposalStatus() {
        guard canOfferCandidateProposalStatus(for: renderedState),
              let reviewBatchID = candidateProposalAdmissionState.receipt?.reviewBatchID else {
            return
        }

        let useCase: OwnerTruthInterviewCandidateProposalStatusUseCase
        if let existingUseCase = candidateProposalStatusUseCase,
           candidateProposalStatusReviewBatchID == reviewBatchID {
            useCase = existingUseCase
        } else {
            let createdUseCase = OwnerTruthInterviewCandidateProposalStatusUseCase(
                accountLease: accountLease,
                reviewBatchID: reviewBatchID,
                client: candidateProposalStatusClient,
                accountLeaseRuntime: accountLeaseRuntime,
                releasePolicyAvailable: candidateProposalStatusPolicyAvailable
            )
            createdUseCase.onViewStateChange = { [weak self] statusState in
                if Thread.isMainThread {
                    self?.renderCandidateProposalStatus(statusState)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.renderCandidateProposalStatus(statusState)
                    }
                }
            }
            candidateProposalStatusUseCase = createdUseCase
            candidateProposalStatusReviewBatchID = reviewBatchID
            useCase = createdUseCase
        }
        useCase.send(.refresh)
    }

    private func renderReviewBatchAcknowledgement(
        _ state: OwnerTruthInterviewReviewBatchAcknowledgementViewState
    ) {
        reviewBatchAcknowledgementState = state
        render(renderedState)
    }

    private func renderCandidateProposalAdmission(
        _ state: OwnerTruthInterviewCandidateProposalAdmissionViewState
    ) {
        candidateProposalAdmissionState = state
        if state.phase == .admitted {
            refreshCandidateProposalStatus()
        }
        render(renderedState)
    }

    private func renderCandidateProposalStatus(
        _ state: OwnerTruthInterviewCandidateProposalStatusViewState
    ) {
        candidateProposalStatusState = state
        render(renderedState)
    }

    private func configureBoundaryControls() {
        boundaryActionsStack.axis = .vertical
        boundaryActionsStack.alignment = .fill
        boundaryActionsStack.spacing = 8
        boundaryActionsStack.distribution = .fill

        configureBoundaryButton(
            skipOnceButton,
            title: presentation == .product ? "这次先跳过" : "本轮跳过",
            accessibilityIdentifier: "owner-truth-interview-boundary-skip-once",
            action: #selector(skipOnceTapped)
        )
        configureBoundaryButton(
            cooldownButton,
            title: "以后再聊",
            accessibilityIdentifier: "owner-truth-interview-boundary-cooldown",
            action: #selector(cooldownTapped)
        )
        configureBoundaryButton(
            doNotAskButton,
            title: "不再问",
            accessibilityIdentifier: "owner-truth-interview-boundary-do-not-ask",
            action: #selector(doNotAskTapped)
        )

        switch presentation {
        case .product:
            productBoundaryActionsRow.axis = .horizontal
            productBoundaryActionsRow.alignment = .fill
            productBoundaryActionsRow.spacing = 8
            productBoundaryActionsRow.distribution = .fillEqually
            [skipOnceButton, cooldownButton, doNotAskButton].forEach(
                productBoundaryActionsRow.addArrangedSubview
            )
            boundaryActionsStack.addArrangedSubview(productBoundaryActionsRow)
            configureBoundaryButton(
                restoreDoNotAskButton,
                title: "重新开启这个话题",
                accessibilityIdentifier: "owner-truth-interview-boundary-restore-do-not-ask",
                action: #selector(restoreDoNotAskTapped)
            )
            boundaryActionsStack.addArrangedSubview(restoreDoNotAskButton)
        case .qa:
            #if DEBUG || UI_QA_SIMULATOR
        [skipOnceButton, cooldownButton, doNotAskButton].forEach(
            boundaryActionsStack.addArrangedSubview
        )
        configureBoundaryButton(
            topicSwitchButton,
            title: "切换话题（暂停当前）",
            accessibilityIdentifier: "owner-truth-interview-topic-switch",
            action: #selector(topicSwitchTapped)
        )
        configureBoundaryButton(
            deepeningCompletedButton,
            title: "记录一次追问完成",
            accessibilityIdentifier: "owner-truth-interview-pacing-deepening-completed",
            action: #selector(deepeningCompletedTapped)
        )
        configureBoundaryButton(
            summaryCompletedButton,
            title: "记录本轮总结完成",
            accessibilityIdentifier: "owner-truth-interview-pacing-summary-completed",
            action: #selector(summaryCompletedTapped)
        )
        configureBoundaryButton(
            restoreDoNotAskButton,
            title: "重新聊这个话题",
            accessibilityIdentifier: "owner-truth-interview-boundary-restore-do-not-ask",
            action: #selector(restoreDoNotAskTapped)
        )
        configureBoundaryButton(
            restoreCooldownButton,
            title: "继续待续话题",
            accessibilityIdentifier: "owner-truth-interview-boundary-restore-cooldown",
            action: #selector(restoreCooldownTapped)
        )
        [
            topicSwitchButton,
            deepeningCompletedButton,
            summaryCompletedButton,
            restoreDoNotAskButton,
            restoreCooldownButton,
        ].forEach(boundaryActionsStack.addArrangedSubview)
            #else
            boundaryActionsStack.isHidden = true
            #endif
        }
    }

    private func configureBoundaryButton(
        _ button: UIButton,
        title: String,
        accessibilityIdentifier: String,
        action: Selector
    ) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.body(presentation == .product ? 13 : 15)
        button.titleLabel?.adjustsFontSizeToFitWidth = presentation == .product
        button.titleLabel?.minimumScaleFactor = 0.82
        button.setTitleColor(DJDesignTokens.Color.textPrimary, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.surface
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: presentation == .product ? 40 : 42).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier
    }

    @objc private func skipOnceTapped() {
        submitBoundary(.skipOnce)
    }

    @objc private func cooldownTapped() {
        submitBoundary(.cooldown)
    }

    @objc private func doNotAskTapped() {
        submitBoundary(.doNotAsk)
    }

    @objc private func topicSwitchTapped() {
        guard presentation == .qa,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.lifecycle == .active,
              renderedState.continuation?.canContinue ?? true else {
            return
        }
        useCase.send(.pauseForTopicSwitch)
    }

    @objc private func deepeningCompletedTapped() {
        submitPacing(.deepeningCompleted)
    }

    @objc private func summaryCompletedTapped() {
        submitPacing(.summaryCompleted)
    }

    @objc private func restoreDoNotAskTapped() {
        guard presentation == .qa || presentation == .product,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.boundary == .doNotAsk else {
            return
        }
        let alert = UIAlertController(
            title: "恢复这个话题？",
            message: "恢复后，后续访谈可以再次围绕这个话题提问。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "暂不恢复", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认恢复", style: .default) { [weak self] _ in
            self?.useCase.send(.restoreDoNotAsk)
        })
        present(alert, animated: true)
    }

    @objc private func restoreCooldownTapped() {
        guard presentation == .qa,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.boundary == .cooldown else {
            return
        }
        useCase.send(.restoreCooldown)
    }

    private func submitBoundary(_ boundary: OwnerTruthInterviewSessionBoundary) {
        guard presentation == .qa || presentation == .product,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.boundary == .open else {
            return
        }
        useCase.send(.setBoundary(boundary))
    }

    private func submitPacing(_ event: OwnerTruthInterviewPacingEvent) {
        guard presentation == .qa,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.lifecycle == .active,
              renderedState.latestReceipt?.boundary == .open else {
            return
        }
        useCase.send(.recordPacing(event))
    }

    func triggerBoundaryButtonForQA(_ boundary: OwnerTruthInterviewSessionBoundary) {
        guard presentation == .qa else { return }
        switch boundary {
        case .skipOnce:
            skipOnceButton.sendActions(for: .touchUpInside)
        case .cooldown:
            cooldownButton.sendActions(for: .touchUpInside)
        case .doNotAsk:
            doNotAskButton.sendActions(for: .touchUpInside)
        case .open:
            return
        }
    }

    func triggerTopicSwitchForQA() {
        guard presentation == .qa else { return }
        topicSwitchButton.sendActions(for: .touchUpInside)
    }

    func triggerPacingForQA(_ event: OwnerTruthInterviewPacingEvent) {
        guard presentation == .qa else { return }
        switch event {
        case .deepeningCompleted:
            deepeningCompletedButton.sendActions(for: .touchUpInside)
        case .summaryCompleted:
            summaryCompletedButton.sendActions(for: .touchUpInside)
        }
    }

    func triggerDoNotAskRestoreForQA() {
        guard presentation == .qa,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.boundary == .doNotAsk else {
            return
        }
        useCase.send(.restoreDoNotAsk)
    }

    func triggerCooldownRestoreForQA() {
        guard presentation == .qa,
              renderedState.phase == .ready,
              renderedState.latestReceipt?.boundary == .cooldown else {
            return
        }
        useCase.send(.restoreCooldown)
    }

    func acknowledgeReviewBatchForUIQA() {
        guard presentation == .product else { return }
        acknowledgeCurrentReviewBatch()
    }

    func startCandidateProposalAdmissionForUIQA() {
        guard presentation == .product else { return }
        startCandidateProposalAdmission()
    }

    func checkCandidateProposalStatusForUIQA() {
        guard presentation == .product,
              candidateProposalStatusEntryButton.isEnabled else {
            return
        }
        candidateProposalStatusEntryButton.sendActions(for: .touchUpInside)
    }

    private func statusText(for state: OwnerTruthInterviewNaturalInputViewState) -> String {
        switch state.phase {
        case .idle:
            return presentation == .qa ? "准备创建访谈会话" : "准备开始"
        case .starting:
            return presentation == .qa ? "正在创建受控会话" : "正在准备"
        case .ready:
            if presentation == .qa {
                if let boundary = state.latestReceipt?.boundary, boundary != .open {
                    return "边界已更新：\(boundaryText(boundary))"
                }
                return state.latestReceipt?.messageSequence == nil
                    ? "可以提交一条自然输入"
                    : "自然输入已受控记录"
            }
            if let continuation = state.continuation {
                return productStatusText(for: continuation)
            }
            return state.latestReceipt?.messageSequence == nil
                ? "可以开始写下"
                : "已记录，可以继续写下新的内容"
        case .submitting:
            return presentation == .qa ? "正在记录自然输入" : "正在保存"
        case .unavailable:
            return unavailableText(state.notice)
        case .failed:
            return "自然输入暂不可用"
        }
    }

    private func detailText(for state: OwnerTruthInterviewNaturalInputViewState) -> String {
        guard let receipt = state.latestReceipt else {
            switch state.notice {
            case .invalidInput:
                return "请输入不超过 20000 字的内容。"
            case .contractMismatch:
                return presentation == .qa ? "会话回执不匹配，未保留输入内容。" : "保存失败，请稍后重试。"
            case .requestFailed:
                return presentation == .qa ? "请求失败，未保留输入内容。" : "保存失败，请稍后重试。"
            default:
                return ""
            }
        }
        guard presentation == .qa else {
            if let continuation = state.continuation {
                return productDetailText(for: continuation)
            }
            return receipt.messageSequence == nil
                ? "准备好后，写下你想讲的内容。"
                : "已保存，可以继续写下新的内容。"
        }
        var lines = [
            "会话：\(lifecycleText(receipt.lifecycle)) · \(boundaryText(receipt.boundary))",
            "线程版本：\(receipt.threadVersion) · 会话版本：\(receipt.sessionVersion)",
            "回执状态：\(receipt.outcome.rawValue)",
        ]
        if let messageSequence = receipt.messageSequence {
            lines.append("已记录输入：第 \(messageSequence) 条（文本不回显）")
        } else {
            lines.append("会话已创建，尚未提交输入。")
        }
        return lines.joined(separator: "\n")
    }

    private func productStatusText(
        for continuation: OwnerTruthInterviewNaturalInputContinuation
    ) -> String {
        switch continuation.state {
        case .readyForNarrative:
            return "可以开始写下"
        case .narrativeRecorded:
            return "这段分享已经留好"
        case .reviewPending:
            return reviewBatchAcknowledgementStatusText()
        case .paused:
            return "这次先到这里"
        case .ended:
            return "这段分享已留好"
        }
    }

    private func productDetailText(
        for continuation: OwnerTruthInterviewNaturalInputContinuation
    ) -> String {
        switch continuation.state {
        case .readyForNarrative:
            return "准备好后，写下你想讲的内容。"
        case .narrativeRecorded:
            return "这段分享已经留好。想起来时，可以继续补充。"
        case .reviewPending:
            return reviewBatchAcknowledgementDetailText()
        case .paused:
            return continuation.canContinueLater
                ? "想继续时，可以再回来。"
                : "已按你的选择，暂不再追问。"
        case .ended:
            return continuation.canContinueLater
                ? "以后还可以开启新的故事。"
                : "这段分享已留好。"
        }
    }

    private func reviewBatchAcknowledgementStatusText() -> String {
        switch candidateProposalAdmissionState.phase {
        case .admitting:
            return "正在开始整理"
        case .admitted:
            return candidateProposalStatusText()
        case .failed, .unavailable:
            return "暂时无法开始整理"
        case .idle:
            break
        }
        switch reviewBatchAcknowledgementState.phase {
        case .discovering, .acknowledging:
            return "正在确认本次分享"
        case .acknowledged:
            return "这段分享已确认"
        case .failed, .unavailable:
            return "暂时无法确认整理"
        case .idle:
            return "这段分享等待整理"
        }
    }

    private func reviewBatchAcknowledgementDetailText() -> String {
        switch candidateProposalAdmissionState.phase {
        case .admitting:
            return "正在建立本次分享的整理边界。"
        case .admitted:
            return candidateProposalStatusDetailText()
        case .failed, .unavailable:
            return candidateProposalAdmissionFailureDetailText()
        case .idle:
            break
        }
        switch reviewBatchAcknowledgementState.phase {
        case .discovering:
            return "正在确认本次分享的整理边界。"
        case .acknowledging:
            return "正在确认本次分享。"
        case .acknowledged:
            return "你可以开始整理本次内容；整理完成后，仍由你确认是否保存为记忆。"
        case .failed, .unavailable:
            return reviewBatchAcknowledgementFailureDetailText()
        case .idle:
            return reviewBatchAcknowledgementPolicyAvailable()
                ? "确认本次分享后，你可以选择是否开始整理。"
                : "这段分享已经留好。"
        }
    }

    private func candidateProposalAdmissionFailureDetailText() -> String {
        switch candidateProposalAdmissionState.notice {
        case .contractMismatch:
            return "本次分享的状态已更新，请重新进入查看。"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入。"
        case .releasePolicyDisabled:
            return "当前暂不能开始整理，请稍后再试。"
        case .invalidVault, .requestFailed, nil:
            return "暂时无法开始整理，请稍后重试。"
        }
    }

    private func candidateProposalStatusText() -> String {
        switch candidateProposalStatusState.phase {
        case .idle, .loading:
            return "正在查看整理进度"
        case .unavailable:
            switch candidateProposalStatusState.notice {
            case .contentUnavailable:
                return "本次整理内容已失效"
            case .contextChanged:
                return "本次整理状态已更新"
            case .releasePolicyDisabled, .invalidVault, .accountUnavailable, .staleAccountLease,
                 .requestFailed, nil:
                return "暂时无法查看整理进度"
            }
        case .failed:
            return "暂时无法查看整理进度"
        case .ready:
            switch candidateProposalStatusState.status?.candidateReviewState {
            case .notReady:
                return "这段分享正在整理"
            case .reviewReady:
                return "整理完成，等待你确认"
            case .noCandidates:
                return "本次暂未形成记忆建议"
            case .extractionFailed:
                return "整理暂未完成"
            case .extractionQuarantined:
                return "本次整理需要进一步核验"
            case nil:
                return "正在查看整理进度"
            }
        }
    }

    private func candidateProposalStatusDetailText() -> String {
        switch candidateProposalStatusState.phase {
        case .idle:
            return "后续整理结果仍会等待你确认是否保存为记忆。"
        case .loading:
            return "正在确认本次分享的整理进度。"
        case .unavailable:
            switch candidateProposalStatusState.notice {
            case .contentUnavailable:
                return "当前没有写入任何正式记忆。请返回后重新进入本次分享。"
            case .contextChanged:
                return "本次分享的状态已更新，请重新查看整理进度。"
            case .releasePolicyDisabled, .invalidVault, .accountUnavailable, .staleAccountLease,
                 .requestFailed, nil:
                return "当前没有写入任何正式记忆，可稍后再次查看。"
            }
        case .failed:
            return "当前没有写入任何正式记忆，可稍后再次查看。"
        case .ready:
            switch candidateProposalStatusState.status?.candidateReviewState {
            case .notReady:
                return "整理完成后，仍会等待你确认是否保存为记忆。"
            case .reviewReady:
                return "候选记忆仍需由你逐项确认，未确认不会写入正式记忆。"
            case .noCandidates:
                return "本次分享仍已保留；你可以继续补充新的内容。"
            case .extractionFailed:
                return "当前没有写入任何正式记忆，可稍后再次查看。"
            case .extractionQuarantined:
                return "当前没有写入任何正式记忆，待进一步核验后再决定。"
            case nil:
                return "后续整理结果仍会等待你确认是否保存为记忆。"
            }
        }
    }

    private func reviewBatchAcknowledgementFailureDetailText() -> String {
        switch reviewBatchAcknowledgementState.notice {
        case .matchingBatchUnavailable:
            return "暂时未找到本次待整理内容，请稍后再试。"
        case .contractMismatch:
            return "本次分享的状态已更新，请重新进入查看。"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入。"
        case .releasePolicyDisabled:
            return "当前暂不能开始整理，请稍后再试。"
        case .invalidVault, .requestFailed, nil:
            return "暂时无法确认整理，请稍后重试。"
        }
    }

    private func lifecycleText(_ lifecycle: OwnerTruthInterviewSessionLifecycle) -> String {
        switch lifecycle {
        case .active: return "进行中"
        case .paused: return "已暂停"
        case .ended: return "已结束"
        }
    }

    private func boundaryText(_ boundary: OwnerTruthInterviewSessionBoundary) -> String {
        switch boundary {
        case .open: return "可继续"
        case .skipOnce: return "本轮跳过"
        case .cooldown: return "冷却中"
        case .doNotAsk: return "不再追问"
        }
    }

    private func unavailableText(_ notice: OwnerTruthInterviewNaturalInputNotice?) -> String {
        switch notice {
        case .qaOnlyDisabled:
            return presentation == .qa ? "QA 开关未启用" : "当前暂不可用，请稍后再试。"
        case .invalidVault:
            return "当前档案空间不可用"
        case .accountUnavailable, .staleAccountLease:
            return "账号已变化，请重新进入"
        case .invalidInput, .contractMismatch, .requestFailed, nil:
            return "自然输入暂不可用"
        }
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)

private struct OwnerTruthInterviewCandidateConfirmationFailClosedUIQAState {
    let phase: String
    let candidateCount: Int
    let batchSubmitHidden: Bool
    let batchSubmitEnabled: Bool
    let listInteractionEnabled: Bool
    let refreshEnabled: Bool
    let statusText: String
}

private extension OwnerTruthInterviewCandidateConfirmationViewController {
    func failClosedUIQAState() -> OwnerTruthInterviewCandidateConfirmationFailClosedUIQAState {
        let phase: String
        switch renderedState.phase {
        case .idle: phase = "idle"
        case .loading: phase = "loading"
        case .ready: phase = "ready"
        case .empty: phase = "empty"
        case .unavailable: phase = "unavailable"
        case .failed: phase = "failed"
        }
        let candidateCount = (renderedState.confirmation?.batchCandidates.count ?? 0)
            + (renderedState.confirmation?.singleCandidates.count ?? 0)
        return OwnerTruthInterviewCandidateConfirmationFailClosedUIQAState(
            phase: phase,
            candidateCount: candidateCount,
            batchSubmitHidden: confirmSelectionButton.isHidden,
            batchSubmitEnabled: confirmSelectionButton.isEnabled,
            listInteractionEnabled: tableView.isUserInteractionEnabled,
            refreshEnabled: refreshButton.isEnabled,
            statusText: statusLabel.text ?? ""
        )
    }
}

/// A simulator-only interaction check for the action failure boundary. The
/// fixture returns a typed-but-mismatched batch receipt, so the product detail
/// must clear old Candidate content before its fresh read completes.
enum OwnerTruthInterviewCandidateConfirmationFailClosedUIQASmoke {
    private static var activeScenario: OwnerTruthInterviewCandidateConfirmationFailClosedUIQAScenario?

    static func start(
        accountLease: AccountLease,
        navigationController: UINavigationController,
        completion: @escaping ([String: Any]) -> Void
    ) {
        let scenario = OwnerTruthInterviewCandidateConfirmationFailClosedUIQAScenario(
            accountLease: accountLease
        )
        activeScenario = scenario
        scenario.start(in: navigationController) { result in
            completion(result)
            activeScenario = nil
        }
    }
}

private final class OwnerTruthInterviewCandidateConfirmationFailClosedUIQAScenario {
    private let accountLease: AccountLease
    private let fixture: OwnerTruthInterviewCandidateConfirmationFailClosedUIQAFixture
    private weak var confirmationController: OwnerTruthInterviewCandidateConfirmationViewController?
    private var initialState: OwnerTruthInterviewCandidateConfirmationFailClosedUIQAState?
    private var reloadState: OwnerTruthInterviewCandidateConfirmationFailClosedUIQAState?
    private var didFinish = false

    init(accountLease: AccountLease) {
        self.accountLease = accountLease
        fixture = OwnerTruthInterviewCandidateConfirmationFailClosedUIQAFixture(
            vaultID: OwnerTruthVaultID(accountLease.vaultId)
        )
    }

    func start(
        in navigationController: UINavigationController,
        completion: @escaping ([String: Any]) -> Void
    ) {
        let controller = OwnerTruthInterviewCandidateConfirmationViewController(
            accountLease: accountLease,
            reviewBatchID: fixture.reviewBatchID,
            confirmationClient: fixture,
            batchActionClient: fixture,
            singleActionClient: fixture,
            releasePolicyAvailable: { true }
        )
        confirmationController = controller
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()

        fixture.onReloadReadStarted = { [weak self] in
            self?.captureReloadState()
        }
        fixture.onReloadReadFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.finish(completion: completion, failureReason: nil)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.submitFixtureBatch(completion: completion)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.finish(completion: completion, failureReason: "timeout")
        }
    }

    private func submitFixtureBatch(completion: @escaping ([String: Any]) -> Void) {
        guard let confirmationController else {
            finish(completion: completion, failureReason: "confirmationDetailUnavailable")
            return
        }
        let state = confirmationController.failClosedUIQAState()
        initialState = state
        guard state.phase == "ready", state.candidateCount == 1 else {
            finish(completion: completion, failureReason: "initialConfirmationUnavailable")
            return
        }
        confirmationController.submitBatchConfirmation(candidateIDs: [fixture.initialCandidateID])
    }

    private func captureReloadState() {
        reloadState = confirmationController?.failClosedUIQAState()
    }

    private func finish(
        completion: @escaping ([String: Any]) -> Void,
        failureReason: String?
    ) {
        guard !didFinish else { return }
        didFinish = true

        let finalState = confirmationController?.failClosedUIQAState()
        let initialState = initialState
        let reloadState = reloadState
        let completed = failureReason == nil
            && initialState?.phase == "ready"
            && initialState?.candidateCount == 1
            && fixture.actionRequestCount == 1
            && fixture.confirmationReadCount == 2
            && reloadState?.phase == "loading"
            && reloadState?.candidateCount == 0
            && reloadState?.batchSubmitHidden == true
            && reloadState?.listInteractionEnabled == false
            && reloadState?.refreshEnabled == false
            && reloadState?.statusText == "确认结果尚未核对完成，请重新载入。"
            && finalState?.phase == "empty"
            && finalState?.candidateCount == 0

        completion([
            "completed": completed,
            "inMemoryFixture": true,
            "candidateRouteNetworkRequests": 0,
            "persistentCandidateWrites": 0,
            "failureDisposition": "responseMismatch",
            "initialCandidateVisible": initialState?.candidateCount == 1,
            "actionRequestCount": fixture.actionRequestCount,
            "confirmationReadCount": fixture.confirmationReadCount,
            "reloadStarted": reloadState != nil,
            "oldCandidateClearedDuringReload": reloadState?.candidateCount == 0,
            "batchSubmitHiddenDuringReload": reloadState?.batchSubmitHidden == true,
            "batchSubmitDisabledDuringReload": reloadState?.batchSubmitEnabled == false,
            "listInteractionDisabledDuringReload": reloadState?.listInteractionEnabled == false,
            "refreshDisabledDuringReload": reloadState?.refreshEnabled == false,
            "staleActionStatusVisibleDuringReload": reloadState?.statusText == "确认结果尚未核对完成，请重新载入。",
            "finalPhase": finalState?.phase ?? "unavailable",
            "finalCandidateCount": finalState?.candidateCount ?? -1,
            "launchArguments": [
                QALaunchScenario.ownerTruthInterviewCandidateConfirmationFailClosedSmoke.rawValue,
            ],
            "failureReason": failureReason as Any,
        ])
    }
}

private final class OwnerTruthInterviewCandidateConfirmationFailClosedUIQAFixture:
    OwnerTruthInterviewCandidateConfirmationClient,
    OwnerTruthInterviewCandidateConfirmationActionClient,
    OwnerTruthInterviewCandidateConfirmationSingleActionClient {
    private let vaultID: OwnerTruthVaultID?
    let reviewBatchID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000c1")!
    )
    let initialCandidateID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000c2")!
    )
    private let mismatchedCandidateID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000c3")!
    )
    private(set) var confirmationReadCount = 0
    private(set) var actionRequestCount = 0
    var onReloadReadStarted: (() -> Void)?
    var onReloadReadFinished: (() -> Void)?

    init(vaultID: OwnerTruthVaultID?) {
        self.vaultID = vaultID
    }

    func fetchOwnerTruthInterviewCandidateConfirmation(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmation, Error>) -> Void
    ) {
        guard vaultID == self.vaultID, reviewBatchID == self.reviewBatchID else {
            completion(.failure(OwnerTruthInterviewCandidateConfirmationFailClosedUIQAError.invalidRequest))
            return
        }
        confirmationReadCount += 1
        do {
            switch confirmationReadCount {
            case 1:
                completion(.success(try makeInitialConfirmation(vaultID: vaultID)))
            case 2:
                onReloadReadStarted?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let self else { return }
                    do {
                        completion(.success(try self.makeEmptyConfirmation(vaultID: vaultID)))
                    } catch {
                        completion(.failure(error))
                    }
                    self.onReloadReadFinished?()
                }
            default:
                completion(.failure(OwnerTruthInterviewCandidateConfirmationFailClosedUIQAError.unexpectedRead))
            }
        } catch {
            completion(.failure(error))
        }
    }

    func confirmOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationBatchCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>) -> Void
    ) {
        guard vaultID == self.vaultID,
              command.reviewBatchID == reviewBatchID else {
            completion(.failure(OwnerTruthInterviewCandidateConfirmationFailClosedUIQAError.invalidRequest))
            return
        }
        actionRequestCount += 1
        do {
            let mismatchedCommand = try OwnerTruthInterviewCandidateConfirmationBatchCommand(
                commandID: "uiqa-mismatched-candidate-confirmation",
                reviewBatchID: reviewBatchID,
                selections: [
                    try OwnerTruthInterviewCandidateBatchSelection(
                        candidateID: mismatchedCandidateID,
                        expectedCandidateVersion: 1
                    ),
                ]
            )
            completion(.success(try OwnerTruthInterviewCandidateConfirmationBatchResult(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmationBatchResult.schemaVersion,
                    "status": OwnerTruthCommandOutcome.created.rawValue,
                    "batchDecisionId": "00000000-0000-0000-0000-0000000000c4",
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "acceptedCandidateCount": 1,
                    "acceptedCandidateIds": [mismatchedCandidateID.rawValue.uuidString],
                    "memoryActivation": [
                        "status": OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
                        "memoryVersionCreated": false,
                    ],
                ],
                expectedCommand: mismatchedCommand
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func confirmOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationSingleCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationSingleResult, Error>) -> Void
    ) {
        completion(.failure(OwnerTruthInterviewCandidateConfirmationFailClosedUIQAError.unexpectedSingleAction))
    }

    private func makeInitialConfirmation(
        vaultID: OwnerTruthVaultID
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        try makeConfirmation(
            vaultID: vaultID,
            batchCandidates: [[
                "candidateId": initialCandidateID.rawValue.uuidString,
                "sourceId": "00000000-0000-0000-0000-0000000000c5",
                "memoryKind": OwnerTruthMemoryKind.experience.rawValue,
                "perspectiveType": OwnerTruthPerspectiveType.firstPerson.rawValue,
                "epistemicStatus": OwnerTruthEpistemicStatus.recalled.rawValue,
                "sensitivity": OwnerTruthSensitivityLevel.standard.rawValue,
                "contentSchemaVersion": "owner-truth-candidate-content-v1",
                "content": ["summary": "UIQA 确认详情候选"],
                "contentHash": "uiqa-candidate-confirmation-hash",
                "sourceRefs": [["sourceId": "00000000-0000-0000-0000-0000000000c5", "sourceVersion": 1]],
                "reviewMode": "batch",
                "candidateVersion": 1,
                "extractionId": "00000000-0000-0000-0000-0000000000c6",
                "reviewPath": OwnerTruthInterviewCandidateReviewPath.batch.rawValue,
            ]],
            singleCandidates: []
        )
    }

    private func makeEmptyConfirmation(
        vaultID: OwnerTruthVaultID
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        try makeConfirmation(
            vaultID: vaultID,
            readiness: .noCandidates,
            batchCandidates: [],
            singleCandidates: []
        )
    }

    private func makeConfirmation(
        vaultID: OwnerTruthVaultID,
        readiness: OwnerTruthInterviewCandidateReviewReadiness = .reviewReady,
        batchCandidates: [[String: Any]],
        singleCandidates: [[String: Any]]
    ) throws -> OwnerTruthInterviewCandidateConfirmation {
        try OwnerTruthInterviewCandidateConfirmation(
            backendJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateConfirmation.schemaVersion,
                "vaultId": vaultID.rawValue,
                "confirmation": [
                    "schemaVersion": OwnerTruthInterviewCandidateConfirmation.compositionSchemaVersion,
                    "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    "admissionId": "00000000-0000-0000-0000-0000000000c7",
                    "sourceId": "00000000-0000-0000-0000-0000000000c5",
                    "sourceVersion": 1,
                    "authorityEpoch": 0,
                    "readiness": readiness.rawValue,
                    "latestExtractionStatus": "succeeded",
                    "selectedExtractionId": "00000000-0000-0000-0000-0000000000c6",
                    "batchCandidateCount": batchCandidates.count,
                    "singleCandidateCount": singleCandidates.count,
                ],
                "batchCandidates": batchCandidates,
                "singleCandidates": singleCandidates,
            ],
            expectedVaultID: vaultID,
            expectedReviewBatchID: reviewBatchID
        )
    }
}

private enum OwnerTruthInterviewCandidateConfirmationFailClosedUIQAError: Error {
    case invalidRequest
    case unexpectedRead
    case unexpectedSingleAction
}

struct OwnerTruthInterviewNaturalInputUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-natural-input-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let sessionCreated: Bool
    let sessionResumed: Bool
    let startRequestCount: Int
    let inputRecorded: Bool
    let messageSequence: Int?
    let transcriptCleared: Bool
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewNaturalInputUIQASmoke {
    static let fixtureText = "这是 UIQA 专用的访谈自然输入。"

    /// Creates an in-memory preview surface for an Echo UIQA route check. It
    /// intentionally does not attach the auto-submit scenario, so opening the
    /// sheet proves layout and presentation without making a backend request.
    static func makePreviewViewController(
        accountLease: AccountLease,
        presentation: OwnerTruthInterviewNaturalInputPresentation = .qa,
        client: OwnerTruthInterviewNaturalInputClient? = nil,
        postNarrativeContinuationState: OwnerTruthInterviewNaturalInputContinuationState = .narrativeRecorded,
        reviewBatchInboxClient: OwnerTruthInterviewPendingReviewBatchInboxClient? = nil,
        reviewBatchAcknowledgementClient: OwnerTruthInterviewReviewBatchAcknowledgementClient? = nil,
        reviewBatchAcknowledgementPolicyAvailable: @escaping () -> Bool = { false },
        candidateProposalAdmissionClient: OwnerTruthInterviewCandidateProposalAdmissionClient? = nil,
        candidateProposalAdmissionPolicyAvailable: @escaping () -> Bool = { false },
        candidateProposalStatusClient: OwnerTruthInterviewCandidateProposalStatusClient? = nil,
        candidateProposalStatusPolicyAvailable: @escaping () -> Bool = { false },
        candidateProposalConfirmationInboxControllerProvider: @escaping (AccountLease, OwnerTruthRecordID) -> UIViewController = {
            accountLease,
            reviewBatchID in
            OwnerTruthInterviewCandidateConfirmationInboxViewController(
                accountLease: accountLease,
                focusedReviewBatchID: reviewBatchID
            )
        }
    ) -> OwnerTruthInterviewNaturalInputViewController {
        let client = client ?? InterviewNaturalInputUIQAClient(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            postNarrativeContinuationState: postNarrativeContinuationState
        )
        let previewGateEnabled: () -> Bool
        switch presentation {
        case .qa:
            previewGateEnabled = { OwnerTruthCandidateReviewQAGate.isEnabled }
        case .product:
            // This preview is reachable only from the UIQA simulator harness.
            // Production still receives its gate from Echo's fresh policy decision.
            previewGateEnabled = { true }
        }
        let resolvedReviewBatchInboxClient = reviewBatchInboxClient
            ?? (client as? OwnerTruthInterviewPendingReviewBatchInboxClient)
            ?? DreamJourneyBackendClient.shared
        let resolvedReviewBatchAcknowledgementClient = reviewBatchAcknowledgementClient
            ?? (client as? OwnerTruthInterviewReviewBatchAcknowledgementClient)
            ?? DreamJourneyBackendClient.shared
        let resolvedCandidateProposalAdmissionClient = candidateProposalAdmissionClient
            ?? (client as? OwnerTruthInterviewCandidateProposalAdmissionClient)
            ?? DreamJourneyBackendClient.shared
        let resolvedCandidateProposalStatusClient = candidateProposalStatusClient
            ?? (client as? OwnerTruthInterviewCandidateProposalStatusClient)
            ?? DreamJourneyBackendClient.shared
        return OwnerTruthInterviewNaturalInputViewController(
            accountLease: accountLease,
            client: client,
            presentation: presentation,
            reviewBatchInboxClient: resolvedReviewBatchInboxClient,
            reviewBatchAcknowledgementClient: resolvedReviewBatchAcknowledgementClient,
            reviewBatchAcknowledgementPolicyAvailable: reviewBatchAcknowledgementPolicyAvailable,
            candidateProposalAdmissionClient: resolvedCandidateProposalAdmissionClient,
            candidateProposalAdmissionPolicyAvailable: candidateProposalAdmissionPolicyAvailable,
            candidateProposalStatusClient: resolvedCandidateProposalStatusClient,
            candidateProposalStatusPolicyAvailable: candidateProposalStatusPolicyAvailable,
            candidateProposalConfirmationInboxControllerProvider: candidateProposalConfirmationInboxControllerProvider,
            qaGateEnabled: previewGateEnabled
        )
    }

    static func makeViewController(
        accountLease: AccountLease
    ) -> OwnerTruthInterviewNaturalInputViewController {
        let client = InterviewNaturalInputUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId))
        let controller = makePreviewViewController(accountLease: accountLease, client: client)
        let scenario = InterviewNaturalInputUIQAScenario(accountLease: accountLease, client: client)
        controller.onViewStateRendered = { state in
            scenario.consume(state, controller: controller)
        }
        return controller
    }

    static func writeFailure(_ reason: String) {
        let result = OwnerTruthInterviewNaturalInputUIQASmokeResult(
            completed: false,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            sessionCreated: false,
            sessionResumed: false,
            startRequestCount: 0,
            inputRecorded: false,
            messageSequence: nil,
            transcriptCleared: false,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewNaturalInputSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: reason
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewNaturalInputSmoke failed result=\(resultURL.path) reason=\(reason)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewNaturalInputSmoke failed reason=\(reason) write=\(error.localizedDescription)")
        }
    }
}

/// Keeps the review-ready simulator fixture inside the Archive module where the
/// private in-memory client lives. Echo receives only opaque batch observations.
struct OwnerTruthInterviewCandidateProposalReviewReadyUIQAObservation {
    let confirmationInboxPresented: Bool
    let focusedReviewBatchMatches: Bool
    let focusedInboxVisibleItemCount: Int
    let otherReviewBatchHidden: Bool
    let confirmationDetailPresented: Bool
}

final class OwnerTruthInterviewCandidateProposalReviewReadyUIQAScenario {
    private let accountLease: AccountLease
    private let naturalInputClient: InterviewNaturalInputUIQAClient
    private let confirmationInboxClient: InterviewNaturalInputUIQAClient.CandidateConfirmationInboxFixture
    private var requestedReviewBatchID: OwnerTruthRecordID?
    private weak var confirmationInboxController: OwnerTruthInterviewCandidateConfirmationInboxViewController?

    init(accountLease: AccountLease) {
        self.accountLease = accountLease
        naturalInputClient = InterviewNaturalInputUIQAClient(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            postNarrativeContinuationState: .reviewPending,
            candidateProposalReviewState: .reviewReady
        )
        confirmationInboxClient = InterviewNaturalInputUIQAClient.CandidateConfirmationInboxFixture(
            vaultID: OwnerTruthVaultID(accountLease.vaultId),
            focusedReviewBatchID: naturalInputClient.reviewBatchIDForUIQA
        )
    }

    var candidateProposalStatusRequestCount: Int {
        naturalInputClient.candidateProposalStatusRequestCount
    }

    var confirmationInboxReadCount: Int {
        confirmationInboxClient.requestCount
    }

    func makePreviewViewController() -> OwnerTruthInterviewNaturalInputViewController {
        OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
            accountLease: accountLease,
            presentation: .product,
            client: naturalInputClient,
            postNarrativeContinuationState: .reviewPending,
            reviewBatchAcknowledgementPolicyAvailable: { true },
            candidateProposalAdmissionPolicyAvailable: { true },
            candidateProposalStatusPolicyAvailable: { true },
            candidateProposalConfirmationInboxControllerProvider: { [weak self] lease, reviewBatchID in
                guard let self else {
                    preconditionFailure("Review-ready UIQA scenario was released before confirmation handoff")
                }
                requestedReviewBatchID = reviewBatchID
                let inbox = OwnerTruthInterviewCandidateConfirmationInboxViewController(
                    accountLease: lease,
                    focusedReviewBatchID: reviewBatchID,
                    client: confirmationInboxClient,
                    releasePolicyAvailable: { true }
                )
                confirmationInboxController = inbox
                return inbox
            }
        )
    }

    func observeHandoff(
        in navigationController: UINavigationController
    ) -> OwnerTruthInterviewCandidateProposalReviewReadyUIQAObservation {
        let visibleReviewBatchIDs = confirmationInboxController?.visibleReviewBatchIDsForUIQA ?? []
        let expectedReviewBatchID = naturalInputClient.reviewBatchIDForUIQA
        return OwnerTruthInterviewCandidateProposalReviewReadyUIQAObservation(
            confirmationInboxPresented: navigationController.topViewController === confirmationInboxController,
            focusedReviewBatchMatches: requestedReviewBatchID == expectedReviewBatchID
                && confirmationInboxController?.focusedReviewBatchIDForUIQA == expectedReviewBatchID,
            focusedInboxVisibleItemCount: visibleReviewBatchIDs.count,
            otherReviewBatchHidden: !visibleReviewBatchIDs.contains(
                confirmationInboxClient.otherReviewBatchIDForUIQA
            ),
            confirmationDetailPresented: navigationController.topViewController
                is OwnerTruthInterviewCandidateConfirmationViewController
        )
    }
}

private final class InterviewNaturalInputUIQAScenario {
    private let accountLease: AccountLease
    private let client: InterviewNaturalInputUIQAClient
    private var didSubmit = false
    private var didWrite = false
    private var didFinish = false
    private var resumeUseCase: OwnerTruthInterviewNaturalInputUseCase?

    init(accountLease: AccountLease, client: InterviewNaturalInputUIQAClient) {
        self.accountLease = accountLease
        self.client = client
    }

    func consume(
        _ state: OwnerTruthInterviewNaturalInputViewState,
        controller: OwnerTruthInterviewNaturalInputViewController
    ) {
        guard !didWrite, !didFinish, state.phase == .ready, let receipt = state.latestReceipt else { return }
        guard receipt.messageSequence != nil else {
            guard !didSubmit else { return }
            didSubmit = true
            DispatchQueue.main.async {
                controller.submitQAFixture(OwnerTruthInterviewNaturalInputUIQASmoke.fixtureText)
            }
            return
        }
        didWrite = true
        startResumeCheck(after: receipt, controller: controller)
    }

    private func startResumeCheck(
        after receipt: OwnerTruthInterviewNaturalInputReceipt,
        controller: OwnerTruthInterviewNaturalInputViewController
    ) {
        let transcriptCleared = controller.isTranscriptClearForQA
        let resumeUseCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: accountLease,
            client: client
        )
        self.resumeUseCase = resumeUseCase
        resumeUseCase.onViewStateChange = { [weak self] resumedState in
            guard let self,
                  !self.didFinish,
                  resumedState.phase == .ready,
                  let resumedReceipt = resumedState.latestReceipt else {
                return
            }
            guard resumedReceipt.outcome == .resumed,
                  resumedReceipt.threadID == receipt.threadID,
                  resumedReceipt.sessionID == receipt.sessionID,
                  resumedReceipt.threadVersion == receipt.threadVersion,
                  resumedReceipt.sessionVersion == receipt.sessionVersion,
                  resumedReceipt.lifecycle == .active,
                  resumedReceipt.boundary == .open,
                  resumedReceipt.messageID == nil,
                  resumedReceipt.messageSequence == nil else {
                self.finish(
                    receipt: receipt,
                    transcriptCleared: transcriptCleared,
                    sessionResumed: false,
                    failureReason: "resumeReceiptMismatch"
                )
                return
            }
            self.finish(
                receipt: receipt,
                transcriptCleared: transcriptCleared,
                sessionResumed: self.client.startRequestCount == 1,
                failureReason: self.client.startRequestCount == 1 ? nil : "unexpectedSecondStart"
            )
        }
        resumeUseCase.send(.start)
    }

    private func finish(
        receipt: OwnerTruthInterviewNaturalInputReceipt,
        transcriptCleared: Bool,
        sessionResumed: Bool,
        failureReason: String?
    ) {
        guard !didFinish else { return }
        didFinish = true
        let result = OwnerTruthInterviewNaturalInputUIQASmokeResult(
            completed: OwnerTruthCandidateReviewQAGate.isEnabled
                && receipt.lifecycle == .active
                && receipt.boundary == .open
                && receipt.messageSequence == 1
                && transcriptCleared
                && sessionResumed,
            qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
            sessionCreated: true,
            sessionResumed: sessionResumed,
            startRequestCount: client.startRequestCount,
            inputRecorded: true,
            messageSequence: receipt.messageSequence,
            transcriptCleared: transcriptCleared,
            launchArguments: [
                QALaunchScenario.ownerTruthInterviewNaturalInputSmoke.rawValue,
                OwnerTruthCandidateReviewQAGate.launchArgument,
            ],
            failureReason: failureReason
        )
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewNaturalInputSmoke completed result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewNaturalInputSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}

struct OwnerTruthInterviewTopicSwitchUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-topic-switch-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let topicSwitchButtonVisible: Bool
    let oldSessionPaused: Bool
    let newSessionStarted: Bool
    let oldAndNewSessionsDiffer: Bool
    let startRequestCount: Int
    let newSessionLifecycle: String?
    let newSessionBoundary: String?
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewTopicSwitchUIQASmoke {
    private static var activeScenario: InterviewNaturalInputTopicSwitchUIQAScenario?

    static func start(
        accountLease: AccountLease,
        navigationController: UINavigationController
    ) {
        let scenario = InterviewNaturalInputTopicSwitchUIQAScenario(
            accountLease: accountLease,
            navigationController: navigationController
        )
        activeScenario = scenario
        scenario.start()
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthInterviewTopicSwitchUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                topicSwitchButtonVisible: false,
                oldSessionPaused: false,
                newSessionStarted: false,
                oldAndNewSessionsDiffer: false,
                startRequestCount: 0,
                newSessionLifecycle: nil,
                newSessionBoundary: nil,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewTopicSwitchSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            ),
            logPrefix: "failed"
        )
    }

    fileprivate static func writeCompleted(
        topicSwitchButtonVisible: Bool,
        oldSessionPaused: Bool,
        newReceipt: OwnerTruthInterviewNaturalInputReceipt,
        oldAndNewSessionsDiffer: Bool,
        startRequestCount: Int
    ) {
        let newSessionStarted = newReceipt.lifecycle == .active
            && newReceipt.boundary == .open
            && newReceipt.messageID == nil
            && newReceipt.messageSequence == nil
        let completed = OwnerTruthCandidateReviewQAGate.isEnabled
            && topicSwitchButtonVisible
            && oldSessionPaused
            && newSessionStarted
            && oldAndNewSessionsDiffer
            && startRequestCount == 2
        write(
            OwnerTruthInterviewTopicSwitchUIQASmokeResult(
                completed: completed,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                topicSwitchButtonVisible: topicSwitchButtonVisible,
                oldSessionPaused: oldSessionPaused,
                newSessionStarted: newSessionStarted,
                oldAndNewSessionsDiffer: oldAndNewSessionsDiffer,
                startRequestCount: startRequestCount,
                newSessionLifecycle: newReceipt.lifecycle.rawValue,
                newSessionBoundary: newReceipt.boundary.rawValue,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewTopicSwitchSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: completed ? nil : "topicSwitchInvariantMismatch"
            ),
            logPrefix: completed ? "completed" : "failed"
        )
        activeScenario = nil
    }

    fileprivate static func writeScenarioFailure(_ reason: String) {
        activeScenario = nil
        writeFailure(reason)
    }

    private static func write(_ result: OwnerTruthInterviewTopicSwitchUIQASmokeResult, logPrefix: String) {
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewTopicSwitchSmoke \(logPrefix) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewTopicSwitchSmoke \(logPrefix) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewNaturalInputTopicSwitchUIQAScenario {
    private let accountLease: AccountLease
    private weak var navigationController: UINavigationController?
    private let client: InterviewNaturalInputUIQAClient
    private var didTrigger = false
    private var didFinish = false

    init(accountLease: AccountLease, navigationController: UINavigationController) {
        self.accountLease = accountLease
        self.navigationController = navigationController
        client = InterviewNaturalInputUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId))
    }

    func start() {
        guard let navigationController else {
            fail("navigationControllerUnavailable")
            return
        }
        let controller = OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
            accountLease: accountLease,
            client: client
        )
        controller.onViewStateRendered = { [weak self, weak controller] state in
            guard let self, let controller else { return }
            self.consume(state, controller: controller)
        }
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()
    }

    private func consume(
        _ state: OwnerTruthInterviewNaturalInputViewState,
        controller: OwnerTruthInterviewNaturalInputViewController
    ) {
        guard !didFinish, state.phase == .ready, let receipt = state.latestReceipt else { return }
        if !didTrigger {
            guard receipt.lifecycle == .active,
                  receipt.boundary == .open,
                  client.startRequestCount == 1,
                  controller.isTopicSwitchActionVisibleForQA else {
                fail("topicSwitchControlUnavailable")
                return
            }
            didTrigger = true
            DispatchQueue.main.async {
                controller.triggerTopicSwitchForQA()
            }
            return
        }
        guard let pausedReceipt = client.lastTopicSwitchPauseReceipt,
              client.startRequestCount == 2 else {
            return
        }
        let oldSessionPaused = pausedReceipt.lifecycle == .paused
            && pausedReceipt.boundary == .open
        let oldAndNewSessionsDiffer = pausedReceipt.threadID != receipt.threadID
            && pausedReceipt.sessionID != receipt.sessionID
        OwnerTruthInterviewTopicSwitchUIQASmoke.writeCompleted(
            topicSwitchButtonVisible: controller.isTopicSwitchActionVisibleForQA,
            oldSessionPaused: oldSessionPaused,
            newReceipt: receipt,
            oldAndNewSessionsDiffer: oldAndNewSessionsDiffer,
            startRequestCount: client.startRequestCount
        )
        didFinish = true
    }

    private func fail(_ reason: String) {
        guard !didFinish else { return }
        didFinish = true
        OwnerTruthInterviewTopicSwitchUIQASmoke.writeScenarioFailure(reason)
    }
}

struct OwnerTruthInterviewPacingUIQASmokeResult: Codable {
    static let fileName = "owner-truth-interview-pacing-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let pacingActionsVisible: Bool
    let deepeningCompletedCount: Int
    let summaryCompletedCount: Int
    let summaryResetObserved: Bool
    let finalDeepeningTurnCount: Int
    let finalSessionVersion: Int?
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewPacingUIQASmoke {
    private static var activeScenario: InterviewNaturalInputPacingUIQAScenario?

    static func start(
        accountLease: AccountLease,
        navigationController: UINavigationController
    ) {
        let scenario = InterviewNaturalInputPacingUIQAScenario(
            accountLease: accountLease,
            navigationController: navigationController
        )
        activeScenario = scenario
        scenario.start()
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthInterviewPacingUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                pacingActionsVisible: false,
                deepeningCompletedCount: 0,
                summaryCompletedCount: 0,
                summaryResetObserved: false,
                finalDeepeningTurnCount: 0,
                finalSessionVersion: nil,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewPacingSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            ),
            logPrefix: "failed"
        )
    }

    fileprivate static func writeCompleted(
        pacingActionsVisible: Bool,
        events: [OwnerTruthInterviewPacingEvent],
        summaryResetObserved: Bool,
        finalDeepeningTurnCount: Int,
        finalReceipt: OwnerTruthInterviewNaturalInputReceipt
    ) {
        let deepeningCompletedCount = events.filter { $0 == .deepeningCompleted }.count
        let summaryCompletedCount = events.filter { $0 == .summaryCompleted }.count
        let finalReceiptIsActive = finalReceipt.lifecycle == .active
            && finalReceipt.boundary == .open
            && finalReceipt.messageID == nil
            && finalReceipt.messageSequence == nil
        let completed = OwnerTruthCandidateReviewQAGate.isEnabled
            && pacingActionsVisible
            && deepeningCompletedCount == 5
            && summaryCompletedCount == 1
            && summaryResetObserved
            && finalDeepeningTurnCount == 1
            && finalReceiptIsActive
        write(
            OwnerTruthInterviewPacingUIQASmokeResult(
                completed: completed,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                pacingActionsVisible: pacingActionsVisible,
                deepeningCompletedCount: deepeningCompletedCount,
                summaryCompletedCount: summaryCompletedCount,
                summaryResetObserved: summaryResetObserved,
                finalDeepeningTurnCount: finalDeepeningTurnCount,
                finalSessionVersion: finalReceipt.sessionVersion,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewPacingSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: completed ? nil : "pacingInvariantMismatch"
            ),
            logPrefix: completed ? "completed" : "failed"
        )
        activeScenario = nil
    }

    fileprivate static func writeScenarioFailure(_ reason: String) {
        activeScenario = nil
        writeFailure(reason)
    }

    private static func write(_ result: OwnerTruthInterviewPacingUIQASmokeResult, logPrefix: String) {
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewPacingSmoke \(logPrefix) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewPacingSmoke \(logPrefix) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewNaturalInputPacingUIQAScenario {
    private let accountLease: AccountLease
    private weak var navigationController: UINavigationController?
    private let client: InterviewNaturalInputUIQAClient
    private let plannedEvents: [OwnerTruthInterviewPacingEvent] = [
        .deepeningCompleted,
        .deepeningCompleted,
        .deepeningCompleted,
        .deepeningCompleted,
        .summaryCompleted,
        .deepeningCompleted,
    ]
    private var nextEventIndex = 0
    private var awaitingRecordedEvent = false
    private var summaryResetObserved = false
    private var didFinish = false

    init(accountLease: AccountLease, navigationController: UINavigationController) {
        self.accountLease = accountLease
        self.navigationController = navigationController
        client = InterviewNaturalInputUIQAClient(vaultID: OwnerTruthVaultID(accountLease.vaultId))
    }

    func start() {
        guard let navigationController else {
            fail("navigationControllerUnavailable")
            return
        }
        let controller = OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
            accountLease: accountLease,
            client: client
        )
        controller.onViewStateRendered = { [weak self, weak controller] state in
            guard let self, let controller else { return }
            self.consume(state, controller: controller)
        }
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()
    }

    private func consume(
        _ state: OwnerTruthInterviewNaturalInputViewState,
        controller: OwnerTruthInterviewNaturalInputViewController
    ) {
        guard !didFinish,
              state.phase == .ready,
              let receipt = state.latestReceipt else {
            return
        }
        guard controller.arePacingActionsVisibleForQA else {
            fail("pacingControlsUnavailable")
            return
        }

        let recordedCount = client.pacingEvents.count
        guard recordedCount <= nextEventIndex else {
            fail("pacingEventCountOutOfOrder")
            return
        }
        if awaitingRecordedEvent {
            guard recordedCount == nextEventIndex else { return }
            awaitingRecordedEvent = false
        }
        if recordedCount >= 5,
           client.pacingEvents[4] == .summaryCompleted,
           client.pacingDeepeningTurnCount == 0 {
            summaryResetObserved = true
        }
        guard nextEventIndex < plannedEvents.count else {
            didFinish = true
            OwnerTruthInterviewPacingUIQASmoke.writeCompleted(
                pacingActionsVisible: controller.arePacingActionsVisibleForQA,
                events: client.pacingEvents,
                summaryResetObserved: summaryResetObserved,
                finalDeepeningTurnCount: client.pacingDeepeningTurnCount,
                finalReceipt: receipt
            )
            return
        }

        let nextEvent = plannedEvents[nextEventIndex]
        nextEventIndex += 1
        awaitingRecordedEvent = true
        DispatchQueue.main.async {
            controller.triggerPacingForQA(nextEvent)
        }
    }

    private func fail(_ reason: String) {
        guard !didFinish else { return }
        didFinish = true
        OwnerTruthInterviewPacingUIQASmoke.writeScenarioFailure(reason)
    }
}

struct OwnerTruthInterviewBoundaryUIQASmokeResult: Codable {
    struct ActionResult: Codable {
        let boundary: String
        let lifecycle: String
        let continuationState: String
        let canContinue: Bool
        let canContinueLater: Bool
    }

    static let fileName = "owner-truth-interview-boundary-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let boundaryButtonsVisible: Bool
    let doNotAskRestoreCompleted: Bool
    let cooldownRestoreCompleted: Bool
    let actionResults: [ActionResult]
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum OwnerTruthInterviewBoundaryUIQASmoke {
    private static var activeScenario: InterviewNaturalInputBoundaryUIQAScenario?

    static func start(
        accountLease: AccountLease,
        navigationController: UINavigationController
    ) {
        let scenario = InterviewNaturalInputBoundaryUIQAScenario(
            accountLease: accountLease,
            navigationController: navigationController
        )
        activeScenario = scenario
        scenario.start()
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthInterviewBoundaryUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                boundaryButtonsVisible: false,
                doNotAskRestoreCompleted: false,
                cooldownRestoreCompleted: false,
                actionResults: [],
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewBoundarySmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            ),
            logPrefix: "failed"
        )
    }

    fileprivate static func writeCompleted(
        boundaryButtonsVisible: Bool,
        actionResults: [OwnerTruthInterviewBoundaryUIQASmokeResult.ActionResult],
        doNotAskRestoreCompleted: Bool,
        cooldownRestoreCompleted: Bool
    ) {
        let expectedBoundaries = [
            OwnerTruthInterviewSessionBoundary.skipOnce.rawValue,
            OwnerTruthInterviewSessionBoundary.cooldown.rawValue,
            OwnerTruthInterviewSessionBoundary.doNotAsk.rawValue,
        ]
        let completed = OwnerTruthCandidateReviewQAGate.isEnabled
            && boundaryButtonsVisible
            && actionResults.map(\.boundary) == expectedBoundaries
            && doNotAskRestoreCompleted
            && cooldownRestoreCompleted
            && actionResults[0].lifecycle == OwnerTruthInterviewSessionLifecycle.active.rawValue
            && actionResults[0].canContinue
            && actionResults[1].lifecycle == OwnerTruthInterviewSessionLifecycle.paused.rawValue
            && !actionResults[1].canContinue
            && actionResults[1].canContinueLater
            && actionResults[2].lifecycle == OwnerTruthInterviewSessionLifecycle.paused.rawValue
            && !actionResults[2].canContinue
            && !actionResults[2].canContinueLater
        write(
            OwnerTruthInterviewBoundaryUIQASmokeResult(
                completed: completed,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                boundaryButtonsVisible: boundaryButtonsVisible,
                doNotAskRestoreCompleted: doNotAskRestoreCompleted,
                cooldownRestoreCompleted: cooldownRestoreCompleted,
                actionResults: actionResults,
                launchArguments: [
                    QALaunchScenario.ownerTruthInterviewBoundarySmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: completed ? nil : "unexpectedBoundaryResult"
            ),
            logPrefix: completed ? "completed" : "failed"
        )
        activeScenario = nil
    }

    fileprivate static func writeScenarioFailure(_ reason: String) {
        activeScenario = nil
        writeFailure(reason)
    }

    private static func write(_ result: OwnerTruthInterviewBoundaryUIQASmokeResult, logPrefix: String) {
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] OwnerTruthInterviewBoundarySmoke \(logPrefix) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthInterviewBoundarySmoke \(logPrefix) write=\(error.localizedDescription)")
        }
    }
}

private final class InterviewNaturalInputBoundaryUIQAScenario {
    private let accountLease: AccountLease
    private weak var navigationController: UINavigationController?
    private let boundaries: [OwnerTruthInterviewSessionBoundary] = [.skipOnce, .cooldown, .doNotAsk]
    private var currentIndex = 0
    private var didTriggerCurrentBoundary = false
    private var awaitingDoNotAskRestore = false
    private var awaitingCooldownRestore = false
    private var actionResults: [OwnerTruthInterviewBoundaryUIQASmokeResult.ActionResult] = []
    private var didFinish = false

    init(accountLease: AccountLease, navigationController: UINavigationController) {
        self.accountLease = accountLease
        self.navigationController = navigationController
    }

    func start() {
        showNextBoundary()
    }

    private func showNextBoundary() {
        guard !didFinish else { return }
        guard currentIndex < boundaries.count else {
            didFinish = true
            OwnerTruthInterviewBoundaryUIQASmoke.writeCompleted(
                boundaryButtonsVisible: true,
                actionResults: actionResults,
                doNotAskRestoreCompleted: false,
                cooldownRestoreCompleted: false
            )
            return
        }
        guard let navigationController else {
            fail("navigationControllerUnavailable")
            return
        }
        let boundary = boundaries[currentIndex]
        let controller = OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
            accountLease: accountLease
        )
        controller.onViewStateRendered = { [weak self, weak controller] state in
            guard let self, let controller else { return }
            self.consume(state, controller: controller, boundary: boundary)
        }
        navigationController.setViewControllers([controller], animated: false)
        controller.loadViewIfNeeded()
    }

    private func consume(
        _ state: OwnerTruthInterviewNaturalInputViewState,
        controller: OwnerTruthInterviewNaturalInputViewController,
        boundary: OwnerTruthInterviewSessionBoundary
    ) {
        guard !didFinish, state.phase == .ready, let receipt = state.latestReceipt else { return }
        if awaitingCooldownRestore {
            guard receipt.boundary == .open,
                  receipt.lifecycle == .active,
                  let continuation = state.continuation,
                  continuation.canContinue,
                  controller.areBoundaryActionsVisibleForQA else {
                if state.continuation != nil {
                    fail("cooldownRestoreFailed")
                }
                return
            }
            awaitingCooldownRestore = false
            currentIndex += 1
            didTriggerCurrentBoundary = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.showNextBoundary()
            }
            return
        }
        if awaitingDoNotAskRestore {
            guard receipt.boundary == .open,
                  receipt.lifecycle == .active,
                  let continuation = state.continuation,
                  continuation.canContinue,
                  controller.areBoundaryActionsVisibleForQA else {
                if state.continuation != nil {
                    fail("doNotAskRestoreFailed")
                }
                return
            }
            didFinish = true
            OwnerTruthInterviewBoundaryUIQASmoke.writeCompleted(
                boundaryButtonsVisible: true,
                actionResults: actionResults,
                doNotAskRestoreCompleted: true,
                cooldownRestoreCompleted: true
            )
            return
        }
        if !didTriggerCurrentBoundary {
            guard receipt.boundary == .open, controller.areBoundaryActionsVisibleForQA else {
                fail("boundaryControlsUnavailable")
                return
            }
            didTriggerCurrentBoundary = true
            DispatchQueue.main.async {
                controller.triggerBoundaryButtonForQA(boundary)
            }
            return
        }
        guard receipt.boundary == boundary, let continuation = state.continuation else { return }
        guard validates(receipt: receipt, continuation: continuation, for: boundary) else {
            fail("unexpectedBoundaryContinuation")
            return
        }
        actionResults.append(
            OwnerTruthInterviewBoundaryUIQASmokeResult.ActionResult(
                boundary: boundary.rawValue,
                lifecycle: receipt.lifecycle.rawValue,
                continuationState: continuation.state.rawValue,
                canContinue: continuation.canContinue,
                canContinueLater: continuation.canContinueLater
            )
        )
        if boundary == .doNotAsk {
            guard controller.isDoNotAskRestoreActionVisibleForQA else {
                fail("doNotAskRestoreUnavailable")
                return
            }
            awaitingDoNotAskRestore = true
            DispatchQueue.main.async {
                controller.triggerDoNotAskRestoreForQA()
            }
            return
        }
        if boundary == .cooldown {
            guard controller.isCooldownRestoreActionVisibleForQA else {
                fail("cooldownRestoreUnavailable")
                return
            }
            awaitingCooldownRestore = true
            DispatchQueue.main.async {
                controller.triggerCooldownRestoreForQA()
            }
            return
        }
        currentIndex += 1
        didTriggerCurrentBoundary = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.showNextBoundary()
        }
    }

    private func validates(
        receipt: OwnerTruthInterviewNaturalInputReceipt,
        continuation: OwnerTruthInterviewNaturalInputContinuation,
        for boundary: OwnerTruthInterviewSessionBoundary
    ) -> Bool {
        switch boundary {
        case .skipOnce:
            return receipt.lifecycle == .active
                && continuation.state == .readyForNarrative
                && continuation.canContinue
                && continuation.canContinueLater
        case .cooldown:
            return receipt.lifecycle == .paused
                && continuation.state == .paused
                && !continuation.canContinue
                && continuation.canContinueLater
        case .doNotAsk:
            return receipt.lifecycle == .paused
                && continuation.state == .paused
                && !continuation.canContinue
                && !continuation.canContinueLater
        case .open:
            return false
        }
    }

    private func fail(_ reason: String) {
        guard !didFinish else { return }
        didFinish = true
        OwnerTruthInterviewBoundaryUIQASmoke.writeScenarioFailure(reason)
    }
}

private final class InterviewNaturalInputUIQAClient: OwnerTruthInterviewNaturalInputClient,
    OwnerTruthInterviewPendingReviewBatchInboxClient,
    OwnerTruthInterviewReviewBatchAcknowledgementClient,
    OwnerTruthInterviewCandidateProposalAdmissionClient,
    OwnerTruthInterviewCandidateProposalStatusClient {
    private let vaultID: OwnerTruthVaultID?
    private let postNarrativeContinuationState: OwnerTruthInterviewNaturalInputContinuationState
    private let candidateProposalReviewState: OwnerTruthInterviewCandidateProposalReviewState
    private var sessionsWithNarrative = Set<UUID>()
    private var endedSessions = Set<UUID>()
    private var boundariesBySessionID: [UUID: OwnerTruthInterviewSessionBoundary] = [:]
    private var currentSessionReceipt: OwnerTruthInterviewNaturalInputReceipt?
    private(set) var startRequestCount = 0
    private(set) var lastTopicSwitchPauseReceipt: OwnerTruthInterviewNaturalInputReceipt?
    private(set) var pacingEvents: [OwnerTruthInterviewPacingEvent] = []
    private(set) var pacingDeepeningTurnCount = 0
    private(set) var lastEndedReceipt: OwnerTruthInterviewNaturalInputReceipt?
    private let reviewBatchID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000b7")!
    )
    private var acknowledgedReviewBatch = false
    private var candidateProposalAdmitted = false
    private(set) var candidateProposalStatusRequestCount = 0

    var reviewBatchIDForUIQA: OwnerTruthRecordID { reviewBatchID }

    init(
        vaultID: OwnerTruthVaultID?,
        postNarrativeContinuationState: OwnerTruthInterviewNaturalInputContinuationState = .narrativeRecorded,
        candidateProposalReviewState: OwnerTruthInterviewCandidateProposalReviewState = .notReady
    ) {
        self.vaultID = vaultID
        self.postNarrativeContinuationState = postNarrativeContinuationState
        self.candidateProposalReviewState = candidateProposalReviewState
    }

    func fetchOwnerTruthInterviewNaturalInputCurrentSession(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputCurrentSession, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            let currentSession: Any
            if let receipt = currentSessionReceipt {
                currentSession = [
                    "status": OwnerTruthInterviewNaturalInputReceiptOutcome.resumed.rawValue,
                    "threadId": receipt.threadID.rawValue.uuidString,
                    "sessionId": receipt.sessionID.rawValue.uuidString,
                    "threadVersion": receipt.threadVersion,
                    "sessionVersion": receipt.sessionVersion,
                    "state": receipt.lifecycle.rawValue,
                    "boundary": receipt.boundary.rawValue,
                ]
            } else {
                currentSession = NSNull()
            }
            completion(.success(try OwnerTruthInterviewNaturalInputCurrentSession(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputCurrentSession.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "currentSession": currentSession,
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func startOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputStartCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            startRequestCount += 1
            let receipt = try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": 1,
                        "sessionVersion": 1,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )
            currentSessionReceipt = receipt
            completion(.success(receipt))
        } catch {
            completion(.failure(error))
        }
    }

    func appendOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputAppendCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        sessionsWithNarrative.insert(command.sessionID.rawValue)
        do {
            let receipt = try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": command.expectedThreadVersion + 1,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                        "messageId": command.messageID.rawValue.uuidString,
                        "messageSequence": 1,
                    ],
                ],
                expectedVaultID: vaultID
            )
            currentSessionReceipt = receipt
            completion(.success(receipt))
        } catch {
            completion(.failure(error))
        }
    }

    func endOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewEndCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              let current = currentSessionReceipt,
              current.threadID == command.threadID,
              current.sessionID == command.sessionID,
              current.lifecycle == .active,
              current.boundary == .open,
              current.threadVersion == command.expectedThreadVersion,
              current.sessionVersion == command.expectedSessionVersion,
              sessionsWithNarrative.contains(command.sessionID.rawValue) else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            let receipt = try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": command.expectedThreadVersion + 1,
                        "sessionVersion": command.expectedSessionVersion + 2,
                        "state": OwnerTruthInterviewSessionLifecycle.ended.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )
            endedSessions.insert(command.sessionID.rawValue)
            lastEndedReceipt = receipt
            currentSessionReceipt = nil
            completion(.success(receipt))
        } catch {
            completion(.failure(error))
        }
    }

    func fetchOwnerTruthInterviewPendingReviewBatchInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewPendingReviewBatchInbox, Error>) -> Void
    ) {
        guard self.vaultID == vaultID, let receipt = lastEndedReceipt else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            completion(.success(try OwnerTruthInterviewPendingReviewBatchInbox(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewPendingReviewBatchInbox.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "reviewBatches": acknowledgedReviewBatch ? [] : [[
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "threadId": receipt.threadID.rawValue.uuidString,
                        "sessionId": receipt.sessionID.rawValue.uuidString,
                        "reviewBatchVersion": 1,
                        "sessionVersion": receipt.sessionVersion,
                        "trigger": OwnerTruthInterviewReviewBatchTrigger.sessionExit.rawValue,
                        "capturedCandidateBatchTurnCount": 1,
                    ]],
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func acknowledgeOwnerTruthInterviewReviewBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewReviewBatchAcknowledgementCommand,
        completion: @escaping (Result<OwnerTruthInterviewReviewBatchAcknowledgementReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              let receipt = lastEndedReceipt,
              command.reviewBatchID == reviewBatchID,
              command.threadID == receipt.threadID,
              command.sessionID == receipt.sessionID,
              command.expectedSessionVersion == receipt.sessionVersion,
              command.expectedReviewBatchVersion == 1 else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            let outcome: OwnerTruthInterviewReviewBatchAcknowledgementOutcome = acknowledgedReviewBatch
                ? .deduplicated
                : .acknowledged
            acknowledgedReviewBatch = true
            completion(.success(try OwnerTruthInterviewReviewBatchAcknowledgementReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewReviewBatchAcknowledgementReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "status": outcome.rawValue,
                    "session": [
                        "threadId": receipt.threadID.rawValue.uuidString,
                        "sessionId": receipt.sessionID.rawValue.uuidString,
                        "sessionVersion": receipt.sessionVersion + 1,
                    ],
                    "reviewBatch": [
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "trigger": OwnerTruthInterviewReviewBatchTrigger.sessionExit.rawValue,
                        "state": "acknowledged",
                        "capturedCandidateBatchTurnCount": 1,
                        "rowVersion": 2,
                    ],
                    "candidateProposal": ["status": "notStarted"],
                    "memoryActivation": ["status": "notApplicable"],
                ],
                expectedVaultID: vaultID,
                expectedReviewBatchID: reviewBatchID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func admitOwnerTruthInterviewCandidateProposal(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateProposalAdmissionCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalAdmissionReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              acknowledgedReviewBatch,
              command.reviewBatchID == reviewBatchID,
              command.expectedReviewBatchVersion == 2 else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            let outcome: OwnerTruthCommandOutcome = candidateProposalAdmitted ? .deduplicated : .created
            candidateProposalAdmitted = true
            completion(.success(try OwnerTruthInterviewCandidateProposalAdmissionReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateProposalAdmissionReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "status": outcome.rawValue,
                    "reviewBatch": [
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                    ],
                    "source": [
                        "status": "admitted",
                        "kind": "conversation",
                        "version": 1,
                    ],
                    "candidateExtraction": [
                        "status": "requested",
                        "ownerMessageCount": 1,
                    ],
                    "candidate": ["status": "notCreated"],
                    "memoryActivation": ["status": "notApplicable"],
                ],
                expectedVaultID: vaultID,
                expectedReviewBatchID: reviewBatchID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func fetchOwnerTruthInterviewCandidateProposalStatus(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalStatus, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              candidateProposalAdmitted,
              reviewBatchID == self.reviewBatchID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            candidateProposalStatusRequestCount += 1
            let extractionState: OwnerTruthInterviewCandidateProposalExtractionState
            switch candidateProposalReviewState {
            case .notReady:
                extractionState = .requested
            case .reviewReady, .noCandidates:
                extractionState = .succeeded
            case .extractionFailed:
                extractionState = .failed
            case .extractionQuarantined:
                extractionState = .quarantined
            }
            completion(.success(try OwnerTruthInterviewCandidateProposalStatus(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewCandidateProposalStatus.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "reviewBatch": [
                        "reviewBatchId": reviewBatchID.rawValue.uuidString,
                        "state": OwnerTruthInterviewCandidateProposalReviewBatchState.acknowledged.rawValue,
                    ],
                    "candidateProposal": [
                        "status": OwnerTruthInterviewCandidateProposalAdmissionState.admitted.rawValue,
                    ],
                    "source": [
                        "status": OwnerTruthInterviewCandidateProposalSourceState.admitted.rawValue,
                    ],
                    "candidateExtraction": [
                        "status": extractionState.rawValue,
                    ],
                    "effectExecution": [
                        "status": OwnerTruthInterviewCandidateProposalEffectState.disabled.rawValue,
                    ],
                    "candidateReview": [
                        "status": candidateProposalReviewState.rawValue,
                    ],
                ],
                expectedVaultID: vaultID,
                expectedReviewBatchID: reviewBatchID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    /// A local-only, content-free discovery fixture for the focused reviewReady
    /// handoff. The view under test receives two opaque batches and must show
    /// only the batch admitted by the current natural-input session.
    final class CandidateConfirmationInboxFixture: OwnerTruthInterviewCandidateConfirmationInboxClient {
        private let vaultID: OwnerTruthVaultID?
        private let focusedReviewBatchID: OwnerTruthRecordID
        private let otherReviewBatchID = OwnerTruthRecordID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000b8")!
        )
        private(set) var requestCount = 0

        init(vaultID: OwnerTruthVaultID?, focusedReviewBatchID: OwnerTruthRecordID) {
            self.vaultID = vaultID
            self.focusedReviewBatchID = focusedReviewBatchID
        }

        var otherReviewBatchIDForUIQA: OwnerTruthRecordID { otherReviewBatchID }

        func fetchOwnerTruthInterviewCandidateConfirmationInbox(
            vaultID: OwnerTruthVaultID,
            completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>) -> Void
        ) {
            guard self.vaultID == vaultID else {
                completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
                return
            }
            requestCount += 1
            do {
                completion(.success(try OwnerTruthInterviewCandidateConfirmationInbox(
                    backendJSONObject: [
                        "schemaVersion": OwnerTruthInterviewCandidateConfirmationInbox.schemaVersion,
                        "vaultId": vaultID.rawValue,
                        "confirmations": [
                            [
                                "reviewBatchId": focusedReviewBatchID.rawValue.uuidString,
                                "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                                "batchCandidateCount": 1,
                                "singleCandidateCount": 0,
                            ],
                            [
                                "reviewBatchId": otherReviewBatchID.rawValue.uuidString,
                                "readiness": OwnerTruthInterviewCandidateReviewReadiness.reviewReady.rawValue,
                                "batchCandidateCount": 1,
                                "singleCandidateCount": 1,
                            ],
                        ],
                    ],
                    expectedVaultID: vaultID
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setOwnerTruthInterviewBoundary(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewBoundaryCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        boundariesBySessionID[command.sessionID.rawValue] = command.boundary
        let lifecycle: OwnerTruthInterviewSessionLifecycle = command.boundary == .skipOnce
            ? .active
            : .paused
        do {
            completion(.success(try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": 1,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": lifecycle.rawValue,
                        "boundary": command.boundary.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func pauseOwnerTruthInterviewForTopicSwitch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPauseForTopicSwitchCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              let current = currentSessionReceipt,
              current.threadID == command.threadID,
              current.sessionID == command.sessionID,
              current.lifecycle == .active,
              current.threadVersion == command.expectedThreadVersion,
              current.sessionVersion == command.expectedSessionVersion else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            let receipt = try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": command.expectedThreadVersion + 1,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": OwnerTruthInterviewSessionLifecycle.paused.rawValue,
                        "boundary": current.boundary.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )
            boundariesBySessionID[command.sessionID.rawValue] = current.boundary
            currentSessionReceipt = nil
            lastTopicSwitchPauseReceipt = receipt
            completion(.success(receipt))
        } catch {
            completion(.failure(error))
        }
    }

    func recordOwnerTruthInterviewPacing(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPacingCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              let current = currentSessionReceipt,
              current.threadID == command.threadID,
              current.sessionID == command.sessionID,
              current.lifecycle == .active,
              current.boundary == .open,
              current.sessionVersion == command.expectedSessionVersion else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        if command.event == .summaryCompleted, pacingDeepeningTurnCount < 2 {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        switch command.event {
        case .deepeningCompleted:
            pacingDeepeningTurnCount += 1
        case .summaryCompleted:
            pacingDeepeningTurnCount = 0
        }
        pacingEvents.append(command.event)
        do {
            let receipt = try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": current.threadVersion,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )
            currentSessionReceipt = receipt
            completion(.success(receipt))
        } catch {
            completion(.failure(error))
        }
    }

    func restoreOwnerTruthInterviewDoNotAsk(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreDoNotAskCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        guard self.vaultID == vaultID,
              boundariesBySessionID[command.sessionID.rawValue] == .doNotAsk else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        boundariesBySessionID[command.sessionID.rawValue] = .open
        do {
            completion(.success(try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": 1,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func restoreOwnerTruthInterviewCooldown(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreCooldownCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    ) {
        // Server clock enforcement is covered by the deployed Postgres smoke.
        // This in-memory client only proves the QA control calls the typed
        // restore contract and returns to an active/open presentation.
        guard self.vaultID == vaultID,
              boundariesBySessionID[command.sessionID.rawValue] == .cooldown else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        boundariesBySessionID[command.sessionID.rawValue] = .open
        do {
            completion(.success(try OwnerTruthInterviewNaturalInputReceipt(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputReceipt.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "receipt": [
                        "status": OwnerTruthCommandOutcome.created.rawValue,
                        "threadId": command.threadID.rawValue.uuidString,
                        "sessionId": command.sessionID.rawValue.uuidString,
                        "threadVersion": 1,
                        "sessionVersion": command.expectedSessionVersion + 1,
                        "state": OwnerTruthInterviewSessionLifecycle.active.rawValue,
                        "boundary": OwnerTruthInterviewSessionBoundary.open.rawValue,
                    ],
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func fetchOwnerTruthInterviewNaturalInputContinuation(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputContinuation, Error>) -> Void
    ) {
        guard self.vaultID == vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        if endedSessions.contains(sessionID.rawValue) {
            do {
                completion(.success(try OwnerTruthInterviewNaturalInputContinuation(
                    backendJSONObject: [
                        "schemaVersion": OwnerTruthInterviewNaturalInputContinuation.schemaVersion,
                        "vaultId": vaultID.rawValue,
                        "presentation": [
                            "state": OwnerTruthInterviewNaturalInputContinuationState.reviewPending.rawValue,
                            "canContinue": false,
                            "canContinueLater": true,
                        ],
                    ],
                    expectedVaultID: vaultID
                )))
            } catch {
                completion(.failure(error))
            }
            return
        }
        let boundary = boundariesBySessionID[sessionID.rawValue] ?? .open
        let presentation: (
            state: OwnerTruthInterviewNaturalInputContinuationState,
            canContinue: Bool,
            canContinueLater: Bool
        )
        switch boundary {
        case .open, .skipOnce:
            presentation = sessionsWithNarrative.contains(sessionID.rawValue)
                ? (postNarrativeContinuationState, true, true)
                : (.readyForNarrative, true, true)
        case .cooldown:
            presentation = (.paused, false, true)
        case .doNotAsk:
            presentation = (.paused, false, false)
        }
        do {
            completion(.success(try OwnerTruthInterviewNaturalInputContinuation(
                backendJSONObject: [
                    "schemaVersion": OwnerTruthInterviewNaturalInputContinuation.schemaVersion,
                    "vaultId": vaultID.rawValue,
                    "presentation": [
                        "state": presentation.state.rawValue,
                        "canContinue": presentation.canContinue,
                        "canContinueLater": presentation.canContinueLater,
                    ],
                ],
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }
}

private enum InterviewNaturalInputUIQAClientError: Error {
    case invalidRequest
}

struct OwnerTruthKnowledgeRecommendationPlanUIQASmokeResult: Codable {
    static let fileName = "owner-truth-knowledge-recommendation-plan-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let selectionState: String?
    let selectedSlots: [String]
    let selectedCount: Int
    let filteredCount: Int
    let coverageDimensionCount: Int
    let candidateIdentifierExposed: Bool
    let singleRecommendationAccepted: Bool
    let emptyRecommendationAccepted: Bool
    let nonReadyPlanAccepted: Bool
    let malformedPlanRejected: Bool
    let useCasePhase: String?
    let useCaseSelectedCount: Int
    let useCaseCoverageDimensionCount: Int
    let useCaseOpaqueIdentifiersExposed: Bool
    let useCaseStaleCompletionRejected: Bool
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

/// This smoke has no product surface. It proves that the iOS client accepts
/// the server-planned, value-minimized M0-B response without retaining opaque
/// candidate or projection identifiers.
enum OwnerTruthKnowledgeRecommendationPlanUIQASmoke {
    static func run(accountLease: AccountLease) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            writeFailure("vaultUnavailable")
            return
        }
        let client = OwnerTruthKnowledgeRecommendationPlanUIQAClient(
            vaultID: vaultID
        )
        client.fetchOwnerTruthKnowledgeRecommendationPlan(vaultID: vaultID) { result in
            switch result {
            case .success(let plan):
                let variants = client.verifyContractVariants(vaultID: vaultID)
                let useCaseVariants = verifyUseCaseVariants(
                    accountLease: accountLease,
                    vaultID: vaultID
                )
                let slots = plan.selected.map(\.slot.rawValue)
                let expectedSlots: Set<OwnerTruthKnowledgeRecommendationSlot> = [.continuity, .breadth]
                let completed = OwnerTruthCandidateReviewQAGate.isEnabled
                    && plan.state == .ready
                    && plan.selected.count == 2
                    && Set(plan.selected.map(\.slot)) == expectedSlots
                    && plan.filteredCount == 1
                    && plan.coverage.count == OwnerTruthKnowledgeRecommendationDimension.allCases.count
                    && variants.singleRecommendationAccepted
                    && variants.emptyRecommendationAccepted
                    && variants.nonReadyPlanAccepted
                    && variants.malformedPlanRejected
                    && useCaseVariants.phase == .ready
                    && useCaseVariants.selectedCount == 2
                    && useCaseVariants.coverageDimensionCount
                        == OwnerTruthKnowledgeRecommendationDimension.allCases.count
                    && !useCaseVariants.opaqueIdentifiersExposed
                    && useCaseVariants.staleCompletionRejected
                write(
                    OwnerTruthKnowledgeRecommendationPlanUIQASmokeResult(
                        completed: completed,
                        qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                        selectionState: plan.state.rawValue,
                        selectedSlots: slots,
                        selectedCount: plan.selected.count,
                        filteredCount: plan.filteredCount,
                        coverageDimensionCount: plan.coverage.count,
                        candidateIdentifierExposed: false,
                        singleRecommendationAccepted: variants.singleRecommendationAccepted,
                        emptyRecommendationAccepted: variants.emptyRecommendationAccepted,
                        nonReadyPlanAccepted: variants.nonReadyPlanAccepted,
                        malformedPlanRejected: variants.malformedPlanRejected,
                        useCasePhase: useCaseVariants.phase.rawValue,
                        useCaseSelectedCount: useCaseVariants.selectedCount,
                        useCaseCoverageDimensionCount: useCaseVariants.coverageDimensionCount,
                        useCaseOpaqueIdentifiersExposed: useCaseVariants.opaqueIdentifiersExposed,
                        useCaseStaleCompletionRejected: useCaseVariants.staleCompletionRejected,
                        launchArguments: [
                            QALaunchScenario.ownerTruthKnowledgeRecommendationPlanSmoke.rawValue,
                            OwnerTruthCandidateReviewQAGate.launchArgument,
                        ],
                        failureReason: completed ? nil : "planInvariantMismatch"
                    )
                )
            case .failure:
                writeFailure("planParseFailed")
            }
        }
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthKnowledgeRecommendationPlanUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                selectionState: nil,
                selectedSlots: [],
                selectedCount: 0,
                filteredCount: 0,
                coverageDimensionCount: 0,
                candidateIdentifierExposed: false,
                singleRecommendationAccepted: false,
                emptyRecommendationAccepted: false,
                nonReadyPlanAccepted: false,
                malformedPlanRejected: false,
                useCasePhase: nil,
                useCaseSelectedCount: 0,
                useCaseCoverageDimensionCount: 0,
                useCaseOpaqueIdentifiersExposed: false,
                useCaseStaleCompletionRejected: false,
                launchArguments: [
                    QALaunchScenario.ownerTruthKnowledgeRecommendationPlanSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            )
        )
    }

    private static func write(_ result: OwnerTruthKnowledgeRecommendationPlanUIQASmokeResult) {
        do {
            let resultURL = try result.writeToDocuments()
            let status = result.completed ? "completed" : "failed"
            print("[UI_QA] OwnerTruthKnowledgeRecommendationPlanSmoke \(status) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthKnowledgeRecommendationPlanSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    private static func verifyUseCaseVariants(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID
    ) -> OwnerTruthKnowledgeRecommendationPlanUIQAUseCaseVariants {
        let client = OwnerTruthKnowledgeRecommendationPlanUIQAClient(vaultID: vaultID)
        let runtime = OwnerTruthKnowledgeRecommendationPlanUIQALeaseRuntime(
            accountLease: accountLease
        )
        let useCase = OwnerTruthKnowledgeRecommendationPlanUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true }
        )
        useCase.refresh()
        let reflectedState = String(reflecting: useCase.viewState)
        let opaqueIdentifiersExposed = [
            accountLease.vaultId,
            "candidate-continuity-opaque",
            "candidate-breadth-opaque",
            "continuity-template-opaque",
            "breadth-template-opaque",
            "memory-version-opaque",
            "qa-checkpoint-opaque",
        ].contains { reflectedState.contains($0) }

        let deferredClient = OwnerTruthKnowledgeRecommendationPlanDeferredUIQAClient(vaultID: vaultID)
        let staleRuntime = OwnerTruthKnowledgeRecommendationPlanUIQALeaseRuntime(
            accountLease: accountLease
        )
        let staleUseCase = OwnerTruthKnowledgeRecommendationPlanUseCase(
            accountLease: accountLease,
            client: deferredClient,
            accountLeaseRuntime: staleRuntime,
            qaGateEnabled: { true }
        )
        staleUseCase.refresh()
        staleRuntime.allowCommit = false
        deferredClient.resolve()
        let staleCompletionRejected = staleUseCase.viewState.phase == .unavailable
            && staleUseCase.viewState.notice == .staleAccountLease

        return OwnerTruthKnowledgeRecommendationPlanUIQAUseCaseVariants(
            phase: useCase.viewState.phase,
            selectedCount: useCase.viewState.recommendations.count,
            coverageDimensionCount: useCase.viewState.coverage.count,
            opaqueIdentifiersExposed: opaqueIdentifiersExposed,
            staleCompletionRejected: staleCompletionRejected
        )
    }
}

private final class OwnerTruthKnowledgeRecommendationPlanUIQAClient: OwnerTruthKnowledgeRecommendationPlanClient {
    private let vaultID: OwnerTruthVaultID

    init(vaultID: OwnerTruthVaultID) {
        self.vaultID = vaultID
    }

    func fetchOwnerTruthKnowledgeRecommendationPlan(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthKnowledgeRecommendationPlan, Error>) -> Void
    ) {
        guard vaultID == self.vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        do {
            completion(.success(try OwnerTruthKnowledgeRecommendationPlan(
                backendJSONObject: Self.fixture(vaultID: vaultID),
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func verifyContractVariants(
        vaultID: OwnerTruthVaultID
    ) -> OwnerTruthKnowledgeRecommendationPlanUIQAContractVariants {
        do {
            var singleResponse = Self.fixture(vaultID: vaultID)
            guard var singleRecommendations = singleResponse["recommendations"] as? [String: Any],
                  let selected = singleRecommendations["selected"] as? [[String: Any]],
                  selected.count == 2 else {
                return .failed
            }
            singleRecommendations["selected"] = [selected[1]]
            singleRecommendations["filtered"] = [] as [[String: Any]]
            singleResponse["recommendations"] = singleRecommendations
            let singlePlan = try OwnerTruthKnowledgeRecommendationPlan(
                backendJSONObject: singleResponse,
                expectedVaultID: vaultID
            )

            var emptyResponse = Self.fixture(vaultID: vaultID)
            guard var emptyRecommendations = emptyResponse["recommendations"] as? [String: Any] else {
                return .failed
            }
            emptyRecommendations["selected"] = [] as [[String: Any]]
            emptyRecommendations["filtered"] = [] as [[String: Any]]
            emptyResponse["recommendations"] = emptyRecommendations
            let emptyPlan = try OwnerTruthKnowledgeRecommendationPlan(
                backendJSONObject: emptyResponse,
                expectedVaultID: vaultID
            )

            var unavailableResponse = Self.fixture(vaultID: vaultID)
            guard var unavailableRecommendations = unavailableResponse["recommendations"] as? [String: Any],
                  var unavailableDimensionRead = unavailableRecommendations["dimensionRead"] as? [String: Any] else {
                return .failed
            }
            unavailableRecommendations["selectionState"] = OwnerTruthKnowledgeRecommendationPlanState.unavailable.rawValue
            unavailableRecommendations["selected"] = [] as [[String: Any]]
            unavailableRecommendations["filtered"] = [] as [[String: Any]]
            unavailableDimensionRead["state"] = OwnerTruthKnowledgeRecommendationPlanState.unavailable.rawValue
            unavailableDimensionRead.removeValue(forKey: "coverage")
            unavailableDimensionRead.removeValue(forKey: "includedMemoryVersionIds")
            unavailableDimensionRead.removeValue(forKey: "excluded")
            unavailableRecommendations["dimensionRead"] = unavailableDimensionRead
            unavailableResponse["recommendations"] = unavailableRecommendations
            let unavailablePlan = try OwnerTruthKnowledgeRecommendationPlan(
                backendJSONObject: unavailableResponse,
                expectedVaultID: vaultID
            )

            var malformedResponse = Self.fixture(vaultID: vaultID)
            guard var malformedRecommendations = malformedResponse["recommendations"] as? [String: Any] else {
                return .failed
            }
            malformedRecommendations["selected"] = [selected[0], selected[0]]
            malformedResponse["recommendations"] = malformedRecommendations
            let malformedRejected: Bool
            do {
                _ = try OwnerTruthKnowledgeRecommendationPlan(
                    backendJSONObject: malformedResponse,
                    expectedVaultID: vaultID
                )
                malformedRejected = false
            } catch {
                malformedRejected = true
            }

            return OwnerTruthKnowledgeRecommendationPlanUIQAContractVariants(
                singleRecommendationAccepted: singlePlan.selected.count == 1
                    && singlePlan.selected.first?.slot == .breadth,
                emptyRecommendationAccepted: emptyPlan.state == .ready && emptyPlan.selected.isEmpty,
                nonReadyPlanAccepted: unavailablePlan.state == .unavailable
                    && unavailablePlan.coverage.isEmpty
                    && unavailablePlan.selected.isEmpty,
                malformedPlanRejected: malformedRejected
            )
        } catch {
            return .failed
        }
    }

    static func fixture(vaultID: OwnerTruthVaultID) -> [String: Any] {
        let policyVersion = "knowledge-dimension-policy-v1"
        let dimensions: [[String: Any]] = [
            ["dimension": "lifeStage", "evidenceCount": 1, "coveredFacetCount": 1, "missingFacetCount": 1],
            ["dimension": "importantPeople", "evidenceCount": 1, "coveredFacetCount": 1, "missingFacetCount": 1],
            ["dimension": "keyDecisions", "evidenceCount": 0, "coveredFacetCount": 0, "missingFacetCount": 3],
            ["dimension": "professionalExperience", "evidenceCount": 0, "coveredFacetCount": 0, "missingFacetCount": 2],
            ["dimension": "values", "evidenceCount": 1, "coveredFacetCount": 1, "missingFacetCount": 1],
            ["dimension": "aspirationsAndBoundaries", "evidenceCount": 0, "coveredFacetCount": 0, "missingFacetCount": 2],
        ]
        return [
            "schemaVersion": OwnerTruthKnowledgeRecommendationPlan.schemaVersion,
            "vaultId": vaultID.rawValue,
            "recommendations": [
                "schemaVersion": OwnerTruthKnowledgeRecommendationPlan.recommendationSchemaVersion,
                "selectionState": OwnerTruthKnowledgeRecommendationPlanState.ready.rawValue,
                "dimensionReadSchemaVersion": OwnerTruthKnowledgeRecommendationPlan.dimensionReadSchemaVersion,
                "dimensionRead": [
                    "schemaVersion": OwnerTruthKnowledgeRecommendationPlan.dimensionReadSchemaVersion,
                    "state": OwnerTruthKnowledgeRecommendationPlanState.ready.rawValue,
                    "vaultId": vaultID.rawValue,
                    "authorityEpoch": 1,
                    // These opaque fields exercise the discard boundary. The
                    // parsed model keeps only count-only coverage below.
                    "checkpoint": "qa-checkpoint-opaque",
                    "includedMemoryVersionIds": ["memory-version-opaque"],
                    "excluded": [["memoryVersionId": "excluded-memory-opaque", "reasonCode": "superseded"]],
                    "coverage": [
                        "schemaVersion": OwnerTruthKnowledgeRecommendationPlan.dimensionProjectionSchemaVersion,
                        "policyVersion": policyVersion,
                        "excludedEvidenceCount": 1,
                        "dimensions": dimensions,
                    ],
                ],
                "selected": [
                    [
                        "candidateId": "candidate-continuity-opaque",
                        "evidenceRefCount": 1,
                        "missingFacet": "experience",
                        "policyVersion": policyVersion,
                        "questionTemplateId": "continuity-template-opaque",
                        "reasonCode": "activeThreadContinuation",
                        "slot": OwnerTruthKnowledgeRecommendationSlot.continuity.rawValue,
                        "targetDimension": OwnerTruthKnowledgeRecommendationDimension.lifeStage.rawValue,
                    ],
                    [
                        "candidateId": "candidate-breadth-opaque",
                        "evidenceRefCount": 1,
                        "missingFacet": "relationshipChange",
                        "policyVersion": policyVersion,
                        "questionTemplateId": "breadth-template-opaque",
                        "reasonCode": "missingDimensionFacet",
                        "slot": OwnerTruthKnowledgeRecommendationSlot.breadth.rawValue,
                        "targetDimension": OwnerTruthKnowledgeRecommendationDimension.importantPeople.rawValue,
                    ],
                ],
                "filtered": [[
                    "candidateId": "candidate-filtered-opaque",
                    "reasonCode": "sameFacetAlreadySelected",
                    "slot": OwnerTruthKnowledgeRecommendationSlot.breadth.rawValue,
                ]],
                "policyVersion": policyVersion,
                "selectionSchemaVersion": OwnerTruthKnowledgeRecommendationPlan.selectionSchemaVersion,
                "candidateSource": "serverPlanned",
                "plannerSchemaVersion": OwnerTruthKnowledgeRecommendationPlan.plannerSchemaVersion,
            ],
        ]
    }
}

private struct OwnerTruthKnowledgeRecommendationPlanUIQAContractVariants {
    let singleRecommendationAccepted: Bool
    let emptyRecommendationAccepted: Bool
    let nonReadyPlanAccepted: Bool
    let malformedPlanRejected: Bool

    static let failed = Self(
        singleRecommendationAccepted: false,
        emptyRecommendationAccepted: false,
        nonReadyPlanAccepted: false,
        malformedPlanRejected: false
    )
}

private final class OwnerTruthKnowledgeRecommendationPlanDeferredUIQAClient: OwnerTruthKnowledgeRecommendationPlanClient {
    private let vaultID: OwnerTruthVaultID
    private var pendingCompletion: ((Result<OwnerTruthKnowledgeRecommendationPlan, Error>) -> Void)?

    init(vaultID: OwnerTruthVaultID) {
        self.vaultID = vaultID
    }

    func fetchOwnerTruthKnowledgeRecommendationPlan(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthKnowledgeRecommendationPlan, Error>) -> Void
    ) {
        guard vaultID == self.vaultID, pendingCompletion == nil else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        pendingCompletion = completion
    }

    func resolve() {
        guard let completion = pendingCompletion else { return }
        pendingCompletion = nil
        do {
            completion(.success(try OwnerTruthKnowledgeRecommendationPlan(
                backendJSONObject: OwnerTruthKnowledgeRecommendationPlanUIQAClient.fixture(vaultID: vaultID),
                expectedVaultID: vaultID
            )))
        } catch {
            completion(.failure(error))
        }
    }
}

private final class OwnerTruthKnowledgeRecommendationPlanUIQALeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    private let accountLease: AccountLease
    var allowRequest = true
    var allowCommit = true

    init(accountLease: AccountLease) {
        self.accountLease = accountLease
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        subjectId == accountLease.subjectId ? accountLease : nil
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        let allowed = lease == accountLease && (checkpoint != .request || allowRequest)
            && (checkpoint != .commit || allowCommit)
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationMismatch,
            sessionRotated: !allowed
        )
    }
}

private struct OwnerTruthKnowledgeRecommendationPlanUIQAUseCaseVariants {
    let phase: OwnerTruthKnowledgeRecommendationPlanUseCasePhase
    let selectedCount: Int
    let coverageDimensionCount: Int
    let opaqueIdentifiersExposed: Bool
    let staleCompletionRejected: Bool
}

struct OwnerTruthKnowledgeDimensionConfirmationUIQASmokeResult: Codable {
    static let fileName = "owner-truth-knowledge-dimension-confirmation-uiqa-result.json"

    let completed: Bool
    let qaGateEnabled: Bool
    let createdOutcome: String?
    let replayOutcome: String?
    let confirmedDimension: String?
    let confirmedFacets: [String]
    let authorityEpoch: Int?
    let receiptRetainsOpaqueIdentifiers: Bool
    let boundHashMismatchRejected: Bool
    let malformedReceiptRejected: Bool
    let useCaseCreatedOutcome: String?
    let useCaseReplayOutcome: String?
    let stableRetryCommandID: Bool
    let unavailableActivationRejected: Bool
    let staleCompletionRejected: Bool
    let useCaseStateRetainsOpaqueIdentifiers: Bool
    let launchArguments: [String]
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

/// This has no product surface. It proves that a QA-only explicit Owner
/// dimension confirmation validates the current-memory binding, accepts an
/// idempotent replay, and drops opaque receipt identifiers before UI state.
enum OwnerTruthKnowledgeDimensionConfirmationUIQASmoke {
    static func run(accountLease: AccountLease) {
        guard let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            writeFailure("vaultUnavailable")
            return
        }
        do {
            let command = try OwnerTruthKnowledgeDimensionConfirmationCommand(
                commandID: "qa-dimension-confirm-001",
                memoryVersionID: OwnerTruthRecordID(
                    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
                ),
                expectedContentHash: String(repeating: "a", count: 64),
                dimension: .keyDecisions,
                coveredFacets: ["reason", "choice"]
            )
            let client = OwnerTruthKnowledgeDimensionConfirmationUIQAClient(vaultID: vaultID)
            client.confirmOwnerTruthKnowledgeDimension(vaultID: vaultID, command: command) { createdResult in
                switch createdResult {
                case .failure:
                    writeFailure("createdReceiptRejected")
                case .success(let createdReceipt):
                    client.confirmOwnerTruthKnowledgeDimension(vaultID: vaultID, command: command) { replayResult in
                        switch replayResult {
                        case .failure:
                            writeFailure("replayReceiptRejected")
                        case .success(let replayReceipt):
                            let variants = client.verifyContractVariants(
                                vaultID: vaultID,
                                command: command
                            )
                            let useCaseVariants = verifyUseCaseVariants(
                                accountLease: accountLease,
                                vaultID: vaultID
                            )
                            let completed = OwnerTruthCandidateReviewQAGate.isEnabled
                                && createdReceipt.outcome == .created
                                && replayReceipt.outcome == .deduplicated
                                && createdReceipt.dimension == .keyDecisions
                                && createdReceipt.coveredFacets == ["choice", "reason"]
                                && createdReceipt.authorityEpoch == 1
                                && !client.receiptRetainsOpaqueIdentifiers(createdReceipt, command: command)
                                && variants.boundHashMismatchRejected
                                && variants.malformedReceiptRejected
                                && useCaseVariants.createdOutcome == .created
                                && useCaseVariants.replayOutcome == .deduplicated
                                && useCaseVariants.stableRetryCommandID
                                && useCaseVariants.unavailableActivationRejected
                                && useCaseVariants.staleCompletionRejected
                                && !useCaseVariants.stateRetainsOpaqueIdentifiers
                            write(
                                OwnerTruthKnowledgeDimensionConfirmationUIQASmokeResult(
                                    completed: completed,
                                    qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                                    createdOutcome: createdReceipt.outcome.rawValue,
                                    replayOutcome: replayReceipt.outcome.rawValue,
                                    confirmedDimension: createdReceipt.dimension.rawValue,
                                    confirmedFacets: createdReceipt.coveredFacets,
                                    authorityEpoch: createdReceipt.authorityEpoch,
                                    receiptRetainsOpaqueIdentifiers: client.receiptRetainsOpaqueIdentifiers(
                                        createdReceipt,
                                        command: command
                                    ),
                                    boundHashMismatchRejected: variants.boundHashMismatchRejected,
                                    malformedReceiptRejected: variants.malformedReceiptRejected,
                                    useCaseCreatedOutcome: useCaseVariants.createdOutcome?.rawValue,
                                    useCaseReplayOutcome: useCaseVariants.replayOutcome?.rawValue,
                                    stableRetryCommandID: useCaseVariants.stableRetryCommandID,
                                    unavailableActivationRejected: useCaseVariants.unavailableActivationRejected,
                                    staleCompletionRejected: useCaseVariants.staleCompletionRejected,
                                    useCaseStateRetainsOpaqueIdentifiers: useCaseVariants.stateRetainsOpaqueIdentifiers,
                                    launchArguments: [
                                        QALaunchScenario.ownerTruthKnowledgeDimensionConfirmationSmoke.rawValue,
                                        OwnerTruthCandidateReviewQAGate.launchArgument,
                                    ],
                                    failureReason: completed ? nil : "confirmationInvariantMismatch"
                                )
                            )
                        }
                    }
                }
            }
        } catch {
            writeFailure("commandRejected")
        }
    }

    static func writeFailure(_ reason: String) {
        write(
            OwnerTruthKnowledgeDimensionConfirmationUIQASmokeResult(
                completed: false,
                qaGateEnabled: OwnerTruthCandidateReviewQAGate.isEnabled,
                createdOutcome: nil,
                replayOutcome: nil,
                confirmedDimension: nil,
                confirmedFacets: [],
                authorityEpoch: nil,
                receiptRetainsOpaqueIdentifiers: false,
                boundHashMismatchRejected: false,
                malformedReceiptRejected: false,
                useCaseCreatedOutcome: nil,
                useCaseReplayOutcome: nil,
                stableRetryCommandID: false,
                unavailableActivationRejected: false,
                staleCompletionRejected: false,
                useCaseStateRetainsOpaqueIdentifiers: false,
                launchArguments: [
                    QALaunchScenario.ownerTruthKnowledgeDimensionConfirmationSmoke.rawValue,
                    OwnerTruthCandidateReviewQAGate.launchArgument,
                ],
                failureReason: reason
            )
        )
    }

    private static func write(_ result: OwnerTruthKnowledgeDimensionConfirmationUIQASmokeResult) {
        do {
            let resultURL = try result.writeToDocuments()
            let status = result.completed ? "completed" : "failed"
            print("[UI_QA] OwnerTruthKnowledgeDimensionConfirmationSmoke \(status) result=\(resultURL.path)")
        } catch {
            print("[UI_QA] OwnerTruthKnowledgeDimensionConfirmationSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    private static func verifyUseCaseVariants(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID
    ) -> OwnerTruthKnowledgeDimensionConfirmationUIQAUseCaseVariants {
        let activation = OwnerTruthCandidateMemoryActivation(
            outcome: .created,
            memoryID: OwnerTruthRecordID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!),
            memoryVersionID: OwnerTruthRecordID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!),
            contentHash: String(repeating: "a", count: 64)
        )
        let client = OwnerTruthKnowledgeDimensionConfirmationUIQAClient(vaultID: vaultID)
        let runtime = OwnerTruthKnowledgeDimensionConfirmationUIQALeaseRuntime(
            accountLease: accountLease
        )
        let useCase = OwnerTruthKnowledgeDimensionConfirmationUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: runtime,
            qaGateEnabled: { true },
            commandIDFactory: { "owner-truth-dimension-qa-001" }
        )
        useCase.confirm(
            memoryActivation: activation,
            dimension: .keyDecisions,
            coveredFacets: ["reason", "choice"]
        )
        let createdOutcome = useCase.viewState.latestReceipt?.outcome
        useCase.confirm(
            memoryActivation: activation,
            dimension: .keyDecisions,
            coveredFacets: ["choice", "reason"]
        )
        let replayOutcome = useCase.viewState.latestReceipt?.outcome
        let stableRetryCommandID = client.receivedCommandIDs.count == 2
            && Set(client.receivedCommandIDs).count == 1

        let requestCountBeforeUnavailableActivation = client.receivedCommandIDs.count
        useCase.confirm(
            memoryActivation: OwnerTruthCandidateMemoryActivation(
                outcome: .notApplicable,
                memoryID: nil,
                memoryVersionID: nil,
                contentHash: nil
            ),
            dimension: .keyDecisions,
            coveredFacets: ["choice"]
        )
        let unavailableActivationRejected = useCase.viewState.phase == .failed
            && useCase.viewState.notice == .memoryActivationUnavailable
            && client.receivedCommandIDs.count == requestCountBeforeUnavailableActivation

        let deferredClient = OwnerTruthKnowledgeDimensionConfirmationDeferredUIQAClient(vaultID: vaultID)
        let staleRuntime = OwnerTruthKnowledgeDimensionConfirmationUIQALeaseRuntime(
            accountLease: accountLease
        )
        let staleUseCase = OwnerTruthKnowledgeDimensionConfirmationUseCase(
            accountLease: accountLease,
            client: deferredClient,
            accountLeaseRuntime: staleRuntime,
            qaGateEnabled: { true },
            commandIDFactory: { "owner-truth-dimension-qa-002" }
        )
        staleUseCase.confirm(
            memoryActivation: activation,
            dimension: .keyDecisions,
            coveredFacets: ["choice"]
        )
        staleRuntime.allowCommit = false
        deferredClient.resolve(outcome: .created)
        let staleCompletionRejected = staleUseCase.viewState.phase == .unavailable
            && staleUseCase.viewState.notice == .staleAccountLease

        let reflectedState = String(reflecting: useCase.viewState)
        let stateRetainsOpaqueIdentifiers = reflectedState.contains(activation.memoryVersionID!.rawValue.uuidString)
            || reflectedState.contains(activation.contentHash!)

        return OwnerTruthKnowledgeDimensionConfirmationUIQAUseCaseVariants(
            createdOutcome: createdOutcome,
            replayOutcome: replayOutcome,
            stableRetryCommandID: stableRetryCommandID,
            unavailableActivationRejected: unavailableActivationRejected,
            staleCompletionRejected: staleCompletionRejected,
            stateRetainsOpaqueIdentifiers: stateRetainsOpaqueIdentifiers
        )
    }
}

private final class OwnerTruthKnowledgeDimensionConfirmationUIQAClient: OwnerTruthKnowledgeDimensionConfirmationClient {
    private let vaultID: OwnerTruthVaultID
    private var completedCommandIDs: Set<String> = []
    private(set) var receivedCommandIDs: [String] = []

    init(vaultID: OwnerTruthVaultID) {
        self.vaultID = vaultID
    }

    func confirmOwnerTruthKnowledgeDimension(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthKnowledgeDimensionConfirmationCommand,
        completion: @escaping (Result<OwnerTruthKnowledgeDimensionConfirmationReceipt, Error>) -> Void
    ) {
        guard vaultID == self.vaultID else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        receivedCommandIDs.append(command.commandID)
        let outcome: OwnerTruthKnowledgeDimensionConfirmationOutcome = completedCommandIDs.insert(command.commandID)
            .inserted ? .created : .deduplicated
        do {
            completion(.success(try OwnerTruthKnowledgeDimensionConfirmationReceipt(
                backendJSONObject: Self.fixture(command: command, outcome: outcome),
                expectedCommand: command
            )))
        } catch {
            completion(.failure(error))
        }
    }

    func verifyContractVariants(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthKnowledgeDimensionConfirmationCommand
    ) -> OwnerTruthKnowledgeDimensionConfirmationUIQAContractVariants {
        guard vaultID == self.vaultID else { return .failed }
        var hashMismatch = Self.fixture(command: command, outcome: .created)
        guard var hashMismatchConfirmation = hashMismatch["confirmation"] as? [String: Any] else {
            return .failed
        }
        hashMismatchConfirmation["boundContentHash"] = String(repeating: "b", count: 64)
        hashMismatch["confirmation"] = hashMismatchConfirmation
        let boundHashMismatchRejected: Bool
        do {
            _ = try OwnerTruthKnowledgeDimensionConfirmationReceipt(
                backendJSONObject: hashMismatch,
                expectedCommand: command
            )
            boundHashMismatchRejected = false
        } catch {
            boundHashMismatchRejected = true
        }

        var malformedReceipt = Self.fixture(command: command, outcome: .created)
        guard var malformedConfirmation = malformedReceipt["confirmation"] as? [String: Any] else {
            return .failed
        }
        malformedConfirmation["coveredFacets"] = ["choice", "choice"]
        malformedReceipt["confirmation"] = malformedConfirmation
        let malformedReceiptRejected: Bool
        do {
            _ = try OwnerTruthKnowledgeDimensionConfirmationReceipt(
                backendJSONObject: malformedReceipt,
                expectedCommand: command
            )
            malformedReceiptRejected = false
        } catch {
            malformedReceiptRejected = true
        }

        return OwnerTruthKnowledgeDimensionConfirmationUIQAContractVariants(
            boundHashMismatchRejected: boundHashMismatchRejected,
            malformedReceiptRejected: malformedReceiptRejected
        )
    }

    func receiptRetainsOpaqueIdentifiers(
        _ receipt: OwnerTruthKnowledgeDimensionConfirmationReceipt,
        command: OwnerTruthKnowledgeDimensionConfirmationCommand
    ) -> Bool {
        let reflected = String(reflecting: receipt)
        return reflected.contains(command.memoryVersionID.rawValue.uuidString)
            || reflected.contains(command.expectedContentHash)
            || reflected.contains("00000000-0000-0000-0000-000000000402")
    }

    static func fixture(
        command: OwnerTruthKnowledgeDimensionConfirmationCommand,
        outcome: OwnerTruthKnowledgeDimensionConfirmationOutcome
    ) -> [String: Any] {
        [
            "schemaVersion": OwnerTruthKnowledgeDimensionConfirmationReceipt.responseSchemaVersion,
            "status": outcome.rawValue,
            "confirmation": [
                "schemaVersion": OwnerTruthKnowledgeDimensionConfirmationReceipt.confirmationSchemaVersion,
                "status": outcome.rawValue,
                "confirmationId": "00000000-0000-0000-0000-000000000402",
                "memoryId": "00000000-0000-0000-0000-000000000403",
                "memoryVersionId": command.memoryVersionID.rawValue.uuidString,
                "boundContentHash": command.expectedContentHash,
                "dimension": command.dimension.rawValue,
                "coveredFacets": command.coveredFacets,
                "authorityEpoch": 1,
            ],
        ]
    }
}

private final class OwnerTruthKnowledgeDimensionConfirmationDeferredUIQAClient: OwnerTruthKnowledgeDimensionConfirmationClient {
    private let vaultID: OwnerTruthVaultID
    private var pendingCommand: OwnerTruthKnowledgeDimensionConfirmationCommand?
    private var pendingCompletion: ((Result<OwnerTruthKnowledgeDimensionConfirmationReceipt, Error>) -> Void)?

    init(vaultID: OwnerTruthVaultID) {
        self.vaultID = vaultID
    }

    func confirmOwnerTruthKnowledgeDimension(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthKnowledgeDimensionConfirmationCommand,
        completion: @escaping (Result<OwnerTruthKnowledgeDimensionConfirmationReceipt, Error>) -> Void
    ) {
        guard vaultID == self.vaultID, pendingCompletion == nil else {
            completion(.failure(InterviewNaturalInputUIQAClientError.invalidRequest))
            return
        }
        pendingCommand = command
        pendingCompletion = completion
    }

    func resolve(outcome: OwnerTruthKnowledgeDimensionConfirmationOutcome) {
        guard let command = pendingCommand,
              let completion = pendingCompletion else {
            return
        }
        pendingCommand = nil
        pendingCompletion = nil
        do {
            completion(.success(try OwnerTruthKnowledgeDimensionConfirmationReceipt(
                backendJSONObject: OwnerTruthKnowledgeDimensionConfirmationUIQAClient.fixture(
                    command: command,
                    outcome: outcome
                ),
                expectedCommand: command
            )))
        } catch {
            completion(.failure(error))
        }
    }
}

private final class OwnerTruthKnowledgeDimensionConfirmationUIQALeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    private let accountLease: AccountLease
    var allowRequest = true
    var allowCommit = true

    init(accountLease: AccountLease) {
        self.accountLease = accountLease
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        subjectId == accountLease.subjectId ? accountLease : nil
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        let allowed = lease == accountLease && (checkpoint != .request || allowRequest)
            && (checkpoint != .commit || allowCommit)
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationMismatch,
            sessionRotated: !allowed
        )
    }
}

private struct OwnerTruthKnowledgeDimensionConfirmationUIQAContractVariants {
    let boundHashMismatchRejected: Bool
    let malformedReceiptRejected: Bool

    static let failed = Self(
        boundHashMismatchRejected: false,
        malformedReceiptRejected: false
    )
}

private struct OwnerTruthKnowledgeDimensionConfirmationUIQAUseCaseVariants {
    let createdOutcome: OwnerTruthKnowledgeDimensionConfirmationOutcome?
    let replayOutcome: OwnerTruthKnowledgeDimensionConfirmationOutcome?
    let stableRetryCommandID: Bool
    let unavailableActivationRejected: Bool
    let staleCompletionRejected: Bool
    let stateRetainsOpaqueIdentifiers: Bool
}

#endif
