import UIKit

final class ProfileViewController: UIViewController {

    var didRequestLogout: (() -> Void)?

    private var careSnapshot: ProfileCareSnapshot?
    private let featureFlags: FeatureFlagService
    private let privacyText = "仅展示关怀信号，不展示聊天原文"

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(
        careSnapshot: ProfileCareSnapshot? = nil,
        featureFlags: FeatureFlagService = .shared
    ) {
        self.careSnapshot = careSnapshot
        self.featureFlags = featureFlags
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的"
        view.backgroundColor = DJDesignTokens.Color.background
        additionalSafeAreaInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: DJDesignTokens.Spacing.tabBarHeight,
            right: 0
        )
        configureScrollView()
        buildContent()
        loadCareSnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func configureScrollView() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 32,
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
        let titleLabel = makeLabel(
            text: "我的",
            font: DJDesignTokens.Font.display(30),
            color: DJDesignTokens.Color.textPrimary
        )
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(18, after: titleLabel)

        contentStack.addArrangedSubview(makePersonaCard())

        if featureFlags.isEnabled(.careDashboard) {
            let sectionLabel = DJComponentFactory.sectionLabel("长辈关怀")
            sectionLabel.font = DJDesignTokens.Font.title(18)
            sectionLabel.textColor = DJDesignTokens.Color.textSecondary
            contentStack.addArrangedSubview(sectionLabel)
            contentStack.addArrangedSubview(makeCareCard(snapshot: careSnapshot))
        }

