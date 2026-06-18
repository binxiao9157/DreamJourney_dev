import UIKit

final class ProfileSettingsViewController: UIViewController {

    private enum ProfileSaveState {
        case idle
        case saving
        case saved
        case failed(String)
        case networkUnavailable
        case invalid(String)
    }

    private enum AccountProfileValidationResult {
        case valid(name: String, gender: String?, region: String?)
        case invalid(String)
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let nameField = UITextField()
    private let genderField = UITextField()
    private let regionField = UITextField()
    private let phoneValueLabel = UILabel()
    private let statusLabel = UILabel()
    private let avatarEditButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let featureFlags: FeatureFlagService
    private let maxNameLength = 24
    private let maxRegionLength = 32
    private let allowedGenderValues = ["男", "女", "不便透露"]

    private var isProfileHiddenBranchesEnabled: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains(ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument)
        #else
        return false
        #endif
    }

    private var isPasswordChangeVisible: Bool {
        ProfileFamilyPersonaReleaseReadiness.isPasswordChangeVisible(
            isPasswordChangeEnabled: featureFlags.isEnabled(.accountPasswordChange),
            isHiddenBranchesEnabled: isProfileHiddenBranchesEnabled
        )
    }

    init(featureFlags: FeatureFlagService = .shared) {
        self.featureFlags = featureFlags
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "个人资料设置"
        view.backgroundColor = DJDesignTokens.Color.background
        configureScrollView()
        buildContent()
        loadUser()
        renderSaveState(.idle)
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
        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeEditableCard())
        if isPasswordChangeVisible {
            contentStack.addArrangedSubview(makeSecurityCard())
        }
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(saveButton)

