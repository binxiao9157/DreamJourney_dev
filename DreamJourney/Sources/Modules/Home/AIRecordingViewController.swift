import UIKit
import AVFoundation
import WebKit
import CocoaLumberjack

// MARK: - 对话消息模型
enum TGMessage: Identifiable {
    case ai(text: String, timestamp: Date = Date())
    case user(text: String, timestamp: Date = Date())
    case photo(imagePath: String, timestamp: Date = Date())  // 用户发送的照片消息
    case wellbeingNotice(text: String, timestamp: Date = Date())
    case privacyConfirmation

    var id: String { UUID().uuidString }
    var timestamp: Date {
        switch self {
        case .ai(_, let t), .user(_, let t), .photo(_, let t), .wellbeingNotice(_, let t): return t
        case .privacyConfirmation: return Date()
        }
    }

    var isWellbeingNotice: Bool {
        if case .wellbeingNotice = self { return true }
        return false
    }
}

// MARK: - 语音球状态
enum VoiceBallState {
    case idle         // 待机：脉冲动效，麦克风图标
    case active       // 对话中：波纹动效，停止图标
}

// MARK: - AIRecordingViewController：首页 AI 智能记录
final class AIRecordingViewController: UIViewController {
    private static var isDigitalHumanDiagnosticsEnabled: Bool {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("--show-digital-human-diagnostics") {
            return true
        }
        let rawValue = processInfo.environment["DREAMJOURNEY_SHOW_DIGITAL_HUMAN_DIAGNOSTICS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes" || rawValue == "enabled"
    }

    // MARK: - UI：顶部标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "寻梦环游"
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return l
    }()