        contentStack.addArrangedSubview(makeSettingsCard())
        contentStack.addArrangedSubview(makeBottomSpacer())
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buildContent()
    }

    private func loadCareSnapshot() {
        guard featureFlags.isEnabled(.careDashboard),
              let userId = UserManager.shared.currentUser?.id else {
            return
        }

        DreamJourneyBackendClient.shared.latestCareSnapshot(userId: userId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                guard let snapshot = ProfileCareSnapshot(json: json) else {
                    return
                }
                careSnapshot = snapshot
                rebuildContent()
            case .failure(let error):
                print("[Profile] care snapshot sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func makePersonaCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.extraLarge)

        let avatarContainer = UIView()
        avatarContainer.backgroundColor = DJDesignTokens.Color.surfaceLow
        avatarContainer.layer.cornerRadius = 28
        avatarContainer.layer.borderWidth = 1
        avatarContainer.layer.borderColor = DJDesignTokens.Color.divider.cgColor

        let avatarImageView = UIImageView()
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)
        avatarImageView.image = UIImage(systemName: "person.fill", withConfiguration: avatarConfig)
        avatarImageView.tintColor = DJDesignTokens.Color.accentDeep
        avatarImageView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "外面世界很美好",
            font: DJDesignTokens.Font.title(22),
            color: DJDesignTokens.Color.textPrimary
        )

        let subtitleLabel = makeLabel(
            text: "愿今天也有被记住的温暖",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let pillLabel = makePill(text: "寻梦陪伴")

        let textStack = UIStackView(arrangedSubviews: [pillLabel, titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let rowStack = UIStackView(arrangedSubviews: [avatarContainer, textStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 14

        card.addSubview(rowStack)
        avatarContainer.addSubview(avatarImageView)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),

            avatarContainer.widthAnchor.constraint(equalToConstant: 56),
            avatarContainer.heightAnchor.constraint(equalToConstant: 56),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 30),
            avatarImageView.heightAnchor.constraint(equalToConstant: 30),
        ])

        return card
    }

    private func makeCareCard(snapshot: ProfileCareSnapshot?) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)

        let titleLabel = makeLabel(
            text: snapshot?.moodTitle ?? "心境追踪",
            font: DJDesignTokens.Font.title(20),
            color: DJDesignTokens.Color.textPrimary
        )
        let statusPill = makePill(text: snapshot?.moodStatus ?? "待同步")

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusPill])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 12

        let privacyLabel = makeLabel(
            text: privacyText,
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textTertiary
        )

        var arrangedSubviews: [UIView] = [headerStack, privacyLabel]
        if let snapshot {
            let statusLabel = makeLabel(
                text: "当前关怀信号",
                font: DJDesignTokens.Font.label(12),
                color: DJDesignTokens.Color.textSecondary
            )
            let meterView = ProfileSignalBarView(value: snapshot.emotionalIndex)

            let signalStack = UIStackView(arrangedSubviews: [statusLabel, meterView])
            signalStack.axis = .vertical
            signalStack.spacing = 8

            let metrics = [
                ProfileCareMetric(
                    title: "情绪信号",
                    value: snapshot.emotionalIndex,
                    status: ProfileCareCopy.signalPercent(snapshot.emotionalIndex)
                ),
                ProfileCareMetric(
                    title: "认知互动",
                    value: snapshot.cognitiveIndex,
                    status: ProfileCareCopy.signalPercent(snapshot.cognitiveIndex)
                ),
                ProfileCareMetric(
                    title: "睡眠节律",
                    value: 0,
                    status: snapshot.sleepStatus
                ),
                ProfileCareMetric(
                    title: "陪伴需求",
                    value: snapshot.lonelinessIndex,
                    status: ProfileCareCopy.signalPercent(snapshot.lonelinessIndex)
                ),
            ]

            arrangedSubviews.append(signalStack)
            arrangedSubviews.append(makeMetricsGrid(metrics))
            arrangedSubviews.append(makeReminderView(text: snapshot.riskReminder))
            arrangedSubviews.append(makeDoctorRow())
        } else {
            arrangedSubviews.append(makeCareEmptyState())
        }

        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 14

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: DJDesignTokens.Spacing.card),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DJDesignTokens.Spacing.card),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DJDesignTokens.Spacing.card),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DJDesignTokens.Spacing.card),
        ])

        return card
    }

    private func makeSettingsCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)

        var rows: [ProfileRowAction] = [.profileSettings]
        if featureFlags.isEnabled(.familyManagement) {
            rows.append(.familyManagement)
        }
        if featureFlags.isEnabled(.legalCenter) {
            rows.append(.legalCenter)
        }
        rows.append(.logout)
        if featureFlags.isEnabled(.accountDeletion) {
            rows.append(.accountDeletion)
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0

        for (index, action) in rows.enumerated() {
            let row = ProfileActionRow(action: action, isLast: index == rows.count - 1)
            row.addTarget(self, action: #selector(settingRowTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(row)
        }

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DJDesignTokens.Spacing.card),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DJDesignTokens.Spacing.card),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])

        return card
    }

    private func makeMetricsGrid(_ metrics: [ProfileCareMetric]) -> UIView {
        let firstRow = UIStackView(arrangedSubviews: metrics.prefix(2).map(makeMetricView))
        firstRow.axis = .horizontal
        firstRow.distribution = .fillEqually
        firstRow.spacing = 10

        let secondRow = UIStackView(arrangedSubviews: metrics.dropFirst(2).map(makeMetricView))
        secondRow.axis = .horizontal
        secondRow.distribution = .fillEqually
        secondRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [firstRow, secondRow])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }

    private func makeCareEmptyState() -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let iconView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image = UIImage(systemName: "clock.arrow.circlepath", withConfiguration: config)
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "关怀信号正在同步",
            font: DJDesignTokens.Font.title(16),
            color: DJDesignTokens.Color.textPrimary
        )
        let bodyLabel = makeLabel(
            text: "连接真实数据后，将展示趋势信号与关怀建议。",
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 4

        let rowStack = UIStackView(arrangedSubviews: [iconView, labelStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 10

        container.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    private func makeMetricView(metric: ProfileCareMetric) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let titleLabel = makeLabel(
            text: metric.title,
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textTertiary
        )
        let statusLabel = makeLabel(
            text: metric.status,
            font: DJDesignTokens.Font.title(18),
            color: DJDesignTokens.Color.textPrimary
        )

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        stack.axis = .vertical
        stack.spacing = 4

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])

        return container
    }

    private func makeReminderView(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceContainer
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let iconView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.image = UIImage(systemName: "bell.badge", withConfiguration: config)
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "风险提醒",
            font: DJDesignTokens.Font.label(12),
            color: DJDesignTokens.Color.accentDeep
        )
        let bodyLabel = makeLabel(
            text: text,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 3

        let rowStack = UIStackView(arrangedSubviews: [iconView, labelStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 10

        container.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])

        return container
    }

    private func makeDoctorRow() -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let avatar = UIView()
        avatar.backgroundColor = DJDesignTokens.Color.surface
        avatar.layer.cornerRadius = 19

        let avatarIcon = UIImageView()
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        avatarIcon.image = UIImage(systemName: "stethoscope", withConfiguration: avatarConfig)
        avatarIcon.tintColor = DJDesignTokens.Color.accentDeep
        avatarIcon.contentMode = .scaleAspectFit

        let nameLabel = makeLabel(
            text: "李医生",
            font: DJDesignTokens.Font.title(16),
            color: DJDesignTokens.Color.textPrimary
        )
        let roleLabel = makeLabel(
            text: "关怀建议",
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textTertiary
        )
        let labelStack = UIStackView(arrangedSubviews: [nameLabel, roleLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2

        let callButton = UIButton(type: .system)
        callButton.setTitle("立即通话", for: .normal)
        callButton.setTitleColor(.white, for: .normal)
        callButton.titleLabel?.font = DJDesignTokens.Font.label(14)
        callButton.backgroundColor = DJDesignTokens.Color.accent
        callButton.layer.cornerRadius = 18
        callButton.contentEdgeInsets = UIEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
        callButton.addTarget(self, action: #selector(doctorCallTapped), for: .touchUpInside)

        let rowStack = UIStackView(arrangedSubviews: [avatar, labelStack, UIView(), callButton])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 10

        container.addSubview(rowStack)
        avatar.addSubview(avatarIcon)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            avatar.widthAnchor.constraint(equalToConstant: 38),
            avatar.heightAnchor.constraint(equalToConstant: 38),

            avatarIcon.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            avatarIcon.widthAnchor.constraint(equalToConstant: 22),
            avatarIcon.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    private func makePill(text: String) -> UILabel {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.backgroundColor = DJDesignTokens.Color.surfaceContainer
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeBottomSpacer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 12).isActive = true
        return view
    }

    @objc private func settingRowTapped(_ sender: ProfileActionRow) {
        switch sender.action {
        case .profileSettings:
            showUnavailableAlert()
        case .familyManagement:
            openFamilyManagement()
        case .legalCenter:
            showUnavailableAlert()
        case .logout:
            UserManager.shared.logout()
        case .accountDeletion:
            showUnavailableAlert()
        }
    }

    @objc private func doctorCallTapped() {
        showUnavailableAlert()
    }

    private func openFamilyManagement() {
        guard featureFlags.isEnabled(.familyManagement) else {
            showUnavailableAlert()
            return
        }

        let viewController = FamilyCircleViewController()
        viewController.title = "家人管理"
        viewController.didRequestLogout = didRequestLogout
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showUnavailableAlert() {
        let alert = UIAlertController(
            title: "暂未开放",
            message: "该功能正在完善中",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

private enum ProfileRowAction {
    case profileSettings
    case familyManagement
    case legalCenter
    case logout
    case accountDeletion

    var title: String {
        switch self {
        case .profileSettings:
            return "个人资料设置"
        case .familyManagement:
            return "家人管理"
        case .legalCenter:
            return "法律法规"
        case .logout:
            return "退出登录"
        case .accountDeletion:
            return "注销账户"
        }
    }

    var iconName: String {
        switch self {
        case .profileSettings:
            return "person.text.rectangle"
        case .familyManagement:
            return "person.2"
        case .legalCenter:
            return "doc.text"
        case .logout:
            return "rectangle.portrait.and.arrow.right"
        case .accountDeletion:
            return "person.crop.circle.badge.xmark"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .accountDeletion:
            return true
        case .profileSettings, .familyManagement, .legalCenter, .logout:
            return false
        }
    }

    var showsChevron: Bool {
        switch self {
        case .logout:
            return false
        case .profileSettings, .familyManagement, .legalCenter, .accountDeletion:
            return true
        }
    }
}

private final class ProfileActionRow: UIControl {

    let action: ProfileRowAction

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView()
    private let dividerView = UIView()

    init(action: ProfileRowAction, isLast: Bool) {
        self.action = action
        super.init(frame: .zero)
        setupView(isLast: isLast)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? DJDesignTokens.Color.surfaceLow : .clear
        }
    }

    private func setupView(isLast: Bool) {
        accessibilityTraits = .button
        accessibilityLabel = action.title

        iconContainer.backgroundColor = action.isDestructive
            ? DJDesignTokens.Color.danger.withAlphaComponent(0.08)
            : DJDesignTokens.Color.surfaceLow
        iconContainer.layer.cornerRadius = 17

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: action.iconName, withConfiguration: iconConfig)
        iconView.tintColor = action.isDestructive
            ? DJDesignTokens.Color.danger
            : DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = action.title
        titleLabel.font = DJDesignTokens.Font.body(15)
        titleLabel.textColor = action.isDestructive
            ? DJDesignTokens.Color.danger
            : DJDesignTokens.Color.textPrimary

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevronView.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevronView.tintColor = DJDesignTokens.Color.textTertiary
        chevronView.contentMode = .scaleAspectFit
        chevronView.isHidden = !action.showsChevron

        dividerView.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.6)
        dividerView.isHidden = isLast

        [iconContainer, titleLabel, chevronView, dividerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        iconContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 58),

            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 34),
            iconContainer.heightAnchor.constraint(equalToConstant: 34),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14),

            dividerView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dividerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}

private final class ProfileSignalBarView: UIView {

    private let value: CGFloat
    private let trackView = UIView()
    private let fillView = UIView()
    private let thumbView = UIView()

    init(value: Double) {
        self.value = min(max(CGFloat(value), 0.08), 0.96)
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        trackView.layer.cornerRadius = trackView.bounds.height / 2
        fillView.layer.cornerRadius = fillView.bounds.height / 2
        thumbView.layer.cornerRadius = thumbView.bounds.height / 2
    }

    private func setupView() {
        trackView.backgroundColor = DJDesignTokens.Color.surfaceContainer
        fillView.backgroundColor = DJDesignTokens.Color.accent
        thumbView.backgroundColor = DJDesignTokens.Color.surface
        thumbView.layer.borderWidth = 3
        thumbView.layer.borderColor = DJDesignTokens.Color.accent.cgColor

        [trackView, fillView, thumbView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),

            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 8),

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            fillView.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: value),

            thumbView.centerXAnchor.constraint(equalTo: fillView.trailingAnchor),
            thumbView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 18),
            thumbView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }
}

private final class PaddingLabel: UILabel {

    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
