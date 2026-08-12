import PhotosUI
import UIKit

private enum FamilyCircleLayout {
    static let rowHeight: CGFloat = 96
}

private enum FamilyPersonaOption {
    case selfAssistant
    case familyMember(FamilyMember)

    var displayName: String {
        switch self {
        case .selfAssistant:
            return "AI 助手"
        case .familyMember(let member):
            return member.name
        }
    }

    var relationLabel: String {
        switch self {
        case .selfAssistant:
            return "自己"
        case .familyMember(let member):
            return member.relation
        }
    }

    var lastUpdated: String {
        switch self {
        case .selfAssistant:
            return "当前回响对象"
        case .familyMember(let member):
            return member.isAcceptedFamilyRelationship ? member.lastUpdated : member.familyInvitationDisplayName
        }
    }

    var unavailableActionLabel: String {
        switch self {
        case .selfAssistant:
            return ""
        case .familyMember(let member):
            return member.familyPersonaAuthorizationDisplayName
        }
    }

    var digitalHumanMode: DigitalHumanMode {
        switch self {
        case .selfAssistant:
            return .sunlight
        case .familyMember(let member):
            return member.digitalHumanMode
        }
    }

    var opensDetail: Bool {
        if case .familyMember = self { return true }
        return false
    }

    var usesSubtleCareTint: Bool {
        if case .familyMember = self, digitalHumanMode == .star {
            return true
        }
        return false
    }

    var isOnline: Bool {
        switch self {
        case .selfAssistant:
            return true
        case .familyMember(let member):
            return member.isAcceptedFamilyRelationship && member.isOnline
        }
    }

    var isSelectable: Bool {
        switch self {
        case .selfAssistant:
            return true
        case .familyMember(let member):
            return member.isAcceptedFamilyMember
        }
    }

    var accessibilitySuffix: String {
        switch self {
        case .selfAssistant:
            return "self"
        case .familyMember(let member):
            return member.id
        }
    }
}

// MARK: - FamilyCircleViewController：亲友页
final class FamilyCircleViewController: UIViewController {

    var didRequestLogout: (() -> Void)?

