import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

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
    private let avatarImageView = UIImageView()
    private let avatarStatusLabel = UILabel()
    private var selectedAvatarJPEG: Data?
    private var avatarSelectionID = UUID()
    private var avatarSelectionOwner: (userID: String, sessionID: String)?
    private var avatarBusy = false
    private var profileSaving = false
    private let avatarEditButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private lazy var securityCard = makeSecurityCard()
    private var passwordCapability: BackendPasswordAuthenticationCapability?
    private let maxNameLength = 24
    private let maxRegionLength = 32
    private let allowedGenderValues = ["男", "女", "不便透露"]

    private var isPasswordChangeVisible: Bool {
        guard let passwordCapability else { return false }
        return ProfileFamilyPersonaReleaseReadiness.isPasswordChangeVisible(
            passwordAuthentication: passwordCapability
        )
    }

    init(featureFlags _: FeatureFlagService = .shared) {
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
        loadPasswordAuthenticationCapability()
        UserManager.shared.refreshAvatar { [weak self] in self?.renderAvatar() }
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
        contentStack.addArrangedSubview(securityCard)
        securityCard.isHidden = true
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

        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 34, weight: .light)
        avatarImageView.image = UIImage(systemName: UserManager.shared.currentUser?.avatarName ?? "person.circle.fill", withConfiguration: avatarConfig)
        avatarImageView.tintColor = DJDesignTokens.Color.accentDeep
        avatarImageView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "头像",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
        avatarEditButton.setTitle("从相册选择", for: .normal)
        avatarEditButton.titleLabel?.font = DJDesignTokens.Font.label(13)
        avatarEditButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        avatarEditButton.contentHorizontalAlignment = .left
        avatarEditButton.accessibilityIdentifier = "profile-settings-avatar-picker"
        avatarEditButton.addTarget(self, action: #selector(selectAvatar), for: .touchUpInside)

        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 28
        avatarImageView.accessibilityIdentifier = "profile-settings-avatar-image"
        avatarStatusLabel.font = DJDesignTokens.Font.body(13)
        avatarStatusLabel.textColor = DJDesignTokens.Color.textSecondary
        avatarStatusLabel.numberOfLines = 0
        avatarStatusLabel.accessibilityIdentifier = "profile-settings-avatar-status"
        let textStack = UIStackView(arrangedSubviews: [titleLabel, avatarEditButton, avatarStatusLabel])
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
            avatarImageView.widthAnchor.constraint(equalToConstant: 56),
            avatarImageView.heightAnchor.constraint(equalToConstant: 56),
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
        button.accessibilityLabel = "密码与安全"
        button.accessibilityTraits = .button
        button.addTarget(self, action: #selector(passwordChangeTapped), for: .touchUpInside)

        let titleLabel = makeLabel(
            text: "密码与安全",
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
        renderAvatar()
    }

    @objc private func saveTapped() {
        guard !profileSaving, !avatarBusy else { return }
        [nameField, genderField, regionField].forEach { $0.resignFirstResponder() }
        switch validateProfile(name: nameField.text, gender: genderField.text, region: regionField.text) {
        case .valid(let name, let gender, let region):
            guard let user = UserManager.shared.currentUser,
                  let session = BackendAuthSessionStore.shared.currentSession,
                  session.isPrivateAccessEligible(for: user.id) else {
                renderSaveState(.failed("请先登录后再保存")); return
            }
            let userID = user.id
            let sessionID = session.sessionId
            let jpeg = selectedAvatarJPEG
            if jpeg != nil {
                guard avatarSelectionOwner?.userID == userID,
                      avatarSelectionOwner?.sessionID == sessionID else {
                    cancelAvatarSelection()
                    renderSaveState(.failed("账号状态已变化，请重新选择头像")); return
                }
            }
            profileSaving = true
            renderSaveState(.saving)
            // Retain this authorized save until it settles, even if the page is popped.
            let saveFields: () -> Void = { [self] in
                guard UserManager.shared.currentUser?.id == userID,
                      BackendAuthSessionStore.shared.currentSession?.sessionId == sessionID else {
                    finishProfileSave(.failed("账号状态已变化，请重新进入资料页")); return
                }
                UserManager.shared.saveProfile(nickname: name, gender: gender, region: region) { [self] result in
                    guard UserManager.shared.currentUser?.id == userID,
                          BackendAuthSessionStore.shared.currentSession?.sessionId == sessionID else {
                        finishProfileSave(.failed("账号状态已变化，请重新进入资料页")); return
                    }
                    switch result {
                    case .saved:
                        loadUser()
                        finishProfileSave(.saved)
                    case .savedWithRemoteWarning:
                        if jpeg != nil {
                            finishProfileSave(.failed("头像已保存，其他资料尚未同步，请再次点击保存"))
                        } else {
                            finishProfileSave(.networkUnavailable)
                        }
                    case .failed(let message):
                        finishProfileSave(.failed(jpeg != nil ? "头像已保存，其他资料未保存：\(message)" : message))
                    }
                }
            }
            if let jpeg {
                UserManager.shared.saveAvatar(jpeg: jpeg, expectedUserID: userID, expectedSessionID: sessionID) { [self] result in
                    switch result {
                    case .saved:
                        selectedAvatarJPEG = nil
                        avatarSelectionOwner = nil
                        avatarStatusLabel.text = nil
                        renderAvatar()
                        saveFields()
                    case .failed(let message):
                        finishProfileSave(.failed(message))
                    case .savedWithRemoteWarning:
                        finishProfileSave(.failed("头像未保存成功，请重试"))
                    }
                }
            } else {
                saveFields()
            }
        case .invalid(let message):
            renderSaveState(.invalid(message))
        }
    }

    private func finishProfileSave(_ state: ProfileSaveState) {
        profileSaving = false
        renderSaveState(state)
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
        saveButton.isEnabled = !profileSaving && !avatarBusy
        [nameField, genderField, regionField].forEach { $0.isEnabled = !profileSaving }
        renderAvatar()
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            if !profileSaving {
                avatarSelectionID = UUID()
                selectedAvatarJPEG = nil
                avatarSelectionOwner = nil
            }
        }
    }

    private func renderAvatar() {
        if let owner = avatarSelectionOwner,
           UserManager.shared.currentUser?.id != owner.userID || BackendAuthSessionStore.shared.currentSession?.sessionId != owner.sessionID {
            avatarSelectionID = UUID(); selectedAvatarJPEG = nil; avatarSelectionOwner = nil; avatarBusy = false
        }
        let data = selectedAvatarJPEG ?? UserManager.shared.currentUser?.avatar?.jpegData
        if let data, let image = UIImage(data: data) {
            avatarImageView.image = image
            avatarImageView.contentMode = .scaleAspectFill
        } else {
            avatarImageView.image = UIImage(systemName: UserManager.shared.currentUser?.avatarName ?? "person.circle.fill")
            avatarImageView.contentMode = .scaleAspectFit
        }
        avatarEditButton.isEnabled = !avatarBusy && !profileSaving
        saveButton.isEnabled = !avatarBusy && !profileSaving
        avatarStatusLabel.isHidden = avatarStatusLabel.text?.isEmpty ?? true
    }

    @objc private func selectAvatar() {
        guard let user = UserManager.shared.currentUser,
              let session = BackendAuthSessionStore.shared.currentSession,
              session.isPrivateAccessEligible(for: user.id), !avatarBusy, !profileSaving else { return }
        avatarSelectionOwner = (user.id, session.sessionId)
        avatarSelectionID = UUID()
        avatarStatusLabel.text = nil
        renderAvatar()
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func cancelAvatarSelection() {
        avatarSelectionID = UUID()
        selectedAvatarJPEG = nil
        avatarSelectionOwner = nil
        avatarStatusLabel.text = nil
        renderAvatar()
    }

    @objc private func passwordChangeTapped() {
        guard let passwordCapability, isPasswordChangeVisible else { return }
        navigationController?.pushViewController(
            ProfilePasswordChangeViewController(capability: passwordCapability),
            animated: true
        )
    }

    private func loadPasswordAuthenticationCapability() {
        DreamJourneyBackendClient.shared.fetchRuntimeConfig { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let runtime):
                self.passwordCapability = runtime.passwordAuthentication
            case .failure:
                self.passwordCapability = nil
            }
            self.securityCard.isHidden = !self.isPasswordChangeVisible
            self.securityCard.accessibilityValue = self.isPasswordChangeVisible ? "可用" : "不可用"
        }
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


extension ProfileSettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        let selection = avatarSelectionID
        avatarBusy = true; avatarStatusLabel.text = "正在读取照片…"; renderAvatar()
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
            let jpeg = url.flatMap { try? ProfileAvatarImageProcessor.jpeg(from: $0) }
            DispatchQueue.main.async {
                guard let self, self.avatarSelectionID == selection else { return }
                self.avatarBusy = false
                guard let owner = self.avatarSelectionOwner,
                      UserManager.shared.currentUser?.id == owner.userID,
                      BackendAuthSessionStore.shared.currentSession?.sessionId == owner.sessionID else {
                    self.cancelAvatarSelection(); return
                }
                if let jpeg {
                    self.selectedAvatarJPEG = jpeg
                    self.avatarStatusLabel.text = nil
                    self.renderSaveState(.idle)
                } else {
                    self.avatarStatusLabel.text = "照片读取失败，请选择30MB以内的静态照片后重试"
                }
                self.renderAvatar()
            }
        }
    }
}

enum ProfileAvatarImageProcessor {
    enum Failure: Error { case invalidImage }
    static func jpeg(from url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary) else { throw Failure.invalidImage }
        let image = UIImage(cgImage: cg)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
        let square = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let scale = max(256 / image.size.width, 256 / image.size.height)
            let width = image.size.width * scale, height = image.size.height * scale
            image.draw(in: CGRect(x: (256 - width) / 2, y: (256 - height) / 2, width: width, height: height))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.85), jpeg.count <= 131_072 else { throw Failure.invalidImage }
        return jpeg
    }
}
