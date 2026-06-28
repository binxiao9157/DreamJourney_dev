import AVFoundation
import UIKit

final class EchoViewController: UIViewController {
    private let viewModel: EchoViewModel

    private let scenicView = EchoScenicParkView()
    private var digitalHumanLivePanelView: DigitalHumanLivePanelView?
    private var digitalHumanAudioLevelMeter: DigitalHumanAudioLevelMeter?
    private var digitalHumanRuntime: DigitalHumanRuntime?

    private let personaBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.9)
        view.layer.cornerRadius = 22
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.18).cgColor
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let personaAvatarView: UIView = {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.14)
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()

    private let personaIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = DJDesignTokens.Color.accentDeep
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let personaNameLabel: UILabel = {
        let label = UILabel()
        label.font = DJDesignTokens.Font.title(15)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let personaSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 1
        return label
    }()

    private let quoteBubble: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.92)
        view.layer.cornerRadius = 18
        view.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner,
            .layerMinXMaxYCorner
        ]
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.18).cgColor
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let quoteLabel: UILabel = {
        let label = UILabel()
        label.text = "\"我一直都在，风吹过树叶的声音就是我的回答。\""
        label.font = DJDesignTokens.Font.body(17)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let archiveContextStatusView: UIView = {
        let archiveContextStatusView = UIView()
        archiveContextStatusView.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.9)
        archiveContextStatusView.layer.cornerRadius = 16
        archiveContextStatusView.layer.borderWidth = 1
        archiveContextStatusView.layer.borderColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.16).cgColor
        archiveContextStatusView.isHidden = true
        archiveContextStatusView.alpha = 0
        archiveContextStatusView.isAccessibilityElement = false
        DJDesignTokens.applySoftShadow(to: archiveContextStatusView)
        return archiveContextStatusView
    }()

    private let archiveContextStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "档案线索正在参与回响"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoArchiveContextStatus"
        label.accessibilityLabel = "档案线索正在参与回响"
        return label
    }()

    private let digitalHumanStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.88)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let digitalHumanStatusTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "数字人回响"
        label.font = DJDesignTokens.Font.title(13)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoDigitalHumanStatusTitle"
        return label
    }()

    private let digitalHumanStatusDetailLabel: UILabel = {
        let label = UILabel()
        label.text = "素材已授权，无法加载时自动回到普通回响"
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoDigitalHumanStatusDetail"
        return label
    }()

    private let voiceStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.84)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        view.isHidden = true
        view.alpha = 0
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let voiceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "轻点话筒，慢慢说给我听"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoVoiceStatus"
        return label
    }()

    private lazy var micButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DJDesignTokens.Color.accentDeep
        button.tintColor = .white
        button.layer.cornerRadius = 28
        button.layer.shadowColor = DJDesignTokens.Color.accentDeep.cgColor
        button.layer.shadowOpacity = 0.24
        button.layer.shadowOffset = CGSize(width: 0, height: 10)
        button.layer.shadowRadius = 18
        button.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        button.accessibilityLabel = "开始语音"
        return button
    }()

    private let micRingView: UIView = {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.12)
        view.layer.cornerRadius = 38
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()

    private var micButtonBottomConstraint: NSLayoutConstraint?
    private var voiceStatusHeightConstraint: NSLayoutConstraint?
    private var currentState: EchoInteractionState = .idle
    private var transcriptEntries: [(text: String, isUser: Bool)] = []
    private var pendingAIText: String?
    private var digitalHumanReplyPrewarmWorkItem: DispatchWorkItem?
    private var digitalHumanProviderTextOverTimeoutWorkItem: DispatchWorkItem?
    private let digitalHumanConversation = DigitalHumanConversationCoordinator()
    private var hasRunTencentDigitalHumanTextDriveSmoke = false
    private var isStoppingForDelayedReply = false
    private var isStoppingVoiceCaptureManually = false
    private var showsVoiceSDKReadinessPreview = false
    private var backendRuntimeTokenApplied = false
    private var hasRequestedCloudDigitalHumanRuntime = false
    private static let digitalHumanReplyPrewarmShortDelay: TimeInterval = 0.18
    private static let digitalHumanReplyPrewarmDebounceDelay: TimeInterval = 0.24
    private static let tencentDigitalHumanTextOverTimeout: TimeInterval = 30
    private static let tencentDigitalHumanPostTextOverResumeDelay: TimeInterval = 1.2
    private static let tencentDigitalHumanLongReplyExtraResumeDelay: TimeInterval = 0.6
    private static let tencentDigitalHumanLongReplyCharacterThreshold = 56

    private var shouldShowDigitalHumanLivePanel: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("DJDisableDigitalHumanLivePanel") {
            return false
        }
        return FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)
            || arguments.contains("DJShowDigitalHumanLivePanel")
            || arguments.contains("DJRunDigitalHumanLivePanelSmoke")
            || arguments.contains("DJRunTencentDigitalHumanTextDriveSmoke")
    }

    private var shouldRunTencentDigitalHumanTextDriveSmoke: Bool {
        ProcessInfo.processInfo.arguments.contains("DJRunTencentDigitalHumanTextDriveSmoke")
    }

    init(viewModel: EchoViewModel = EchoViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        observeDigitalHumanContext()
        setupLayout()
        bindViewModel()
        updatePersonaBadge()
        seedTranscriptPreview()
        if !viewModel.restoreStoredDelayedReplyIfAvailable() {
            render(state: .idle)
        }
        renderArchiveContextStatus(viewModel.archiveContextStatus)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DialogEngineManager.shared.delegate = self
        if shouldShowDigitalHumanLivePanel {
            DialogEngineManager.shared.setLocalTTSPlaybackEnabled(false)
        }
        if !DialogEngineManager.shared.isEngineReady,
           !DreamJourneyBackendClient.shared.isRealtimeVoiceConfigConfigured {
            DialogEngineManager.shared.setup()
        }
        viewModel.refreshArchiveContextStatus()
        updatePersonaBadge()
        refreshTranscriptPreviewForCurrentContextIfIdle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareCloudDigitalHumanRuntimeIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if DialogEngineManager.shared.delegate === self {
            if DialogEngineManager.shared.isDialogActive {
                interruptDigitalHumanPlayback(reason: "viewWillDisappear")
                DialogEngineManager.shared.stopDialog()
                flushPendingAIReplyIfNeeded()
                ConversationMemoryManager.shared.endSession()
                viewModel.resetToIdle()
            }
            stopDigitalHumanAudioLevelMetering()
            resetDigitalHumanReplyDispatchState()
            DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true)
            digitalHumanRuntime?.interrupt()
            digitalHumanRuntime?.close()
            digitalHumanRuntime = nil
            hasRequestedCloudDigitalHumanRuntime = false
            DialogEngineManager.shared.delegate = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safeBottom = Self.systemBottomSafeInset
        micButtonBottomConstraint?.constant = -(WarmTabBarView.tabBarHeight + safeBottom + 28)
    }

    private static var systemBottomSafeInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    private func setupLayout() {
        if shouldShowDigitalHumanLivePanel {
            let digitalHumanLivePanelView = DigitalHumanLivePanelView()
            self.digitalHumanLivePanelView = digitalHumanLivePanelView
            digitalHumanAudioLevelMeter = DigitalHumanAudioLevelMeter(panelView: digitalHumanLivePanelView)
        }

        view.addSubview(scenicView)
        view.addSubview(personaBadgeView)
        view.addSubview(archiveContextStatusView)
        if let digitalHumanLivePanelView {
            view.addSubview(digitalHumanLivePanelView)
            view.addSubview(digitalHumanStatusView)
        }
        view.addSubview(quoteBubble)
        view.addSubview(voiceStatusView)
        view.addSubview(micRingView)
        view.addSubview(micButton)

        let personaTextStack = UIStackView(arrangedSubviews: [personaNameLabel, personaSubtitleLabel])
        personaTextStack.axis = .vertical
        personaTextStack.alignment = .leading
        personaTextStack.spacing = 2

        personaBadgeView.addSubview(personaAvatarView)
        personaBadgeView.addSubview(personaTextStack)
        personaAvatarView.addSubview(personaIconView)
        archiveContextStatusView.addSubview(archiveContextStatusLabel)
        let digitalHumanStatusStack = UIStackView(arrangedSubviews: [
            digitalHumanStatusTitleLabel,
            digitalHumanStatusDetailLabel
        ])
        digitalHumanStatusStack.axis = .vertical
        digitalHumanStatusStack.alignment = .center
        digitalHumanStatusStack.spacing = 2
        digitalHumanStatusView.addSubview(digitalHumanStatusStack)
        quoteBubble.addSubview(quoteLabel)
        voiceStatusView.addSubview(voiceStatusLabel)

        [
            scenicView,
            personaBadgeView,
            personaAvatarView,
            personaIconView,
            personaTextStack,
            archiveContextStatusView,
            archiveContextStatusLabel,
            digitalHumanStatusView,
            digitalHumanStatusTitleLabel,
            digitalHumanStatusDetailLabel,
            digitalHumanStatusStack,
            quoteBubble,
            quoteLabel,
            voiceStatusView,
            voiceStatusLabel,
            micRingView,
            micButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        digitalHumanLivePanelView?.translatesAutoresizingMaskIntoConstraints = false

        let micBottomConstraint = micButton.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -(WarmTabBarView.tabBarHeight + 28)
        )
        micButtonBottomConstraint = micBottomConstraint
        let voiceStatusHeight = voiceStatusView.heightAnchor.constraint(equalToConstant: 0)
        voiceStatusHeightConstraint = voiceStatusHeight

        NSLayoutConstraint.activate([
            scenicView.topAnchor.constraint(equalTo: view.topAnchor),
            scenicView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scenicView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scenicView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            personaBadgeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            personaBadgeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            personaBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            personaBadgeView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.78),

            personaAvatarView.topAnchor.constraint(equalTo: personaBadgeView.topAnchor, constant: 8),
            personaAvatarView.leadingAnchor.constraint(equalTo: personaBadgeView.leadingAnchor, constant: 8),
            personaAvatarView.bottomAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: -8),
            personaAvatarView.widthAnchor.constraint(equalToConstant: 40),
            personaAvatarView.heightAnchor.constraint(equalToConstant: 40),

            personaIconView.centerXAnchor.constraint(equalTo: personaAvatarView.centerXAnchor),
            personaIconView.centerYAnchor.constraint(equalTo: personaAvatarView.centerYAnchor),
            personaIconView.widthAnchor.constraint(equalToConstant: 22),
            personaIconView.heightAnchor.constraint(equalToConstant: 22),

            personaTextStack.leadingAnchor.constraint(equalTo: personaAvatarView.trailingAnchor, constant: 10),
            personaTextStack.centerYAnchor.constraint(equalTo: personaAvatarView.centerYAnchor),
            personaTextStack.trailingAnchor.constraint(equalTo: personaBadgeView.trailingAnchor, constant: -14),

            quoteBubble.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            quoteBubble.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            quoteBubble.bottomAnchor.constraint(equalTo: voiceStatusView.topAnchor, constant: -12),
            quoteBubble.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.74),

            archiveContextStatusView.leadingAnchor.constraint(equalTo: quoteBubble.leadingAnchor),
            archiveContextStatusView.bottomAnchor.constraint(equalTo: quoteBubble.topAnchor, constant: -12),
            archiveContextStatusView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            archiveContextStatusView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.78),

            archiveContextStatusLabel.topAnchor.constraint(equalTo: archiveContextStatusView.topAnchor, constant: 8),
            archiveContextStatusLabel.leadingAnchor.constraint(equalTo: archiveContextStatusView.leadingAnchor, constant: 14),
            archiveContextStatusLabel.trailingAnchor.constraint(equalTo: archiveContextStatusView.trailingAnchor, constant: -14),
            archiveContextStatusLabel.bottomAnchor.constraint(equalTo: archiveContextStatusView.bottomAnchor, constant: -8),

            quoteLabel.topAnchor.constraint(equalTo: quoteBubble.topAnchor, constant: 16),
            quoteLabel.leadingAnchor.constraint(equalTo: quoteBubble.leadingAnchor, constant: 16),
            quoteLabel.trailingAnchor.constraint(equalTo: quoteBubble.trailingAnchor, constant: -16),
            quoteLabel.bottomAnchor.constraint(equalTo: quoteBubble.bottomAnchor, constant: -16),

            voiceStatusView.centerXAnchor.constraint(equalTo: micButton.centerXAnchor),
            voiceStatusView.bottomAnchor.constraint(equalTo: micButton.topAnchor, constant: -8),
            voiceStatusView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            voiceStatusView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            voiceStatusHeight,

            voiceStatusLabel.centerYAnchor.constraint(equalTo: voiceStatusView.centerYAnchor),
            voiceStatusLabel.leadingAnchor.constraint(equalTo: voiceStatusView.leadingAnchor, constant: 16),
            voiceStatusLabel.trailingAnchor.constraint(equalTo: voiceStatusView.trailingAnchor, constant: -16),

            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            micBottomConstraint,
            micButton.widthAnchor.constraint(equalToConstant: 56),
            micButton.heightAnchor.constraint(equalToConstant: 56),

            micRingView.centerXAnchor.constraint(equalTo: micButton.centerXAnchor),
            micRingView.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
            micRingView.widthAnchor.constraint(equalToConstant: 76),
            micRingView.heightAnchor.constraint(equalToConstant: 76)
        ])

        if let digitalHumanLivePanelView {
            NSLayoutConstraint.activate([
                digitalHumanLivePanelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                digitalHumanLivePanelView.topAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: 14),
                digitalHumanLivePanelView.widthAnchor.constraint(equalToConstant: 190),
                digitalHumanLivePanelView.heightAnchor.constraint(equalTo: digitalHumanLivePanelView.widthAnchor),

                digitalHumanStatusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                digitalHumanStatusView.topAnchor.constraint(equalTo: digitalHumanLivePanelView.bottomAnchor, constant: 8),
                digitalHumanStatusView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.78),
                digitalHumanStatusStack.topAnchor.constraint(equalTo: digitalHumanStatusView.topAnchor, constant: 8),
                digitalHumanStatusStack.leadingAnchor.constraint(equalTo: digitalHumanStatusView.leadingAnchor, constant: 14),
                digitalHumanStatusStack.trailingAnchor.constraint(equalTo: digitalHumanStatusView.trailingAnchor, constant: -14),
                digitalHumanStatusStack.bottomAnchor.constraint(equalTo: digitalHumanStatusView.bottomAnchor, constant: -8)
            ])
        }
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state: state)
            }
        }

        viewModel.onTranscriptAppend = { [weak self] text, isUser in
            DispatchQueue.main.async {
                self?.appendTranscript(text: text, isUser: isUser)
            }
        }

        viewModel.onArchiveContextStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.renderArchiveContextStatus(status)
            }
        }
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
        viewModel.refreshArchiveContextStatus()
        updatePersonaBadge()
        refreshTranscriptPreviewForCurrentContextIfIdle()
    }

    private func updatePersonaBadge() {
        let context = DigitalHumanContextStore.shared.current
        let iconName = context.isSelfAssistant ? "sparkles" : "person.crop.circle.fill"
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        personaIconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
        personaAvatarView.backgroundColor = context.isSelfAssistant
            ? DJDesignTokens.Color.accent.withAlphaComponent(0.14)
            : DJDesignTokens.Color.accentDeep.withAlphaComponent(0.12)
        personaNameLabel.text = context.isSelfAssistant ? "自己 · AI 助手" : context.resolvedDisplayName
        personaSubtitleLabel.text = makePersonaBadgeSubtitle(context: context)
        personaBadgeView.accessibilityLabel = "\(personaNameLabel.text ?? "")，\(personaSubtitleLabel.text ?? "")"
        digitalHumanLivePanelView?.setPersona(
            name: personaNameLabel.text ?? context.resolvedDisplayName,
            subtitle: personaSubtitleLabel.text ?? ""
        )
    }

    private func makePersonaBadgeSubtitle(context: DigitalHumanContext) -> String {
        if context.isSelfAssistant {
            return "沉淀自己的个人数据库"
        }
        if let relation = context.relation?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relation.isEmpty {
            return "\(relation)的数字人回响"
        }
        return "家人数字人回响"
    }

    private func seedTranscriptPreview() {
        transcriptEntries = [
            (text: makeContextualOpeningLine(), isUser: false)
        ]
        reloadTranscriptPreview()
    }

    private func refreshTranscriptPreviewForCurrentContextIfIdle() {
        guard case .idle = currentState else { return }
        seedTranscriptPreview()
    }

    private func makeContextualOpeningLine() -> String {
        let context = DigitalHumanContextStore.shared.current
        if context.isSelfAssistant {
            return "\"我是你的 AI 助手，会陪你把自己的故事慢慢讲出来。\""
        }
        return "\"\(context.resolvedDisplayName)的回响已连接，想听你继续说说我们的故事。\""
    }

    private func appendTranscript(text: String, isUser: Bool) {
        transcriptEntries.append((text: text, isUser: isUser))
        if transcriptEntries.count > 4 {
            transcriptEntries.removeFirst(transcriptEntries.count - 4)
        }
        reloadTranscriptPreview()
    }

    private func reloadTranscriptPreview() {
        guard let latestEntry = transcriptEntries.last else {
            return
        }
        quoteLabel.text = latestEntry.text
    }

    private func render(state: EchoInteractionState) {
        currentState = state
        renderDigitalHumanLivePanel(for: state)

        switch state {
        case .idle:
            renderVoiceStatus(text: nil, isVisible: false)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "开始语音"
            )
            setMicPulse(active: false)
        case .starting:
            renderVoiceStatus(text: "正在准备麦克风", isVisible: true)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.surfaceContainer,
                isEnabled: false,
                accessibilityLabel: "正在准备麦克风"
            )
            setMicPulse(active: false)
        case .listening:
            renderVoiceStatus(text: "我在听，您慢慢说", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "停止语音"
            )
            setMicPulse(active: true)
        case .thinking:
            renderVoiceStatus(text: "我在想一想", isVisible: true)
            configureMicButton(
                systemName: "ellipsis",
                backgroundColor: DJDesignTokens.Color.surfaceContainer,
                isEnabled: false,
                accessibilityLabel: "我在想一想"
            )
            setMicPulse(active: false)
        case .waitingReply(let minutes):
            renderVoiceStatus(text: "先去窗边走走，约 \(minutes) 分钟后我再回信", isVisible: true)
            configureMicButton(
                systemName: "hourglass",
                backgroundColor: DJDesignTokens.Color.surfaceContainer,
                isEnabled: false,
                accessibilityLabel: "先去窗边走走，约 \(minutes) 分钟后我再回信"
            )
            setMicPulse(active: false)
        case .speaking:
            renderVoiceStatus(text: "回响正在抵达", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "停止回响"
            )
            setMicPulse(active: true)
        case .replied:
            if digitalHumanConversation.shouldResumeAfterProviderSpeech,
               routeEchoAudioThroughDigitalHuman {
                renderVoiceStatus(text: "正在恢复聆听", isVisible: true)
                configureMicButton(
                    systemName: "stop.fill",
                    backgroundColor: DJDesignTokens.Color.accentDeep,
                    isEnabled: true,
                    accessibilityLabel: "停止语音"
                )
                setMicPulse(active: true)
            } else {
                renderVoiceStatus(text: "回信已抵达", isVisible: true)
                configureMicButton(
                    systemName: "checkmark",
                    backgroundColor: DJDesignTokens.Color.accentDeep,
                    isEnabled: false,
                    accessibilityLabel: "回信已抵达"
                )
                setMicPulse(active: false)
            }
        case .error(let message):
            renderVoiceStatus(text: message, isVisible: true)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "重新开始语音"
            )
            setMicPulse(active: false)
        }
    }

    private func renderDigitalHumanLivePanel(for state: EchoInteractionState) {
        let liveState: DigitalHumanLiveInteractionState
        switch state {
        case .idle:
            liveState = .idle
        case .starting, .listening:
            liveState = .listening
        case .thinking, .waitingReply:
            liveState = .thinking
        case .speaking, .replied:
            liveState = .speaking
        case .error:
            liveState = .failed
        }
        digitalHumanLivePanelView?.setInteractionState(liveState)
        if liveState == .idle || liveState == .stopped || liveState == .failed {
            stopDigitalHumanAudioLevelMetering()
        }
    }

    private func startSDKTTSPlaybackFallback() {
        guard shouldShowDigitalHumanLivePanel else { return }
        digitalHumanAudioLevelMeter?.startSDKTTSPlaybackFallback()
    }

    private func cachedLipSyncTimelineForEchoReply(_ text: String) -> DigitalHumanLipSyncTimeline? {
        guard shouldShowDigitalHumanLivePanel else { return nil }
        return MemoirTTSService.shared.getCachedLipSyncTimeline(forText: text)
    }

    @discardableResult
    private func applyCachedLipSyncTimelineForEchoReply(_ text: String) -> Bool {
        guard let timeline = cachedLipSyncTimelineForEchoReply(text) else {
            return false
        }
        stopDigitalHumanAudioLevelMetering(resetLevel: false)
        digitalHumanLivePanelView?.applyPlaybackEvent(.visemeTimeline(timeline))
        return true
    }

    private func stopDigitalHumanAudioLevelMetering(resetLevel: Bool = true) {
        digitalHumanAudioLevelMeter?.stop(resetLevel: resetLevel)
    }

    private var tencentCloudRenderProvidesAudibleTTS: Bool {
        // Digital-human mode has a single audio owner: Tencent cloud render.
        // Ordinary Echo keeps the existing local Volcengine TTS path.
        return true
    }

    private var tencentDigitalHumanProviderCanOwnAudio: Bool {
        guard let digitalHumanRuntime,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
              digitalHumanRuntime.profile != nil else {
            return false
        }
        switch digitalHumanRuntime.state {
        case .ready, .buffering, .speaking:
            return true
        default:
            return false
        }
    }

    private var tencentDigitalHumanAudioRouteReserved: Bool {
        guard shouldShowDigitalHumanLivePanel,
              let digitalHumanRuntime,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
              digitalHumanRuntime.profile != nil,
              tencentCloudRenderProvidesAudibleTTS else {
            return false
        }
        switch digitalHumanRuntime.state {
        case .preparing, .connecting, .ready, .buffering, .speaking:
            return true
        default:
            return false
        }
    }

    private var routeEchoAudioThroughDigitalHuman: Bool {
        guard shouldShowDigitalHumanLivePanel,
              tencentDigitalHumanAudioRouteReserved,
              tencentCloudRenderProvidesAudibleTTS else {
            return false
        }
        return true
    }

    private var shouldDriveTencentVisualLipSync: Bool {
        guard shouldShowDigitalHumanLivePanel,
              let digitalHumanRuntime,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
              digitalHumanRuntime.profile != nil else {
            return false
        }
        return true
    }

    private var shouldDispatchEchoReplyToTencentProvider: Bool {
        routeEchoAudioThroughDigitalHuman && tencentDigitalHumanProviderCanOwnAudio
    }

    private func applyEchoAudioRoutePolicy() {
        let shouldRouteThroughDigitalHuman = routeEchoAudioThroughDigitalHuman
        if shouldRouteThroughDigitalHuman {
            DialogEngineManager.shared.setLocalTTSPlaybackEnabled(false)
            digitalHumanStatusDetailLabel.text = "腾讯数智人负责声音与口型同步"
            print("[TencentDigitalHuman] echo audio route=tencentDigitalHuman")
        } else {
            if !tencentDigitalHumanAudioRouteReserved {
                DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true)
            }
            if shouldShowDigitalHumanLivePanel,
               let digitalHumanRuntime,
               digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
               digitalHumanRuntime.profile != nil {
                digitalHumanStatusDetailLabel.text = "数字人暂未接管声音，已回到普通回响"
            }
            print("[TencentDigitalHuman] echo audio route=volcengineLocalTTS")
        }
    }

    private func prepareCloudDigitalHumanRuntimeIfNeeded() {
        guard shouldShowDigitalHumanLivePanel,
              digitalHumanRuntime == nil,
              hasRequestedCloudDigitalHumanRuntime == false else {
            return
        }
        hasRequestedCloudDigitalHumanRuntime = true
        digitalHumanStatusDetailLabel.text = "正在连接腾讯数智人"
        digitalHumanLivePanelView?.showProviderPlaceholder("正在连接腾讯数智人")

        DreamJourneyBackendClient.shared.fetchDigitalHumanRuntimeCapability { [weak self] result in
            switch result {
            case .success(let capability):
                self?.createCloudDigitalHumanSession(capability: capability)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.digitalHumanStatusDetailLabel.text = "数字人配置读取失败，已回到普通回响"
                    self?.digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                    self?.applyEchoAudioRoutePolicy()
                    print("[TencentDigitalHuman] runtime capability failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func createCloudDigitalHumanSession(capability: DigitalHumanRuntimeCapability) {
        let context = DigitalHumanContextStore.shared.current
        let userId = UserManager.shared.currentUser?.id ?? context.viewerUserId ?? "ios-device-qa"
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        DreamJourneyBackendClient.shared.createDigitalHumanSession(
            userId: userId,
            personaId: context.ownerId,
            scene: "echo",
            deviceId: deviceId,
            lifecycleMode: context.mode
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCloudDigitalHumanSession(result, capability: capability)
            }
        }
    }

    private func handleCloudDigitalHumanSession(
        _ result: Result<DigitalHumanSessionContract, Error>,
        capability: DigitalHumanRuntimeCapability
    ) {
        switch result {
        case .success(let contract):
            let context = DigitalHumanContextStore.shared.current
            let profile = contract.toDigitalHumanProfile(displayName: context.resolvedDisplayName)
            let runtimeSelection = DigitalHumanRuntimeFactory.makeRuntime(
                for: contract,
                capability: capability
            )
            let runtime = runtimeSelection.runtime
            digitalHumanRuntime = runtime
            bindDigitalHumanRuntimeState(runtime)

            guard runtimeSelection.isRealSDKBacked else {
                digitalHumanStatusDetailLabel.text = "腾讯 SDK 暂不可用，已回到普通回响"
                digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                applyEchoAudioRoutePolicy()
                print("[TencentDigitalHuman] fallback=\(runtimeSelection.fallbackReason ?? "unknown")")
                return
            }

            digitalHumanLivePanelView?.hostProviderView(runtime.contentView)
            do {
                try runtime.configure(profile)
                applyEchoAudioRoutePolicy()
                try runtime.open()
                digitalHumanStatusDetailLabel.text = "腾讯云渲染连接中"
                applyEchoAudioRoutePolicy()
            } catch {
                digitalHumanStatusDetailLabel.text = "腾讯数智人打开失败，已回到普通回响"
                digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                applyEchoAudioRoutePolicy()
                print("[TencentDigitalHuman] open failed: \(error.localizedDescription)")
            }
        case .failure(let error):
            digitalHumanStatusDetailLabel.text = "数字人会话创建失败，已回到普通回响"
            digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
            applyEchoAudioRoutePolicy()
            print("[TencentDigitalHuman] session failed: \(error.localizedDescription)")
        }
    }

    private func normalizedDigitalHumanReplyText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func digitalHumanReplyLooksComplete(_ text: String) -> Bool {
        guard let lastCharacter = text.last else { return false }
        return ["。", "！", "？", ".", "!", "?"].contains(String(lastCharacter))
    }

    private func tencentDigitalHumanDialogResumeDelay(for text: String?) -> TimeInterval {
        let characterCount = text?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
        guard characterCount > Self.tencentDigitalHumanLongReplyCharacterThreshold else {
            return Self.tencentDigitalHumanPostTextOverResumeDelay
        }
        return Self.tencentDigitalHumanPostTextOverResumeDelay + Self.tencentDigitalHumanLongReplyExtraResumeDelay
    }

    private func scheduleDigitalHumanReplyPrewarm(_ text: String) {
        let normalizedText = normalizedDigitalHumanReplyText(text)
        guard shouldShowDigitalHumanLivePanel,
              shouldDispatchEchoReplyToTencentProvider,
              !viewModel.isWaitingForDelayedReply,
              !normalizedText.isEmpty else {
            return
        }

        cancelDigitalHumanReplyPrewarm()
        let delay = digitalHumanReplyLooksComplete(normalizedText)
            ? Self.digitalHumanReplyPrewarmShortDelay
            : Self.digitalHumanReplyPrewarmDebounceDelay
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.digitalHumanReplyPrewarmWorkItem = nil
            self.sendEchoReplyToDigitalHumanRuntimeIfReady(normalizedText, source: "chatStreamingPrewarm")
        }
        digitalHumanReplyPrewarmWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        print("[TencentDigitalHuman] scheduled reply prewarm source=chatStreamingPrewarm delay=\(String(format: "%.2f", delay)) textLength=\(normalizedText.count)")
    }

    private func cancelDigitalHumanReplyPrewarm() {
        digitalHumanReplyPrewarmWorkItem?.cancel()
        digitalHumanReplyPrewarmWorkItem = nil
    }

    private func resetDigitalHumanReplyDispatchState() {
        digitalHumanConversation.reset(
            cancelPrewarm: cancelDigitalHumanReplyPrewarm,
            cancelTextOverTimeout: cancelTencentDigitalHumanTextOverTimeout
        )
    }

    private func prepareAudioSessionForTencentProviderPlayback(preserveRecordingCategory: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord || session.mode != .voiceChat {
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .allowBluetooth]
                )
            }
            try session.setActive(true)
            print(
                "[TencentDigitalHuman] AVAudioSession prepared for provider playback " +
                "preserveRecordingCategory=\(preserveRecordingCategory) category=playAndRecord"
            )
        } catch {
            print("[TencentDigitalHuman] AVAudioSession provider playback prepare failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func pauseDialogEngineForTencentProviderSpeechIfNeeded() -> Bool {
        guard routeEchoAudioThroughDigitalHuman,
              DialogEngineManager.shared.isDialogActive else {
            return false
        }
        digitalHumanConversation.markPausingForProviderSpeech()
        DialogEngineManager.shared.stopDialog()
        print("[TencentDigitalHuman] paused DialogEngine before provider speech")
        return true
    }

    @discardableResult
    private func resumeDialogEngineAfterTencentProviderSpeechIfNeeded(reason: String) -> Bool {
        guard digitalHumanConversation.consumeResumeAfterProviderSpeech() else {
            return false
        }
        guard shouldShowDigitalHumanLivePanel,
              view.window != nil else {
            return true
        }
        DialogEngineManager.shared.delegate = self
        if DialogEngineManager.shared.isDialogActive {
            DialogEngineManager.shared.stopDialog()
        }
        resumeVoiceCaptureAfterTencentProviderSpeech(reason: reason)
        print("[TencentDigitalHuman] resumed DialogEngine listening after provider speech reason=\(reason)")
        return true
    }

    private func resumeVoiceCaptureAfterTencentProviderSpeech(reason: String) {
        DialogEngineManager.shared.delegate = self
        resetDigitalHumanReplyDispatchState()
        muteTencentProviderRemoteAudioForUserCapture(reason: reason)
        viewModel.beginVoiceInteraction()
        applyEchoAudioRoutePolicy()
        if DialogEngineManager.shared.isEngineReady {
            DialogEngineManager.shared.startDialog(sendsGreeting: false)
        } else {
            configureVoiceRuntimeThenStart()
        }
        print("[TencentDigitalHuman] resume voice capture after provider speech reason=\(reason)")
    }

    @discardableResult
    private func muteTencentProviderRemoteAudioForUserCapture(reason: String) -> Bool {
        guard tencentDigitalHumanAudioRouteReserved,
              let cloudRuntime = digitalHumanRuntime as? TencentDigitalHumanCloudRuntime else {
            return false
        }
        stopDigitalHumanAudioLevelMetering()
        cloudRuntime.setRemoteAudioMuted(true)
        print("[TencentDigitalHuman] muted provider remote audio before user capture reason=\(reason)")
        return true
    }

    private func sendEchoReplyToDigitalHumanRuntimeIfReady(_ text: String, source: String) {
        let normalizedText = normalizedDigitalHumanReplyText(text)
        guard shouldShowDigitalHumanLivePanel,
              shouldDispatchEchoReplyToTencentProvider,
              let digitalHumanRuntime,
              digitalHumanRuntime.profile != nil,
              !normalizedText.isEmpty else {
            return
        }
        guard !digitalHumanConversation.isDuplicateReply(normalizedText) else {
            print("[TencentDigitalHuman] skipped duplicate reply text source=\(source) textLength=\(normalizedText.count)")
            return
        }
        if let activeTencentDigitalHumanRequestID = digitalHumanConversation.activeRequestID {
            print(
                "[TencentDigitalHuman] skipped new request while provider is speaking " +
                "source=\(source) activeRequestID=\(activeTencentDigitalHumanRequestID) " +
                "newLength=\(normalizedText.count)"
            )
            return
        }
        do {
            let requestID = makeTencentDigitalHumanRequestID()
            let turnID = ensureCurrentEchoTurnID()
            let pausedDialogEngine = pauseDialogEngineForTencentProviderSpeechIfNeeded()
            prepareAudioSessionForTencentProviderPlayback(preserveRecordingCategory: pausedDialogEngine)
            try digitalHumanRuntime.sendTextChunk(normalizedText, requestID: requestID, sequence: 1, isFinal: true)
            digitalHumanConversation.beginProviderRequest(
                requestID: requestID,
                replyText: normalizedText,
                turnID: turnID,
                keepsPendingReply: routeEchoAudioThroughDigitalHuman
            )
            scheduleTencentDigitalHumanTextOverTimeout(requestID: requestID, source: source)
            print("[TencentDigitalHuman] sent reply text turnID=\(turnID) source=\(source) requestID=\(requestID) textLength=\(normalizedText.count)")
        } catch {
            resumeDialogEngineAfterTencentProviderSpeechIfNeeded(reason: "sendTextFailed")
            print("[TencentDigitalHuman] send text failed source=\(source): \(error.localizedDescription)")
        }
    }

    private func ensureCurrentEchoTurnID() -> String {
        digitalHumanConversation.ensureTurnID(makeID: makeTencentDigitalHumanRequestID)
    }

    private func makeTencentDigitalHumanRequestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private func scheduleTencentDigitalHumanTextOverTimeout(requestID: String, source: String) {
        cancelTencentDigitalHumanTextOverTimeout()
        let turnID = ensureCurrentEchoTurnID()
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleTencentDigitalHumanTextOverTimeout(requestID: requestID)
        }
        digitalHumanProviderTextOverTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.tencentDigitalHumanTextOverTimeout,
            execute: workItem
        )
        print(
            "[TencentDigitalHuman] scheduled TextOver timeout " +
            "turnID=\(turnID) source=\(source) requestID=\(requestID) " +
            "timeout=\(Self.tencentDigitalHumanTextOverTimeout)"
        )
    }

    private func cancelTencentDigitalHumanTextOverTimeout() {
        digitalHumanProviderTextOverTimeoutWorkItem?.cancel()
        digitalHumanProviderTextOverTimeoutWorkItem = nil
    }

    private func handleTencentDigitalHumanTextOverTimeout(requestID: String) {
        guard digitalHumanConversation.activeRequestID == requestID else {
            print(
                "[TencentDigitalHuman] ignored stale TextOver timeout " +
                "turnID=\(digitalHumanConversation.currentTurnID ?? "unknown") requestID=\(requestID) " +
                "activeRequestID=\(digitalHumanConversation.activeRequestID ?? "none")"
            )
            return
        }

        cancelTencentDigitalHumanTextOverTimeout()
        let turnID = digitalHumanConversation.currentTurnID ?? "unknown"
        digitalHumanConversation.clearProviderRequest()
        stopDigitalHumanAudioLevelMetering()
        digitalHumanRuntime?.interrupt()
        viewModel.markReplyDelivered()
        print("[TencentDigitalHuman] TextOver timeout turnID=\(turnID) requestID=\(requestID); recovered Echo state")

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tencentDigitalHumanPostTextOverResumeDelay) { [weak self] in
            guard let self else { return }
            if self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(reason: "providerTextOverTimeout") {
                return
            }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
            } else {
                self.viewModel.resetToIdle()
            }
        }
    }

    private func interruptDigitalHumanPlayback(reason: String) {
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        digitalHumanConversation.clearProviderRequestAndResumeState()
        if let cloudRuntime = digitalHumanRuntime as? TencentDigitalHumanCloudRuntime {
            cloudRuntime.interruptPlaybackIfNeeded(reason: reason)
        } else {
            digitalHumanRuntime?.interrupt()
        }
        stopDigitalHumanAudioLevelMetering()
        print("[TencentDigitalHuman] interrupted provider playback turnID=\(digitalHumanConversation.currentTurnID ?? "unknown") reason=\(reason)")
    }

    private var hasTencentDigitalHumanProviderSpeechInFlight: Bool {
        digitalHumanConversation.hasProviderSpeechInFlight
    }

    private var shouldInterruptTencentDigitalHumanOnUserStop: Bool {
        digitalHumanConversation.shouldInterruptOnUserStop(routeEchoAudioThroughDigitalHuman: routeEchoAudioThroughDigitalHuman)
    }

    private func preserveTencentProviderSessionAfterLocalDialogStop(reason: String) {
        cancelDigitalHumanReplyPrewarm()
        digitalHumanConversation.clearResumeState()
        stopDigitalHumanAudioLevelMetering()
        print(
            "[TencentDigitalHuman] preserved provider session after local dialog stop " +
            "turnID=\(digitalHumanConversation.currentTurnID ?? "unknown") reason=\(reason) " +
            "providerSpeechInFlight=\(hasTencentDigitalHumanProviderSpeechInFlight)"
        )
    }

    @discardableResult
    private func startUIQAMeteredPlayback() -> Bool {
        guard shouldShowDigitalHumanLivePanel else { return false }
        do {
            try digitalHumanAudioLevelMeter?.startUIQAMeteredPlayback()
            return true
        } catch {
            print("[Echo] digital human UIQA metered playback failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    private func startUIQAMockVisemeTimeline() -> Bool {
        guard shouldShowDigitalHumanLivePanel else { return false }
        guard let synthesis = makeUIQAMockSynthesisResultWithVisemeTimeline(),
              let event = synthesis.lipSyncPlaybackEvent else {
            digitalHumanLivePanelView?.setMouthShape("neutral", intensity: 0, source: .providerVisemeTimeline)
            return false
        }
        digitalHumanLivePanelView?.applyPlaybackEvent(event)
        return true
    }

    private func makeUIQAMockSynthesisResultWithVisemeTimeline() -> VoiceCloneSynthesisResult? {
        let timeline = DigitalHumanLipSyncTimeline.makeUIQAMockProviderTimeline()
        guard let timelineData = try? JSONEncoder().encode(timeline),
              let timelineJSON = try? JSONSerialization.jsonObject(with: timelineData) as? [String: Any] else {
            return nil
        }

        return VoiceCloneSynthesisResult(json: [
            "voiceProfileId": "S_mock_digital_human_viseme",
            "providerMode": "mockProviderVisemeTimeline",
            "visemeTimeline": timelineJSON,
            "audio": [
                "encoding": "base64",
                "format": "mp3",
                "data": "TU9DS19BVURJTw==",
                "byteCount": 10
            ]
        ])
    }

    private func renderVoiceStatus(
        text: String?,
        isVisible: Bool,
        accessibilityIdentifier: String = "echoVoiceStatus"
    ) {
        voiceStatusLabel.text = text
        voiceStatusLabel.accessibilityLabel = text
        voiceStatusLabel.accessibilityIdentifier = accessibilityIdentifier
        voiceStatusHeightConstraint?.constant = isVisible ? 32 : 0
        voiceStatusView.isHidden = !isVisible
        voiceStatusView.alpha = isVisible ? 1 : 0
    }

    private func renderArchiveContextStatus(_ status: EchoArchiveContextStatus) {
        archiveContextStatusView.isHidden = !status.shouldShowArchiveContextIndicator
        archiveContextStatusView.alpha = status.shouldShowArchiveContextIndicator ? 1 : 0
        guard let text = status.indicatorText else {
            archiveContextStatusLabel.text = nil
            archiveContextStatusLabel.accessibilityLabel = nil
            return
        }
        archiveContextStatusLabel.text = text
        archiveContextStatusLabel.accessibilityLabel = text
    }

    private func configureMicButton(
        systemName: String,
        backgroundColor: UIColor,
        isEnabled: Bool,
        accessibilityLabel: String
    ) {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        micButton.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        micButton.backgroundColor = backgroundColor
        micButton.tintColor = isEnabled || backgroundColor == DJDesignTokens.Color.accentDeep
            ? .white
            : DJDesignTokens.Color.textSecondary
        micButton.isEnabled = isEnabled
        micButton.alpha = isEnabled ? 1 : 0.86
        micButton.accessibilityLabel = accessibilityLabel
    }

    private func setMicPulse(active: Bool) {
        micRingView.layer.removeAnimation(forKey: "echoPulse")

        guard active else {
            micRingView.transform = .identity
            micRingView.alpha = 0
            return
        }

        micRingView.alpha = 1
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.92
        pulse.toValue = 1.08
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        micRingView.layer.add(pulse, forKey: "echoPulse")
    }

    @objc private func micTapped() {
        switch currentState {
        case .listening, .thinking, .speaking:
            stopVoiceCapture()
        case .replied where digitalHumanConversation.shouldResumeAfterProviderSpeech:
            stopVoiceCapture()
        case .error:
            viewModel.retryAfterError()
            startVoiceCapture()
        default:
            startVoiceCapture()
        }
    }

    private func startVoiceCapture() {
        MicrophonePermissionManager.shared.requestPermission { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard granted else {
                    MicrophonePermissionManager.shared.showPermissionDeniedAlert(on: self)
                    self.viewModel.fail("需要麦克风权限，才能听见您的声音")
                    return
                }
                DialogEngineManager.shared.delegate = self
                self.pendingAIText = nil
                self.resetDigitalHumanReplyDispatchState()
                self.viewModel.prepareVoiceInteraction()
                if self.prepareTencentProviderForUserCaptureIfNeeded() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.configureVoiceRuntimeThenStart()
                    }
                } else {
                    self.configureVoiceRuntimeThenStart()
                }
            }
        }
    }

    private func bindDigitalHumanRuntimeState(_ runtime: DigitalHumanRuntime) {
        runtime.onStateChange = { [weak self, weak runtime] state in
            DispatchQueue.main.async {
                guard let self,
                      runtime === self.digitalHumanRuntime else {
                    return
                }
                self.handleDigitalHumanRuntimeStateChange(state)
            }
        }
    }

    private func handleDigitalHumanRuntimeStateChange(_ state: DigitalHumanSessionState) {
        switch state {
        case .speaking:
            digitalHumanLivePanelView?.setInteractionState(.speaking)
            if case .speaking = currentState {
                renderVoiceStatus(text: "腾讯数智人正在回响", isVisible: true)
            }
        case .ready:
            applyEchoAudioRoutePolicy()
            completeTencentDigitalHumanReplyIfNeeded()
            runTencentDigitalHumanTextDriveSmokeIfNeeded(trigger: "runtimeReady")
        case .interrupting, .closed:
            stopDigitalHumanAudioLevelMetering()
        case .failed(let code):
            degradeTencentDigitalHumanRoute(reason: code)
        default:
            break
        }
    }

    @discardableResult
    private func prepareTencentProviderForUserCaptureIfNeeded() -> Bool {
        guard tencentDigitalHumanAudioRouteReserved,
              let digitalHumanRuntime,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime else {
            return false
        }

        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        digitalHumanConversation.clearProviderRequestAndResumeState()
        stopDigitalHumanAudioLevelMetering()
        (digitalHumanRuntime as? TencentDigitalHumanCloudRuntime)?.setRemoteAudioMuted(true)
        digitalHumanRuntime.interrupt()
        print("[TencentDigitalHuman] muted provider audio before user capture; provider view preserved")
        return true
    }

    private func degradeTencentDigitalHumanRoute(reason: String) {
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        digitalHumanConversation.clearForRouteFailure()
        stopDigitalHumanAudioLevelMetering()

        let failedRuntime = digitalHumanRuntime
        digitalHumanRuntime = nil
        digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
        digitalHumanStatusDetailLabel.text = "数字人声音暂不可用，已回到普通回响"
        DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true)
        failedRuntime?.close()
        print("[TencentDigitalHuman] route fallback after runtime failure turnID=\(digitalHumanConversation.currentTurnID ?? "unknown"): \(reason)")
    }

    private func completeTencentDigitalHumanReplyIfNeeded() {
        guard routeEchoAudioThroughDigitalHuman,
              let completion = digitalHumanConversation.completeProviderRequest() else {
            return
        }

        let resumeDelay = tencentDigitalHumanDialogResumeDelay(for: completion.replyText)
        cancelTencentDigitalHumanTextOverTimeout()
        stopDigitalHumanAudioLevelMetering()
        viewModel.markReplyDelivered()
        print(
            "[TencentDigitalHuman] TextOver completed turnID=\(completion.turnID) " +
            "requestID=\(completion.requestID) textLength=\(completion.replyText?.count ?? 0) " +
            "resumeDelay=\(String(format: "%.2f", resumeDelay))"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + resumeDelay) { [weak self] in
            guard let self else { return }
            if self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(reason: "providerTextOver") {
                return
            }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
            } else {
                self.viewModel.resetToIdle()
            }
        }
    }

    private func runTencentDigitalHumanTextDriveSmokeIfNeeded(trigger: String) {
        guard shouldRunTencentDigitalHumanTextDriveSmoke,
              !hasRunTencentDigitalHumanTextDriveSmoke,
              routeEchoAudioThroughDigitalHuman,
              digitalHumanRuntime?.profile != nil,
              digitalHumanConversation.activeRequestID == nil else {
            return
        }
        hasRunTencentDigitalHumanTextDriveSmoke = true
        let text = "真机数字人文本驱动测试。请用腾讯数智人说出这句话。"
        viewModel.receiveAIReply(text)
        sendEchoReplyToDigitalHumanRuntimeIfReady(text, source: "trueDeviceTextDriveSmoke")
        print("[TencentDigitalHuman][QA] true device text-drive smoke triggered by \(trigger)")
    }

    private func configureVoiceRuntimeThenStart() {
        guard DreamJourneyBackendClient.shared.isRealtimeVoiceConfigConfigured else {
            backendRuntimeTokenApplied = false
            renderVoiceSDKReadinessPreviewIfNeeded()
            startDialogWithLocalVoiceFallback()
            return
        }

        let userId = UserManager.shared.currentUser?.id
            ?? UIDevice.current.identifierForVendor?.uuidString
            ?? "anonymous-ios-user"
        DreamJourneyBackendClient.shared.fetchRealtimeVoiceConfig(userId: userId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let runtimeConfig):
                if DialogEngineManager.shared.configure(runtimeConfig: runtimeConfig) {
                    self.backendRuntimeTokenApplied = true
                    self.renderVoiceSDKReadinessPreviewIfNeeded()
                    self.applyEchoAudioRoutePolicy()
                    DialogEngineManager.shared.startDialog(
                        sendsGreeting: !self.routeEchoAudioThroughDigitalHuman
                    )
                } else {
                    self.backendRuntimeTokenApplied = false
                    self.renderVoiceSDKReadinessPreviewIfNeeded()
                    self.startDialogWithLocalVoiceFallback()
                }
            case .failure(let error):
                print("[Echo] backend voice runtime config failed, fallback to local build settings: \(error.localizedDescription)")
                self.backendRuntimeTokenApplied = false
                self.renderVoiceSDKReadinessPreviewIfNeeded()
                self.startDialogWithLocalVoiceFallback()
            }
        }
    }

    private func startDialogWithLocalVoiceFallback() {
        applyEchoAudioRoutePolicy()
        DialogEngineManager.shared.startDialog(
            sendsGreeting: !routeEchoAudioThroughDigitalHuman
        )
    }

    private func currentVoiceSDKReadinessSummary() -> VoiceSDKReadinessSummary {
        VoiceSDKReadinessSummary.current(
            backendRuntimeConfigured: DreamJourneyBackendClient.shared.isRealtimeVoiceConfigConfigured,
            backendRuntimeTokenApplied: backendRuntimeTokenApplied,
            localConfigReady: DialogEngineManager.shared.currentConfigurationIsProductionReady,
            productionVoiceSDKQualityVerified: false
        )
    }

    private func renderVoiceSDKReadinessPreviewIfNeeded() {
        guard showsVoiceSDKReadinessPreview else { return }
        let summary = currentVoiceSDKReadinessSummary()
        renderVoiceStatus(
            text: summary.title,
            isVisible: true,
            accessibilityIdentifier: "echoVoiceSDKReadinessStatus"
        )
    }

    private func stopVoiceCapture() {
        isStoppingVoiceCaptureManually = true
        if shouldInterruptTencentDigitalHumanOnUserStop {
            interruptDigitalHumanPlayback(reason: "userStop")
        } else {
            preserveTencentProviderSessionAfterLocalDialogStop(reason: "userStop")
        }
        if DialogEngineManager.shared.isDialogActive {
            DialogEngineManager.shared.stopDialog()
        } else {
            isStoppingVoiceCaptureManually = false
            if !hasTencentDigitalHumanProviderSpeechInFlight {
                resetDigitalHumanReplyDispatchState()
            }
            viewModel.resetToIdle()
        }
    }

    private func flushPendingAIReplyIfNeeded() {
        guard let aiText = pendingAIText,
              !aiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        viewModel.receiveAIReply(aiText)
        pendingAIText = nil
    }

    private func beginDelayedReplyWait() {
        pendingAIText = nil
        resetDigitalHumanReplyDispatchState()
        preserveTencentProviderSessionAfterLocalDialogStop(reason: "delayedReplyWait")
        guard DialogEngineManager.shared.isDialogActive else { return }
        isStoppingForDelayedReply = true
        DialogEngineManager.shared.stopDialog()
    }

    private func scheduleDelayedReplyNotificationIfNeeded() {
        guard let delayedReply = viewModel.pendingDelayedReply else {
            return
        }

        EchoDelayedReplyNotificationScheduler.shared.requestAuthorizationIfNeeded { granted in
            guard granted else { return }
            EchoDelayedReplyNotificationScheduler.shared.schedule(delayedReply) { error in
                if let error {
                    print("[Echo] delayed reply local notification failed: \(error.localizedDescription)")
                }
            }
        }

        guard DreamJourneyBackendClient.shared.isEchoDelayedReplyPushConfigured,
              let userId = UserManager.shared.currentUser?.id else {
            return
        }

        let tokenStore = PushDeviceTokenStore.shared
        if tokenStore.registration(for: userId) == nil,
           DreamJourneyBackendClient.shared.isPushDeviceTokenRegistrationConfigured,
           let deviceToken = tokenStore.loadDeviceToken() {
            DreamJourneyBackendClient.shared.registerPushDeviceToken(
                userId: userId,
                deviceToken: deviceToken,
                environment: PushDeviceTokenEnvironment.current,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
            ) { [weak self] result in
                if case .success(let object) = result,
                   let item = object["item"] as? [String: Any],
                   let registration = PushDeviceTokenRegistration(json: item) {
                    _ = tokenStore.saveRegistration(registration)
                }
                self?.submitDelayedReplyPush(userId: userId, delayedReply: delayedReply)
            }
        } else {
            submitDelayedReplyPush(userId: userId, delayedReply: delayedReply)
        }
    }

    private func submitDelayedReplyPush(userId: String, delayedReply: EchoDelayedReply) {
        DreamJourneyBackendClient.shared.scheduleEchoDelayedReplyPush(
            userId: userId,
            delayedReply: delayedReply
        ) { result in
            if case .failure(let error) = result {
                print("[Echo] delayed reply push contract failed: \(error.localizedDescription)")
            }
        }
    }
}

