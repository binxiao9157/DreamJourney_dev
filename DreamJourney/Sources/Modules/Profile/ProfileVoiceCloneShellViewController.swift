import AVFoundation
import UIKit
import UniformTypeIdentifiers

final class ProfileVoiceCloneShellViewController: UIViewController, UIDocumentPickerDelegate, AVAudioPlayerDelegate {
    private struct QualityPreviewReceipt {
        let voiceProfileId: String
        let retryGeneration: Int
        let value: String
        let expiresAt: String?
    }

    private var snapshot: VoiceCloneProfileSnapshot
    private var voiceCloneRuntimeCapability = VoiceCloneRuntimeCapability.localFallback(isBackendConfigured: false)
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let authorizationSwitch = UISwitch()

    private weak var statusTitleLabel: UILabel?
    private weak var statusCaptionLabel: UILabel?
    private weak var sampleStatusValueLabel: UILabel?
    private weak var voiceAvailabilityLabel: UILabel?
    private weak var synthesisStatusValueLabel: UILabel?
    private weak var authorizationHintLabel: UILabel?
    private weak var feedbackLabel: UILabel?
    private weak var submitButton: UIButton?
    private weak var previewButton: UIButton?
    private weak var acceptQualityButton: UIButton?
    private weak var refreshButton: UIButton?
    private weak var disableButton: UIButton?
    private weak var deleteButton: UIButton?
    private var previewPlayer: AVAudioPlayer?
    private var previewFileURL: URL?
    private var qualityPreviewReceipt: QualityPreviewReceipt?
    private var viewAccountLease: AccountLease?
    private var viewDigitalHumanContext: DigitalHumanContext?

    private var isBusy = false {
        didSet { updateActionAvailability() }
    }

    init(snapshot: VoiceCloneProfileSnapshot = VoiceCloneService.shared.voiceCloneShellSnapshot()) {
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewDigitalHumanContext = DigitalHumanContextStore.shared.current
        viewAccountLease = captureViewAccountLease()
        title = "音色复刻"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-voice-clone-shell"
        setupLayout()
        renderSnapshot(snapshot, feedback: "先确认授权，再选择本人音频样本提交训练。")
        loadVoiceCloneRuntimeCapability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showPreviousLevelNavigationIfNeeded(animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPreviewRuntime()
    }

    private func captureViewAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        return accountLease
    }

    private func validateViewOperation(at checkpoint: AccountLeaseCheckpoint) -> Bool {
        guard let accountLease = viewAccountLease,
              let digitalHumanContext = viewDigitalHumanContext else {
            return false
        }
        return accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
            && digitalHumanContext == DigitalHumanContextStore.shared.current
    }

