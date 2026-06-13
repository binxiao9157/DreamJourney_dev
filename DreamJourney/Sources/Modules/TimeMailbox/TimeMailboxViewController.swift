import UIKit

final class TimeMailboxViewController: UIViewController {

    private let repository: TimeMailboxRepository
    private var letters: [TimeMailboxLetter] = []

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "时空信箱"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .warmPrimary
        return label
    }()

    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        button.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        button.tintColor = .warmAccent
        button.accessibilityLabel = "写信"
        return button
    }()

    private let boundaryLabel: UILabel = {
        let label = UILabel()
        label.text = "信件默认只保存在时空信箱；回声基于已整理记忆生成，不是逝者真实回复。打开信箱后会刷新投递状态。"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return label
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.dataSource = self
        table.delegate = self
        table.register(TimeMailboxCell.self, forCellReuseIdentifier: TimeMailboxCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        return table
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "还没有信件"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .warmSubtitle
        label.textAlignment = .center
        return label
    }()

    init(repository: TimeMailboxRepository = .shared) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: WarmTabBarView.tabBarHeight, right: 0)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        setupLayout()
        reloadLetters()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLetters()
    }

    private func setupLayout() {
        [titleLabel, addButton, boundaryLabel, tableView, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            addButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 44),

            boundaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            boundaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            boundaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: boundaryLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -24),
        ])
    }

    private func reloadLetters() {
        _ = repository.refreshDelivery()
        letters = repository.letters()
        emptyLabel.isHidden = !letters.isEmpty
        tableView.reloadData()
    }

    @objc private func addTapped() {
        let composer = TimeMailboxComposerViewController()
        composer.onSeal = { [weak self] draft in
            self?.sealLetter(draft)
        }
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func sealLetter(_ draft: TimeMailboxDraft) {
        let assessment = SafetyMonitor.shared.evaluate("\(draft.title)\n\(draft.body)")
        guard assessment.level != .high else {
            dismiss(animated: true) { [weak self] in
                let crisis = CrisisInterventionViewController(assessment: assessment)
                crisis.modalPresentationStyle = .fullScreen
                self?.present(crisis, animated: true)
            }
            return
        }

        do {
            _ = try repository.createLetter(
                recipientName: draft.recipientName,
                title: draft.title,
                body: draft.body,
                deliverAt: draft.deliverAt,
                boundaryAcknowledged: draft.boundaryAcknowledged,
                privacyMetadata: draft.privacyMetadata
            )
            dismiss(animated: true) { [weak self] in
                self?.showToast("信已封存", type: .success)
                self?.reloadLetters()
            }
        } catch TimeMailboxRepositoryError.invalidRecipient {
            showToast("请填写收件人", type: .info)
        } catch TimeMailboxRepositoryError.invalidBody {
            showToast("请写下想说的话", type: .info)
        } catch TimeMailboxRepositoryError.boundaryNotAcknowledged {
            showToast("请先确认时空边界", type: .info)
        } catch {
            showToast("封存失败，请稍后重试", type: .error)
        }
    }

    private func presentReader(for letter: TimeMailboxLetter) {
        guard letter.status != .sealed else {
            showToast("还未到投递时间", type: .info)
            return
        }

        do {
            try repository.markRead(id: letter.id)
        } catch {
            showToast("读取失败", type: .error)
            return
        }

        let latest = repository.letters().first(where: { $0.id == letter.id }) ?? letter
        let alert = UIAlertController(
            title: latest.title,
            message: latest.replyText ?? "这封信已经到达，但回声还在整理中。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "我知道了", style: .default))
        present(alert, animated: true)
        reloadLetters()
    }
}

extension TimeMailboxViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        letters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TimeMailboxCell.reuseIdentifier,
            for: indexPath
        ) as! TimeMailboxCell
        cell.configure(with: letters[indexPath.row])
        return cell
    }
}

extension TimeMailboxViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentReader(for: letters[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        108
    }
}

private struct TimeMailboxDraft {
    let recipientName: String
    let title: String
    let body: String
    let deliverAt: Date
    let boundaryAcknowledged: Bool
    let privacyMetadata: MemoryPrivacyMetadata
}

private final class TimeMailboxComposerViewController: UIViewController {
    var onSeal: ((TimeMailboxDraft) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let recipientField = TimeMailboxComposerViewController.makeTextField(placeholder: "收件人，如：妈妈")
    private let titleField = TimeMailboxComposerViewController.makeTextField(placeholder: "标题，如：今天很想你")

    private let bodyTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .warmPrimary
        textView.backgroundColor = .warmSurface
        textView.layer.cornerRadius = 10
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.warmDivider.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        return textView
    }()