extension EchoViewController: DialogEngineDelegate {
    func onDialogStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.resetDigitalHumanReplyDispatchState()
            self?.viewModel.beginVoiceInteraction()
        }
    }

    func onASRResult(text: String, isFinal: Bool) {
        guard isFinal else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.routeEchoAudioThroughDigitalHuman,
               self.hasTencentDigitalHumanProviderSpeechInFlight {
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "userSpeechFinal")
            }
            self.resetDigitalHumanReplyDispatchState()
            let turnID = self.digitalHumanConversation.startUserTurn(makeID: self.makeTencentDigitalHumanRequestID)
            print("[TencentDigitalHuman] user turn started turnID=\(turnID)")
            self.viewModel.finishUserVoice(text: text)
            if self.viewModel.isWaitingForDelayedReply {
                self.scheduleDelayedReplyNotificationIfNeeded()
                self.beginDelayedReplyWait()
            }
        }
    }

    func onTTSStarted(text: String) {
        guard !viewModel.isWaitingForDelayedReply else { return }
        pendingAIText = nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cancelDigitalHumanReplyPrewarm()
            self.viewModel.receiveAIReply(text)
            if self.shouldDispatchEchoReplyToTencentProvider {
                self.sendEchoReplyToDigitalHumanRuntimeIfReady(text, source: "ttsStartedFallback")
            }
            if self.routeEchoAudioThroughDigitalHuman {
                print("[TencentDigitalHuman] skipped SDK TTS fallback; Tencent cloud render owns audio/lip-sync")
                return
            }
            if self.applyCachedLipSyncTimelineForEchoReply(text) != true {
                self.startSDKTTSPlaybackFallback()
            }
        }
    }

    func onTTSFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.viewModel.isWaitingForDelayedReply else { return }
            if self.routeEchoAudioThroughDigitalHuman,
               self.hasTencentDigitalHumanProviderSpeechInFlight {
                print("[TencentDigitalHuman] waiting for provider TextOver before finishing Echo reply")
                return
            }
            self.stopDigitalHumanAudioLevelMetering()
            self.viewModel.markReplyDelivered()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                if DialogEngineManager.shared.isDialogActive {
                    self.viewModel.beginVoiceInteraction()
                } else {
                    self.viewModel.resetToIdle()
                }
            }
        }
    }

    func onChatStreaming(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.viewModel.isWaitingForDelayedReply else {
                return
            }
            self.pendingAIText = text
            if self.shouldDispatchEchoReplyToTencentProvider {
                if self.routeEchoAudioThroughDigitalHuman {
                    self.cancelDigitalHumanReplyPrewarm()
                    print("[TencentDigitalHuman] skipped streaming prewarm; waiting for SDK TTS sentence text")
                    return
                }
                self.scheduleDigitalHumanReplyPrewarm(text)
            } else {
                self.cancelDigitalHumanReplyPrewarm()
            }
        }
    }

    func onError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.stopDigitalHumanAudioLevelMetering()
            if self?.hasTencentDigitalHumanProviderSpeechInFlight == true {
                self?.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogError")
            } else {
                self?.resetDigitalHumanReplyDispatchState()
            }
            self?.viewModel.fail(error.localizedDescription)
        }
    }

    func onDialogEnded(reason: DialogEndReason) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.digitalHumanConversation.consumePausingForProviderSpeech() {
                print("[TencentDigitalHuman] DialogEngine paused for provider speech")
                return
            }
            if self.isStoppingForDelayedReply {
                self.isStoppingForDelayedReply = false
                ConversationMemoryManager.shared.endSession()
                return
            }
            if self.isStoppingVoiceCaptureManually {
                self.isStoppingVoiceCaptureManually = false
                self.flushPendingAIReplyIfNeeded()
                ConversationMemoryManager.shared.endSession()
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogEndedAfterUserStop")
                if !self.hasTencentDigitalHumanProviderSpeechInFlight {
                    self.resetDigitalHumanReplyDispatchState()
                }
                self.viewModel.resetToIdle()
                return
            }
            self.flushPendingAIReplyIfNeeded()
            ConversationMemoryManager.shared.endSession()
            self.stopDigitalHumanAudioLevelMetering()
            if self.hasTencentDigitalHumanProviderSpeechInFlight {
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogEnded")
            } else {
                self.resetDigitalHumanReplyDispatchState()
            }
            self.viewModel.resetToIdle()
        }
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
extension EchoViewController {
    func runUIQAMicrophoneSmoke() {
        micTapped()
    }