    // MARK: - UI：消息流
    private lazy var messageTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(TGMessageCell.self, forCellReuseIdentifier: "AIMessageCell")
        tv.register(TGMessageCell.self, forCellReuseIdentifier: "UserMessageCell")
        tv.register(TGPhotoCell.self, forCellReuseIdentifier: "PhotoCell")
        tv.register(TGPrivacyCell.self, forCellReuseIdentifier: "PrivacyCell")
        tv.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))
        tv.dataSource = self
        tv.delegate = self
        tv.keyboardDismissMode = .onDrag
        return tv
    }()

    // MARK: - UI：底部操作区
    private lazy var bottomContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .warmBackground
        return v
    }()

    /// 底部容器底部约束（动态调整避开 TabBar）
    private var bottomContainerBottomConstraint: NSLayoutConstraint!

    /// 底部分割线（UI稿无分割线，隐藏）
    private let bottomDivider: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    /// 左侧辅助按鈕：相册
    private lazy var albumButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 0.55)
        b.layer.cornerRadius = 22
        b.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let icon = UIImage(systemName: "photo", withConfiguration: config)
        b.setImage(icon, for: .normal)
        b.tintColor = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1.0)
        b.addTarget(self, action: #selector(albumTapped), for: .touchUpInside)
        return b
    }()

    /// 右侧辅助按鈕：拍照
    private lazy var cameraButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 0.55)
        b.layer.cornerRadius = 22
        b.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let icon = UIImage(systemName: "camera", withConfiguration: config)
        b.setImage(icon, for: .normal)
        b.tintColor = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1.0)
        b.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        return b
    }()

    /// 中央语音球（橙色大圆 + 麦克风图标）
    private lazy var voiceBallButton: UIButton = {
        let b = UIButton(type: .custom)
        b.layer.cornerRadius = 40
        b.layer.masksToBounds = false
        b.backgroundColor = UIColor(red: 0.93, green: 0.58, blue: 0.22, alpha: 1.0)
        // 外圆光晕
        b.layer.shadowColor = UIColor(red: 0.93, green: 0.58, blue: 0.22, alpha: 0.45).cgColor
        b.layer.shadowOpacity = 1
        b.layer.shadowOffset = .zero
        b.layer.shadowRadius = 14
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        let micIcon = UIImage(systemName: "mic.fill", withConfiguration: config)
        b.setImage(micIcon, for: .normal)
        b.tintColor = .white
        b.addTarget(self, action: #selector(voiceBallTapped), for: .touchUpInside)
        return b
    }()

    private lazy var privacyScopeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 0.55)
        config.baseForegroundColor = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1.0)
        config.image = UIImage(systemName: "lock.shield")
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        let b = UIButton(configuration: config)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.addTarget(self, action: #selector(privacyScopeTapped), for: .touchUpInside)
        return b
    }()

    private lazy var digitalHumanDiagnosticsButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 0.55)
        config.baseForegroundColor = UIColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1.0)
        config.image = UIImage(systemName: "info.circle")
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)
        let button = UIButton(configuration: config)
        button.accessibilityLabel = "数字人真机诊断"
        button.addTarget(self, action: #selector(digitalHumanDiagnosticsTapped), for: .touchUpInside)
        return button
    }()

    private let validationSpacerView = UIView()
    private let digitalHumanAvatarView = DigitalHumanAvatarView()
    private lazy var digitalHumanFallbackCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 1.00, green: 0.96, blue: 0.89, alpha: 1.0)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0.93, green: 0.58, blue: 0.22, alpha: 0.26).cgColor
        view.isHidden = true
        view.alpha = 0
        return view
    }()
    private let digitalHumanFallbackTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = UIColor(red: 0.31, green: 0.24, blue: 0.17, alpha: 1.0)
        label.numberOfLines = 1
        return label
    }()
    private let digitalHumanFallbackMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 0.48, green: 0.39, blue: 0.30, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()
    private lazy var digitalHumanRetryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "重试数字人"
        config.image = UIImage(systemName: "arrow.clockwise.circle.fill")
        config.imagePadding = 4
        config.baseForegroundColor = .warmAccent
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(retryDigitalHumanTapped), for: .touchUpInside)
        return button
    }()
    private lazy var digitalHumanContinueButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "继续语音"
        config.baseForegroundColor = .warmSubtitle
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(continueVoiceFallbackTapped), for: .touchUpInside)
        return button
    }()
    private var validationSpacerTopConstraint: NSLayoutConstraint!
    private var validationSpacerHeightConstraint: NSLayoutConstraint!
    private var messageTableTopConstraint: NSLayoutConstraint!
    private var digitalHumanFallbackHeightConstraint: NSLayoutConstraint!

    // MARK: - State
    private var messages: [TGMessage] = []
    private var voiceBallState: VoiceBallState = .idle
    private var pulseLayer: CABasicAnimation?
    /// 用户语音中间结果缓存（不直接显示，等待最终确认或 AI 开始回复时再展示）
    private var pendingUserText: String?
    /// AI 流式拼接缓存（不直接显示，等 TTS 句子完整时再展示）
    private var pendingAIText: String?
    /// 当前是否处于危机干预流程，用于阻止已排队的普通收尾 UI。
    private var isCrisisInterventionActive = false
    private var currentDialogStartMessageIndex = 0
    private var currentDialogAllowsMemoir = true
    private var selectedDialogPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    private var currentDialogPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    private var selectedDialogFamilyVisibility = FamilyVisibilitySelection.allMembers
    private let conversationWellbeingLimiter = ConversationWellbeingLimiter()

    // MARK: - 对话录音（用于声音复刻）
    /// 并行录音器：对话期间录制用户语音，供声音复刻训练使用
    private var sessionRecorder: AVAudioRecorder?
    /// 最近一次对话的录音文件 URL
    private(set) var lastSessionRecordingURL: URL?
    /// 与录音文件配对的 sessionId（用于详情页查找 recordings/{sessionId}.m4a）
    private(set) var lastSessionId: String?
    private let dialogEngine: DialogEngineProtocol = DialogEngineFactory.makeDefault()
    private var digitalHumanSpeechRequestID = 0
    private var isDigitalHumanSpeechPlaybackEnabled = false
    private var currentAssistantResponseText: String?
    private var retryableDigitalHumanSpeechText: String?
    private var isAwaitingDigitalHumanAudioEnd = false
    private let digitalHumanFallbackSynthesizer = AVSpeechSynthesizer()
    private var digitalHumanNativeAudioPlayer: AVAudioPlayer?
    private var digitalHumanNativeAudioURL: URL?
    private var nativeAudioPlaybackRequestID: Int?
    private var digitalHumanPlaybackWatchdog: DispatchWorkItem?
    private var isDigitalHumanSystemSpeechFallbackActive = false
    private var systemSpeechFallbackRequestID: Int?
    private var isRealtimeDialogPausedForDigitalHumanPlayback = false
    private var pendingDialogEndReasonAfterDigitalHumanPlayback: DialogEndReason?
    private var hasFinalizedCurrentDialogSession = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        hideKeyboardWhenTapped()
        setupLayout()
        configureDigitalHumanCallbacks()
        setupNotifications()
        updateVoiceBallState(.idle)
        // 预初始化 Dialog 引擎
        dialogEngine.delegate = self
        digitalHumanFallbackSynthesizer.delegate = self
        configureDigitalHumanSpeechPlayback()
        if Self.isDigitalHumanDiagnosticsEnabled {
            DigitalHumanReadinessReport.make().persistEvidenceFiles()
        }
        dialogEngine.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private func configureDigitalHumanCallbacks() {
        digitalHumanAvatarView.onAudioPlaybackEnded = { [weak self] in
            guard let self = self else { return }
            if self.isDigitalHumanSystemSpeechFallbackActive || self.digitalHumanNativeAudioPlayer != nil {
                return
            }
            self.finishDigitalHumanSpeechPlayback(source: "speech_envelope")
        }
        digitalHumanAvatarView.onAudioPlaybackFailed = { [weak self] message in
            DDLogWarn("[DigitalHuman] 音频播放异常: \(message)")
            self?.handleDigitalHumanPlaybackFailure(
                reason: "webview_audio_failed detail=\(DigitalHumanPlaybackEvidenceStore.sanitize(message))",
                logReason: "webview_audio_failed: \(message)"
            )
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 动态更新 bottomContainer 底部位置，确保紧贴 WarmTabBar 顶部。
        // ⚠️ 不读 view.safeAreaInsets.bottom：detail 页 hidesBottomBarWhenPushed 触发的
        // safeArea 重算会让该值变大，导致返回后三合一按钮悬浮过高。
        // 改为通过 keyWindow 取纯系统 home indicator 高度。
        let safeBottom = Self.systemBottomSafeInset
        bottomContainerBottomConstraint.constant = -(WarmTabBarView.tabBarHeight + safeBottom)
    }

    /// 通过 keyWindow 获取纯系统 home indicator 高度，避免 push/pop detail 时 view.safeAreaInsets 被污染
    private static var systemBottomSafeInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(privacyScopeButton)
        validationSpacerView.isHidden = true
        view.addSubview(validationSpacerView)
        view.addSubview(digitalHumanAvatarView)
        view.addSubview(digitalHumanFallbackCard)
        view.addSubview(messageTableView)
        view.addSubview(bottomDivider)
        view.addSubview(bottomContainer)

        bottomContainer.addSubview(albumButton)
        bottomContainer.addSubview(voiceBallButton)
        bottomContainer.addSubview(cameraButton)

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        [titleLabel, privacyScopeButton, validationSpacerView, digitalHumanAvatarView, digitalHumanFallbackCard, messageTableView, bottomDivider, bottomContainer,
         albumButton, voiceBallButton, cameraButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        configureDigitalHumanDiagnosticsIfNeeded()
        setupDigitalHumanFallbackCard()

        let ballSize: CGFloat = 80
        let sideSize: CGFloat = 44

        // 底部操作区底部约束（动态调整避开 TabBar）
        bottomContainerBottomConstraint = bottomContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -56)
        validationSpacerTopConstraint = validationSpacerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0)
        validationSpacerHeightConstraint = validationSpacerView.heightAnchor.constraint(equalToConstant: 0)
        messageTableTopConstraint = messageTableView.topAnchor.constraint(equalTo: digitalHumanFallbackCard.bottomAnchor, constant: 8)
        digitalHumanFallbackHeightConstraint = digitalHumanFallbackCard.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // 顶部标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            privacyScopeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            privacyScopeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            privacyScopeButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),

            validationSpacerTopConstraint,
            validationSpacerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            validationSpacerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            validationSpacerHeightConstraint,

            digitalHumanAvatarView.topAnchor.constraint(equalTo: validationSpacerView.bottomAnchor, constant: 12),
            digitalHumanAvatarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            digitalHumanAvatarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            digitalHumanAvatarView.heightAnchor.constraint(equalToConstant: 218),

            digitalHumanFallbackCard.topAnchor.constraint(equalTo: digitalHumanAvatarView.bottomAnchor, constant: 8),
            digitalHumanFallbackCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            digitalHumanFallbackCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            digitalHumanFallbackHeightConstraint,

            // 消息流
            messageTableTopConstraint,
            messageTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageTableView.bottomAnchor.constraint(equalTo: bottomDivider.topAnchor),

            // 分割线
            bottomDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomDivider.heightAnchor.constraint(equalToConstant: 0.5),
            bottomDivider.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor),

            // 底部操作区
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContainerBottomConstraint,
            bottomContainer.heightAnchor.constraint(equalToConstant: 110),
            
            // 语音球（中央）
            voiceBallButton.widthAnchor.constraint(equalToConstant: ballSize),
            voiceBallButton.heightAnchor.constraint(equalToConstant: ballSize),
            voiceBallButton.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            voiceBallButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor, constant: -4),
            
            // 左侧相册按鈕
            albumButton.widthAnchor.constraint(equalToConstant: sideSize),
            albumButton.heightAnchor.constraint(equalToConstant: sideSize),
            albumButton.centerYAnchor.constraint(equalTo: voiceBallButton.centerYAnchor),
            albumButton.trailingAnchor.constraint(equalTo: voiceBallButton.leadingAnchor, constant: -44),
            
            // 右侧拍照按鈕
            cameraButton.widthAnchor.constraint(equalToConstant: sideSize),
            cameraButton.heightAnchor.constraint(equalToConstant: sideSize),
            cameraButton.centerYAnchor.constraint(equalTo: voiceBallButton.centerYAnchor),
            cameraButton.leadingAnchor.constraint(equalTo: voiceBallButton.trailingAnchor, constant: 44),
        ])
        updatePrivacyScopeButton()
    }

    private func setupDigitalHumanFallbackCard() {
        let actionStack = UIStackView(arrangedSubviews: [digitalHumanRetryButton, digitalHumanContinueButton])
        actionStack.axis = .horizontal
        actionStack.spacing = 8
        actionStack.alignment = .center
        actionStack.distribution = .fillProportionally

        let textStack = UIStackView(arrangedSubviews: [digitalHumanFallbackTitleLabel, digitalHumanFallbackMessageLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let contentStack = UIStackView(arrangedSubviews: [textStack, actionStack])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        digitalHumanFallbackCard.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let top = contentStack.topAnchor.constraint(equalTo: digitalHumanFallbackCard.topAnchor, constant: 10)
        let bottom = contentStack.bottomAnchor.constraint(equalTo: digitalHumanFallbackCard.bottomAnchor, constant: -10)
        top.priority = .defaultHigh
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            top,
            contentStack.leadingAnchor.constraint(equalTo: digitalHumanFallbackCard.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: digitalHumanFallbackCard.trailingAnchor, constant: -12),
            bottom
        ])
    }

    private func configureDigitalHumanDiagnosticsIfNeeded() {
        guard Self.isDigitalHumanDiagnosticsEnabled else { return }
        view.addSubview(digitalHumanDiagnosticsButton)
        digitalHumanDiagnosticsButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            digitalHumanDiagnosticsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            digitalHumanDiagnosticsButton.trailingAnchor.constraint(equalTo: privacyScopeButton.leadingAnchor, constant: -8),
            digitalHumanDiagnosticsButton.widthAnchor.constraint(equalToConstant: 38),
            digitalHumanDiagnosticsButton.heightAnchor.constraint(equalToConstant: 34),
            digitalHumanDiagnosticsButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10)
        ])
    }

    // MARK: - Voice Ball State Machine
    private func updateVoiceBallState(_ state: VoiceBallState) {
        voiceBallState = state
        voiceBallButton.layer.removeAnimation(forKey: "pulse")
        voiceBallButton.layer.removeAllAnimations()

        let orangeColor = UIColor(red: 0.93, green: 0.58, blue: 0.22, alpha: 1.0)
        let stopColor = UIColor(red: 0.85, green: 0.30, blue: 0.20, alpha: 1.0)

        switch state {
        case .idle:
            voiceBallButton.backgroundColor = orangeColor
            voiceBallButton.layer.shadowColor = UIColor(red: 0.93, green: 0.58, blue: 0.22, alpha: 0.45).cgColor
            let micConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            voiceBallButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
            voiceBallButton.transform = .identity
            startPulseAnimation()
        case .active:
            voiceBallButton.backgroundColor = stopColor
            voiceBallButton.layer.shadowColor = UIColor(red: 0.85, green: 0.30, blue: 0.20, alpha: 0.40).cgColor
            let stopConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            voiceBallButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: stopConfig), for: .normal)
            voiceBallButton.transform = .identity
            startActiveAnimation()
        }
    }

    private func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.8
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulseLayer = pulse
        voiceBallButton.layer.add(pulse, forKey: "pulse")
    }

    private func startActiveAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.2
        pulse.fromValue = 1.0
        pulse.toValue = 1.08
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulseLayer = pulse
        voiceBallButton.layer.add(pulse, forKey: "pulse")
    }

    // MARK: - Actions
    @objc private func voiceBallTapped() {
        switch voiceBallState {
        case .idle:
            startRecording()
        case .active:
            stopRecording()
        }
    }

    @objc private func cameraTapped() {
        #if targetEnvironment(simulator)
        showToast("模拟器无法使用相机，请在真机上测试", type: .info)
        #else
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
        #endif
    }

    @objc private func albumTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func privacyScopeTapped() {
        guard voiceBallState == .idle else {
            showToast("本次对话进行中，使用范围会在下次开聊前生效", type: .info)
            return
        }

        let alert = UIAlertController(
            title: "本次对话使用范围",
            message: "本机只保留在设备；可生成可用于知识提取和回忆录生成；亲友可进入家庭关怀和亲属圈。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "本机", style: .default) { [weak self] _ in
            self?.setDialogPrivacyScope(.localOnly)
        })
        alert.addAction(UIAlertAction(title: "可生成", style: .default) { [weak self] _ in
            self?.setDialogPrivacyScope(.generationAllowed)
        })
        alert.addAction(UIAlertAction(title: "亲友", style: .default) { [weak self] _ in
            self?.presentDialogFamilyVisibilityPicker()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = privacyScopeButton
        alert.popoverPresentationController?.sourceRect = privacyScopeButton.bounds
        present(alert, animated: true)
    }

    @objc private func digitalHumanDiagnosticsTapped() {
        guard Self.isDigitalHumanDiagnosticsEnabled else { return }
        let report = DigitalHumanReadinessReport.make()
        let viewController = DigitalHumanDiagnosticsViewController(report: report)
        let navigationController = UINavigationController(rootViewController: viewController)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func setDialogPrivacyScope(_ scope: MemoryPrivacyScope) {
        selectedDialogPrivacyMetadata = HomeDialogPrivacyMetadataFactory.make(
            scope: scope,
            familyVisibility: selectedDialogFamilyVisibility.visibility
        )
        updatePrivacyScopeButton()
    }

    private func presentDialogFamilyVisibilityPicker() {
        let picker = FamilyVisibilityPickerViewController(
            initialVisibility: selectedDialogFamilyVisibility.visibility
        )
        picker.onSelect = { [weak self] selection in
            self?.selectedDialogFamilyVisibility = selection
            self?.setDialogPrivacyScope(.familyCircle)
        }
        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func updatePrivacyScopeButton() {
        var config = privacyScopeButton.configuration
        let scope = selectedDialogPrivacyMetadata.scope
        config?.title = HomeDialogPrivacyMetadataFactory.buttonTitle(
            for: selectedDialogPrivacyMetadata,
            familySummary: selectedDialogFamilyVisibility.summary
        )
        config?.image = UIImage(systemName: HomeDialogPrivacyMetadataFactory.iconName(for: scope))
        privacyScopeButton.configuration = config
        if scope == .familyCircle {
            privacyScopeButton.accessibilityLabel = "对话使用范围：亲友，\(selectedDialogFamilyVisibility.summary)"
        } else {
            privacyScopeButton.accessibilityLabel = "对话使用范围：\(HomeDialogPrivacyMetadataFactory.title(for: scope))"
        }
    }

    // MARK: - Mock Dialog
    private func startRecording() {
        guard handleConversationWellbeingBeforeRecording() else { return }

        MicrophonePermissionManager.shared.requestPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                // 先启动 DialogEngine（由 SDK 配置 AudioSession），再启动并行录音（共享同一 AudioSession）
                // 顺序很重要：如果先启动 AVAudioRecorder，它会隐式修改 AudioSession 配置，可能影响 SDK 的 AEC
                self.digitalHumanAvatarView.setState(.listening, prompt: "正在聆听")
                dialogEngine.startDialog()
                self.startSessionRecording()
            } else {
                MicrophonePermissionManager.shared.showPermissionDeniedAlert(on: self)
                self.updateVoiceBallState(.idle)
            }
        }
    }

    private func handleConversationWellbeingBeforeRecording() -> Bool {
        conversationWellbeingLimiter.startSession()
        return presentConversationWellbeingDecisionIfNeeded(afterAssistantPlayback: false)
    }

    @discardableResult
    private func presentConversationWellbeingDecisionIfNeeded(afterAssistantPlayback: Bool) -> Bool {
        let decision = conversationWellbeingLimiter.decision()
        switch decision {
        case .allow:
            return true
        case .nudge(let message):
            appendConversationWellbeingMessage(message)
            conversationWellbeingLimiter.markNudgeShown()
            if afterAssistantPlayback {
                digitalHumanAvatarView.setState(.idle, prompt: "可以先休息一下")
            }
            return true
        case .limit(let message):
            appendConversationWellbeingMessage(message)
            stopSessionRecording()
            if dialogEngine.isDialogActive {
                dialogEngine.stopDialog(reason: .manual)
            }
            updateVoiceBallState(.idle)
            resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
            digitalHumanAvatarView.clearSpeechAudio()
            digitalHumanAvatarView.setState(.idle, prompt: "先休息一下")
            showToast("今天先到这里，晚些时候再回来", type: .info)
            return false
        }
    }

    private func appendConversationWellbeingMessage(_ message: String) {
        if case .wellbeingNotice(let lastMessage, _) = messages.last, lastMessage == message {
            return
        }
        messages.append(.wellbeingNotice(text: message, timestamp: Date()))
        messageTableView.reloadData()
        scrollToBottom()
    }

    private func stopRecording() {
        // 先停止并行录音，再停止 DialogEngine
        stopSessionRecording()
        dialogEngine.stopDialog()
    }

    private func handleRecognizeAndReply() {
        // 实际流程由 DialogEngineDelegate 回调驱动，此方法保留作为手动停止后的备用处理
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        messageTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .djUserDidLogout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKnowledgeExtractionFinished(_:)),
            name: .djConversationKnowledgeExtractionFinished,
            object: nil
        )
    }

    @objc private func handleLogout() {
        messages = []
        messageTableView.reloadData()
        updateVoiceBallState(.idle)
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        dialogEngine.destroyEngine()
    }

    @objc private func handleDidEnterBackground() {
        if dialogEngine.isDialogActive {
            dialogEngine.stopDialog()
            updateVoiceBallState(.idle)
        }
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        // 安全防护：确保并行录音也被停止（正常流程由 onDialogEnded 触发，此处兜底）
        stopSessionRecording()
    }

    @objc private func handleWillEnterForeground() {
        if !dialogEngine.isEngineReady {
            dialogEngine.setup()
        }
        // 检查声音复刻训练是否在后台完成（Timer 会被挂起，需要手动检查）
        VoiceCloneService.shared.checkPendingTraining()
    }

    @objc private func handleKnowledgeExtractionFinished(_ notification: Notification) {
        let addedCount = notification.userInfo?["addedCount"] as? Int ?? 0
        let deterministicAddedCount = notification.userInfo?["deterministicAddedCount"] as? Int ?? 0
        let llmAddedCount = notification.userInfo?["llmAddedCount"] as? Int ?? 0
        let didAttemptLLM = notification.userInfo?["didAttemptLLM"] as? Bool ?? false
        let didFailLLM = notification.userInfo?["didFailLLM"] as? Bool ?? false
        if addedCount > 0 {
            if didFailLLM {
                showToast("已本地沉淀 \(deterministicAddedCount) 条，远端 AI 抽取暂未完成", type: .info)
            } else if llmAddedCount > 0 {
                showToast("结构化知识库已沉淀 \(addedCount) 条，其中 AI 抽取 \(llmAddedCount) 条", type: .success)
            } else if didAttemptLLM {
                showToast("已本地沉淀 \(deterministicAddedCount) 条，AI 暂无新增线索", type: .info)
            } else {
                showToast("结构化知识库已本地沉淀 \(addedCount) 条", type: .success)
            }
        } else {
            if didFailLLM {
                showToast("远端 AI 抽取暂未完成，本轮暂无本地新增", type: .info)
            } else {
                showToast("本轮暂无可新增的结构化知识", type: .info)
            }
        }
    }

    private func configureDigitalHumanSpeechPlayback() {
        isDigitalHumanSpeechPlaybackEnabled =
            VolcEngineCredentialProvider.apiKey() != nil &&
            VolcEngineCredentialProvider.voiceType() != nil

        guard isDigitalHumanSpeechPlaybackEnabled else {
            DDLogWarn("[DigitalHumanSpeech] 未启用 WAV 播放：缺少 VolcEngineAPIKey 或 VolcEngineVoiceType")
            return
        }

        if let manager = dialogEngine as? DialogEngineManager {
            manager.config.enablePlayer = false
            DDLogInfo("[DigitalHumanSpeech] 已关闭实时 SDK 内置播放器，改由 WebView 数字人播放 WAV")
        }
    }
}

