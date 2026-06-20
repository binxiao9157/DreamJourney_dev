import UIKit
import UniformTypeIdentifiers

final class ProfileVoiceCloneShellViewController: UIViewController, UIDocumentPickerDelegate {
    private var snapshot: VoiceCloneProfileSnapshot
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let authorizationSwitch = UISwitch()

    private weak var sampleStatusValueLabel: UILabel?
    private weak var profileIdValueLabel: UILabel?
    private weak var providerModeValueLabel: UILabel?
    private weak var contractVersionValueLabel: UILabel?
    private weak var entryStatusValueLabel: UILabel?
    private weak var feedbackLabel: UILabel?
    private weak var submitButton: UIButton?
    private weak var refreshButton: UIButton?
    private weak var disableButton: UIButton?
    private weak var deleteButton: UIButton?

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
        title = "音色复刻"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-voice-clone-shell"
        setupLayout()
        applySnapshot(snapshot, feedback: "先确认授权，再选择本人音频样本提交训练。")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showPreviousLevelNavigationIfNeeded(animated: animated)
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
        contentStack.addArrangedSubview(makeContractCard())
        contentStack.addArrangedSubview(makeActionCard())
    }

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        let iconView = UIImageView(image: UIImage(systemName: "waveform.badge.mic"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "音色复刻",
            font: DJDesignTokens.Font.title(22),
            color: DJDesignTokens.Color.textPrimary
        )

        let subtitleLabel = makeLabel(
            text: "提交本人授权的音频样本，由后端代理训练音色；iOS 不保存火山语音密钥。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let statusStack = UIStackView()
        statusStack.axis = .vertical
        statusStack.spacing = 10

        let sampleRow = makeInfoRow(
            title: "声音样本状态",
            value: snapshot.sampleStatus.displayText,
            accessibilityIdentifier: "profileVoiceCloneSampleStatusValue"
        ) { [weak self] label in
            self?.sampleStatusValueLabel = label
        }
        let profileRow = makeInfoRow(
            title: "voiceProfileId",
            value: snapshot.voiceProfileId,
            accessibilityIdentifier: "profileVoiceCloneProfileIdValue"
        ) { [weak self] label in
            self?.profileIdValueLabel = label
        }
        let providerRow = makeInfoRow(
            title: "providerMode",
            value: snapshot.providerMode,
            accessibilityIdentifier: "profileVoiceCloneProviderModeValue"
        ) { [weak self] label in
            self?.providerModeValueLabel = label
        }
        let versionRow = makeInfoRow(
            title: "合同版本",
            value: "\(snapshot.contractVersion)",
            accessibilityIdentifier: "profileVoiceCloneContractVersionValue"
        ) { [weak self] label in
            self?.contractVersionValueLabel = label
        }
        let entryRow = makeInfoRow(
            title: "入口状态",
            value: "公开可见，需授权训练",
            accessibilityIdentifier: "profileVoiceCloneEntryStatusValue"
        ) { [weak self] label in
            self?.entryStatusValueLabel = label
        }

        [sampleRow, profileRow, providerRow, versionRow, entryRow].forEach(statusStack.addArrangedSubview)

        card.addSubview(stack)
        [stack, iconView, titleLabel, subtitleLabel, statusStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(statusStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 38),
            iconView.heightAnchor.constraint(equalToConstant: 38),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeContractCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(makeSectionTitle("授权说明"))
        stack.addArrangedSubview(makeBody(snapshot.authorizationCopy))

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

        stack.addArrangedSubview(authorizationRow)
        stack.addArrangedSubview(makeSectionTitle("删除/禁用合同"))
        stack.addArrangedSubview(makeBody(snapshot.disableContract))
        stack.addArrangedSubview(makeBody(snapshot.deleteContract))

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

        [feedback, submit, refresh, disable, delete].forEach(stack.addArrangedSubview)

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
        feedbackLabel?.text = authorizationSwitch.isOn
            ? "已确认授权，可以选择音频样本提交训练。"
            : "勾选授权后才能提交声音样本。"
        updateActionAvailability()
    }

    @objc private func submitSampleTapped() {
        guard authorizationSwitch.isOn else {
            feedbackLabel?.text = "请先确认本人授权。"
            return
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func refreshStatusTapped() {
        guard hasVoiceProfile else {
            feedbackLabel?.text = "还没有可刷新的 voiceProfileId。"
            return
        }
        setBusyFeedback("正在刷新训练状态...")
        VoiceCloneService.shared.queryStatus(speakerId: snapshot.voiceProfileId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.reloadBackendSnapshot(feedback: "训练状态已刷新。")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
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

    @objc private func deleteVoiceTapped() {
        confirmDestructive(
            title: "删除音色",
            message: "删除会清理后端样本、训练产物和本地 voiceProfileId。此操作不可恢复。",
            actionTitle: "删除"
        ) { [weak self] in
            self?.performDeleteVoice()
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let audioURL = urls.first else { return }
        let didAccess = audioURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                audioURL.stopAccessingSecurityScopedResource()
            }
        }

        setBusyFeedback("已选择音频样本，正在提交后端训练...")
        VoiceCloneService.shared.trainVoice(
            audioURL: audioURL,
            authorizationConfirmed: authorizationSwitch.isOn,
            onProfileAccepted: { [weak self] snapshot in
                DispatchQueue.main.async {
                    self?.applySnapshot(snapshot, feedback: "后端已接收声音样本，训练中；可稍后刷新状态。")
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let profileId):
                    self.reloadBackendSnapshot(feedback: "音色训练已完成：\(profileId)")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        feedbackLabel?.text = "已取消选择音频样本。"
    }

    private func performDisableVoice() {
        guard hasVoiceProfile else {
            feedbackLabel?.text = "还没有可禁用的 voiceProfileId。"
            return
        }
        setBusyFeedback("正在禁用音色...")
        VoiceCloneService.shared.disableVoiceProfileRemote(profileId: snapshot.voiceProfileId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let snapshot):
                    self.applySnapshot(snapshot, feedback: "音色已禁用。")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func performDeleteVoice() {
        guard hasVoiceProfile else {
            feedbackLabel?.text = "还没有可删除的 voiceProfileId。"
            return
        }
        setBusyFeedback("正在删除音色...")
        VoiceCloneService.shared.deleteVoiceProfileRemote(profileId: snapshot.voiceProfileId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let snapshot):
                    self.applySnapshot(snapshot, feedback: "音色已删除。")
                case .failure(let error):
                    self.finishBusy(feedback: error.localizedDescription)
                }
            }
        }
    }

    private func reloadBackendSnapshot(feedback: String) {
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured,
              let userId = UserManager.shared.currentUser?.id else {
            finishBusy(feedback: "后端语音服务尚未配置，无法刷新音色状态。")
            return
        }

        DreamJourneyBackendClient.shared.fetchVoiceCloneProfiles(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let profiles):
                    let currentProfileId = self.snapshot.voiceProfileId
                    let selectedProfile = profiles.first(where: { $0.voiceProfileId == currentProfileId })
                        ?? profiles.first(where: { $0.sampleStatus != .deleted })
                        ?? profiles.first
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

    private func applySnapshot(_ snapshot: VoiceCloneProfileSnapshot, feedback: String? = nil) {
        self.snapshot = snapshot
        sampleStatusValueLabel?.text = snapshot.sampleStatus.displayText
        profileIdValueLabel?.text = snapshot.voiceProfileId
        providerModeValueLabel?.text = snapshot.providerMode
        contractVersionValueLabel?.text = "\(snapshot.contractVersion)"
        entryStatusValueLabel?.text = "公开可见，需授权训练"
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

    private func updateActionAvailability() {
        submitButton?.isEnabled = !isBusy && authorizationSwitch.isOn
        refreshButton?.isEnabled = !isBusy && hasVoiceProfile && snapshot.sampleStatus != .deleted && snapshot.sampleStatus != .disabled
        disableButton?.isEnabled = !isBusy && hasVoiceProfile && snapshot.sampleStatus != .disabled && snapshot.sampleStatus != .deleted
        deleteButton?.isEnabled = !isBusy && hasVoiceProfile && snapshot.sampleStatus != .deleted
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
