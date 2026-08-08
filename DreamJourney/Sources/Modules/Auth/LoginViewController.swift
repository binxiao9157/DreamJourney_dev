import UIKit

// MARK: - LoginViewController
final class LoginViewController: UIViewController {

    var didLogin: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: "寻梦环游",
            attributes: [
                .kern: 4.0,
                .font: DJDesignTokens.Font.display(40),
                .foregroundColor: DJDesignTokens.Color.accentDeep,
            ]
        )
        label.font = DJDesignTokens.Font.display(40)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "在时空中，留下你的身影"
        label.font = DJDesignTokens.Font.body(16)
        label.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.62)
        label.textAlignment = .center
        return label
    }()

    private let phoneFieldContainer = UIView()
    private let phoneIcon = UIImageView(image: UIImage(systemName: "iphone"))
    private let phoneField: UITextField = {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: "手机号",
            attributes: [.foregroundColor: DJDesignTokens.Color.textSecondary.withAlphaComponent(0.42)]
        )
        field.font = DJDesignTokens.Font.body(16)
        field.textColor = DJDesignTokens.Color.textPrimary
        field.keyboardType = .numberPad
        field.returnKeyType = .next
        field.borderStyle = .none
        return field
    }()

    private lazy var loginButton: UIButton = {
        let button = DJComponentFactory.primaryButton(title: "登录", target: self, action: #selector(loginTapped))
        button.titleLabel?.font = DJDesignTokens.Font.label(16)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.layer.cornerRadius = 28.5
        button.layer.shadowColor = DJDesignTokens.Color.accent.cgColor
        button.layer.shadowOpacity = 0.22
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 24
        return button
    }()

    private let registerPrefixLabel: UILabel = {
        let label = UILabel()
        label.text = "还没有账号？"
        label.font = DJDesignTokens.Font.body(16)
        label.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.62)
        return label
    }()

    private lazy var registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即注册", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(16)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        return button
    }()

    private var rawPhone = ""
    private var isLoginInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        setupActions()
        hideKeyboardWhenTapped()
    }

    private func setupLayout() {
        configureFieldContainer(phoneFieldContainer, icon: phoneIcon, textField: phoneField)

        let registerStack = UIStackView(arrangedSubviews: [registerPrefixLabel, registerButton])
        registerStack.axis = .horizontal
        registerStack.alignment = .center
        registerStack.spacing = 4

        [
            titleLabel,
            subtitleLabel,
            phoneFieldContainer,
            loginButton,
            registerStack,
        ].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            phoneFieldContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 64),
            phoneFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            phoneFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            phoneFieldContainer.heightAnchor.constraint(equalToConstant: 56),

            loginButton.topAnchor.constraint(equalTo: phoneFieldContainer.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 57),

            registerStack.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 28),
            registerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func configureFieldContainer(_ container: UIView, icon: UIImageView, textField: UITextField) {
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer
        container.layer.cornerRadius = 28
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.clear.cgColor

        icon.tintColor = DJDesignTokens.Color.textTertiary
        icon.contentMode = .scaleAspectFit

        container.addSubview(icon)
        container.addSubview(textField)
        icon.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            textField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: container.topAnchor),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func setupActions() {
        phoneField.delegate = self
        phoneField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
    }

    @objc private func phoneChanged() {
        guard let text = phoneField.text else { return }
        let digits = text.filter { $0.isNumber }
        rawPhone = String(digits.prefix(11))

        var formatted = ""
        for (index, character) in rawPhone.enumerated() {
            if index == 3 || index == 7 {
                formatted += " "
            }
            formatted.append(character)
        }
        phoneField.text = formatted

        loginButton.isEnabled = true
    }

    @objc private func registerTapped() {
        let alert = UIAlertController(
            title: "手机号验证",
            message: "输入手机号并完成验证码验证后，将自动创建账号。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func loginTapped() {
        guard !isLoginInProgress else { return }
        guard rawPhone.count == 11 else {
            showLoginAlert(title: "手机号不完整", message: "请输入 11 位手机号。")
            phoneField.becomeFirstResponder()
            return
        }

        guard DreamJourneyBackendClient.shared.isLoginSyncConfigured else {
            showLoginAlert(
                title: "登录服务暂不可用",
                message: "当前无法验证你的身份，请检查网络后重试。"
            )
            return
        }

        let submittedPhone = rawPhone
        setLoginInProgress(true)
        DreamJourneyBackendClient.shared.fetchRuntimeConfig { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let runtime):
                let identityChallenge = runtime.identityChallenge
                guard identityChallenge.canStartClientFlow else {
                    self.setLoginInProgress(false)
                    self.showLoginAlert(
                        title: "身份验证暂不可用",
                        message: "当前无法安全验证手机号，请稍后重试。"
                    )
                    return
                }
                self.beginIdentityChallengeLogin(
                    phone: submittedPhone,
                    capability: identityChallenge
                )
            case .failure(let error):
                self.setLoginInProgress(false)
                self.showLoginAlert(title: "登录失败", message: error.localizedDescription)
            }
        }
    }

    private func beginIdentityChallengeLogin(
        phone: String,
        capability: BackendIdentityChallengeCapability
    ) {
        DreamJourneyBackendClient.shared.createIdentityChallenge(phone: phone) { [weak self] result in
            guard let self else { return }
            self.setLoginInProgress(false)
            switch result {
            case .success(let challenge):
                self.presentIdentityVerification(
                    challenge: challenge,
                    phone: phone,
                    capability: capability
                )
            case .failure(let error):
                self.showLoginAlert(
                    title: "身份验证失败",
                    message: self.identityChallengeFailureMessage(error)
                )
            }
        }
    }

    private func presentIdentityVerification(
        challenge: BackendIdentityChallengeContract,
        phone: String,
        capability: BackendIdentityChallengeCapability
    ) {
        guard !challenge.isExpired() else {
            showLoginAlert(title: "验证已过期", message: "请重新发起身份验证。")
            return
        }
        let verificationMessage: String
        if capability.providerMode == "synthetic" {
            verificationMessage = "请输入测试环境验证码完成身份验证。"
        } else {
            switch challenge.deliveryState {
            case .delivered:
                verificationMessage = "验证码已送达，请输入验证码完成身份验证。"
            case .accepted:
                verificationMessage = challenge.recoveryState == .available
                    ? "验证码请求已受理；若暂未收到，请稍后重试。"
                    : "验证码请求已受理，请输入验证码完成身份验证。"
            case .unknown:
                verificationMessage = "验证码送达状态暂未确认，请稍后查看。"
            case .undeliverable:
                showLoginAlert(
                    title: "验证码未送达",
                    message: "本次验证无法继续，请稍后重新发起。"
                )
                return
            }
        }
        let alert = UIAlertController(
            title: "验证手机号",
            message: verificationMessage,
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "验证码"
            textField.keyboardType = .numberPad
            textField.textContentType = .oneTimeCode
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "验证", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let verificationCode = alert?.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !verificationCode.isEmpty else {
                self.showLoginAlert(title: "验证码不能为空", message: "请重新发起验证。")
                return
            }
            self.setLoginInProgress(true)
            DreamJourneyBackendClient.shared.verifyIdentityChallenge(
                challengeId: challenge.challengeId,
                verificationCode: verificationCode,
                nickname: ""
            ) { [weak self] result in
                guard let self else { return }
                self.setLoginInProgress(false)
                switch result {
                case .success(let response):
                    self.handleBackendLoginSuccess(response, phone: phone)
                case .failure(let error):
                    let retry: (() -> Void)?
                    if challenge.isExpired() {
                        retry = nil
                    } else {
                        retry = { [weak self] in
                            guard let self else { return }
                            self.presentIdentityVerification(
                                challenge: challenge,
                                phone: phone,
                                capability: capability
                            )
                        }
                    }
                    self.showLoginAlert(
                        title: "身份验证失败",
                        message: error.localizedDescription,
                        actionTitle: retry == nil ? "知道了" : "重新输入",
                        action: retry
                    )
                }
            }
        })
        present(alert, animated: true)
    }

    private func identityChallengeFailureMessage(_ error: Error) -> String {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              let context = clientError.backendErrorContext,
              context.code == "identity_challenge_rate_limited",
              let retryAfterSeconds = context.retryAfterSeconds,
              retryAfterSeconds > 0 else {
            return error.localizedDescription
        }
        return "请求过于频繁，请在 \(retryAfterSeconds) 秒后重试。"
    }

    private func handleBackendLoginSuccess(_ response: [String: Any], phone: String) {
        guard let user = response["user"] as? [String: Any] else {
            showLoginAlert(title: "登录失败", message: "后端返回的用户数据不可用。")
            return
        }
        guard let userId = user["id"] as? String,
              !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showLoginAlert(title: "登录失败", message: "后端返回的用户身份不可用。")
            return
        }
        let nickname = (user["nickname"] as? String) ?? ""
        guard UserManager.shared.loginVerifiedAccount(
            phone: phone,
            nickname: nickname,
            userId: userId
        ) else {
            showLoginAlert(title: "登录失败", message: "登录会话已失效，请重新验证手机号。")
            return
        }
        didLogin?()
    }

    private func setLoginInProgress(_ inProgress: Bool) {
        isLoginInProgress = inProgress
        loginButton.isEnabled = !inProgress
        phoneField.isEnabled = !inProgress
        registerButton.isEnabled = !inProgress
        loginButton.setTitle(inProgress ? "登录中..." : "登录", for: .normal)
    }

    private func showLoginAlert(
        title: String,
        message: String,
        actionTitle: String = "知道了",
        action: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
            action?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
