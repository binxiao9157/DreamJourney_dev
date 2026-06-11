import UIKit

final class MemoryArchiveViewController: UIViewController {

    private let repository: MemoryArchiveRepository
    private var items: [MemoryArchiveItem] = []

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "记忆档案馆"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .warmPrimary
        return label
    }()

    private let boundaryLabel: UILabel = {
        let label = UILabel()
        label.text = "这里保存的是照片、口头禅和性格线索，用来整理记忆，不代表逝者复活。"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .warmPrimary
        label.numberOfLines = 0
        return label
    }()

    private lazy var photoButton = makeActionButton(title: "上传旧照片", iconName: "photo.on.rectangle")
    private lazy var textButton = makeActionButton(title: "添加文字素材", iconName: "square.and.pencil")
    private lazy var knowledgeButton = makeActionButton(title: "结构化知识库", iconName: "brain.head.profile")

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.dataSource = self
        table.delegate = self
        table.register(MemoryArchiveCell.self, forCellReuseIdentifier: MemoryArchiveCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        return table
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "还没有档案素材"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .warmSubtitle
        label.textAlignment = .center
        return label
    }()

    init(repository: MemoryArchiveRepository = .shared) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: WarmTabBarView.tabBarHeight, right: 0)
        setupActions()
        setupLayout()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadData()
    }

    private func setupActions() {
        photoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        textButton.addTarget(self, action: #selector(textTapped), for: .touchUpInside)
        knowledgeButton.addTarget(self, action: #selector(knowledgeTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        let actionStack = UIStackView(arrangedSubviews: [photoButton, textButton, knowledgeButton])
        actionStack.axis = .vertical
        actionStack.spacing = 10

        [titleLabel, boundaryLabel, summaryLabel, actionStack, tableView, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            boundaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            boundaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            boundaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            summaryLabel.topAnchor.constraint(equalTo: boundaryLabel.bottomAnchor, constant: 12),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            actionStack.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 14),
            actionStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -20),
        ])
    }

    private func reloadData() {
        items = repository.items()
        let summary = repository.summary()
        summaryLabel.text = "共 \(summary.totalCount) 份素材 · 照片 \(summary.photoCount) · 文字 \(summary.textCount) · 已分析 \(summary.analyzedPhotoCount)"
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    @objc private func photoTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showToast("当前设备无法访问相册", type: .error)
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func textTapped() {
        let composer = MemoryArchiveTextComposerViewController()
        composer.onSave = { [weak self] draft in
            self?.saveTextDraft(draft)
        }
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func knowledgeTapped() {
        let knowledgeVC = KnowledgeBaseViewController()
        knowledgeVC.title = "结构化知识库"
        navigationController?.navigationBar.isHidden = false
        navigationController?.pushViewController(knowledgeVC, animated: true)
    }

    private func saveTextDraft(_ draft: MemoryArchiveTextDraft) {
        let assessment = SafetyMonitor.shared.evaluate("\(draft.title)\n\(draft.note)")
        guard assessment.level != .high else {
            dismiss(animated: true) { [weak self] in
                let crisis = CrisisInterventionViewController(assessment: assessment)
                crisis.modalPresentationStyle = .fullScreen
                self?.present(crisis, animated: true)
            }
            return
        }

        do {
            let item = try repository.addText(
                kind: draft.kind,
                title: draft.title,
                note: draft.note,
                tags: draft.tags,
                isPrivate: draft.isPrivate
            )
            if !item.isPrivate {
                Stage1MemoryFacade.shared.recordUserTurn("记忆档案馆保存\(item.kind.displayName)：\(item.note)")
            }
            dismiss(animated: true) { [weak self] in
                self?.showToast("素材已保存", type: .success)
                self?.reloadData()
            }
        } catch {
            showToast("请填写素材内容", type: .info)
        }
    }

    private func saveArchivePhoto(_ image: UIImage) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let archiveDir = docs?.appendingPathComponent("archive_photos") else { return nil }
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let fileName = "archive_photo_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = archiveDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private func analyzePhoto(_ image: UIImage, itemId: String) {
        let maxDimension: CGFloat = 1024
        let scaledImage: UIImage
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }

        guard let imageData = scaledImage.jpegData(compressionQuality: 0.6) else { return }
        let base64 = imageData.base64EncodedString()

        DeepSeekService.shared.analyzeImage(imageBase64: base64) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let kbAnalysis):
                    let archiveAnalysis = MemoryArchiveImageAnalysis(
                        summary: kbAnalysis.description,
                        detectedPeople: kbAnalysis.detectedPeople,
                        scene: kbAnalysis.scene.nilIfEmpty,
                        occasion: kbAnalysis.occasion.nilIfEmpty,
                        mood: kbAnalysis.mood.nilIfEmpty,
                        estimatedDecade: kbAnalysis.estimatedDecade
                    )
                    do {
                        let item = try self.repository.applyImageAnalysis(id: itemId, analysis: archiveAnalysis)
                        if !item.isPrivate {
                            let sessionId = ConversationMemoryManager.shared.currentMemory.sessionCount + 1
                            Stage1MemoryFacade.shared.ingestImageAnalysis(kbAnalysis, sessionId: sessionId)
                            Stage1MemoryFacade.shared.recordUserTurn("记忆档案馆上传旧照片：\(archiveAnalysis.summary)")
                        }
                        self.showToast("照片分析完成", type: .success)
                    } catch {
                        self.showToast("照片分析结果保存失败", type: .error)
                    }
                case .failure:
                    _ = try? self.repository.markAnalysisFailed(id: itemId)
                    self.showToast("照片已保存，分析稍后可重试", type: .info)
                }
                self.reloadData()
            }
        }
    }

    private func makeActionButton(title: String, iconName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .warmSurface
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.warmDivider.cgColor
        button.tintColor = .warmAccent
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: iconName)
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.warmPrimary,
            ])
        )
        button.configuration = config
        return button
    }
}

