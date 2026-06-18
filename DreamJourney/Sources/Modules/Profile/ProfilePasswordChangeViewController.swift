import UIKit

final class ProfilePasswordChangeViewController: UIViewController {

    private enum PasswordValidationResult {
        case valid(currentPassword: String, newPassword: String)
        case invalid(String)
    }

    private enum PasswordChangeState {
        case idle
        case saving
        case saved
        case invalid(String)
        case failed(String)
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let currentPasswordField = UITextField()
    private let newPasswordField = UITextField()
    private let confirmPasswordField = UITextField()
    private let statusLabel = UILabel()
    private let saveButton = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "修改密码"
        view.backgroundColor = DJDesignTokens.Color.background
        configureScrollView()
        buildContent()
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
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.alignment = .fill
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
        contentStack.addArrangedSubview(makeFormCard())
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(saveButton)

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
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

    private func makeFormCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let stack = UIStackView(arrangedSubviews: [
            makeInputRow(
                title: "当前密码",
                textField: currentPasswordField,
                accessibilityIdentifier: "profile-password-current-field"
            ),
            makeDivider(),
            makeInputRow(
                title: "新密码",
                textField: newPasswordField,
                accessibilityIdentifier: "profile-password-new-field"
            ),
            makeDivider(),
            makeInputRow(
                title: "确认新密码",
                textField: confirmPasswordField,
                accessibilityIdentifier: "profile-password-confirm-field"
            ),
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

    private func makeInputRow(title: String, textField: UITextField, accessibilityIdentifier: String) -> UIView {
        let container = UIView()
        let titleLabel = makeLabel(
            text: title,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        )

        textField.font = DJDesignTokens.Font.body(15)
        textField.textColor = DJDesignTokens.Color.textPrimary
        textField.textAlignment = .right
        textField.isSecureTextEntry = true
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        textField.accessibilityIdentifier = accessibilityIdentifier
        textField.addTarget(self, action: #selector(passwordFieldDidChange), for: .editingChanged)

        container.addSubview(titleLabel)
        container.addSubview(textField)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: textField.leadingAnchor, constant: -12),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])

        return container
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.45)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return divider
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    @objc private func saveTapped() {
        [currentPasswordField, newPasswordField, confirmPasswordField].forEach { $0.resignFirstResponder() }

        switch validatePasswords(
            currentPassword: currentPasswordField.text,
            newPassword: newPasswordField.text,
            confirmPassword: confirmPasswordField.text
        ) {
        case .valid(let currentPassword, let newPassword):
            submitPasswordChange(currentPassword: currentPassword, newPassword: newPassword)
        case .invalid(let message):
            renderState(.invalid(message))
        }
    }

    private func submitPasswordChange(currentPassword: String, newPassword: String) {
        guard DreamJourneyBackendClient.shared.isPasswordChangeConfigured else {
            renderState(.failed("当前环境暂不支持修改密码"))
            return
        }
        guard let userId = UserManager.shared.currentUser?.id else {
            renderState(.failed("请先登录后再修改密码"))
            return
        }

        renderState(.saving)
        DreamJourneyBackendClient.shared.changePassword(
            userId: userId,
            oldPassword: currentPassword,
            newPassword: newPassword
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                currentPasswordField.text = nil
                newPasswordField.text = nil
                confirmPasswordField.text = nil
                renderState(.saved)
            case .failure(let error):
                renderState(.failed(error.localizedDescription))
            }
        }
    }

    private func validatePasswords(
        currentPassword rawCurrentPassword: String?,
        newPassword rawNewPassword: String?,
        confirmPassword rawConfirmPassword: String?
    ) -> PasswordValidationResult {
        let currentPassword = (rawCurrentPassword ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = (rawNewPassword ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmPassword = (rawConfirmPassword ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentPassword.isEmpty else {
            return .invalid("当前密码不能为空。")
        }
        guard newPassword.count >= 8 else {
            return .invalid("新密码至少 8 位。")
        }
        guard confirmPassword == newPassword else {
            return .invalid("确认新密码必须一致。")
        }
        return .valid(currentPassword: currentPassword, newPassword: newPassword)
    }

    private func renderState(_ state: PasswordChangeState) {
        saveButton.isEnabled = true
        saveButton.alpha = 1
        saveButton.setTitle("保存新密码", for: .normal)

        switch state {
        case .idle:
            statusLabel.isHidden = true
            statusLabel.text = nil
        case .saving:
            saveButton.isEnabled = false
            saveButton.alpha = 0.68
            saveButton.setTitle("提交中...", for: .normal)
            statusLabel.isHidden = false
            statusLabel.text = "提交中..."
            statusLabel.textColor = DJDesignTokens.Color.textSecondary
        case .saved:
            statusLabel.isHidden = false
            statusLabel.text = "密码已更新"
            statusLabel.textColor = DJDesignTokens.Color.accentDeep
        case .invalid(let message):
            statusLabel.isHidden = false
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .failed(let message):
            statusLabel.isHidden = false
            statusLabel.text = "修改失败：\(message)"
            statusLabel.textColor = DJDesignTokens.Color.danger
        }
    }

    @objc private func passwordFieldDidChange() {
        renderState(.idle)
    }
}

extension ProfilePasswordChangeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
