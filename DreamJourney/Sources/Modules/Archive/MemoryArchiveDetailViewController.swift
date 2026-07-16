import AVFoundation
import UIKit

private enum ArchiveDetailLayout {
    static let contentTopMargin: CGFloat = 12
    static let contentBottomMargin: CGFloat = 32
    static let contentStackSpacing: CGFloat = 16
    static let cardInset: CGFloat = 18
    static let cardInnerSpacing: CGFloat = 14
    static let headerIconSize: CGFloat = 44
    static let headerStackSpacing: CGFloat = 12
    static let photoMediaInset: CGFloat = 12
    static let photoMediaAspectRatio: CGFloat = 0.72
    static let photoOverlayRatio: CGFloat = 0.48
    static let audioPlayButtonSize: CGFloat = 48
    static let audioWaveformHeight: CGFloat = 42
    static let audioTrackHeight: CGFloat = 8
    static let analysisHeroIconSize: CGFloat = 42
    static let analysisSummaryInset: CGFloat = 16
    static let analysisCardSpacing: CGFloat = 14
    static let analysisPanelSpacing: CGFloat = 10
    static let analysisAccentWidth: CGFloat = 4
}

final class MemoryArchiveDetailViewController: UIViewController, AVAudioPlayerDelegate {
    private static let analysisDisclaimerText = "基于照片说明和本地规则整理；后端仅同步元数据，我们不会人为查看你的记忆内容。"

    private var item: MemoryArchiveItem
    private let repository: MemoryArchiveRepository
    private let isReadOnly: Bool
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var audioPlayer: AVAudioPlayer?
    private weak var audioPlayButton: UIButton?
    private weak var analysisRetryButton: UIButton?
    private weak var mediaUploadIntentButton: UIButton?
    private var isRetryingRemoteAnalysis = false
    private var isRequestingMediaUploadIntent = false
    private var archiveMediaRuntimeCapability: ArchiveMediaRuntimeCapability?
    private var archiveMediaRuntimeErrorText: String?
    private var didRequestArchiveMediaRuntimeCapability = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    private static let stitchDetailBottomRhythm: CGFloat = 120

    private static func detailBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat {
        max(stitchDetailBottomRhythm, DJDesignTokens.Spacing.section + safeAreaBottomInset)
    }