    // MARK: - UI：顶部标题行
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "选择数字人"
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return l
    }()

    /// 右上角"+"邀请按钮
    private lazy var addButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        b.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        b.tintColor = .warmAccent
        b.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - UI：邀请区
    private let inviteSectionLabel: UILabel = {
        let l = UILabel()
        l.text = "家人管理"
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = UIColor(white: 0.55, alpha: 1.0)
        return l
    }()

    /// 搜索框容器
    private let searchContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        return v
    }()

    private let searchIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        iv.image = UIImage(systemName: "magnifyingglass", withConfiguration: config)
        iv.tintColor = UIColor(white: 0.65, alpha: 1.0)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let searchField: UITextField = {
        let f = UITextField()
        f.placeholder = "输入手机号邀请家人"
        f.font = .systemFont(ofSize: 15)
        f.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        f.returnKeyType = .search
        f.borderStyle = .none
        f.backgroundColor = .clear
        return f
    }()

    /// 手机号邀请按钮
    private lazy var inviteButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = .white
        b.layer.cornerRadius = 12
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.warmAccent.cgColor
        b.layer.masksToBounds = true

        // 图标 + 文字竖向排列（用 UIStackView 构建内容）
        let stampConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let stampIcon = UIImageView(image: UIImage(systemName: "paperplane", withConfiguration: stampConfig))
        stampIcon.tintColor = .warmAccent
        stampIcon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "发送手机号邀请"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .warmAccent
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [stampIcon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false

        b.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: b.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: b.centerYAnchor),
        ])
        b.addTarget(self, action: #selector(copyInviteTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - UI：亲友圈列表
    private let circleHeaderLabel: UILabel = {
        let l = UILabel()
        l.text = "回响对象与状态"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return l
    }()

    private let memberCountLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor(white: 0.55, alpha: 1.0)
        return l
    }()

    private lazy var membersTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(FriendMemberCell.self, forCellReuseIdentifier: "FriendMemberCell")
        tv.dataSource = self
        tv.delegate = self
        tv.isScrollEnabled = false
        return tv
    }()

    private lazy var contributeMemoryButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: "square.and.pencil")
        configuration.imagePadding = 7
        configuration.title = "贡献家庭记忆"
        configuration.baseForegroundColor = .warmAccent
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.accessibilityIdentifier = "familyContributionCreateButton"
        button.addTarget(self, action: #selector(contributeMemoryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var reviewContributionsButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: "tray.full")
        configuration.imagePadding = 7
        configuration.title = "待审核贡献"
        configuration.baseForegroundColor = .warmAccent
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.accessibilityIdentifier = "familyContributionReviewButton"
        button.addTarget(self, action: #selector(reviewContributionsTapped), for: .touchUpInside)
        return button
    }()

    private lazy var contributionActionsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [contributeMemoryButton, reviewContributionsButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.isHidden = true
        return stack
    }()

    // MARK: - UI：底部 slogan
    private let sloganLabel: UILabel = {
        let l = UILabel()
        l.text = "让每一个人的故事都被听见，让每一份回忆都得以传承"
        l.font = .systemFont(ofSize: 12)
        l.textColor = UIColor(white: 0.65, alpha: 1.0)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    // MARK: - Data
    private var members: [FamilyMember] { FamilyRepository.shared.getAll() }
    private var personaOptions: [FamilyPersonaOption] {
        [.selfAssistant] + members.map { .familyMember($0) }
    }
    private var tableHeightConstraint: NSLayoutConstraint?
    private var contributionActionsHeightConstraint: NSLayoutConstraint?
    private var contributorGrants: [FamilyContributionGrantContract] = []
    private var pendingOwnerContributionCount = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        // 自定义 WarmTabBar 高 56pt 不在系统 safeArea 内，显式声明底部 inset，
        // 让 scrollView 的 contentInset 自动避让 TabBar，底部 slogan 不被遮挡
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 56, right: 0)
        setupLayout()
        searchField.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !showPreviousLevelNavigationIfNeeded(animated: animated) {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
        updateMemberListUI()
        refreshFamilyContributionState()
        guard let userId = UserManager.shared.currentUser?.id else { return }
        FamilyRepository.shared.refreshFromBackend(userId: userId) { [weak self] result in
            guard case .success = result else { return }
            self?.updateMemberListUI()
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let content = UIView()
        content.backgroundColor = .clear
        scrollView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // 搜索框内部布局
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchField)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
        ])

        [titleLabel, addButton, inviteSectionLabel, searchContainer, inviteButton, contributionActionsStack,
         circleHeaderLabel, memberCountLabel, membersTableView, sloganLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        tableHeightConstraint = membersTableView.heightAnchor.constraint(equalToConstant: tableHeight)
        contributionActionsHeightConstraint = contributionActionsStack.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // 标题行
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            addButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 32),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            // 邀请区
            inviteSectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            inviteSectionLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            searchContainer.topAnchor.constraint(equalTo: inviteSectionLabel.bottomAnchor, constant: 10),
            searchContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 46),

            inviteButton.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 12),
            inviteButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            inviteButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            inviteButton.heightAnchor.constraint(equalToConstant: 56),

            // 亲友圈列表
            contributionActionsStack.topAnchor.constraint(equalTo: inviteButton.bottomAnchor, constant: 14),
            contributionActionsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            contributionActionsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            contributionActionsHeightConstraint!,

            circleHeaderLabel.topAnchor.constraint(equalTo: contributionActionsStack.bottomAnchor, constant: 24),
            circleHeaderLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            memberCountLabel.centerYAnchor.constraint(equalTo: circleHeaderLabel.centerYAnchor),
            memberCountLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            membersTableView.topAnchor.constraint(equalTo: circleHeaderLabel.bottomAnchor, constant: 12),
            membersTableView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            membersTableView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tableHeightConstraint!,

            // Slogan
            sloganLabel.topAnchor.constraint(equalTo: membersTableView.bottomAnchor, constant: 32),
            sloganLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            sloganLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            sloganLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }

    private var tableHeight: CGFloat {
        CGFloat(personaOptions.count) * FamilyCircleLayout.rowHeight
    }

    private func updateMemberListUI() {
        memberCountLabel.text = "\(personaOptions.count) 位"
        tableHeightConstraint?.constant = tableHeight
        membersTableView.reloadData()
        view.layoutIfNeeded()
    }

    private func refreshFamilyContributionState() {
        guard let user = UserManager.shared.currentUser,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: user.id) else {
            contributorGrants = []
            pendingOwnerContributionCount = 0
            updateFamilyContributionActions()
            return
        }

        DreamJourneyBackendClient.shared.listContributorFamilyContributionGrants(
            accountLease: accountLease
        ) { [weak self] result in
            guard let self,
                  AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else { return }
            if case .success(let grants) = result {
                self.contributorGrants = grants.filter(\.isActive)
            } else {
                self.contributorGrants = []
            }
            self.updateFamilyContributionActions()
        }

        FeatureGateService.shared.refreshPolicy(for: .ownerTruthFamilyContribution) { [weak self] _ in
            guard let self,
                  AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed,
                  FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
                    .ownerTruthFamilyContribution
                  ) else {
                self?.pendingOwnerContributionCount = 0
                self?.updateFamilyContributionActions()
                return
            }
            DreamJourneyBackendClient.shared.listOwnerFamilyContributionSubmissions(
                accountLease: accountLease
            ) { [weak self] result in
                guard let self,
                      AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else { return }
                self.pendingOwnerContributionCount = (try? result.get())?
                    .filter(\.isPendingReview).count ?? 0
                self.updateFamilyContributionActions()
            }
        }
    }

    private func updateFamilyContributionActions() {
        contributeMemoryButton.isHidden = contributorGrants.isEmpty
        reviewContributionsButton.isHidden = pendingOwnerContributionCount == 0
        reviewContributionsButton.configuration?.title = "待审核贡献 \(pendingOwnerContributionCount)"
        contributionActionsStack.isHidden = contributeMemoryButton.isHidden
            && reviewContributionsButton.isHidden
        contributionActionsHeightConstraint?.constant = contributionActionsStack.isHidden ? 0 : 44
    }

    private func isCurrentPersona(_ option: FamilyPersonaOption) -> Bool {
        let current = DigitalHumanContextStore.shared.current
        switch option {
        case .selfAssistant:
            return current.isSelfAssistant
        case .familyMember(let member):
            return !current.isSelfAssistant && current.ownerId == member.id
        }
    }

    // MARK: - Actions
    @objc private func addTapped() {
        // 弹出搜索/邀请弹窗（复用 searchField 聚焦）
        searchField.becomeFirstResponder()
    }

    @objc private func copyInviteTapped() {
        presentFamilyInviteSheet(prefilledPhone: searchField.text)
    }

    @objc private func contributeMemoryTapped() {
        guard let user = UserManager.shared.currentUser,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: user.id),
              !contributorGrants.isEmpty else {
            showToast("当前没有可用的家庭贡献授权", type: .info)
            return
        }
        let openComposer: (FamilyContributionGrantContract) -> Void = { [weak self] grant in
            let composer = FamilyContributionComposerViewController(
                grant: grant,
                accountLease: accountLease
            )
            composer.onSubmissionUpdated = { [weak self] in
                self?.refreshFamilyContributionState()
            }
            self?.navigationController?.pushViewController(composer, animated: true)
        }
        if contributorGrants.count == 1, let grant = contributorGrants.first {
            openComposer(grant)
            return
        }
        let sheet = UIAlertController(
            title: "选择要贡献给的家人",
            message: nil,
            preferredStyle: .actionSheet
        )
        for grant in contributorGrants {
            let relationship = members.first { $0.relationshipId == grant.relationshipId }
            let title = relationship?.name ?? "家人 \(grant.ownerSubjectId.suffix(4))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                openComposer(grant)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = contributeMemoryButton
            popover.sourceRect = contributeMemoryButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func reviewContributionsTapped() {
        guard let user = UserManager.shared.currentUser,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: user.id) else {
            return
        }
        let review = FamilyContributionReviewViewController(accountLease: accountLease)
        review.onReviewUpdated = { [weak self] in
            self?.refreshFamilyContributionState()
        }
        navigationController?.pushViewController(review, animated: true)
    }

    private func selectPersona(option: FamilyPersonaOption) {
        guard let user = UserManager.shared.currentUser else {
            showToast("请先登录后再切换回响对象", type: .info)
            return
        }

        switch option {
        case .selfAssistant:
            DigitalHumanContextStore.shared.current = DigitalHumanContext.defaultContext(userId: user.id)
            showToast("已切换到自己 AI 助手", type: .success)
        case .familyMember(let member):
            guard member.isAcceptedFamilyMember else {
                showToast(
                    member.familyPersonaAuthorizationDisplayName,
                    type: member.invitationStatus == "failed" ? .error : .info
                )
                return
            }
            DigitalHumanContextStore.shared.current = DigitalHumanContext(
                viewerUserId: user.id,
                ownerId: member.id,
                displayName: member.name,
                relation: member.relation,
                mode: member.digitalHumanMode,
                isSelfAssistant: false
            )
            showToast("已切换到 \(member.name) 的回响", type: .success)
        }

        navigationController?.popViewController(animated: true)
    }

    private func openMemberDetail(member: FamilyMember) {
        let detail = FamilyMemberDetailViewController(member: member)
        detail.onSelectPersona = { [weak self] refreshedMember in
            self?.selectPersona(option: .familyMember(refreshedMember))
        }
        detail.onModeChange = { [weak self] member, mode in
            self?.setMode(mode, for: member)
        }
        navigationController?.pushViewController(detail, animated: true)
    }

    private func setMode(_ mode: DigitalHumanMode, for member: FamilyMember) {
        FamilyRepository.shared.updateMode(memberId: member.id, mode: mode)

        if let user = UserManager.shared.currentUser,
           DigitalHumanContextStore.shared.current.ownerId == member.id {
            DigitalHumanContextStore.shared.current = DigitalHumanContext(
                viewerUserId: user.id,
                ownerId: member.id,
                displayName: member.name,
                relation: member.relation,
                mode: mode,
                isSelfAssistant: false
            )
        }

        membersTableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension FamilyCircleViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personaOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendMemberCell", for: indexPath) as! FriendMemberCell
        let option = personaOptions[indexPath.row]
        cell.configure(
            with: option,
            isCurrent: isCurrentPersona(option),
            isLast: indexPath.row == personaOptions.count - 1
        )
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FamilyCircleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        FamilyCircleLayout.rowHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = personaOptions[indexPath.row]
        switch option {
        case .selfAssistant:
            selectPersona(option: option)
        case .familyMember(let member):
            openMemberDetail(member: member)
        }
    }

    private func presentFamilyInviteSheet(prefilledPhone: String?) {
        let alert = UIAlertController(
            title: "邀请家人",
            message: "通过手机号发送邀请。家人加入后不可删除；退出或解除关系暂未开放。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "手机号"
            textField.keyboardType = .phonePad
            textField.text = prefilledPhone?.trimmingCharacters(in: .whitespacesAndNewlines)
            textField.accessibilityIdentifier = "familyInvitePhoneField"
        }
        alert.addTextField { textField in
            textField.placeholder = "称呼，例如 陈岚"
            textField.accessibilityIdentifier = "familyInviteNameField"
        }
        alert.addTextField { textField in
            textField.placeholder = "关系，例如 女儿"
            textField.text = "家人"
            textField.accessibilityIdentifier = "familyInviteRelationField"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "发送邀请", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let phone = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fields = alert?.textFields ?? []
            let name = fields.indices.contains(1) ? fields[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" : ""
            let relation = fields.indices.contains(2) ? fields[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" : ""
            inviteFamilyMember(
                phone: phone,
                name: name.isEmpty ? "家人 \(phone.suffix(4))" : name,
                relation: relation.isEmpty ? "家人" : relation
            )
        })
        present(alert, animated: true)
    }

    private func inviteFamilyMember(phone: String, name: String, relation: String) {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 11 else {
            showToast("请输入有效手机号", type: .error)
            return
        }
        guard let userId = UserManager.shared.currentUser?.id else {
            showToast("请先登录后再邀请家人", type: .info)
            return
        }
        showToast("正在发送邀请", type: .info)
        FamilyRepository.shared.inviteByPhone(
            userId: userId,
            phone: digits,
            name: name,
            relation: relation
        ) { [weak self] result in
            self?.searchField.text = nil
            self?.updateMemberListUI()
            switch result {
            case .success:
                self?.showToast("邀请已发送，等待家人加入", type: .success)
            case .failure:
                self?.showToast("邀请失败，可稍后重试", type: .error)
            }
        }
    }
}

