import UIKit

/// Neutral text reader for one server-admitted PublicationVersion. The page
/// only receives the redacted projection and deterministic public answer.
final class ProfilePublicationVisitorViewController: UIViewController {
    private enum State {
        case loading
        case invitations([PublicationVisitorInvitationSummary])
        case empty
        case loaded(PublicationVisitorProjection, PublicationVisitorAnswer?)
        case failed(String)
    }

    private let runtime: PublicationVisitorRuntime
    private let invitationClient: PublicationVisitorInvitationListClient
    private let readerClient: PublicationVisitorReaderClient
    private let accountLeaseProvider: () -> AccountLease?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private weak var questionField: UITextField?
    private weak var submitButton: UIButton?
    private weak var voiceButton: UIButton?
    private weak var voiceStatusLabel: UILabel?
    private var readUseCase: PublicationVisitorReadUseCase?
    private var projection: PublicationVisitorProjection?
    private var availableInvitations: [PublicationVisitorInvitationSummary] = []
    private var speechCapture: EchoNativeSpeechCapture?
    private var voicePlaybackBinding: DialogEngineBindingHandle?
    private var voicePlaybackRequestID = UUID()
    private var voiceLifecycleGeneration: UInt64 = 0
    private var voiceStatusText: String?
    private let voicePlaybackOwnerID = UUID()

    init(
        runtime: PublicationVisitorRuntime = .shared,
        invitationClient: PublicationVisitorInvitationListClient = DreamJourneyBackendClient.shared,
        readerClient: PublicationVisitorReaderClient = DreamJourneyBackendClient.shared,
        accountLeaseProvider: @escaping () -> AccountLease? = {
            AccountLeaseRuntime.shared.capture(forSubjectId: UserManager.shared.currentUser?.id)
        }
    ) {
        self.runtime = runtime
        self.invitationClient = invitationClient
        self.readerClient = readerClient
        self.accountLeaseProvider = accountLeaseProvider
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "受邀回忆"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-publication-visitor-shell"
        configureLayout()
        render(.loading)
        loadEntry()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVoiceInteraction()
    }

    private func configureLayout() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
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

