import UIKit

final class PasswordResetViewController: UIViewController {
    private enum ResetState {
        case idle
        case requestingCode
        case awaitingCode
        case reauthenticating
        case resetting
        case completed
        case invalid(String)
        case locked(String)
        case failed(String)
    }

    private let capability: BackendPasswordAuthenticationCapability
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let phoneField = UITextField()
    private let verificationField = UITextField()
    private let newPasswordField = UITextField()
    private let confirmPasswordField = UITextField()
    private let requestCodeButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var rawPhone = ""
    private var pendingChallenge: BackendIdentityChallengeContract?
    private var pendingPhone: String?
    private var resetToken: BackendPasswordActionTokenContract?
    private var isBusy = false
    private var didComplete = false

    init(capability: BackendPasswordAuthenticationCapability) {
        self.capability = capability
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "重置密码"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        configureLayout()
        configureFields()
        render(.idle)
        hideKeyboardWhenTapped()
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

        let introLabel = UILabel()
        introLabel.text = "通过手机号验证身份后设置新密码。验证码只用于本次重置。"
        introLabel.font = DJDesignTokens.Font.body(14)
        introLabel.textColor = DJDesignTokens.Color.textSecondary
        introLabel.numberOfLines = 0

        contentStack.addArrangedSubview(introLabel)
        contentStack.addArrangedSubview(makeFormCard())
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(resetButton)

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "auth.passwordReset.status"

        resetButton.setTitle("确认重置", for: .normal)
        resetButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = DJDesignTokens.Color.accent
        resetButton.layer.cornerRadius = 22
        resetButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        resetButton.accessibilityIdentifier = "auth.passwordReset.submit"
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

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

    private func configureFields() {
        phoneField.keyboardType = .numberPad
        phoneField.textContentType = .telephoneNumber
        phoneField.accessibilityIdentifier = "auth.passwordReset.phone"
        phoneField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)

        verificationField.keyboardType = .numberPad
        verificationField.textContentType = .oneTimeCode
        verificationField.accessibilityIdentifier = "auth.passwordReset.code"
        verificationField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)

        [newPasswordField, confirmPasswordField].forEach {
            $0.isSecureTextEntry = true
            $0.textContentType = .newPassword
            $0.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        }
        newPasswordField.accessibilityIdentifier = "auth.passwordReset.newPassword"
        confirmPasswordField.accessibilityIdentifier = "auth.passwordReset.confirmPassword"

        requestCodeButton.setTitle("获取验证码", for: .normal)
        requestCodeButton.titleLabel?.font = DJDesignTokens.Font.label(13)
        requestCodeButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        requestCodeButton.accessibilityIdentifier = "auth.passwordReset.requestCode"
        requestCodeButton.addTarget(self, action: #selector(requestCodeTapped), for: .touchUpInside)
    }

