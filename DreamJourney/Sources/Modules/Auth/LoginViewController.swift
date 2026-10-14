import UIKit

// MARK: - LoginViewController
final class LoginViewController: UIViewController {

    private enum AuthMode: Equatable {
        case login
        case register
    }

    private enum CredentialMode: Int, Equatable {
        case password = 0
        case verificationCode = 1
    }

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

    private let credentialModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["密码", "验证码"])
        control.selectedSegmentIndex = CredentialMode.verificationCode.rawValue
        control.selectedSegmentTintColor = DJDesignTokens.Color.surface
        control.setTitleTextAttributes([
            .font: DJDesignTokens.Font.label(14),
            .foregroundColor: DJDesignTokens.Color.textPrimary,
        ], for: .normal)
        control.accessibilityIdentifier = "auth.credentialMode"
        return control
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

    private let verificationFieldContainer = UIView()
    private let verificationIcon = UIImageView(image: UIImage(systemName: "number.square"))
    private let verificationField: UITextField = {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: "验证码",
            attributes: [.foregroundColor: DJDesignTokens.Color.textSecondary.withAlphaComponent(0.42)]
        )
        field.font = DJDesignTokens.Font.body(16)
        field.textColor = DJDesignTokens.Color.textPrimary
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.returnKeyType = .done
        field.borderStyle = .none
        return field
    }()

    private let passwordFieldContainer = UIView()
    private let passwordIcon = UIImageView(image: UIImage(systemName: "lock"))
    private let passwordField: UITextField = {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: "密码",
            attributes: [.foregroundColor: DJDesignTokens.Color.textSecondary.withAlphaComponent(0.42)]
        )
        field.font = DJDesignTokens.Font.body(16)
        field.textColor = DJDesignTokens.Color.textPrimary
        field.isSecureTextEntry = true
        field.textContentType = .password
        field.returnKeyType = .done
        field.borderStyle = .none
        return field
    }()

    private lazy var requestCodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("获取验证码", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(14)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.addTarget(self, action: #selector(requestVerificationCodeTapped), for: .touchUpInside)
        return button
    }()

    private let verificationHintLabel: UILabel = {
        let label = UILabel()
        label.text = "输入手机号后获取验证码"
        label.font = DJDesignTokens.Font.body(13)
        label.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.7)
        label.numberOfLines = 0
        return label
    }()

    private lazy var forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("忘记密码", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "auth.forgotPassword"
        return button
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

    private let loginScrollView = UIScrollView()
    private let loginContentView = UIView()
    private let legalDocumentLinks = UIStackView()
    private var hasAcceptedLegal = false
    private lazy var legalConsentButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = DJDesignTokens.Color.accentDeep
        button.accessibilityIdentifier = "auth.legalConsent"
        button.accessibilityLabel = "同意使用说明和免责说明，并知悉隐私说明"
        button.addTarget(self, action: #selector(toggleLegalConsent), for: .touchUpInside)
        return button
    }()
    private let capabilityLoader: (@escaping (Result<BackendRuntimeConfig, Error>) -> Void) -> Void

    init(capabilityLoader: @escaping (@escaping (Result<BackendRuntimeConfig, Error>) -> Void) -> Void = {
        DreamJourneyBackendClient.shared.fetchRuntimeConfig(completion: $0)
    }) {
        self.capabilityLoader = capabilityLoader
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var rawPhone = ""
    private var authMode: AuthMode = .login
    private var credentialMode: CredentialMode = .verificationCode
    private var passwordAuthentication = BackendPasswordAuthenticationCapability(json: nil)
    private var pendingChallenge: BackendIdentityChallengeContract?
    private var pendingPhone: String?
    private var isChallengeRequestInProgress = false
    private var isLoginInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        setupActions()
        applyAuthMode(animated: false)
        applyCredentialMode(animated: false)
        updateControls()
        loadAuthenticationCapabilities()
        hideKeyboardWhenTapped()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        legalDocumentLinks.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    @objc private func toggleLegalConsent() {
        guard !isLoginInProgress, !isChallengeRequestInProgress else { return }
        hasAcceptedLegal.toggle()
        updateControls()
    }

    /// All credential request paths, including auto-submit continuations, require explicit consent.
    private func requireLegalConsent() -> Bool {
        guard hasAcceptedLegal else {
            showLoginAlert(title: "请先阅读并勾选", message: "登录前请阅读并同意使用说明和免责说明，并了解隐私说明。")
            return false
        }
        return true
    }

    private func makeLegalControls() -> UIView {
        let explanation = UILabel()
        explanation.text = "我已阅读并同意使用说明、免责说明，并知悉隐私说明"
        explanation.font = .preferredFont(forTextStyle: .footnote)
        explanation.adjustsFontForContentSizeCategory = true
        explanation.textColor = DJDesignTokens.Color.textSecondary
        explanation.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [legalConsentButton, explanation])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 4
        legalConsentButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        legalConsentButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let links = UIStackView()
        links.axis = .vertical
        links.alignment = .leading
        let documentLinks = legalDocumentLinks
        documentLinks.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        documentLinks.alignment = .leading
        documentLinks.spacing = 6
        links.addArrangedSubview(documentLinks)
        for document in [AppLegalDocument.usage, .disclaimer, .privacy] {
            let button = UIButton(type: .system)
            button.setTitle("《\(document.title)》", for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.tintColor = DJDesignTokens.Color.accentDeep
            button.accessibilityIdentifier = "auth.legal.\(document.rawValue)"
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.presentLegal(document: document) }, for: .touchUpInside)
            documentLinks.addArrangedSubview(button)
        }
        let all = UIButton(type: .system)
        all.setTitle("查看全部法律说明", for: .normal)
        all.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        all.titleLabel?.adjustsFontForContentSizeCategory = true
        all.tintColor = DJDesignTokens.Color.accentDeep
        all.accessibilityIdentifier = "auth.legal.all"
        all.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        all.addAction(UIAction { [weak self] _ in self?.presentLegal(document: nil) }, for: .touchUpInside)
        links.addArrangedSubview(all)
        let stack = UIStackView(arrangedSubviews: [row, links])
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }

    private func presentLegal(document: AppLegalDocument?) {
        view.endEditing(true)
        let reader: UIViewController = document.map { LegalDocumentViewController(document: $0) } ?? ProfileLegalViewController()
        reader.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "关闭", style: .plain, target: self, action: #selector(closeLegal))
        let navigation = UINavigationController(rootViewController: reader)
        navigation.navigationBar.tintColor = DJDesignTokens.Color.accentDeep
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }

    @objc private func closeLegal() { dismiss(animated: true) }

    private func setupLayout() {
        loginScrollView.keyboardDismissMode = .interactive
        loginScrollView.alwaysBounceVertical = true
        view.addSubview(loginScrollView)
        loginScrollView.addSubview(loginContentView)
        loginScrollView.translatesAutoresizingMaskIntoConstraints = false
        loginContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loginScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loginScrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            loginScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loginScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loginContentView.topAnchor.constraint(equalTo: loginScrollView.contentLayoutGuide.topAnchor),
            loginContentView.bottomAnchor.constraint(equalTo: loginScrollView.contentLayoutGuide.bottomAnchor),
            loginContentView.leadingAnchor.constraint(equalTo: loginScrollView.contentLayoutGuide.leadingAnchor),
            loginContentView.trailingAnchor.constraint(equalTo: loginScrollView.contentLayoutGuide.trailingAnchor),
            loginContentView.widthAnchor.constraint(equalTo: loginScrollView.frameLayoutGuide.widthAnchor),
        ])
        let legalControls = makeLegalControls()
        configureFieldContainer(phoneFieldContainer, icon: phoneIcon, textField: phoneField)
        configureFieldContainer(passwordFieldContainer, icon: passwordIcon, textField: passwordField)
        configureVerificationFieldContainer()

        let registerStack = UIStackView(arrangedSubviews: [registerPrefixLabel, registerButton])
        registerStack.axis = .horizontal
        registerStack.alignment = .center
        registerStack.spacing = 4

        let credentialHelpStack = UIStackView(arrangedSubviews: [verificationHintLabel, forgotPasswordButton])
        credentialHelpStack.axis = .horizontal
        credentialHelpStack.alignment = .firstBaseline
        credentialHelpStack.spacing = 12

        [
            titleLabel,
            subtitleLabel,
            credentialModeControl,
            phoneFieldContainer,
            passwordFieldContainer,
            verificationFieldContainer,
            credentialHelpStack,
            legalControls,
            loginButton,
            registerStack,
        ].forEach {
            loginContentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: loginContentView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: loginContentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: loginContentView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            credentialModeControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),
            credentialModeControl.leadingAnchor.constraint(equalTo: loginContentView.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            credentialModeControl.trailingAnchor.constraint(equalTo: loginContentView.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            credentialModeControl.heightAnchor.constraint(equalToConstant: 36),

            phoneFieldContainer.topAnchor.constraint(equalTo: credentialModeControl.bottomAnchor, constant: 20),
            phoneFieldContainer.leadingAnchor.constraint(equalTo: loginContentView.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            phoneFieldContainer.trailingAnchor.constraint(equalTo: loginContentView.trailingAnchor, constant: -DJDesignTokens.Spacing.page),
            phoneFieldContainer.heightAnchor.constraint(equalToConstant: 56),

            passwordFieldContainer.topAnchor.constraint(equalTo: phoneFieldContainer.bottomAnchor, constant: 16),
            passwordFieldContainer.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            passwordFieldContainer.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            passwordFieldContainer.heightAnchor.constraint(equalToConstant: 56),

            verificationFieldContainer.topAnchor.constraint(equalTo: phoneFieldContainer.bottomAnchor, constant: 16),
            verificationFieldContainer.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            verificationFieldContainer.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            verificationFieldContainer.heightAnchor.constraint(equalToConstant: 56),

            credentialHelpStack.topAnchor.constraint(equalTo: verificationFieldContainer.bottomAnchor, constant: 8),
            credentialHelpStack.leadingAnchor.constraint(equalTo: verificationFieldContainer.leadingAnchor, constant: 16),
            credentialHelpStack.trailingAnchor.constraint(equalTo: verificationFieldContainer.trailingAnchor, constant: -16),

            legalControls.topAnchor.constraint(equalTo: credentialHelpStack.bottomAnchor, constant: 16),
            legalControls.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            legalControls.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            loginButton.topAnchor.constraint(equalTo: legalControls.bottomAnchor, constant: 16),
            loginButton.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 57),

            registerStack.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 28),
            registerStack.centerXAnchor.constraint(equalTo: loginContentView.centerXAnchor),
            registerStack.bottomAnchor.constraint(equalTo: loginContentView.bottomAnchor, constant: -24),
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

    private func configureVerificationFieldContainer() {
        verificationFieldContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer
        verificationFieldContainer.layer.cornerRadius = 28
        verificationFieldContainer.layer.borderWidth = 1
        verificationFieldContainer.layer.borderColor = UIColor.clear.cgColor

        verificationIcon.tintColor = DJDesignTokens.Color.textTertiary
        verificationIcon.contentMode = .scaleAspectFit

        verificationFieldContainer.addSubview(verificationIcon)
        verificationFieldContainer.addSubview(verificationField)
        verificationFieldContainer.addSubview(requestCodeButton)
        verificationIcon.translatesAutoresizingMaskIntoConstraints = false
        verificationField.translatesAutoresizingMaskIntoConstraints = false
        requestCodeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            verificationIcon.leadingAnchor.constraint(equalTo: verificationFieldContainer.leadingAnchor, constant: 16),
            verificationIcon.centerYAnchor.constraint(equalTo: verificationFieldContainer.centerYAnchor),
            verificationIcon.widthAnchor.constraint(equalToConstant: 20),
            verificationIcon.heightAnchor.constraint(equalToConstant: 20),

            verificationField.leadingAnchor.constraint(equalTo: verificationIcon.trailingAnchor, constant: 10),
            verificationField.topAnchor.constraint(equalTo: verificationFieldContainer.topAnchor),
            verificationField.bottomAnchor.constraint(equalTo: verificationFieldContainer.bottomAnchor),

            verificationField.trailingAnchor.constraint(equalTo: requestCodeButton.leadingAnchor, constant: -8),
            requestCodeButton.trailingAnchor.constraint(equalTo: verificationFieldContainer.trailingAnchor, constant: -16),
            requestCodeButton.centerYAnchor.constraint(equalTo: verificationFieldContainer.centerYAnchor),
            requestCodeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
        ])
    }

    private func setupActions() {
        credentialModeControl.addTarget(self, action: #selector(credentialModeChanged), for: .valueChanged)
        phoneField.delegate = self
        phoneField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
        passwordField.delegate = self
        passwordField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
        verificationField.delegate = self
        verificationField.addTarget(self, action: #selector(verificationCodeChanged), for: .editingChanged)
        phoneField.accessibilityIdentifier = "auth.phone"
        passwordField.accessibilityIdentifier = "auth.password"
        verificationField.accessibilityIdentifier = "auth.verificationCode"
        requestCodeButton.accessibilityIdentifier = "auth.requestCode"
        loginButton.accessibilityIdentifier = "auth.submit"
        registerButton.accessibilityIdentifier = "auth.switchMode"
    }

    @objc private func credentialModeChanged() {
        guard let mode = CredentialMode(rawValue: credentialModeControl.selectedSegmentIndex) else { return }
        if mode == .password, !passwordAuthentication.canLogin {
            credentialModeControl.selectedSegmentIndex = CredentialMode.verificationCode.rawValue
            showLoginAlert(title: "密码登录暂不可用", message: "当前服务尚未开放密码登录，请使用验证码登录。")
            return
        }
        credentialMode = mode
        applyCredentialMode(animated: true)
    }

    @objc private func phoneChanged() {
        if credentialMode == .password && passwordAuthentication.usernameLoginReady {
            rawPhone = ""
            updateControls()
            return
        }
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

        if pendingPhone != nil, pendingPhone != rawPhone {
            clearPendingChallenge()
        }
        updateControls()
    }

    @objc private func verificationCodeChanged() {
        let digits = verificationField.text?.filter { $0.isNumber } ?? ""
        verificationField.text = String(digits.prefix(8))
        updateControls()
    }

    @objc private func passwordChanged() {
        updateControls()
    }

    private var passwordLoginIdentifier: String {
        (phoneField.text ?? "").replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func presentUsernameRegistration() {
        guard requireLegalConsent() else { return }
        let alert = UIAlertController(title: "凭邀请码注册", message: "不需要短信。用户名为 4–32 位字母、数字或下划线，以字母开头；密码 8–128 位。注册不会自动开放家人记忆。", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "家人提供的邀请码"; $0.autocapitalizationType = .allCharacters; $0.accessibilityIdentifier = "auth.invitationCode" }
        alert.addTextField { $0.placeholder = "用户名（与昵称分开）"; $0.autocapitalizationType = .none; $0.autocorrectionType = .no; $0.accessibilityIdentifier = "auth.username" }
        alert.addTextField { $0.placeholder = "设置密码"; $0.isSecureTextEntry = true; $0.textContentType = .newPassword; $0.accessibilityIdentifier = "auth.registrationPassword" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "注册", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields else { return }
            let code = fields[0].text ?? "", name = fields[1].text ?? "", password = fields[2].text ?? ""
            self.setLoginInProgress(true)
            DreamJourneyBackendClient.shared.registerInvitedUsername(code: code, username: name, password: password) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.setLoginInProgress(false)
                    switch result {
                    case .success:
                        self.authMode = .login
                        self.credentialMode = .password
                        self.credentialModeControl.selectedSegmentIndex = CredentialMode.password.rawValue
                        self.phoneField.text = name
                        self.passwordField.text = password
                        self.applyAuthMode(animated: false)
                        self.applyCredentialMode(animated: false)
                        self.showLoginAlert(title: "注册成功", message: "请点击登录。加入家庭时在家人管理中输入同一邀请码；回响授权需由本人另外确认。")
                    case .failure:
                        self.showLoginAlert(title: "未完成注册", message: "请核对邀请码是否有效、用户名是否符合规则或已被使用，密码需 8–128 位。如已注册，请直接登录。")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func registerTapped() {
        if passwordAuthentication.canRegisterUsername {
            presentUsernameRegistration()
            return
        }
        authMode = authMode == .login ? .register : .login
        if authMode == .register {
            credentialMode = .verificationCode
            credentialModeControl.selectedSegmentIndex = CredentialMode.verificationCode.rawValue
        }
        applyAuthMode(animated: true)
        applyCredentialMode(animated: true)
        phoneField.becomeFirstResponder()
    }

    @objc private func forgotPasswordTapped() {
        guard requireLegalConsent() else { return }
        if passwordAuthentication.usernameLoginReady && !passwordLoginIdentifier.allSatisfy({ $0.isNumber }) {
            showLoginAlert(title: "找回用户名账号", message: "请联系 liftora@163.com 核对账号。邀请码不能用于重设已注册账号的密码。")
            return
        }
        guard passwordAuthentication.canResetPassword else {
            showLoginAlert(title: "密码重置暂不可用", message: "当前无法安全重置密码，请使用验证码登录。")
            return
        }
        let controller = PasswordResetViewController(capability: passwordAuthentication)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }

    @objc private func requestVerificationCodeTapped() {
        requestIdentityChallenge(autoSubmitCode: nil)
    }

    private func requestIdentityChallenge(autoSubmitCode: String?) {
        guard requireLegalConsent() else { return }
        guard !isChallengeRequestInProgress, !isLoginInProgress else { return }
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
        setChallengeRequestInProgress(true)
        capabilityLoader { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let runtime):
                let identityChallenge = runtime.identityChallenge
                guard identityChallenge.canStartClientFlow else {
                    self.setChallengeRequestInProgress(false)
                    self.showLoginAlert(
                        title: "身份验证暂不可用",
                        message: "当前无法安全验证手机号，请稍后重试。"
                    )
                    return
                }
                self.beginIdentityChallengeLogin(
                    phone: submittedPhone,
                    capability: identityChallenge,
                    autoSubmitCode: autoSubmitCode
                )
            case .failure(let error):
                self.setChallengeRequestInProgress(false)
                self.showLoginAlert(title: "获取验证码失败", message: error.localizedDescription)
            }
        }
    }

    @objc private func loginTapped() {
        guard requireLegalConsent() else { return }
        guard !isLoginInProgress, !isChallengeRequestInProgress else { return }
        guard credentialMode == .password ? !passwordLoginIdentifier.isEmpty : rawPhone.count == 11 else {
            showLoginAlert(title: "登录信息不完整", message: "请输入用户名或有效手机号。")
            phoneField.becomeFirstResponder()
            return
        }
        switch credentialMode {
        case .password:
            submitPasswordLogin()
        case .verificationCode:
            submitVerificationCodeLogin()
        }
    }

    private func submitPasswordLogin() {
        guard requireLegalConsent() else { return }
        guard authMode == .login, passwordAuthentication.canLogin else {
            showLoginAlert(title: "密码登录暂不可用", message: "请切换到验证码登录。")
            return
        }
        let password = passwordField.text ?? ""
        guard password.count >= passwordAuthentication.minimumPasswordLength,
              password.count <= passwordAuthentication.maximumPasswordLength else {
            showLoginAlert(
                title: "密码不完整",
                message: "请输入 \(passwordAuthentication.minimumPasswordLength) 至 \(passwordAuthentication.maximumPasswordLength) 位密码。"
            )
            passwordField.becomeFirstResponder()
            return
        }

        setLoginInProgress(true)
        let submittedPhone = passwordLoginIdentifier
        let isUsername = !submittedPhone.allSatisfy { $0.isNumber }
        DreamJourneyBackendClient.shared.loginWithPassword(
            phone: submittedPhone,
            password: password,
            identityType: isUsername ? "username" : "phone"
        ) { [weak self] result in
            guard let self else { return }
            self.setLoginInProgress(false)
            switch result {
            case .success(let login):
                self.completeLogin(
                    userId: login.userId,
                    nickname: login.nickname,
                    phone: isUsername ? "" : submittedPhone
                )
            case .failure(let error):
                self.renderPasswordFailure(error, title: "密码登录失败")
            }
        }
    }

    private func submitVerificationCodeLogin() {
        guard requireLegalConsent() else { return }
        let verificationCode = verificationField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !verificationCode.isEmpty else {
            showLoginAlert(title: "验证码不能为空", message: "请输入收到的验证码。")
            verificationField.becomeFirstResponder()
            return
        }

        guard let challenge = pendingChallenge,
              pendingPhone == rawPhone else {
            requestIdentityChallenge(autoSubmitCode: verificationCode)
            return
        }
        guard !challenge.isExpired() else {
            clearPendingChallenge(message: "验证码已过期，正在重新验证。")
            verificationField.text = verificationCode
            requestIdentityChallenge(autoSubmitCode: verificationCode)
            return
        }

        submitIdentityVerification(
            challenge: challenge,
            verificationCode: verificationCode,
            phone: rawPhone
        )
    }

    private func submitIdentityVerification(
        challenge: BackendIdentityChallengeContract,
        verificationCode: String,
        phone: String
    ) {
        guard requireLegalConsent() else { return }
        setLoginInProgress(true)
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
                if challenge.isExpired() {
                    self.clearPendingChallenge(message: "验证码已过期，请重新获取。")
                } else {
                    self.verificationHintLabel.text = "验证失败，请检查验证码后重试"
                    self.verificationHintLabel.textColor = .systemRed
                }
                self.showLoginAlert(
                    title: "身份验证失败",
                    message: self.identityChallengeFailureMessage(error)
                )
            }
        }
    }

    private func beginIdentityChallengeLogin(
        phone: String,
        capability: BackendIdentityChallengeCapability,
        autoSubmitCode: String?
    ) {
        guard requireLegalConsent() else {
            setChallengeRequestInProgress(false)
            return
        }
        DreamJourneyBackendClient.shared.createIdentityChallenge(
            phone: phone,
            purpose: authMode == .register ? "register" : "login"
        ) { [weak self] result in
            guard let self else { return }
            self.setChallengeRequestInProgress(false)
            switch result {
            case .success(let challenge):
                self.prepareIdentityVerification(
                    challenge: challenge,
                    phone: phone,
                    capability: capability,
                    autoSubmitCode: autoSubmitCode
                )
            case .failure(let error):
                self.showLoginAlert(
                    title: "身份验证失败",
                    message: self.identityChallengeFailureMessage(error)
                )
            }
        }
    }

    private func prepareIdentityVerification(
        challenge: BackendIdentityChallengeContract,
        phone: String,
        capability: BackendIdentityChallengeCapability,
        autoSubmitCode: String?
    ) {
        guard !challenge.isExpired() else {
            showLoginAlert(title: "验证已过期", message: "请重新发起身份验证。")
            return
        }
        let verificationMessage: String
        if capability.providerMode == "synthetic" {
            verificationMessage = "请输入测试账号对应的固定验证码。"
        } else {
            switch challenge.deliveryState {
            case .delivered:
                verificationMessage = "验证码已送达，请输入验证码。"
            case .accepted:
                verificationMessage = challenge.recoveryState == .available
                    ? "验证码请求已受理；若暂未收到，可重新获取。"
                    : "验证码请求已受理，请输入验证码。"
            case .unknown:
                verificationMessage = "验证码送达状态暂未确认，请稍后输入或重新获取。"
            case .undeliverable:
                showLoginAlert(
                    title: "验证码未送达",
                    message: "本次验证无法继续，请稍后重新发起。"
                )
                return
            }
        }
        pendingChallenge = challenge
        pendingPhone = phone
        verificationField.text = autoSubmitCode ?? ""
        verificationHintLabel.text = verificationMessage
        verificationHintLabel.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.7)
        updateControls()
        if let autoSubmitCode, !autoSubmitCode.isEmpty {
            submitIdentityVerification(
                challenge: challenge,
                verificationCode: autoSubmitCode,
                phone: phone
            )
        } else {
            verificationField.becomeFirstResponder()
        }
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
        completeLogin(userId: userId, nickname: nickname, phone: phone)
    }

    private func completeLogin(userId: String, nickname: String, phone: String) {
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

    private func renderPasswordFailure(_ error: Error, title: String) {
        let context = (error as? DreamJourneyBackendClient.ClientError)?.backendErrorContext
        let failure = BackendPasswordFailureState.resolve(
            code: context?.code,
            retryAfterSeconds: context?.retryAfterSeconds,
            message: context?.detail ?? error.localizedDescription
        )
        switch failure {
        case .locked(let message, let retryAfterSeconds):
            let retry = retryAfterSeconds.map { "请在 \($0) 秒后重试。" } ?? "请稍后重试。"
            verificationHintLabel.text = "密码已临时锁定"
            verificationHintLabel.textColor = DJDesignTokens.Color.danger
            showLoginAlert(title: "密码已锁定", message: "\(message)\n\(retry)")
        case .invalidCredentials:
            verificationHintLabel.text = "手机号或密码不正确"
            verificationHintLabel.textColor = DJDesignTokens.Color.danger
            showLoginAlert(title: title, message: "手机号或密码不正确。")
        case .reauthenticationRequired(let message),
             .unavailable(let message),
             .failed(let message):
            verificationHintLabel.text = "密码登录失败，请重试"
            verificationHintLabel.textColor = DJDesignTokens.Color.danger
            showLoginAlert(title: title, message: message)
        }
    }

    private func setLoginInProgress(_ inProgress: Bool) {
        isLoginInProgress = inProgress
        updateControls()
    }

    private func setChallengeRequestInProgress(_ inProgress: Bool) {
        isChallengeRequestInProgress = inProgress
        updateControls()
    }

    private func clearPendingChallenge(message: String = "输入手机号后获取验证码") {
        pendingChallenge = nil
        pendingPhone = nil
        verificationField.text = ""
        verificationHintLabel.text = message
        verificationHintLabel.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.7)
    }

    private func applyAuthMode(animated: Bool) {
        let updates = {
            let title = self.authMode == .login ? "寻梦环游" : "创建账号"
            self.titleLabel.attributedText = NSAttributedString(
                string: title,
                attributes: [
                    .kern: 4.0,
                    .font: DJDesignTokens.Font.display(40),
                    .foregroundColor: DJDesignTokens.Color.accentDeep,
                ]
            )
            self.subtitleLabel.text = self.authMode == .login
                ? "在时空中，留下你的身影"
                : "验证手机号后，将自动创建你的账号"
            self.registerPrefixLabel.text = self.authMode == .login ? "还没有账号？" : "已有账号？"
            self.registerButton.setTitle(self.authMode == .login ? "立即注册" : "立即登录", for: .normal)
            self.credentialModeControl.setEnabled(
                self.authMode == .login && self.passwordAuthentication.canLogin,
                forSegmentAt: CredentialMode.password.rawValue
            )
            self.updateControls()
        }
        if animated {
            UIView.transition(
                with: view,
                duration: 0.22,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: updates
            )
        } else {
            updates()
        }
    }

    private func applyCredentialMode(animated: Bool) {
        let updates = {
            let usesPassword = self.credentialMode == .password && self.authMode == .login
            self.phoneField.keyboardType = usesPassword && self.passwordAuthentication.usernameLoginReady ? .asciiCapable : .numberPad
            self.phoneField.autocapitalizationType = .none
            self.phoneField.autocorrectionType = .no
            self.phoneField.placeholder = usesPassword && self.passwordAuthentication.usernameLoginReady ? "用户名或手机号" : "手机号"
            self.passwordFieldContainer.isHidden = !usesPassword
            self.verificationFieldContainer.isHidden = usesPassword
            self.forgotPasswordButton.isHidden = !usesPassword || !(self.passwordAuthentication.canResetPassword || self.passwordAuthentication.usernameLoginReady)
            if usesPassword {
                self.verificationHintLabel.text = self.passwordAuthentication.canLogin
                    ? "使用已设置的密码登录"
                    : "密码登录暂不可用，请使用验证码"
            } else if self.pendingChallenge == nil {
                self.verificationHintLabel.text = "输入手机号后获取验证码"
            }
            self.verificationHintLabel.textColor = DJDesignTokens.Color.textSecondary.withAlphaComponent(0.7)
            self.updateControls()
        }
        if animated {
            UIView.transition(
                with: view,
                duration: 0.2,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: updates
            )
        } else {
            updates()
        }
    }

    private func loadAuthenticationCapabilities() {
        credentialModeControl.setEnabled(false, forSegmentAt: CredentialMode.password.rawValue)
        capabilityLoader { [weak self] result in
            guard let self else { return }
            if case .success(let runtime) = result {
                self.passwordAuthentication = runtime.passwordAuthentication
            } else {
                self.passwordAuthentication = BackendPasswordAuthenticationCapability(json: nil)
            }
            if self.credentialMode == .password, !self.passwordAuthentication.canLogin {
                self.credentialMode = .verificationCode
                self.credentialModeControl.selectedSegmentIndex = CredentialMode.verificationCode.rawValue
            }
            self.credentialModeControl.setEnabled(
                self.authMode == .login && self.passwordAuthentication.canLogin,
                forSegmentAt: CredentialMode.password.rawValue
            )
            self.applyCredentialMode(animated: false)
        }
    }

    private func updateControls() {
        let isBusy = isChallengeRequestInProgress || isLoginInProgress
        let hasChallenge = pendingChallenge != nil && pendingPhone == rawPhone
        let hasVerificationCode = !(verificationField.text ?? "").isEmpty
        let passwordLength = (passwordField.text ?? "").count
        let hasPassword = passwordLength >= passwordAuthentication.minimumPasswordLength
            && passwordLength <= passwordAuthentication.maximumPasswordLength
        let usesPassword = credentialMode == .password && authMode == .login

        legalConsentButton.isEnabled = !isBusy
        legalConsentButton.setImage(UIImage(systemName: hasAcceptedLegal ? "checkmark.square.fill" : "square"), for: .normal)
        legalConsentButton.accessibilityValue = hasAcceptedLegal ? "已勾选" : "未勾选"
        legalConsentButton.accessibilityTraits = hasAcceptedLegal ? [.button, .selected] : [.button]
        credentialModeControl.isEnabled = !isBusy
        phoneField.isEnabled = !isBusy
        passwordField.isEnabled = !isBusy
        verificationField.isEnabled = !isBusy
        requestCodeButton.isEnabled = hasAcceptedLegal && !usesPassword && rawPhone.count == 11 && !isBusy
        forgotPasswordButton.isEnabled = hasAcceptedLegal && (passwordAuthentication.canResetPassword || passwordAuthentication.usernameLoginReady) && !isBusy
        loginButton.isEnabled = hasAcceptedLegal && (usesPassword ? !passwordLoginIdentifier.isEmpty : rawPhone.count == 11)
            && (usesPassword ? hasPassword && passwordAuthentication.canLogin : hasVerificationCode)
            && !isBusy
        registerButton.isEnabled = !isBusy

        if isChallengeRequestInProgress {
            requestCodeButton.setTitle("发送中...", for: .normal)
        } else {
            requestCodeButton.setTitle(hasChallenge ? "重新获取" : "获取验证码", for: .normal)
        }
        if isLoginInProgress {
            loginButton.setTitle(usesPassword ? "登录中..." : "验证中...", for: .normal)
        } else {
            loginButton.setTitle(authMode == .login ? "登录" : "注册并登录", for: .normal)
        }
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
