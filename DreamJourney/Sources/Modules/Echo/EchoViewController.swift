import UIKit

final class EchoViewController: UIViewController {
    private let viewModel: EchoViewModel

    private let scenicView = EchoScenicParkView()

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

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.text = "刚才"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.60)
        label.numberOfLines = 1
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
    private var isStoppingForDelayedReply = false

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
        setupLayout()
        bindViewModel()
        seedTranscriptPreview()
        if !viewModel.restoreStoredDelayedReplyIfAvailable() {
            render(state: .idle)
        }
        renderArchiveContextStatus(viewModel.archiveContextStatus)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DialogEngineManager.shared.delegate = self
        if !DialogEngineManager.shared.isEngineReady {
            DialogEngineManager.shared.setup()
        }
        viewModel.refreshArchiveContextStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if DialogEngineManager.shared.delegate === self {
            if DialogEngineManager.shared.isDialogActive {
                DialogEngineManager.shared.stopDialog()
                flushPendingAIReplyIfNeeded()
                ConversationMemoryManager.shared.endSession()
                viewModel.resetToIdle()
            }
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
        view.addSubview(scenicView)
        view.addSubview(archiveContextStatusView)
        view.addSubview(quoteBubble)
        view.addSubview(timestampLabel)
        view.addSubview(voiceStatusView)
        view.addSubview(micRingView)
        view.addSubview(micButton)

        archiveContextStatusView.addSubview(archiveContextStatusLabel)
        quoteBubble.addSubview(quoteLabel)
        voiceStatusView.addSubview(voiceStatusLabel)

        [
            scenicView,
            archiveContextStatusView,
            archiveContextStatusLabel,
            quoteBubble,
            quoteLabel,
            timestampLabel,
            voiceStatusView,
            voiceStatusLabel,
            micRingView,
            micButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

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

            timestampLabel.topAnchor.constraint(equalTo: quoteBubble.bottomAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: quoteBubble.leadingAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: quoteBubble.trailingAnchor),

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

    private func seedTranscriptPreview() {
        transcriptEntries = [
            (text: "\"我一直都在，风吹过树叶的声音就是我的回答。\"", isUser: false)
        ]
        reloadTranscriptPreview()
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
        timestampLabel.text = "刚才"
    }

    private func render(state: EchoInteractionState) {
        currentState = state

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
                systemName: "waveform",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: false,
                accessibilityLabel: "回响正在抵达"
            )
            setMicPulse(active: true)
        case .replied:
            renderVoiceStatus(text: "回信已抵达", isVisible: true)
            configureMicButton(
                systemName: "checkmark",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: false,
                accessibilityLabel: "回信已抵达"
            )
            setMicPulse(active: false)
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

    private func renderVoiceStatus(text: String?, isVisible: Bool) {
        voiceStatusLabel.text = text
        voiceStatusLabel.accessibilityLabel = text
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
        case .listening:
            stopVoiceCapture()
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
                self.viewModel.beginVoiceInteraction()
                DialogEngineManager.shared.startDialog()
            }
        }
    }

    private func stopVoiceCapture() {
        if DialogEngineManager.shared.isDialogActive {
            DialogEngineManager.shared.stopDialog()
        } else {
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
            self?.viewModel.beginVoiceInteraction()
        }
    }

    func onASRResult(text: String, isFinal: Bool) {
        guard isFinal else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
            self?.viewModel.receiveAIReply(text)
        }
    }

    func onTTSFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.viewModel.isWaitingForDelayedReply else { return }
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
        guard !viewModel.isWaitingForDelayedReply else { return }
        pendingAIText = text
    }

    func onError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.fail(error.localizedDescription)
        }
    }

    func onDialogEnded(reason: DialogEndReason) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isStoppingForDelayedReply {
                self.isStoppingForDelayedReply = false
                ConversationMemoryManager.shared.endSession()
                return
            }
            self.flushPendingAIReplyIfNeeded()
            ConversationMemoryManager.shared.endSession()
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