    func runUIQAEchoVoiceStatePreview() {
        for turn in 1..<EchoReplyPacingPolicy.waitAfterUserTurnCount {
            viewModel.beginVoiceInteraction()
            viewModel.finishUserVoice(text: "第 \(turn) 次想起爸爸小时候的故事")
            viewModel.receiveAIReply("我在听，慢慢说。")
        }
        viewModel.beginVoiceInteraction()
        viewModel.finishUserVoice(text: "第十次想起这件事")
        if viewModel.isWaitingForDelayedReply {
            beginDelayedReplyWait()
        }
    }

    func runUIQAEchoListeningStatePreview() {
        viewModel.beginVoiceInteraction()
    }

    func runUIQAEchoSpeakingStatePreview() {
        viewModel.receiveAIReply("我在这里，慢慢听你说。")
    }

    func runUIQAVoiceSDKReadinessPreview() {
        showsVoiceSDKReadinessPreview = true
        renderVoiceSDKReadinessPreviewIfNeeded()
    }

    func runUIQADigitalHumanLivePanelSmoke(completion: @escaping ([String: Any]) -> Void) {
        guard let panel = digitalHumanLivePanelView else {
            completion([
                "completed": false,
                "panelVisible": false,
                "failureReason": "digitalHumanLivePanelNotCreated"
            ])
            return
        }

        updatePersonaBadge()
        panel.setLocalPreviewEnabled(true)
        viewModel.beginVoiceInteraction()
        let usesProviderVisemeTimeline = ProcessInfo.processInfo.arguments.contains("DJDigitalHumanLipSyncProviderVisemeTimeline")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.render(state: .thinking)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.viewModel.receiveAIReply("我在这里，慢慢听你说。")
            if usesProviderVisemeTimeline {
                _ = self?.startUIQAMockVisemeTimeline()
            } else {
                _ = self?.startUIQAMeteredPlayback()
            }
        }
        func finishWhenRealAssetReady(attemptsRemaining: Int) {
            panel.snapshot { [weak self] snapshot in
                let audioLevel = snapshot?.audioLevel ?? 0
                let audioLevelSource = snapshot?.audioLevelSource ?? ""
                let lipSyncSource = snapshot?.lipSyncSource ?? ""
                let currentMouthShape = snapshot?.currentMouthShape ?? ""
                let lipSyncFrameCount = snapshot?.lipSyncFrameCount ?? 0
                let panelReady = snapshot?.ready == true
                let hasRealDigitalHumanAsset = snapshot?.hasRealDigitalHumanAsset == true
                let assetVideoReady = snapshot?.assetVideoReady == true
                let hasFallbackAvatar = snapshot?.hasFallbackAvatar == true
                let speaking = snapshot?.stateName == DigitalHumanLiveInteractionState.speaking.rawValue
                let meteringSampleCount = self?.digitalHumanAudioLevelMeter?.meteringSampleCount ?? 0
                let lipSyncReady = usesProviderVisemeTimeline
                    ? audioLevelSource == DigitalHumanPlaybackSource.providerVisemeTimeline.rawValue
                        && lipSyncSource == DigitalHumanPlaybackSource.providerVisemeTimeline.rawValue
                        && lipSyncFrameCount > 0
                        && currentMouthShape != "neutral"
                    : audioLevelSource == DigitalHumanAudioLevelSource.avAudioPlayerMetering.rawValue
                        && meteringSampleCount > 0
                if panelReady && hasRealDigitalHumanAsset && !hasFallbackAvatar && !assetVideoReady && attemptsRemaining > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        finishWhenRealAssetReady(attemptsRemaining: attemptsRemaining - 1)
                    }
                    return
                }
                completion([
                    "completed": panelReady && speaking && audioLevel > 0 && lipSyncReady && hasRealDigitalHumanAsset && assetVideoReady && !hasFallbackAvatar,
                    "panelVisible": !panel.isHidden && panel.alpha > 0,
                    "panelReady": panelReady,
                    "rendererReady": snapshot?.rendererReady ?? false,
                    "hasRealDigitalHumanAsset": hasRealDigitalHumanAsset,
                    "assetVideoReady": assetVideoReady,
                    "hasFallbackAvatar": hasFallbackAvatar,
                    "panelFailed": snapshot?.failed ?? panel.didFail,
                    "stateName": snapshot?.stateName ?? "missing",
                    "audioLevel": audioLevel,
                    "audioLevelSource": audioLevelSource,
                    "lipSyncMode": usesProviderVisemeTimeline ? "providerVisemeTimeline" : "avAudioPlayerMetering",
                    "lipSyncSource": lipSyncSource,
                    "currentMouthShape": currentMouthShape,
                    "lipSyncFrameCount": lipSyncFrameCount,
                    "meteringSampleCount": meteringSampleCount,
                    "personaName": snapshot?.personaName ?? "",
                    "personaSubtitle": snapshot?.personaSubtitle ?? "",
                    "voiceStatusText": self?.voiceStatusLabel.text ?? "",
                    "quoteText": self?.quoteLabel.text ?? ""
                ])
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            finishWhenRealAssetReady(attemptsRemaining: 14)
        }
    }

    func runUIQADigitalHumanRuntimeStubSmoke(completion: @escaping ([String: Any]) -> Void) {
        let context = DigitalHumanContextStore.shared.current
        let userId = UserManager.shared.currentUser?.id ?? context.viewerUserId ?? "user_9999"
        DreamJourneyBackendClient.shared.createDigitalHumanSession(
            userId: userId,
            personaId: context.ownerId,
            scene: "echo",
            deviceId: "ios-uiqa-simulator",
            lifecycleMode: context.mode
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let contract):
                let profile = contract.toDigitalHumanProfile(displayName: context.resolvedDisplayName)
                let runtimeSelection = DigitalHumanRuntimeFactory.makeRuntime(for: contract)
                let runtime = runtimeSelection.runtime
                self.digitalHumanRuntime = runtime
                do {
                    try runtime.configure(profile)
                    try runtime.open()
                    try runtime.sendTextChunk("我在这里。", requestID: contract.sessionId, sequence: 1, isFinal: false)
                    let speakingState = runtime.state
                    try runtime.sendTextChunk("", requestID: contract.sessionId, sequence: 2, isFinal: true)

                    let audioOnlyRuntime = AudioOnlyDigitalHumanRuntime()
                    try audioOnlyRuntime.configure(profile)
                    try audioOnlyRuntime.open()

                    completion([
                        "completed": true,
                        "provider": contract.provider,
                        "providerMode": contract.providerMode,
                        "sessionId": contract.sessionId,
                        "driveMode": contract.driveMode,
                        "runtimeProvider": runtimeSelection.selectedProvider,
                        "runtimeProviderMode": runtimeSelection.selectedMode,
                        "runtimeFactoryFallbackReason": runtimeSelection.fallbackReason ?? "",
                        "runtimeIsRealSDKBacked": runtimeSelection.isRealSDKBacked,
                        "runtimeStateAfterFinal": "\(runtime.state)",
                        "runtimeSpeakingState": "\(speakingState)",
                        "audioOnlyFallbackState": "\(audioOnlyRuntime.state)",
                        "fallbackMode": contract.fallbackMode,
                        "allowInterrupt": contract.sessionPolicy.allowInterrupt,
                        "proactiveSpeechAllowed": contract.sessionPolicy.proactiveSpeechAllowed,
                        "credentialMode": contract.credential.mode,
                        "defaultReleaseVisible": FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel),
                    ])
                } catch {
                    completion([
                        "completed": false,
                        "failureReason": "runtimeError",
                        "error": error.localizedDescription,
                    ])
                }
            case .failure(let error):
                completion([
                    "completed": false,
                    "failureReason": "backendSessionError",
                    "error": error.localizedDescription,
                ])
            }
        }
    }
}
#endif

