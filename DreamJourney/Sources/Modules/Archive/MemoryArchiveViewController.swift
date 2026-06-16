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

    private var creationOptions: [MemoryArchiveCreationOption] {
        MemoryArchiveCreationOption.availableOptions(
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters)
        )
    }

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
        mainStack.spacing = DJDesignTokens.Spacing.page
        mainStack.layoutMargins = UIEdgeInsets(
            top: DJDesignTokens.Spacing.page,
            left: DJDesignTokens.Spacing.page,
            bottom: DJDesignTokens.Spacing.section,
            right: DJDesignTokens.Spacing.page
        )
        mainStack.isLayoutMarginsRelativeArrangement = true

        featureCardsStack.axis = .vertical
        featureCardsStack.spacing = 0

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

        let header = makeHeader()
        mainStack.addArrangedSubview(header)
        mainStack.addArrangedSubview(featureCardsStack)
        mainStack.addArrangedSubview(makePrimaryCTA())
        mainStack.addArrangedSubview(makeTimelineHeader())
        mainStack.addArrangedSubview(listStack)
        mainStack.setCustomSpacing(DJDesignTokens.Spacing.section, after: header)
        mainStack.setCustomSpacing(DJDesignTokens.Spacing.section, after: featureCardsStack)
        mainStack.setCustomSpacing(DJDesignTokens.Spacing.section, after: listStack)
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

        featureCardsStack.addArrangedSubview(makeFeatureGrid(summary: summary))
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
        titleLabel.font = DJDesignTokens.Font.display(40)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "在此处整理、回顾与珍藏那些不愿遗忘的片段。"
        subtitleLabel.font = DJDesignTokens.Font.body(16)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makePrimaryCTA() -> UIControl {
        let control = UIControl()
        control.backgroundColor = DJDesignTokens.Color.accent
        control.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        control.addTarget(self, action: #selector(archiveNewMemoryTapped(_:)), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        iconContainer.layer.cornerRadius = 32
        iconContainer.isUserInteractionEnabled = false

        let iconView = UIImageView(image: UIImage(systemName: "plus"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "封存新记忆"
        titleLabel.font = DJDesignTokens.Font.title(20)
        titleLabel.textColor = DJDesignTokens.Color.accentDeep
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "文字、图片或声音"
        subtitleLabel.font = DJDesignTokens.Font.body(16)
        subtitleLabel.textColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.78)
        subtitleLabel.textAlignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = 4
        textStack.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.isUserInteractionEnabled = false

        control.addSubview(stack)
        iconContainer.addSubview(iconView)
        [stack, iconContainer, iconView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: 160),

            stack.centerXAnchor.constraint(equalTo: control.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: control.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: control.trailingAnchor, constant: -24),

            iconContainer.widthAnchor.constraint(equalToConstant: 64),
            iconContainer.heightAnchor.constraint(equalToConstant: 64),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = "封存新记忆，文字、图片或声音"
        return control
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

    private func makeTimelineHeader() -> UIView {
        let stack = UIStackView()
        stack.alignment = .center
        stack.spacing = 12

        let titleLabel = DJComponentFactory.sectionLabel("时间胶囊")
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let sortButton = UIButton(type: .system)
        sortButton.setTitle("按时间排序", for: .normal)
        sortButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        sortButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.tintColor = DJDesignTokens.Color.accentDeep
        sortButton.semanticContentAttribute = .forceRightToLeft
        sortButton.contentHorizontalAlignment = .trailing

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(sortButton)
        return stack
    }

    private func makeFeatureGrid(summary: (total: Int, photos: Int, audio: Int, text: Int)) -> UIView {
        let photoCard = makeFeatureTile(
            iconName: "photo.on.rectangle.angled",
            title: "相册影像",
            detail: "\(summary.photos) 个瞬间",
            isLarge: true,
            action: #selector(selectPhotoTapped)
        )

        let voiceCard = makeFeatureTile(
            iconName: "waveform",
            title: "语音档案",
            detail: nil,
            isLarge: false,
            action: nil
        )

        let personaCard = makeFeatureTile(
            iconName: "slider.horizontal.3",
            title: "人格设定",
            detail: nil,
            isLarge: false,
            action: #selector(personaCardTapped)
        )

        let rightColumn = UIStackView(arrangedSubviews: [voiceCard, personaCard])
        rightColumn.axis = .vertical
        rightColumn.spacing = 16
        rightColumn.distribution = .fillEqually

        let grid = UIStackView(arrangedSubviews: [photoCard, rightColumn])
        grid.axis = .horizontal
        grid.spacing = 16
        grid.distribution = .fillEqually

        NSLayoutConstraint.activate([
            photoCard.heightAnchor.constraint(equalToConstant: 148),
        ])

        return grid
    }

    private func makeFeatureTile(
        iconName: String,
        title: String,
        detail: String?,
        isLarge: Bool,
        action: Selector?
    ) -> UIControl {
        let control = UIControl()
        control.backgroundColor = DJDesignTokens.Color.surface
        control.layer.cornerRadius = DJDesignTokens.Radius.large
        control.layer.borderWidth = 1
        control.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.48).cgColor
        control.addTarget(self, action: action ?? #selector(disabledFeatureTapped), for: .touchUpInside)
        DJDesignTokens.applySoftShadow(to: control)

        let iconContainer = makeIconContainer(iconName: iconName, tintColor: DJDesignTokens.Color.accentDeep)
        iconContainer.backgroundColor = isLarge
            ? DJDesignTokens.Color.surfaceContainer
            : DJDesignTokens.Color.surfaceLow

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = isLarge ? DJDesignTokens.Font.title(20) : DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        let textStack = UIStackView(arrangedSubviews: [titleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        if let detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = DJDesignTokens.Font.label(12)
            detailLabel.textColor = DJDesignTokens.Color.textSecondary
            detailLabel.numberOfLines = 1
            textStack.addArrangedSubview(detailLabel)
        }

        let stack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        stack.axis = isLarge ? .vertical : .horizontal
        stack.alignment = isLarge ? .leading : .center
        stack.spacing = isLarge ? 18 : 12
        stack.isUserInteractionEnabled = false

        control.addSubview(stack)
        [stack, iconContainer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: isLarge ? 40 : 32),
            iconContainer.heightAnchor.constraint(equalToConstant: isLarge ? 40 : 32),

            stack.topAnchor.constraint(equalTo: control.topAnchor, constant: isLarge ? 20 : 16),
            stack.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: isLarge ? 20 : 14),
            stack.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: isLarge ? -20 : -14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: control.bottomAnchor, constant: isLarge ? -20 : -16),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = detail == nil ? title : "\(title)，\(detail ?? "")"
        return control
    }

    private func makeArchiveItemRow(_ item: MemoryArchiveItem) -> UIView {
        let control = MemoryArchiveItemRowControl(item: item)
        control.addTarget(self, action: #selector(archiveItemTapped(_:)), for: .touchUpInside)

        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = 12

        let iconContainer = makeIconContainer(iconName: item.kind.archiveIconName, tintColor: DJDesignTokens.Color.textSecondary)

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

        let statusStack = UIStackView()
        statusStack.spacing = 6
        statusStack.alignment = .center

        let kindBadge = makeBadge(text: item.kind.archiveDisplayName)
        let analysisBadge = makeStatusBadge(text: item.analysisStatus.archiveDisplayName)
        statusStack.addArrangedSubview(kindBadge)
        statusStack.addArrangedSubview(analysisBadge)

        let noteLabel = UILabel()
        noteLabel.text = item.note
        noteLabel.font = DJDesignTokens.Font.body(14)
        noteLabel.textColor = DJDesignTokens.Color.textSecondary
        noteLabel.numberOfLines = 3

        let dateLabel = UILabel()
        dateLabel.text = Self.itemDateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.label(11)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        control.addSubview(card)
        card.addSubview(stack)
        [card, stack, iconContainer, textStack, topLine, titleLabel, statusStack, kindBadge, analysisBadge, noteLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topLine.addArrangedSubview(titleLabel)
        topLine.addArrangedSubview(statusStack)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusStack.setContentHuggingPriority(.required, for: .horizontal)

        textStack.addArrangedSubview(topLine)
        textStack.addArrangedSubview(noteLabel)
        textStack.addArrangedSubview(dateLabel)

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: control.topAnchor),
            card.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: control.bottomAnchor),

            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        control.accessibilityTraits = .button
        control.accessibilityLabel = "\(item.title)，\(item.kind.archiveDisplayName)，\(item.analysisStatus.archiveDisplayName)"
        return control
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

    private func makeStatusBadge(text: String) -> UILabel {
        let label = makeBadge(text: text)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.backgroundColor = DJDesignTokens.Color.surfaceContainer
        return label
    }

    @objc private func archiveNewMemoryTapped(_ sender: UIControl) {
        let sheet = MemoryArchiveCreationSheetViewController(options: creationOptions)
        sheet.delegate = self
        present(sheet, animated: true)
    }

    @objc private func disabledFeatureTapped() {
        showToast("该入口将在后续开放", type: .info)
    }

    @objc private func archiveItemTapped(_ sender: MemoryArchiveItemRowControl) {
        navigationController?.pushViewController(
            MemoryArchiveDetailViewController(item: sender.item),
            animated: true
        )
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

            let item = isTimeLetter
                ? MemoryArchiveItemFactory.makeTimeLetter(note: rawText)
                : MemoryArchiveItemFactory.makeTextItem(note: rawText)
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
            let item = MemoryArchiveItemFactory.makePhotoItem(localPath: fileURL.path)
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

extension MemoryArchiveViewController: MemoryArchiveCreationSheetViewControllerDelegate {
    func memoryArchiveCreationSheet(
        _ viewController: MemoryArchiveCreationSheetViewController,
        didSelect option: MemoryArchiveCreationOption
    ) {
        switch option.archiveKind {
        case .text:
            presentTextEntry(kind: .text)
        case .photo:
            presentPhotoPicker()
        case .audio:
            showToast("语音素材录入将在后续开放", type: .info)
        case .timeLetter:
            guard FeatureFlagService.shared.isEnabled(.timeLetters) else { return }
            presentTextEntry(kind: .timeLetter)
        case .video:
            showToast("视频素材录入将在后续开放", type: .info)
        }
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

private final class MemoryArchiveItemRowControl: UIControl {
    let item: MemoryArchiveItem

    init(item: MemoryArchiveItem) {
        self.item = item
        super.init(frame: .zero)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