// MARK: - UITableViewDataSource
extension AIRecordingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        switch msg {
        case .ai(let text, let ts), .wellbeingNotice(let text, let ts):
            let cell = tableView.dequeueReusableCell(withIdentifier: "AIMessageCell", for: indexPath) as! TGMessageCell
            cell.configure(text: text, isUser: false, timestamp: ts)
            return cell
        case .user(let text, let ts):
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserMessageCell", for: indexPath) as! TGMessageCell
            cell.configure(text: text, isUser: true, timestamp: ts)
            return cell
        case .photo(let imagePath, let ts):
            let cell = tableView.dequeueReusableCell(withIdentifier: "PhotoCell", for: indexPath) as! TGPhotoCell
            cell.configure(imagePath: imagePath, timestamp: ts)
            return cell
        case .privacyConfirmation:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PrivacyCell", for: indexPath) as! TGPrivacyCell
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension AIRecordingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let msg = messages[indexPath.row]
        switch msg {
        case .photo:
            return TGPhotoCell.cellHeight
        case .privacyConfirmation:
            return 80
        case .ai(let text, _), .wellbeingNotice(let text, _), .user(let text, _):
            let maxWidth = TGMessageCell.maxBubbleWidth(for: tableView.bounds.width)
            let textSize = TGMessageCell.messageTextSize(
                for: text,
                isUser: {
                    if case .user = msg { return true }
                    return false
                }(),
                maxBubbleWidth: maxWidth
            )
            return textSize.height
                + TGMessageCell.verticalPadding * 2
                + TGMessageCell.topPadding
                + TGMessageCell.timestampHeight
                + TGMessageCell.timestampTopPadding
                + TGMessageCell.bottomPadding
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension AIRecordingViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }

        // 保存图片到本地 Documents/photos/ 目录
        let imagePath = savePhotoToLocal(image)

        // 显示为用户消息气泡（含缩略图）
        messages.append(.photo(imagePath: imagePath, timestamp: Date()))
        // AI 回复（先发占位，后续替换为分析结果）
        messages.append(.ai(text: "照片收到了！能不能跟我说说这张照片背后的故事？", timestamp: Date()))
        let aiMessageIndex = messages.count - 1
        messageTableView.reloadData()
        scrollToBottom()

        // 记录到对话记忆
        let privacyMetadata = selectedDialogPrivacyMetadata
        Stage1MemoryFacade.shared.recordUserTurn(Stage1MailboxMemoryInput(
            "[发送了一张照片]",
            privacyMetadata: privacyMetadata
        ))
        Stage1MemoryFacade.shared.recordAssistantTurn(Stage1MailboxMemoryInput(
            "照片收到了！能不能跟我说说这张照片背后的故事？",
            privacyMetadata: privacyMetadata
        ))

        // 【KBLite】异步分析图片
        if PrivacyScopePolicy.canUse(metadata: privacyMetadata, surface: .remoteExtraction) {
            analyzeUploadedPhoto(
                image,
                aiMessageIndex: aiMessageIndex,
                imagePath: imagePath,
                privacyMetadata: privacyMetadata
            )
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    /// 异步分析上传的照片（KBLite）
    private func analyzeUploadedPhoto(
        _ image: UIImage,
        aiMessageIndex: Int,
        imagePath: String,
        privacyMetadata: MemoryPrivacyMetadata
    ) {
        // 压缩图片并转 base64（限制大小）
        let maxDimension: CGFloat = 1024
        let scaledImage: UIImage
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }

        guard let imageData = scaledImage.jpegData(compressionQuality: 0.6) else { return }
        let base64 = imageData.base64EncodedString()

        print("[KBLite] 🖼️ 开始分析图片 (size: \(imageData.count) bytes)")

        DeepSeekService.shared.analyzeImage(imageBase64: base64) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let analysis):
                    print("[KBLite] 🖼️ 图片分析完成: \(analysis.description.prefix(50))...")

                    // 入库
                    let sessionId = ConversationMemoryManager.shared.currentMemory.sessionCount + 1
                    Stage1MemoryFacade.shared.ingestImageAnalysis(
                        analysis,
                        sessionId: sessionId,
                        privacyMetadata: privacyMetadata
                    )

                    // 关联照片到足迹地图
                    if !analysis.scene.isEmpty || analysis.estimatedDecade != nil {
                        self.associatePhotoToMemory(imagePath: imagePath, analysis: analysis)
                    }

                    // 替换 AI 回复为分析结果
                    let enrichedReply = self.buildImageReply(from: analysis)
                    if aiMessageIndex < self.messages.count {
                        self.messages[aiMessageIndex] = .ai(text: enrichedReply, timestamp: Date())
                        // 更新记忆记录
                        Stage1MemoryFacade.shared.recordAssistantTurn(Stage1MailboxMemoryInput(
                            enrichedReply,
                            privacyMetadata: privacyMetadata
                        ))
                        self.messageTableView.reloadRows(at: [IndexPath(row: aiMessageIndex, section: 0)], with: .automatic)
                    }

                case .failure(let error):
                    print("[KBLite] ⚠️ 图片分析失败: \(error.localizedDescription)（使用默认回复）")
                }
            }
        }
    }

    /// 根据分析结果生成温暖的 AI 回复
    private func buildImageReply(from analysis: KBImageAnalysisResult) -> String {
        var parts: [String] = []

        if !analysis.scene.isEmpty {
            parts.append("这张照片是在\(analysis.scene)拍的吧？")
        }
        if !analysis.mood.isEmpty {
            let moodText: String
            switch analysis.mood {
            case "温馨": moodText = "看着特别温馨"
            case "欢乐": moodText = "大家笑得真开心"
            case "庄重": moodText = "拍得很正式呢"
            case "感伤": moodText = "看着让人感慨"
            default: moodText = "感觉\(analysis.mood)"
            }
            parts.append(moodText)
        }
        if let decade = analysis.estimatedDecade {
            parts.append("像是\(decade)年代的照片")
        }

        if parts.isEmpty {
            if !analysis.description.isEmpty {
                return analysis.description + "——能不能跟我说说这张照片背后的故事？"
            }
            return "照片收到了！能不能跟我说说这张照片背后的故事？"
        }

        return parts.joined(separator: "，") + "。能不能跟我说说这张照片背后的故事？"
    }

    /// 将分析结果关联到足迹地图上已有的 Memory 标注
    /// - Parameters:
    ///   - imagePath: 本地图片路径
    ///   - analysis: DeepSeek Vision 分析结果
    private func associatePhotoToMemory(imagePath: String, analysis: KBImageAnalysisResult) {
        let allMemories = MemoryRepository.shared.getAll()
        guard !allMemories.isEmpty else { return }

        let fileName = (imagePath as NSString).lastPathComponent
        var bestMatch: MemoryModel?
        var bestScore = 0

        for memory in allMemories {
            var score = 0

            // 地点名匹配
            if !analysis.scene.isEmpty, memory.location.contains(analysis.scene) || analysis.scene.contains(memory.location) {
                score += 3
            }

            // 年份匹配（±3年）
            if let decade = analysis.estimatedDecade,
               abs(memory.year - decade) <= 3 {
                score += 2
            }

            // 标题或内容包含场景关键词
            let memoryText = "\(memory.title) \(memory.subtitle) \(memory.fullContent ?? "")"
            if !analysis.scene.isEmpty, memoryText.contains(analysis.scene) {
                score += 1
            }

            if score > bestScore {
                bestScore = score
                bestMatch = memory
            }
        }

        if var match = bestMatch, bestScore >= 2 {
            match.imageNames.append(fileName)
            MemoryRepository.shared.update(match)
            print("[KBLite] 🖼️ 照片 '\(fileName)' 已关联到足迹记忆: \(match.title) (匹配度: \(bestScore))")
        } else {
            print("[KBLite] 🖼️ 照片 '\(fileName)' 未找到高度匹配的足迹记忆 (最高: \(bestScore))")
        }
    }

    /// 将图片保存到本地 Documents/photos/ 目录，返回文件路径
    private func savePhotoToLocal(_ image: UIImage) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDir = docs.appendingPathComponent("photos")
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = photosDir.appendingPathComponent(fileName)

        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }

        return fileURL.path
    }
}