    private func makeFormCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let stack = UIStackView(arrangedSubviews: [
            makeInputRow(title: "手机号", textField: phoneField),
            makeDivider(),
            makeCodeRow(),
            makeDivider(),
            makeInputRow(title: "新密码", textField: newPasswordField),
            makeDivider(),
            makeInputRow(title: "确认新密码", textField: confirmPasswordField),
        ])
        stack.axis = .vertical
        stack.spacing = 0
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makeInputRow(title: String, textField: UITextField) -> UIView {
        let row = UIView()
        let label = UILabel()
        label.text = title
        label.font = DJDesignTokens.Font.body(15)
        label.textColor = DJDesignTokens.Color.textPrimary
        textField.font = DJDesignTokens.Font.body(15)
        textField.textColor = DJDesignTokens.Color.textPrimary
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing

        row.addSubview(label)
        row.addSubview(textField)
        label.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: textField.leadingAnchor, constant: -12),
            textField.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 156),
        ])
        return row
    }

    private func makeCodeRow() -> UIView {
        let row = UIView()
        let label = UILabel()
        label.text = "验证码"
        label.font = DJDesignTokens.Font.body(15)
        label.textColor = DJDesignTokens.Color.textPrimary
        verificationField.font = DJDesignTokens.Font.body(15)
        verificationField.textColor = DJDesignTokens.Color.textPrimary
        verificationField.textAlignment = .right

        let rightStack = UIStackView(arrangedSubviews: [verificationField, requestCodeButton])
        rightStack.axis = .horizontal
        rightStack.spacing = 10
        row.addSubview(label)
        row.addSubview(rightStack)
        label.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            rightStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
            verificationField.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])
        return row
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.45)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return divider
    }

    @objc private func phoneChanged() {
        let digits = (phoneField.text ?? "").filter(\.isNumber)
        rawPhone = String(digits.prefix(11))
        phoneField.text = rawPhone
        if pendingPhone != nil, pendingPhone != rawPhone {
            pendingChallenge = nil
            pendingPhone = nil
            resetToken = nil
        }
        render(.idle)
    }

    @objc private func fieldChanged() {
        resetToken = nil
        render(.idle)
    }

    @objc private func requestCodeTapped() {
        guard !isBusy, capability.canResetPassword else {
            render(.failed("当前环境暂不支持密码重置。"))
            return
        }
        guard rawPhone.count == 11 else {
            render(.invalid("请输入 11 位手机号。"))
            return
        }
        setBusy(true)
        render(.requestingCode)
        DreamJourneyBackendClient.shared.createIdentityChallenge(
            phone: rawPhone,
            purpose: BackendPasswordAction.passwordReset.rawValue
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success(let challenge):
                self.pendingChallenge = challenge
                self.pendingPhone = self.rawPhone
                self.resetToken = nil
                self.render(.awaitingCode)
                self.verificationField.becomeFirstResponder()
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    @objc private func resetTapped() {
        if didComplete {
            dismiss(animated: true)
            return
        }
        guard !isBusy, capability.canResetPassword else {
            render(.failed("当前环境暂不支持密码重置。"))
            return
        }
        let code = (verificationField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = newPasswordField.text ?? ""
        let confirmation = confirmPasswordField.text ?? ""
        guard rawPhone.count == 11 else {
            render(.invalid("请输入 11 位手机号。"))
            return
        }
        guard !code.isEmpty else {
            render(.invalid("请输入验证码。"))
            return
        }
        guard newPassword.count >= capability.minimumPasswordLength,
              newPassword.count <= capability.maximumPasswordLength else {
            render(.invalid("新密码需为 \(capability.minimumPasswordLength) 至 \(capability.maximumPasswordLength) 位。"))
            return
        }
        guard newPassword == confirmation else {
            render(.invalid("确认新密码必须一致。"))
            return
        }
        if let resetToken, !resetToken.isExpired {
            submitReset(token: resetToken, newPassword: newPassword)
            return
        }
        guard let challenge = pendingChallenge,
              pendingPhone == rawPhone,
              !challenge.isExpired(),
              challenge.purpose == BackendPasswordAction.passwordReset.rawValue else {
            render(.invalid("请先获取新的验证码。"))
            return
        }
        setBusy(true)
        render(.reauthenticating)
        DreamJourneyBackendClient.shared.verifyIdentityChallengeAction(
            challengeId: challenge.challengeId,
            verificationCode: code,
            expectedAction: .passwordReset
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success(let token):
                self.resetToken = token
                self.submitReset(token: token, newPassword: newPassword)
            case .failure(let error):
                self.renderFailure(error)
            }
        }
    }

    private func submitReset(token: BackendPasswordActionTokenContract, newPassword: String) {
        guard !token.isExpired else {
            resetToken = nil
            render(.invalid("本次验证已过期，请重新获取验证码。"))
            return
        }
        setBusy(true)
        render(.resetting)
        DreamJourneyBackendClient.shared.resetPassword(
            resetToken: token.actionToken,
            newPassword: newPassword
        ) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            self.resetToken = nil
            switch result {
            case .success:
                self.didComplete = true
                self.render(.completed)
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
            render(.locked("\(message) \(suffix)"))
        case .reauthenticationRequired(let message),
             .invalidCredentials(let message),
             .unavailable(let message),
             .failed(let message):
            render(.failed(message))
        }
    }

    private func setBusy(_ value: Bool) {
        isBusy = value
        [phoneField, verificationField, newPasswordField, confirmPasswordField].forEach {
            $0.isEnabled = !value
        }
        requestCodeButton.isEnabled = !value
        resetButton.isEnabled = !value
        resetButton.alpha = value ? 0.68 : 1
    }

    private func render(_ state: ResetState) {
        statusLabel.isHidden = false
        statusLabel.textColor = DJDesignTokens.Color.textSecondary
        resetButton.setTitle(didComplete ? "完成" : "确认重置", for: .normal)
        switch state {
        case .idle:
            statusLabel.text = capability.canResetPassword ? "验证手机号后重置密码" : "密码重置暂不可用"
        case .requestingCode:
            statusLabel.text = "正在发送验证码..."
        case .awaitingCode:
            statusLabel.text = "验证码已受理，请完成验证。"
        case .reauthenticating:
            statusLabel.text = "正在验证身份..."
        case .resetting:
            statusLabel.text = "正在重置密码..."
        case .completed:
            statusLabel.text = "密码已重置，请使用新密码登录。"
            statusLabel.textColor = DJDesignTokens.Color.accentDeep
        case .invalid(let message):
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .locked(let message):
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .failed(let message):
            statusLabel.text = "重置失败：\(message)"
            statusLabel.textColor = DJDesignTokens.Color.danger
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