// MARK: - FamilyMemberDetailViewController：家人管理详情
final class FamilyMemberDetailViewController: UIViewController {

    var onModeChange: ((FamilyMember, DigitalHumanMode) -> Void)?
    var onSelectPersona: ((FamilyMember) -> Void)?

    private var member: FamilyMember

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1.0)
        v.layer.cornerRadius = 34
        v.layer.masksToBounds = true
        return v
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = UIColor(red: 0.35, green: 0.28, blue: 0.20, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return label
    }()

    private let relationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.48, alpha: 1.0)
        return label
    }()

    private let updatedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(white: 0.58, alpha: 1.0)
        return label
    }()

    private let voiceStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(red: 0.50, green: 0.35, blue: 0.13, alpha: 1.0)
        label.numberOfLines = 1
        label.accessibilityIdentifier = "familyMemberVoiceStatus"
        return label
    }()

    private lazy var selectButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "person.crop.circle.badge.checkmark")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .warmAccent
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(selectPersonaTapped), for: .touchUpInside)
        return button
    }()

    private lazy var contributionAccessButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: "person.crop.circle.badge.plus")
        configuration.imagePadding = 8
        configuration.title = "允许此家人贡献记忆"
        configuration.baseForegroundColor = .warmAccent
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.accessibilityIdentifier = "familyContributionAccessButton"
        button.addTarget(self, action: #selector(contributionAccessTapped), for: .touchUpInside)
        return button
    }()

    private let boundarySection: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.84)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        return view
    }()

    private let boundaryIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "moon.stars.fill")
        imageView.tintColor = UIColor(red: 0.45, green: 0.39, blue: 0.32, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let boundaryTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "星辰陪伴"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return label
    }()

    private let boundaryDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(white: 0.48, alpha: 1.0)
        label.numberOfLines = 0
        label.text = "开启后会展示心境追踪，并在与该家人或自己 AI 助手互动时使用更谨慎的陪伴边界。"
        return label
    }()

    private lazy var starSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .warmAccent
        toggle.addTarget(self, action: #selector(starSwitchChanged(_:)), for: .valueChanged)
        return toggle
    }()

    private let irreversibleNoticeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor(white: 0.56, alpha: 1.0)
        label.numberOfLines = 0
        label.text = "状态可关闭；家人创建后不可删除。请在确认陪伴关系和家人知情的前提下调整。"
        return label
    }()

    private var familyContributionGrant: FamilyContributionGrantContract?
    private var contributionAccessHeightConstraint: NSLayoutConstraint?

    init(member: FamilyMember) {
        self.member = member
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家人管理"
        view.backgroundColor = .warmBackground
        setupLayout()
        updateContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showPreviousLevelNavigationIfNeeded(animated: animated)
        if let refreshedMember = FamilyRepository.shared.get(by: member.id) {
            member = refreshedMember
            updateContent()
        }
        refreshContributionAccess()
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = UIView()
        scrollView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        avatarView.addSubview(avatarInitialLabel)
        boundarySection.addSubview(boundaryIconView)
        boundarySection.addSubview(boundaryTitleLabel)
        boundarySection.addSubview(boundaryDescriptionLabel)
        boundarySection.addSubview(starSwitch)
        boundarySection.addSubview(irreversibleNoticeLabel)

        [avatarView, nameLabel, relationLabel, updatedLabel, voiceStatusLabel, selectButton,
         contributionAccessButton, boundarySection].forEach {
            content.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        [avatarInitialLabel, boundaryIconView, boundaryTitleLabel, boundaryDescriptionLabel,
         starSwitch, irreversibleNoticeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        contributionAccessHeightConstraint = contributionAccessButton.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scrollView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            avatarView.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            avatarView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            avatarView.widthAnchor.constraint(equalToConstant: 68),
            avatarView.heightAnchor.constraint(equalToConstant: 68),

            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarInitialLabel.widthAnchor.constraint(equalTo: avatarView.widthAnchor),
            avatarInitialLabel.heightAnchor.constraint(equalTo: avatarView.heightAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 5),

            relationLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            relationLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            relationLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),

            updatedLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            updatedLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            updatedLabel.topAnchor.constraint(equalTo: relationLabel.bottomAnchor, constant: 5),

            voiceStatusLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            voiceStatusLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            voiceStatusLabel.topAnchor.constraint(equalTo: updatedLabel.bottomAnchor, constant: 6),

            selectButton.topAnchor.constraint(equalTo: voiceStatusLabel.bottomAnchor, constant: 24),
            selectButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            selectButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            selectButton.heightAnchor.constraint(equalToConstant: 48),

            contributionAccessButton.topAnchor.constraint(equalTo: selectButton.bottomAnchor, constant: 12),
            contributionAccessButton.leadingAnchor.constraint(equalTo: selectButton.leadingAnchor),
            contributionAccessButton.trailingAnchor.constraint(equalTo: selectButton.trailingAnchor),
            contributionAccessHeightConstraint!,

            boundarySection.topAnchor.constraint(equalTo: contributionAccessButton.bottomAnchor, constant: 20),
            boundarySection.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            boundarySection.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            boundarySection.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),

            boundaryIconView.topAnchor.constraint(equalTo: boundarySection.topAnchor, constant: 20),
            boundaryIconView.leadingAnchor.constraint(equalTo: boundarySection.leadingAnchor, constant: 18),
            boundaryIconView.widthAnchor.constraint(equalToConstant: 24),
            boundaryIconView.heightAnchor.constraint(equalToConstant: 24),

            boundaryTitleLabel.leadingAnchor.constraint(equalTo: boundaryIconView.trailingAnchor, constant: 12),
            boundaryTitleLabel.centerYAnchor.constraint(equalTo: boundaryIconView.centerYAnchor),
            boundaryTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: starSwitch.leadingAnchor, constant: -12),

            starSwitch.trailingAnchor.constraint(equalTo: boundarySection.trailingAnchor, constant: -18),
            starSwitch.centerYAnchor.constraint(equalTo: boundaryIconView.centerYAnchor),

            boundaryDescriptionLabel.topAnchor.constraint(equalTo: boundaryIconView.bottomAnchor, constant: 16),
            boundaryDescriptionLabel.leadingAnchor.constraint(equalTo: boundarySection.leadingAnchor, constant: 18),
            boundaryDescriptionLabel.trailingAnchor.constraint(equalTo: boundarySection.trailingAnchor, constant: -18),

            irreversibleNoticeLabel.topAnchor.constraint(equalTo: boundaryDescriptionLabel.bottomAnchor, constant: 14),
            irreversibleNoticeLabel.leadingAnchor.constraint(equalTo: boundaryDescriptionLabel.leadingAnchor),
            irreversibleNoticeLabel.trailingAnchor.constraint(equalTo: boundaryDescriptionLabel.trailingAnchor),
            irreversibleNoticeLabel.bottomAnchor.constraint(equalTo: boundarySection.bottomAnchor, constant: -18),
        ])
    }

    private func updateContent() {
        avatarInitialLabel.text = String(member.name.prefix(1))
        nameLabel.text = member.name
        relationLabel.text = member.relation
        updatedLabel.text = "最近更新: \(member.lastUpdated)"
        voiceStatusLabel.text = "音色: \(member.voiceCloneStatusLabel)"
        let isCurrent = DigitalHumanContextStore.shared.current.ownerId == member.id
            && !DigitalHumanContextStore.shared.current.isSelfAssistant
        selectButton.configuration?.title = member.isAcceptedFamilyMember
            ? (isCurrent ? "当前回响对象" : "设为当前回响对象")
            : member.familyPersonaAuthorizationDisplayName
        selectButton.isEnabled = member.isAcceptedFamilyMember && !isCurrent
        selectButton.configuration?.baseBackgroundColor = isCurrent
            ? UIColor.warmAccent.withAlphaComponent(0.36)
            : .warmAccent
        starSwitch.setOn(member.digitalHumanMode == .star, animated: false)
        starSwitch.isEnabled = member.isAcceptedFamilyMember
        boundarySection.backgroundColor = member.digitalHumanMode == .star
            ? UIColor(red: 0.86, green: 0.84, blue: 0.78, alpha: 0.58)
            : UIColor.white.withAlphaComponent(0.84)
        view.accessibilityIdentifier = "familyMemberDetail.\(member.id)"
        starSwitch.accessibilityIdentifier = "familyMemberStarSwitch.\(member.id)"
    }

    private func refreshContributionAccess() {
        guard member.isAcceptedFamilyRelationship,
              !member.relationshipId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !member.memberSubjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let user = UserManager.shared.currentUser,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: user.id) else {
            contributionAccessButton.isHidden = true
            contributionAccessHeightConstraint?.constant = 0
            return
        }
        FeatureGateService.shared.refreshPolicy(for: .ownerTruthFamilyContribution) { [weak self] _ in
            guard let self,
                  AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed,
                  FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
                    .ownerTruthFamilyContribution
                  ) else {
                self?.contributionAccessButton.isHidden = true
                self?.contributionAccessHeightConstraint?.constant = 0
                return
            }
            DreamJourneyBackendClient.shared.listOwnerFamilyContributionGrants(
                accountLease: accountLease
            ) { [weak self] result in
                guard let self,
                      AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else { return }
                self.familyContributionGrant = (try? result.get())?.first {
                    $0.relationshipId == self.member.relationshipId
                        && $0.contributorSubjectId == self.member.memberSubjectId
                        && $0.isActive
                }
                self.contributionAccessButton.isHidden = false
                self.contributionAccessHeightConstraint?.constant = 44
                self.contributionAccessButton.configuration?.title = self.familyContributionGrant == nil
                    ? "允许此家人贡献记忆"
                    : "撤销记忆贡献权限"
                self.contributionAccessButton.configuration?.image = UIImage(
                    systemName: self.familyContributionGrant == nil
                        ? "person.crop.circle.badge.plus"
                        : "person.crop.circle.badge.minus"
                )
            }
        }
    }

    @objc private func selectPersonaTapped() {
        onSelectPersona?(member)
    }

    @objc private func contributionAccessTapped() {
        guard let user = UserManager.shared.currentUser,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: user.id) else {
            return
        }
        if let grant = familyContributionGrant {
            let alert = UIAlertController(
                title: "撤销贡献权限？",
                message: "撤销后，此家人之前提交但尚未接受的内容会立即隐藏，不能继续提交。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "确认撤销", style: .destructive) { [weak self] _ in
                self?.setContributionAccess(accountLease: accountLease, existingGrant: grant)
            })
            present(alert, animated: true)
        } else {
            setContributionAccess(accountLease: accountLease, existingGrant: nil)
        }
    }

    private func setContributionAccess(
        accountLease: AccountLease,
        existingGrant: FamilyContributionGrantContract?
    ) {
        contributionAccessButton.isEnabled = false
        let completion: (Result<FamilyContributionGrantContract, Error>) -> Void = { [weak self] result in
            guard let self,
                  AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else { return }
            self.contributionAccessButton.isEnabled = true
            switch result {
            case .success(let grant):
                self.familyContributionGrant = grant.isActive ? grant : nil
                self.showToast(
                    grant.isActive ? "已允许此家人贡献记忆" : "贡献权限已撤销",
                    type: .success
                )
                self.refreshContributionAccess()
            case .failure(let error):
                self.showToast("操作失败：\(error.localizedDescription)", type: .error)
            }
        }
        if let existingGrant {
            DreamJourneyBackendClient.shared.revokeOwnerFamilyContributionGrant(
                accountLease: accountLease,
                grant: existingGrant,
                completion: completion
            )
        } else {
            DreamJourneyBackendClient.shared.createOwnerFamilyContributionGrant(
                accountLease: accountLease,
                relationshipId: member.relationshipId,
                contributorSubjectId: member.memberSubjectId,
                completion: completion
            )
        }
    }

    @objc private func starSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            guard member.digitalHumanMode != .star else { return }
            sender.setOn(false, animated: true)
            showEnableStarConfirmation()
        } else if member.digitalHumanMode == .star {
            applyMode(.sunlight)
        }
    }

    private func showEnableStarConfirmation() {
        let alert = UIAlertController(
            title: "确认开启星辰陪伴？",
            message: "这会让系统在该家人的回响中呈现心境追踪，并在切回自己 AI 助手时同步展示。请确认这是经过慎重考虑的陪伴设置。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "再想想", style: .cancel) { [weak self] _ in
            self?.starSwitch.setOn(false, animated: true)
        })
        let confirm = UIAlertAction(title: "确认开启", style: .default) { [weak self] _ in
            self?.applyMode(.star)
        }
        confirm.accessibilityIdentifier = "familyMemberConfirmEnableStar"
        alert.addAction(confirm)
        present(alert, animated: true)
    }

    private func applyMode(_ mode: DigitalHumanMode) {
        member.digitalHumanMode = mode
        onModeChange?(member, mode)
        updateContent()
        let message = mode == .star ? "已开启星辰陪伴" : "已关闭星辰陪伴"
        showToast(message, type: .success)
    }
}