// MARK: - DialogEngineDelegate
extension AIRecordingViewController: DialogEngineDelegate {

    func onDialogStarted() {
        // 保留历史消息，不清空（新会话消息追加在旧消息下方）
        isCrisisInterventionActive = false
        currentDialogStartMessageIndex = messages.count
        currentDialogAllowsMemoir = true
        currentDialogPrivacyMetadata = selectedDialogPrivacyMetadata
        pendingUserText = nil
        pendingAIText = nil
        pendingDialogEndReasonAfterDigitalHumanPlayback = nil
        hasFinalizedCurrentDialogSession = false
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        hideDigitalHumanFallbackPresentation()
        conversationWellbeingLimiter.startSession()
        updateVoiceBallState(.active)
        digitalHumanAvatarView.setState(.listening, prompt: "正在聆听")
    }

    func onASRResult(text: String, isFinal: Bool) {
        if isFinal {
            digitalHumanAvatarView.setState(.thinking, prompt: "正在整理")
            // 最终结果：直接显示为正式用户消息
            pendingUserText = nil
            currentAssistantResponseText = nil
            retryableDigitalHumanSpeechText = nil
            conversationWellbeingLimiter.recordFinalUserTurn(text)
            messages.append(.user(text: text, timestamp: Date()))
            messageTableView.reloadData()
            scrollToBottom()
            // 记录到对话记忆
            Stage1MemoryFacade.shared.recordUserTurn(Stage1MailboxMemoryInput(
                text,
                emotionHint: careEmotionHint(for: text),
                privacyMetadata: currentDialogPrivacyMetadata
            ))
        } else {
            // 中间结果：只记录不显示，等待最终确认
            pendingUserText = text
            digitalHumanAvatarView.setState(.listening, prompt: text.isEmpty ? "正在聆听" : text)
        }
    }

    func onTTSStarted(text: String) {
        publishAssistantResponse(text)
    }

    func onAssistantFinalText(text: String) {
        publishAssistantResponse(text)
    }

