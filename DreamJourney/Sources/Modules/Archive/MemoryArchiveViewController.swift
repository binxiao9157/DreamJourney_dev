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
}

final class MemoryArchiveViewController: UIViewController {
    private let repository: MemoryArchiveRepository

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()
    private let featureCardsStack = UIStackView()
    private let listStack = UIStackView()

    private let summaryLabel = UILabel()
    private let progressLabel = UILabel()
    private let remoteSyncCaptionLabel = PaddingLabel(horizontalInset: 12, verticalInset: 8)
    private let analysisPrivacyDisclaimerLabel = PaddingLabel(horizontalInset: 12, verticalInset: 8)
    private var isRefreshingFromBackend = false

    private var creationOptions: [MemoryArchiveCreationOption] {
        MemoryArchiveCreationOption.availableOptions(
            isAudioUploadEnabled: isArchiveAudioCreationEnabled,
            isVideoUploadEnabled: isArchiveVideoCreationEnabled,
            isTimeLettersEnabled: isTimeLetterCreationEnabled
        )
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
        setupLayout()
        refreshContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshContent()
        refreshRemoteArchiveIfNeeded()
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
        mainStack.addArrangedSubview(header)
        mainStack.addArrangedSubview(featureCardsStack)
        mainStack.addArrangedSubview(analysisPrivacyDisclaimerLabel)
        mainStack.addArrangedSubview(remoteSyncCaptionLabel)
        mainStack.addArrangedSubview(makePrimaryCTA())
        mainStack.addArrangedSubview(makeTimelineHeader())
        mainStack.addArrangedSubview(listStack)
        mainStack.setCustomSpacing(ArchiveLayout.afterHeaderSpacing, after: header)
        mainStack.setCustomSpacing(ArchiveLayout.afterFeatureGridSpacing, after: featureCardsStack)
        mainStack.setCustomSpacing(ArchiveLayout.afterFeatureGridSpacing, after: analysisPrivacyDisclaimerLabel)
        mainStack.setCustomSpacing(ArchiveLayout.afterRemoteCaptionSpacing, after: remoteSyncCaptionLabel)
        mainStack.setCustomSpacing(ArchiveLayout.afterListSpacing, after: listStack)
    }