        statusLabel.font = DJDesignTokens.Font.body(13)
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.accessibilityIdentifier = "profile-settings-save-status"

        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = DJDesignTokens.Color.accent
        saveButton.layer.cornerRadius = 22
        saveButton.accessibilityIdentifier = "profile-settings-save-button"
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    private func makeHeader() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let avatarContainer = UIView()
        avatarContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.55)
        avatarContainer.layer.cornerRadius = 32
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = DJDesignTokens.Color.divider.cgColor

        let avatarImageView = UIImageView()
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 34, weight: .light)
        avatarImageView.image = UIImage(systemName: UserManager.shared.currentUser?.avatarName ?? "person.circle.fill", withConfiguration: avatarConfig)
        avatarImageView.tintColor = DJDesignTokens.Color.accentDeep
        avatarImageView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "头像",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
        let subtitleLabel = makeLabel(
            text: "当前版本仅展示系统头像，暂不开放相册选择。",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )

        avatarEditButton.setTitle("头像上传暂未开放", for: .normal)
        avatarEditButton.titleLabel?.font = DJDesignTokens.Font.label(13)
        avatarEditButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        avatarEditButton.contentHorizontalAlignment = .left
        avatarEditButton.accessibilityIdentifier = "profile-settings-avatar-placeholder"
        avatarEditButton.addTarget(self, action: #selector(showAvatarPlaceholder), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, avatarEditButton])
        textStack.axis = .vertical
        textStack.spacing = 6

        let stack = UIStackView(arrangedSubviews: [avatarContainer, textStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 14

        card.addSubview(stack)
        avatarContainer.addSubview(avatarImageView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),

            avatarContainer.widthAnchor.constraint(equalToConstant: 64),
            avatarContainer.heightAnchor.constraint(equalToConstant: 64),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 38),
            avatarImageView.heightAnchor.constraint(equalToConstant: 38),
        ])

        return card
    }

    private func makeSecurityCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let button = UIControl()
        button.isAccessibilityElement = true
        button.accessibilityIdentifier = "profile-settings-password-change-row"
        button.accessibilityLabel = "修改密码"
        button.accessibilityTraits = .button
        button.addTarget(self, action: #selector(passwordChangeTapped), for: .touchUpInside)

        let titleLabel = makeLabel(
            text: "修改密码",
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        )

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DJDesignTokens.Color.textTertiary
        chevron.contentMode = .scaleAspectFit

        button.addSubview(titleLabel)
        button.addSubview(chevron)
        card.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chevron.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),

            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14),
        ])

        return card
    }

    private func makeEditableCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let nameRow = makeInputRow(
            title: "名称",
            textField: nameField,
            accessibilityIdentifier: "profile-settings-name-field"
        )
        let genderRow = makeInputRow(
            title: "性别",
            textField: genderField,
            accessibilityIdentifier: "profile-settings-gender-field"
        )
        let regionRow = makeInputRow(
            title: "地区",
            textField: regionField,
            accessibilityIdentifier: "profile-settings-region-field"
        )
        let phoneRow = makeReadonlyRow(title: "手机号", valueLabel: phoneValueLabel)

        let stack = UIStackView(arrangedSubviews: [
            nameRow,
            makeDivider(),
            genderRow,
            makeDivider(),
            regionRow,
            makeDivider(),
            phoneRow
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
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        textField.accessibilityIdentifier = accessibilityIdentifier
        textField.addTarget(self, action: #selector(profileFieldDidChange), for: .editingChanged)

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

    private func makeReadonlyRow(title: String, valueLabel: UILabel) -> UIView {
        let container = UIView()
        let titleLabel = makeLabel(
            text: title,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        )

        valueLabel.font = DJDesignTokens.Font.body(15)
        valueLabel.textColor = DJDesignTokens.Color.textTertiary
        valueLabel.textAlignment = .right
        valueLabel.accessibilityIdentifier = "profile-settings-phone-value"
        phoneValueLabel.isUserInteractionEnabled = false

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -12),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
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

    private func loadUser() {
        let user = UserManager.shared.currentUser
        nameField.text = user?.nickname ?? "寻梦环游用户"
        genderField.text = user?.gender ?? ""
        regionField.text = user?.region ?? ""
        phoneValueLabel.text = user?.maskedPhone ?? "未登录"
    }

    @objc private func saveTapped() {
        [nameField, genderField, regionField].forEach { $0.resignFirstResponder() }

        switch validateProfile(name: nameField.text, gender: genderField.text, region: regionField.text) {
        case .valid(let name, let gender, let region):
            renderSaveState(.saving)
            UserManager.shared.saveProfile(nickname: name, gender: gender, region: region) { [weak self] result in
                guard let self else { return }
                self.loadUser()
                switch result {
                case .saved:
                    self.renderSaveState(.saved)
                case .savedWithRemoteWarning:
                    self.renderSaveState(.networkUnavailable)
                case .failed(let message):
                    self.renderSaveState(.failed(message))
                }
            }
        case .invalid(let message):
            renderSaveState(.invalid(message))
        }
    }

    private func validateProfile(name rawName: String?, gender rawGender: String?, region rawRegion: String?) -> AccountProfileValidationResult {
        let name = (rawName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let gender = normalizedOptionalField(rawGender)
        let region = normalizedOptionalField(rawRegion)

        guard !name.isEmpty else {
            return .invalid("名称不能为空")
        }
        guard name.count <= maxNameLength else {
            return .invalid("名称不能超过24个字")
        }
        if let gender, !allowedGenderValues.contains(gender) {
            return .invalid("性别仅支持：男、女、不便透露")
        }
        if let region, region.count > maxRegionLength {
            return .invalid("地区不能超过32个字")
        }
        return .valid(name: name, gender: gender, region: region)
    }

    private func normalizedOptionalField(_ rawValue: String?) -> String? {
        let value = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func renderSaveState(_ state: ProfileSaveState) {
        saveButton.isEnabled = true
        saveButton.alpha = 1
        saveButton.setTitle("保存", for: .normal)

        switch state {
        case .idle:
            statusLabel.isHidden = true
            statusLabel.text = nil
        case .saving:
            saveButton.isEnabled = false
            saveButton.alpha = 0.68
            saveButton.setTitle("保存中...", for: .normal)
            statusLabel.isHidden = false
            statusLabel.text = "保存中..."
            statusLabel.textColor = DJDesignTokens.Color.textSecondary
        case .saved:
            statusLabel.isHidden = false
            statusLabel.text = "已保存"
            statusLabel.textColor = DJDesignTokens.Color.accentDeep
        case .failed(let message):
            statusLabel.isHidden = false
            statusLabel.text = "保存失败：\(message)"
            statusLabel.textColor = DJDesignTokens.Color.danger
        case .networkUnavailable:
            statusLabel.isHidden = false
            statusLabel.text = "网络异常，已先保存到本机"
            statusLabel.textColor = DJDesignTokens.Color.accent
        case .invalid(let message):
            statusLabel.isHidden = false
            statusLabel.text = message
            statusLabel.textColor = DJDesignTokens.Color.danger
        }
    }

    @objc private func profileFieldDidChange() {
        renderSaveState(.idle)
    }

    @objc private func showAvatarPlaceholder() {
        let alert = UIAlertController(
            title: "头像上传暂未开放",
            message: "当前版本仅展示系统头像，暂不开放相册选择。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func passwordChangeTapped() {
        navigationController?.pushViewController(ProfilePasswordChangeViewController(), animated: true)
    }
}

extension ProfileSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let current = textField.text ?? ""
        guard let textRange = Range(range, in: current) else { return true }
        let nextValue = current.replacingCharacters(in: textRange, with: string)
        if textField === nameField, nextValue.count > maxNameLength {
            renderSaveState(.invalid("名称不能超过24个字"))
            return false
        }
        if textField === regionField, nextValue.count > maxRegionLength {
            renderSaveState(.invalid("地区不能超过32个字"))
            return false
        }
        return true
    }
}
