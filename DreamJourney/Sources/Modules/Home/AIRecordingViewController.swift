import UIKit
import AVFoundation
import CocoaLumberjack

// MARK: - 对话消息模型
enum TGMessage: Identifiable {
    case ai(text: String, timestamp: Date = Date())
    case user(text: String, timestamp: Date = Date())
    case photo(imagePath: String, timestamp: Date = Date())  // 用户发送的照片消息
    case privacyConfirmation

    var id: String { UUID().uuidString }
    var timestamp: Date {
        switch self {
        case .ai(_, let t), .user(_, let t), .photo(_, let t): return t
        case .privacyConfirmation: return Date()
        }
    }
}

// MARK: - 语音球状态
enum VoiceBallState {
    case idle         // 待机：脉冲动效，麦克风图标
    case active       // 对话中：波纹动效，停止图标
}

// MARK: - AIRecordingViewController：首页 AI 智能记录
final class AIRecordingViewController: UIViewController {

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

    // MARK: - State
    private var messages: [TGMessage] = []
    private var voiceBallState: VoiceBallState = .idle
    private var pulseLayer: CABasicAnimation?
    /// 用户语音中间结果缓存（不直接显示，等待最终确认或 AI 开始回复时再展示）
    private var pendingUserText: String?
    /// AI 流式拼接缓存（不直接显示，等 TTS 句子完整时再展示）
    private var pendingAIText: String?
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let privateMediaStore = AccountPrivateMediaStore.shared
    private let dialogEngineOwnerId = UUID()
    private var dialogAccountLease: AccountLease?
    private var dialogEngineBindingHandle: DialogEngineBindingHandle?
    private var mediaPickerAccountLease: AccountLease?
    private var mediaPickerDigitalHumanContext: DigitalHumanContext?
    private var pendingPhotoArtifacts: [String: AccountPrivateMediaArtifact] = [:]