private final class EchoScenicParkView: UIView {
    private let backgroundImageLayer = CALayer()
    private let skyLayer = CAGradientLayer()
    private let meadowLayer = CAShapeLayer()
    private let pathLayer = CAShapeLayer()
    private let treeBackLayer = CAShapeLayer()
    private let treeFrontLayer = CAShapeLayer()
    private let lightLayer = CAShapeLayer()
    private let overlayLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(backgroundImageLayer)
        layer.addSublayer(skyLayer)
        layer.addSublayer(lightLayer)
        layer.addSublayer(treeBackLayer)
        layer.addSublayer(meadowLayer)
        layer.addSublayer(pathLayer)
        layer.addSublayer(treeFrontLayer)
        layer.addSublayer(overlayLayer)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageLayer.frame = bounds
        skyLayer.frame = bounds
        overlayLayer.frame = bounds

        let width = bounds.width
        let height = bounds.height

        let lightPath = UIBezierPath(ovalIn: CGRect(x: width * 0.58, y: height * 0.08, width: 150, height: 150))
        lightLayer.path = lightPath.cgPath

        let meadowPath = UIBezierPath()
        meadowPath.move(to: CGPoint(x: 0, y: height * 0.45))
        meadowPath.addCurve(
            to: CGPoint(x: width, y: height * 0.42),
            controlPoint1: CGPoint(x: width * 0.28, y: height * 0.36),
            controlPoint2: CGPoint(x: width * 0.72, y: height * 0.55)
        )
        meadowPath.addLine(to: CGPoint(x: width, y: height))
        meadowPath.addLine(to: CGPoint(x: 0, y: height))
        meadowPath.close()
        meadowLayer.path = meadowPath.cgPath

