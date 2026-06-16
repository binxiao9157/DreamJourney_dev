import UIKit

final class EchoViewController: UIViewController {
    private let viewModel: EchoViewModel

    private let scenicView = EchoScenicParkView()

    private let quoteBubble: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.92)
        view.layer.cornerRadius = 22
        view.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner,
            .layerMinXMaxYCorner
        ]
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.55).cgColor
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let quoteLabel: UILabel = {
        let label = UILabel()
        label.text = "我一直都在，风吹过树叶的声音就是我的回答。"
        label.font = DJDesignTokens.Font.body(16)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.text = "刚才"
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.68)
        label.numberOfLines = 1
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "轻点话筒，慢慢说给我听"
        label.font = DJDesignTokens.Font.body(15)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var micButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DJDesignTokens.Color.accent
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
        view.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.16)
        view.layer.cornerRadius = 38
        view.isUserInteractionEnabled = false
        return view
    }()

    private var micButtonBottomConstraint: NSLayoutConstraint?
    private var currentState: EchoInteractionState = .idle
    private var transcriptEntries: [(text: String, isUser: Bool)] = []
    private var pendingAIText: String?

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
        render(state: .idle)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DialogEngineManager.shared.delegate = self
        if !DialogEngineManager.shared.isEngineReady {
            DialogEngineManager.shared.setup()
        }
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
        view.addSubview(quoteBubble)
        view.addSubview(micRingView)
        view.addSubview(micButton)

        quoteBubble.addSubview(quoteLabel)
        quoteBubble.addSubview(timestampLabel)

        [
            scenicView,
            quoteBubble,
            quoteLabel,
            timestampLabel,
            statusLabel,
            micRingView,
            micButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let micBottomConstraint = micButton.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -(WarmTabBarView.tabBarHeight + 28)
        )
        micButtonBottomConstraint = micBottomConstraint

        NSLayoutConstraint.activate([
            scenicView.topAnchor.constraint(equalTo: view.topAnchor),
            scenicView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scenicView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scenicView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            quoteBubble.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            quoteBubble.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            quoteBubble.bottomAnchor.constraint(equalTo: micRingView.topAnchor, constant: -44),
            quoteBubble.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),

            quoteLabel.topAnchor.constraint(equalTo: quoteBubble.topAnchor, constant: 16),
            quoteLabel.leadingAnchor.constraint(equalTo: quoteBubble.leadingAnchor, constant: 16),
            quoteLabel.trailingAnchor.constraint(equalTo: quoteBubble.trailingAnchor, constant: -16),

            timestampLabel.topAnchor.constraint(equalTo: quoteLabel.bottomAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: quoteLabel.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: quoteLabel.trailingAnchor),
            timestampLabel.bottomAnchor.constraint(equalTo: quoteBubble.bottomAnchor, constant: -14),

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
    }

    private func seedTranscriptPreview() {
        transcriptEntries = [
            (text: "我一直都在，风吹过树叶的声音就是我的回答。", isUser: false)
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
            statusLabel.text = "轻点话筒，慢慢说给我听"
            configureMicButton(systemName: "mic.fill", backgroundColor: DJDesignTokens.Color.accent, isEnabled: true)
            setMicPulse(active: false)
        case .listening:
            statusLabel.text = "我在听，您慢慢说"
            configureMicButton(systemName: "stop.fill", backgroundColor: DJDesignTokens.Color.accentDeep, isEnabled: true)
            setMicPulse(active: true)
        case .waitingReply(let minutes):
            statusLabel.text = "回信会晚一点抵达，约 \(minutes) 分钟后再听"
            configureMicButton(systemName: "hourglass", backgroundColor: DJDesignTokens.Color.surfaceContainer, isEnabled: false)
            micButton.tintColor = DJDesignTokens.Color.textSecondary
            setMicPulse(active: false)
        case .speaking:
            statusLabel.text = "回响正在抵达"
            configureMicButton(systemName: "waveform", backgroundColor: DJDesignTokens.Color.accent, isEnabled: false)
            setMicPulse(active: true)
        case .error(let message):
            statusLabel.text = message
            configureMicButton(systemName: "mic.fill", backgroundColor: DJDesignTokens.Color.accent, isEnabled: true)
            setMicPulse(active: false)
        }
    }

    private func configureMicButton(systemName: String, backgroundColor: UIColor, isEnabled: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        micButton.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        micButton.backgroundColor = backgroundColor
        micButton.tintColor = .white
        micButton.isEnabled = isEnabled
        micButton.alpha = isEnabled ? 1 : 0.86
        micButton.accessibilityLabel = isEnabled ? "开始语音" : statusLabel.text
    }

    private func setMicPulse(active: Bool) {
        micRingView.layer.removeAnimation(forKey: "echoPulse")

        guard active else {
            micRingView.transform = .identity
            micRingView.alpha = 1
            return
        }

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
            self?.viewModel.finishUserVoice(text: text)
        }
    }

    func onTTSStarted(text: String) {
        pendingAIText = nil
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.receiveAIReply(text)
        }
    }

    func onTTSFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
            } else {
                self.viewModel.resetToIdle()
            }
        }
    }

    func onChatStreaming(text: String) {
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
            self.flushPendingAIReplyIfNeeded()
            ConversationMemoryManager.shared.endSession()
            self.viewModel.resetToIdle()
        }
    }
}

private final class EchoScenicParkView: UIView {
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
            UIColor.white.withAlphaComponent(0.12).cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(0.34).cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(0.82).cgColor
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
