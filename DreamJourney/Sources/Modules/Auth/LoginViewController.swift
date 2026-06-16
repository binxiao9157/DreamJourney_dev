import UIKit

// MARK: - LoginViewController
final class LoginViewController: UIViewController {

    var didLogin: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "寻梦环游"
        label.font = DJDesignTokens.Font.display(30)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "在时空中，留下你的身影"
        label.font = DJDesignTokens.Font.body(13)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.textAlignment = .center
        return label
    }()

    private let modeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.surfaceContainer
        view.layer.cornerRadius = DJDesignTokens.Radius.pill
        return view
    }()

    private let phoneModeLabel: UILabel = {
        let label = UILabel()
        label.text = "手机号"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.textAlignment = .center
        label.backgroundColor = DJDesignTokens.Color.surface
        label.layer.cornerRadius = 17
        label.layer.masksToBounds = true
        return label
    }()

    private let passwordModeLabel: UILabel = {
        let label = UILabel()
        label.text = "时光账号"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.textAlignment = .center
        return label
    }()

    private let phoneFieldContainer = UIView()
    private let phoneIcon = UIImageView(image: UIImage(systemName: "iphone"))
    private let phoneField: UITextField = {
        let field = UITextField()
        field.placeholder = "手机号"
        field.font = DJDesignTokens.Font.body(15)
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
        field.placeholder = "密码"
        field.font = DJDesignTokens.Font.body(15)
        field.textColor = DJDesignTokens.Color.textPrimary
        field.isSecureTextEntry = true
        field.returnKeyType = .done
        field.borderStyle = .none
        return field
    }()

    private lazy var forgotButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("忘记密码？", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(12)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        return button
    }()

    private lazy var loginButton: UIButton = {
        let button = DJComponentFactory.primaryButton(title: "登录", target: self, action: #selector(loginTapped))
        button.isEnabled = false
        button.alpha = 0.55
        return button
    }()

    private let registerPrefixLabel: UILabel = {
        let label = UILabel()
        label.text = "还没有账号？"
        label.font = DJDesignTokens.Font.body(13)
        label.textColor = DJDesignTokens.Color.textTertiary
        return label
    }()

    private lazy var registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即注册", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        return button
    }()

    private var rawPhone = ""

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

        modeContainer.addSubview(phoneModeLabel)
        modeContainer.addSubview(passwordModeLabel)

        let registerStack = UIStackView(arrangedSubviews: [registerPrefixLabel, registerButton])
        registerStack.axis = .horizontal
        registerStack.alignment = .center
        registerStack.spacing = 4

        [
            titleLabel,
            subtitleLabel,
            modeContainer,
            phoneFieldContainer,
            passwordFieldContainer,
            forgotButton,
            loginButton,
            registerStack,
        ].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [phoneModeLabel, passwordModeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 94),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            modeContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 46),
            modeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            modeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            modeContainer.heightAnchor.constraint(equalToConstant: 42),

            phoneModeLabel.leadingAnchor.constraint(equalTo: modeContainer.leadingAnchor, constant: 4),
            phoneModeLabel.topAnchor.constraint(equalTo: modeContainer.topAnchor, constant: 4),
            phoneModeLabel.bottomAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: -4),
            phoneModeLabel.widthAnchor.constraint(equalTo: modeContainer.widthAnchor, multiplier: 0.5, constant: -4),

            passwordModeLabel.trailingAnchor.constraint(equalTo: modeContainer.trailingAnchor, constant: -4),
            passwordModeLabel.topAnchor.constraint(equalTo: modeContainer.topAnchor, constant: 4),
            passwordModeLabel.bottomAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: -4),
            passwordModeLabel.leadingAnchor.constraint(equalTo: phoneModeLabel.trailingAnchor, constant: 4),

            phoneFieldContainer.topAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: 22),
            phoneFieldContainer.leadingAnchor.constraint(equalTo: modeContainer.leadingAnchor),
            phoneFieldContainer.trailingAnchor.constraint(equalTo: modeContainer.trailingAnchor),
            phoneFieldContainer.heightAnchor.constraint(equalToConstant: 48),

            passwordFieldContainer.topAnchor.constraint(equalTo: phoneFieldContainer.bottomAnchor, constant: 12),
            passwordFieldContainer.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            passwordFieldContainer.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            passwordFieldContainer.heightAnchor.constraint(equalToConstant: 48),

            forgotButton.topAnchor.constraint(equalTo: passwordFieldContainer.bottomAnchor, constant: 10),
            forgotButton.trailingAnchor.constraint(equalTo: passwordFieldContainer.trailingAnchor),

            loginButton.topAnchor.constraint(equalTo: forgotButton.bottomAnchor, constant: 20),
            loginButton.leadingAnchor.constraint(equalTo: phoneFieldContainer.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: phoneFieldContainer.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 48),

            registerStack.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),
            registerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func configureFieldContainer(_ container: UIView, icon: UIImageView, textField: UITextField) {
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium
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
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

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

        let canLogin = rawPhone.count == 11
        loginButton.isEnabled = canLogin
        loginButton.alpha = canLogin ? 1 : 0.55
    }

    @objc private func forgotTapped() {
        let alert = UIAlertController(title: "暂未开放", message: "密码找回功能将在后续版本开放。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func registerTapped() {
        let alert = UIAlertController(title: "暂未开放", message: "当前版本可直接使用手机号登录。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func loginTapped() {
        guard rawPhone.count == 11 else { return }
        UserManager.shared.login(phone: rawPhone, nickname: "")
        didLogin?()
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
