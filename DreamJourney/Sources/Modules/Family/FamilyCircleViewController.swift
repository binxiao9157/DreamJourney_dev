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
            return member.isAcceptedFamilyMember ? member.lastUpdated : member.familyInvitationDisplayName
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
            return member.isAcceptedFamilyMember && member.isOnline
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
        FamilyRepository.shared.refreshFromBackend(userId: UserManager.shared.currentUser?.id ?? "user_001") { [weak self] result in
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

        [titleLabel, addButton, inviteSectionLabel, searchContainer, inviteButton,
         circleHeaderLabel, memberCountLabel, membersTableView, sloganLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        tableHeightConstraint = membersTableView.heightAnchor.constraint(equalToConstant: tableHeight)

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
            circleHeaderLabel.topAnchor.constraint(equalTo: inviteButton.bottomAnchor, constant: 28),
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
                showToast(member.familyInvitationDisplayName, type: member.invitationStatus == "failed" ? .error : .info)
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

        [avatarView, nameLabel, relationLabel, updatedLabel, selectButton, boundarySection].forEach {
            content.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        [avatarInitialLabel, boundaryIconView, boundaryTitleLabel, boundaryDescriptionLabel,
         starSwitch, irreversibleNoticeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

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

            selectButton.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 28),
            selectButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            selectButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            selectButton.heightAnchor.constraint(equalToConstant: 48),

            boundarySection.topAnchor.constraint(equalTo: selectButton.bottomAnchor, constant: 20),
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
        let isCurrent = DigitalHumanContextStore.shared.current.ownerId == member.id
            && !DigitalHumanContextStore.shared.current.isSelfAssistant
        selectButton.configuration?.title = member.isAcceptedFamilyMember
            ? (isCurrent ? "当前回响对象" : "设为当前回响对象")
            : member.familyInvitationDisplayName
        selectButton.isEnabled = member.isAcceptedFamilyMember && !isCurrent
        selectButton.configuration?.baseBackgroundColor = isCurrent
            ? UIColor.warmAccent.withAlphaComponent(0.36)
            : .warmAccent
        starSwitch.setOn(member.digitalHumanMode == .star, animated: false)
        boundarySection.backgroundColor = member.digitalHumanMode == .star
            ? UIColor(red: 0.86, green: 0.84, blue: 0.78, alpha: 0.58)
            : UIColor.white.withAlphaComponent(0.84)
        view.accessibilityIdentifier = "familyMemberDetail.\(member.id)"
        starSwitch.accessibilityIdentifier = "familyMemberStarSwitch.\(member.id)"
    }

    @objc private func selectPersonaTapped() {
        onSelectPersona?(member)
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
            footprintButton.setTitle(option.lastUpdated, for: .normal)
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
