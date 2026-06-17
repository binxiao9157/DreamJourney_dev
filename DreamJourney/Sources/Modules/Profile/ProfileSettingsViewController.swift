import UIKit

final class ProfileSettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let nicknameField = UITextField()
    private let phoneValueLabel = UILabel()
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
        title = "个人资料设置"
        view.backgroundColor = DJDesignTokens.Color.background
        configureScrollView()
        buildContent()
        loadUser()
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
        contentStack.addArrangedSubview(saveButton)

        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = DJDesignTokens.Color.accent
        saveButton.layer.cornerRadius = 22
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
            text: "当前版本先展示系统头像，后续开放上传与更换。",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

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

    private func makeEditableCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let nicknameRow = makeInputRow(title: "昵称", textField: nicknameField)
        let phoneRow = makeReadonlyRow(title: "手机号", valueLabel: phoneValueLabel)

        let stack = UIStackView(arrangedSubviews: [nicknameRow, makeDivider(), phoneRow])
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
        nicknameField.text = user?.nickname ?? "寻梦环游用户"
        phoneValueLabel.text = user?.maskedPhone ?? "未登录"
    }

    @objc private func saveTapped() {
        UserManager.shared.updateProfile(nickname: nicknameField.text ?? "")
        nicknameField.resignFirstResponder()
        loadUser()

        let alert = UIAlertController(title: "已保存", message: "个人资料已更新。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

extension ProfileSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