    private func loadEntry() {
        guard PublicationVisitorM2AccessGate.isRouteAllowed else {
            runtime.clear(reason: .policyDenied)
            render(.failed(PublicationVisitorAccessError.disabled.localizedDescription))
            return
        }
        guard let accountLease = accountLeaseProvider() else {
            runtime.clear(reason: .accountLeaseInvalid)
            render(.failed(PublicationVisitorAccessError.accountLeaseInvalid.localizedDescription))
            return
        }
        if runtime.hasPendingOrActiveAccess {
            openInvitation(accountLease: accountLease)
            return
        }
        invitationClient.fetchVisitorInvitations(accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let contract):
                    self.availableInvitations = contract.invitations.filter { $0.expiresAt > Date() }
                    self.render(self.availableInvitations.isEmpty ? .empty : .invitations(self.availableInvitations))
                case .failure(let error):
                    self.render(.failed(self.message(for: error)))
                }
            }
        }
    }

    private func openInvitation(accountLease: AccountLease) {
        runtime.open(accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    let useCase = self.runtime.makeReadUseCase(client: self.readerClient)
                    self.readUseCase = useCase
                    useCase.loadProjection { [weak self] result in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch result {
                            case .success(let projection):
                                self.projection = projection
                                self.render(.loaded(projection, nil))
                            case .failure(let error):
                                self.render(.failed(self.message(for: error)))
                            }
                        }
                    }
                case .failure(let error):
                    self.render(.failed(self.message(for: error)))
                }
            }
        }
    }

    @objc private func submitQuestion() {
        submitQuestionRequest(playsVoiceResponse: false)
    }

    private func submitQuestionRequest(playsVoiceResponse: Bool) {
        guard let question = questionField?.text,
              let projection,
              let readUseCase else { return }
        cancelOrdinaryVoicePlayback()
        submitButton?.isEnabled = false
        voiceButton?.isEnabled = false
        if playsVoiceResponse {
            setVoiceStatus("正在整理公开回忆")
        }
        readUseCase.answer(question) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.submitButton?.isEnabled = true
                self.voiceButton?.isEnabled = true
                switch result {
                case .success(let response):
                    self.projection = response.projection
                    self.render(.loaded(response.projection, response.answer))
                    if playsVoiceResponse {
                        self.playOrdinaryVoiceAnswer(response.answer.text)
                    }
                case .failure(let error):
                    if playsVoiceResponse {
                        self.setVoiceStatus(self.message(for: error))
                    }
                    if self.runtime.snapshot().session.isActive {
                        self.render(.loaded(projection, nil))
                    } else {
                        self.render(.failed(self.message(for: error)))
                    }
                }
            }
        }
    }

    @objc private func toggleVoiceQuestion() {
        if let speechCapture {
            setVoiceStatus("正在识别")
            voiceButton?.setImage(UIImage(systemName: "hourglass"), for: .normal)
            speechCapture.finish()
            return
        }

        cancelOrdinaryVoicePlayback()
        let capture = EchoNativeSpeechCapture()
        speechCapture = capture
        voiceButton?.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        setVoiceStatus("正在准备麦克风")
        capture.start(
            onReady: { [weak self] in
                self?.setVoiceStatus("正在聆听，再次点击结束")
            },
            onPartial: { [weak self] text in
                self?.questionField?.text = text
            },
            onFinal: { [weak self] text in
                guard let self else { return }
                self.speechCapture = nil
                self.questionField?.text = text
                self.voiceButton?.setImage(UIImage(systemName: "mic.fill"), for: .normal)
                self.submitQuestionRequest(playsVoiceResponse: true)
            },
            onFailure: { [weak self] error in
                guard let self else { return }
                self.speechCapture = nil
                self.voiceButton?.setImage(UIImage(systemName: "mic.fill"), for: .normal)
                self.setVoiceStatus(self.message(for: error))
            }
        )
    }

    @objc private func retry() {
        render(.loading)
        loadEntry()
    }

    @objc private func selectInvitation(_ sender: UIButton) {
        guard availableInvitations.indices.contains(sender.tag),
              let invitation = availableInvitations[sender.tag].invitation,
              let accountLease = accountLeaseProvider() else {
            render(.failed(PublicationVisitorAccessError.accountLeaseInvalid.localizedDescription))
            return
        }
        runtime.stage(invitation)
        render(.loading)
        openInvitation(accountLease: accountLease)
    }

    private func render(_ state: State) {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        contentStack.addArrangedSubview(makeHeader())
        switch state {
        case .loading:
            contentStack.addArrangedSubview(makeStatusCard(
                title: "正在验证访问权限",
                message: "",
                showsSpinner: true
            ))
        case .invitations(let invitations):
            contentStack.addArrangedSubview(makeLabel(
                text: "选择一份已授权的公开回忆。",
                font: DJDesignTokens.Font.body(14),
                color: DJDesignTokens.Color.textSecondary
            ))
            for (index, invitation) in invitations.enumerated() {
                contentStack.addArrangedSubview(makeInvitationCard(invitation, index: index))
            }
        case .empty:
            contentStack.addArrangedSubview(makeStatusCard(
                title: "暂无受邀回忆",
                message: "对方创建邀请后，会出现在这里。"
            ))
        case .failed(let message):
            contentStack.addArrangedSubview(makeStatusCard(
                title: "暂时无法打开",
                message: message,
                showsRetry: true
            ))
        case .loaded(let projection, let answer):
            contentStack.addArrangedSubview(makeProjectionCard(projection))
            contentStack.addArrangedSubview(makeQuestionCard(answer: answer))
        }
    }

    private func makeInvitationCard(
        _ invitation: PublicationVisitorInvitationSummary,
        index: Int
    ) -> UIView {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = invitation.title
        configuration.subtitle = "有效期至 \(Self.dateFormatter.string(from: invitation.expiresAt))"
        configuration.image = UIImage(systemName: "text.book.closed")
        configuration.imagePadding = 12
        configuration.imagePlacement = .leading
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 18,
            leading: 18,
            bottom: 18,
            trailing: 18
        )
        configuration.baseForegroundColor = DJDesignTokens.Color.textPrimary
        configuration.titleAlignment = .leading
        button.configuration = configuration
        button.contentHorizontalAlignment = .fill
        button.backgroundColor = DJDesignTokens.Color.surface
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.layer.borderWidth = 1
        button.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.35).cgColor
        button.tag = index
        button.accessibilityIdentifier = "profile-publication-visitor-invitation-\(index)"
        button.accessibilityHint = "打开这份公开回忆"
        button.addTarget(self, action: #selector(selectInvitation(_:)), for: .touchUpInside)
        return button
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.addArrangedSubview(makeLabel(
            text: "受邀回忆",
            font: DJDesignTokens.Font.title(24),
            color: DJDesignTokens.Color.textPrimary
        ))
        let disclosure = makeLabel(
            text: "内容来自本人确认的公开副本。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        disclosure.accessibilityIdentifier = "profile-publication-visitor-disclosure"
        stack.addArrangedSubview(disclosure)
        return stack
    }

    private func makeProjectionCard(_ projection: PublicationVisitorProjection) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-visitor-projection"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(makeLabel(
            text: projection.title,
            font: DJDesignTokens.Font.title(19),
            color: DJDesignTokens.Color.textPrimary
        ))
        stack.addArrangedSubview(makeLabel(
            text: projection.body,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        ))
        stack.addArrangedSubview(makeLabel(
            text: projection.aiDisclosure,
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textSecondary
        ))
        pin(stack, to: card)
        return card
    }

    private func makeQuestionCard(answer: PublicationVisitorAnswer?) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-visitor-question-card"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(makeLabel(
            text: "询问这段回忆",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        ))

        let field = UITextField()
        field.placeholder = "输入一个问题"
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .send
        field.accessibilityIdentifier = "profile-publication-visitor-question-field"
        questionField = field
        stack.addArrangedSubview(field)

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.spacing = 10

        let voiceButton = UIButton(type: .system)
        var voiceConfiguration = UIButton.Configuration.filled()
        voiceConfiguration.image = UIImage(systemName: "mic.fill")
        voiceConfiguration.baseBackgroundColor = DJDesignTokens.Color.surfaceContainer
        voiceConfiguration.baseForegroundColor = DJDesignTokens.Color.accent
        voiceButton.configuration = voiceConfiguration
        voiceButton.accessibilityLabel = "语音提问"
        voiceButton.accessibilityHint = "再次点击结束聆听"
        voiceButton.accessibilityIdentifier = "profile-publication-visitor-voice-question"
        voiceButton.addTarget(self, action: #selector(toggleVoiceQuestion), for: .touchUpInside)
        voiceButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        self.voiceButton = voiceButton
        actions.addArrangedSubview(voiceButton)

        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "发送"
        configuration.baseBackgroundColor = DJDesignTokens.Color.accent
        configuration.baseForegroundColor = .white
        button.configuration = configuration
        button.accessibilityIdentifier = "profile-publication-visitor-question-submit"
        button.addTarget(self, action: #selector(submitQuestion), for: .touchUpInside)
        submitButton = button
        actions.addArrangedSubview(button)
        stack.addArrangedSubview(actions)

        let voiceStatus = makeLabel(
            text: voiceStatusText ?? "",
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textSecondary
        )
        voiceStatus.isHidden = voiceStatusText == nil
        voiceStatus.accessibilityIdentifier = "profile-publication-visitor-voice-status"
        voiceStatusLabel = voiceStatus
        stack.addArrangedSubview(voiceStatus)

        if let answer {
            let answerLabel = makeLabel(
                text: answer.text,
                font: DJDesignTokens.Font.body(15),
                color: DJDesignTokens.Color.textPrimary
            )
            answerLabel.accessibilityIdentifier = "profile-publication-visitor-answer"
            stack.addArrangedSubview(answerLabel)
            stack.addArrangedSubview(makeLabel(
                text: answer.identityDisclosure,
                font: DJDesignTokens.Font.body(12),
                color: DJDesignTokens.Color.textSecondary
            ))
        }
        pin(stack, to: card)
        return card
    }

    private func playOrdinaryVoiceAnswer(_ text: String) {
        guard let accountLease = accountLeaseProvider() else {
            setVoiceStatus(PublicationVisitorAccessError.accountLeaseInvalid.localizedDescription)
            return
        }

        cancelOrdinaryVoicePlayback()
        voicePlaybackRequestID = UUID()
        voiceLifecycleGeneration &+= 1
        let requestID = voicePlaybackRequestID
        let lifecycleGeneration = voiceLifecycleGeneration
        guard let binding = DialogEngineManager.shared.bindAccountLease(
            accountLease,
            ownerId: voicePlaybackOwnerID
        ) else {
            setVoiceStatus("回答已显示，普通语音暂不可用")
            return
        }
        voicePlaybackBinding = binding
        guard DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true),
              DialogEngineManager.shared.setLocalTTSVoiceSelection(
                voiceProfileId: nil,
                contextKey: "publicationVisitor",
                lifecycleGeneration: lifecycleGeneration,
                for: binding
              ) else {
            finishOrdinaryVoicePlayback(
                requestID: requestID,
                binding: binding,
                status: "回答已显示，普通语音暂不可用"
            )
            return
        }
        setVoiceStatus("正在连接普通语音")

        DreamJourneyBackendClient.shared.fetchRealtimeVoiceConfig(
            userId: accountLease.subjectId
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.voicePlaybackRequestID == requestID,
                      self.voicePlaybackBinding == binding else {
                    return
                }
                guard self.accountLeaseProvider() == accountLease else {
                    self.finishOrdinaryVoicePlayback(
                        requestID: requestID,
                        binding: binding,
                        status: nil
                    )
                    return
                }
                guard case .success(let runtimeConfig) = result,
                      DialogEngineManager.shared.configure(runtimeConfig: runtimeConfig) else {
                    self.finishOrdinaryVoicePlayback(
                        requestID: requestID,
                        binding: binding,
                        status: "回答已显示，普通语音暂不可用"
                    )
                    return
                }

                _ = DialogEngineManager.shared.startTextReplyPlayback(
                    text: text,
                    onStarted: { [weak self] in
                        DispatchQueue.main.async {
                            guard self?.voicePlaybackRequestID == requestID else { return }
                            self?.setVoiceStatus("正在朗读回答")
                        }
                    },
                    completion: { [weak self] playbackResult in
                        DispatchQueue.main.async {
                            self?.finishOrdinaryVoicePlayback(
                                requestID: requestID,
                                binding: binding,
                                status: playbackResult.isSuccess
                                    ? nil
                                    : "回答已显示，普通语音暂不可用"
                            )
                        }
                    }
                )
            }
        }
    }

    private func finishOrdinaryVoicePlayback(
        requestID: UUID,
        binding: DialogEngineBindingHandle,
        status: String?
    ) {
        guard voicePlaybackRequestID == requestID,
              voicePlaybackBinding == binding else { return }
        _ = DialogEngineManager.shared.unbindAccountLease(binding)
        voicePlaybackBinding = nil
        setVoiceStatus(status)
    }

    private func cancelOrdinaryVoicePlayback() {
        voicePlaybackRequestID = UUID()
        DialogEngineManager.shared.cancelTextReplyPlayback()
        if let binding = voicePlaybackBinding {
            _ = DialogEngineManager.shared.unbindAccountLease(binding)
        }
        voicePlaybackBinding = nil
    }

    private func stopVoiceInteraction() {
        speechCapture?.cancel()
        speechCapture = nil
        cancelOrdinaryVoicePlayback()
        voiceStatusText = nil
    }

    private func setVoiceStatus(_ text: String?) {
        voiceStatusText = text
        voiceStatusLabel?.text = text ?? ""
        voiceStatusLabel?.isHidden = text == nil
    }

    private func makeStatusCard(
        title: String,
        message: String,
        showsSpinner: Bool = false,
        showsRetry: Bool = false
    ) -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        if showsSpinner {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            stack.addArrangedSubview(spinner)
        }
        stack.addArrangedSubview(makeLabel(
            text: title,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        ))
        if !message.isEmpty {
            let label = makeLabel(
                text: message,
                font: DJDesignTokens.Font.body(14),
                color: DJDesignTokens.Color.textSecondary
            )
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }
        if showsRetry {
            let button = UIButton(type: .system)
            button.setTitle("重新验证", for: .normal)
            button.addTarget(self, action: #selector(retry), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        pin(stack, to: card)
        return card
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = DJDesignTokens.Radius.medium
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.35).cgColor
        return card
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

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func message(for error: Error) -> String {
        if let accessError = error as? PublicationVisitorAccessError {
            return accessError.localizedDescription
        }
        if error is EchoNativeSpeechCapture.CaptureError {
            return error.localizedDescription
        }
        return "受邀回忆暂时不可用"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
