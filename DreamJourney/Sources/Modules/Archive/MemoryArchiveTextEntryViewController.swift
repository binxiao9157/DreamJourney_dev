import UIKit

struct TimeLetterEntryPayload {
    let note: String
    let openAt: Date
    let recipients: [TimeLetterRecipientSelection]
    let imageLocalPath: String?
}

final class MemoryArchiveTextEntryViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var onSave: ((String) -> Void)?
    var onSaveDraft: ((String) -> Void)?
    var onSaveTimeLetter: ((TimeLetterEntryPayload) -> Void)?
    var onSaveDraftTimeLetter: ((TimeLetterEntryPayload) -> Void)?

    private let kind: MemoryArchiveItemKind
    private let initialText: String?
    private let textEntryTitle: String?
    private let textEntrySubtitle: String?
    private let textSaveButtonTitle: String?
    private let initialTimeLetterPayload: TimeLetterEntryPayload?
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let openAtPicker = UIDatePicker()
    private let recipientsStack = UIStackView()
    private let imageStatusLabel = UILabel()
    private var recipientButtons: [String: UIButton] = [:]
    private var availableRecipients: [TimeLetterRecipientSelection] = []
    private var selectedRecipientIds: Set<String> = ["self"]
    private var selectedImageLocalPath: String?
    private lazy var saveButton = DJComponentFactory.primaryButton(
        title: isTimeLetter ? "封存时间信件" : (textSaveButtonTitle ?? "保存到档案馆"),
        target: self,
        action: #selector(saveTapped)
    )
    private lazy var draftButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("保存草稿", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.surfaceContainer
        button.layer.cornerRadius = 24
        button.accessibilityIdentifier = "time-letter-draft-button"
        button.addTarget(self, action: #selector(saveDraftTapped), for: .touchUpInside)
        return button
    }()

    private var isTimeLetter: Bool {
        kind == .timeLetter
    }

    init(
        kind: MemoryArchiveItemKind,
        initialText: String? = nil,
        textEntryTitle: String? = nil,
        textEntrySubtitle: String? = nil,
        textSaveButtonTitle: String? = nil,
        initialTimeLetterPayload: TimeLetterEntryPayload? = nil
    ) {
        self.kind = kind
        self.initialText = initialText
        self.textEntryTitle = textEntryTitle
        self.textEntrySubtitle = textEntrySubtitle
        self.textSaveButtonTitle = textSaveButtonTitle
        self.initialTimeLetterPayload = initialTimeLetterPayload
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let initialTimeLetterPayload {
            selectedRecipientIds = Set(initialTimeLetterPayload.recipients.map(\.id))
            selectedImageLocalPath = initialTimeLetterPayload.imageLocalPath
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        configureTimeLetterDefaults()
        configureTextEntryDefaults()
        configureSheet()
        buildLayout()
        updateSaveButton()
    }

    private func configureTimeLetterDefaults() {
        guard isTimeLetter else { return }
        availableRecipients = makeAvailableRecipients()
        if selectedRecipientIds.isEmpty {
            selectedRecipientIds = ["self"]
        }
        openAtPicker.date = initialTimeLetterPayload?.openAt
            ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
            ?? Date()
        textView.text = initialTimeLetterPayload?.note ?? ""
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    private func configureTextEntryDefaults() {
        guard !isTimeLetter else { return }
        textView.text = initialText ?? ""
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    private func configureSheet() {
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DJDesignTokens.Radius.extraLarge
        }
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = isTimeLetter ? "录入时间信件" : (textEntryTitle ?? "添加文字描述")
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = isTimeLetter
            ? "写给未来某一天的自己或家人；支持文字和图片，封存后不可删除或修改。"
            : (textEntrySubtitle ?? "写下一段想封存的片段，人物、地点、称呼和生活细节都可以。")
        subtitleLabel.font = DJDesignTokens.Font.body(15)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = DJDesignTokens.Font.label(14)
        cancelButton.setTitleColor(DJDesignTokens.Color.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), cancelButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 12

        let inputCard = UIView()
        inputCard.backgroundColor = DJDesignTokens.Color.surface
        inputCard.layer.cornerRadius = DJDesignTokens.Radius.large
        inputCard.layer.borderWidth = 1
        inputCard.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        DJDesignTokens.applySoftShadow(to: inputCard)

        textView.delegate = self
        textView.backgroundColor = .clear
        textView.font = DJDesignTokens.Font.body(16)
        textView.textColor = DJDesignTokens.Color.textPrimary
        textView.tintColor = DJDesignTokens.Color.accentDeep
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        textView.textContainer.lineFragmentPadding = 0

        placeholderLabel.text = isTimeLetter ? "这封信想说什么？" : "这段记忆是什么？"
        placeholderLabel.font = DJDesignTokens.Font.body(16)
        placeholderLabel.textColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.56)

        saveButton.titleLabel?.font = DJDesignTokens.Font.label(16)
        saveButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        saveButton.layer.cornerRadius = 28

        let helperLabel = UILabel()
        helperLabel.text = isTimeLetter
            ? "封存后会按打开时间提醒本人和收件人。"
            : "仅保存你主动录入的内容，不会展示聊天原文。"
        helperLabel.font = DJDesignTokens.Font.label(12)
        helperLabel.textColor = DJDesignTokens.Color.textTertiary
        helperLabel.numberOfLines = 0

        var arrangedSubviews: [UIView] = [headerStack, subtitleLabel, inputCard]
        if isTimeLetter {
            arrangedSubviews.append(makeTimeLetterOptionsStack())
            arrangedSubviews.append(helperLabel)
            arrangedSubviews.append(draftButton)
        } else {
            arrangedSubviews.append(helperLabel)
        }
        arrangedSubviews.append(saveButton)

        let contentStack = UIStackView(arrangedSubviews: arrangedSubviews)
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 30,
            leading: DJDesignTokens.Spacing.page,
            bottom: 28,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(contentStack)
        inputCard.addSubview(textView)
        textView.addSubview(placeholderLabel)
        [contentStack, headerStack, titleLabel, cancelButton, inputCard, textView, placeholderLabel, draftButton, saveButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -12),

            inputCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 168),

            textView.topAnchor.constraint(equalTo: inputCard.topAnchor),
            textView.leadingAnchor.constraint(equalTo: inputCard.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: inputCard.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: inputCard.bottomAnchor),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 18),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 14),

            draftButton.heightAnchor.constraint(equalToConstant: 48),
            saveButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSaveButton()
    }

    private func updateSaveButton() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let canSave = hasText && (!isTimeLetter || !selectedRecipientIds.isEmpty)
        saveButton.isEnabled = canSave
        saveButton.alpha = canSave ? 1 : 0.55
        draftButton.isEnabled = canSave
        draftButton.alpha = canSave ? 1 : 0.55
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        if isTimeLetter {
            saveTimeLetter(with: onSaveTimeLetter)
        } else {
            save(with: onSave)
        }
    }

    @objc private func saveDraftTapped() {
        saveTimeLetter(with: onSaveDraftTimeLetter)
    }

    private func save(with handler: ((String) -> Void)?) {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            updateSaveButton()
            return
        }
        dismiss(animated: true) {
            handler?(rawText)
        }
    }

    private func saveTimeLetter(with handler: ((TimeLetterEntryPayload) -> Void)?) {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            updateSaveButton()
            return
        }

        let selectedRecipients = availableRecipients.filter { selectedRecipientIds.contains($0.id) }
        guard !selectedRecipients.isEmpty else {
            updateSaveButton()
            return
        }

        let payload = TimeLetterEntryPayload(
            note: rawText,
            openAt: openAtPicker.date,
            recipients: selectedRecipients,
            imageLocalPath: selectedImageLocalPath
        )
        dismiss(animated: true) {
            handler?(payload)
        }
    }

    private func makeAvailableRecipients() -> [TimeLetterRecipientSelection] {
        var result = [TimeLetterRecipientSelection(id: "self", name: "我")]
        FamilyRepository.shared.getAll().filter(\.isAcceptedFamilyRelationship).forEach { member in
            guard !result.contains(where: { $0.id == member.id }) else { return }
            result.append(TimeLetterRecipientSelection(id: member.id, name: member.name))
        }
        return result
    }

    private func makeTimeLetterOptionsStack() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [
            makeOpenAtCard(),
            makeRecipientsCard(),
            makeImageAttachmentCard(),
        ])
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }

    private func makeOpenAtCard() -> UIView {
        let card = makeOptionCard()
        let titleLabel = makeOptionTitleLabel("打开时间")
        let subtitleLabel = makeOptionSubtitleLabel("选择未来可以打开这封信的时间。")

        openAtPicker.datePickerMode = .dateAndTime
        openAtPicker.minimumDate = Date()
        openAtPicker.preferredDatePickerStyle = .compact
        openAtPicker.tintColor = DJDesignTokens.Color.accentDeep
        openAtPicker.accessibilityIdentifier = "time-letter-open-at-picker"

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, openAtPicker])
        row.alignment = .center
        row.spacing = 12

        card.addSubview(row)
        [row, textStack, titleLabel, subtitleLabel, openAtPicker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func makeRecipientsCard() -> UIView {
        let card = makeOptionCard()
        let titleLabel = makeOptionTitleLabel("收件人")
        let subtitleLabel = makeOptionSubtitleLabel("至少选择一位，可以同时留给自己和家人。")

        recipientsStack.axis = .horizontal
        recipientsStack.alignment = .leading
        recipientsStack.spacing = 8
        recipientsStack.distribution = .fill

        availableRecipients.forEach { recipient in
            let button = makeRecipientButton(recipient)
            recipientsStack.addArrangedSubview(button)
            recipientButtons[recipient.id] = button
        }
        refreshRecipientButtons()

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, recipientsStack])
        stack.axis = .vertical
        stack.spacing = 10

        card.addSubview(stack)
        [stack, titleLabel, subtitleLabel, recipientsStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func makeImageAttachmentCard() -> UIView {
        let card = makeOptionCard()
        let titleLabel = makeOptionTitleLabel("图片")
        let subtitleLabel = makeOptionSubtitleLabel("可附上一张照片，让未来更容易回到当时。")

        let button = UIButton(type: .system)
        button.setTitle(selectedImageLocalPath == nil ? "选择图片" : "更换图片", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(14)
        button.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.surfaceLow
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.accessibilityIdentifier = "time-letter-image-picker-button"
        button.addTarget(self, action: #selector(selectTimeLetterImageTapped), for: .touchUpInside)

        imageStatusLabel.text = selectedImageLocalPath == nil ? "未添加图片" : "已添加 1 张图片"
        imageStatusLabel.font = DJDesignTokens.Font.label(12)
        imageStatusLabel.textColor = DJDesignTokens.Color.textTertiary
        imageStatusLabel.accessibilityIdentifier = "time-letter-image-status"

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, imageStatusLabel])
        textStack.axis = .vertical
        textStack.spacing = 5

        let row = UIStackView(arrangedSubviews: [textStack, button])
        row.alignment = .center
        row.spacing = 12

        card.addSubview(row)
        [row, textStack, titleLabel, subtitleLabel, imageStatusLabel, button].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func makeOptionCard() -> UIView {
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = DJDesignTokens.Radius.large
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.42).cgColor
        return card
    }

    private func makeOptionTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.title(15)
        label.textColor = DJDesignTokens.Color.textPrimary
        return label
    }

    private func makeOptionSubtitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.body(12)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.numberOfLines = 0
        return label
    }

    private func makeRecipientButton(_ recipient: TimeLetterRecipientSelection) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(recipient.name, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(13)
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 11, bottom: 7, right: 11)
        button.accessibilityIdentifier = "time-letter-recipient-\(recipient.id)"
        button.addAction(UIAction { [weak self] _ in
            self?.toggleRecipient(recipient.id)
        }, for: .touchUpInside)
        return button
    }

    private func toggleRecipient(_ recipientId: String) {
        if selectedRecipientIds.contains(recipientId), selectedRecipientIds.count > 1 {
            selectedRecipientIds.remove(recipientId)
        } else {
            selectedRecipientIds.insert(recipientId)
        }
        refreshRecipientButtons()
        updateSaveButton()
    }

    private func refreshRecipientButtons() {
        recipientButtons.forEach { recipientId, button in
            let isSelected = selectedRecipientIds.contains(recipientId)
            button.backgroundColor = isSelected
                ? DJDesignTokens.Color.accent.withAlphaComponent(0.18)
                : DJDesignTokens.Color.surfaceLow
            button.setTitleColor(
                isSelected ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.textSecondary,
                for: .normal
            )
        }
    }

    @objc private func selectTimeLetterImageTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        defer { picker.dismiss(animated: true) }
        guard let image = info[.originalImage] as? UIImage,
              let imageData = image.jpegData(compressionQuality: 0.88),
              let directoryURL = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ).appendingPathComponent("archive-time-letter-images", isDirectory: true) else {
            return
        }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try imageData.write(to: fileURL, options: [.atomic])
            selectedImageLocalPath = fileURL.path
            imageStatusLabel.text = "已添加 1 张图片"
            imageStatusLabel.textColor = DJDesignTokens.Color.accentDeep
        } catch {
            imageStatusLabel.text = "图片保存失败，请重试"
            imageStatusLabel.textColor = .systemRed
        }
    }
}
