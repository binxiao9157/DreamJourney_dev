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
    static let bookCoverCornerRadius: CGFloat = 22
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
    private var messages: [InAppMessage]
    private let onOpenMessage: (InAppMessage) -> Void
    private let onShowAllTimeLetters: () -> Void
    private let onMessageStateChanged: () -> Void

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
        onOpenMessage: @escaping (InAppMessage) -> Void,
        onShowAllTimeLetters: @escaping () -> Void,
        onMessageStateChanged: @escaping () -> Void
    ) {
        self.repository = repository
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

    private func refreshMessagesFromRepository() {
        messages = repository.inAppMessageCenterSnapshot().messages
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
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
        onShowAllTimeLetters()
    }

    @objc private func archiveReadRemindersTapped() {
        let readMessages = messages.filter { !$0.isArchived && !$0.isUnread }
        guard !readMessages.isEmpty else {
            showToast("暂无已读消息可归档", type: .info)
            return
        }
        readMessages.forEach(archiveMessage)
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

    private func replaceLocalMessage(_ message: InAppMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.insert(message, at: 0)
        }
        messages = InAppMessageCenterSnapshot.sortedMessages(messages)
        tableView.reloadData()
        updateEmptyState()
        onMessageStateChanged()
    }

    private func archiveMessage(_ message: InAppMessage) {
        let archivedMessage = message.markingArchived(archivedAt: ISO8601DateFormatter().string(from: Date()))
        replaceLocalMessage(archivedMessage)
        repository.archiveInAppMessage(message) { [weak self] result in
            switch result {
            case .success(let updated):
                DispatchQueue.main.async {
                    self?.replaceLocalMessage(updated)
                }
            case .failure:
                DispatchQueue.main.async {
                    self?.showToast("归档同步失败，本地已收起", type: .info)
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
        let message = message(at: indexPath)
        let readMessage = message.markingRead(readAt: ISO8601DateFormatter().string(from: Date()))
        replaceLocalMessage(readMessage)
        onOpenMessage(message)
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
            self?.archiveMessage(message)
            completion(true)
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

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()
    private let featureCardsStack = UIStackView()
    private let listStack = UIStackView()
    private let archiveFilterButton = UIButton(type: .system)

    private weak var headerTitleLabel: UILabel?
    private weak var headerSubtitleLabel: UILabel?
    private weak var bookEntryControl: UIControl?
    private weak var bookEntryModeLabel: UILabel?
    private weak var bookEntryTitleLabel: UILabel?
    private weak var bookEntrySubtitleLabel: UILabel?
    private weak var bookEntryMetaLabel: UILabel?
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
    private var isRefreshingFromBackend = false
    private var isRefreshingTimeLetterMailbox = false
    private var activeKindFilter: ArchiveKindFilter?

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
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if isUIQAArchiveHiddenBranchesEnabled {
            return true
        }
        #endif
        return FeatureFlagService.shared.isEnabled(.personaSettings)
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
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
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
        configureArchiveFilterButton()
        let bookEntry = makeBookEntryCard()
        let materialsHeader = makeMaterialsHeader()
        let primaryCTA = makePrimaryCTA()
        mainStack.addArrangedSubview(header)
        mainStack.addArrangedSubview(featureCardsStack)
        mainStack.addArrangedSubview(analysisPrivacyDisclaimerLabel)
        mainStack.addArrangedSubview(remoteSyncCaptionLabel)
        mainStack.addArrangedSubview(timeLetterReminderButton)
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
        updateArchiveFilterButton()
        reloadArchiveList()
    }

    private func updateAutobiographyPageCopy() {
        let isSelfMode = isSelfAutobiographyMode
        let summary = repository.summary()
        let bookTitle = isSelfMode ? "我的自传" : "\(archivePersonaName)的故事"
        let estimatedPages = max(1, summary.total + 1)
        view.backgroundColor = DJDesignTokens.Color.background
        scrollView.backgroundColor = DJDesignTokens.Color.background

        headerTitleLabel?.text = "记忆档案"
        headerSubtitleLabel?.text = isSelfMode
            ? "上方进入完整自传，下方管理你记录的记忆素材。"
            : "上方翻阅 \(archivePersonaName) 的故事，下方查看已沉淀的素材。"

        bookEntryModeLabel?.text = isSelfMode ? "AUTOBIOGRAPHY" : "FAMILY STORY"
        bookEntryTitleLabel?.text = bookTitle
        bookEntrySubtitleLabel?.text = isSelfMode
            ? "一本合上的生命书，点击后翻开阅读。"
            : "一本合上的故事书，点击后翻开阅读。"
        bookEntryMetaLabel?.text = "3 章 · \(estimatedPages) 页 · \(summary.total) 段素材"
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
        guard FeatureFlagService.shared.isEnabled(.archiveRemoteFetch),
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

        let snapshot = currentInAppMessageCenterSnapshot()
        let reminderCount = repository.timeLetterReminderCount()
        guard let title = snapshot.entryButtonTitle(timeLetterReminderCount: reminderCount) else {
            timeLetterReminderButton.setTitle(nil, for: .normal)
            timeLetterReminderButton.accessibilityLabel = nil
            timeLetterReminderButton.isHidden = true
            return
        }

        timeLetterReminderButton.setTitle(title, for: .normal)
        timeLetterReminderButton.accessibilityLabel = title
        timeLetterReminderButton.isHidden = false
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

        let bookShadow = UIView()
        bookShadow.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        bookShadow.layer.cornerRadius = 22

        let pageBlock = UIView()
        pageBlock.backgroundColor = UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1)
        pageBlock.layer.cornerRadius = ArchiveLayout.bookCoverCornerRadius
        pageBlock.layer.borderWidth = 1
        pageBlock.layer.borderColor = UIColor(red: 0.64, green: 0.52, blue: 0.36, alpha: 0.32).cgColor

        let rightPageEdge = UIView()
        rightPageEdge.backgroundColor = UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1)
        rightPageEdge.layer.cornerRadius = 10
        rightPageEdge.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        rightPageEdge.clipsToBounds = true

        let pageEdgeLines = UIStackView()
        pageEdgeLines.axis = .vertical
        pageEdgeLines.distribution = .fillEqually
        pageEdgeLines.spacing = 5
        (0..<12).forEach { index in
            let line = UIView()
            line.backgroundColor = UIColor(red: 0.58, green: 0.46, blue: 0.30, alpha: index % 2 == 0 ? 0.18 : 0.10)
            pageEdgeLines.addArrangedSubview(line)
            line.translatesAutoresizingMaskIntoConstraints = false
            line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        }

        let cover = UIView()
        cover.backgroundColor = UIColor(red: 0.34, green: 0.16, blue: 0.10, alpha: 1)
        cover.layer.cornerRadius = ArchiveLayout.bookCoverCornerRadius
        cover.layer.borderWidth = 1
        cover.layer.borderColor = UIColor(red: 0.91, green: 0.70, blue: 0.40, alpha: 0.34).cgColor
        cover.clipsToBounds = true

        let spine = UIView()
        spine.backgroundColor = UIColor(red: 0.22, green: 0.10, blue: 0.07, alpha: 1)

        let spineRuleTop = UIView()
        spineRuleTop.backgroundColor = UIColor(red: 0.92, green: 0.70, blue: 0.38, alpha: 0.45)
        let spineRuleBottom = UIView()
        spineRuleBottom.backgroundColor = UIColor(red: 0.92, green: 0.70, blue: 0.38, alpha: 0.32)

        let innerFrame = UIView()
        innerFrame.layer.cornerRadius = 17
        innerFrame.layer.borderWidth = 1
        innerFrame.layer.borderColor = UIColor(red: 0.96, green: 0.78, blue: 0.46, alpha: 0.35).cgColor
        innerFrame.isUserInteractionEnabled = false

        let coverRuleTop = UIView()
        coverRuleTop.backgroundColor = UIColor(red: 0.96, green: 0.78, blue: 0.46, alpha: 0.48)
        let coverRuleBottom = UIView()
        coverRuleBottom.backgroundColor = UIColor(red: 0.96, green: 0.78, blue: 0.46, alpha: 0.36)

        let modeLabel = PaddingLabel(horizontalInset: 10, verticalInset: 5)
        modeLabel.text = isSelfAutobiographyMode ? "AUTOBIOGRAPHY" : "FAMILY STORY"
        modeLabel.font = DJDesignTokens.Font.label(10)
        modeLabel.textColor = UIColor(red: 0.97, green: 0.78, blue: 0.44, alpha: 0.92)
        modeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        modeLabel.layer.cornerRadius = 11
        modeLabel.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = isSelfAutobiographyMode ? "我的自传" : "\(archivePersonaName)的故事"
        titleLabel.font = DJDesignTokens.Font.display(31)
        titleLabel.textColor = UIColor(red: 1.0, green: 0.82, blue: 0.50, alpha: 1)
        titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.24)
        titleLabel.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.76

        let subtitleLabel = UILabel()
        subtitleLabel.text = isSelfAutobiographyMode
            ? "一本合上的生命书，点击后翻开阅读。"
            : "一本合上的故事书，点击后翻开阅读。"
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        subtitleLabel.numberOfLines = 2

        let metaLabel = UILabel()
        metaLabel.text = "3 章 · 1 页 · 0 段素材"
        metaLabel.font = DJDesignTokens.Font.label(12)
        metaLabel.textColor = UIColor(red: 0.96, green: 0.80, blue: 0.50, alpha: 0.78)
        metaLabel.numberOfLines = 1

        let enterLabel = UILabel()
        enterLabel.text = "翻开"
        enterLabel.font = DJDesignTokens.Font.label(13)
        enterLabel.textColor = UIColor(red: 1.0, green: 0.86, blue: 0.56, alpha: 1)

        let enterIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
        enterIcon.tintColor = UIColor(red: 1.0, green: 0.86, blue: 0.56, alpha: 1)
        enterIcon.contentMode = .scaleAspectFit

        let enterRow = UIStackView(arrangedSubviews: [enterLabel, enterIcon])
        enterRow.alignment = .center
        enterRow.spacing = 6

        let textStack = UIStackView(arrangedSubviews: [
            modeLabel,
            titleLabel,
            coverRuleTop,
            subtitleLabel,
            metaLabel,
            enterRow,
            coverRuleBottom,
        ])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = 9
        textStack.isUserInteractionEnabled = false

        [
            bookShadow,
            pageBlock,
            rightPageEdge,
            pageEdgeLines,
            cover,
            spine,
            spineRuleTop,
            spineRuleBottom,
            innerFrame,
            coverRuleTop,
            coverRuleBottom,
            modeLabel,
            titleLabel,
            subtitleLabel,
            metaLabel,
            enterRow,
            enterLabel,
            enterIcon,
        ].forEach { $0.isUserInteractionEnabled = false }

        rightPageEdge.addSubview(pageEdgeLines)
        control.addSubview(bookShadow)
        control.addSubview(pageBlock)
        pageBlock.addSubview(rightPageEdge)
        control.addSubview(cover)
        cover.addSubview(spine)
        cover.addSubview(innerFrame)
        spine.addSubview(spineRuleTop)
        spine.addSubview(spineRuleBottom)
        cover.addSubview(textStack)

        [
            bookShadow,
            pageBlock,
            rightPageEdge,
            pageEdgeLines,
            cover,
            spine,
            spineRuleTop,
            spineRuleBottom,
            innerFrame,
            textStack,
            modeLabel,
            titleLabel,
            coverRuleTop,
            subtitleLabel,
            metaLabel,
            enterRow,
            enterLabel,
            enterIcon,
            coverRuleBottom,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: 224),

            bookShadow.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 36),
            bookShadow.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -24),
            bookShadow.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -10),
            bookShadow.heightAnchor.constraint(equalToConstant: 24),

            pageBlock.topAnchor.constraint(equalTo: control.topAnchor, constant: 24),
            pageBlock.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 30),
            pageBlock.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -20),
            pageBlock.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -18),

            rightPageEdge.topAnchor.constraint(equalTo: pageBlock.topAnchor, constant: 10),
            rightPageEdge.trailingAnchor.constraint(equalTo: pageBlock.trailingAnchor, constant: -4),
            rightPageEdge.bottomAnchor.constraint(equalTo: pageBlock.bottomAnchor, constant: -9),
            rightPageEdge.widthAnchor.constraint(equalToConstant: 26),

            pageEdgeLines.topAnchor.constraint(equalTo: rightPageEdge.topAnchor, constant: 12),
            pageEdgeLines.leadingAnchor.constraint(equalTo: rightPageEdge.leadingAnchor, constant: 4),
            pageEdgeLines.trailingAnchor.constraint(equalTo: rightPageEdge.trailingAnchor, constant: -4),
            pageEdgeLines.bottomAnchor.constraint(equalTo: rightPageEdge.bottomAnchor, constant: -12),

            cover.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
            cover.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
            cover.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -34),
            cover.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -28),

            spine.topAnchor.constraint(equalTo: cover.topAnchor),
            spine.leadingAnchor.constraint(equalTo: cover.leadingAnchor),
            spine.bottomAnchor.constraint(equalTo: cover.bottomAnchor),
            spine.widthAnchor.constraint(equalToConstant: 48),

            spineRuleTop.leadingAnchor.constraint(equalTo: spine.leadingAnchor, constant: 12),
            spineRuleTop.trailingAnchor.constraint(equalTo: spine.trailingAnchor, constant: -12),
            spineRuleTop.topAnchor.constraint(equalTo: spine.topAnchor, constant: 28),
            spineRuleTop.heightAnchor.constraint(equalToConstant: 1),

            spineRuleBottom.leadingAnchor.constraint(equalTo: spine.leadingAnchor, constant: 12),
            spineRuleBottom.trailingAnchor.constraint(equalTo: spine.trailingAnchor, constant: -12),
            spineRuleBottom.bottomAnchor.constraint(equalTo: spine.bottomAnchor, constant: -28),
            spineRuleBottom.heightAnchor.constraint(equalToConstant: 1),

            innerFrame.topAnchor.constraint(equalTo: cover.topAnchor, constant: 18),
            innerFrame.leadingAnchor.constraint(equalTo: spine.trailingAnchor, constant: 16),
            innerFrame.trailingAnchor.constraint(equalTo: cover.trailingAnchor, constant: -18),
            innerFrame.bottomAnchor.constraint(equalTo: cover.bottomAnchor, constant: -18),

            textStack.leadingAnchor.constraint(equalTo: innerFrame.leadingAnchor, constant: 18),
            textStack.trailingAnchor.constraint(equalTo: innerFrame.trailingAnchor, constant: -18),
            textStack.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: innerFrame.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: innerFrame.bottomAnchor, constant: -14),

            coverRuleTop.widthAnchor.constraint(equalToConstant: 84),
            coverRuleTop.heightAnchor.constraint(equalToConstant: 1),
            coverRuleBottom.widthAnchor.constraint(equalToConstant: 54),
            coverRuleBottom.heightAnchor.constraint(equalToConstant: 1),
            enterIcon.widthAnchor.constraint(equalToConstant: 13),
            enterIcon.heightAnchor.constraint(equalToConstant: 13),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = isSelfAutobiographyMode ? "我的自传，点击进入完整书本" : "\(archivePersonaName)的故事，点击进入完整书本"
        bookEntryControl = control
        bookEntryModeLabel = modeLabel
        bookEntryTitleLabel = titleLabel
        bookEntrySubtitleLabel = subtitleLabel
        bookEntryMetaLabel = metaLabel
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

        tiles.append(makeFeatureTile(
            iconName: "waveform",
            title: "语音档案",
            detail: "\(summary.audio) 段声音",
            isLarge: false,
            action: #selector(audioCardTapped)
        ))

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
        guard FeatureFlagService.shared.isEnabled(.personaSettings) else {
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
        let snapshot = currentInAppMessageCenterSnapshot()
        guard !snapshot.messages.isEmpty else {
            applyArchiveKindFilter(.timeLetter)
            return
        }
        presentInAppMessageCenter(snapshot)
    }

    private func currentInAppMessageCenterSnapshot() -> InAppMessageCenterSnapshot {
        repository.inAppMessageCenterSnapshot(
            familyInvitationSources: FamilyRepository.shared.getAll().map { $0 as FamilyInvitationMessageSource },
            careSignalSources: currentCareSignalMessageSources()
        )
    }

    private func currentCareSignalMessageSources() -> [CareSignalMessageSource] {
        let contextOwnerId = DigitalHumanContextStore.shared.current.ownerId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = contextOwnerId.isEmpty ? UserManager.shared.currentUser?.id : contextOwnerId
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

    private func presentInAppMessageCenter(_ snapshot: InAppMessageCenterSnapshot) {
        let center = InAppMessageCenterViewController(
            snapshot: snapshot,
            repository: repository,
            onOpenMessage: { [weak self] message in
                self?.openInAppMessage(message)
            },
            onShowAllTimeLetters: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
                self?.applyArchiveKindFilter(.timeLetter)
            },
            onMessageStateChanged: { [weak self] in
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

    private func openInAppMessage(_ message: InAppMessage) {
        switch message.kind {
        case .timeLetter:
            guard let reminder = repository.timeLetterMailboxReminder(for: message) else {
                showToast("时间信件暂不可打开", type: .error)
                return
            }
            openTimeLetterReminder(reminder)
        case .familyInvitation:
            openFamilyInvitationMessage(message)
        case .careSignal:
            openCareSignalMessage(message)
        case .systemNotice:
            showToast("系统通知会在后续接入消息中心", type: .info)
        }
    }

    private func openFamilyInvitationMessage(_ message: InAppMessage) {
        repository.markInAppMessageRead(message) { [weak self] _ in
            self?.refreshContent()
        }
        if let familyMemberId = message.familyMemberId,
           let member = FamilyRepository.shared.get(by: familyMemberId) {
            let detailViewController = FamilyMemberDetailViewController(member: member)
            navigationController?.pushViewController(detailViewController, animated: true)
            return
        }
        navigationController?.pushViewController(FamilyCircleViewController(), animated: true)
    }

    private func openCareSignalMessage(_ message: InAppMessage) {
        repository.markInAppMessageRead(message) { [weak self] _ in
            self?.refreshContent()
        }
        guard let tabBarController else {
            navigationController?.pushViewController(ProfileViewController(), animated: true)
            return
        }
        tabBarController.selectedIndex = min(2, (tabBarController.viewControllers?.count ?? 1) - 1)
    }

    private func openTimeLetterReminder(_ reminder: TimeLetterMailboxReminder) {
        showToast("正在打开时间信件", type: .info)
        repository.resolveTimeLetterReminderDetail(reminder) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let item):
                repository.markTimeLetterMailboxReminderRead(reminder) { [weak self] _ in
                    self?.refreshContent()
                }
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
        guard isTimeLetterCreationEnabled else { return }
        let currentUser = UserManager.shared.currentUser
        let viewController = MapFootprintViewController(
            viewMode: .host,
            ownerId: currentUser?.id ?? "user_001",
            ownerName: currentUser?.nickname
        )
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func presentTextEntry(kind: MemoryArchiveItemKind) {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        let isTimeLetter = kind == .timeLetter
        let entryViewController = MemoryArchiveTextEntryViewController(kind: kind)
        if isTimeLetter {
            entryViewController.onSaveTimeLetter = { [weak self] payload in
                guard let self else { return }
                let item = MemoryArchiveItemFactory.makeTimeLetter(
                    note: payload.note,
                    openAt: payload.openAt,
                    recipients: payload.recipients,
                    imageLocalPath: payload.imageLocalPath
                )
                self.repository.add(item)
                self.refreshContent()
                self.showToast("时间信件已封存", type: .success)
            }
            entryViewController.onSaveDraftTimeLetter = { [weak self] payload in
                guard let self else { return }
                let item = MemoryArchiveItemFactory.makeTimeLetterDraft(
                    note: payload.note,
                    openAt: payload.openAt,
                    recipients: payload.recipients,
                    imageLocalPath: payload.imageLocalPath
                )
                self.repository.add(item)
                self.refreshContent()
                self.showToast("时间信件草稿已保存", type: .success)
            }
        } else {
            entryViewController.onSave = { [weak self] rawText in
                guard let self else { return }
                let item = MemoryArchiveItemFactory.makeTextItem(note: rawText)
                self.repository.add(item)
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

        let entryViewController = MemoryArchiveAudioRecorderViewController()
        entryViewController.onSave = { [weak self] fileURL, duration, note in
            guard let self else { return }
            let item = MemoryArchiveItemFactory.makeAudioItem(
                localPath: fileURL.path,
                duration: duration,
                note: note
            )
            self.repository.add(item)
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

        let entryViewController = MemoryArchiveVideoEntryViewController()
        entryViewController.onCreateMockVideoArchive = { [weak self] in
            guard let self else { return }
            do {
                let item = try self.makeHiddenQAMockVideoArchiveItem()
                self.repository.add(item)
                self.refreshContent()
                self.showToast("测试视频档案已生成", type: .success)
            } catch {
                self.showToast("测试视频档案生成失败", type: .error)
            }
        }
        present(entryViewController, animated: true)
    }

    private func makeHiddenQAMockVideoArchiveItem() throws -> MemoryArchiveItem {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let videoDirectoryURL = documentsURL.appendingPathComponent("archive-video", isDirectory: true)
        let thumbnailDirectoryURL = documentsURL.appendingPathComponent("archive-video-thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: videoDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)

        let identifier = UUID().uuidString
        let videoURL = videoDirectoryURL.appendingPathComponent("hidden-qa-\(identifier).mov")
        let thumbnailURL = thumbnailDirectoryURL.appendingPathComponent("hidden-qa-\(identifier).jpg")
        let mockVideoData = Data("DreamJourney hidden QA mock video placeholder".utf8)
        try mockVideoData.write(to: videoURL, options: [.atomic])

        let thumbnailImage = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 96)).image { context in
            DJDesignTokens.Color.surfaceContainer.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 96))
            DJDesignTokens.Color.accentDeep.setFill()
            context.fill(CGRect(x: 56, y: 28, width: 48, height: 40))
        }
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.72) else {
            throw NSError(
                domain: "DreamJourney.Archive.VideoShell",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode mock thumbnail"]
            )
        }
        try thumbnailData.write(to: thumbnailURL, options: [.atomic])

        return MemoryArchiveItemFactory.makeVideoItem(
            localPath: videoURL.path,
            thumbnailPath: thumbnailURL.path,
            fileSizeBytes: Int64(mockVideoData.count),
            note: "隐藏 QA 生成的 mock 视频档案。"
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

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func saveImageToArchive(_ image: UIImage) throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw ArchiveImageSaveError.jpegEncodingFailed
        }

        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-images", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func imageBase64ForArchiveAnalysis(_ image: UIImage) -> String? {
        image.jpegData(compressionQuality: 0.72)?.base64EncodedString()
    }

    private func savePhotoArchiveItem(_ item: MemoryArchiveItem, image: UIImage, successMessage: String) {
        guard isSelfAutobiographyMode else {
            showReadOnlyArchiveToast()
            return
        }

        repository.add(item)
        refreshContent()
        showToast(successMessage, type: .success)
        analyzePhotoArchiveItemIfPossible(item, image: image)
    }

    private func analyzePhotoArchiveItemIfPossible(_ item: MemoryArchiveItem, image: UIImage) {
        guard DreamJourneyBackendClient.shared.isArchiveImageAnalysisConfigured else {
            return
        }

        DreamJourneyBackendClient.shared.fetchArchiveImageAnalysisRuntimeCapability { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let capability):
                guard capability.canRunVisionAnalysis else {
                    markArchiveImageAnalysisUnavailable(item, capability: capability)
                    return
                }
                requestRemoteArchiveImageAnalysis(item, image: image)
            case .failure(let error):
                markArchiveImageAnalysisFailed(item, reason: archiveAnalysisFailureReason(error))
            }
        }
    }

    private func requestRemoteArchiveImageAnalysis(_ item: MemoryArchiveItem, image: UIImage) {
        guard let imageBase64 = imageBase64ForArchiveAnalysis(image) else {
            var updatedItem = item
            updatedItem.markAnalysisFailed(reason: "image_encoding_failed")
            repository.update(updatedItem, syncToBackend: true)
            refreshContent()
            showToast("照片分析失败，可稍后重试", type: .error)
            return
        }

        DreamJourneyBackendClient.shared.requestArchiveImageAnalysis(
            userId: currentArchiveAnalysisUserId,
            archiveItemId: item.id,
            imageBase64: imageBase64
        ) { [weak self] result in
            guard let self else { return }
            var updatedItem = item
            switch result {
            case .success(let object):
                updatedItem.applyRemoteImageAnalysisResult(object)
                repository.update(updatedItem, syncToBackend: true)
                refreshContent()
                if updatedItem.analysisStatus.isRetryableFailureLike {
                    showToast("AI 分析暂不可用，可稍后重试", type: .error)
                } else {
                    showToast("已生成图像分析", type: .success)
                }
            case .failure(let error):
                markArchiveImageAnalysisFailed(item, reason: archiveAnalysisFailureReason(error))
            }
        }
    }

    private func markArchiveImageAnalysisUnavailable(
        _ item: MemoryArchiveItem,
        capability: ArchiveImageAnalysisRuntimeCapability
    ) {
        var updatedItem = item
        updatedItem.markAnalysisUnavailableFromRuntime(
            provider: capability.provider,
            fallbackMode: capability.fallbackMode,
            message: capability.availabilityDisplayText
        )
        repository.update(updatedItem, syncToBackend: true)
        refreshContent()
        showToast(capability.availabilityDisplayText, type: .error)
    }

    private func markArchiveImageAnalysisFailed(_ item: MemoryArchiveItem, reason: String) {
        var updatedItem = item
        updatedItem.markAnalysisFailed(reason: reason)
        repository.update(updatedItem, syncToBackend: true)
        refreshContent()
        showToast("AI 分析暂不可用，可稍后重试", type: .error)
    }

    private var currentArchiveAnalysisUserId: String {
        UserManager.shared.currentUser?.id ?? "user_001"
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
        do {
            let fileURL = try saveImageToArchive(image)
            let item = MemoryArchiveItemFactory.makePhotoItem(localPath: fileURL.path, source: .samplePhoto)
            savePhotoArchiveItem(item, image: image, successMessage: "照片已封存")
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

        guard let image = info[.originalImage] as? UIImage else {
            showToast("照片读取失败", type: .error)
            return
        }

        do {
            let fileURL = try saveImageToArchive(image)
            let item = MemoryArchiveItemFactory.makePhotoItem(localPath: fileURL.path)
            savePhotoArchiveItem(item, image: image, successMessage: "照片已封存")
        } catch {
            showToast("照片保存失败", type: .error)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
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

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "照片编码失败"
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