    private func updateArchiveListScrollInsets() {
        let bottomInset = Self.archiveListBottomInset(safeAreaBottomInset: view.safeAreaInsets.bottom)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func refreshContent() {
        let summary = repository.summary()
        summaryLabel.text = "已封存 \(summary.total) 段素材 · 相册 \(summary.photos) · 语音 \(summary.audio) · 文字 \(summary.text)"
        progressLabel.text = "档案素材和每一次回响对话，都会补足称呼、关系、偏好与生活线索，让数字人格更接近真实的表达方式。"

        reloadFeatureCards(summary: summary)
        reloadArchiveList()
    }

    private func refreshRemoteArchiveIfNeeded() {
        guard FeatureFlagService.shared.isEnabled(.archiveRemoteFetch),
              !isRefreshingFromBackend else {
            return
        }

        isRefreshingFromBackend = true
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

    private func configureAnalysisPrivacyDisclaimerLabel() {
        analysisPrivacyDisclaimerLabel.text = "AI 分析为主，后端辅助处理；我们不会人为查看你的记忆内容。"
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
            remoteSyncCaptionLabel.text = "远端暂不可用，已保留本地档案"
            remoteSyncCaptionLabel.isHidden = false
        }
        remoteSyncCaptionLabel.accessibilityLabel = remoteSyncCaptionLabel.text
    }

    private func reloadFeatureCards(summary: (total: Int, photos: Int, audio: Int, text: Int)) {
        featureCardsStack.removeAllArrangedSubviews()

        featureCardsStack.addArrangedSubview(makeFeatureGrid(summary: summary))
    }

    private func reloadArchiveList() {
        listStack.removeAllArrangedSubviews()
        let items = repository.allItems()

        if items.isEmpty {
            #if UI_QA_SIMULATOR && targetEnvironment(simulator)
            listStack.addArrangedSubview(makeStitchPhotoMemoryCard())
            listStack.addArrangedSubview(makeStitchAudioMemoryCard())
            #else
            listStack.addArrangedSubview(makeEmptyStateCard())
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
        stack.spacing = ArchiveLayout.headerStackSpacing

        let titleLabel = UILabel()
        titleLabel.text = "记忆档案馆"
        titleLabel.font = DJDesignTokens.Font.display(ArchiveLayout.headerTitleFontSize)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "在此处整理、回顾与珍藏那些不愿遗忘的片段。"
        subtitleLabel.font = DJDesignTokens.Font.body(ArchiveLayout.headerSubtitleFontSize)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makePrimaryCTA() -> UIControl {
        let control = UIControl()
        control.backgroundColor = DJDesignTokens.Color.accent
        control.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        control.addTarget(self, action: #selector(archiveNewMemoryTapped(_:)), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        iconContainer.layer.cornerRadius = ArchiveLayout.primaryCTAIconSize / 2
        iconContainer.isUserInteractionEnabled = false

        let iconView = UIImageView(image: UIImage(systemName: "plus"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "封存新记忆"
        titleLabel.font = DJDesignTokens.Font.title(ArchiveLayout.primaryCTATitleFontSize)
        titleLabel.textColor = DJDesignTokens.Color.accentDeep
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = makeArchiveCTASubtitle()
        subtitleLabel.font = DJDesignTokens.Font.body(ArchiveLayout.primaryCTASubtitleFontSize)
        subtitleLabel.textColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.78)
        subtitleLabel.textAlignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = ArchiveLayout.primaryCTATextSpacing
        textStack.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = ArchiveLayout.primaryCTAStackSpacing
        stack.isUserInteractionEnabled = false

        control.addSubview(stack)
        iconContainer.addSubview(iconView)
        [stack, iconContainer, iconView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAHeight),

            stack.centerXAnchor.constraint(equalTo: control.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: control.leadingAnchor, constant: ArchiveLayout.primaryCTAHorizontalSafety),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: control.trailingAnchor, constant: -ArchiveLayout.primaryCTAHorizontalSafety),

            iconContainer.widthAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAIconSize),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAIconSymbolSize),
            iconView.heightAnchor.constraint(equalToConstant: ArchiveLayout.primaryCTAIconSymbolSize),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = "封存新记忆，\(makeArchiveCTASubtitle())"
        return control
    }

    private func makeArchiveCTASubtitle() -> String {
        var inputs = ["文字", "图片"]
        if isArchiveAudioCreationEnabled {
            inputs.append("声音")
        }
        if isArchiveVideoCreationEnabled {
            inputs.append("视频")
        }
        if isTimeLetterCreationEnabled {
            inputs.append("时间信件")
        }
        return inputs.joined(separator: "、")
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
        let stack = UIStackView()
        stack.alignment = .center
        stack.spacing = 12

        let titleLabel = DJComponentFactory.sectionLabel("时间胶囊")
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let sortButton = UIButton(type: .system)
        sortButton.setTitle("按时间排序", for: .normal)
        sortButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        sortButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.tintColor = DJDesignTokens.Color.accentDeep
        sortButton.semanticContentAttribute = .forceRightToLeft
        sortButton.contentHorizontalAlignment = .trailing

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(sortButton)
        return stack
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
            action: #selector(selectPhotoTapped)
        )

        let secondaryTiles = makeSecondaryFeatureTiles()
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

    private func makeSecondaryFeatureTiles() -> [UIView] {
        var tiles: [UIView] = []

        if isArchiveAudioCreationEnabled {
            tiles.append(makeFeatureTile(
                iconName: "waveform",
                title: "语音档案",
                detail: nil,
                isLarge: false,
                action: #selector(audioCardTapped)
            ))
        }

        if isPersonaSettingsVisible {
            tiles.append(makeFeatureTile(
                iconName: "slider.horizontal.3",
                title: "人格设定",
                detail: nil,
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

        let image = item.localPath.flatMap { UIImage(contentsOfFile: $0) }
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
            let image = item.localPath.flatMap { UIImage(contentsOfFile: $0) }
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
        case .text, .timeLetter, .video:
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

    private func makeEmptyStateCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: "archivebox"))
        iconView.tintColor = DJDesignTokens.Color.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "还没有封存的记忆"
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = "先写下一段文字，或从相册选择一张照片。"
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
        let sheet = MemoryArchiveCreationSheetViewController(options: creationOptions)
        sheet.delegate = self
        present(sheet, animated: true)
    }

    @objc private func disabledFeatureTapped() {
        showToast("该入口将在后续开放", type: .info)
    }

    @objc private func archiveItemTapped(_ sender: MemoryArchiveItemRowControl) {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(
            MemoryArchiveDetailViewController(item: sender.item),
            animated: true
        )
    }

    @objc private func selectPhotoTapped() {
        presentPhotoEntry()
    }

    @objc private func audioCardTapped() {
        guard isArchiveAudioCreationEnabled else {
            showToast("语音素材录入将在后续开放", type: .info)
            return
        }
        presentAudioEntry()
    }

    @objc private func personaCardTapped() {
        guard FeatureFlagService.shared.isEnabled(.personaSettings) else {
            showToast("人格设定将在后续开放", type: .info)
            return
        }
        navigationController?.pushViewController(KnowledgeBaseViewController(), animated: true)
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
        let isTimeLetter = kind == .timeLetter
        let entryViewController = MemoryArchiveTextEntryViewController(kind: kind)
        entryViewController.onSave = { [weak self] rawText in
            guard let self else { return }
            let item = isTimeLetter
                ? MemoryArchiveItemFactory.makeTimeLetter(note: rawText)
                : MemoryArchiveItemFactory.makeTextItem(note: rawText)
            self.repository.add(item)
            self.refreshContent()
            self.showToast("已封存", type: .success)
        }
        present(entryViewController, animated: true)
    }

    private func presentAudioEntry() {
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
        let entryViewController = MemoryArchiveVideoEntryViewController()
        present(entryViewController, animated: true)
    }

    private func presentPhotoEntry() {
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

    private func saveSamplePhotoToArchive() {
        let image = UIImage(named: "default_memory_1") ?? makeFallbackArchiveImage()
        do {
            let fileURL = try saveImageToArchive(image)
            let item = MemoryArchiveItemFactory.makePhotoItem(localPath: fileURL.path, source: .samplePhoto)
            repository.add(item)
            refreshContent()
            showToast("照片已封存", type: .success)
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
            repository.add(item)
            refreshContent()
            showToast("照片已封存", type: .success)
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
