import UIKit

// MARK: - FamilyCircleViewController：亲友页
final class FamilyCircleViewController: UIViewController {

    var didRequestLogout: (() -> Void)?

    // MARK: - UI：顶部标题行
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "亲友"
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
        l.text = "邀请新成员 / 接受邀请"
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
        f.placeholder = "搜索手机号添加家人..."
        f.font = .systemFont(ofSize: 15)
        f.textColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        f.returnKeyType = .search
        f.borderStyle = .none
        f.backgroundColor = .clear
        return f
    }()

    /// 复制邀请邮票按钮
    private lazy var inviteButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = .white
        b.layer.cornerRadius = 12
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.warmAccent.cgColor
        b.layer.masksToBounds = true

        // 图标 + 文字竖向排列（用 UIStackView 构建内容）
        let stampConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let stampIcon = UIImageView(image: UIImage(systemName: "checkmark.seal", withConfiguration: stampConfig))
        stampIcon.tintColor = .warmAccent
        stampIcon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "复制邀请邮票"
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

    private lazy var quickActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        FamilyCircleQuickAction.defaultActions.forEach { action in
            stack.addArrangedSubview(makeQuickActionButton(for: action))
        }
        return stack
    }()

    // MARK: - UI：亲友圈列表
    private let circleHeaderLabel: UILabel = {
        let l = UILabel()
        l.text = "我的亲友圈"
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
    private var membersTableHeightConstraint: NSLayoutConstraint?

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
        syncFamilyMembersFromBackend(showErrors: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        updateMemberListUI()
        syncFamilyMembersFromBackend(showErrors: false)
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
         quickActionsStack, circleHeaderLabel, memberCountLabel, membersTableView, sloganLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        let rowHeight: CGFloat = 80
        let tableHeightConstraint = membersTableView.heightAnchor.constraint(equalToConstant: CGFloat(members.count) * rowHeight)
        membersTableHeightConstraint = tableHeightConstraint

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

            quickActionsStack.topAnchor.constraint(equalTo: inviteButton.bottomAnchor, constant: 12),
            quickActionsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            quickActionsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            // 亲友圈列表
            circleHeaderLabel.topAnchor.constraint(equalTo: quickActionsStack.bottomAnchor, constant: 28),
            circleHeaderLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            memberCountLabel.centerYAnchor.constraint(equalTo: circleHeaderLabel.centerYAnchor),
            memberCountLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            membersTableView.topAnchor.constraint(equalTo: circleHeaderLabel.bottomAnchor, constant: 12),
            membersTableView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            membersTableView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tableHeightConstraint,

            // Slogan
            sloganLabel.topAnchor.constraint(equalTo: membersTableView.bottomAnchor, constant: 32),
            sloganLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            sloganLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            sloganLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }

    // MARK: - Actions
    @objc private func addTapped() {
        let alert = UIAlertController(title: "亲友邀请", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "输入手机号", style: .default) { [weak self] _ in
            self?.searchField.becomeFirstResponder()
        })
        alert.addAction(UIAlertAction(title: "接受邀请", style: .default) { [weak self] _ in
            self?.acceptInvitationFromCurrentInput()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = addButton
            popover.sourceRect = addButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func copyInviteTapped() {
        let phone = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty else {
            showToast("请先输入要邀请的手机号", type: .info)
            searchField.becomeFirstResponder()
            return
        }

        FamilyRepository.shared.inviteBackendMember(
            name: "",
            relation: "亲友",
            phone: phone
        ) { [weak self] result in
            switch result {
            case .success(let invitation):
                let invitationCode = invitation.invitationCode
                UIPasteboard.general.string = invitation.shareText
                self?.searchField.text = nil
                self?.updateMemberListUI()
                self?.showToast("已复制 \(invitation.member.name) 的邀请码 \(invitationCode)", type: .success)
            case .failure(let error):
                self?.showToast(error.localizedDescription, type: .error)
            }
        }
    }

    @objc private func careDashboardTapped() {
        navigationController?.navigationBar.isHidden = false
        navigationController?.pushViewController(CareDashboardViewController(), animated: true)
    }

    @objc private func familyFootprintTapped() {
        let currentUserId = UserManager.shared.currentUser?.id ?? ""
        let ownerName = UserManager.shared.currentUser?.nickname ?? "全家"
        let viewController = MapFootprintViewController(
            viewMode: .guest,
            ownerId: currentUserId,
            ownerName: ownerName
        )
        viewController.title = "家族足迹地图"
        navigationController?.navigationBar.isHidden = false
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func acceptInvitationFromCurrentInput() {
        acceptInvitation(phone: searchField.text)
    }

    func acceptInvitationCodeFromDeepLink(_ invitationCode: String) {
        searchField.text = invitationCode
        acceptInvitation(phone: invitationCode)
    }

    private func acceptInvitation(phone rawPhone: String?) {
        let phone = rawPhone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty else {
            showToast("请输入手机号、邀请码或邀请链接后接受邀请", type: .info)
            searchField.becomeFirstResponder()
            return
        }
        if FamilyRepository.shared.invitationCode(from: phone) != nil {
            FamilyRepository.shared.acceptBackendInvitationCode(phone) { [weak self] result in
                switch result {
                case .success(let acceptedMember):
                    self?.searchField.text = nil
                    self?.updateMemberListUI()
                    self?.showToast("已通过邀请码加入 \(acceptedMember.name) 的亲友圈", type: .success)
                case .failure(let error):
                    self?.showToast(error.localizedDescription, type: .error)
                }
            }
            return
        }
        FamilyRepository.shared.acceptBackendInvitation(phone: phone) { [weak self] result in
            switch result {
            case .success(let acceptedMember):
                self?.searchField.text = nil
                self?.updateMemberListUI()
                self?.showToast("已接受 \(acceptedMember.name) 的亲友邀请", type: .success)
            case .failure(let error):
                self?.showToast(error.localizedDescription, type: .error)
            }
        }
    }

    private func makeQuickActionButton(for action: FamilyCircleQuickAction) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.warmDivider.cgColor
        button.accessibilityLabel = action.accessibilityLabel

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: action.iconName, withConfiguration: iconConfig))
        icon.tintColor = .warmAccent
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = action.title
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .warmPrimary

        let subtitle = UILabel()
        subtitle.text = action.subtitle
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .warmSubtitle

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 2

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        arrow.tintColor = .warmSubtitle
        arrow.contentMode = .scaleAspectFit

        let row = UIStackView(arrangedSubviews: [icon, textStack, UIView(), arrow])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false

        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            arrow.widthAnchor.constraint(equalToConstant: 14),
            row.topAnchor.constraint(equalTo: button.topAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -10),
            button.heightAnchor.constraint(equalToConstant: 64),
        ])

        switch action.kind {
        case .careDashboard:
            button.addTarget(self, action: #selector(careDashboardTapped), for: .touchUpInside)
        case .familyFootprint:
            button.addTarget(self, action: #selector(familyFootprintTapped), for: .touchUpInside)
        }

        return button
    }

    private func openCareDashboard(for member: FamilyMember) {
        guard member.isCareDashboardAccessible,
              !FamilyRepository.shared.isAccessRevoked(for: member.id) else {
            showToast(member.isAccessRevoked ? "\(member.name) 的访问权限已撤回" : "\(member.name) 尚未接受邀请", type: .info)
            return
        }
        navigationController?.navigationBar.isHidden = false
        navigationController?.pushViewController(
            CareDashboardViewController(viewerFamilyMemberID: member.id),
            animated: true
        )
    }

    private func revokeAccess(for member: FamilyMember) {
        guard !FamilyRepository.shared.isAccessRevoked(for: member.id) else {
            showToast("\(member.name) 的访问权限已撤回", type: .info)
            return
        }

        let revokedMetadata = FamilyAccessControlService.revokeMemberAccess(
            from: MemoryPrivacyMetadata(scope: .familyCircle, familyVisibility: .allMembers),
            revokedMemberID: member.id,
            allFamilyMemberIDs: members.map(\.id)
        )
        let remainingVisibleCount = revokedMetadata.familyVisibility.allowedMemberIDs.count

        let alert = UIAlertController(
            title: "撤回 \(member.name) 的访问权限？",
            message: "撤回后，当前访问者身份不会再匹配该成员，后续分享/关怀入口也会避开该成员视角。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "撤回访问", style: .destructive) { [weak self] _ in
            FamilyRepository.shared.revokeBackendAccess(for: member.id) { result in
                switch result {
                case .success:
                    self?.updateMemberListUI()
                    self?.showToast("已撤回 \(member.name) 的访问权限，剩余 \(remainingVisibleCount) 位可见", type: .success)
                case .failure(let error):
                    self?.showToast(error.localizedDescription, type: .error)
                }
            }
        })
        present(alert, animated: true)
    }

    private func syncFamilyMembersFromBackend(showErrors: Bool) {
        FamilyRepository.shared.syncFromBackend { [weak self] result in
            switch result {
            case .success:
                self?.updateMemberListUI()
            case .failure(let error):
                if showErrors {
                    self?.showToast(error.localizedDescription, type: .error)
                }
            }
        }
    }

    private func updateMemberListUI() {
        memberCountLabel.text = "\(members.count) 位成员"
        membersTableHeightConstraint?.constant = CGFloat(members.count) * 80
        membersTableView.reloadData()
    }

}

