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
        if passwordAuthentication.registrationAdmissionEnabled {
            guard requireLegalConsent() else { return }
            guard passwordAuthentication.canRegisterPhone else {
                showLoginAlert(title: "手机号注册暂未开放", message: "短信服务尚未准备完成，请稍后再试。已有账号可以正常登录。")
                return
            }
            let controller = PhoneRegistrationViewController()
            controller.onRegistered = { [weak self] phone in
                guard let self else { return }
                self.authMode = .login
                self.credentialMode = .password
                self.credentialModeControl.selectedSegmentIndex = CredentialMode.password.rawValue
                self.phoneField.text = phone
                self.passwordField.text = ""
                self.applyAuthMode(animated: false)
                self.applyCredentialMode(animated: false)
            }
            present(UINavigationController(rootViewController: controller), animated: true)
            return
        }
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
        if passwordAuthentication.usernameLoginReady && LoginIdentifierPolicy.isUsername(passwordLoginIdentifier) {
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
        let isUsername = LoginIdentifierPolicy.isUsername(submittedPhone)
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

/// Enrollment is separate from login: an OTP/grant never becomes an app session.
private final class PhoneRegistrationViewController: UIViewController {
    var onRegistered: ((String) -> Void)?
    private let invite = UITextField(), phone = UITextField(), code = UITextField()
    private let password = UITextField(), confirmation = UITextField(), consent = UISwitch()
    private let status = UILabel(), send = UIButton(type: .system), submit = UIButton(type: .system)
    private let checkResult = UIButton(type: .system)
    private var attempt: [String: Any]?
    private var sendOperation = UUID().uuidString, completionOperation = UUID().uuidString
    private var sentInput = "", grant = "", busy = false, nextSend = Date.distantPast
    private var completing = false

    private let registrationScroll = UIScrollView()
    private let legalLinks = UIStackView()
    private let codeRow = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "手机号注册"
        view.backgroundColor = DJDesignTokens.Color.background
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.accentDeep
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = DJDesignTokens.Color.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: DJDesignTokens.Color.textPrimary]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(close))

        let scroll = registrationScroll, stack = UIStackView()
        scroll.keyboardDismissMode = .interactive
        scroll.alwaysBounceVertical = true
        scroll.accessibilityIdentifier = "registration.form"
        stack.axis = .vertical; stack.spacing = 14
        view.addSubview(scroll); scroll.addSubview(stack); view.addSubview(status)
        status.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false; stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -8),
            status.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)])

        let heading = registrationLabel("创建你的账号", font: DJDesignTokens.Font.display(28), color: DJDesignTokens.Color.accentDeep)
        let intro = registrationLabel("让值得珍藏的回忆，从这里开始。", font: DJDesignTokens.Font.body(14))
        let header = UIStackView(arrangedSubviews: [heading, intro])
        header.axis = .vertical; header.spacing = 8
        stack.addArrangedSubview(header)

        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(dismissRegistrationKeyboard))]
        toolbar.tintColor = DJDesignTokens.Color.accentDeep
        toolbar.sizeToFit()
        for (field, placeholder, id) in [(invite,"请输入注册邀请码","invite"),(phone,"中国大陆手机号","phone"),
            (code,"短信验证码","code"),(password,"设置密码（8–128位）","password"),(confirmation,"再次输入密码","confirmation")] {
            field.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: DJDesignTokens.Font.body(16))
            field.adjustsFontForContentSizeCategory = true
            field.textColor = DJDesignTokens.Color.textPrimary
            field.tintColor = DJDesignTokens.Color.accentDeep
            field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: DJDesignTokens.Color.textTertiary])
            field.borderStyle = .none; field.autocorrectionType = .no
            field.autocapitalizationType = .none; field.accessibilityIdentifier = "registration." + id
            field.accessibilityLabel = placeholder
            field.inputAccessoryView = toolbar
        }
        phone.keyboardType = .phonePad; code.keyboardType = .numberPad; code.textContentType = .oneTimeCode
        password.isSecureTextEntry = true; confirmation.isSecureTextEntry = true
        password.textContentType = .newPassword; confirmation.textContentType = .newPassword

        stack.addArrangedSubview(registrationSection("注册邀请码", views: [registrationField(invite, icon: "ticket")]))
        let codeContainer = registrationField(code, icon: "number.square")
        codeRow.addArrangedSubview(codeContainer); codeRow.addArrangedSubview(send)
        codeRow.spacing = 8; codeRow.alignment = .fill
        send.setContentHuggingPriority(.required, for: .horizontal)
        send.setContentCompressionResistancePriority(.required, for: .horizontal)
        send.titleLabel?.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: DJDesignTokens.Font.label(14))
        send.titleLabel?.adjustsFontForContentSizeCategory = true
        send.tintColor = DJDesignTokens.Color.accentDeep
        send.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stack.addArrangedSubview(registrationSection("验证手机号", views: [registrationField(phone, icon: "iphone"), codeRow]))
        stack.addArrangedSubview(registrationSection("设置登录密码", views: [registrationField(password, icon: "lock"), registrationField(confirmation, icon: "lock.rotation")]))

        let legal = registrationLabel("我已阅读并同意使用说明、免责说明，并知悉隐私说明", font: DJDesignTokens.Font.body(13))
        consent.onTintColor = DJDesignTokens.Color.accentDeep
        consent.setContentHuggingPriority(.required, for: .horizontal)
        consent.setContentCompressionResistancePriority(.required, for: .horizontal)
        consent.accessibilityIdentifier = "registration.consent"
        consent.accessibilityLabel = "同意使用说明、免责说明，并知悉隐私说明"
        let legalRow = UIStackView(arrangedSubviews: [consent, legal])
        legalRow.spacing = 12; legalRow.alignment = .center
        legalLinks.spacing = 4; legalLinks.distribution = .fillEqually
        for document in [AppLegalDocument.usage, .disclaimer, .privacy] {
            let button = UIButton(type: .system)
            button.setTitle("《\(document.title)》", for: .normal)
            button.titleLabel?.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: DJDesignTokens.Font.body(13))
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.tintColor = DJDesignTokens.Color.accentDeep
            button.accessibilityIdentifier = "registration.legal.\(document.rawValue)"
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { [weak self] _ in
                self?.view.endEditing(true)
                self?.navigationController?.pushViewController(LegalDocumentViewController(document: document), animated: true)
            }, for: .touchUpInside)
            legalLinks.addArrangedSubview(button)
        }
        let legalGroup = UIStackView(arrangedSubviews: [legalRow, legalLinks])
        legalGroup.axis = .vertical; legalGroup.spacing = 0
        stack.addArrangedSubview(legalGroup)
        stack.setCustomSpacing(12, after: legalGroup)

        send.setTitle("获取验证码", for: .normal)
        var primary = UIButton.Configuration.filled()
        primary.title = "完成注册"
        primary.baseForegroundColor = DJDesignTokens.Color.textPrimary
        primary.baseBackgroundColor = DJDesignTokens.Color.accent
        primary.cornerStyle = .capsule
        primary.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        primary.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: DJDesignTokens.Font.label(16))
            return attributes
        }
        submit.configuration = primary
        submit.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        checkResult.setTitle("查询本次注册结果", for: .normal); checkResult.isHidden = true
        checkResult.tintColor = DJDesignTokens.Color.accentDeep
        checkResult.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        checkResult.titleLabel?.adjustsFontForContentSizeCategory = true
        checkResult.titleLabel?.numberOfLines = 0
        checkResult.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        send.accessibilityIdentifier = "registration.send"; submit.accessibilityIdentifier = "registration.submit"
        send.addTarget(self, action: #selector(sendCode), for: .touchUpInside)
        submit.addTarget(self, action: #selector(register), for: .touchUpInside)
        checkResult.addTarget(self, action: #selector(queryResult), for: .touchUpInside)
        [submit, checkResult].forEach { stack.addArrangedSubview($0) }
        status.numberOfLines = 0; status.accessibilityIdentifier = "registration.status"
        status.font = .preferredFont(forTextStyle: .footnote); status.adjustsFontForContentSizeCategory = true
        status.textColor = DJDesignTokens.Color.textSecondary
        stack.setCustomSpacing(8, after: submit)
        let note = registrationLabel("邀请码仅控制名额；家人记忆需本人另行授权。", font: DJDesignTokens.Font.body(12))
        note.textAlignment = .center
        stack.addArrangedSubview(note)
        updateRegistrationLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(revealRegistrationField), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }

    private func registrationLabel(_ text: String, font: UIFont, color: UIColor = DJDesignTokens.Color.textSecondary) -> UILabel {
        let label = UILabel()
        label.text = text; label.numberOfLines = 0; label.textColor = color
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func registrationSection(_ title: String, views: [UIView]) -> UIStackView {
        let label = registrationLabel(title, font: DJDesignTokens.Font.label(13))
        let stack = UIStackView(arrangedSubviews: [label] + views)
        stack.axis = .vertical; stack.spacing = 10
        return stack
    }

    private func registrationField(_ field: UITextField, icon: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer
        container.layer.cornerRadius = 28
        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = DJDesignTokens.Color.textTertiary
        symbol.contentMode = .scaleAspectFit
        symbol.isAccessibilityElement = false
        let row = UIStackView(arrangedSubviews: [symbol, field])
        row.alignment = .center; row.spacing = 10
        container.addSubview(row); row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            field.heightAnchor.constraint(equalTo: row.heightAnchor),
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            symbol.widthAnchor.constraint(equalToConstant: 20), symbol.heightAnchor.constraint(equalToConstant: 20)])
        return container
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateRegistrationLayout()
    }

    private func updateRegistrationLayout() {
        let largeText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        legalLinks.axis = largeText ? .vertical : .horizontal
        codeRow.axis = largeText ? .vertical : .horizontal
    }

    @objc private func dismissRegistrationKeyboard() { view.endEditing(true) }

    @objc private func revealRegistrationField() {
        guard let field = [invite, phone, code, password, confirmation].first(where: { $0.isFirstResponder }) else { return }
        view.layoutIfNeeded()
        registrationScroll.scrollRectToVisible(field.convert(field.bounds, to: registrationScroll).insetBy(dx: 0, dy: -20), animated: true)
    }

    private func setBusy(_ value: Bool) {
        busy = value; [send,submit,checkResult].forEach { $0.isEnabled = !value }
        [invite,phone,code,password,confirmation].forEach { $0.isEnabled = !value && !completing }
        consent.isEnabled = !value && !completing
        isModalInPresentation = value || completing
    }
    private var inputKey: String { (invite.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() + ":" + (LoginIdentifierPolicy.mainlandPhone(phone.text ?? "") ?? "") }
    private func call(_ operation: String, _ payload: [String:Any], completion: @escaping ([String:Any]) -> Void) {
        setBusy(true)
        DreamJourneyBackendClient.shared.phoneRegistrationCommand(operation,payload:payload) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }; self.setBusy(false)
                switch result {
                case .success(let json): completion(json)
                case .failure(let error):
                    if case DreamJourneyBackendClient.ClientError.backendError(let httpStatus, _) = error,
                       let httpStatus, [400,409,410,429].contains(httpStatus) {
                        self.completing = false; self.setBusy(false)
                        self.status.text = "本次操作未完成，请核对邀请码、验证码和名额状态。验证码过期时请重新获取；已有账号可直接登录。"
                        return
                    }
                    self.status.text = self.completing ? "暂未确认注册结果，请点“查询本次注册结果”；不要重新注册。" : "操作未完成。请核对邀请码、验证码及网络；短信未开放、已达人数上限或发送过于频繁时暂不可注册。"
                }
            }
        }
    }
    @objc private func close() {
        guard !busy else { return }
        let leave = { [weak self] in
            self?.password.text = ""; self?.confirmation.text = ""
            self?.dismiss(animated: true)
        }
        guard completing else { leave(); return }
        let alert = UIAlertController(title: "注册结果尚未确认",
            message: "建议先查询结果。离开不会撤销已提交的注册；稍后可用刚才的手机号和密码尝试登录。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续查询", style: .cancel))
        alert.addAction(UIAlertAction(title: "返回登录", style: .default) { _ in leave() })
        present(alert, animated: true)
    }
    @objc private func sendCode() {
        guard !busy && !completing else { return }
        guard consent.isOn, let normalized = LoginIdentifierPolicy.mainlandPhone(phone.text ?? ""), !(invite.text ?? "").isEmpty else {
            status.text = "请填写邀请码、有效大陆手机号，并勾选说明。"; return
        }
        guard Date() >= nextSend else { status.text = "请等待60秒后再获取验证码。"; return }
        // Explicit resend is a new operation only after a known response/cooldown.
        if attempt != nil || sentInput != inputKey { sendOperation = UUID().uuidString }
        sentInput = inputKey; attempt = nil; grant = ""; completionOperation = UUID().uuidString
        status.text = "验证码发送中"
        call("challenges",["invitationCode":invite.text ?? "","phone":normalized,"legalConsent":true,"operationId":sendOperation]) { [weak self] json in
            guard let self else { return }; self.attempt = json; self.nextSend = Date().addingTimeInterval(60)
            let accepted = ["accepted","delivered"].contains(json["status"] as? String ?? "")
            self.status.text = accepted ? "验证码已提交发送，请查看短信。" : "暂未确认短信送达；若收到验证码可继续，60秒后可主动重发。"
        }
    }
    private var attemptPayload: [String:Any]? {
        guard let attempt, let id = attempt["attemptId"] as? String, let token = attempt["attemptToken"] as? String else { return nil }
        return ["attemptId":id,"attemptToken":token]
    }
    @objc private func register() {
        guard !busy && !completing else { return }
        guard consent.isOn, sentInput == inputKey, let base = attemptPayload else { status.text = "请先为当前手机号获取验证码。"; return }
        let value = password.text ?? ""
        guard (8...128).contains(value.count), value == confirmation.text else { status.text = "两次密码需一致，长度8–128位。"; return }
        status.text = "正在验证验证码"
        call("verify",base.merging(["code":code.text ?? ""]) { _,new in new }) { [weak self] json in
            guard let self, let grant = json["grant"] as? String else { return }
            self.grant = grant; self.completing = true; self.checkResult.isHidden = false
            self.finish(base:base,password:value)
        }
    }
    private func finish(base:[String:Any],password:String) {
        status.text = "正在注册"
        call("complete",base.merging(["grant":grant,"password":password,"legalConsent":true,"operationId":completionOperation]) { _,new in new }) { [weak self] json in self?.handleResult(json) }
    }
    @objc private func queryResult() {
        guard !busy, let base = attemptPayload else { return }
        call("result",base) { [weak self] json in
            guard let self else { return }
            if json["status"] as? String == "verified" {
                // Same operation and immutable fields: safe replay after unknown HTTP result.
                self.finish(base:base,password:self.password.text ?? "")
            } else { self.handleResult(json) }
        }
    }
    private func handleResult(_ json:[String:Any]) {
        let result = json["status"] as? String ?? ""
        guard ["registered","existingAccount"].contains(result) else {
            if ["locked", "superseded", "undeliverable"].contains(result) { completing = false; setBusy(false) }
            status.text = "本次尚未完成注册，请核对短信或稍后查询结果。"; return
        }
        completing = false; setBusy(false); password.text = ""; confirmation.text = ""
        let number = LoginIdentifierPolicy.mainlandPhone(phone.text ?? "") ?? ""
        let alert = UIAlertController(title: result == "registered" ? "注册成功" : "手机号已有账号",
            message: "请返回登录；已有账号密码未改变。家庭关系与记忆授权需另外确认。",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"去登录",style:.default) { [weak self] _ in self?.onRegistered?(number); self?.dismiss(animated:true) })
        present(alert,animated:true)
    }
}
