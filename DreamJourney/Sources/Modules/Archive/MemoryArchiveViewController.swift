import UIKit

final class MemoryArchiveViewController: UIViewController {
    private let repository: MemoryArchiveRepository

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()
    private let featureCardsStack = UIStackView()
    private let listStack = UIStackView()

    private let summaryLabel = UILabel()
    private let progressLabel = UILabel()

    private static let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    init(repository: MemoryArchiveRepository = .shared) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "记忆档案馆"
        view.backgroundColor = DJDesignTokens.Color.background
        setupLayout()
        refreshContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    private func setupLayout() {
        scrollView.backgroundColor = DJDesignTokens.Color.background
        scrollView.keyboardDismissMode = .onDrag
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset.bottom = DJDesignTokens.Spacing.tabBarHeight + DJDesignTokens.Spacing.page
        scrollView.verticalScrollIndicatorInsets.bottom = DJDesignTokens.Spacing.tabBarHeight + DJDesignTokens.Spacing.page

        mainStack.axis = .vertical
        mainStack.spacing = DJDesignTokens.Spacing.card
        mainStack.layoutMargins = UIEdgeInsets(
            top: DJDesignTokens.Spacing.page,
            left: DJDesignTokens.Spacing.page,
            bottom: DJDesignTokens.Spacing.section,
            right: DJDesignTokens.Spacing.page
        )
        mainStack.isLayoutMarginsRelativeArrangement = true

        featureCardsStack.axis = .vertical
        featureCardsStack.spacing = 12

        listStack.axis = .vertical
        listStack.spacing = 12

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)

        [scrollView, contentView, mainStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        mainStack.addArrangedSubview(makeHeader())
        mainStack.addArrangedSubview(makePrimaryCTA())
        mainStack.addArrangedSubview(makeSummaryCard())
        mainStack.addArrangedSubview(featureCardsStack)
        mainStack.addArrangedSubview(makeSectionHeader(title: "时间胶囊", subtitle: "按时间保存那些值得回看的片段"))
        mainStack.addArrangedSubview(listStack)
    }

    private func refreshContent() {
        let summary = repository.summary()
        summaryLabel.text = "已封存 \(summary.total) 段素材 · 相册 \(summary.photos) · 语音 \(summary.audio) · 文字 \(summary.text)"
        progressLabel.text = "档案素材和每一次回响对话，都会补足称呼、关系、偏好与生活线索，让数字人格更接近真实的表达方式。"

        reloadFeatureCards(summary: summary)
        reloadArchiveList()
    }

    private func reloadFeatureCards(summary: (total: Int, photos: Int, audio: Int, text: Int)) {
        featureCardsStack.removeAllArrangedSubviews()

        featureCardsStack.addArrangedSubview(makeFeatureCard(
            iconName: "photo.on.rectangle.angled",
            title: "相册影像",
            detail: "已收纳 \(summary.photos) 张照片",
            action: #selector(selectPhotoTapped)
        ))
        featureCardsStack.addArrangedSubview(makeFeatureCard(
            iconName: "waveform",
            title: "语音档案",
            detail: "已沉淀 \(summary.audio) 段声音素材",
            action: nil
        ))
        featureCardsStack.addArrangedSubview(makeFeatureCard(
            iconName: "person.text.rectangle",
            title: "人格设定",
            detail: "管理称呼、关系与偏好线索",
            action: #selector(personaCardTapped)
        ))
        if FeatureFlagService.shared.isEnabled(.timeLetters) {
            featureCardsStack.addArrangedSubview(makeFeatureCard(
                iconName: "map",
                title: "时光足迹",
                detail: "按地点回看已开放的记忆片段",
                action: #selector(mapFootprintTapped)
            ))
        }
    }