// MARK: - UITableViewDataSource
extension FamilyCircleViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendMemberCell", for: indexPath) as! FriendMemberCell
        let member = members[indexPath.row]
        cell.configure(
            with: member,
            isLast: indexPath.row == members.count - 1,
            isAccessRevoked: FamilyRepository.shared.isAccessRevoked(for: member.id) || member.isAccessRevoked
        )
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FamilyCircleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 80 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let member = members[indexPath.row]
        openCareDashboard(for: member)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let member = members[indexPath.row]
        guard !FamilyRepository.shared.isAccessRevoked(for: member.id),
              !member.isAccessRevoked else {
            return nil
        }

        let revoke = UIContextualAction(style: .destructive, title: "撤回") { [weak self] _, _, completion in
            self?.revokeAccess(for: member)
            completion(true)
        }
        revoke.image = UIImage(systemName: "person.crop.circle.badge.xmark")
        return UISwipeActionsConfiguration(actions: [revoke])
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let member = members[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let care = UIAction(
                title: "查看关怀看板",
                image: UIImage(systemName: "heart.text.square")
            ) { _ in
                self?.openCareDashboard(for: member)
            }
            let revoke = UIAction(
                title: member.isAccessRevoked || FamilyRepository.shared.isAccessRevoked(for: member.id) ? "访问已撤回" : "撤回访问",
                image: UIImage(systemName: "person.crop.circle.badge.xmark"),
                attributes: member.isAccessRevoked || FamilyRepository.shared.isAccessRevoked(for: member.id) ? [.disabled] : [.destructive]
            ) { _ in
                self?.revokeAccess(for: member)
            }
            return UIMenu(title: member.name, children: [care, revoke])
        }
    }
}