    private func publishAssistantResponse(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard currentAssistantResponseText != trimmed else {
            digitalHumanAvatarView.setState(.speaking, prompt: trimmed)
            return
        }

        cancelInFlightDigitalHumanPlaybackForNewAssistantResponse()
        currentAssistantResponseText = trimmed
        retryableDigitalHumanSpeechText = trimmed
        DDLogInfo("[DigitalHumanSpeech] assistant_final chars=\(trimmed.count) digitalSpeechEnabled=\(isDigitalHumanSpeechPlaybackEnabled)")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "assistant_final chars=\(trimmed.count) digitalSpeechEnabled=\(isDigitalHumanSpeechPlaybackEnabled)"
        )
        digitalHumanAvatarView.setState(.speaking, prompt: trimmed)
        if !isDigitalHumanSpeechPlaybackEnabled {
            digitalHumanAvatarView.feedSpeechText(trimmed)
        }
        synthesizeDigitalHumanSpeechIfNeeded(trimmed)
        // AI 开始说话前，将待确认的用户文本显示出来
        flushPendingUserText()
        // 清空流式缓存（TTS 已提供完整文本）
        pendingAIText = nil
        // 显示完整的 AI 句子
        messages.append(.ai(text: trimmed, timestamp: Date()))
        messageTableView.reloadData()
        scrollToBottom()
        // 记录到对话记忆
        Stage1MemoryFacade.shared.recordAssistantTurn(Stage1MailboxMemoryInput(
            trimmed,
            privacyMetadata: currentDialogPrivacyMetadata
        ))
    }

    func onChatStreaming(text: String) {
        // 流式拼接：不更新 UI，只记录最新累积文本（用于 chat 结束时兜底展示）
        pendingAIText = text
        digitalHumanAvatarView.setState(.thinking, prompt: text.isEmpty ? "正在组织回答" : text)
    }

    /// 将待确认的用户文本发布为正式消息
    private func flushPendingUserText() {
        if let text = pendingUserText, !text.isEmpty {
            messages.append(.user(text: text, timestamp: Date()))
            // 记录到对话记忆
            Stage1MemoryFacade.shared.recordUserTurn(Stage1MailboxMemoryInput(
                text,
                emotionHint: careEmotionHint(for: text),
                privacyMetadata: currentDialogPrivacyMetadata
            ))
            pendingUserText = nil
        }
    }

    private func cancelInFlightDigitalHumanPlaybackForNewAssistantResponse() {
        let hasInFlightPlayback = isAwaitingDigitalHumanAudioEnd
            || digitalHumanNativeAudioPlayer != nil
            || isDigitalHumanSystemSpeechFallbackActive
        guard hasInFlightPlayback else { return }
        let wasRealtimeDialogPaused = isRealtimeDialogPausedForDigitalHumanPlayback
        DDLogInfo("[DigitalHumanSpeech] playback_cancelled_for_new_response requestID=\(digitalHumanSpeechRequestID)")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "playback_cancelled_for_new_response requestID=\(digitalHumanSpeechRequestID)"
        )
        cancelDigitalHumanPlaybackWatchdog()
        stopDigitalHumanNativeAudio()
        stopDigitalHumanSystemSpeechFallback()
        digitalHumanAvatarView.clearSpeechAudio()
        isAwaitingDigitalHumanAudioEnd = false
        isRealtimeDialogPausedForDigitalHumanPlayback = wasRealtimeDialogPaused
    }

    func onTTSFinished() {
        if isRealtimeDialogPausedForDigitalHumanPlayback {
            DDLogInfo("[DigitalHumanSpeech] sdk_tts_finished_ignored requestID=\(digitalHumanSpeechRequestID) reason=native_audio_exclusive_playback")
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "sdk_tts_finished_ignored requestID=\(digitalHumanSpeechRequestID) reason=native_audio_exclusive_playback"
            )
            return
        }
        if !DigitalHumanSpeechPlaybackPolicy.shouldFinishOnSDKTTSFinished(
            isDigitalHumanSpeechPlaybackEnabled: isDigitalHumanSpeechPlaybackEnabled,
            isAwaitingDigitalHumanAudioEnd: isAwaitingDigitalHumanAudioEnd
        ) {
            return
        }
        finishDigitalHumanSpeechPlayback(source: "sdk_tts_finished")
    }

    private func finishDigitalHumanSpeechPlayback(source: String) {
        let wasRealtimeDialogPaused = isRealtimeDialogPausedForDigitalHumanPlayback
        // TTS 播报结束，保持 active 状态等待用户继续说话
        DDLogInfo("[DigitalHumanSpeech] playback_finished source=\(source) requestID=\(digitalHumanSpeechRequestID)")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "playback_finished source=\(source) requestID=\(digitalHumanSpeechRequestID)"
        )
        cancelDigitalHumanPlaybackWatchdog()
        stopDigitalHumanNativeAudio()
        stopDigitalHumanSystemSpeechFallback()
        if source == "timeout" {
            retryableDigitalHumanSpeechText = currentAssistantResponseText
        } else {
            retryableDigitalHumanSpeechText = nil
            hideDigitalHumanFallbackPresentation()
        }
        digitalHumanSpeechRequestID += 1
        isAwaitingDigitalHumanAudioEnd = false
        isRealtimeDialogPausedForDigitalHumanPlayback = false
        currentAssistantResponseText = nil
        if let deferredEndReason = pendingDialogEndReasonAfterDigitalHumanPlayback {
            pendingDialogEndReasonAfterDigitalHumanPlayback = nil
            DDLogInfo("[DigitalHumanSpeech] dialog_end_finalizing_after_native_audio reason=\(deferredEndReason)")
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "dialog_end_finalizing_after_native_audio reason=\(deferredEndReason)"
            )
            finalizeDialogEnd(reason: deferredEndReason)
            return
        }
        if wasRealtimeDialogPaused {
            updateVoiceBallState(.idle)
            digitalHumanAvatarView.setState(.idle, prompt: "点麦克风继续说")
        } else {
            digitalHumanAvatarView.setState(.listening, prompt: "可以继续说")
        }
        presentConversationWellbeingDecisionIfNeeded(afterAssistantPlayback: true)
    }

    func onError(error: Error) {
        updateVoiceBallState(.idle)
        stopSessionRecording()
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        digitalHumanAvatarView.clearSpeechAudio()
        digitalHumanAvatarView.setState(.error, prompt: "语音服务异常")
        showVoiceServiceRecovery()
    }

    private func synthesizeDigitalHumanSpeechIfNeeded(_ text: String) {
        guard isDigitalHumanSpeechPlaybackEnabled else { return }
        digitalHumanSpeechRequestID += 1
        isAwaitingDigitalHumanAudioEnd = true
        let requestID = digitalHumanSpeechRequestID
        let uid = UIDevice.current.identifierForVendor?.uuidString ?? "dreamjourney-user"
        scheduleDigitalHumanPlaybackWatchdog(requestID: requestID, text: text)

        DigitalHumanSpeechService.shared.synthesizeWAV(text: text, uid: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, requestID == self.digitalHumanSpeechRequestID else { return }

                switch result {
                case .success(let base64Wav):
                    DDLogInfo("[DigitalHumanSpeech] wav_synth_success requestID=\(requestID) base64Chars=\(base64Wav.count)")
                    DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                        "wav_synth_success requestID=\(requestID) base64Chars=\(base64Wav.count)"
                    )
                    self.startDigitalHumanNativeAudio(base64Wav, requestID: requestID, text: text)
                case .failure(let error):
                    self.handleDigitalHumanPlaybackFailure(
                        reason: "wav_synth_failed error=\(error.diagnosticSummary)",
                        logReason: "wav_synth_failed: \(error.localizedDescription)",
                        requestID: requestID
                    )
                }
            }
        }
    }

    private func startDigitalHumanNativeAudio(_ base64Wav: String, requestID: Int, text: String) {
        guard let wavData = Data(base64Encoded: base64Wav) else {
            handleDigitalHumanPlaybackFailure(
                reason: "native_audio_decode_failed",
                logReason: "native_audio_decode_failed: invalid base64 WAV",
                requestID: requestID
            )
            return
        }

        do {
            pauseRealtimeDialogForDigitalHumanPlayback(requestID: requestID)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true)
            logDigitalHumanAudioRoute(stage: "configured", requestID: requestID)

            stopDigitalHumanNativeAudio()
            let audioURL = try persistDigitalHumanNativeAudio(wavData, requestID: requestID)
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            digitalHumanNativeAudioPlayer = player
            digitalHumanNativeAudioURL = audioURL
            nativeAudioPlaybackRequestID = requestID

            guard player.play() else {
                handleDigitalHumanPlaybackFailure(
                    reason: "native_audio_play_failed",
                    logReason: "native_audio_play_failed: AVAudioPlayer.play returned false",
                    requestID: requestID
                )
                return
            }

            logDigitalHumanAudioRoute(stage: "started", requestID: requestID)
            DDLogInfo("[DigitalHumanSpeech] native_audio_started requestID=\(requestID) duration=\(String(format: "%.2f", player.duration)) bytes=\(wavData.count)")
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "native_audio_started requestID=\(requestID) duration=\(String(format: "%.2f", player.duration)) bytes=\(wavData.count)"
            )
            digitalHumanAvatarView.playSpeechEnvelope(duration: player.duration, prompt: text)
        } catch {
            handleDigitalHumanPlaybackFailure(
                reason: "native_audio_error",
                logReason: "native_audio_error: \(error.localizedDescription)",
                requestID: requestID
            )
        }
    }

    private func pauseRealtimeDialogForDigitalHumanPlayback(requestID: Int) {
        guard dialogEngine.isDialogActive else { return }
        isRealtimeDialogPausedForDigitalHumanPlayback = true
        stopSessionRecording()
        DDLogInfo("[DigitalHumanSpeech] realtime_dialog_pausing requestID=\(requestID) reason=native_audio_exclusive_playback")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "realtime_dialog_pausing requestID=\(requestID) reason=native_audio_exclusive_playback"
        )
        dialogEngine.stopDialog(reason: .manual)
    }

    private func persistDigitalHumanNativeAudio(_ data: Data, requestID: Int) throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("digital_human_native_\(requestID).wav")
        try data.write(to: url, options: .atomic)
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "native_audio_file requestID=\(requestID) path=Documents/diagnostics/\(url.lastPathComponent)"
        )
        return url
    }

    private func logDigitalHumanAudioRoute(stage: String, requestID: Int) {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
            .map { "\($0.portType.rawValue):\($0.portName)" }
            .joined(separator: ",")
        let inputs = session.currentRoute.inputs
            .map { "\($0.portType.rawValue):\($0.portName)" }
            .joined(separator: ",")
        let message = "audio_route stage=\(stage) requestID=\(requestID) category=\(session.category.rawValue) mode=\(session.mode.rawValue) outputVolume=\(String(format: "%.2f", session.outputVolume)) inputs=\(inputs) outputs=\(outputs)"
        DDLogInfo("[DigitalHumanSpeech] \(message)")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(message)
    }

    private func handleDigitalHumanPlaybackFailure(reason: String, logReason: String? = nil, requestID: Int? = nil) {
        if let requestID, requestID != digitalHumanSpeechRequestID {
            return
        }
        guard isAwaitingDigitalHumanAudioEnd else { return }
        let text = currentAssistantResponseText ?? ""
        stopDigitalHumanNativeAudio()
        DDLogWarn("[DigitalHumanSpeech] \(logReason ?? reason) requestID=\(digitalHumanSpeechRequestID) fallback=systemTTS")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "\(reason) requestID=\(digitalHumanSpeechRequestID) fallback=systemTTS"
        )
        let presentation = DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(reason: reason)
        showDigitalHumanFallbackPresentation(presentation)
        digitalHumanAvatarView.feedSpeechText(text)
        startDigitalHumanSystemSpeechFallback(text, requestID: digitalHumanSpeechRequestID)
    }

    private func scheduleDigitalHumanPlaybackWatchdog(requestID: Int, text: String) {
        cancelDigitalHumanPlaybackWatchdog()
        let timeout = DigitalHumanSpeechPlaybackPolicy.watchdogTimeout(for: text)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  self.digitalHumanSpeechRequestID == requestID,
                  self.isAwaitingDigitalHumanAudioEnd else { return }
            DDLogWarn("[DigitalHumanSpeech] playback_timeout requestID=\(requestID) timeout=\(String(format: "%.1f", timeout))")
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "playback_timeout requestID=\(requestID) timeout=\(String(format: "%.1f", timeout))"
            )
            let presentation = DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(reason: "playback_timeout")
            self.showDigitalHumanFallbackPresentation(presentation)
            self.finishDigitalHumanSpeechPlayback(source: "timeout")
        }
        digitalHumanPlaybackWatchdog = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    private func cancelDigitalHumanPlaybackWatchdog() {
        digitalHumanPlaybackWatchdog?.cancel()
        digitalHumanPlaybackWatchdog = nil
    }

    private func startDigitalHumanSystemSpeechFallback(_ text: String, requestID: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            finishDigitalHumanSpeechPlayback(source: "empty_fallback_text")
            return
        }
        stopDigitalHumanSystemSpeechFallback()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        isDigitalHumanSystemSpeechFallbackActive = true
        systemSpeechFallbackRequestID = requestID
        digitalHumanFallbackSynthesizer.speak(utterance)
    }

    private func stopDigitalHumanSystemSpeechFallback() {
        isDigitalHumanSystemSpeechFallbackActive = false
        systemSpeechFallbackRequestID = nil
        if digitalHumanFallbackSynthesizer.isSpeaking {
            digitalHumanFallbackSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func stopDigitalHumanNativeAudio() {
        if digitalHumanNativeAudioPlayer?.isPlaying == true {
            digitalHumanNativeAudioPlayer?.stop()
        }
        digitalHumanNativeAudioPlayer?.delegate = nil
        digitalHumanNativeAudioPlayer = nil
        digitalHumanNativeAudioURL = nil
        nativeAudioPlaybackRequestID = nil
    }

    private func resetDigitalHumanSpeechPlayback(stopFallbackAudio: Bool) {
        cancelDigitalHumanPlaybackWatchdog()
        stopDigitalHumanNativeAudio()
        if stopFallbackAudio {
            stopDigitalHumanSystemSpeechFallback()
        }
        hideDigitalHumanFallbackPresentation()
        digitalHumanSpeechRequestID += 1
        isAwaitingDigitalHumanAudioEnd = false
        isRealtimeDialogPausedForDigitalHumanPlayback = false
        pendingDialogEndReasonAfterDigitalHumanPlayback = nil
        currentAssistantResponseText = nil
        retryableDigitalHumanSpeechText = nil
    }

    private func showDigitalHumanFallbackPresentation(_ presentation: DigitalHumanSpeechPlaybackPolicy.FallbackPresentation) {
        digitalHumanFallbackTitleLabel.text = presentation.title
        digitalHumanFallbackMessageLabel.text = presentation.message
        digitalHumanRetryButton.configuration?.title = presentation.recoveryActionTitle
        digitalHumanContinueButton.configuration?.title = presentation.continueActionTitle
        digitalHumanFallbackCard.isHidden = false
        digitalHumanFallbackHeightConstraint.isActive = false
        UIView.animate(withDuration: 0.22) {
            self.digitalHumanFallbackCard.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    private func hideDigitalHumanFallbackPresentation() {
        guard !digitalHumanFallbackCard.isHidden || digitalHumanFallbackCard.alpha > 0 else { return }
        digitalHumanFallbackHeightConstraint.isActive = true
        UIView.animate(withDuration: 0.18, animations: {
            self.digitalHumanFallbackCard.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.digitalHumanFallbackCard.isHidden = true
        })
    }

    private func showVoiceServiceRecovery() {
        let presentation = DigitalHumanSpeechPlaybackPolicy.FallbackPresentation(
            title: "语音服务暂时不可用",
            message: "本次对话已安全收尾，可以稍后重试；当前不会写入共享记忆，也不影响查看其他功能。",
            recoveryActionTitle: "重试数字人",
            continueActionTitle: "继续语音"
        )
        showDigitalHumanFallbackPresentation(presentation)
        showToast("语音服务暂时不可用，可稍后重试", type: .info)
    }

    @objc private func retryDigitalHumanTapped() {
        guard let text = (currentAssistantResponseText ?? retryableDigitalHumanSpeechText)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            hideDigitalHumanFallbackPresentation()
            digitalHumanAvatarView.setState(.listening, prompt: "可以继续说")
            return
        }
        currentAssistantResponseText = text
        retryableDigitalHumanSpeechText = nil
        stopDigitalHumanSystemSpeechFallback()
        hideDigitalHumanFallbackPresentation()
        digitalHumanAvatarView.clearSpeechAudio()
        digitalHumanAvatarView.setState(.speaking, prompt: text)
        synthesizeDigitalHumanSpeechIfNeeded(text)
    }

    @objc private func continueVoiceFallbackTapped() {
        retryableDigitalHumanSpeechText = nil
        hideDigitalHumanFallbackPresentation()
        digitalHumanAvatarView.setState(.listening, prompt: "可以继续说")
    }

    func onSafetyTriggered(assessment: SafetyAssessment) {
        isCrisisInterventionActive = true
        currentDialogAllowsMemoir = false
        pendingUserText = nil
        pendingAIText = nil
        pendingDialogEndReasonAfterDigitalHumanPlayback = nil
        hasFinalizedCurrentDialogSession = true
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        Stage1MemoryFacade.shared.discardCurrentConversationSession()
        stopSessionRecording()
        updateVoiceBallState(.idle)
        digitalHumanAvatarView.clearSpeechAudio()
        digitalHumanAvatarView.setState(.idle, prompt: "准备聆听家族故事")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.presentedViewController == nil else { return }
            let viewController = CrisisInterventionViewController(assessment: assessment)
            viewController.modalPresentationStyle = .fullScreen
            self.present(viewController, animated: true)
        }
    }

    func onDialogEnded(reason: DialogEndReason) {
        if isRealtimeDialogPausedForDigitalHumanPlayback {
            pendingDialogEndReasonAfterDigitalHumanPlayback = reason
            DDLogInfo("[DigitalHumanSpeech] dialog_end_deferred_for_native_audio reason=\(reason)")
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "dialog_end_deferred_for_native_audio reason=\(reason)"
            )
            updateVoiceBallState(.idle)
            return
        }

        finalizeDialogEnd(reason: reason)
    }

    private func finalizeDialogEnd(reason: DialogEndReason) {
        guard !hasFinalizedCurrentDialogSession else {
            DDLogInfo("[AIRecording] dialog_end_duplicate_ignored reason=\(reason)")
            return
        }
        hasFinalizedCurrentDialogSession = true
        pendingDialogEndReasonAfterDigitalHumanPlayback = nil

        if case .crisis = reason {
            pendingUserText = nil
            pendingAIText = nil
            currentDialogAllowsMemoir = false
            Stage1MemoryFacade.shared.discardCurrentConversationSession()
            updateVoiceBallState(.idle)
            resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
            digitalHumanAvatarView.clearSpeechAudio()
            digitalHumanAvatarView.setState(.idle, prompt: "准备聆听家族故事")
            return
        }

        // 对话结束时，刷新未展示的待确认文本
        flushPendingUserText()
        // 如果有未展示的 AI 流式文本（没有经过 TTS），兜底展示
        if let aiText = pendingAIText, !aiText.isEmpty {
            messages.append(.ai(text: aiText, timestamp: Date()))
            Stage1MemoryFacade.shared.recordAssistantTurn(Stage1MailboxMemoryInput(
                aiText,
                privacyMetadata: currentDialogPrivacyMetadata
            ))
            pendingAIText = nil
            messageTableView.reloadData()
            scrollToBottom()
        }
        // 结束会话：提取摘要并持久化
        Stage1MemoryFacade.shared.finishConversationSession()
        updateVoiceBallState(.idle)
        resetDigitalHumanSpeechPlayback(stopFallbackAudio: true)
        digitalHumanAvatarView.clearSpeechAudio()
        digitalHumanAvatarView.setState(.idle, prompt: "准备聆听家族故事")

        switch reason {
        case .keyword:
            showToast("寻梦环游已经记住您说的了，下次再聊～", type: .success)
        case .silenceTimeout:
            showToast("您好像有事忙，寻梦环游先告辞啦～", type: .info)
        case .manual:
            break
        case .serverEnded:
            break
        case .crisis:
            break
        }

        // 延迟弹出回忆录生成卡片（等待 toast 消失后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self,
                  !self.isCrisisInterventionActive,
                  DialogEndIntentPolicy.shouldPromptMemoir(for: reason),
                  self.currentDialogAllowsMemoir,
                  self.presentedViewController == nil else { return }
            self.showMemoirGenerationCard()
        }
    }

    // MARK: - 对话并行录音（用于声音复刻训练）

    /// 开始并行录音（与豆包 SDK 同时录制，用于声音复刻）
    private func startSessionRecording() {
        let recordingsDir = FileManager.default.temporaryDirectory.appendingPathComponent("TGSessionRecordings")
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let fileURL = recordingsDir.appendingPathComponent("session_\(Int(Date().timeIntervalSince1970)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            sessionRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            sessionRecorder?.record()
            DDLogInfo("[AIRecording] 并行录音已启动: \(fileURL.lastPathComponent)")
        } catch {
            DDLogWarn("[AIRecording] 并行录音启动失败: \(error.localizedDescription)")
            sessionRecorder = nil
        }
    }

    private func careEmotionHint(for text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let negativeHints = ["孤单", "难过", "烦", "没意思", "不想说", "睡不好", "失眠", "头晕", "胸闷", "疼", "不舒服", "吃不下"]
        if negativeHints.contains(where: { normalized.contains($0) }) {
            return "negative"
        }
        let lowEnergyHints = ["累", "没精神", "不太想", "想休息"]
        if lowEnergyHints.contains(where: { normalized.contains($0) }) {
            return "low"
        }
        return "neutral"
    }

    /// 停止并行录音并保存到持久化目录
    private func stopSessionRecording() {
        guard let recorder = sessionRecorder, recorder.isRecording else {
            sessionRecorder = nil
            return
        }

        // Bug fix: 在 stop() 之前读取 currentTime，部分 iOS 版本 stop() 后 currentTime 会重置为 0
        let duration = recorder.currentTime
        recorder.stop()

        let url = recorder.url
        // 检查录音时长，至少 3 秒才有价值用于声音复刻
        if duration >= 3 {
            // 移动到 Application Support 持久化目录（tmp 目录可能被系统清理）
            let sessionId = "session_\(Int(Date().timeIntervalSince1970))"
            if let persistentURL = MemoirRepository.shared.saveRecording(from: url, sessionId: sessionId) {
                lastSessionRecordingURL = persistentURL
                lastSessionId = sessionId   // 记录 sessionId，生成回忆录时一并传给 MemoirFlowManager
                DDLogInfo("[AIRecording] 对话录音已持久化: \(persistentURL.lastPathComponent), 时长: \(String(format: "%.1f", duration))秒")
            } else {
                // 持久化失败则退回使用 tmp 文件
                lastSessionRecordingURL = url
                lastSessionId = nil
                DDLogWarn("[AIRecording] 录音持久化失败，使用 tmp 文件: \(url.lastPathComponent)")
            }
        } else {
            lastSessionRecordingURL = nil
            lastSessionId = nil
            try? FileManager.default.removeItem(at: url)
            DDLogInfo("[AIRecording] 对话录音太短(\(String(format: "%.1f", duration))秒)，已丢弃")
        }
        sessionRecorder = nil
    }

    /// 显示回忆录生成弹窗
    private func showMemoirGenerationCard() {
        guard currentDialogAllowsMemoir else { return }
        guard PrivacyScopePolicy.canUse(metadata: currentDialogPrivacyMetadata, surface: .memoirGeneration) else {
            return
        }
        MemoirGenerationCard.show(in: view,
            onGenerate: { [weak self] in
                self?.handleMemoirGeneration()
            },
            onDismiss: nil
        )
    }

    /// 处理回忆录生成请求
    private func handleMemoirGeneration() {
        guard currentDialogAllowsMemoir else {
            showToast("安全事件后的对话不会生成回忆录", type: .info)
            return
        }
        guard PrivacyScopePolicy.canUse(metadata: currentDialogPrivacyMetadata, surface: .memoirGeneration) else {
            showToast("当前对话未授权生成回忆录，可在下次开聊前选择“可生成”", type: .info)
            return
        }
        let sessionMessages = Array(messages.dropFirst(currentDialogStartMessageIndex))
        let memoirSessionMessages = sessionMessages.filter { !$0.isWellbeingNotice }
        guard !memoirSessionMessages.isEmpty else {
            showToast("本次对话内容不足，暂不能生成回忆录", type: .info)
            return
        }
        // 将 TGMessage 转换为 Memoir 模块的 DialogMessage 格式
        let dialogMessages = PrivacyScopePolicy.sanitized(
            items: MemoirFlowManager.convertToDialogMessages(
                memoirSessionMessages,
                privacyMetadata: currentDialogPrivacyMetadata
            ),
            surface: .memoirGeneration
        )

        // 本地内容质量检测（即时反馈，无需等 API 调用）
        if let reason = MemoirFlowManager.checkDialogContent(dialogMessages) {
            showToast(reason, type: .info)
            return
        }

        MemoirFlowManager.shared.startGeneration(
            on: self,
            dialogMessages: dialogMessages,
            recordingURL: lastSessionRecordingURL,
            sessionId: lastSessionId
        )
    }
}