// MARK: - FamilyContributionComposerViewController
final class FamilyContributionComposerViewController: UIViewController, PHPickerViewControllerDelegate {
    var onSubmissionUpdated: (() -> Void)?

    private let grant: FamilyContributionGrantContract
    private let accountLease: AccountLease
    private var selectedImageData: Data?
    private var selectedImageFileName = "family-memory.jpg"

    private let materialControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["文字", "图片"])
        control.selectedSegmentIndex = 0
        control.accessibilityIdentifier = "familyContributionMaterialControl"
        return control
    }()

    private let textView: UITextView = {
        let view = UITextView()
        view.font = .systemFont(ofSize: 17)
        view.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        view.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(white: 0.86, alpha: 1).cgColor
        view.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        view.accessibilityIdentifier = "familyContributionTextView"
        return view
    }()

    private let imagePreview: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.isHidden = true
        imageView.accessibilityIdentifier = "familyContributionImagePreview"
        return imageView
    }()

    private lazy var chooseImageButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "选择一张图片"
        configuration.image = UIImage(systemName: "photo.on.rectangle")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .warmAccent
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.accessibilityIdentifier = "familyContributionChooseImageButton"
        button.addTarget(self, action: #selector(chooseImageTapped), for: .touchUpInside)
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(white: 0.46, alpha: 1)
        label.numberOfLines = 0
        label.text = "提交后需由档案所有者审核；接受前不会进入记忆或回响。"
        label.accessibilityIdentifier = "familyContributionSubmitStatus"
        return label
    }()

    private lazy var submitButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "提交审核"
        configuration.image = UIImage(systemName: "paperplane.fill")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = .warmAccent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "familyContributionSubmitButton"
        button.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        return button
    }()

    init(grant: FamilyContributionGrantContract, accountLease: AccountLease) {
        self.grant = grant
        self.accountLease = accountLease
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "贡献家庭记忆"
        view.backgroundColor = .warmBackground
        showPreviousLevelNavigationIfNeeded(animated: false)
        setupLayout()
        materialControl.addTarget(self, action: #selector(materialChanged), for: .valueChanged)
    }

    private func setupLayout() {
        let recipientLabel = UILabel()
        recipientLabel.text = "提交给家人 · \(grant.ownerSubjectId.suffix(4))"
        recipientLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        recipientLabel.textColor = UIColor(red: 0.30, green: 0.24, blue: 0.18, alpha: 1)

        let stack = UIStackView(arrangedSubviews: [
            recipientLabel,
            materialControl,
            textView,
            chooseImageButton,
            imagePreview,
            statusLabel,
            submitButton,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 190),
            imagePreview.heightAnchor.constraint(equalToConstant: 230),
            chooseImageButton.heightAnchor.constraint(equalToConstant: 48),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    @objc private func materialChanged() {
        let usesImage = materialControl.selectedSegmentIndex == 1
        textView.isHidden = usesImage
        chooseImageButton.isHidden = !usesImage
        imagePreview.isHidden = !usesImage || selectedImageData == nil
        statusLabel.text = usesImage
            ? "图片会先安全上传，档案所有者接受前不会分析或进入回响。"
            : "提交后需由档案所有者审核；接受前不会进入记忆或回响。"
    }

    @objc private func chooseImageTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first,
              result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            let data = image.jpegData(compressionQuality: 0.86)
            DispatchQueue.main.async {
                guard let data, data.count <= 8 * 1024 * 1024 else {
                    self.showToast("图片过大，请选择较小的图片", type: .error)
                    return
                }
                self.selectedImageData = data
                self.selectedImageFileName = "family-memory-\(UUID().uuidString.prefix(8)).jpg"
                self.imagePreview.image = image
                self.imagePreview.isHidden = false
                self.chooseImageButton.configuration?.title = "重新选择图片"
                self.statusLabel.text = "图片已选择，等待提交审核。"
            }
        }
    }

    @objc private func submitTapped() {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            showToast("账号状态已变化，请重新进入", type: .error)
            return
        }
        setSubmitting(true)
        let completion: (Result<FamilyContributionSubmissionContract, Error>) -> Void = { [weak self] result in
            guard let self,
                  AccountLeaseRuntime.shared.validate(self.accountLease, at: .ui).allowed else { return }
            self.setSubmitting(false)
            switch result {
            case .success:
                self.statusLabel.text = "已提交，等待档案所有者审核。"
                self.statusLabel.textColor = UIColor(red: 0.24, green: 0.50, blue: 0.30, alpha: 1)
                self.submitButton.configuration?.title = "已提交"
                self.submitButton.isEnabled = false
                self.onSubmissionUpdated?()
            case .failure(let error):
                self.statusLabel.text = "提交失败：\(error.localizedDescription)。内容仍保留，可重新提交。"
                self.statusLabel.textColor = .systemRed
                self.submitButton.configuration?.title = "重新提交"
            }
        }
        if materialControl.selectedSegmentIndex == 0 {
            let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                setSubmitting(false)
                showToast("请输入要贡献的记忆", type: .info)
                return
            }
            DreamJourneyBackendClient.shared.submitFamilyContributionText(
                accountLease: accountLease,
                grant: grant,
                text: text,
                completion: completion
            )
        } else {
            guard let selectedImageData else {
                setSubmitting(false)
                showToast("请先选择图片", type: .info)
                return
            }
            DreamJourneyBackendClient.shared.submitFamilyContributionImage(
                accountLease: accountLease,
                grant: grant,
                fileName: selectedImageFileName,
                contentType: "image/jpeg",
                content: selectedImageData,
                completion: completion
            )
        }
    }

    private func setSubmitting(_ submitting: Bool) {
        submitButton.isEnabled = !submitting
        materialControl.isEnabled = !submitting
        textView.isEditable = !submitting
        chooseImageButton.isEnabled = !submitting
        submitButton.configuration?.showsActivityIndicator = submitting
        if submitting {
            submitButton.configuration?.title = "正在提交"
            statusLabel.text = "正在安全提交，请稍候。"
            statusLabel.textColor = UIColor(white: 0.46, alpha: 1)
        }
    }
}