extension MemoryArchiveViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.originalImage] as? UIImage,
              let imagePath = saveArchivePhoto(image) else {
            picker.dismiss(animated: true)
            showToast("照片保存失败", type: .error)
            return
        }

        picker.dismiss(animated: true) { [weak self] in
            self?.presentPhotoPrivacyChoice(image: image, imagePath: imagePath)
        }
    }

    private func presentPhotoPrivacyChoice(image: UIImage, imagePath: String) {
        let alert = UIAlertController(
            title: "照片保存方式",
            message: "私密保存只保存在本机档案馆；选择分析整理会调用图片分析并写入记忆线索。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "仅私密保存", style: .default) { [weak self] _ in
            self?.savePickedPhoto(image, imagePath: imagePath, allowAnalysis: false)
        })
        alert.addAction(UIAlertAction(title: "分析并整理为记忆线索", style: .default) { [weak self] _ in
            self?.savePickedPhoto(image, imagePath: imagePath, allowAnalysis: true)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )
        present(alert, animated: true)
    }

    private func savePickedPhoto(_ image: UIImage, imagePath: String, allowAnalysis: Bool) {
        do {
            let item = try repository.addPhoto(
                localPath: imagePath,
                title: "旧照片",
                note: "从相册加入的记忆照片",
                tags: ["旧照片"],
                isPrivate: !allowAnalysis
            )
            reloadData()
            if allowAnalysis {
                showToast("照片已加入档案馆，开始分析", type: .success)
                analyzePhoto(image, itemId: item.id)
            } else {
                showToast("照片已私密保存", type: .success)
            }
        } catch {
            showToast("照片加入失败", type: .error)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension MemoryArchiveViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: MemoryArchiveCell.reuseIdentifier,
            for: indexPath
        ) as! MemoryArchiveCell
        cell.configure(with: items[indexPath.row])
        return cell
    }
}

extension MemoryArchiveViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        112
    }
}

private struct MemoryArchiveTextDraft {
    let kind: MemoryArchiveItemKind
    let title: String
    let note: String
    let tags: [String]
    let isPrivate: Bool
}

private final class MemoryArchiveTextComposerViewController: UIViewController {
    var onSave: ((MemoryArchiveTextDraft) -> Void)?