    // MARK: - 对话录音（用于声音复刻）
    /// 并行录音器：对话期间录制用户语音，供声音复刻训练使用
    private var sessionRecorder: AVAudioRecorder?
    private var sessionRecordingAccountLease: AccountLease?
    private var sessionRecordingArtifact: AccountPrivateMediaArtifact?
    private var lastSessionRecordingArtifact: AccountPrivateMediaArtifact?
    /// 最近一次对话的账号隔离录音 staging URL
    private(set) var lastSessionRecordingURL: URL?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        hideKeyboardWhenTapped()
        setupLayout()
        setupNotifications()
        updateVoiceBallState(.idle)
        retireLegacyGlobalMedia()
        activateDialogAccountLeaseIfAvailable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activateDialogAccountLeaseIfAvailable()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let accountLease = dialogAccountLease,
           validateDialogEngineBinding(accountLease: accountLease, at: .runtime) {
            if DialogEngineManager.shared.isDialogActive {
                DialogEngineManager.shared.stopDialog()
            } else {
                stopSessionRecording(accountLease: accountLease)
            }
        }
        discardStaleSessionRecording()
        releaseDialogEngineBinding()
        dialogAccountLease = nil
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
        discardPendingPhotoArtifacts()
        discardStaleSessionRecording()
        releaseDialogEngineBinding()
        NotificationCenter.default.removeObserver(self)
    }

    private func retireLegacyGlobalMedia() {
        let privateMediaStore = privateMediaStore
        DispatchQueue.global(qos: .utility).async {
            do {
                try privateMediaStore.purgeExpiredStaging(
                    before: Date().addingTimeInterval(-24 * 60 * 60)
                )
                try privateMediaStore.retireLegacyGlobalMedia()
            } catch {
                DDLogWarn("[AIRecording] 旧全局媒体处置失败，将在下次进入时重试: \(error)")
            }
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(messageTableView)
        view.addSubview(bottomDivider)
        view.addSubview(bottomContainer)

        bottomContainer.addSubview(albumButton)
        bottomContainer.addSubview(voiceBallButton)
        bottomContainer.addSubview(cameraButton)

        [titleLabel, messageTableView, bottomDivider, bottomContainer,
         albumButton, voiceBallButton, cameraButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let ballSize: CGFloat = 80
        let sideSize: CGFloat = 44

        // 底部操作区底部约束（动态调整避开 TabBar）
        bottomContainerBottomConstraint = bottomContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -56)

        NSLayoutConstraint.activate([
            // 顶部标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // 消息流
            messageTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
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
        guard let accountLease = captureMediaPickerAccountLease() else {
            showToast("账号状态已变化，请重新进入后再拍照", type: .error)
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        mediaPickerAccountLease = accountLease
        mediaPickerDigitalHumanContext = DigitalHumanContextStore.shared.current
        present(picker, animated: true)
        #endif
    }

    @objc private func albumTapped() {
        guard let accountLease = captureMediaPickerAccountLease() else {
            showToast("账号状态已变化，请重新进入后再选择照片", type: .error)
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        mediaPickerAccountLease = accountLease
        mediaPickerDigitalHumanContext = DigitalHumanContextStore.shared.current
        present(picker, animated: true)
    }

    private func captureMediaPickerAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              validateMediaPickerAccountLease(accountLease, at: .request) else {
            return nil
        }
        return accountLease
    }

    private func validateMediaPickerAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func validateMediaPickerOperation(
        _ accountLease: AccountLease,
        digitalHumanContext: DigitalHumanContext,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        validateMediaPickerAccountLease(accountLease, at: checkpoint)
            && digitalHumanContext == DigitalHumanContextStore.shared.current
    }

    private func captureInitialDialogAccountLease() -> AccountLease? {
        guard dialogAccountLease == nil,
              let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        return accountLease
    }

    @discardableResult
    private func activateDialogAccountLeaseIfAvailable() -> Bool {
        if let existingAccountLease = dialogAccountLease,
           validateDialogAccountLease(existingAccountLease, at: .request),
           bindDialogEngine(accountLease: existingAccountLease) {
            DialogEngineManager.shared.delegate = self
            DialogEngineManager.shared.setup()
            return true
        }

        if dialogAccountLease != nil {
            releaseDialogEngineBinding()
            dialogAccountLease = nil
        }
        guard let accountLease = captureInitialDialogAccountLease() else {
            return false
        }
        dialogAccountLease = accountLease
        guard bindDialogEngine(accountLease: accountLease) else {
            dialogAccountLease = nil
            return false
        }
        DialogEngineManager.shared.delegate = self
        DialogEngineManager.shared.setup()
        return true
    }

    private func validateDialogAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        dialogAccountLease == accountLease
            && accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    @discardableResult
    private func bindDialogEngine(accountLease: AccountLease) -> Bool {
        guard validateDialogAccountLease(accountLease, at: .request),
              let bindingHandle = DialogEngineManager.shared.bindAccountLease(
                accountLease,
                ownerId: dialogEngineOwnerId
              ) else {
            releaseDialogEngineBinding()
            return false
        }
        dialogEngineBindingHandle = bindingHandle
        return DialogEngineManager.shared.isCurrentBinding(bindingHandle)
    }

    private func releaseDialogEngineBinding() {
        guard let bindingHandle = dialogEngineBindingHandle else { return }
        _ = DialogEngineManager.shared.unbindAccountLease(bindingHandle)
        dialogEngineBindingHandle = nil
    }

    private func validateDialogEngineBinding(
        accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        validateDialogAccountLease(accountLease, at: checkpoint)
            && DialogEngineManager.shared.isCurrentBinding(dialogEngineBindingHandle)
    }

    // MARK: - Mock Dialog
    private func startRecording() {
        guard let accountLease = dialogAccountLease,
              validateDialogAccountLease(accountLease, at: .request),
              bindDialogEngine(accountLease: accountLease) else {
            discardStaleSessionRecording()
            return
        }
        DialogEngineManager.shared.delegate = self
        MicrophonePermissionManager.shared.requestPermission { [weak self] granted in
            guard let self,
                  self.dialogAccountLease == accountLease,
                  self.validateDialogEngineBinding(accountLease: accountLease, at: .runtime),
                  self.validateDialogAccountLease(accountLease, at: .ui) else {
                self?.discardStaleSessionRecording()
                return
            }
            if granted {
                // 先启动 DialogEngine（由 SDK 配置 AudioSession），再启动并行录音（共享同一 AudioSession）
                // 顺序很重要：如果先启动 AVAudioRecorder，它会隐式修改 AudioSession 配置，可能影响 SDK 的 AEC
                guard self.bindDialogEngine(accountLease: accountLease) else { return }
                DialogEngineManager.shared.delegate = self
                DialogEngineManager.shared.startDialog()
                self.startSessionRecording(accountLease: accountLease)
            } else {
                MicrophonePermissionManager.shared.showPermissionDeniedAlert(on: self)
                self.updateVoiceBallState(.idle)
            }
        }
    }

    private func stopRecording() {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .runtime) else {
            discardStaleSessionRecording()
            return
        }
        // 先停止并行录音，再停止 DialogEngine
        stopSessionRecording(accountLease: accountLease)
        guard validateDialogEngineBinding(accountLease: accountLease, at: .runtime) else { return }
        DialogEngineManager.shared.stopDialog()
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
            selector: #selector(handleAccountDidChange),
            name: .djUserDidLogout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountDidChange),
            name: .djUserDidLogin,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDialogAuthorityEpochDidChange),
            name: .djRecoveryAuthorityEpochDidChange,
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
    }

    @objc private func handleAccountDidChange() {
        performDialogAccountScopeResetOnMain(clearsMessages: true)
    }

    @objc private func handleDialogAuthorityEpochDidChange() {
        performDialogAccountScopeResetOnMain(clearsMessages: false)
    }

    private func performDialogAccountScopeResetOnMain(clearsMessages: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.performDialogAccountScopeResetOnMain(clearsMessages: clearsMessages)
            }
            return
        }
        releaseDialogEngineBinding()
        dialogAccountLease = nil
        mediaPickerAccountLease = nil
        mediaPickerDigitalHumanContext = nil
        discardPendingPhotoArtifacts()
        discardStaleSessionRecording()
        pendingUserText = nil
        pendingAIText = nil
        if clearsMessages {
            messages = []
            messageTableView.reloadData()
        } else {
            messages.removeAll {
                if case .photo = $0 { return true }
                return false
            }
            messageTableView.reloadData()
        }
        updateVoiceBallState(.idle)
        if view.window != nil {
            activateDialogAccountLeaseIfAvailable()
        }
    }

    @objc private func handleDidEnterBackground() {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .runtime) else {
            discardStaleSessionRecording()
            return
        }
        if DialogEngineManager.shared.isDialogActive {
            DialogEngineManager.shared.stopDialog()
            if validateDialogAccountLease(accountLease, at: .ui) {
                updateVoiceBallState(.idle)
            }
        }
        // 安全防护：确保并行录音也被停止（正常流程由 onDialogEnded 触发，此处兜底）
        stopSessionRecording(accountLease: accountLease)
    }

    @objc private func handleWillEnterForeground() {
        guard view.window != nil,
              let accountLease = dialogAccountLease,
              validateDialogAccountLease(accountLease, at: .runtime),
              bindDialogEngine(accountLease: accountLease) else {
            discardStaleSessionRecording()
            return
        }
        DialogEngineManager.shared.delegate = self
        if !DialogEngineManager.shared.isEngineReady {
            DialogEngineManager.shared.setup()
        }
        // 检查声音复刻训练是否在后台完成（Timer 会被挂起，需要手动检查）
        VoiceCloneService.shared.checkPendingTraining()
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
        case .ai(let text, let ts):
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
        case .ai(let text, _), .user(let text, _):
            // 与 TGMessageCell.sizeThatFits 保持一致
            let maxWidth = UIScreen.main.bounds.width * 0.72
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 5
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .paragraphStyle: paragraphStyle
            ])
            let hPad: CGFloat = 16
            let vPad: CGFloat = 12
            let textSize = label.sizeThatFits(CGSize(width: maxWidth - hPad * 2, height: .infinity))
            return textSize.height + vPad * 2 + 8 + 17 + 6
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension AIRecordingViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        defer {
            mediaPickerAccountLease = nil
            mediaPickerDigitalHumanContext = nil
        }
        guard let accountLease = mediaPickerAccountLease,
              let digitalHumanContext = mediaPickerDigitalHumanContext,
              validateMediaPickerOperation(
                accountLease,
                digitalHumanContext: digitalHumanContext,
                at: .ui
              ) else { return }
        guard let image = info[.originalImage] as? UIImage else { return }

        guard let photoArtifact = try? savePhotoToLocal(image, accountLease: accountLease) else {
            return
        }
        let imagePath = photoArtifact.fileURL.path
        guard validateMediaPickerOperation(
            accountLease,
            digitalHumanContext: digitalHumanContext,
            at: .commit
        ) else {
            privateMediaStore.discard(photoArtifact)
            return
        }
        pendingPhotoArtifacts[imagePath] = photoArtifact

        // 显示为用户消息气泡（含缩略图）
        messages.append(.photo(imagePath: imagePath, timestamp: Date()))
        // AI 回复（先发占位，后续替换为分析结果）
        messages.append(.ai(text: "照片收到了！能不能跟我说说这张照片背后的故事？", timestamp: Date()))
        let aiMessageIndex = messages.count - 1
        messageTableView.reloadData()
        scrollToBottom()

        // 记录到对话记忆
        ConversationMemoryManager.shared.recordUserTurn(text: "[发送了一张照片]")
        ConversationMemoryManager.shared.recordAITurn(text: "照片收到了！能不能跟我说说这张照片背后的故事？")

        // 【KBLite】异步分析图片
        analyzeUploadedPhoto(
            image,
            aiMessageIndex: aiMessageIndex,
            photoArtifact: photoArtifact,
            accountLease: accountLease,
            digitalHumanContext: digitalHumanContext
        )
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        mediaPickerAccountLease = nil
        mediaPickerDigitalHumanContext = nil
    }

    /// 异步分析上传的照片（KBLite）
    private func analyzeUploadedPhoto(
        _ image: UIImage,
        aiMessageIndex: Int,
        photoArtifact: AccountPrivateMediaArtifact,
        accountLease: AccountLease,
        digitalHumanContext: DigitalHumanContext
    ) {
        guard validateMediaPickerOperation(
            accountLease,
            digitalHumanContext: digitalHumanContext,
            at: .request
        ) else { return }
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
            guard let self,
                  self.validateMediaPickerOperation(
                    accountLease,
                    digitalHumanContext: digitalHumanContext,
                    at: .runtime
                  ) else { return }
            DispatchQueue.main.async {
                guard self.validateMediaPickerOperation(
                    accountLease,
                    digitalHumanContext: digitalHumanContext,
                    at: .ui
                ) else { return }
                switch result {
                case .success(let analysis):
                    print("[KBLite] 🖼️ 图片分析完成: \(analysis.description.prefix(50))...")

                    // 入库
                    let sessionId = ConversationMemoryManager.shared.currentMemory.sessionCount + 1
                    let sourceAssetId = photoArtifact.fileURL
                        .deletingPathExtension()
                        .lastPathComponent
                    guard self.validateMediaPickerOperation(
                        accountLease,
                        digitalHumanContext: digitalHumanContext,
                        at: .commit
                    ) else { return }
                    KBLiteManager.shared.ingestImageAnalysis(
                        analysis,
                        sessionId: sessionId,
                        sourceAssetId: sourceAssetId
                    )

                    // 关联照片到足迹地图
                    if !analysis.scene.isEmpty || analysis.estimatedDecade != nil {
                        self.associatePhotoToMemory(
                            photoArtifact: photoArtifact,
                            analysis: analysis,
                            accountLease: accountLease
                        )
                    }

                    // 替换 AI 回复为分析结果
                    let enrichedReply = self.buildImageReply(from: analysis)
                    if aiMessageIndex < self.messages.count {
                        self.messages[aiMessageIndex] = .ai(text: enrichedReply, timestamp: Date())
                        // 更新记忆记录
                        ConversationMemoryManager.shared.recordAITurn(text: enrichedReply)
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
    private func associatePhotoToMemory(
        photoArtifact: AccountPrivateMediaArtifact,
        analysis: KBImageAnalysisResult,
        accountLease: AccountLease
    ) {
        guard validateMediaPickerAccountLease(accountLease, at: .runtime) else { return }
        let allMemories = MemoryRepository.shared.getAllByOwner(accountLease.subjectId, accountLease: accountLease)
        guard !allMemories.isEmpty else { return }

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
            let persistentArtifact: AccountPrivateMediaArtifact
            do {
                persistentArtifact = try privateMediaStore.promotePhotoStaging(
                    photoArtifact,
                    accountLease: accountLease
                )
            } catch {
                DDLogWarn("[AIRecording] 照片持久化提交失败: \(error.localizedDescription)")
                return
            }
            replacePendingPhotoArtifact(
                photoArtifact,
                with: persistentArtifact
            )
            guard let persistentReference = try? privateMediaStore.persistentPhotoReference(
                for: persistentArtifact
            ) else {
                return
            }
            match.imageNames.append(persistentReference)
            guard validateMediaPickerAccountLease(accountLease, at: .commit),
                  MemoryRepository.shared.update(
                    match,
                    ownerId: accountLease.subjectId,
                    accountLease: accountLease
                  ) else { return }
            pendingPhotoArtifacts.removeValue(forKey: persistentArtifact.fileURL.path)
            print("[KBLite] 🖼️ 照片 '\(persistentArtifact.fileURL.lastPathComponent)' 已关联到足迹记忆: \(match.title) (匹配度: \(bestScore))")
        } else {
            print("[KBLite] 🖼️ 照片 '\(photoArtifact.fileURL.lastPathComponent)' 未找到高度匹配的足迹记忆 (最高: \(bestScore))")
        }
    }

    private func replacePendingPhotoArtifact(
        _ sourceArtifact: AccountPrivateMediaArtifact,
        with destinationArtifact: AccountPrivateMediaArtifact
    ) {
        pendingPhotoArtifacts.removeValue(forKey: sourceArtifact.fileURL.path)
        pendingPhotoArtifacts[destinationArtifact.fileURL.path] = destinationArtifact
        messages = messages.map { message in
            guard case .photo(let path, let timestamp) = message,
                  path == sourceArtifact.fileURL.path else {
                return message
            }
            return .photo(imagePath: destinationArtifact.fileURL.path, timestamp: timestamp)
        }
        messageTableView.reloadData()
    }

    private func discardPendingPhotoArtifacts() {
        let artifacts = Array(pendingPhotoArtifacts.values)
        pendingPhotoArtifacts.removeAll()
        artifacts.forEach { privateMediaStore.discard($0) }
    }

    /// 将图片保存到账号隔离的临时媒体目录，关联到记忆后再持久化。
    private func savePhotoToLocal(
        _ image: UIImage,
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        guard validateMediaPickerAccountLease(accountLease, at: .commit) else {
            throw AIRecordingMediaCommitError.accountSessionChanged
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw AIRecordingMediaCommitError.imageEncodingFailed
        }
        guard validateMediaPickerAccountLease(accountLease, at: .commit) else {
            throw AIRecordingMediaCommitError.accountSessionChanged
        }
        let artifact = try privateMediaStore.writePhotoStaging(
            data,
            fileExtension: "jpg",
            accountLease: accountLease
        )
        guard validateMediaPickerAccountLease(accountLease, at: .commit) else {
            privateMediaStore.discard(artifact)
            throw AIRecordingMediaCommitError.accountSessionChanged
        }
        return artifact
    }
}

private enum AIRecordingMediaCommitError: Error {
    case accountSessionChanged
    case imageEncodingFailed
}

// MARK: - DialogEngineDelegate
extension AIRecordingViewController: DialogEngineDelegate {

    func onDialogStarted() {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        // 保留历史消息，不清空（新会话消息追加在旧消息下方）
        pendingUserText = nil
        pendingAIText = nil
        updateVoiceBallState(.active)
    }

    func onASRResult(text: String, isFinal: Bool) {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        if isFinal {
            // 最终结果：直接显示为正式用户消息
            pendingUserText = nil
            messages.append(.user(text: text, timestamp: Date()))
            messageTableView.reloadData()
            scrollToBottom()
            // 记录到对话记忆
            ConversationMemoryManager.shared.recordUserTurn(text: text)
        } else {
            // 中间结果：只记录不显示，等待最终确认
            pendingUserText = text
        }
    }

    func onTTSStarted(text: String) {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        // AI 开始说话前，将待确认的用户文本显示出来
        flushPendingUserText(accountLease: accountLease)
        // 清空流式缓存（TTS 已提供完整文本）
        pendingAIText = nil
        // 显示完整的 AI 句子
        messages.append(.ai(text: text, timestamp: Date()))
        messageTableView.reloadData()
        scrollToBottom()
        // 记录到对话记忆
        ConversationMemoryManager.shared.recordAITurn(text: text)
    }

    func onChatStreaming(text: String) {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        // 流式拼接：不更新 UI，只记录最新累积文本（用于 chat 结束时兜底展示）
        pendingAIText = text
    }

    /// 将待确认的用户文本发布为正式消息
    private func flushPendingUserText(accountLease: AccountLease) {
        guard validateDialogAccountLease(accountLease, at: .ui) else { return }
        if let text = pendingUserText, !text.isEmpty {
            messages.append(.user(text: text, timestamp: Date()))
            // 记录到对话记忆
            ConversationMemoryManager.shared.recordUserTurn(text: text)
            pendingUserText = nil
        }
    }

    func onTTSFinished() {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else { return }
        // TTS 播报结束，保持 active 状态等待用户继续说话
    }

    func onError(error: Error) {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        stopSessionRecording(accountLease: accountLease)
        guard validateDialogAccountLease(accountLease, at: .ui) else { return }
        updateVoiceBallState(.idle)
        showToast(error.localizedDescription, type: .error)
    }

    func onDialogEnded(reason: DialogEndReason) {
        guard let accountLease = dialogAccountLease,
              validateDialogEngineBinding(accountLease: accountLease, at: .ui) else {
            discardStaleSessionRecording()
            return
        }
        stopSessionRecording(accountLease: accountLease)
        guard validateDialogAccountLease(accountLease, at: .ui) else { return }
        // 对话结束时，刷新未展示的待确认文本
        flushPendingUserText(accountLease: accountLease)
        // 如果有未展示的 AI 流式文本（没有经过 TTS），兜底展示
        if let aiText = pendingAIText, !aiText.isEmpty {
            messages.append(.ai(text: aiText, timestamp: Date()))
            ConversationMemoryManager.shared.recordAITurn(text: aiText)
            pendingAIText = nil
            messageTableView.reloadData()
            scrollToBottom()
        }
        // 结束会话：提取摘要并持久化
        guard validateDialogAccountLease(accountLease, at: .commit) else { return }
        ConversationMemoryManager.shared.endSession()
        updateVoiceBallState(.idle)

        switch reason {
        case .keyword:
            showToast("寻梦环游已经记住您说的了，下次再聊～", type: .success)
        case .silenceTimeout:
            showToast("您好像有事忙，寻梦环游先告辞啦～", type: .info)
        case .manual:
            break
        case .serverEnded:
            break
        }

        // 延迟弹出回忆录生成卡片（等待 toast 消失后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self,
                  self.dialogAccountLease == accountLease,
                  self.validateDialogAccountLease(accountLease, at: .timer),
                  self.validateDialogAccountLease(accountLease, at: .ui) else { return }
            self.showMemoirGenerationCard(accountLease: accountLease)
        }
    }

    // MARK: - 对话并行录音（用于声音复刻训练）

    /// 开始并行录音（与豆包 SDK 同时录制，用于声音复刻）
    private func startSessionRecording(accountLease: AccountLease) {
        guard dialogAccountLease == accountLease,
              validateDialogAccountLease(accountLease, at: .runtime) else {
            discardStaleSessionRecording()
            return
        }
        discardStaleSessionRecording()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recordingArtifact: AccountPrivateMediaArtifact
        do {
            recordingArtifact = try privateMediaStore.prepareRecordingStaging(
                accountLease: accountLease
            )
            sessionRecordingArtifact = recordingArtifact
            let recorder = try AVAudioRecorder(url: recordingArtifact.fileURL, settings: settings)
            guard validateDialogAccountLease(accountLease, at: .runtime) else {
                privateMediaStore.discard(recordingArtifact)
                discardStaleSessionRecording()
                return
            }
            sessionRecorder = recorder
            sessionRecordingAccountLease = accountLease
            guard recorder.record(),
                  validateDialogAccountLease(accountLease, at: .runtime) else {
                discardStaleSessionRecording()
                return
            }
            DDLogInfo(
                "[AIRecording] 并行录音已启动: \(recordingArtifact.fileURL.lastPathComponent)"
            )
        } catch {
            DDLogWarn("[AIRecording] 并行录音启动失败: \(error.localizedDescription)")
            if let artifact = sessionRecordingArtifact {
                privateMediaStore.discard(artifact)
            }
            sessionRecorder = nil
            sessionRecordingAccountLease = nil
            sessionRecordingArtifact = nil
        }
    }

    /// 停止并行录音并保留账号隔离的会话 staging。
    private func stopSessionRecording(accountLease: AccountLease) {
        guard let recorder = sessionRecorder,
              let recordingArtifact = sessionRecordingArtifact else {
            sessionRecorder = nil
            sessionRecordingAccountLease = nil
            sessionRecordingArtifact = nil
            return
        }
        guard sessionRecordingAccountLease == accountLease,
              validateDialogAccountLease(accountLease, at: .runtime),
              recorder.isRecording else {
            discardActiveSessionRecording()
            return
        }

        // Bug fix: 在 stop() 之前读取 currentTime，部分 iOS 版本 stop() 后 currentTime 会重置为 0
        let duration = recorder.currentTime
        recorder.stop()

        sessionRecorder = nil
        sessionRecordingAccountLease = nil
        sessionRecordingArtifact = nil
        guard validateDialogAccountLease(accountLease, at: .commit) else {
            privateMediaStore.discard(recordingArtifact)
            lastSessionRecordingArtifact = nil
            lastSessionRecordingURL = nil
            return
        }
        // 检查录音时长，至少 3 秒才有价值用于声音复刻
        if duration >= 3 {
            do {
                let finalizedArtifact = try privateMediaStore.finalizeRecordingStaging(
                    recordingArtifact,
                    accountLease: accountLease
                )
                guard validateDialogAccountLease(accountLease, at: .commit) else {
                    privateMediaStore.discard(finalizedArtifact)
                    lastSessionRecordingArtifact = nil
                    lastSessionRecordingURL = nil
                    return
                }
                if let previousArtifact = lastSessionRecordingArtifact {
                    privateMediaStore.discard(previousArtifact)
                }
                lastSessionRecordingArtifact = finalizedArtifact
                lastSessionRecordingURL = finalizedArtifact.fileURL
                DDLogInfo("[AIRecording] 对话录音 staging 已完成: \(finalizedArtifact.fileURL.lastPathComponent), 时长: \(duration)秒")
            } catch {
                privateMediaStore.discard(recordingArtifact)
                lastSessionRecordingArtifact = nil
                lastSessionRecordingURL = nil
                DDLogWarn("[AIRecording] 对话录音 staging 提交失败: \(error.localizedDescription)")
            }
        } else {
            privateMediaStore.discard(recordingArtifact)
            lastSessionRecordingArtifact = nil
            lastSessionRecordingURL = nil
            DDLogInfo("[AIRecording] 对话录音太短(\(String(format: "%.1f", duration))秒)，已丢弃")
        }
    }

    private func discardStaleSessionRecording() {
        discardActiveSessionRecording()
        if let artifact = lastSessionRecordingArtifact {
            privateMediaStore.discard(artifact)
        }
        lastSessionRecordingArtifact = nil
        lastSessionRecordingURL = nil
    }

    private func discardActiveSessionRecording() {
        if let recorder = sessionRecorder {
            if recorder.isRecording {
                recorder.stop()
            }
        }
        if let artifact = sessionRecordingArtifact {
            privateMediaStore.discard(artifact)
        }
        sessionRecorder = nil
        sessionRecordingAccountLease = nil
        sessionRecordingArtifact = nil
    }

    /// 显示回忆录生成弹窗
    private func showMemoirGenerationCard(accountLease: AccountLease) {
        guard validateDialogAccountLease(accountLease, at: .ui) else { return }
        MemoirGenerationCard.show(in: view,
            onGenerate: { [weak self] in
                guard let self,
                      self.dialogAccountLease == accountLease,
                      self.validateDialogAccountLease(accountLease, at: .ui) else { return }
                self.handleMemoirGeneration(accountLease: accountLease)
            },
            onDismiss: nil
        )
    }

    /// 处理回忆录生成请求
    private func handleMemoirGeneration(accountLease: AccountLease) {
        guard validateDialogAccountLease(accountLease, at: .request),
              let memoirAuthorization = MemoirRepository.shared.captureAccountLeaseAndOwner(),
              memoirAuthorization.accountLease == accountLease,
              MemoirRepository.shared.validateAccountLease(
                accountLease,
                ownerId: memoirAuthorization.ownerId,
                at: .request
              ) else { return }
        // 将 TGMessage 转换为 Memoir 模块的 DialogMessage 格式
        let dialogMessages = MemoirFlowManager.convertToDialogMessages(messages)

        // 本地内容质量检测（即时反馈，无需等 API 调用）
        if let reason = MemoirFlowManager.checkDialogContent(dialogMessages) {
            showToast(reason, type: .info)
            return
        }

        guard dialogAccountLease == accountLease,
              validateDialogAccountLease(accountLease, at: .request),
              MemoirRepository.shared.validateAccountLease(
                accountLease,
                ownerId: memoirAuthorization.ownerId,
                at: .request
              ) else { return }
        let recordingInput = persistLastSessionRecording(
            accountLease: accountLease,
            ownerId: memoirAuthorization.ownerId
        )
        MemoirFlowManager.shared.startGeneration(
            on: self,
            dialogMessages: dialogMessages,
            recordingURL: recordingInput.url,
            sessionId: recordingInput.sessionId,
            accountLease: accountLease,
            ownerId: memoirAuthorization.ownerId
        )
    }

    private func persistLastSessionRecording(
        accountLease: AccountLease,
        ownerId: String
    ) -> (url: URL?, sessionId: String?) {
        guard let stagingArtifact = lastSessionRecordingArtifact,
              let stagingURL = lastSessionRecordingURL else {
            return (nil, nil)
        }
        let recordingSessionId = "session_\(UUID().uuidString.lowercased())"
        guard let persistentURL = MemoirRepository.shared.saveRecording(
            from: stagingURL,
            sessionId: recordingSessionId,
            accountLease: accountLease,
            ownerId: ownerId
        ) else {
            DDLogWarn("[AIRecording] 回忆录录音持久化失败，本轮不绑定原始录音")
            return (stagingURL, nil)
        }
        privateMediaStore.discard(stagingArtifact)
        lastSessionRecordingArtifact = nil
        lastSessionRecordingURL = nil
        return (persistentURL, recordingSessionId)
    }
}
