import UIKit

final class ProfilePasswordChangeViewController: UIViewController {
    private enum Mode: Int {
        case change = 0
        case setup = 1
    }

    private enum PasswordState {
        case idle
        case requestingCode
        case awaitingCode
        case reauthenticating
        case saving
        case saved(String)
        case invalid(String)
        case locked(String)
        case failed(String)
    }

    private let capability: BackendPasswordAuthenticationCapability
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let modeControl = UISegmentedControl(items: ["修改密码", "设置密码"])
    private let formStack = UIStackView()
    private let currentPasswordField = UITextField()
    private let verificationField = UITextField()
    private let newPasswordField = UITextField()
    private let confirmPasswordField = UITextField()
    private let requestCodeButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private var currentPasswordRow = UIView()
    private var verificationRow = UIView()

    private var mode: Mode
    private var pendingChallenge: BackendIdentityChallengeContract?
    private var reauthToken: BackendPasswordActionTokenContract?
    private var isBusy = false

    init(capability: BackendPasswordAuthenticationCapability) {
        self.capability = capability
        mode = capability.canChangePassword ? .change : .setup
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "密码与安全"
        view.backgroundColor = DJDesignTokens.Color.background
        configureScrollView()
        buildContent()
        configureFields()
        applyMode(animated: false)
        renderState(.idle)
        hideKeyboardWhenTapped()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: DJDesignTokens.Color.textPrimary,
            .font: DJDesignTokens.Font.title(18),
        ]
    }

    private func configureScrollView() {
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

    private func buildContent() {
        modeControl.selectedSegmentIndex = mode.rawValue
        modeControl.selectedSegmentTintColor = DJDesignTokens.Color.surface
        modeControl.setEnabled(capability.canChangePassword, forSegmentAt: Mode.change.rawValue)
        modeControl.setEnabled(capability.canSetupPassword, forSegmentAt: Mode.setup.rawValue)
        modeControl.isHidden = !(capability.canChangePassword && capability.canSetupPassword)
        modeControl.accessibilityIdentifier = "profile-password-mode"
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        let explanation = UILabel()
        explanation.text = "修改密码需要当前密码；首次设置密码需使用手机号验证码再次确认身份。"
        explanation.font = DJDesignTokens.Font.body(13)
        explanation.textColor = DJDesignTokens.Color.textSecondary
        explanation.numberOfLines = 0

        contentStack.addArrangedSubview(modeControl)
        contentStack.addArrangedSubview(explanation)
        contentStack.addArrangedSubview(makeFormCard())
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(saveButton)

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "profile-password-status"

        saveButton.setTitle("保存新密码", for: .normal)
        saveButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = DJDesignTokens.Color.accent
        saveButton.layer.cornerRadius = 22
        saveButton.accessibilityIdentifier = "profile-password-save-button"
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    private func configureFields() {
        [currentPasswordField, newPasswordField, confirmPasswordField].forEach {
            $0.isSecureTextEntry = true
            $0.clearButtonMode = .whileEditing
            $0.returnKeyType = .done
            $0.delegate = self
            $0.addTarget(self, action: #selector(passwordFieldDidChange), for: .editingChanged)
        }
        currentPasswordField.textContentType = .password
        newPasswordField.textContentType = .newPassword
        confirmPasswordField.textContentType = .newPassword
        currentPasswordField.accessibilityIdentifier = "profile-password-current-field"
        newPasswordField.accessibilityIdentifier = "profile-password-new-field"
        confirmPasswordField.accessibilityIdentifier = "profile-password-confirm-field"

        verificationField.keyboardType = .numberPad
        verificationField.textContentType = .oneTimeCode
        verificationField.returnKeyType = .done
        verificationField.delegate = self
        verificationField.accessibilityIdentifier = "profile-password-verification-field"
        verificationField.addTarget(self, action: #selector(verificationFieldDidChange), for: .editingChanged)

        requestCodeButton.setTitle("获取验证码", for: .normal)
        requestCodeButton.titleLabel?.font = DJDesignTokens.Font.label(13)
        requestCodeButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        requestCodeButton.accessibilityIdentifier = "profile-password-request-code"
        requestCodeButton.addTarget(self, action: #selector(requestCodeTapped), for: .touchUpInside)
    }

    private func makeFormCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        currentPasswordRow = makeInputRow(title: "当前密码", textField: currentPasswordField)
        verificationRow = makeCodeRow()
        formStack.axis = .vertical
        formStack.spacing = 0
        [
            currentPasswordRow,
            makeDivider(),
            verificationRow,
            makeDivider(),
            makeInputRow(title: "新密码", textField: newPasswordField),
            makeDivider(),
            makeInputRow(title: "确认新密码", textField: confirmPasswordField),
        ].forEach(formStack.addArrangedSubview)

        card.addSubview(formStack)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: card.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            formStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makeInputRow(title: String, textField: UITextField) -> UIView {
        let row = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.body(15)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        textField.font = DJDesignTokens.Font.body(15)
        textField.textColor = DJDesignTokens.Color.textPrimary
        textField.textAlignment = .right

        row.addSubview(titleLabel)
        row.addSubview(textField)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: textField.leadingAnchor, constant: -12),
            textField.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
        return row
    }

    private func makeCodeRow() -> UIView {
        let row = UIView()
        let titleLabel = UILabel()
        titleLabel.text = "手机号验证"
        titleLabel.font = DJDesignTokens.Font.body(15)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        verificationField.font = DJDesignTokens.Font.body(15)
        verificationField.textColor = DJDesignTokens.Color.textPrimary
        verificationField.textAlignment = .right

        let rightStack = UIStackView(arrangedSubviews: [verificationField, requestCodeButton])
        rightStack.axis = .horizontal
        rightStack.spacing = 10
        row.addSubview(titleLabel)
        row.addSubview(rightStack)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            rightStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            verificationField.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])
        return row
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.45)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return divider
    }

    @objc private func modeChanged() {
        guard let selected = Mode(rawValue: modeControl.selectedSegmentIndex) else { return }
        mode = selected
        pendingChallenge = nil
        reauthToken = nil
        verificationField.text = nil
        applyMode(animated: true)
        renderState(.idle)
    }

    private func applyMode(animated: Bool) {
        let updates = {
            self.currentPasswordRow.isHidden = self.mode != .change
            self.verificationRow.isHidden = self.mode != .setup
            self.saveButton.setTitle(self.mode == .change ? "保存新密码" : "验证并设置密码", for: .normal)
        }
        if animated {
            UIView.transition(
                with: formStack,
                duration: 0.2,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: updates
            )
        } else {
            updates()
        }
    }

    @objc private func requestCodeTapped() {
        guard !isBusy, mode == .setup, capability.canSetupPassword else {
            renderState(.failed("当前环境暂不支持设置密码。"))
            return
        }
        guard let phone = UserManager.shared.currentUser?.phone, phone.count == 11 else {
            renderState(.failed("当前账号没有可验证的手机号。"))
            return
        }
        setBusy(true)
        renderState(.requestingCode)
        DreamJourneyBackendClient.shared.createIdentityChallenge(
            phone: phone,
            purpose: BackendPasswordAction.sensitiveOperation.rawValue
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success(let challenge):
                self.pendingChallenge = challenge
                self.reauthToken = nil
                self.renderState(.awaitingCode)
                self.verificationField.becomeFirstResponder()
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    @objc private func saveTapped() {
        [currentPasswordField, verificationField, newPasswordField, confirmPasswordField].forEach {
            $0.resignFirstResponder()
        }
        guard !isBusy, capability.canManagePassword else {
            renderState(.failed("当前环境暂不支持密码管理。"))
            return
        }
        let newPassword = newPasswordField.text ?? ""
        let confirmation = confirmPasswordField.text ?? ""
        guard newPassword.count >= capability.minimumPasswordLength,
              newPassword.count <= capability.maximumPasswordLength else {
            renderState(.invalid("新密码需为 \(capability.minimumPasswordLength) 至 \(capability.maximumPasswordLength) 位。"))
            return
        }
        guard confirmation == newPassword else {
            renderState(.invalid("确认新密码必须一致。"))
            return
        }
        switch mode {
        case .change:
            let currentPassword = currentPasswordField.text ?? ""
            guard !currentPassword.isEmpty else {
                renderState(.invalid("当前密码不能为空。"))
                return
            }
            submitPasswordChange(currentPassword: currentPassword, newPassword: newPassword)
        case .setup:
            submitPasswordSetup(newPassword: newPassword)
        }
    }

    private func submitPasswordChange(currentPassword: String, newPassword: String) {
        guard capability.canChangePassword else {
            renderState(.failed("当前环境暂不支持修改密码。"))
            return
        }
        setBusy(true)
        renderState(.saving)
        DreamJourneyBackendClient.shared.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success:
                self.clearFields()
                self.renderState(.saved("密码已更新"))
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    private func submitPasswordSetup(newPassword: String) {
        guard capability.canSetupPassword else {
            renderState(.failed("当前环境暂不支持设置密码。"))
            return
        }
        if let reauthToken, !reauthToken.isExpired {
            performPasswordSetup(newPassword: newPassword, token: reauthToken)
            return
        }
        let code = (verificationField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            renderState(.invalid("请输入验证码。"))
            return
        }
        guard let challenge = pendingChallenge,
              !challenge.isExpired(),
              challenge.purpose == BackendPasswordAction.sensitiveOperation.rawValue else {
            renderState(.invalid("请先获取新的验证码。"))
            return
        }
        setBusy(true)
        renderState(.reauthenticating)
        DreamJourneyBackendClient.shared.verifyIdentityChallengeAction(
            challengeId: challenge.challengeId,
            verificationCode: code,
            expectedAction: .sensitiveOperation
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success(let token):
                self.reauthToken = token
                self.performPasswordSetup(newPassword: newPassword, token: token)
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    private func performPasswordSetup(
        newPassword: String,
        token: BackendPasswordActionTokenContract
    ) {
        guard !token.isExpired else {
            reauthToken = nil
            renderState(.invalid("本次身份验证已过期，请重新获取验证码。"))
            return
        }
        setBusy(true)
        renderState(.saving)
        DreamJourneyBackendClient.shared.setupPassword(
            newPassword: newPassword,
            reauthToken: token.actionToken
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            self.reauthToken = nil
            switch result {
            case .success:
                self.clearFields()
                self.renderState(.saved("密码已设置"))
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    private func renderFailure(_ error: Error) {
        let context = (error as? DreamJourneyBackendClient.ClientError)?.backendErrorContext
        switch BackendPasswordFailureState.resolve(
            code: context?.code,
            retryAfterSeconds: context?.retryAfterSeconds,
            message: context?.detail ?? error.localizedDescription
        ) {
        case .locked(let message, let retryAfter):
            let suffix = retryAfter.map { "请在 \($0) 秒后重试。" } ?? "请稍后重试。"
            renderState(.locked("\(message) \(suffix)"))
        case .reauthenticationRequired(let message):
            reauthToken = nil
            renderState(.failed("身份验证已失效：\(message)"))
        case .invalidCredentials:
            renderState(.failed("当前密码不正确。"))
        case .unavailable(let message), .failed(let message):
            renderState(.failed(message))
        }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        modeControl.isEnabled = !busy
        [currentPasswordField, verificationField, newPasswordField, confirmPasswordField].forEach {
            $0.isEnabled = !busy
        }
        requestCodeButton.isEnabled = !busy
        saveButton.isEnabled = !busy
        saveButton.alpha = busy ? 0.68 : 1
    }

    private func clearFields() {
        currentPasswordField.text = nil
        verificationField.text = nil
        newPasswordField.text = nil
        confirmPasswordField.text = nil
        pendingChallenge = nil
        reauthToken = nil
    }

    private func renderState(_ state: PasswordState) {
        statusLabel.isHidden = false
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        switch state {
        case .idle:
            statusLabel.text = mode == .change ? "输入当前密码后更新" : "获取验证码完成再认证"
        case .requestingCode:
            statusLabel.text = "正在发送验证码..."
        case .awaitingCode:
            statusLabel.text = "验证码已受理，请完成身份验证。"
        case .reauthenticating:
            statusLabel.text = "正在重新验证身份..."
        case .saving:
            statusLabel.text = "提交中..."
        case .saved(let message):
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.accentDeep
        case .invalid(let message):
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .locked(let message):
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .failed(let message):
            statusLabel.text = "操作失败：\(message)"
            statusLabel.textColor = DJDesignTokens.Color.danger
        }
    }

    @objc private func passwordFieldDidChange() {
        renderState(.idle)
    }

    @objc private func verificationFieldDidChange() {
        reauthToken = nil
        renderState(.idle)
    }
}

extension ProfilePasswordChangeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