        let path = UIBezierPath()
        path.move(to: CGPoint(x: width * 0.42, y: height))
        path.addCurve(
            to: CGPoint(x: width * 0.55, y: height * 0.48),
            controlPoint1: CGPoint(x: width * 0.50, y: height * 0.82),
            controlPoint2: CGPoint(x: width * 0.38, y: height * 0.60)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.66, y: height),
            controlPoint1: CGPoint(x: width * 0.72, y: height * 0.62),
            controlPoint2: CGPoint(x: width * 0.74, y: height * 0.82)
        )
        path.close()
        pathLayer.path = path.cgPath

        treeBackLayer.path = makeTreeLine(
            bounds: bounds,
            baseY: height * 0.39,
            radius: 58,
            count: 6,
            xOffset: -30
        ).cgPath
        treeFrontLayer.path = makeTreeLine(
            bounds: bounds,
            baseY: height * 0.49,
            radius: 72,
            count: 5,
            xOffset: 18
        ).cgPath
    }

    private func configureLayers() {
        let backgroundImage = UIImage(named: "echo_park_background")
        backgroundImageLayer.contents = backgroundImage?.cgImage
        backgroundImageLayer.contentsGravity = .resizeAspectFill
        backgroundImageLayer.isHidden = backgroundImage == nil

        let shouldUseVectorFallback = backgroundImage == nil
        [skyLayer, lightLayer, treeBackLayer, meadowLayer, pathLayer, treeFrontLayer].forEach {
            $0.isHidden = !shouldUseVectorFallback
        }

        skyLayer.colors = [
            UIColor(hex: "#fff9f0").cgColor,
            UIColor(hex: "#f7dfbd").cgColor,
            UIColor(hex: "#d8c89d").cgColor
        ]
        skyLayer.startPoint = CGPoint(x: 0.5, y: 0)
        skyLayer.endPoint = CGPoint(x: 0.5, y: 1)

        lightLayer.fillColor = UIColor(hex: "#fff2c6").withAlphaComponent(0.72).cgColor

        treeBackLayer.fillColor = UIColor(hex: "#b8aa78").withAlphaComponent(0.82).cgColor
        treeFrontLayer.fillColor = UIColor(hex: "#7f8d5d").withAlphaComponent(0.78).cgColor
        meadowLayer.fillColor = UIColor(hex: "#c8b982").withAlphaComponent(0.86).cgColor
        pathLayer.fillColor = UIColor(hex: "#e8cfa8").withAlphaComponent(0.9).cgColor

        overlayLayer.colors = [
            UIColor.clear.cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(backgroundImage == nil ? 0.34 : 0.12).cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(backgroundImage == nil ? 0.82 : 0.72).cgColor
        ]
        overlayLayer.locations = [0, 0.58, 1]
        overlayLayer.startPoint = CGPoint(x: 0.5, y: 0)
        overlayLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    private func makeTreeLine(
        bounds: CGRect,
        baseY: CGFloat,
        radius: CGFloat,
        count: Int,
        xOffset: CGFloat
    ) -> UIBezierPath {
        let path = UIBezierPath()
        let spacing = bounds.width / CGFloat(max(count - 1, 1))

        for index in 0..<count {
            let centerX = CGFloat(index) * spacing + xOffset
            let rect = CGRect(
                x: centerX - radius,
                y: baseY - radius,
                width: radius * 2,
                height: radius * 1.45
            )
            path.append(UIBezierPath(ovalIn: rect))
        }

        let ground = CGRect(x: -40, y: baseY + radius * 0.28, width: bounds.width + 80, height: radius)
        path.append(UIBezierPath(roundedRect: ground, cornerRadius: radius * 0.5))
        return path
    }
}