    private let deliveryControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["立即", "1 分钟", "明日"])
        control.selectedSegmentIndex = 1
        control.selectedSegmentTintColor = .warmAccent
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.warmPrimary], for: .normal)
        return control
    }()

    private let privacyControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["本机", "可生成", "亲友"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .warmAccent
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.warmPrimary], for: .normal)
        return control
    }()

    private let familyVisibilityButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "person.2")
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        let button = UIButton(configuration: config)
        button.backgroundColor = .warmSurface
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.warmDivider.cgColor
        button.contentHorizontalAlignment = .leading
        button.tintColor = .warmAccent
        return button
    }()

    private lazy var familyVisibilitySection = makeSection(
        title: "亲友范围",
        view: familyVisibilityButton,
        height: 44
    )

    private let boundarySwitch: UISwitch = {
        let control = UISwitch()
        control.onTintColor = .warmAccent
        return control
    }()

    private var selectedFamilyVisibility = FamilyVisibilitySelection.allMembers

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        title = "写一封信"
        hideKeyboardWhenTapped()
        setupNavigation()
        setupLayout()
        privacyControl.addTarget(self, action: #selector(privacyChanged), for: .valueChanged)
        familyVisibilityButton.addTarget(self, action: #selector(familyVisibilityTapped), for: .touchUpInside)
        updateFamilyVisibilityState()
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "封存",
            style: .done,
            target: self,
            action: #selector(sealTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .warmAccent
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        [scrollView, stackView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        stackView.addArrangedSubview(makeSection(title: "收件人", view: recipientField, height: 44))
        stackView.addArrangedSubview(makeSection(title: "标题", view: titleField, height: 44))
        stackView.addArrangedSubview(makeSection(title: "想说的话", view: bodyTextView, height: 220))
        stackView.addArrangedSubview(makeSection(title: "投递时间", view: deliveryControl, height: 36))
        stackView.addArrangedSubview(makeSection(title: "使用范围", view: privacyControl, height: 36))
        stackView.addArrangedSubview(familyVisibilitySection)
        stackView.addArrangedSubview(makeBoundaryRow())

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func makeSection(title: String, view: UIView, height: CGFloat) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .warmSubtitle

        let stack = UIStackView(arrangedSubviews: [label, view])
        stack.axis = .vertical
        stack.spacing = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return stack
    }

    private func makeBoundaryRow() -> UIView {
        let label = UILabel()
        label.text = "我知道回信是基于记忆整理的回应，不是逝者真实回复。"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .warmPrimary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [label, boundarySwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func privacyChanged() {
        updateFamilyVisibilityState()
    }

    @objc private func familyVisibilityTapped() {
        let picker = FamilyVisibilityPickerViewController(
            initialVisibility: selectedFamilyVisibility.visibility
        )
        picker.onSelect = { [weak self] selection in
            self?.selectedFamilyVisibility = selection
            self?.updateFamilyVisibilityState()
        }
        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    @objc private func sealTapped() {
        let recipient = (recipientField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        let deliverAt: Date
        switch deliveryControl.selectedSegmentIndex {
        case 0:
            deliverAt = Date()
        case 2:
            deliverAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        default:
            deliverAt = Date().addingTimeInterval(60)
        }

        onSeal?(
            TimeMailboxDraft(
                recipientName: recipient,
                title: title,
                body: body,
                deliverAt: deliverAt,
                boundaryAcknowledged: boundarySwitch.isOn,
                privacyMetadata: selectedPrivacyMetadata()
            )
        )
    }

    private func selectedPrivacyMetadata() -> MemoryPrivacyMetadata {
        switch privacyControl.selectedSegmentIndex {
        case 1:
            return MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeForExplicitGenerationAuthorization())
        case 2:
            return MemoryPrivacyMetadata(
                scope: MemoryPrivacyMigration.scopeForExplicitFamilyAuthorization(),
                familyVisibility: selectedFamilyVisibility.visibility
            )
        default:
            return MemoryPrivacyMetadata(scope: .localOnly)
        }
    }

    private func updateFamilyVisibilityState() {
        familyVisibilitySection.isHidden = privacyControl.selectedSegmentIndex != 2

        var config = familyVisibilityButton.configuration ?? .plain()
        config.title = selectedFamilyVisibility.summary
        config.baseForegroundColor = .warmPrimary
        familyVisibilityButton.configuration = config
    }

    private static func makeTextField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.textColor = .warmPrimary
        field.backgroundColor = .warmSurface
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.warmDivider.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.rightViewMode = .always
        field.clearButtonMode = .whileEditing
        return field
    }
}

private final class TimeMailboxCell: UITableViewCell {
    static let reuseIdentifier = "TimeMailboxCell"

    private let surface = UIView()
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let recipientLabel = UILabel()
    private let dateLabel = UILabel()
    private let previewLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with letter: TimeMailboxLetter) {
        statusLabel.text = statusText(for: letter.status)
        statusLabel.textColor = statusColor(for: letter.status)
        titleLabel.text = letter.title
        recipientLabel.text = "写给 \(letter.recipientName)"
        dateLabel.text = "投递 \(Self.formatter.string(from: letter.deliverAt))"
        previewLabel.text = letter.body.replacingOccurrences(of: "\n", with: " ")
    }

    private func setupView() {
        backgroundColor = .clear
        selectionStyle = .none

        surface.backgroundColor = .warmSurface
        surface.layer.cornerRadius = 12
        surface.layer.borderWidth = 0.5
        surface.layer.borderColor = UIColor.warmDivider.cgColor

        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .warmPrimary
        recipientLabel.font = .systemFont(ofSize: 13)
        recipientLabel.textColor = .warmSubtitle
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .warmSubtitle
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.textColor = .warmPrimary
        previewLabel.numberOfLines = 1

        contentView.addSubview(surface)
        [statusLabel, titleLabel, recipientLabel, dateLabel, previewLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview($0)
        }
        surface.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            surface.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            surface.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            surface.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            statusLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -14),

            titleLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),

            recipientLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            recipientLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            dateLabel.centerYAnchor.constraint(equalTo: recipientLabel.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),

            previewLabel.topAnchor.constraint(equalTo: recipientLabel.bottomAnchor, constant: 8),
            previewLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            previewLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
        ])
    }

    private func statusText(for status: TimeMailboxDeliveryStatus) -> String {
        switch status {
        case .sealed: return "等待中"
        case .delivered: return "可阅读"
        case .read: return "已读"
        }
    }

    private func statusColor(for status: TimeMailboxDeliveryStatus) -> UIColor {
        switch status {
        case .sealed: return .warmSubtitle
        case .delivered: return .warmAccent
        case .read: return .warmPrimary
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
}