// MARK: - UITextFieldDelegate
extension FamilyCircleViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let phone = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if phone.isEmpty {
            showToast("请输入手机号", type: .info)
        } else {
            acceptInvitation(phone: phone)
        }
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - FriendMemberCell：亲友列表行
final class FriendMemberCell: UITableViewCell {

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

    // MARK: 关怀看板按钮
    private let footprintButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("关怀看板", for: .normal)
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

        avatarContainer.addSubview(avatarView)
        avatarContainer.addSubview(onlineDot)
        avatarView.addSubview(avatarInitialLabel)

        contentView.addSubview(avatarContainer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(relationLabel)
        contentView.addSubview(lastUpdatedLabel)
        contentView.addSubview(footprintButton)
        contentView.addSubview(divider)

        [avatarContainer, avatarView, onlineDot, avatarInitialLabel,
         nameLabel, relationLabel, lastUpdatedLabel, footprintButton, divider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
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
            nameLabel.topAnchor.constraint(equalTo: avatarContainer.topAnchor, constant: 8),

            // 关系胶囊
            relationLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            relationLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            relationLabel.heightAnchor.constraint(equalToConstant: 18),

            // 上次更新
            lastUpdatedLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            lastUpdatedLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            // 查看足迹按钮
            footprintButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footprintButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            footprintButton.widthAnchor.constraint(equalToConstant: 88),
            footprintButton.heightAnchor.constraint(equalToConstant: 30),

            // 分割线
            divider.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with member: FamilyMember, isLast: Bool, isAccessRevoked: Bool = false) {
        // 头像首字
        avatarInitialLabel.text = String(member.name.prefix(1))

        // 在线状态圆点颜色
        onlineDot.backgroundColor = member.isOnline && !isAccessRevoked
            ? UIColor(red: 0.20, green: 0.75, blue: 0.30, alpha: 1.0)
            : UIColor(white: 0.75, alpha: 1.0)

        nameLabel.text = member.name

        // 关系标签内边距
        let padding = "  \(member.relation)  "
        relationLabel.text = padding

        let isBlocked = isAccessRevoked || !member.isCareDashboardAccessible
        lastUpdatedLabel.text = member.accessStateText
        lastUpdatedLabel.textColor = isBlocked ? UIColor.systemRed.withAlphaComponent(0.78) : UIColor(white: 0.60, alpha: 1.0)

        footprintButton.setTitle(member.careDashboardActionTitle, for: .normal)
        footprintButton.setTitleColor(
            isBlocked ? UIColor.systemRed.withAlphaComponent(0.78) : UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0),
            for: .normal
        )
        footprintButton.layer.borderColor = isBlocked
            ? UIColor.systemRed.withAlphaComponent(0.25).cgColor
            : UIColor(white: 0.82, alpha: 1.0).cgColor

        // 最后一行不显示分割线
        divider.isHidden = isLast
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarInitialLabel.text = nil
        nameLabel.text = nil
        relationLabel.text = nil
        lastUpdatedLabel.text = nil
        lastUpdatedLabel.textColor = UIColor(white: 0.60, alpha: 1.0)
        footprintButton.setTitle("关怀看板", for: .normal)
        footprintButton.setTitleColor(UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0), for: .normal)
        footprintButton.layer.borderColor = UIColor(white: 0.82, alpha: 1.0).cgColor
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