    private func setupLayout() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 18,
            leading: DJDesignTokens.Spacing.page,
            bottom: 32,
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

        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.addArrangedSubview(makeAuthorizationCard())
        contentStack.addArrangedSubview(makeActionCard())
    }

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18

        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 14

        let iconContainer = UIView()
        iconContainer.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.14)
        iconContainer.layer.cornerRadius = 24
        iconContainer.layer.masksToBounds = true

        let iconView = UIImageView(image: UIImage(systemName: "waveform.badge.mic"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit
        iconContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25),
        ])

        let titleLabel = makeLabel(
            text: "音色复刻",
            font: DJDesignTokens.Font.title(22),
            color: DJDesignTokens.Color.textPrimary
        )

        let subtitleLabel = makeLabel(
            text: "用一段本人授权的声音样本，生成可用于回响的专属音色。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        headerStack.addArrangedSubview(iconContainer)
        headerStack.addArrangedSubview(textStack)
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
        ])

        let statusContainer = UIView()
        statusContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.70)
        statusContainer.layer.cornerRadius = DJDesignTokens.Radius.medium
        statusContainer.layer.masksToBounds = true

        let statusStack = UIStackView()
        statusStack.axis = .vertical
        statusStack.spacing = 8
        statusContainer.addSubview(statusStack)
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusStack.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 14),
            statusStack.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 14),
            statusStack.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -14),
            statusStack.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -14),
        ])

        let statusTitle = makeLabel(
            text: voiceStatusTitle(for: snapshot),
            font: DJDesignTokens.Font.title(18),
            color: DJDesignTokens.Color.textPrimary
        )
        statusTitle.accessibilityIdentifier = "profileVoiceCloneStatusTitle"
        statusTitleLabel = statusTitle

        let statusCaption = makeLabel(
            text: voiceStatusCaption(for: snapshot),
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )
        statusCaption.accessibilityIdentifier = "profileVoiceCloneStatusCaption"
        statusCaptionLabel = statusCaption

        let sampleRow = makeInfoRow(
            title: "样本状态",
            value: snapshot.sampleStatus.displayText,
            accessibilityIdentifier: "profileVoiceCloneSampleStatusValue"
        ) { [weak self] label in
            self?.sampleStatusValueLabel = label
        }

        let availabilityRow = makeInfoRow(
            title: "可用状态",
            value: voiceAvailabilityText(for: snapshot),
            accessibilityIdentifier: "profileVoiceCloneEntryStatusValue"
        ) { [weak self] label in
            self?.voiceAvailabilityLabel = label
        }

        let synthesisRow = makeInfoRow(
            title: "回响语音",
            value: voiceSynthesisStatusText(for: snapshot),
            accessibilityIdentifier: "profileVoiceCloneSynthesisStatusValue"
        ) { [weak self] label in
            self?.synthesisStatusValueLabel = label
        }

        [statusTitle, statusCaption, sampleRow, availabilityRow, synthesisRow].forEach(statusStack.addArrangedSubview)

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(statusContainer)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeAuthorizationCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(makeSectionTitle("授权与样本"))
        stack.addArrangedSubview(makeBody("只使用你主动选择的音频样本训练音色。训练、查询、合成、禁用和删除都由后端代理处理。"))

        let authorizationRow = UIStackView()
        authorizationRow.axis = .horizontal
        authorizationRow.alignment = .center
        authorizationRow.spacing = 12

        let authorizationLabel = makeLabel(
            text: "我确认本人授权，并同意仅用于寻梦环游音色复刻。",
            font: DJDesignTokens.Font.label(14),
            color: DJDesignTokens.Color.textPrimary
        )
        authorizationSwitch.accessibilityIdentifier = "profileVoiceCloneAuthorizeSwitch"
        authorizationSwitch.addTarget(self, action: #selector(authorizationChanged), for: .valueChanged)
        authorizationRow.addArrangedSubview(authorizationLabel)
        authorizationRow.addArrangedSubview(authorizationSwitch)
        authorizationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        authorizationSwitch.setContentHuggingPriority(.required, for: .horizontal)

        let authorizationHint = makeLabel(
            text: "确认授权后才能提交声音样本。",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textTertiary
        )
        authorizationHint.accessibilityIdentifier = "profileVoiceCloneAuthorizationHint"
        authorizationHintLabel = authorizationHint

        stack.addArrangedSubview(authorizationRow)
        stack.addArrangedSubview(authorizationHint)

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeActionCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(makeSectionTitle("训练与管理"))

        let feedback = makeLabel(
            text: "",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )
        feedback.accessibilityIdentifier = "profileVoiceCloneFeedbackLabel"
        feedbackLabel = feedback

        let submit = makeActionButton(title: "选择音频样本并提交", style: .primary)
        submit.accessibilityIdentifier = "profileVoiceCloneSubmitButton"
        submit.addTarget(self, action: #selector(submitSampleTapped), for: .touchUpInside)
        submitButton = submit

        let preview = makeActionButton(title: "试听复刻效果", style: .secondary)
        preview.accessibilityIdentifier = "profileVoiceClonePreviewButton"
        preview.addTarget(self, action: #selector(previewVoiceTapped), for: .touchUpInside)
        previewButton = preview

        let accept = makeActionButton(title: "确认使用此音色", style: .primary)
        accept.accessibilityIdentifier = "profileVoiceCloneAcceptQualityButton"
        accept.addTarget(self, action: #selector(acceptVoiceQualityTapped), for: .touchUpInside)
        acceptQualityButton = accept

        let refresh = makeActionButton(title: "刷新训练状态", style: .secondary)
        refresh.accessibilityIdentifier = "profileVoiceCloneRefreshButton"
        refresh.addTarget(self, action: #selector(refreshStatusTapped), for: .touchUpInside)
        refreshButton = refresh

        let disable = makeActionButton(title: "禁用音色", style: .secondary)
        disable.accessibilityIdentifier = "profileVoiceCloneDisableButton"
        disable.addTarget(self, action: #selector(disableVoiceTapped), for: .touchUpInside)
        disableButton = disable

        let delete = makeActionButton(title: "删除音色", style: .destructive)
        delete.accessibilityIdentifier = "profileVoiceCloneDeleteButton"
        delete.addTarget(self, action: #selector(deleteVoiceTapped), for: .touchUpInside)
        deleteButton = delete

        [feedback, submit, preview, accept, refresh, disable, delete].forEach(stack.addArrangedSubview)

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    @objc private func authorizationChanged() {
        let message = voiceTrainingAdmissionHint()
        authorizationHintLabel?.text = message
        feedbackLabel?.text = message
        updateActionAvailability()
    }

    @objc private func submitSampleTapped() {
        guard validateViewOperation(at: .request) else {
            feedbackLabel?.text = "账号或回响角色已变化，请重新进入后再提交。"
            return
        }
        guard authorizationSwitch.isOn else {
            feedbackLabel?.text = "请先确认本人授权。"
            return
        }

        let wavType = UTType(filenameExtension: "wav") ?? .audio
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [wavType], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func refreshStatusTapped() {
        guard validateViewOperation(at: .request) else { return }
        guard hasVoiceProfile else {
            feedbackLabel?.text = "还没有可刷新的音色。"
            return
        }
        setBusyFeedback("正在刷新训练状态...")
        VoiceCloneService.shared.queryStatus(speakerId: snapshot.voiceProfileId) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success:
                    self.reloadBackendSnapshot(feedback: "训练状态已刷新。")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    @objc private func previewVoiceTapped() {
        guard validateViewOperation(at: .request),
              let accountLease = viewAccountLease else {
            feedbackLabel?.text = "账号或回响角色已变化，请重新进入后再试听。"
            return
        }
        guard canPreviewVoice else {
            feedbackLabel?.text = "训练完成并确认合成服务可用后，才能试听复刻效果。"
            return
        }
        qualityPreviewReceipt = nil
        updateActionAvailability()
        setBusyFeedback("正在生成试听音频...")
        DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
            userId: accountLease.subjectId,
            voiceProfileId: snapshot.voiceProfileId,
            text: "你好，我是你的复刻声音。请听听这段声音是否像你本人。",
            audioFormat: "mp3",
            sampleRate: 24000,
            requestPurpose: "qualityPreview"
        ) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success(let synthesis):
                    guard let receiptId = synthesis.qualityPreviewReceiptId,
                          !receiptId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        self.finishBusy(feedback: "试听生成失败：后端未返回试听确认凭据。")
                        return
                    }
                    let receipt = QualityPreviewReceipt(
                        voiceProfileId: self.snapshot.voiceProfileId,
                        retryGeneration: self.snapshot.retryGeneration,
                        value: receiptId,
                        expiresAt: synthesis.qualityPreviewExpiresAt
                    )
                    self.playPreviewAudio(
                        synthesis,
                        accountLease: accountLease,
                        qualityPreviewReceipt: receipt
                    )
                case .failure(let error):
                    self.finishBusy(feedback: "试听生成失败：\(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func acceptVoiceQualityTapped() {
        guard validateViewOperation(at: .request) else { return }
        guard canAcceptVoiceQuality else {
            feedbackLabel?.text = "请先试听训练完成的音色，再确认使用。"
            return
        }

        let alert = UIAlertController(
            title: "确认使用此音色？",
            message: "确认后，回响和后续合成会使用这份音色。若听感不像本人，请重新提交样本。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "再听一下", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认使用", style: .default) { [weak self] _ in
            self?.performAcceptVoiceQuality()
        })
        present(alert, animated: true)
    }

    @objc private func disableVoiceTapped() {
        confirmDestructive(
            title: "禁用音色",
            message: "禁用后该音色将不能继续用于后端合成，可重新提交样本恢复。",
            actionTitle: "禁用"
        ) { [weak self] in
            self?.performDisableVoice()
        }
    }

    private func playPreviewAudio(
        _ synthesis: VoiceCloneSynthesisResult,
        accountLease: AccountLease,
        qualityPreviewReceipt: QualityPreviewReceipt
    ) {
        guard viewAccountLease == accountLease,
              validateViewOperation(at: .runtime) else {
            return
        }
        guard let audioData = synthesis.audioData, !audioData.isEmpty else {
            finishBusy(feedback: "试听生成失败：后端未返回有效音频。")
            return
        }
        do {
            stopPreviewRuntime()
            let fileExtension = synthesis.audioFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "mp3"
                : synthesis.audioFormat
            let previewURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "voice-clone-preview-\(snapshot.voiceProfileId)-\(accountLease.generationId.uuidString)"
                )
                .appendingPathExtension(fileExtension)
            guard validateViewOperation(at: .commit) else { return }
            try audioData.write(to: previewURL, options: .atomic)
            guard validateViewOperation(at: .commit) else {
                try? FileManager.default.removeItem(at: previewURL)
                return
            }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            guard validateViewOperation(at: .runtime) else {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                try? FileManager.default.removeItem(at: previewURL)
                return
            }
            previewFileURL = previewURL
            previewPlayer = try AVAudioPlayer(contentsOf: previewURL)
            previewPlayer?.delegate = self
            previewPlayer?.prepareToPlay()
            guard previewPlayer?.play() == true else {
                stopPreviewRuntime()
                finishBusy(feedback: "试听播放失败：无法开始播放音频。")
                return
            }
            self.qualityPreviewReceipt = qualityPreviewReceipt
            finishBusy(feedback: "试听已开始。若声音像本人，请点“确认使用此音色”；不满意可重新提交样本。")
        } catch {
            finishBusy(feedback: "试听播放失败：\(error.localizedDescription)")
        }
    }

    private func stopPreviewRuntime() {
        let ownedPreviewRuntime = previewPlayer != nil || previewFileURL != nil
        previewPlayer?.stop()
        previewPlayer = nil
        if ownedPreviewRuntime {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        if let previewFileURL {
            try? FileManager.default.removeItem(at: previewFileURL)
        }
        previewFileURL = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === previewPlayer else { return }
        stopPreviewRuntime()
    }

    private func performAcceptVoiceQuality() {
        guard validateViewOperation(at: .request) else { return }
        guard voiceCloneRuntimeCapability.canPerform(.accept) else {
            finishBusy(feedback: "当前服务未开放音色确认，请刷新能力状态后重试。")
            return
        }
        guard let receipt = currentQualityPreviewReceipt else {
            finishBusy(feedback: "请先生成并试听复刻音频后再确认。")
            return
        }
        setBusyFeedback("正在确认音色效果...")
        VoiceCloneService.shared.acceptVoiceProfileQualityRemote(
            profileId: snapshot.voiceProfileId,
            previewReceiptId: receipt.value
        ) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success(let snapshot):
                    self.qualityPreviewReceipt = nil
                    self.applySnapshot(snapshot, feedback: "已确认使用此音色，后续回响可使用复刻语音。")
                case .failure(let error):
                    self.finishBusy(feedback: "确认失败：\(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func deleteVoiceTapped() {
        confirmDestructive(
            title: "删除音色",
            message: "删除会立即停止该音色用于回响，并更新本地记录。当前未接入第三方服务清理回执，无法确认第三方数据是否已删除。此操作不可恢复。",
            actionTitle: "删除"
        ) { [weak self] in
            self?.performDeleteVoice()
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard validateViewOperation(at: .ui),
              validateViewOperation(at: .request) else { return }
        guard canSubmitVoiceTraining else {
            feedbackLabel?.text = snapshot.sampleStatus == .failed
                ? "当前失败记录尚未获得重试许可，请先刷新训练状态。"
                : "声音复刻训练服务暂不可用，请稍后再试。"
            return
        }
        guard let audioURL = urls.first else { return }
        let didAccess = audioURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                audioURL.stopAccessingSecurityScopedResource()
            }
        }

        let retryingProfile = snapshot.canRetryTraining ? snapshot : nil
        guard let temporaryURL = copySelectedVoiceSample(audioURL) else {
            feedbackLabel?.text = "音频文件读取失败，请确认文件已下载到本机后重试。"
            return
        }
        setBusyFeedback("正在获取本人授权语句...")
        VoiceCloneService.shared.prepareSampleAuthorization(
            retryingProfile: retryingProfile
        ) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else {
                self?.removeTemporaryVoiceSample(temporaryURL)
                return
            }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else {
                    self.removeTemporaryVoiceSample(temporaryURL)
                    return
                }
                switch result {
                case .success(let preparation):
                    self.presentSampleAuthorizationConfirmation(
                        temporaryURL: temporaryURL,
                        retryingProfile: retryingProfile,
                        preparation: preparation
                    )
                case .failure(let error):
                    self.removeTemporaryVoiceSample(temporaryURL)
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func presentSampleAuthorizationConfirmation(
        temporaryURL: URL,
        retryingProfile: VoiceCloneProfileSnapshot?,
        preparation: VoiceCloneSampleAuthorizationPreparation
    ) {
        let alert = UIAlertController(
            title: "确认本人声音样本",
            message: "请确认以下声明后再提交训练：\n\n\(preparation.authorization.statement)\n\n该授权语句将在短时间后失效。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.removeTemporaryVoiceSample(temporaryURL)
            self?.finishBusy(feedback: "已取消提交声音样本。")
        })
        alert.addAction(UIAlertAction(title: "确认并提交", style: .default) { [weak self] _ in
            self?.submitAuthorizedVoiceSample(
                temporaryURL: temporaryURL,
                retryingProfile: retryingProfile,
                preparation: preparation
            )
        })
        present(alert, animated: true)
    }

    private func submitAuthorizedVoiceSample(
        temporaryURL: URL,
        retryingProfile: VoiceCloneProfileSnapshot?,
        preparation: VoiceCloneSampleAuthorizationPreparation
    ) {
        guard validateViewOperation(at: .request) else {
            removeTemporaryVoiceSample(temporaryURL)
            return
        }
        setBusyFeedback(retryingProfile == nil ? "正在提交后端训练..." : "正在重新提交后端训练...")
        VoiceCloneService.shared.trainVoice(
            audioURL: temporaryURL,
            speakerId: preparation.voiceProfileId,
            authorizationConfirmed: true,
            sampleAuthorization: preparation.authorization,
            retryingProfile: retryingProfile,
            onProfileAccepted: { [weak self] snapshot in
                guard let self, self.validateViewOperation(at: .runtime) else { return }
                DispatchQueue.main.async {
                    guard self.validateViewOperation(at: .ui) else { return }
                    self.applySnapshot(snapshot, feedback: "后端已接收声音样本，训练中；可稍后刷新状态。")
                }
            }
        ) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                self.removeTemporaryVoiceSample(temporaryURL)
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success:
                    self.reloadBackendSnapshot(feedback: "音色训练状态已更新，请先试听确认效果。")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func copySelectedVoiceSample(_ sourceURL: URL) -> URL? {
        let extensionValue = sourceURL.pathExtension.lowercased()
        guard extensionValue == "wav",
              let data = try? Data(contentsOf: sourceURL),
              !data.isEmpty,
              data.count <= 10 * 1024 * 1024 else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-clone-sample-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func removeTemporaryVoiceSample(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard validateViewOperation(at: .ui) else { return }
        feedbackLabel?.text = "已取消选择音频样本。"
    }

    private func performDisableVoice() {
        guard validateViewOperation(at: .request) else { return }
        guard voiceCloneRuntimeCapability.canPerform(.pause) else {
            feedbackLabel?.text = "当前服务未开放音色暂停，请刷新能力状态后重试。"
            return
        }
        guard hasVoiceProfile, snapshot.canDisableRemotely else {
            feedbackLabel?.text = "还没有可禁用的音色。"
            return
        }
        setBusyFeedback("正在禁用音色...")
        VoiceCloneService.shared.disableVoiceProfileRemote(profileId: snapshot.voiceProfileId) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success(let snapshot):
                    self.applySnapshot(
                        snapshot,
                        feedback: snapshot.exitDisclosureText.isEmpty ? "音色已暂停用于回响。" : snapshot.exitDisclosureText
                    )
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func performDeleteVoice() {
        guard validateViewOperation(at: .request) else { return }
        guard voiceCloneRuntimeCapability.canPerform(.delete) else {
            feedbackLabel?.text = "当前服务未开放音色删除，请刷新能力状态后重试。"
            return
        }
        guard hasVoiceProfile, snapshot.canDeleteRemotely else {
            feedbackLabel?.text = "还没有可删除的音色。"
            return
        }
        setBusyFeedback("正在删除音色...")
        VoiceCloneService.shared.deleteVoiceProfileRemote(profileId: snapshot.voiceProfileId) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success(let snapshot):
                    self.applySnapshot(snapshot, feedback: snapshot.exitDisclosureText)
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func reloadBackendSnapshot(feedback: String) {
        guard validateViewOperation(at: .request),
              let accountLease = viewAccountLease else {
            return
        }
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured,
              !accountLease.subjectId.isEmpty else {
            finishBusy(feedback: "后端语音服务尚未配置，无法刷新音色状态。")
            return
        }

        DreamJourneyBackendClient.shared.fetchVoiceCloneProfiles(userId: accountLease.subjectId) { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                switch result {
                case .success(let profiles):
                    let currentProfileId = self.snapshot.voiceProfileId
                    let selectedProfile = VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles, preferredProfileId: currentProfileId)
                    if let selectedProfile {
                        self.applySnapshot(VoiceCloneProfileSnapshot(backendContract: selectedProfile), feedback: feedback)
                    } else {
                        self.applySnapshot(VoiceCloneService.shared.voiceCloneShellSnapshot(), feedback: feedback)
                    }
                case .failure(let error):
                    self.finishBusy(feedback: "刷新失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func loadVoiceCloneRuntimeCapability() {
        guard validateViewOperation(at: .request) else {
            synthesisStatusValueLabel?.text = voiceSynthesisStatusText(for: snapshot)
            updateActionAvailability()
            return
        }
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            synthesisStatusValueLabel?.text = voiceSynthesisStatusText(for: snapshot)
            return
        }

        DreamJourneyBackendClient.shared.fetchVoiceCloneRuntimeCapability { [weak self] result in
            guard let self, self.validateViewOperation(at: .runtime) else { return }
            DispatchQueue.main.async {
                guard self.validateViewOperation(at: .ui) else { return }
                if case .success(let capability) = result {
                    self.voiceCloneRuntimeCapability = capability
                }
                self.authorizationHintLabel?.text = self.voiceTrainingAdmissionHint()
                self.synthesisStatusValueLabel?.text = self.voiceSynthesisStatusText(for: self.snapshot)
                self.updateActionAvailability()
            }
        }
    }

    private func applySnapshot(_ snapshot: VoiceCloneProfileSnapshot, feedback: String? = nil) {
        guard validateViewOperation(at: .commit) else { return }
        if qualityPreviewReceipt?.voiceProfileId != snapshot.voiceProfileId
            || qualityPreviewReceipt?.retryGeneration != snapshot.retryGeneration
            || !snapshot.qualityAcceptanceRequired
            || snapshot.lifecycleState != .previewReady {
            qualityPreviewReceipt = nil
        }
        VoiceCloneService.shared.persistSnapshot(snapshot)
        guard validateViewOperation(at: .ui) else { return }
        renderSnapshot(snapshot, feedback: feedback)
    }

    private func renderSnapshot(_ snapshot: VoiceCloneProfileSnapshot, feedback: String? = nil) {
        self.snapshot = snapshot
        statusTitleLabel?.text = voiceStatusTitle(for: snapshot)
        statusCaptionLabel?.text = voiceStatusCaption(for: snapshot)
        sampleStatusValueLabel?.text = voiceSampleStatusText(for: snapshot)
        voiceAvailabilityLabel?.text = voiceAvailabilityText(for: snapshot)
        synthesisStatusValueLabel?.text = voiceSynthesisStatusText(for: snapshot)
        if let feedback {
            feedbackLabel?.text = feedback
        }
        isBusy = false
        updateActionAvailability()
    }

    private func setBusyFeedback(_ text: String) {
        isBusy = true
        feedbackLabel?.text = text
    }

    private func finishBusy(feedback: String) {
        isBusy = false
        feedbackLabel?.text = feedback
    }

    private var hasVoiceProfile: Bool {
        let profileId = snapshot.voiceProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
        return !profileId.isEmpty && profileId != "voiceProfileId_not_created"
    }

    private var canPreviewVoice: Bool {
        hasVoiceProfile
            && snapshot.canPreviewQuality
            && voiceCloneRuntimeCapability.canPerform(.preview)
    }

    private var canSubmitVoiceTraining: Bool {
        guard voiceCloneRuntimeCapability.canTrain else { return false }
        return snapshot.sampleStatus != .failed || snapshot.canRetryTraining
    }

    private func voiceTrainingAdmissionHint() -> String {
        guard authorizationSwitch.isOn else {
            return "确认授权后才能提交声音样本。"
        }
        guard voiceCloneRuntimeCapability.canTrain else {
            switch voiceCloneRuntimeCapability.trainingAdmissionReason {
            case "identityLivenessProviderUnavailable":
                return "身份与活体核验服务尚未完成配置，暂不能提交训练。"
            case "voiceCloneProviderUnavailable":
                return "音色训练服务暂不可用，请稍后再试。"
            default:
                return "当前暂不能提交训练，请稍后刷新服务状态。"
            }
        }
        return "已确认授权，可以选择音频样本提交训练。"
    }

    private var canRefreshVoiceTrainingStatus: Bool {
        voiceCloneRuntimeCapability.canQuery
    }

    private var canAcceptVoiceQuality: Bool {
        voiceCloneRuntimeCapability.canPerform(.accept)
            && snapshot.canAcceptQuality
            && currentQualityPreviewReceipt != nil
    }

    private var currentQualityPreviewReceipt: QualityPreviewReceipt? {
        guard let receipt = qualityPreviewReceipt,
              receipt.voiceProfileId == snapshot.voiceProfileId,
              receipt.retryGeneration == snapshot.retryGeneration,
              !receipt.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return receipt
    }

    private func updateActionAvailability() {
        let hasValidLease = validateViewOperation(at: .ui)
        submitButton?.isEnabled = hasValidLease
            && !isBusy
            && authorizationSwitch.isOn
            && canSubmitVoiceTraining
        previewButton?.isEnabled = hasValidLease && !isBusy && canPreviewVoice
        acceptQualityButton?.isEnabled = hasValidLease && !isBusy && canAcceptVoiceQuality
        refreshButton?.isEnabled = hasValidLease
            && !isBusy
            && hasVoiceProfile
            && canRefreshVoiceTrainingStatus
            && (!snapshot.isUseRevoked || snapshot.canRefreshExitState)
        disableButton?.isEnabled = hasValidLease
            && !isBusy
            && hasVoiceProfile
            && snapshot.canDisableRemotely
            && voiceCloneRuntimeCapability.canPerform(.pause)
        deleteButton?.isEnabled = hasValidLease
            && !isBusy
            && hasVoiceProfile
            && snapshot.canDeleteRemotely
            && voiceCloneRuntimeCapability.canPerform(.delete)
        previewButton?.isHidden = !canPreviewVoice
        acceptQualityButton?.isHidden = !canAcceptVoiceQuality
        [refreshButton, disableButton, deleteButton].forEach { button in
            button?.isHidden = !hasVoiceProfile
        }
        updateButtonAppearance()
    }

    private func confirmDestructive(
        title: String,
        message: String,
        actionTitle: String,
        handler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive) { _ in handler() })
        present(alert, animated: true)
    }

    private func voiceStatusTitle(for snapshot: VoiceCloneProfileSnapshot) -> String {
        switch snapshot.lifecycleState {
        case .paused:
            return "音色已暂停"
        case .deleting:
            return "正在停止音色"
        case .deleted:
            return snapshot.exitState == "completed" ? "音色已删除" : "正在确认删除"
        default:
            break
        }
        switch snapshot.sampleStatus {
        case .notProvided:
            return "还没有创建音色"
        case .pending:
            return "样本已提交"
        case .ready:
            guard snapshot.isReadyForUse else {
                if !snapshot.eligibilityAllowed {
                    return "本人资格待验证"
                }
                if snapshot.lifecycleSchemaVersion != "voice-profile-lifecycle-v1" {
                    return "音色状态待安全校验"
                }
                if snapshot.qualityAcceptanceRequired && snapshot.realCloneProviderReady {
                    return "训练完成，待试听确认"
                }
                return "音色状态待同步"
            }
            return "音色已可使用"
        case .failed:
            return "训练失败，可重新提交"
        case .disabled:
            return "音色已禁用"
        case .deleted:
            return "音色已停止使用"
        }
    }

    private func voiceSampleStatusText(for snapshot: VoiceCloneProfileSnapshot) -> String {
        switch snapshot.lifecycleState {
        case .deleting:
            return "清理中"
        case .deleted:
            return "已删除"
        default:
            return snapshot.sampleStatus.displayText
        }
    }

    private func voiceStatusCaption(for snapshot: VoiceCloneProfileSnapshot) -> String {
        switch snapshot.lifecycleState {
        case .paused, .deleting, .deleted:
            let disclosure = snapshot.exitDisclosureText.isEmpty
                ? "该音色已停止用于回响。"
                : snapshot.exitDisclosureText
            guard !snapshot.providerCleanupReceiptAvailable else {
                return disclosure
            }
            return "\(disclosure) 在收到确认前，不会把第三方清理误报为完成。"
        default:
            break
        }
        switch snapshot.sampleStatus {
        case .notProvided:
            return "确认授权后，选择一段清晰的本人音频样本开始训练。"
        case .pending:
            return "后端已接收样本，稍后刷新即可查看训练结果。"
        case .ready:
            guard snapshot.isReadyForUse else {
                if !snapshot.eligibilityAllowed {
                    return "当前账号尚未完成本人、在世成年人资格验证，这份音色暂不能试听或用于回响。"
                }
                if snapshot.lifecycleSchemaVersion != "voice-profile-lifecycle-v1" {
                    return "这份历史音色缺少当前授权与资格状态，请刷新训练状态后再使用。"
                }
                if !snapshot.realCloneProviderReady {
                    return "后端还未确认这次训练可用于合成，请刷新训练状态。"
                }
                if snapshot.qualityAcceptanceRequired {
                    return "火山已返回可合成状态，但这不等于音色效果已验收；请试听确认后再作为正式复刻音色使用。"
                }
                return "音色槽位已返回，但还未满足回响可用条件，请刷新训练状态。"
            }
            return "后续回响可使用这份音色，仍可随时禁用或删除。"
        case .failed:
            if let providerMessage = providerFailureMessage(for: snapshot) {
                return "训练未完成：\(providerMessage)"
            }
            return "这次样本未能完成训练，可以换一段更清晰的音频重试。"
        case .disabled:
            return "当前音色不会再用于合成，可重新提交样本恢复。"
        case .deleted:
            return snapshot.exitDisclosureText
        }
    }

    private func providerFailureMessage(for snapshot: VoiceCloneProfileSnapshot) -> String? {
        snapshot.providerFailureDisplayText
    }

    private func voiceAvailabilityText(for snapshot: VoiceCloneProfileSnapshot) -> String {
        if snapshot.isUseRevoked {
            return "不可用于回响"
        }
        switch snapshot.sampleStatus {
        case .ready:
            if snapshot.isReadyForUse {
                return "可用于回响"
            }
            if !snapshot.eligibilityAllowed {
                return "资格待验证"
            }
            if snapshot.lifecycleSchemaVersion != "voice-profile-lifecycle-v1" {
                return "待安全校验"
            }
            if snapshot.qualityAcceptanceRequired && snapshot.realCloneProviderReady {
                return "待试听确认"
            }
            return "待同步确认"
        case .pending:
            return "训练中"
        case .failed:
            return "待重试"
        case .disabled:
            return "已暂停"
        case .deleted:
            return "已停止"
        case .notProvided:
            return "待创建"
        }
    }

    private func voiceSynthesisStatusText(for snapshot: VoiceCloneProfileSnapshot) -> String {
        if snapshot.isUseRevoked {
            if snapshot.lifecycleState == .paused || snapshot.exitState == "accessRevoked" {
                return "音色已暂停，回响会使用普通语音"
            }
            return "音色已停止使用，回响会使用普通语音"
        }
        switch snapshot.sampleStatus {
        case .ready:
            guard snapshot.isReadyForUse else {
                if !snapshot.eligibilityAllowed {
                    return "本人资格待验证，暂不用于回响"
                }
                if snapshot.lifecycleSchemaVersion != "voice-profile-lifecycle-v1" {
                    return "音色状态待安全校验，暂不用于回响"
                }
                if snapshot.qualityAcceptanceRequired && snapshot.realCloneProviderReady {
                    return "可合成，待确认效果"
                }
                return "音色状态待同步，暂不用于回响"
            }
            if voiceCloneRuntimeCapability.canSynthesize {
                if voiceCloneRuntimeCapability.voiceClone2TrialReady,
                   voiceCloneRuntimeCapability.tencentAudioDrive.supported {
                    return "音色已就绪，回响可使用复刻语音"
                }
                return "音色已就绪，回响可使用复刻语音"
            }
            return "音色已就绪，合成服务待配置"
        case .pending:
            return "训练完成后可用于回响"
        case .failed:
            return "训练失败，重新提交样本后可用"
        case .disabled:
            return "音色已暂停，回响会使用普通语音"
        case .deleted:
            return "音色已停止使用，回响会使用普通语音"
        case .notProvided:
            return "创建音色后可用于回响"
        }
    }

    private func makeInfoRow(
        title: String,
        value: String,
        accessibilityIdentifier: String? = nil,
        valueLabelHandler: ((UILabel) -> Void)? = nil
    ) -> UIView {
        let row = UIStackView()
        row.alignment = .firstBaseline
        row.spacing = 12

        let titleLabel = makeLabel(
            text: title,
            font: DJDesignTokens.Font.label(12),
            color: DJDesignTokens.Color.textTertiary
        )
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = makeLabel(
            text: value,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textSecondary
        )
        valueLabel.textAlignment = .right
        valueLabel.accessibilityIdentifier = accessibilityIdentifier
        valueLabelHandler?(valueLabel)

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        makeLabel(
            text: text,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
    }

    private func makeBody(_ text: String) -> UILabel {
        makeLabel(
            text: text,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
    }

    private enum ActionButtonStyle {
        case primary
        case secondary
        case destructive
    }

    private func makeActionButton(title: String, style: ActionButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(14)
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        button.tag = {
            switch style {
            case .primary:
                return 1
            case .secondary:
                return 2
            case .destructive:
                return 3
            }
        }()

        switch style {
        case .primary:
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = DJDesignTokens.Color.accent
        case .secondary:
            button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
            button.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.78)
        case .destructive:
            button.setTitleColor(DJDesignTokens.Color.danger, for: .normal)
            button.backgroundColor = DJDesignTokens.Color.danger.withAlphaComponent(0.10)
        }
        button.setTitleColor(DJDesignTokens.Color.textTertiary, for: .disabled)
        return button
    }

    private func updateButtonAppearance() {
        [submitButton, previewButton, acceptQualityButton, refreshButton, disableButton, deleteButton].forEach { button in
            guard let button else { return }
            switch button.tag {
            case 1:
                button.backgroundColor = button.isEnabled
                    ? DJDesignTokens.Color.accent
                    : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.88)
                button.setTitleColor(button.isEnabled ? .white : DJDesignTokens.Color.textTertiary, for: .normal)
            case 2:
                button.backgroundColor = button.isEnabled
                    ? DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.78)
                    : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.52)
                button.setTitleColor(
                    button.isEnabled ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.textTertiary,
                    for: .normal
                )
            case 3:
                button.backgroundColor = button.isEnabled
                    ? DJDesignTokens.Color.danger.withAlphaComponent(0.10)
                    : DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.52)
                button.setTitleColor(
                    button.isEnabled ? DJDesignTokens.Color.danger : DJDesignTokens.Color.textTertiary,
                    for: .normal
                )
            default:
                break
            }
        }
    }

    private func makeCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.46).cgColor
        return card
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }
}