// MARK: - FamilyContributionReviewViewController
final class FamilyContributionReviewViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onReviewUpdated: (() -> Void)?

    private let accountLease: AccountLease
    private var submissions: [FamilyContributionSubmissionContract] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无待审核的家庭贡献"
        label.font = .systemFont(ofSize: 15)
        label.textColor = UIColor(white: 0.52, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    init(accountLease: AccountLease) {
        self.accountLease = accountLease
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家庭贡献审核"
        view.backgroundColor = .warmBackground
        showPreviousLevelNavigationIfNeeded(animated: false)
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "familyContributionReviewList"
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
        loadSubmissions()
    }

    @objc private func refreshTapped() {
        loadSubmissions()
    }

    private func loadSubmissions() {
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else { return }
        navigationItem.rightBarButtonItem?.isEnabled = false
        DreamJourneyBackendClient.shared.listOwnerFamilyContributionSubmissions(
            accountLease: accountLease
        ) { [weak self] result in
            guard let self,
                  AccountLeaseRuntime.shared.validate(self.accountLease, at: .ui).allowed else { return }
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            switch result {
            case .success(let rows):
                self.submissions = rows
                    .filter { $0.status != "withdrawn" }
                    .sorted { lhs, rhs in
                        if lhs.isPendingReview != rhs.isPendingReview { return lhs.isPendingReview }
                        return lhs.submissionId < rhs.submissionId
                    }
                self.tableView.backgroundView = self.submissions.isEmpty ? self.emptyLabel : nil
                self.tableView.reloadData()
            case .failure(let error):
                self.emptyLabel.text = "加载失败：\(error.localizedDescription)\n可点击右上角重试"
                self.tableView.backgroundView = self.emptyLabel
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        submissions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "familyContributionReviewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let item = submissions[indexPath.row]
        cell.textLabel?.text = item.materialKind == "text"
            ? (item.text ?? "文字记忆")
            : "图片记忆"
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = Self.statusText(item)
        let canOpen = item.isPendingReview || item.handoff.canOpenCandidateReview
        cell.accessoryType = canOpen ? .disclosureIndicator : .none
        cell.selectionStyle = canOpen ? .default : .none
        cell.accessibilityIdentifier = "familyContributionReviewItem.\(item.submissionId)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = submissions[indexPath.row]
        if item.handoff.canOpenCandidateReview {
            openCandidateReview(item)
            return
        }
        guard item.isPendingReview else { return }
        if item.materialKind == "image" {
            showImageReview(item)
        } else {
            showReviewDecision(item, image: nil)
        }
    }

    private func showImageReview(_ submission: FamilyContributionSubmissionContract) {
        showToast("正在读取图片", type: .info)
        DreamJourneyBackendClient.shared.readOwnerFamilyContributionImage(
            accountLease: accountLease,
            submission: submission
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    self.showToast("图片格式无法读取", type: .error)
                    return
                }
                self.showReviewDecision(submission, image: image)
            case .failure(let error):
                self.showToast("图片读取失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    private func showReviewDecision(
        _ submission: FamilyContributionSubmissionContract,
        image: UIImage?
    ) {
        let review = FamilyContributionDecisionViewController(
            submission: submission,
            image: image
        )
        review.onDecision = { [weak self, weak review] accepted in
            review?.setSubmitting(true)
            self?.decide(submission, accepted: accepted) { success in
                review?.setSubmitting(false)
                if success {
                    review?.dismiss(animated: true)
                }
            }
        }
        present(review, animated: true)
    }

    private func decide(
        _ submission: FamilyContributionSubmissionContract,
        accepted: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        DreamJourneyBackendClient.shared.reviewOwnerFamilyContributionSubmission(
            accountLease: accountLease,
            submission: submission,
            accepted: accepted
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.showToast(accepted ? "已接受，等待生成正式记忆" : "已拒绝此贡献", type: .success)
                self.onReviewUpdated?()
                self.loadSubmissions()
                completion(true)
            case .failure(let error):
                self.showToast("审核失败：\(error.localizedDescription)", type: .error)
                completion(false)
            }
        }
    }

    private func openCandidateReview(_ submission: FamilyContributionSubmissionContract) {
        guard let sourceId = submission.handoff.sourceId,
              let sourceUUID = UUID(uuidString: sourceId) else {
            showToast("候选记忆尚未准备完成", type: .info)
            return
        }
        let inbox = OwnerTruthCandidateInboxViewController(
            accountLease: accountLease,
            sourceIDFilter: OwnerTruthRecordID(rawValue: sourceUUID)
        )
        navigationController?.pushViewController(inbox, animated: true)
    }

    private static func statusText(_ submission: FamilyContributionSubmissionContract) -> String {
        switch submission.handoff.status {
        case .ownerReviewPending: return "等待审核"
        case .ownerRejected: return "已拒绝"
        case .withdrawn: return "授权已撤回"
        case .mediaProcessing: return "图片处理中"
        case .mediaProcessingFailed: return "图片处理失败，可稍后重试"
        case .candidateExtractionRequested: return "正在整理候选记忆"
        case .candidatePendingReview: return "候选记忆待确认"
        case .candidateRejected: return "候选记忆未采纳"
        case .memoryActivationPending: return "正式记忆生成中"
        case .memoryCurrent: return "已成为正式记忆"
        }
    }
}

private final class FamilyContributionDecisionViewController: UIViewController {
    var onDecision: ((Bool) -> Void)?

    private let submission: FamilyContributionSubmissionContract
    private let image: UIImage?
    private lazy var acceptButton = makeButton(
        title: "接受并进入候选记忆",
        style: .filled(),
        accepted: true
    )
    private lazy var rejectButton = makeButton(title: "拒绝", style: .tinted(), accepted: false)

    init(submission: FamilyContributionSubmissionContract, image: UIImage?) {
        self.submission = submission
        self.image = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        let titleLabel = UILabel()
        titleLabel.text = "审核家庭贡献"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)

        let contentView: UIView
        if let image {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.layer.cornerRadius = 10
            imageView.layer.masksToBounds = true
            contentView = imageView
        } else {
            let label = UILabel()
            label.text = submission.text
            label.font = .systemFont(ofSize: 17)
            label.numberOfLines = 0
            label.backgroundColor = UIColor.white.withAlphaComponent(0.82)
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            contentView = label
        }
        let notice = UILabel()
        notice.text = "接受后内容才会进入候选记忆，仍需按正式记忆流程确认。"
        notice.font = .systemFont(ofSize: 13)
        notice.textColor = UIColor(white: 0.48, alpha: 1)
        notice.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, contentView, notice, acceptButton, rejectButton])
        stack.axis = .vertical
        stack.spacing = 14
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            acceptButton.heightAnchor.constraint(equalToConstant: 48),
            rejectButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    func setSubmitting(_ submitting: Bool) {
        acceptButton.isEnabled = !submitting
        rejectButton.isEnabled = !submitting
        acceptButton.configuration?.showsActivityIndicator = submitting
    }

    private func makeButton(
        title: String,
        style: UIButton.Configuration,
        accepted: Bool
    ) -> UIButton {
        var configuration = style
        configuration.title = title
        configuration.baseBackgroundColor = accepted ? .warmAccent : nil
        configuration.baseForegroundColor = accepted ? .white : .warmAccent
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak self] _ in self?.onDecision?(accepted) }, for: .touchUpInside)
        return button
    }
}