    init(
        item: MemoryArchiveItem,
        repository: MemoryArchiveRepository = .shared,
        isReadOnly: Bool = false
    ) {
        self.item = item
        self.repository = repository
        self.isReadOnly = isReadOnly
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "档案详情"
        view.backgroundColor = DJDesignTokens.Color.background
        setupLayout()
        configureNavigationActions()
        refreshArchiveMediaRuntimeCapabilityIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showPreviousLevelNavigationIfNeeded(animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDetailScrollInsets()
    }

    private func setupLayout() {
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        updateDetailScrollInsets()

        contentStack.axis = .vertical
        contentStack.spacing = ArchiveDetailLayout.contentStackSpacing
        contentStack.layoutMargins = UIEdgeInsets(
            top: ArchiveDetailLayout.contentTopMargin,
            left: DJDesignTokens.Spacing.page,
            bottom: ArchiveDetailLayout.contentBottomMargin,
            right: DJDesignTokens.Spacing.page
        )
        contentStack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        [scrollView, contentStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

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

        reloadContent()
    }

    private func updateDetailScrollInsets() {
        let bottomInset = Self.detailBottomInset(safeAreaBottomInset: view.safeAreaInsets.bottom)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func configureNavigationActions() {
        guard shouldShowLocalAnalysisAction && canManageCurrentArchiveItem else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "sparkles"),
            style: .plain,
            target: self,
            action: #selector(analyzeArchiveItemTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "生成本地分析"
    }

    private var canManageCurrentArchiveItem: Bool {
        !isReadOnly && item.canManage(by: UserManager.shared.currentUser?.id ?? "")
    }

    private var shouldShowLocalAnalysisAction: Bool {
        guard item.analysisStatus != .analyzed else { return false }
        #if DEBUG || UI_QA_SIMULATOR
        let qaSyntheticOverride = true
        #else
        let qaSyntheticOverride = false
        #endif
        return FeatureGateService.shared.isRouteAllowed(
            .archiveLocalAnalysis,
            localEnabled: FeatureFlagService.shared.isEnabled(.archiveLocalAnalysis),
            qaSyntheticOverride: qaSyntheticOverride
        )
    }

    private var shouldSyncArchiveUpdateToBackend: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    private func reloadContent() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayButton = nil
        analysisRetryButton = nil
        mediaUploadIntentButton = nil

        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        contentStack.addArrangedSubview(makeHeaderCard())

        if let mediaCard = makeMediaCard() {
            contentStack.addArrangedSubview(mediaCard)
        }

        if let hiddenMediaStateCard = makeHiddenMediaStateCard() {
            contentStack.addArrangedSubview(hiddenMediaStateCard)
        }
        if let runtimeCapabilityCard = makeArchiveMediaRuntimeCapabilityCard() {
            contentStack.addArrangedSubview(runtimeCapabilityCard)
        }

        contentStack.addArrangedSubview(makeMetadataCard())
        contentStack.addArrangedSubview(makePrimaryContentCard())
        contentStack.addArrangedSubview(makeAnalysisCard())
        updateDetailScrollInsets()
    }

    private func makeHeaderCard() -> UIView {
        let presentation = item.archivePresentation
        let card = makeDetailCard(radius: DJDesignTokens.Radius.extraLarge)
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = ArchiveDetailLayout.headerStackSpacing

        let iconContainer = makeIconContainer(iconName: presentation.previewIconName)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = presentation.title
        titleLabel.font = DJDesignTokens.Font.title(24)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let badgeStack = UIStackView()
        badgeStack.spacing = 8
        badgeStack.alignment = .center
        badgeStack.addArrangedSubview(makeBadge(text: presentation.kindLabel))
        badgeStack.addArrangedSubview(makeBadge(
            text: presentation.statusLabel,
            textColor: DJDesignTokens.Color.textSecondary,
            backgroundColor: DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        ))

        let dateLabel = UILabel()
        dateLabel.text = Self.dateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.body(13)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(badgeStack)
        textStack.addArrangedSubview(dateLabel)

        card.addSubview(stack)
        [stack, iconContainer, textStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: ArchiveDetailLayout.headerIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: ArchiveDetailLayout.headerIconSize),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveDetailLayout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveDetailLayout.cardInset),
        ])

        return card
    }

    private func makeMediaCard() -> UIView? {
        switch item.kind {
        case .photo:
            return makePhotoMediaCard()
        case .audio:
            return makeAudioMediaCard()
        case .video:
            return makeVideoMediaCard()
        case .timeLetter:
            return item.resolvedLocalFilePath == nil ? nil : makePhotoMediaCard()
        default:
            return nil
        }
    }

    private func makePhotoMediaCard() -> UIView {
        let presentation = item.archivePresentation
        let image = item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }
        let hasImage = image != nil
        let card = makeDetailCard(radius: DJDesignTokens.Radius.extraLarge)
        card.clipsToBounds = true

        let imageContainer = UIView()
        imageContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.86)
        imageContainer.clipsToBounds = true
        imageContainer.layer.cornerRadius = DJDesignTokens.Radius.large

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = !hasImage

        let placeholderIcon = UIImageView(image: UIImage(systemName: "photo.on.rectangle.angled"))
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.34)
        placeholderIcon.isHidden = hasImage

        let overlayView = UIView()
        overlayView.backgroundColor = hasImage
            ? UIColor.black.withAlphaComponent(0.28)
            : DJDesignTokens.Color.surface.withAlphaComponent(0.78)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 7

        let titleLabel = UILabel()
        titleLabel.text = presentation.previewTitle
        titleLabel.font = DJDesignTokens.Font.title(20)
        titleLabel.textColor = hasImage ? .white : DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = presentation.previewSubtitle
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = hasImage
            ? UIColor.white.withAlphaComponent(0.84)
            : DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let badge = makeBadge(
            text: presentation.kindLabel,
            textColor: hasImage ? .white : DJDesignTokens.Color.accentDeep,
            backgroundColor: hasImage
                ? UIColor.white.withAlphaComponent(0.18)
                : DJDesignTokens.Color.surfaceLow
        )

        card.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(placeholderIcon)
        imageContainer.addSubview(overlayView)
        imageContainer.addSubview(textStack)
        imageContainer.addSubview(badge)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        [imageContainer, imageView, placeholderIcon, overlayView, textStack, titleLabel, subtitleLabel, badge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.photoMediaInset),
            imageContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveDetailLayout.photoMediaInset),
            imageContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveDetailLayout.photoMediaInset),
            imageContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveDetailLayout.photoMediaInset),
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: ArchiveDetailLayout.photoMediaAspectRatio),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor, constant: -22),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 72),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 72),

            overlayView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            overlayView.heightAnchor.constraint(equalTo: imageContainer.heightAnchor, multiplier: ArchiveDetailLayout.photoOverlayRatio),

            badge.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: 14),
            badge.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 14),

            textStack.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeAudioMediaCard() -> UIView? {
        let presentation = item.archivePresentation
        let card = makeDetailCard(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveDetailLayout.contentStackSpacing

        let headerStack = UIStackView()
        headerStack.alignment = .center
        headerStack.spacing = ArchiveDetailLayout.headerStackSpacing

        let playButton = UIButton(type: .system)
        playButton.backgroundColor = DJDesignTokens.Color.accent
        playButton.tintColor = DJDesignTokens.Color.accentDeep
        playButton.layer.cornerRadius = 24
        let hasPlayableAudio = item.hasResolvedLocalFile
        playButton.setImage(UIImage(systemName: hasPlayableAudio ? "play.fill" : "waveform.slash"), for: .normal)
        playButton.isEnabled = hasPlayableAudio
        playButton.alpha = hasPlayableAudio ? 1 : 0.68
        playButton.accessibilityIdentifier = hasPlayableAudio
            ? "archive-audio-play-button"
            : "archive-audio-media-placeholder"
        playButton.addTarget(self, action: #selector(playAudioTapped), for: .touchUpInside)
        audioPlayButton = hasPlayableAudio ? playButton : nil

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = presentation.previewTitle
        titleLabel.font = DJDesignTokens.Font.title(18)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        let durationLabel = UILabel()
        durationLabel.text = presentation.previewSubtitle
        durationLabel.font = DJDesignTokens.Font.body(13)
        durationLabel.textColor = DJDesignTokens.Color.textSecondary
        durationLabel.numberOfLines = 0

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(durationLabel)

        headerStack.addArrangedSubview(playButton)
        headerStack.addArrangedSubview(titleStack)

        let trackView = UIView()
        trackView.backgroundColor = DJDesignTokens.Color.surfaceContainer
        trackView.layer.cornerRadius = 4

        let progressView = UIView()
        progressView.backgroundColor = DJDesignTokens.Color.accentDeep
        progressView.layer.cornerRadius = 4

        let waveformView = makeWaveformView()

        card.addSubview(stack)
        trackView.addSubview(progressView)
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(waveformView)
        stack.addArrangedSubview(trackView)
        stack.addArrangedSubview(makeAudioTranscriptCard())

        [stack, headerStack, playButton, titleStack, titleLabel, durationLabel, waveformView, trackView, progressView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveDetailLayout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveDetailLayout.cardInset),

            playButton.widthAnchor.constraint(equalToConstant: ArchiveDetailLayout.audioPlayButtonSize),
            playButton.heightAnchor.constraint(equalToConstant: ArchiveDetailLayout.audioPlayButtonSize),

            waveformView.heightAnchor.constraint(equalToConstant: ArchiveDetailLayout.audioWaveformHeight),

            trackView.heightAnchor.constraint(equalToConstant: ArchiveDetailLayout.audioTrackHeight),

            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            progressView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0.34),
        ])

        return card
    }

    private func makeAudioTranscriptCard() -> UIView {
        let transcriptCard = UIView()
        transcriptCard.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.62)
        transcriptCard.layer.cornerRadius = DJDesignTokens.Radius.large
        transcriptCard.accessibilityIdentifier = "archive-audio-transcript-card"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let statusLabel = makeBadge(
            text: item.audioTranscriptionStatusDisplayName ?? "未转写",
            textColor: item.metadata[MemoryArchiveItem.mediaTranscriptionStatusMetadataKey] == ArchiveMediaTranscriptionStatus.failed.rawValue
                ? DJDesignTokens.Color.danger
                : DJDesignTokens.Color.accentDeep,
            backgroundColor: item.metadata[MemoryArchiveItem.mediaTranscriptionStatusMetadataKey] == ArchiveMediaTranscriptionStatus.failed.rawValue
                ? DJDesignTokens.Color.danger.withAlphaComponent(0.12)
                : DJDesignTokens.Color.accent.withAlphaComponent(0.16)
        )
        statusLabel.accessibilityIdentifier = "archive-audio-transcription-state"

        let transcriptLabel = UILabel()
        transcriptLabel.text = audioTranscriptDisplayText
        transcriptLabel.font = DJDesignTokens.Font.body(14)
        transcriptLabel.textColor = DJDesignTokens.Color.textSecondary
        transcriptLabel.numberOfLines = 0

        transcriptCard.addSubview(stack)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(transcriptLabel)

        if item.metadata[MemoryArchiveItem.mediaTranscriptionStatusMetadataKey] == ArchiveMediaTranscriptionStatus.failed.rawValue {
            let retryLabel = UILabel()
            retryLabel.text = "转写失败，可重试；当前可继续使用声音说明进入回响上下文。"
            retryLabel.font = DJDesignTokens.Font.label(12)
            retryLabel.textColor = DJDesignTokens.Color.textTertiary
            retryLabel.numberOfLines = 0
            retryLabel.accessibilityIdentifier = "archive-audio-transcription-retry-copy"
            stack.addArrangedSubview(retryLabel)
        }

        [stack, statusLabel, transcriptLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: transcriptCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: transcriptCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: transcriptCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: transcriptCard.bottomAnchor, constant: -14),
        ])

        return transcriptCard
    }

    private var audioTranscriptDisplayText: String {
        if let transcriptText = item.metadataTranscriptTextForDisplay {
            return transcriptText
        }
        switch item.metadata[MemoryArchiveItem.mediaTranscriptionStatusMetadataKey] {
        case ArchiveMediaTranscriptionStatus.pending.rawValue:
            return "正在等待转写结果，完成后会优先作为回响上下文。"
        case ArchiveMediaTranscriptionStatus.failed.rawValue:
            return "没有可用转写文本，回响会优先使用你填写的声音说明。"
        default:
            return "暂未生成转写文本，回响会使用声音说明，不会注入空转写。"
        }
    }

    private func makeVideoMediaCard() -> UIView? {
        let presentation = item.archivePresentation
        let card = makeDetailCard(radius: DJDesignTokens.Radius.extraLarge)
        card.clipsToBounds = true
        card.accessibilityIdentifier = "archive-video-media-card"

        let mediaContainer = UIView()
        mediaContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.86)
        mediaContainer.clipsToBounds = true
        mediaContainer.layer.cornerRadius = DJDesignTokens.Radius.large

        let thumbnailImage = item.resolvedThumbnailPath
            .flatMap { UIImage(contentsOfFile: $0) }
        let hasThumbnail = thumbnailImage != nil
        let hasLocalVideo = item.hasResolvedLocalFile

        let imageView = UIImageView(image: thumbnailImage)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = !hasThumbnail
        imageView.accessibilityIdentifier = "archive-video-thumbnail-image"

        let placeholderIcon = UIImageView(image: UIImage(systemName: hasLocalVideo ? "video" : "video.slash"))
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.42)
        placeholderIcon.isHidden = hasThumbnail
        placeholderIcon.accessibilityIdentifier = "archive-video-media-placeholder"

        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        overlayView.isHidden = !hasThumbnail
        overlayView.accessibilityIdentifier = "archive-video-thumbnail-overlay"

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 7

        let titleLabel = UILabel()
        titleLabel.text = hasLocalVideo ? presentation.previewTitle : "视频待补充"
        titleLabel.font = DJDesignTokens.Font.title(19)
        titleLabel.textColor = hasThumbnail ? .white : DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = hasLocalVideo
            ? presentation.previewSubtitle
            : "当前只有视频档案说明，补回本地视频后再继续上传与分析。"
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = hasThumbnail
            ? UIColor.white.withAlphaComponent(0.84)
            : DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let badge = makeBadge(
            text: presentation.kindLabel,
            textColor: hasThumbnail ? .white : DJDesignTokens.Color.accentDeep,
            backgroundColor: hasThumbnail
                ? UIColor.white.withAlphaComponent(0.18)
                : DJDesignTokens.Color.surfaceLow
        )

        card.addSubview(mediaContainer)
        mediaContainer.addSubview(imageView)
        mediaContainer.addSubview(placeholderIcon)
        mediaContainer.addSubview(overlayView)
        mediaContainer.addSubview(textStack)
        mediaContainer.addSubview(badge)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.addArrangedSubview(makeVideoMediaMetaStrip())

        [mediaContainer, imageView, placeholderIcon, overlayView, textStack, titleLabel, subtitleLabel, badge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            mediaContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.photoMediaInset),
            mediaContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveDetailLayout.photoMediaInset),
            mediaContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveDetailLayout.photoMediaInset),
            mediaContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveDetailLayout.photoMediaInset),
            mediaContainer.heightAnchor.constraint(equalTo: mediaContainer.widthAnchor, multiplier: 0.58),

            imageView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: mediaContainer.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: mediaContainer.centerYAnchor, constant: -20),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 68),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 68),

            overlayView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
            overlayView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor, multiplier: 0.52),

            badge.topAnchor.constraint(equalTo: mediaContainer.topAnchor, constant: 14),
            badge.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor, constant: 14),

            textStack.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeVideoMediaMetaStrip() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .leading
        stack.accessibilityIdentifier = "archive-video-meta-strip"

        let fileSizeBadge = makeBadge(
            text: item.metadataFileSizeDisplayName ?? "文件大小未知",
            textColor: DJDesignTokens.Color.textSecondary,
            backgroundColor: DJDesignTokens.Color.surface.withAlphaComponent(0.72)
        )
        fileSizeBadge.accessibilityIdentifier = "archive-video-file-size"

        let analysisBadge = makeBadge(
            text: item.videoAnalysisStatusDisplayName ?? item.analysisStatus.archiveDisplayName,
            textColor: item.analysisStatus.isRetryableFailureLike ? DJDesignTokens.Color.danger : DJDesignTokens.Color.accentDeep,
            backgroundColor: item.analysisStatus.isRetryableFailureLike
                ? DJDesignTokens.Color.danger.withAlphaComponent(0.12)
                : DJDesignTokens.Color.accent.withAlphaComponent(0.18)
        )
        analysisBadge.accessibilityIdentifier = "archive-video-analysis-state"

        let thumbnailBadge = makeBadge(
            text: item.metadata["thumbnailStatus"] == "failed" ? "缩略图失败" : "缩略图占位",
            textColor: DJDesignTokens.Color.textSecondary,
            backgroundColor: DJDesignTokens.Color.surface.withAlphaComponent(0.72)
        )

        stack.addArrangedSubview(fileSizeBadge)
        stack.addArrangedSubview(analysisBadge)
        stack.addArrangedSubview(thumbnailBadge)
        stack.addArrangedSubview(UIView())
        return stack
    }

    private func makeHiddenMediaStateCard() -> UIView? {
        guard item.kind == .audio || item.kind == .video else {
            return nil
        }

        let card = makeDetailCard(radius: DJDesignTokens.Radius.large)
        card.accessibilityIdentifier = "archive-hidden-media-state-card"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let headerStack = UIStackView()
        headerStack.alignment = .center
        headerStack.spacing = 12

        let stateIcon = makeIconContainer(iconName: hiddenMediaStateIconName)
        stateIcon.backgroundColor = hiddenMediaStateTint.withAlphaComponent(0.14)

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = hiddenMediaStateTitle
        titleLabel.font = DJDesignTokens.Font.title(17)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = hiddenMediaStateIdentifier

        let subtitleLabel = UILabel()
        subtitleLabel.text = hiddenMediaStateSubtitle
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)
        headerStack.addArrangedSubview(stateIcon)
        headerStack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(headerStack)

        if item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] == ArchiveMediaUploadStatus.failed.rawValue {
            let retryLabel = UILabel()
            retryLabel.text = "可使用“重新上传”按钮重试；当前不会执行真实对象存储 PUT。"
            retryLabel.font = DJDesignTokens.Font.label(12)
            retryLabel.textColor = DJDesignTokens.Color.textTertiary
            retryLabel.numberOfLines = 0
            retryLabel.accessibilityIdentifier = "archive-hidden-media-retry-copy"
            if item.kind == .video {
                retryLabel.accessibilityLabel = "mock 视频失败/重试"
            }
            stack.addArrangedSubview(retryLabel)
        }

        card.addSubview(stack)
        [stack, headerStack, stateIcon, titleStack, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),

            stateIcon.widthAnchor.constraint(equalToConstant: 42),
            stateIcon.heightAnchor.constraint(equalToConstant: 42),
        ])

        return card
    }

    private func makeArchiveMediaRuntimeCapabilityCard() -> UIView? {
        guard item.kind == .audio || item.kind == .video else {
            return nil
        }

        let capability = effectiveArchiveMediaRuntimeCapability
        let card = makeDetailCard(radius: DJDesignTokens.Radius.large)
        card.accessibilityIdentifier = "archive-hidden-media-runtime-card"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let titleLabel = UILabel()
        titleLabel.text = "后端媒体能力"
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        let stateLabel = makeBadge(
            text: archiveMediaRuntimeErrorText ?? capability.availabilityDisplayText,
            textColor: capability.uploadIntentAvailable ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.danger,
            backgroundColor: capability.uploadIntentAvailable
                ? DJDesignTokens.Color.accent.withAlphaComponent(0.16)
                : DJDesignTokens.Color.danger.withAlphaComponent(0.12)
        )
        stateLabel.accessibilityIdentifier = "archive-hidden-media-runtime-state"

        let providerLabel = UILabel()
        providerLabel.text = capability.providerDisplayText
        providerLabel.font = DJDesignTokens.Font.body(13)
        providerLabel.textColor = DJDesignTokens.Color.textSecondary
        providerLabel.numberOfLines = 0
        providerLabel.accessibilityIdentifier = "archive-hidden-media-runtime-provider"

        let uploadModeLabel = UILabel()
        uploadModeLabel.text = "\(capability.providerModeDisplayText) · \(capability.uploadExecutionDisplayText)"
        uploadModeLabel.font = DJDesignTokens.Font.body(13)
        uploadModeLabel.textColor = DJDesignTokens.Color.textSecondary
        uploadModeLabel.numberOfLines = 0
        uploadModeLabel.accessibilityIdentifier = "archive-hidden-media-runtime-upload-mode"

        let supportedKindText = capability.supports(kind: item.kind)
            ? "\(item.kind.archiveDisplayName) 支持元数据同步"
            : "\(item.kind.archiveDisplayName) 暂不支持元数据同步"
        let limitLabel = UILabel()
        limitLabel.text = "\(supportedKindText) · \(capability.fileSizeLimitDisplayText(for: item.kind)) · 有效期 \(capability.uploadIntentTTLSeconds) 秒"
        limitLabel.font = DJDesignTokens.Font.label(12)
        limitLabel.textColor = DJDesignTokens.Color.textTertiary
        limitLabel.numberOfLines = 0
        limitLabel.accessibilityIdentifier = "archive-hidden-media-runtime-limit"

        card.addSubview(stack)
        [stack, titleLabel, stateLabel, providerLabel, uploadModeLabel, limitLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(stateLabel)
        stack.addArrangedSubview(providerLabel)
        stack.addArrangedSubview(uploadModeLabel)
        stack.addArrangedSubview(limitLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private var effectiveArchiveMediaRuntimeCapability: ArchiveMediaRuntimeCapability {
        archiveMediaRuntimeCapability
            ?? ArchiveMediaRuntimeCapability.localFallback(
                isBackendConfigured: DreamJourneyBackendClient.shared.isArchiveMediaUploadIntentConfigured
            )
    }

    private var hiddenMediaStateIdentifier: String {
        if !item.hasResolvedLocalFile {
            return "archive-hidden-media-empty-state"
        }
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.failed.rawValue:
            return "archive-hidden-media-failed-state"
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "archive-hidden-media-uploaded-state"
        default:
            return "archive-hidden-media-local-state"
        }
    }

    private var hiddenMediaStateTitle: String {
        if !item.hasResolvedLocalFile {
            return "媒体文件待补充"
        }
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.pending.rawValue:
            return "媒体元数据上传中"
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "媒体元数据已同步"
        case ArchiveMediaUploadStatus.failed.rawValue:
            return "上传失败，可重新同步"
        default:
            return "媒体文件仅保存在本地"
        }
    }

    private var hiddenMediaStateSubtitle: String {
        if !item.hasResolvedLocalFile {
            return "当前只有档案说明，补回本地文件后再同步媒体元数据。"
        }
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.pending.rawValue:
            return "正在请求后端上传合同，请保持当前页面。"
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "已登记对象存储 key，后续可接真实文件上传。"
        case ArchiveMediaUploadStatus.failed.rawValue:
            let reason = item.metadata[MemoryArchiveItem.mediaUploadErrorMetadataKey] ?? "上传失败"
            return "最近一次同步未完成：\(reason)"
        default:
            return "本地文件已保存，当前公开版本不会自动上传媒体内容。"
        }
    }

    private var hiddenMediaStateIconName: String {
        if !item.hasResolvedLocalFile {
            return "externaldrive.badge.questionmark"
        }
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "checkmark.icloud"
        case ArchiveMediaUploadStatus.failed.rawValue:
            return "exclamationmark.icloud"
        case ArchiveMediaUploadStatus.pending.rawValue:
            return "arrow.triangle.2.circlepath.icloud"
        default:
            return "externaldrive"
        }
    }

    private var hiddenMediaStateTint: UIColor {
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.failed.rawValue:
            return DJDesignTokens.Color.danger
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return UIColor.systemGreen
        default:
            return DJDesignTokens.Color.accentDeep
        }
    }

    private func makeWaveformView() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 5

        let heights: [CGFloat] = [14, 24, 18, 34, 26, 16, 30, 38, 22, 28, 18, 32, 24, 14]
        heights.forEach { height in
            let bar = UIView()
            bar.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.42)
            bar.layer.cornerRadius = 2
            stack.addArrangedSubview(bar)
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.heightAnchor.constraint(equalToConstant: height).isActive = true
        }

        return stack
    }

    private func makePrimaryContentCard() -> UIView {
        let presentation = item.archivePresentation
        switch item.kind {
        case .text, .timeLetter:
            return makeWrittenContentCard()
        default:
            return makeTextCard(title: presentation.originalContentTitle, body: presentation.note)
        }
    }

    private func makeWrittenContentCard() -> UIView {
        let presentation = item.archivePresentation
        let card = makeDetailCard(radius: DJDesignTokens.Radius.extraLarge)
        card.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.62)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        let headerStack = UIStackView()
        headerStack.alignment = .center
        headerStack.spacing = 12

        let iconContainer = makeIconContainer(iconName: presentation.previewIconName)
        iconContainer.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.82)

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = presentation.previewTitle
        titleLabel.font = DJDesignTokens.Font.title(19)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = presentation.previewSubtitle
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)

        let bodyContainer = UIView()
        bodyContainer.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.92)
        bodyContainer.layer.cornerRadius = DJDesignTokens.Radius.large

        let accentLine = UIView()
        accentLine.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.42)
        accentLine.layer.cornerRadius = 2

        let bodyLabel = UILabel()
        let trimmedNote = presentation.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.kind == .timeLetter && trimmedNote.isEmpty {
            bodyLabel.text = item.isTimeLetterDraft
                ? "这封信还没有内容，可继续编辑草稿。"
                : "这封信已封存，等待打开时间到来。"
        } else {
            bodyLabel.text = presentation.note
        }
        bodyLabel.font = DJDesignTokens.Font.body(17)
        bodyLabel.textColor = DJDesignTokens.Color.textSecondary
        bodyLabel.numberOfLines = 0
        if item.kind == .timeLetter && trimmedNote.isEmpty {
            bodyLabel.accessibilityIdentifier = "archive-time-letter-empty-body"
        }

        card.addSubview(stack)
        headerStack.addArrangedSubview(iconContainer)
        headerStack.addArrangedSubview(titleStack)
        bodyContainer.addSubview(accentLine)
        bodyContainer.addSubview(bodyLabel)
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(bodyContainer)
        if item.kind == .timeLetter {
            stack.addArrangedSubview(makeTimeLetterStateCard())
            if item.isTimeLetterDraft {
                stack.addArrangedSubview(makeTimeLetterLifecycleActions())
            }
        } else if item.kind == .text && canManageCurrentArchiveItem {
            stack.addArrangedSubview(makeLifecycleButton(
                title: "编辑文字",
                identifier: "archive-text-edit-button",
                action: #selector(editTextArchiveTapped)
            ))
        }

        [stack, headerStack, iconContainer, titleStack, titleLabel, subtitleLabel, bodyContainer, accentLine, bodyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),

            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            accentLine.topAnchor.constraint(equalTo: bodyContainer.topAnchor, constant: 16),
            accentLine.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor, constant: 16),
            accentLine.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor, constant: -16),
            accentLine.widthAnchor.constraint(equalToConstant: 4),

            bodyLabel.topAnchor.constraint(equalTo: bodyContainer.topAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: accentLine.trailingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor, constant: -16),
            bodyLabel.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeTimeLetterStateCard() -> UIView {
        let stateCard = UIView()
        stateCard.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.74)
        stateCard.layer.cornerRadius = DJDesignTokens.Radius.large
        stateCard.accessibilityIdentifier = "archive-time-letter-state-card"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let titleLabel = UILabel()
        titleLabel.text = timeLetterPrimaryStatusText
        titleLabel.font = DJDesignTokens.Font.title(15)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = item.isTimeLetterDraft
            ? "archive-time-letter-draft-state"
            : "archive-time-letter-sealed-state"

        let subtitleLabel = UILabel()
        subtitleLabel.text = timeLetterSecondaryStatusText
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stateCard.addSubview(stack)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(makeTimeLetterPolicyLabel(
            text: "打开：\(timeLetterOpenAtText)",
            identifier: "archive-time-letter-delivery-state"
        ))
        stack.addArrangedSubview(makeTimeLetterPolicyLabel(
            text: item.isTimeLetterDraft ? "封存前可继续编辑" : "已封存，不可删除或修改",
            identifier: "archive-time-letter-lock-state"
        ))
        stack.addArrangedSubview(makeTimeLetterPolicyLabel(
            text: item.isTimeLetterDraft
                ? "封存后安排提醒"
                : (item.timeLetterNotificationScheduled ? "本地通知 + 应用内提醒" : "提醒待安排"),
            identifier: "archive-time-letter-notification-state"
        ))
        [stack, titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: stateCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: stateCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: stateCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: stateCard.bottomAnchor, constant: -14),
        ])

        return stateCard
    }

    private var timeLetterOpenAtText: String {
        item.timeLetterOpenAt.map(Self.dateFormatter.string(from:)) ?? "未设置"
    }

    private var timeLetterRecipientText: String {
        item.timeLetterRecipientNames.isEmpty
            ? "我"
            : item.timeLetterRecipientNames.joined(separator: "、")
    }

    private var timeLetterPrimaryStatusText: String {
        if item.isTimeLetterDraft {
            return "草稿未封存"
        }
        if item.isTimeLetterDelivered {
            return "已提醒本人和收件人"
        }
        return item.isTimeLetterDue ? "已到打开时间" : "等待未来打开"
    }

    private var timeLetterSecondaryStatusText: String {
        if item.isTimeLetterDraft {
            return "写好后再封存。封存后，这封信会进入等待状态。"
        }
        return "收件人：\(timeLetterRecipientText)。到期后提醒本人和收件人回看。"
    }

    private func makeTimeLetterPolicyLabel(text: String, identifier: String) -> UILabel {
        let label = DetailPaddingLabel(horizontalInset: 10, verticalInset: 6)
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.16)
        label.layer.cornerRadius = DJDesignTokens.Radius.small
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.accessibilityIdentifier = identifier
        return label
    }

    private func makeTimeLetterLifecycleActions() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually

        if item.isTimeLetterDraft && canManageCurrentArchiveItem {
            stack.addArrangedSubview(makeLifecycleButton(
                title: "编辑草稿",
                identifier: "archive-time-letter-edit-draft",
                action: #selector(editTimeLetterDraftTapped)
            ))
            stack.addArrangedSubview(makeLifecycleButton(
                title: "封存草稿",
                identifier: "archive-time-letter-seal-draft",
                action: #selector(sealTimeLetterDraftTapped)
            ))
            stack.addArrangedSubview(makeLifecycleButton(
                title: "删除草稿",
                identifier: "archive-time-letter-delete-draft",
                action: #selector(deleteTimeLetterDraftTapped)
            ))
        }

        return stack
    }

    private func makeLifecycleButton(
        title: String,
        identifier: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(12)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.surface
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 10, bottom: 9, right: 10)
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeTextCard(title: String, body: String) -> UIView {
        let card = makeDetailCard(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let titleLabel = DJComponentFactory.sectionLabel(title)

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DJDesignTokens.Font.body(16)
        bodyLabel.textColor = DJDesignTokens.Color.textSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        card.addSubview(stack)
        [stack, titleLabel, bodyLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bodyLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeMetadataCard() -> UIView {
        let card = makeDetailCard(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        let titleLabel = DJComponentFactory.sectionLabel(item.kind == .timeLetter ? "开启安排" : "档案信息")
        stack.addArrangedSubview(titleLabel)

        item.archiveDetailMetadataRows.forEach { row in
            stack.addArrangedSubview(makeMetadataRow(title: row.title, value: row.value))
        }
        if item.isMediaUploadIntentEligible {
            stack.addArrangedSubview(makeMediaUploadIntentButton())
        }

        card.addSubview(stack)
        [stack, titleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeMediaUploadIntentButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(mediaUploadIntentButtonTitle, for: .normal)
        button.setImage(UIImage(systemName: "arrow.up.doc"), for: .normal)
        button.tintColor = DJDesignTokens.Color.accentDeep
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.18)
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        button.isEnabled = !isRequestingMediaUploadIntent
        button.alpha = isRequestingMediaUploadIntent ? 0.72 : 1
        button.accessibilityIdentifier = "archive-media-upload-intent-button"
        button.accessibilityLabel = mediaUploadIntentButtonTitle
        button.addTarget(self, action: #selector(requestMediaUploadIntentTapped), for: .touchUpInside)
        mediaUploadIntentButton = button
        return button
    }

    private var mediaUploadIntentButtonTitle: String {
        if isRequestingMediaUploadIntent {
            return "上传中..."
        }
        switch item.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] {
        case ArchiveMediaUploadStatus.failed.rawValue:
            return "重新上传"
        case ArchiveMediaUploadStatus.uploaded.rawValue:
            return "重新同步媒体元数据"
        default:
            return "同步媒体元数据"
        }
    }

    private func makeMetadataRow(title: String, value: String) -> UIView {
        let stack = UIStackView()
        stack.alignment = .firstBaseline
        stack.spacing = 12

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.label(12)
        titleLabel.textColor = DJDesignTokens.Color.textTertiary
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = DJDesignTokens.Font.body(15)
        valueLabel.textColor = DJDesignTokens.Color.textSecondary
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        [titleLabel, valueLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 72),
        ])

        return stack
    }

    private func makeAnalysisCard() -> UIView {
        let isAnalyzed = item.analysisStatus == .analyzed
        let summaryText = item.analysisSummary ?? defaultAnalysisSummaryText

        let card = makeDetailCard(radius: DJDesignTokens.Radius.extraLarge)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveDetailLayout.analysisCardSpacing

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeAnalysisHeader())
        stack.addArrangedSubview(makeAnalysisDisclaimerLabel())
        stack.addArrangedSubview(makeAnalysisSummaryPanel(summary: summaryText, isAnalyzed: isAnalyzed))
        stack.addArrangedSubview(makeInsightSection(title: "标签", iconName: "tag", values: item.tags, emptyText: "暂无标签"))
        stack.addArrangedSubview(makeInsightSection(title: "人物线索", iconName: "person.2", values: item.detectedPeople, emptyText: item.analysisStatus == .pending ? "等待识别" : "暂无人物线索"))
        stack.addArrangedSubview(makeInsightSection(title: "地点线索", iconName: "mappin.and.ellipse", values: item.detectedLocationClues, emptyText: item.analysisStatus == .pending ? "等待识别" : "暂无地点线索"))
        stack.addArrangedSubview(makeInsightSection(title: "场景线索", iconName: "camera.viewfinder", values: item.detectedSceneClues, emptyText: item.analysisStatus == .pending ? "等待识别" : "暂无场景线索"))
        if item.analysisStatus == .failed {
            stack.addArrangedSubview(makeAnalysisRetryButton())
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ArchiveDetailLayout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ArchiveDetailLayout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ArchiveDetailLayout.cardInset),
        ])

        return card
    }

    private var defaultAnalysisSummaryText: String {
        switch item.analysisStatus {
        case .failed:
            return "AI 分析暂不可用，可稍后重试。"
        case .retryable:
            return "AI 分析暂不可用，可稍后重试。"
        case .manual, .pending, .analyzing, .analyzed:
            return "生成本地分析后，会整理出可用于后续回响的人物、地点、场景和生活线索。"
        }
    }

    private var analysisStatusDisplayText: String {
        switch item.analysisStatus {
        case .analyzed:
            return "已生成"
        case .failed:
            return "分析失败"
        case .retryable:
            return "可重试"
        case .analyzing:
            return "分析中"
        case .manual, .pending:
            return "待生成"
        }
    }

    private var analysisSubtitleText: String {
        switch item.analysisStatus {
        case .analyzed:
            return "已整理为回响上下文"
        case .failed:
            return "云端已同步，可稍后重新分析"
        case .retryable:
            return "云端已同步，可稍后重新分析"
        case .analyzing:
            return "正在整理回响上下文"
        case .manual, .pending:
            return "生成后补全回响上下文"
        }
    }

    private func makeAnalysisHeader() -> UIView {
        let headerStack = UIStackView()
        headerStack.alignment = .center
        headerStack.spacing = ArchiveDetailLayout.headerStackSpacing

        let iconContainer = makeIconContainer(iconName: "sparkles")
        iconContainer.backgroundColor = item.analysisStatus == .analyzed
            ? DJDesignTokens.Color.accent.withAlphaComponent(0.22)
            : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 3

        let titleLabel = UILabel()
        titleLabel.text = "分析线索"
        titleLabel.font = DJDesignTokens.Font.title(20)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = analysisSubtitleText
        subtitleLabel.font = DJDesignTokens.Font.label(12)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary

        let analysisStatusLabel = makeBadge(
            text: "",
            textColor: item.analysisStatus == .analyzed ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.textSecondary,
            backgroundColor: item.analysisStatus == .analyzed
                ? DJDesignTokens.Color.accent.withAlphaComponent(0.18)
                : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        )
        analysisStatusLabel.text = analysisStatusDisplayText
        analysisStatusLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)
        headerStack.addArrangedSubview(iconContainer)
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(analysisStatusLabel)

        [headerStack, iconContainer, titleStack, titleLabel, subtitleLabel, analysisStatusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: ArchiveDetailLayout.analysisHeroIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: ArchiveDetailLayout.analysisHeroIconSize),
        ])

        return headerStack
    }

    private func makeAnalysisRetryButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(isRetryingRemoteAnalysis ? "重新分析中..." : "重新分析", for: .normal)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = DJDesignTokens.Color.accentDeep
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.18)
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        button.isEnabled = !isRetryingRemoteAnalysis
        button.alpha = isRetryingRemoteAnalysis ? 0.72 : 1
        button.accessibilityIdentifier = "archive-analysis-retry-button"
        button.accessibilityLabel = "重新分析"
        button.addTarget(self, action: #selector(retryAnalysisTapped), for: .touchUpInside)
        analysisRetryButton = button
        return button
    }

    private func makeAnalysisDisclaimerLabel() -> UILabel {
        let label = UILabel()
        label.text = Self.analysisDisclaimerText
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 0
        label.accessibilityIdentifier = "archive-analysis-disclaimer-label"
        return label
    }

    private func makeAnalysisSummaryPanel(summary: String, isAnalyzed: Bool) -> UIView {
        let summaryContainer = UIView()
        summaryContainer.backgroundColor = isAnalyzed
            ? DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.68)
            : DJDesignTokens.Color.surfaceLow.withAlphaComponent(0.76)
        summaryContainer.layer.cornerRadius = DJDesignTokens.Radius.large

        let accentLine = UIView()
        accentLine.backgroundColor = isAnalyzed
            ? DJDesignTokens.Color.accentDeep.withAlphaComponent(0.48)
            : DJDesignTokens.Color.divider.withAlphaComponent(0.70)
        accentLine.layer.cornerRadius = ArchiveDetailLayout.analysisAccentWidth / 2

        let summaryLabel = UILabel()
        summaryLabel.text = summary
        summaryLabel.font = DJDesignTokens.Font.body(16)
        summaryLabel.textColor = DJDesignTokens.Color.textSecondary
        summaryLabel.numberOfLines = 0

        summaryContainer.addSubview(accentLine)
        summaryContainer.addSubview(summaryLabel)
        [accentLine, summaryLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            accentLine.topAnchor.constraint(equalTo: summaryContainer.topAnchor, constant: ArchiveDetailLayout.analysisSummaryInset),
            accentLine.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor, constant: ArchiveDetailLayout.analysisSummaryInset),
            accentLine.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor, constant: -ArchiveDetailLayout.analysisSummaryInset),
            accentLine.widthAnchor.constraint(equalToConstant: ArchiveDetailLayout.analysisAccentWidth),

            summaryLabel.topAnchor.constraint(equalTo: summaryContainer.topAnchor, constant: ArchiveDetailLayout.analysisSummaryInset),
            summaryLabel.leadingAnchor.constraint(equalTo: accentLine.trailingAnchor, constant: 12),
            summaryLabel.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor, constant: -ArchiveDetailLayout.analysisSummaryInset),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor, constant: -ArchiveDetailLayout.analysisSummaryInset),
        ])

        return summaryContainer
    }

    private func makeInsightSection(
        title: String,
        iconName: String,
        values: [String],
        emptyText: String
    ) -> UIView {
        let section = UIView()
        section.backgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.72)
        section.layer.cornerRadius = DJDesignTokens.Radius.large

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ArchiveDetailLayout.analysisPanelSpacing

        let headerStack = UIStackView()
        headerStack.alignment = .center
        headerStack.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.72)
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.label(12)
        titleLabel.textColor = DJDesignTokens.Color.textTertiary

        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .leading

        let displayValues = values.isEmpty ? [emptyText] : values
        displayValues.forEach { value in
            chipStack.addArrangedSubview(makeBadge(
                text: value,
                textColor: values.isEmpty ? DJDesignTokens.Color.textTertiary : DJDesignTokens.Color.accentDeep,
                backgroundColor: values.isEmpty
                    ? DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.66)
                    : DJDesignTokens.Color.accent.withAlphaComponent(0.16)
            ))
        }
        let chipSpacer = UIView()
        chipSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chipSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chipStack.addArrangedSubview(chipSpacer)

        section.addSubview(stack)
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(UIView())
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(chipStack)

        [stack, headerStack, iconView, titleLabel, chipStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: section.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -14),

            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
        ])

        return section
    }

    private func makeIconContainer(iconName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let imageView = UIImageView(image: UIImage(systemName: iconName))
        imageView.tintColor = DJDesignTokens.Color.accentDeep
        imageView.contentMode = .scaleAspectFit

        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
        ])

        return container
    }

    private func makeDetailCard(radius: CGFloat) -> UIView {
        let card = DJComponentFactory.cardView(radius: radius)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42).cgColor
        return card
    }

    private func makeBadge(
        text: String,
        textColor: UIColor = DJDesignTokens.Color.accentDeep,
        backgroundColor: UIColor = DJDesignTokens.Color.surfaceLow
    ) -> UILabel {
        let label = DetailPaddingLabel(horizontalInset: 9, verticalInset: 5)
        label.text = text
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = textColor
        label.backgroundColor = backgroundColor
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    @objc private func analyzeArchiveItemTapped() {
        if item.analysisStatus == .failed {
            item.retryLocalAnalysis()
        }
        item.applyLocalAnalysisResult()
        let didPersist = repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)
        reloadContent()
        configureNavigationActions()
        showToast(didPersist ? "已生成本地分析" : "已生成本地分析预览", type: .success)
    }

    @objc private func editTimeLetterDraftTapped() {
        guard item.isTimeLetterDraft, canManageCurrentArchiveItem else { return }
        let payload = TimeLetterEntryPayload(
            note: item.note,
            openAt: item.timeLetterOpenAt ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            recipients: item.timeLetterRecipients,
            imageLocalPath: item.localPath
        )
        let entryViewController = MemoryArchiveTextEntryViewController(
            kind: .timeLetter,
            initialTimeLetterPayload: payload
        )
        entryViewController.onSaveDraftTimeLetter = { [weak self] payload in
            guard let self else { return }
            item = item.updatingTimeLetterDraft(
                note: payload.note,
                openAt: payload.openAt,
                recipients: payload.recipients,
                imageLocalPath: payload.imageLocalPath
            )
            _ = repository.update(item)
            reloadContent()
            showToast("草稿已更新", type: .success)
        }
        entryViewController.onSaveTimeLetter = { [weak self] payload in
            guard let self else { return }
            item = item.sealingTimeLetter(
                openAt: payload.openAt,
                recipients: payload.recipients,
                imageLocalPath: payload.imageLocalPath
            )
            _ = repository.update(item)
            reloadContent()
            showToast("时间信件已封存", type: .success)
        }
        present(entryViewController, animated: true)
    }

    @objc private func editTextArchiveTapped() {
        guard item.kind == .text, canManageCurrentArchiveItem else { return }
        let entryViewController = MemoryArchiveTextEntryViewController(
            kind: .text,
            initialText: item.note,
            textEntryTitle: "编辑文字",
            textEntrySubtitle: "调整这段自传内容，保存后会同步更新当前档案。",
            textSaveButtonTitle: "保存修改"
        )
        entryViewController.onSave = { [weak self] rawText in
            guard let self else { return }
            item.note = rawText
            item.title = "文字记忆"
            item.updatedAt = Date()
            item.analysisStatus = .manual
            item.analysisSummary = "这是一段手动封存的文字片段，可作为后续回响生成的语义线索。"
            if !item.tags.contains("文字片段") {
                item.tags.append("文字片段")
            }
            item.metadata["source"] = "manual_text"
            item.metadata["contentKind"] = "text"
            item.metadata["characterCount"] = "\(rawText.count)"
            item.metadata["storage"] = "local_user_defaults"
            _ = repository.update(item)
            reloadContent()
            configureNavigationActions()
            showToast("文字已更新", type: .success)
        }
        present(entryViewController, animated: true)
    }

    @objc private func sealTimeLetterDraftTapped() {
        guard item.isTimeLetterDraft, canManageCurrentArchiveItem else { return }
        item = item.sealingTimeLetterDraft()
        _ = repository.update(item)
        reloadContent()
        showToast("时间信件已封存", type: .success)
    }

    @objc private func deleteTimeLetterDraftTapped() {
        guard item.isTimeLetterDraft, canManageCurrentArchiveItem else { return }
        let alert = UIAlertController(
            title: "删除时间信件草稿？",
            message: "删除后不会触发投递，也不会同步到后端。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除草稿", style: .destructive) { [weak self] _ in
            guard let self else { return }
            _ = repository.remove(id: item.id)
            navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func requestMediaUploadIntentTapped() {
        guard item.isMediaUploadIntentEligible else {
            markMediaUploadFailure("缺少本地媒体文件")
            return
        }
        guard DreamJourneyBackendClient.shared.isArchiveMediaUploadIntentConfigured else {
            markMediaUploadFailure("后端未配置")
            return
        }
        guard effectiveArchiveMediaRuntimeCapability.uploadIntentAvailable,
              effectiveArchiveMediaRuntimeCapability.supports(kind: item.kind) else {
            markMediaUploadFailure("后端暂不支持该媒体类型")
            return
        }
        guard !effectiveArchiveMediaRuntimeCapability.requiresClientUpload else {
            markMediaUploadFailure("真实对象存储上传尚未开放")
            return
        }
        guard let payload = repository.archiveMediaUploadIntentPayload(for: item) else {
            markMediaUploadFailure("媒体上传参数不完整")
            return
        }

        isRequestingMediaUploadIntent = true
        item = item.markingMediaUploadPending()
        _ = repository.update(item, syncToBackend: false)
        reloadContent()

        DreamJourneyBackendClient.shared.requestArchiveMediaUploadIntent(payload: payload) { [weak self] result in
            guard let self else { return }
            isRequestingMediaUploadIntent = false
            switch result {
            case .success(let intent):
                guard !intent.requiresClientUpload else {
                    markMediaUploadFailure("真实对象存储上传尚未开放")
                    return
                }
                item = item.markingMediaUploadUploaded(intent: intent)
                _ = repository.update(item, syncToBackend: false)
                reloadContent()
                showToast("媒体元数据已同步", type: .success)
            case .failure(let error):
                markMediaUploadFailure(error.localizedDescription)
            }
        }
    }

    private func markMediaUploadFailure(_ reason: String) {
        isRequestingMediaUploadIntent = false
        item = item.markingMediaUploadFailed(reason.isEmpty ? "上传失败" : reason)
        _ = repository.update(item, syncToBackend: false)
        reloadContent()
        showToast("上传失败，可重试", type: .error)
    }

    private func refreshArchiveMediaRuntimeCapabilityIfNeeded() {
        guard item.kind == .audio || item.kind == .video else {
            return
        }
        guard !didRequestArchiveMediaRuntimeCapability else {
            return
        }
        didRequestArchiveMediaRuntimeCapability = true
        guard DreamJourneyBackendClient.shared.isArchiveMediaUploadIntentConfigured else {
            archiveMediaRuntimeCapability = ArchiveMediaRuntimeCapability.localFallback(isBackendConfigured: false)
            archiveMediaRuntimeErrorText = "后端媒体同步未配置"
            reloadContent()
            return
        }

        DreamJourneyBackendClient.shared.fetchArchiveMediaRuntimeCapability { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let capability):
                archiveMediaRuntimeCapability = capability
                archiveMediaRuntimeErrorText = nil
            case .failure:
                archiveMediaRuntimeCapability = ArchiveMediaRuntimeCapability.localFallback(isBackendConfigured: true)
                archiveMediaRuntimeErrorText = "后端能力读取失败，使用本地合同"
            }
            reloadContent()
        }
    }

    @objc private func retryAnalysisTapped() {
        requestRemoteImageAnalysisRetry()
    }

    private func requestRemoteImageAnalysisRetry() {
        guard item.kind == .photo else {
            showToast("该素材暂不支持云端重新分析", type: .info)
            return
        }
        guard DreamJourneyBackendClient.shared.isArchiveImageAnalysisConfigured else {
            showToast("AI 分析暂不可用，可稍后重试", type: .error)
            return
        }

        DreamJourneyBackendClient.shared.fetchArchiveImageAnalysisRuntimeCapability { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let capability):
                guard capability.canRunVisionAnalysis else {
                    markArchiveImageAnalysisUnavailable(capability: capability)
                    return
                }
                requestRemoteImageAnalysisRetryAfterRuntimeCheck()
            case .failure(let error):
                item.markAnalysisFailed(reason: archiveAnalysisFailureReason(error))
                _ = repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)
                reloadContent()
                configureNavigationActions()
                showToast("AI 分析暂不可用，可稍后重试", type: .error)
            }
        }
    }

    private func requestRemoteImageAnalysisRetryAfterRuntimeCheck() {
        guard let localPath = item.resolvedLocalFilePath,
              let image = UIImage(contentsOfFile: localPath),
              let imageBase64 = imageBase64ForRemoteArchiveAnalysis(image) else {
            showToast("缺少原始照片，无法重新分析", type: .error)
            return
        }

        isRetryingRemoteAnalysis = true
        item.retryLocalAnalysis()
        _ = repository.update(item, syncToBackend: false)
        reloadContent()
        configureNavigationActions()

        DreamJourneyBackendClient.shared.requestArchiveImageAnalysis(
            userId: currentArchiveAnalysisUserId,
            archiveItemId: item.id,
            imageBase64: imageBase64
        ) { [weak self] result in
            guard let self else { return }
            isRetryingRemoteAnalysis = false
            switch result {
            case .success(let object):
                item.applyRemoteImageAnalysisResult(object)
                _ = repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)
                reloadContent()
                configureNavigationActions()
                if item.analysisStatus.isRetryableFailureLike {
                    showToast("AI 分析暂不可用，可稍后重试", type: .error)
                } else {
                    showToast("已重新生成图像分析", type: .success)
                }
            case .failure(let error):
                item.markAnalysisFailed(reason: archiveAnalysisFailureReason(error))
                _ = repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)
                reloadContent()
                configureNavigationActions()
                showToast("AI 分析暂不可用，可稍后重试", type: .error)
            }
        }
    }

    private func markArchiveImageAnalysisUnavailable(capability: ArchiveImageAnalysisRuntimeCapability) {
        item.markAnalysisUnavailableFromRuntime(
            provider: capability.provider,
            fallbackMode: capability.fallbackMode,
            message: capability.availabilityDisplayText
        )
        _ = repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)
        reloadContent()
        configureNavigationActions()
        showToast(capability.availabilityDisplayText, type: .error)
    }

    private var currentArchiveAnalysisUserId: String {
        UserManager.shared.currentUser?.id ?? "user_001"
    }

    private func imageBase64ForRemoteArchiveAnalysis(_ image: UIImage) -> String? {
        image.jpegData(compressionQuality: 0.72)?.base64EncodedString()
    }

    private func archiveAnalysisFailureReason(_ error: Error) -> String {
        let normalized = error.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "backend_image_analysis_failed" : String(normalized.prefix(80))
    }

    @objc private func playAudioTapped() {
        guard let localPath = item.resolvedLocalFilePath else { return }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
            audioPlayButton?.setImage(UIImage(systemName: "play.fill"), for: .normal)
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: localPath))
            player.delegate = self
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            audioPlayButton?.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        } catch {
            showToast("音频加载失败", type: .error)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayButton?.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }

    private func audioDurationText() -> String {
        guard let localPath = item.resolvedLocalFilePath,
              let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: localPath)) else {
            return "已封存"
        }
        let totalSeconds = max(1, Int(player.duration.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
extension MemoryArchiveDetailViewController {
    func runUIQALocalAnalysisSmoke() {
        analyzeArchiveItemTapped()
    }

    func runUIQAArchiveFailedAnalysisRetrySmoke(completion: @escaping ([String: Any]) -> Void) {
        view.layoutIfNeeded()
        let retryButtonVisible = analysisRetryButton?.window != nil && analysisRetryButton?.isHidden == false
        let retryButtonEnabled = analysisRetryButton?.isEnabled == true
        let initialAnalysisStatus = item.analysisStatus.rawValue
        let initialAnalysisText = item.archiveAnalysisAvailabilityDisplayName ?? "missing"
        let initialCloudText = item.archiveBackendSyncDisplayName ?? "missing"

        if retryButtonEnabled {
            analysisRetryButton?.sendActions(for: .touchUpInside)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            guard let self else { return }
            let result: [String: Any] = [
                "retryButtonVisible": retryButtonVisible,
                "retryButtonEnabled": retryButtonEnabled,
                "retryActionFired": retryButtonEnabled,
                "backendConfigured": DreamJourneyBackendClient.shared.isArchiveImageAnalysisConfigured,
                "initialAnalysisStatus": initialAnalysisStatus,
                "finalAnalysisStatus": item.analysisStatus.rawValue,
                "initialAnalysisStateText": initialAnalysisText,
                "finalAnalysisStateText": item.archiveAnalysisAvailabilityDisplayName ?? "missing",
                "initialCloudStateText": initialCloudText,
                "finalCloudStateText": item.archiveBackendSyncDisplayName ?? "missing",
                "analysisRetryable": item.analysisRetryableForBackend,
                "analysisSummary": item.analysisSummary ?? "",
                "analysisFailureReason": item.metadata[MemoryArchiveItem.analysisFailureReasonMetadataKey] ?? "",
                "detectedPeopleCount": item.detectedPeople.count,
                "detectedLocationCount": item.detectedLocationClues.count,
                "detectedSceneCount": item.detectedSceneClues.count,
                "tagCount": item.tags.count,
            ]
            completion(result)
        }
    }
}
#endif

private final class DetailPaddingLabel: UILabel {
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

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + horizontalInset * 2,
            height: size.height + verticalInset * 2
        )
    }
}
