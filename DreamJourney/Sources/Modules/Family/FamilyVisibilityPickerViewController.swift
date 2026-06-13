import UIKit

struct FamilyVisibilitySelection: Equatable {
    let visibility: FamilyMemberVisibility
    let summary: String

    static let allMembers = FamilyVisibilitySelection(
        visibility: .allMembers,
        summary: "全体亲友"
    )
}

final class FamilyVisibilityPickerViewController: UIViewController {
    var onSelect: ((FamilyVisibilitySelection) -> Void)?

    private let members: [FamilyMember]
    private var selectedIDs: Set<String>
    private var isAllMembersSelected: Bool

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = .warmBackground
        return table
    }()

    init(
        members: [FamilyMember] = FamilyRepository.shared.getAll(),
        initialVisibility: FamilyMemberVisibility = .allMembers
    ) {
        self.members = members
        self.isAllMembersSelected = initialVisibility.includesAllMembers
        self.selectedIDs = Set(initialVisibility.allowedMemberIDs)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择亲友"
        view.backgroundColor = .warmBackground
        tableView.dataSource = self
        tableView.delegate = self
        setupNavigation()
        setupLayout()
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .warmAccent
    }

    private func setupLayout() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        if isAllMembersSelected || selectedIDs.isEmpty {
            onSelect?(.allMembers)
            dismiss(animated: true)
            return
        }

        let orderedMembers = members.filter { selectedIDs.contains($0.id) }
        let summary = orderedMembers.map(\.name).joined(separator: "、")
        onSelect?(FamilyVisibilitySelection(
            visibility: .selectedMembers(orderedMembers.map(\.id)),
            summary: summary.isEmpty ? "已选亲友" : summary
        ))
        dismiss(animated: true)
    }
}

extension FamilyVisibilityPickerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : members.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "可见范围" : "具体亲友"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1 else { return nil }
        return "选择具体亲友后，分享包和关怀看板只会包含全体可见内容以及授权给这些亲友的内容。"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .warmSurface
        cell.textLabel?.textColor = .warmPrimary
        cell.detailTextLabel?.textColor = .warmSubtitle
        cell.tintColor = .warmAccent

        if indexPath.section == 0 {
            cell.textLabel?.text = "全体亲友"
            cell.detailTextLabel?.text = "适合家庭共同可见的素材"
            cell.accessoryType = isAllMembersSelected ? .checkmark : .none
            return cell
        }

        let member = members[indexPath.row]
        cell.textLabel?.text = member.name
        cell.detailTextLabel?.text = member.relation
        cell.accessoryType = !isAllMembersSelected && selectedIDs.contains(member.id) ? .checkmark : .none
        return cell
    }
}

extension FamilyVisibilityPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            isAllMembersSelected = true
            selectedIDs.removeAll()
            tableView.reloadData()
            return
        }

        isAllMembersSelected = false
        let memberID = members[indexPath.row].id
        if selectedIDs.contains(memberID) {
            selectedIDs.remove(memberID)
        } else {
            selectedIDs.insert(memberID)
        }
        tableView.reloadData()
    }
}

extension MemoryPrivacyMetadata {
    var familyVisibilitySummary: String {
        guard scope == .familyCircle else {
            return ""
        }
        if familyVisibility.includesAllMembers {
            return "全体亲友"
        }
        let names = FamilyRepository.shared.getAll()
            .filter { familyVisibility.allowedMemberIDs.contains($0.id) }
            .map(\.name)
        return names.isEmpty ? "已选亲友" : names.joined(separator: "、")
    }
}
