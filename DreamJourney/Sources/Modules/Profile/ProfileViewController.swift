import UIKit

private enum ProfileLayout {
    static let contentTopMargin: CGFloat = 18
    static let contentBottomMargin: CGFloat = 28
    static let contentStackSpacing: CGFloat = 16
    static let afterPersonaSpacing: CGFloat = 16
    static let personaTopPadding: CGFloat = 0
    static let personaBottomPadding: CGFloat = 12
    static let personaAvatarSize: CGFloat = 56
    static let personaAvatarIconSize: CGFloat = 30
    static let personaStatusDotSize: CGFloat = 13
    static let personaStackSpacing: CGFloat = 6
    static let personaTextSpacing: CGFloat = 3
    static let personaTitleFontSize: CGFloat = 18
    static let personaSubtitleFontSize: CGFloat = 11
    static let careCardPadding: CGFloat = 16
    static let careStackSpacing: CGFloat = 10
    static let careTitleFontSize: CGFloat = 18
    static let careSignalHeight: CGFloat = 44
    static let settingsRowMinHeight: CGFloat = 56
}

final class ProfileViewController: UIViewController {

    var didRequestLogout: (() -> Void)?

    private var careSnapshot: ProfileCareSnapshot?
    private var personaContext: DigitalHumanContext
    private let featureFlags: FeatureFlagService

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private var isProfileHiddenBranchesEnabled: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("DJEnableProfileHiddenBranches")
        #else
        return false
        #endif
    }

    private var isCareDoctorContactVisible: Bool {
        isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.careDoctorContact)
    }

    private static let warmTabBarFloatingBottomInset: CGFloat = 16

    private static func profileScrollBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat {
        DJDesignTokens.Spacing.tabBarHeight + warmTabBarFloatingBottomInset + safeAreaBottomInset + DJDesignTokens.Spacing.page
    }

    init(
        careSnapshot: ProfileCareSnapshot? = nil,
        featureFlags: FeatureFlagService = .shared
    ) {
        self.careSnapshot = careSnapshot
        self.personaContext = DigitalHumanContextStore.shared.current
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
        observeDigitalHumanContext()
        configureScrollView()
        buildContent()
        loadCareSnapshot()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProfileScrollInsets()
    }

    private func configureScrollView() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        updateProfileScrollInsets()

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = ProfileLayout.contentStackSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ProfileLayout.contentTopMargin,
            leading: DJDesignTokens.Spacing.page,
            bottom: ProfileLayout.contentBottomMargin,
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

    private func updateProfileScrollInsets() {
        let bottomInset = Self.profileScrollBottomInset(safeAreaBottomInset: view.safeAreaInsets.bottom)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func buildContent() {
        let personaView = makePersonaCard()
        contentStack.addArrangedSubview(personaView)
        contentStack.setCustomSpacing(ProfileLayout.afterPersonaSpacing, after: personaView)

        if featureFlags.isEnabled(.careDashboard) {
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

    private func observeDigitalHumanContext() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(digitalHumanContextDidChange(_:)),
            name: .djDigitalHumanContextDidChange,
            object: nil
        )
    }

    @objc private func digitalHumanContextDidChange(_ notification: Notification) {
        if let context = notification.object as? DigitalHumanContext {
            personaContext = context
        } else {
            personaContext = DigitalHumanContextStore.shared.current
        }
        rebuildContent()
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
                    careSnapshot = .offlineFallback()
                    rebuildContent()
                    return
                }
                careSnapshot = snapshot
                rebuildContent()
            case .failure(let error):
                print("[Profile] care snapshot sync failed: \(error.localizedDescription)")
                careSnapshot = .offlineFallback()
                rebuildContent()
            }
        }
    }

    private func makePersonaCard() -> UIView {
        let container = UIView()

        let avatarContainer = UIView()
        avatarContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.55)
        avatarContainer.layer.cornerRadius = ProfileLayout.personaAvatarSize / 2
        avatarContainer.layer.borderWidth = 2
        avatarContainer.layer.borderColor = DJDesignTokens.Color.divider.cgColor
        DJDesignTokens.applySoftShadow(to: avatarContainer)

        let avatarImageView = UIImageView()
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: ProfileLayout.personaAvatarIconSize, weight: .light)
        avatarImageView.image = UIImage(systemName: "face.smiling", withConfiguration: avatarConfig)
        avatarImageView.tintColor = DJDesignTokens.Color.accentDeep
        avatarImageView.contentMode = .scaleAspectFit

        let statusDot = UIView()
        statusDot.backgroundColor = DJDesignTokens.Color.accent
        statusDot.layer.cornerRadius = ProfileLayout.personaStatusDotSize / 2
        statusDot.layer.borderWidth = 2
        statusDot.layer.borderColor = DJDesignTokens.Color.surface.cgColor

        let context = personaContext

        let titleLabel = makeLabel(
            text: makePersonaTitle(context: context),
            font: DJDesignTokens.Font.title(ProfileLayout.personaTitleFontSize),
            color: DJDesignTokens.Color.textPrimary
        )
        titleLabel.textAlignment = .center

        let subtitleLabel = makeLabel(
            text: makePersonaSubtitle(context: context),
            font: DJDesignTokens.Font.label(ProfileLayout.personaSubtitleFontSize),
            color: DJDesignTokens.Color.textTertiary
        )
        subtitleLabel.textAlignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = ProfileLayout.personaTextSpacing

        let stack = UIStackView(arrangedSubviews: [avatarContainer, textStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = ProfileLayout.personaStackSpacing

        container.addSubview(stack)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(statusDot)
        stack.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: ProfileLayout.personaTopPadding),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -ProfileLayout.personaBottomPadding),

            avatarContainer.widthAnchor.constraint(equalToConstant: ProfileLayout.personaAvatarSize),
            avatarContainer.heightAnchor.constraint(equalToConstant: ProfileLayout.personaAvatarSize),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: ProfileLayout.personaAvatarIconSize + 2),
            avatarImageView.heightAnchor.constraint(equalToConstant: ProfileLayout.personaAvatarIconSize + 2),

            statusDot.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: -2),
            statusDot.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: -2),
            statusDot.widthAnchor.constraint(equalToConstant: ProfileLayout.personaStatusDotSize),
            statusDot.heightAnchor.constraint(equalToConstant: ProfileLayout.personaStatusDotSize),
        ])

        return container
    }

    private func makePersonaTitle(context: DigitalHumanContext) -> String {
        if context.isSelfAssistant {
            return "外面世界很美好"
        }
        return context.resolvedDisplayName
    }

    private func makePersonaSubtitle(context: DigitalHumanContext) -> String {
        if context.isSelfAssistant {
            return "今天又是阳光灿烂的一天"
        }
        if let relation = context.relation,
           !relation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(relation)的回响已连接"
        }
        return "家人数字人的回响已连接"
    }

    private func makeCareCard(snapshot: ProfileCareSnapshot?) -> UIView {
        let card = makeProfileCard()

        let titleLabel = makeLabel(
            text: "心境追踪",
            font: DJDesignTokens.Font.title(ProfileLayout.careTitleFontSize),
            color: DJDesignTokens.Color.textPrimary
        )
        let iconView = UIImageView()
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        iconView.image = UIImage(systemName: "drop", withConfiguration: iconConfig)
        iconView.tintColor = DJDesignTokens.Color.textSecondary
        iconView.contentMode = .scaleAspectFit

        let titleStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 8

        let statusPill = makePill(text: snapshot?.moodStatus ?? "平稳")

        let headerStack = UIStackView(arrangedSubviews: [titleStack, UIView(), statusPill])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 12

        let meterView = ProfileSignalBarView(value: snapshot?.emotionalIndex ?? 0.8, height: ProfileLayout.careSignalHeight)
        let doctorRow = makeDoctorRow()
        let syncCaption = makeCareSyncCaption(snapshot: snapshot)

        let stack = UIStackView(arrangedSubviews: [headerStack, meterView, doctorRow, syncCaption])
        stack.axis = .vertical
        stack.spacing = ProfileLayout.careStackSpacing

        card.addSubview(stack)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ProfileLayout.careCardPadding),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ProfileLayout.careCardPadding),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ProfileLayout.careCardPadding),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ProfileLayout.careCardPadding),
        ])

        return card
    }

    private func makeCareSyncCaption(snapshot: ProfileCareSnapshot?) -> UILabel {
        let label = makeLabel(
            text: snapshot?.syncCaption ?? "关怀数据同步后会更新状态。",
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textTertiary
        )
        label.numberOfLines = 0
        label.accessibilityIdentifier = "profileCareSyncCaption"
        return label
    }

    private func makeSettingsCard() -> UIView {
        let card = makeProfileCard()

        let rows = makeSettingsRows()

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
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DJDesignTokens.Spacing.card),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DJDesignTokens.Spacing.card),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeSettingsRows() -> [ProfileRowAction] {
        var rows: [ProfileRowAction] = []
        if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.profileSettings) {
            rows.append(.profileSettings)
        }
        if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.familyManagement) {
            rows.append(.familyManagement)
        }
        if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.legalCenter) {
            rows.append(.legalCenter)
        }
        rows.append(.logout)
        if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.accountDeletion) {
            rows.append(.accountDeletion)
        }
        return rows
    }

    private func makeDoctorRow() -> UIView {
        let container = UIView()

        let divider = UIView()
        divider.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.28)

        let avatar = UIView()
        avatar.backgroundColor = DJDesignTokens.Color.surfaceLow
        avatar.layer.cornerRadius = 16

        let avatarIcon = UIImageView()
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        avatarIcon.image = UIImage(systemName: "person", withConfiguration: avatarConfig)
        avatarIcon.tintColor = DJDesignTokens.Color.textSecondary
        avatarIcon.contentMode = .scaleAspectFit

        let nameLabel = makeLabel(
            text: "李医生",
            font: DJDesignTokens.Font.label(13),
            color: DJDesignTokens.Color.textPrimary
        )

        var rowViews: [UIView] = [avatar, nameLabel, UIView()]
        if isCareDoctorContactVisible {
            let callButton = UIButton(type: .system)
            callButton.setTitle("立即通话", for: .normal)
            callButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
            callButton.titleLabel?.font = DJDesignTokens.Font.label(13)
            callButton.addTarget(self, action: #selector(doctorCallTapped), for: .touchUpInside)
            rowViews.append(callButton)
        }

        let rowStack = UIStackView(arrangedSubviews: rowViews)
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 8

        container.addSubview(divider)
        container.addSubview(rowStack)
        avatar.addSubview(avatarIcon)
        divider.translatesAutoresizingMaskIntoConstraints = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            rowStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            avatar.widthAnchor.constraint(equalToConstant: 32),
            avatar.heightAnchor.constraint(equalToConstant: 32),

            avatarIcon.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            avatarIcon.widthAnchor.constraint(equalToConstant: 18),
            avatarIcon.heightAnchor.constraint(equalToConstant: 18),
        ])

        return container
    }

    private func makeProfileCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        return card
    }

    private func makePill(text: String) -> UILabel {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.55)
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
            showProfileSettings()
        case .familyManagement:
            openFamilyManagement()
        case .legalCenter:
            showLegalCenter()
        case .logout:
            UserManager.shared.logout()
        case .accountDeletion:
            showUnavailableAlert(
                title: "注销账户暂未开放",
                message: "账号注销需要完整确认与合规流程，后续版本会提供。"
            )
        }
    }

    private func showProfileSettings() {
        let viewController = ProfileSettingsViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showLegalCenter() {
        let viewController = ProfileLegalViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc private func doctorCallTapped() {
        showUnavailableAlert()
    }

    private func openFamilyManagement() {
        guard featureFlags.isEnabled(.familySpace) else {
            showUnavailableAlert(
                title: "家人管理暂未开放",
                message: "当前版本先保留入口，完整家人空间会在后续版本开放。"
            )
            return
        }

        let viewController = FamilyCircleViewController()
        viewController.title = "家人管理"
        viewController.didRequestLogout = didRequestLogout
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showUnavailableAlert(
        title: String = "暂未开放",
        message: String = "该功能正在完善中"
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
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
            return "chevron.right"
        case .familyManagement:
            return "chevron.right"
        case .legalCenter:
            return "chevron.right"
        case .logout:
            return "rectangle.portrait.and.arrow.right"
        case .accountDeletion:
            return "trash"
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

}

private final class ProfileActionRow: UIControl {

    let action: ProfileRowAction

    private let titleLabel = UILabel()
    private let trailingIconView = UIImageView()
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

        titleLabel.text = action.title
        titleLabel.font = DJDesignTokens.Font.body(16)
        titleLabel.textColor = action.isDestructive
            ? DJDesignTokens.Color.danger
            : DJDesignTokens.Color.textPrimary

        let trailingConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        trailingIconView.image = UIImage(systemName: action.iconName, withConfiguration: trailingConfig)
        trailingIconView.tintColor = action.isDestructive
            ? DJDesignTokens.Color.danger.withAlphaComponent(0.72)
            : DJDesignTokens.Color.textTertiary
        trailingIconView.contentMode = .scaleAspectFit

        dividerView.backgroundColor = DJDesignTokens.Color.divider.withAlphaComponent(0.6)
        dividerView.isHidden = isLast

        [titleLabel, trailingIconView, dividerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: ProfileLayout.settingsRowMinHeight),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingIconView.leadingAnchor, constant: -8),

            trailingIconView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingIconView.widthAnchor.constraint(equalToConstant: 18),
            trailingIconView.heightAnchor.constraint(equalToConstant: 18),

            dividerView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dividerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
}

private final class ProfileSignalBarView: UIView {

    private let value: CGFloat
    private let preferredHeight: CGFloat
    private let waveLayer = CAShapeLayer()
    private let thumbLayer = CAShapeLayer()

    init(value: Double, height: CGFloat = ProfileLayout.careSignalHeight) {
        self.value = min(max(CGFloat(value), 0.08), 0.96)
        self.preferredHeight = height
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 8
        let width = max(bounds.width - inset * 2, 1)
        let centerY = bounds.midY
        let path = UIBezierPath()
        path.move(to: CGPoint(x: inset, y: centerY))
        path.addCurve(
            to: CGPoint(x: bounds.maxX - inset, y: centerY),
            controlPoint1: CGPoint(x: inset + width * 0.28, y: centerY - 8),
            controlPoint2: CGPoint(x: inset + width * 0.62, y: centerY + 8)
        )
        waveLayer.path = path.cgPath

        let thumbX = inset + width * value
        thumbLayer.path = UIBezierPath(
            ovalIn: CGRect(x: thumbX - 4, y: centerY - 4, width: 8, height: 8)
        ).cgPath
    }

    private func setupView() {
        backgroundColor = .clear
        waveLayer.fillColor = UIColor.clear.cgColor
        waveLayer.strokeColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.48).cgColor
        waveLayer.lineWidth = 2
        waveLayer.lineCap = .round

        thumbLayer.fillColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.62).cgColor

        layer.addSublayer(waveLayer)
        layer.addSublayer(thumbLayer)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: preferredHeight),
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