extension AIRecordingViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  DigitalHumanSpeechPlaybackPolicy.shouldAcceptSystemSpeechCallback(
                    isFallbackActive: self.isDigitalHumanSystemSpeechFallbackActive,
                    fallbackRequestID: self.systemSpeechFallbackRequestID,
                    currentRequestID: self.digitalHumanSpeechRequestID
                  ) else { return }
            self.isDigitalHumanSystemSpeechFallbackActive = false
            self.systemSpeechFallbackRequestID = nil
            self.finishDigitalHumanSpeechPlayback(source: "system_tts")
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  DigitalHumanSpeechPlaybackPolicy.shouldAcceptSystemSpeechCallback(
                    isFallbackActive: self.isDigitalHumanSystemSpeechFallbackActive,
                    fallbackRequestID: self.systemSpeechFallbackRequestID,
                    currentRequestID: self.digitalHumanSpeechRequestID
                  ) else { return }
            self.isDigitalHumanSystemSpeechFallbackActive = false
            self.systemSpeechFallbackRequestID = nil
            self.finishDigitalHumanSpeechPlayback(source: "system_tts_cancelled")
        }
    }
}

extension AIRecordingViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  player === self.digitalHumanNativeAudioPlayer,
                  self.nativeAudioPlaybackRequestID == self.digitalHumanSpeechRequestID else { return }
            if flag {
                self.finishDigitalHumanSpeechPlayback(source: "native_audio")
            } else {
                self.handleDigitalHumanPlaybackFailure(
                    reason: "native_audio_interrupted",
                    logReason: "native_audio_interrupted: playback did not finish successfully",
                    requestID: self.digitalHumanSpeechRequestID
                )
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  player === self.digitalHumanNativeAudioPlayer,
                  self.nativeAudioPlaybackRequestID == self.digitalHumanSpeechRequestID else { return }
            self.handleDigitalHumanPlaybackFailure(
                reason: "native_audio_decode_error",
                logReason: "native_audio_decode_error: \(error?.localizedDescription ?? "unknown")",
                requestID: self.digitalHumanSpeechRequestID
            )
        }
    }
}

// MARK: - Digital Human Avatar

private final class DigitalHumanAvatarView: UIView, WKNavigationDelegate, WKScriptMessageHandler {
    enum AvatarState: String {
        case idle
        case listening
        case thinking
        case speaking
        case error
    }

    private let webView: WKWebView
    private let schemeHandler: AvatarWebResourceSchemeHandler
    private var currentState: AvatarState = .idle
    private var currentPrompt = "准备聆听家族故事"
    private var didFinishInitialLoad = false
    private var didRevealInitialAvatar = false
    private var initialAvatarRevealFallbackWorkItem: DispatchWorkItem?
    private var pendingSpeechDuration: TimeInterval?
    var onAudioPlaybackEnded: (() -> Void)?
    var onAudioPlaybackFailed: ((String) -> Void)?