    private func reloadArchiveList() {
        listStack.removeAllArrangedSubviews()
        let items = repository.allItems()

        if items.isEmpty {
            listStack.addArrangedSubview(makeEmptyStateCard())
            return
        }

        items.forEach { item in
            listStack.addArrangedSubview(makeArchiveItemRow(item))
        }
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = "记忆档案馆"
        titleLabel.font = DJDesignTokens.Font.display(34)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "整理、回顾与珍藏那些不愿遗忘的片段"
        subtitleLabel.font = DJDesignTokens.Font.body(16)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makePrimaryCTA() -> UIButton {
        let button = DJComponentFactory.primaryButton(
            title: "封存新记忆",
            target: self,
            action: #selector(archiveNewMemoryTapped(_:))
        )
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }

    private func makeSummaryCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let eyebrowLabel = UILabel()
        eyebrowLabel.text = "数字人格成长"
        eyebrowLabel.font = DJDesignTokens.Font.label(12)
        eyebrowLabel.textColor = DJDesignTokens.Color.accentDeep

        summaryLabel.font = DJDesignTokens.Font.title(18)
        summaryLabel.textColor = DJDesignTokens.Color.textPrimary
        summaryLabel.numberOfLines = 0

        progressLabel.font = DJDesignTokens.Font.body(14)
        progressLabel.textColor = DJDesignTokens.Color.textSecondary
        progressLabel.numberOfLines = 0

        card.addSubview(stack)
        [stack, eyebrowLabel, summaryLabel, progressLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stack.addArrangedSubview(eyebrowLabel)
        stack.addArrangedSubview(summaryLabel)
        stack.addArrangedSubview(progressLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeSectionHeader(title: String, subtitle: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4

        let titleLabel = DJComponentFactory.sectionLabel(title)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textTertiary
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makeFeatureCard(iconName: String, title: String, detail: String, action: Selector?) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.alignment = .center
        stack.spacing = 14

        let iconContainer = makeIconContainer(iconName: iconName, tintColor: DJDesignTokens.Color.accent)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.title(17)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = DJDesignTokens.Font.body(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = action == nil ? DJDesignTokens.Color.divider : DJDesignTokens.Color.textTertiary
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(stack)
        [stack, iconContainer, textStack, titleLabel, detailLabel, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        if let action = action {
            card.isAccessibilityElement = true
            card.accessibilityTraits = .button
            card.accessibilityLabel = title
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        }

        return card
    }

    private func makeArchiveItemRow(_ item: MemoryArchiveItem) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = 12

        let iconContainer = makeIconContainer(iconName: item.kind.iconName, tintColor: DJDesignTokens.Color.textSecondary)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6

        let topLine = UIStackView()
        topLine.alignment = .center
        topLine.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let statusLabel = makeBadge(text: item.kind.displayName)

        let noteLabel = UILabel()
        noteLabel.text = item.note
        noteLabel.font = DJDesignTokens.Font.body(14)
        noteLabel.textColor = DJDesignTokens.Color.textSecondary
        noteLabel.numberOfLines = 3

        let dateLabel = UILabel()
        dateLabel.text = Self.itemDateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.label(11)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        card.addSubview(stack)
        [stack, iconContainer, textStack, topLine, titleLabel, statusLabel, noteLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topLine.addArrangedSubview(titleLabel)
        topLine.addArrangedSubview(statusLabel)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        textStack.addArrangedSubview(topLine)
        textStack.addArrangedSubview(noteLabel)
        textStack.addArrangedSubview(dateLabel)

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    private func makeEmptyStateCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: "archivebox"))
        iconView.tintColor = DJDesignTokens.Color.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "还没有封存的记忆"
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = "先写下一段文字，或从相册选择一张照片。"
        detailLabel.font = DJDesignTokens.Font.body(13)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        card.addSubview(stack)
        [stack, iconView, titleLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
        ])

        return card
    }

    private func makeIconContainer(iconName: String, tintColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let imageView = UIImageView(image: UIImage(systemName: iconName))
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit

        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    private func makeBadge(text: String) -> UILabel {
        let label = PaddingLabel(horizontalInset: 8, verticalInset: 4)
        label.text = text
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.backgroundColor = DJDesignTokens.Color.surfaceLow
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }

    @objc private func archiveNewMemoryTapped(_ sender: UIButton) {
        let sheet = UIAlertController(title: "封存新记忆", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "添加文字描述", style: .default) { [weak self] _ in
            self?.presentTextEntry(kind: .text)
        })

        sheet.addAction(UIAlertAction(title: "选择照片", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        if FeatureFlagService.shared.isEnabled(.timeLetters) {
            sheet.addAction(UIAlertAction(title: "录入时间信件", style: .default) { [weak self] _ in
                self?.presentTextEntry(kind: .timeLetter)
            })
        }

        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }

        present(sheet, animated: true)
    }

    @objc private func selectPhotoTapped() {
        presentPhotoPicker()
    }

    @objc private func personaCardTapped() {
        navigationController?.pushViewController(KnowledgeBaseViewController(), animated: true)
    }

    @objc private func mapFootprintTapped() {
        guard FeatureFlagService.shared.isEnabled(.timeLetters) else { return }
        let currentUser = UserManager.shared.currentUser
        let viewController = MapFootprintViewController(
            viewMode: .host,
            ownerId: currentUser?.id ?? "user_001",
            ownerName: currentUser?.nickname
        )
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func presentTextEntry(kind: MemoryArchiveItemKind) {
        let isTimeLetter = kind == .timeLetter
        let alert = UIAlertController(
            title: isTimeLetter ? "录入时间信件" : "添加文字描述",
            message: isTimeLetter ? "写给未来某一天的自己或家人。" : "写下一段想封存的片段。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = isTimeLetter ? "这封信想说什么？" : "这段记忆是什么？"
            textField.clearButtonMode = .whileEditing
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let rawText = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawText.isEmpty else {
                self?.showToast("请输入内容", type: .info)
                return
            }

            let item = MemoryArchiveItem(
                kind: kind,
                title: isTimeLetter ? "时间信件" : "文字记忆",
                note: rawText
            )
            self.repository.add(item)
            self.refreshContent()
            self.showToast("已封存", type: .success)
        })

        present(alert, animated: true)
    }

    private func presentPhotoPicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showToast("无法打开相册", type: .error)
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func saveImageToArchive(_ image: UIImage) throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw ArchiveImageSaveError.jpegEncodingFailed
        }

        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-images", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

extension MemoryArchiveViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            showToast("照片读取失败", type: .error)
            return
        }

        do {
            let fileURL = try saveImageToArchive(image)
            let item = MemoryArchiveItem(
                kind: .photo,
                title: "相册影像",
                note: "从相册封存的一张照片",
                localPath: fileURL.path
            )
            repository.add(item)
            refreshContent()
            showToast("照片已封存", type: .success)
        } catch {
            showToast("照片保存失败", type: .error)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private enum ArchiveImageSaveError: LocalizedError {
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "照片编码失败"
        }
    }
}

private extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { subview in
            removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}

private extension MemoryArchiveItemKind {
    var displayName: String {
        switch self {
        case .photo:
            return "相册"
        case .video:
            return "视频"
        case .audio:
            return "语音"
        case .text:
            return "文字"
        case .timeLetter:
            return "信件"
        }
    }

    var iconName: String {
        switch self {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .text:
            return "text.alignleft"
        case .timeLetter:
            return "envelope"
        }
    }
}

private final class PaddingLabel: UILabel {
    private let horizontalInset: CGFloat
    private let verticalInset: CGFloat

    init(horizontalInset: CGFloat, verticalInset: CGFloat) {
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + horizontalInset * 2,
            height: size.height + verticalInset * 2
        )
    }
}