    private let kindControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["回忆", "性格", "口头禅"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .warmAccent
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.warmPrimary], for: .normal)
        return control
    }()

    private let titleField = MemoryArchiveTextComposerViewController.makeTextField(placeholder: "标题")

    private let noteTextView: UITextView = {
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

    private let privateSwitch: UISwitch = {
        let control = UISwitch()
        control.isOn = true
        control.onTintColor = .warmAccent
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        title = "添加素材"
        hideKeyboardWhenTapped()
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
            title: "保存",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .warmAccent
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        [scrollView, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        stack.addArrangedSubview(makeSection(title: "素材类型", view: kindControl, height: 36))
        stack.addArrangedSubview(makeSection(title: "标题", view: titleField, height: 44))
        stack.addArrangedSubview(makeSection(title: "内容", view: noteTextView, height: 220))
        stack.addArrangedSubview(makePrivateRow())

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
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

    private func makePrivateRow() -> UIView {
        let label = UILabel()
        label.text = "私密保存"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .warmPrimary

        let row = UIStackView(arrangedSubviews: [label, UIView(), privateSwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        return row
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let kind: MemoryArchiveItemKind
        switch kindControl.selectedSegmentIndex {
        case 1: kind = .personalityNote
        case 2: kind = .catchphrase
        default: kind = .textNote
        }

        let draft = MemoryArchiveTextDraft(
            kind: kind,
            title: (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            note: noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: [kind.displayName],
            isPrivate: privateSwitch.isOn
        )
        onSave?(draft)
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

private final class MemoryArchiveCell: UITableViewCell {
    static let reuseIdentifier = "MemoryArchiveCell"

    private let surface = UIView()
    private let thumbnailView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: MemoryArchiveItem) {
        titleLabel.text = item.title
        detailLabel.text = item.displayDetail
        statusLabel.text = item.statusText
        statusLabel.textColor = item.statusColor

        if item.kind == .photo, let path = item.localPath, let image = UIImage(contentsOfFile: path) {
            thumbnailView.image = image
            thumbnailView.tintColor = nil
            thumbnailView.backgroundColor = .clear
        } else {
            thumbnailView.image = UIImage(systemName: item.kind.iconName)
            thumbnailView.tintColor = .warmAccent
            thumbnailView.backgroundColor = UIColor.warmAccent.withAlphaComponent(0.12)
        }
    }

    private func setupView() {
        backgroundColor = .clear
        selectionStyle = .none

        surface.backgroundColor = .warmSurface
        surface.layer.cornerRadius = 12
        surface.layer.borderWidth = 0.5
        surface.layer.borderColor = UIColor.warmDivider.cgColor

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 8

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .warmPrimary
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .warmSubtitle
        detailLabel.numberOfLines = 2
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)

        contentView.addSubview(surface)
        [thumbnailView, titleLabel, detailLabel, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview($0)
        }
        surface.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            surface.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            surface.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            surface.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            thumbnailView.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 72),

            statusLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -14),

            titleLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -10),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
        ])
    }
}

private extension MemoryArchiveItemKind {
    var displayName: String {
        switch self {
        case .photo: return "旧照片"
        case .textNote: return "文字回忆"
        case .personalityNote: return "性格描述"
        case .catchphrase: return "口头禅"
        }
    }

    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .textNote: return "text.alignleft"
        case .personalityNote: return "person.text.rectangle"
        case .catchphrase: return "quote.bubble"
        }
    }
}

private extension MemoryArchiveItem {
    var displayDetail: String {
        if let summary = analysisSummary, !summary.isEmpty {
            return summary
        }
        if !note.isEmpty {
            return note
        }
        return kind.displayName
    }

    var statusText: String {
        switch analysisStatus {
        case .manual: return kind.displayName
        case .pending: return "分析中"
        case .analyzed: return "已分析"
        case .failed: return "待补充"
        }
    }

    var statusColor: UIColor {
        switch analysisStatus {
        case .manual: return .warmPrimary
        case .pending: return .warmSubtitle
        case .analyzed: return .warmAccent
        case .failed: return .warmSubtitle
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