    override init(frame: CGRect) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        let schemeHandler = AvatarWebResourceSchemeHandler()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: Self.avatarResourceScheme)
        self.schemeHandler = schemeHandler
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frame)
        configuration.userContentController.add(WeakScriptMessageDelegate(self), name: "avatarHealth")
        setupView()
        loadAvatarHTML()
    }

    required init?(coder: NSCoder) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        let schemeHandler = AvatarWebResourceSchemeHandler()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: Self.avatarResourceScheme)
        self.schemeHandler = schemeHandler
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(coder: coder)
        configuration.userContentController.add(WeakScriptMessageDelegate(self), name: "avatarHealth")
        setupView()
        loadAvatarHTML()
    }

    deinit {
        initialAvatarRevealFallbackWorkItem?.cancel()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "avatarHealth")
    }

    func setState(_ state: AvatarState, prompt: String? = nil) {
        currentState = state
        if state != .speaking {
            pendingSpeechDuration = nil
        }
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentPrompt = prompt
        }
        applyCurrentState()
    }

    func feedSpeechText(_ text: String) {
        let estimatedSeconds = min(max(Double(text.count) * 0.18, 1.2), 12.0)
        playSpeechEnvelope(duration: estimatedSeconds, prompt: text)
    }

    func playSpeechEnvelope(duration: TimeInterval, prompt: String? = nil) {
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentPrompt = prompt
        }
        currentState = .speaking
        pendingSpeechDuration = duration
        guard didFinishInitialLoad else { return }
        let promptJSON = Self.jsonStringLiteral(currentPrompt)
        let script = """
        if (window.DreamJourneyAvatar) {
          window.DreamJourneyAvatar.setState('speaking', \(promptJSON));
          window.DreamJourneyAvatar.playSpeechEnvelope(\(duration));
        }
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func feedAudioBase64(_ base64: String) {
        guard didFinishInitialLoad else { return }
        let audioJSON = Self.jsonStringLiteral(base64)
        let script = "window.DreamJourneyAvatar && window.DreamJourneyAvatar.feedAudioBase64(\(audioJSON));"
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.onAudioPlaybackFailed?("evaluateJavaScript: \(error.localizedDescription)")
            }
        }
    }

    func clearSpeechAudio() {
        pendingSpeechDuration = nil
        guard didFinishInitialLoad else { return }
        let script = "window.DreamJourneyAvatar && window.DreamJourneyAvatar.clearAudio();"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func setupView() {
        backgroundColor = .clear
        layer.cornerRadius = 16
        layer.masksToBounds = true
        layer.borderColor = UIColor.clear.cgColor
        layer.borderWidth = 0

        webView.navigationDelegate = self
        webView.alpha = 1
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func loadAvatarHTML() {
        guard let url = URL(string: "\(Self.avatarResourceScheme)://local/avatar.html") else {
            webView.loadHTMLString(Self.avatarHTML, baseURL: Bundle.main.resourceURL)
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent("avatar_startup_single_surface mode=html_string")
            return
        }
        webView.load(URLRequest(url: url))
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent("avatar_web_load mode=url_scheme")
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent("avatar_startup_single_surface mode=url_scheme")
    }

    private func applyCurrentState() {
        guard didFinishInitialLoad else { return }
        let promptJSON = Self.jsonStringLiteral(currentPrompt)
        let script = "window.DreamJourneyAvatar && window.DreamJourneyAvatar.setState('\(currentState.rawValue)', \(promptJSON));"
        webView.evaluateJavaScript(script, completionHandler: nil)
        if currentState == .speaking, let pendingSpeechDuration {
            let speechScript = "window.DreamJourneyAvatar && window.DreamJourneyAvatar.playSpeechEnvelope(\(pendingSpeechDuration));"
            webView.evaluateJavaScript(speechScript, completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishInitialLoad = true
        applyCurrentState()
        scheduleInitialAvatarRevealFallback()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "avatarHealth" else { return }
        DDLogInfo("[DigitalHuman] \(message.body)")
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
                "avatar_health type=unknown detail=\(DigitalHumanPlaybackEvidenceStore.sanitize(String(describing: message.body)))"
            )
            return
        }
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "avatar_health type=\(DigitalHumanPlaybackEvidenceStore.sanitize(type)) detail=\(DigitalHumanPlaybackEvidenceStore.sanitize(String(describing: body["detail"] ?? "")))"
        )
        if type == "avatar_video_surface_ready" {
            revealInitialAvatarIfNeeded(reason: type)
        }

        switch DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: type) {
        case .finish:
            onAudioPlaybackEnded?()
        case .fail:
            onAudioPlaybackFailed?(String(describing: body["detail"] ?? type))
        case .ignore:
            break
        }
    }

    private func scheduleInitialAvatarRevealFallback() {
        initialAvatarRevealFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.didRevealInitialAvatar else { return }
            DigitalHumanPlaybackEvidenceStore.shared.appendEvent("avatar_startup_waiting_for_video reason=timeout")
        }
        initialAvatarRevealFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: workItem)
    }

    private func revealInitialAvatarIfNeeded(reason: String) {
        guard !didRevealInitialAvatar else { return }
        didRevealInitialAvatar = true
        initialAvatarRevealFallbackWorkItem?.cancel()
        initialAvatarRevealFallbackWorkItem = nil
        DigitalHumanPlaybackEvidenceStore.shared.appendEvent(
            "avatar_startup_reveal reason=\(DigitalHumanPlaybackEvidenceStore.sanitize(reason))"
        )
    }

    private static func jsonStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }

    private final class WeakScriptMessageDelegate: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?

        init(_ target: WKScriptMessageHandler?) {
            self.target = target
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(userContentController, didReceive: message)
        }
    }

    private final class AvatarWebResourceSchemeHandler: NSObject, WKURLSchemeHandler {
        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url else {
                fail(urlSchemeTask, message: "missing URL")
                return
            }

            do {
                let path = normalizedPath(from: url)
                let resource = try resourceData(for: path)
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": resource.mimeType,
                        "Content-Length": "\(resource.data.count)",
                        "Access-Control-Allow-Origin": "*",
                        "Cache-Control": "no-store"
                    ]
                )
                if let response {
                    urlSchemeTask.didReceive(response)
                }
                urlSchemeTask.didReceive(resource.data)
                urlSchemeTask.didFinish()
            } catch {
                fail(urlSchemeTask, message: error.localizedDescription)
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

        private func normalizedPath(from url: URL) -> String {
            let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return rawPath.removingPercentEncoding ?? rawPath
        }

        private func resourceData(for path: String) throws -> (data: Data, mimeType: String) {
            if path.isEmpty || path == "avatar.html" {
                guard let data = DigitalHumanAvatarView.avatarHTML.data(using: .utf8) else {
                    throw NSError(domain: "DigitalHumanAvatarView", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "avatar html encoding failed"
                    ])
                }
                return (data, "text/html; charset=utf-8")
            }

            let filename = (path as NSString).lastPathComponent
            guard let sourceURL = bundleURL(for: filename) else {
                throw NSError(domain: "DigitalHumanAvatarView", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "missing avatar resource \(filename)"
                ])
            }
            return (try Data(contentsOf: sourceURL), mimeType(for: filename))
        }

        private func bundleURL(for filename: String) -> URL? {
            if let directURL = Bundle.main.url(forResource: filename, withExtension: nil) {
                return directURL
            }
            let nsFilename = filename as NSString
            let name = nsFilename.deletingPathExtension
            let ext = nsFilename.pathExtension
            if !name.isEmpty, !ext.isEmpty,
               let typedURL = Bundle.main.url(forResource: name, withExtension: ext) {
                return typedURL
            }
            return Bundle.main.resourceURL?.appendingPathComponent(filename)
        }

        private func mimeType(for filename: String) -> String {
            switch (filename as NSString).pathExtension.lowercased() {
            case "html":
                return "text/html; charset=utf-8"
            case "js":
                return "application/javascript; charset=utf-8"
            case "wasm":
                return "application/wasm"
            case "mp4":
                return "video/mp4"
            case "gz":
                return "application/gzip"
            case "png":
                return "image/png"
            default:
                return "application/octet-stream"
            }
        }

        private func fail(_ urlSchemeTask: WKURLSchemeTask, message: String) {
            let error = NSError(
                domain: "DigitalHumanAvatarView",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            urlSchemeTask.didFailWithError(error)
        }
    }

    private static let avatarResourceScheme = "dreamjourney-avatar"

    private static let avatarHTML = """
    <!doctype html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <style>
    :root {
      color-scheme: light;
      --ink: #2c251f;
      --muted: rgba(44, 37, 31, .62);
      --orange: #ed9239;
      --green: #5a8f72;
      --blue: #4c7498;
      --paper: #fbf6ef;
    }
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
    }
    #stage {
      position: relative;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: transparent;
    }
    #status {
      position: absolute;
      top: 14px;
      left: 14px;
      right: 14px;
      z-index: 10;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      color: var(--ink);
    }
    #stateText {
      font-size: 15px;
      font-weight: 700;
      white-space: nowrap;
    }
    #prompt {
      max-width: 58%;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.25;
      text-align: right;
      overflow: hidden;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }
    #screen, #screen2 {
      position: absolute;
      inset: 0;
      display: none;
    }
    #screen2 {
      z-index: 20;
      pointer-events: none;
    }
    #avatarPoster, #canvas_video {
      position: absolute;
      left: 50%;
      bottom: -8px;
      width: min(60vw, 220px);
      height: auto;
      max-height: calc(100% - 48px);
      transform: translateX(-50%);
      object-fit: contain;
      pointer-events: none;
      will-change: opacity;
    }
    #avatarPoster {
      z-index: 20;
      opacity: 1;
      transition: opacity .18s ease-out;
    }
    #canvas_video {
      z-index: 21;
      opacity: 0;
      transition: opacity .22s ease-out;
    }
    body[data-video-ready="true"] #avatarPoster {
      opacity: 0;
    }
    body[data-video-ready="true"] #canvas_video {
      opacity: 1;
    }
    body[data-video-ready="true"] #loadingSpinner,
    body[data-video-ready="true"] #startMessage {
      display: none;
    }
    #canvas_gl, #background_video {
      display: none;
    }
    #fallbackAvatar {
      position: absolute;
      left: 50%;
      bottom: 16px;
      width: 142px;
      height: 142px;
      transform: translateX(-50%);
      z-index: 2;
      display: none;
    }
    .halo {
      position: absolute;
      inset: 8px;
      border-radius: 50%;
      background: rgba(237, 146, 57, .18);
      box-shadow: 0 18px 46px rgba(237, 146, 57, .24);
      animation: breathe 2.4s ease-in-out infinite;
    }
    .head {
      position: absolute;
      left: 26px;
      top: 18px;
      width: 90px;
      height: 106px;
      border-radius: 45px 45px 38px 38px;
      background: linear-gradient(180deg, #f2c5a3, #d99b72);
      box-shadow: inset 0 -10px 18px rgba(100, 60, 38, .12);
    }
    .hair {
      position: absolute;
      left: 22px;
      top: 10px;
      width: 98px;
      height: 58px;
      border-radius: 54px 54px 26px 26px;
      background: #3a2c26;
    }
    .eye {
      position: absolute;
      top: 64px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #2c251f;
    }
    .eye.left { left: 56px; }
    .eye.right { right: 56px; }
    .mouth {
      position: absolute;
      left: 63px;
      top: 90px;
      width: 16px;
      height: 5px;
      border-radius: 10px;
      background: #7a443a;
      transform-origin: center;
    }
    body[data-state="speaking"] .mouth {
      animation: talk .34s ease-in-out infinite;
    }
    body[data-state="listening"] .halo {
      background: rgba(90, 143, 114, .22);
      box-shadow: 0 18px 46px rgba(90, 143, 114, .25);
    }
    body[data-state="thinking"] .halo {
      background: rgba(76, 116, 152, .20);
      box-shadow: 0 18px 46px rgba(76, 116, 152, .22);
    }
    body[data-state="error"] .halo {
      background: rgba(207, 76, 65, .20);
      box-shadow: 0 18px 46px rgba(207, 76, 65, .22);
    }
    #loadingSpinner {
      position: absolute;
      display: none;
      right: 15px;
      bottom: 14px;
      z-index: 9;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--orange);
      box-shadow: 14px 0 rgba(237, 146, 57, .5), 28px 0 rgba(237, 146, 57, .28);
      animation: dots 1s ease-in-out infinite;
    }
    #startMessage {
      position: absolute;
      display: none;
      left: 14px;
      bottom: 12px;
      z-index: 8;
      color: rgba(44, 37, 31, .45);
      font-size: 11px;
      font-weight: 600;
    }
    @keyframes breathe {
      0%, 100% { transform: scale(.96); opacity: .72; }
      50% { transform: scale(1.04); opacity: 1; }
    }
    @keyframes talk {
      0%, 100% { height: 5px; transform: scaleX(1); }
      50% { height: 16px; transform: scaleX(.78); }
    }
    @keyframes dots {
      0%, 100% { opacity: .5; transform: translateY(0); }
      50% { opacity: 1; transform: translateY(-2px); }
    }
    </style>
    </head>
    <body data-state="idle">
      <div id="stage">
        <div id="status">
          <div id="stateText">准备聆听</div>
          <div id="prompt">准备聆听家族故事</div>
        </div>
        <div id="fallbackAvatar" aria-hidden="true">
          <div class="halo"></div>
          <div class="hair"></div>
          <div class="head"></div>
          <div class="eye left"></div>
          <div class="eye right"></div>
          <div class="mouth"></div>
        </div>
        <div id="loadingSpinner"></div>
        <div id="startMessage">正在加载数字人</div>
        <div id="screen"></div>
        <img id="avatarPoster" src="avatar_poster.png" alt="" aria-hidden="true">
        <div id="screen2">
          <video id="background_video" muted playsinline loop></video>
          <canvas id="canvas_video"></canvas>
          <canvas id="canvas_gl"></canvas>
        </div>
      </div>
      <script>
        const avatarRuntime = {
          audioQueue: [],
          audioContext: null,
          currentSource: null,
          isPlayingAudio: false,
          isVideoReady: false,
          pendingSpeechDuration: null,
          speechTimer: null,
          postHealth: function(type, detail) {
            try {
              window.webkit?.messageHandlers?.avatarHealth?.postMessage({ type, detail });
            } catch (_) {}
          },
          hideFallbackAvatar: function() {
            const fallback = document.getElementById('fallbackAvatar');
            if (fallback) {
              fallback.style.display = 'none';
            }
          },
          markAvatarVideoReady: function(detail) {
            this.isVideoReady = true;
            document.body.dataset.videoReady = 'true';
            const spinner = document.getElementById('loadingSpinner');
            const startMessage = document.getElementById('startMessage');
            const screen = document.getElementById('screen');
            const screen2 = document.getElementById('screen2');
            if (spinner) {
              spinner.style.display = 'none';
            }
            if (startMessage) {
              startMessage.style.display = 'none';
            }
            if (screen) {
              screen.style.display = 'block';
            }
            if (screen2) {
              screen2.style.display = 'block';
            }
            this.hideFallbackAvatar();
            this.postHealth('avatar_video_surface_ready', detail || 'video surface ready');
            if (document.body.dataset.state === 'speaking' && this.pendingSpeechDuration) {
              window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.playForDuration(this.pendingSpeechDuration);
            } else {
              window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.pause('video_ready_idle');
            }
          },
          probeResources: async function() {
            const result = {
              baseURI: document.baseURI,
              pako: !!window.pako,
              createQtAppInstance: typeof window.createQtAppInstance,
              webAssembly: typeof WebAssembly !== 'undefined'
            };
            const paths = [
              'pako.min.js',
              'DHLiveMini.js',
              'DHLiveMini.wasm',
              'MiniLive2.js',
              'MiniMateLoader.js',
              '01.mp4',
              'combined_data.json.gz',
              'bs_texture_halfFace.png'
            ];
            for (const path of paths) {
              try {
                const response = await fetch(path, { cache: 'no-store' });
                result[path] = response.status + ':' + response.ok;
              } catch (error) {
                result[path] = 'error:' + String(error && error.message ? error.message : error);
              }
            }
            this.postHealth('resource_probe', result);
          },
          markShellReady: function(detail) {
            if (this.isVideoReady) {
              this.postHealth('avatar_shell_ready_ignored', detail || 'video surface already ready');
              return;
            }
            const startMessage = document.getElementById('startMessage');
            if (startMessage) {
              startMessage.style.display = 'none';
            }
            this.postHealth('avatar_shell_loading', detail || 'shell ready, waiting for first video frame');
          },
          setState: function(state, prompt) {
            document.body.dataset.state = state || 'idle';
            const title = {
              idle: '准备聆听',
              listening: '正在聆听',
              thinking: '正在整理',
              speaking: '正在讲述',
              error: '需要重试'
            }[state] || '准备聆听';
            document.getElementById('stateText').textContent = title;
            document.getElementById('prompt').textContent = prompt || '准备聆听家族故事';
            if (state !== 'speaking') {
              this.pendingSpeechDuration = null;
              window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.pause('state_' + (state || 'idle'));
            }
          },
          playSpeechEnvelope: function(durationSeconds) {
            clearTimeout(this.speechTimer);
            document.body.dataset.state = 'speaking';
            const duration = Math.max(600, Math.min(Number(durationSeconds || 2) * 1000, 60000));
            this.pendingSpeechDuration = duration / 1000;
            window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.playForDuration(this.pendingSpeechDuration);
            this.speechTimer = setTimeout(() => {
              if (document.body.dataset.state === 'speaking') {
                this.setState('listening', '可以继续说');
                this.pendingSpeechDuration = null;
                window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.pause('speech_envelope_ended');
                this.postHealth('speech_envelope_ended', duration);
              }
            }, duration);
          },
          feedAudioBase64: function(base64Audio) {
            if (!base64Audio) {
              this.postHealth('audio_ignored', 'empty base64');
              return false;
            }
            try {
              const bytes = this.base64ToUint8Array(base64Audio);
              this.audioQueue.push(bytes);
              this.playNextAudio();
              return true;
            } catch (error) {
              this.postHealth('audio_error', String(error && error.message ? error.message : error));
              return false;
            }
          },
          playNextAudio: function() {
            if (this.isPlayingAudio || this.audioQueue.length === 0) {
              return;
            }
            const bytes = this.audioQueue.shift();
            if (window.Module && Module._malloc && Module._setAudioBuffer && Module.HEAPU8) {
              const ptr = Module._malloc(bytes.byteLength);
              Module.HEAPU8.set(bytes, ptr);
              Module._setAudioBuffer(ptr, bytes.byteLength);
              Module._free(ptr);
              this.postHealth('audio_buffered', bytes.byteLength);
            } else {
              this.postHealth('audio_module_unavailable', 'Module audio api unavailable');
            }

            this.isPlayingAudio = true;
            this.ensureAudioContext();
            const wavBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
            this.audioContext.decodeAudioData(wavBuffer, (audioBuffer) => {
              const source = this.audioContext.createBufferSource();
              this.currentSource = source;
              source.buffer = audioBuffer;
              source.connect(this.audioContext.destination);
              source.onended = () => {
                this.currentSource = null;
                this.isPlayingAudio = false;
                if (this.audioQueue.length > 0) {
                  this.playNextAudio();
                } else {
                  this.pendingSpeechDuration = null;
                  window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.pause('audio_ended');
                  this.postHealth('audio_ended', audioBuffer.duration);
                }
              };
              this.setState('speaking', '正在讲述');
              source.start(0);
            }, (error) => {
              this.postHealth('audio_decode_error', String(error && error.message ? error.message : error));
              this.isPlayingAudio = false;
              this.playSpeechEnvelope(Math.max(1.2, bytes.byteLength / 24000));
              this.playNextAudio();
            });
          },
          ensureAudioContext: function() {
            if (!this.audioContext || this.audioContext.state === 'closed') {
              this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            } else if (this.audioContext.state === 'suspended') {
              this.audioContext.resume();
            }
          },
          clearAudio: function() {
            clearTimeout(this.speechTimer);
            try {
              if (this.currentSource) {
                this.currentSource.stop();
              }
            } catch (_) {}
            this.currentSource = null;
            this.audioQueue = [];
            this.isPlayingAudio = false;
            if (window.Module && Module._clearAudio) {
              Module._clearAudio();
            }
            this.pendingSpeechDuration = null;
            window.DreamJourneyMiniLive && window.DreamJourneyMiniLive.pause('clear_audio');
            this.setState('idle', '准备聆听家族故事');
          },
          base64ToUint8Array: function(base64) {
            const raw = atob(base64);
            const bytes = new Uint8Array(raw.length);
            for (let i = 0; i < raw.length; i += 1) {
              bytes[i] = raw.charCodeAt(i);
            }
            return bytes;
          }
        };
        window.DreamJourneyAvatar = avatarRuntime;
        const avatarPoster = document.getElementById('avatarPoster');
        if (avatarPoster) {
          if (avatarPoster.complete && avatarPoster.naturalWidth > 0) {
            avatarRuntime.postHealth('avatar_startup_poster_visible', 'poster loaded from cache');
          } else {
            avatarPoster.addEventListener('load', function() {
              avatarRuntime.postHealth('avatar_startup_poster_visible', 'poster loaded');
            }, { once: true });
            avatarPoster.addEventListener('error', function() {
              avatarRuntime.postHealth('avatar_startup_poster_error', 'poster failed to load');
            }, { once: true });
          }
        }
        avatarRuntime.markShellReady('dom ready');
        setTimeout(function() {
          window.DreamJourneyAvatar && window.DreamJourneyAvatar.markShellReady('startup timeout fallback');
        }, 1800);
        avatarRuntime.postHealth('capabilities', {
          webgl2: !!document.createElement('canvas').getContext('webgl2'),
          wasm: typeof WebAssembly !== 'undefined',
          secureContext: window.isSecureContext
        });
        window.addEventListener('error', function(event) {
          console.log('[DreamJourneyAvatar] fallback:', event.message);
          window.DreamJourneyAvatar.markShellReady('runtime error fallback');
          window.DreamJourneyAvatar.postHealth('runtime_error', event.message);
        });
        window.addEventListener('unhandledrejection', function(event) {
          const reason = event.reason && event.reason.message ? event.reason.message : String(event.reason);
          window.DreamJourneyAvatar.markShellReady('runtime promise fallback');
          window.DreamJourneyAvatar.postHealth('runtime_unhandledrejection', reason);
        });
      </script>
      <script src="pako.min.js"></script>
      <script src="DHLiveMini.js"></script>
      <script src="MiniLive2.js"></script>
      <script>
        if (window.CONFIG) {
          CONFIG.chromaKeyEnabled = true;
          CONFIG.faceRetargetEnabled = false;
          CONFIG.videoSrc = '01.mp4';
          CONFIG.dataSrc = 'combined_data.json.gz';
          CONFIG.showFPS = false;
        }
      </script>
      <script src="MiniMateLoader.js"></script>
      <script>
        window.DreamJourneyAvatar && window.DreamJourneyAvatar.probeResources();
      </script>
    </body>
    </html>
    """
}