// MARK: - UITextFieldDelegate
extension FamilyCircleViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let phone = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if phone.isEmpty {
            showToast("请输入手机号", type: .info)
        } else {
            presentFamilyInviteSheet(prefilledPhone: phone)
        }
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - FriendMemberCell：亲友列表行
final class FriendMemberCell: UITableViewCell {

    private let rowTintView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 18
        v.layer.masksToBounds = true
        return v
    }()

    // MARK: 头像容器（带在线状态圆点）
    private let avatarContainer: UIView = {
        let v = UIView()
        return v
    }()

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.88, alpha: 1.0)
        v.layer.cornerRadius = 28
        v.layer.masksToBounds = true
        return v
    }()

    private let avatarInitialLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .medium)
        l.textColor = UIColor(white: 0.45, alpha: 1.0)
        l.textAlignment = .center
        return l
    }()

    /// 在线状态圆点（右下角）
    private let onlineDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 6
        v.layer.masksToBounds = true
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.warmBackground.cgColor
        return v
    }()

    // MARK: 文字区域
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        return l
    }()

    /// 关系标签（橙色小胶囊）
    private let relationLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = .warmAccent
        l.backgroundColor = UIColor.warmAccent.withAlphaComponent(0.12)
        l.layer.cornerRadius = 8
        l.layer.masksToBounds = true
        l.textAlignment = .center
        return l
    }()

    private let lastUpdatedLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = UIColor(white: 0.60, alpha: 1.0)
        return l
    }()

    // MARK: 查看足迹按钮
    private let footprintButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("切换", for: .normal)
        b.setTitleColor(UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0), for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        b.backgroundColor = .white
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor(white: 0.82, alpha: 1.0).cgColor
        b.layer.masksToBounds = true
        b.isUserInteractionEnabled = false

        // 右箭头
        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        arrow.tintColor = UIColor(white: 0.55, alpha: 1.0)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        b.addSubview(arrow)
        NSLayoutConstraint.activate([
            arrow.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -10),
        ])
        return b
    }()

    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
        return v
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(rowTintView)
        avatarContainer.addSubview(avatarView)
        avatarContainer.addSubview(onlineDot)
        avatarView.addSubview(avatarInitialLabel)

        contentView.addSubview(avatarContainer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(relationLabel)
        contentView.addSubview(lastUpdatedLabel)
        contentView.addSubview(footprintButton)
        contentView.addSubview(divider)

        [rowTintView, avatarContainer, avatarView, onlineDot, avatarInitialLabel,
         nameLabel, relationLabel, lastUpdatedLabel, footprintButton, divider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        relationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            rowTintView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            rowTintView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            rowTintView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            rowTintView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            // 头像容器
            avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: 60),
            avatarContainer.heightAnchor.constraint(equalToConstant: 60),

            avatarView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarInitialLabel.widthAnchor.constraint(equalTo: avatarView.widthAnchor),
            avatarInitialLabel.heightAnchor.constraint(equalTo: avatarView.heightAnchor),

            // 在线状态圆点（右下角）
            onlineDot.widthAnchor.constraint(equalToConstant: 12),
            onlineDot.heightAnchor.constraint(equalToConstant: 12),
            onlineDot.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            onlineDot.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),

            // 姓名
            nameLabel.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            // 关系胶囊
            relationLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            relationLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            relationLabel.heightAnchor.constraint(equalToConstant: 18),
            relationLabel.trailingAnchor.constraint(lessThanOrEqualTo: footprintButton.leadingAnchor, constant: -8),

            // 上次更新
            lastUpdatedLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            lastUpdatedLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            lastUpdatedLabel.trailingAnchor.constraint(lessThanOrEqualTo: footprintButton.leadingAnchor, constant: -12),

            // 查看足迹按钮
            footprintButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footprintButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            footprintButton.widthAnchor.constraint(equalToConstant: 78),
            footprintButton.heightAnchor.constraint(equalToConstant: 30),

            // 分割线
            divider.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    fileprivate func configure(
        with option: FamilyPersonaOption,
        isCurrent: Bool,
        isLast: Bool
    ) {
        // 头像首字
        avatarInitialLabel.text = String(option.displayName.prefix(1))

        // 在线状态圆点颜色
        onlineDot.backgroundColor = option.isOnline
            ? UIColor(red: 0.20, green: 0.75, blue: 0.30, alpha: 1.0)
            : UIColor(white: 0.75, alpha: 1.0)

        nameLabel.text = option.displayName

        // 关系标签内边距
        let padding = "  \(option.relationLabel)  "
        relationLabel.text = padding

        lastUpdatedLabel.text = option.opensDetail ? "最近更新: \(option.lastUpdated)" : option.lastUpdated
        accessibilityIdentifier = "familyPersonaOption.\(option.accessibilitySuffix)"
        if isCurrent {
            accessibilityLabel = "当前回响对象，\(option.displayName)"
        } else if option.opensDetail {
            accessibilityLabel = "进入\(option.displayName)的家人管理"
        } else {
            accessibilityLabel = "切换到\(option.displayName)"
        }

        if isCurrent {
            footprintButton.setTitle("当前", for: .normal)
        } else if !option.isSelectable {
            footprintButton.setTitle(option.unavailableActionLabel, for: .normal)
        } else {
            footprintButton.setTitle(option.opensDetail ? "管理" : "切换", for: .normal)
        }
        footprintButton.backgroundColor = isCurrent
            ? UIColor.warmAccent.withAlphaComponent(0.14)
            : (option.isSelectable ? .white : UIColor.warmAccent.withAlphaComponent(0.10))
        footprintButton.setTitleColor(
            isCurrent || !option.isSelectable ? .warmAccent : UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0),
            for: .normal
        )

        rowTintView.backgroundColor = option.usesSubtleCareTint
            ? UIColor(red: 0.62, green: 0.57, blue: 0.49, alpha: 0.14)
            : .clear

        // 最后一行不显示分割线
        divider.isHidden = isLast
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rowTintView.backgroundColor = .clear
        avatarInitialLabel.text = nil
        nameLabel.text = nil
        relationLabel.text = nil
        lastUpdatedLabel.text = nil
        footprintButton.setTitle("切换", for: .normal)
        footprintButton.backgroundColor = .white
        footprintButton.setTitleColor(UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0), for: .normal)
        divider.isHidden = false
    }
}

// MARK: - 保留兼容旧注册（空 stub）
final class FamilyMembersCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) { fatalError() }
}
