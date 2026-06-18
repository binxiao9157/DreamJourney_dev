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
        field.returnKeyType = .done
        field.borderStyle = .none
        return field
    }()

    private lazy var forgotButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("忘记密码？", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.setTitleColor(DJDesignTokens.Color.accentDeep.withAlphaComponent(0.8), for: .normal)
        button.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
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
        configureFieldContainer(passwordFieldContainer, icon: passwordIcon, textField: passwordField)

        let registerStack = UIStackView(arrangedSubviews: [registerPrefixLabel, registerButton])
        registerStack.axis = .horizontal
        registerStack.alignment = .center
        registerStack.spacing = 4

        [
            titleLabel,
            subtitleLabel,
            phoneFieldContainer,
            passwordFieldContainer,
            forgotButton,
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

            passwordFieldContainer.topAnchor.constraint(equalTo: phoneFieldContainer.bottomAnchor, constant: 12),
            passwordFieldContainer.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            passwordFieldContainer.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            passwordFieldContainer.heightAnchor.constraint(equalToConstant: 56),

            forgotButton.topAnchor.constraint(equalTo: passwordFieldContainer.bottomAnchor, constant: 18),
            forgotButton.trailingAnchor.constraint(equalTo: passwordFieldContainer.trailingAnchor),

            loginButton.topAnchor.constraint(equalTo: forgotButton.bottomAnchor, constant: 20),
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
        passwordField.delegate = self
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

    @objc private func forgotTapped() {
        let alert = UIAlertController(title: "暂未开放", message: "密码找回功能将在后续版本开放。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func registerTapped() {
        let alert = UIAlertController(title: "暂未开放", message: "当前版本可使用手机号和密码登录。", preferredStyle: .alert)
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

        let password = normalizedPassword()
        guard !password.isEmpty else {
            showLoginAlert(title: "密码不能为空", message: "请输入登录密码。")
            passwordField.becomeFirstResponder()
            return
        }
        guard password.count >= 8 else {
            showLoginAlert(title: "密码至少 8 位", message: "请检查后重新输入。")
            passwordField.becomeFirstResponder()
            return
        }

        guard DreamJourneyBackendClient.shared.isLoginSyncConfigured else {
            UserManager.shared.login(phone: rawPhone, nickname: "")
            didLogin?()
            return
        }

        setLoginInProgress(true)
        DreamJourneyBackendClient.shared.upsertUser(phone: rawPhone, nickname: "", password: password) { [weak self] result in
            guard let self else { return }
            self.setLoginInProgress(false)
            switch result {
            case .success(let response):
                self.handleBackendLoginSuccess(response, phone: self.rawPhone)
            case .failure(let error):
                self.showLoginAlert(title: "登录失败", message: error.localizedDescription)
            }
        }
    }

    private func normalizedPassword() -> String {
        (passwordField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleBackendLoginSuccess(_ response: [String: Any], phone: String) {
        guard let user = response["user"] as? [String: Any] else {
            showLoginAlert(title: "登录失败", message: "后端返回的用户数据不可用。")
            return
        }
        let userId = user["id"] as? String
        let nickname = (user["nickname"] as? String) ?? ""
        UserManager.shared.login(phone: phone, nickname: nickname, id: userId)
        didLogin?()
    }

    private func setLoginInProgress(_ inProgress: Bool) {
        isLoginInProgress = inProgress
        loginButton.isEnabled = !inProgress
        loginButton.setTitle(inProgress ? "登录中..." : "登录", for: .normal)
    }

    private func showLoginAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == phoneField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
