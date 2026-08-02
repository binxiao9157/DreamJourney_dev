import UIKit

struct TimeLetterEntryPayload {
    let note: String
    let openAt: Date
    let recipients: [TimeLetterRecipientSelection]
    let imageLocalPath: String?
    let imageMediaMetadata: ArchiveMediaMetadata?

    init(
        note: String,
        openAt: Date,
        recipients: [TimeLetterRecipientSelection],
        imageLocalPath: String?,
        imageMediaMetadata: ArchiveMediaMetadata? = nil
    ) {
        self.note = note
        self.openAt = openAt
        self.recipients = recipients
        self.imageLocalPath = imageLocalPath
        self.imageMediaMetadata = imageMediaMetadata
    }
}

enum MemoryArchiveTextEntryMode: Equatable {
    case archive
    case ownerTruthSource
}

final class MemoryArchiveTextEntryViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var onSave: ((String) -> Void)?
    var onSaveDraft: ((String) -> Void)?
    var onSaveTimeLetter: ((TimeLetterEntryPayload) -> Void)?
    var onSaveDraftTimeLetter: ((TimeLetterEntryPayload) -> Void)?
    var onSubmitOwnerTruthSource: ((String, @escaping (Result<OwnerTruthTextSourceCaptureReceipt, Error>) -> Void) -> Void)?
    var onOwnerTruthSourceAccepted: ((OwnerTruthTextSourceCaptureReceipt) -> Void)?

    private let kind: MemoryArchiveItemKind
    private let entryMode: MemoryArchiveTextEntryMode
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
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let mediaStore = ArchiveMediaStore.shared
    private var recipientButtons: [String: UIButton] = [:]
    private var availableRecipients: [TimeLetterRecipientSelection] = []
    private var selectedRecipientIds: Set<String> = ["self"]
    private var selectedImageLocalPath: String?
    private var selectedImageMediaMetadata: ArchiveMediaMetadata?
    private var imagePickerAccountLease: AccountLease?
    private var entryAccountLease: AccountLease?
    private var selectedImageCreatedByEntry = false
    private var shouldKeepSelectedImage = false
    private var isSubmittingOwnerTruthSource = false
    private lazy var saveButton = DJComponentFactory.primaryButton(
        title: isTimeLetter
            ? "封存时间信件"
            : (isOwnerTruthSourceEntry ? "提交待确认" : (textSaveButtonTitle ?? "保存到档案馆")),
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

    private var isOwnerTruthSourceEntry: Bool {
        entryMode == .ownerTruthSource
    }

    init(
        kind: MemoryArchiveItemKind,
        initialText: String? = nil,
        textEntryTitle: String? = nil,
        textEntrySubtitle: String? = nil,
        textSaveButtonTitle: String? = nil,
        initialTimeLetterPayload: TimeLetterEntryPayload? = nil,
        entryMode: MemoryArchiveTextEntryMode = .archive,
        accountLease: AccountLease? = nil
    ) {
        self.kind = kind
        self.entryMode = entryMode
        self.initialText = initialText
        self.textEntryTitle = textEntryTitle
        self.textEntrySubtitle = textEntrySubtitle
        self.textSaveButtonTitle = textSaveButtonTitle
        self.initialTimeLetterPayload = initialTimeLetterPayload
        entryAccountLease = accountLease
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let initialTimeLetterPayload {
            selectedRecipientIds = Set(initialTimeLetterPayload.recipients.map(\.id))
            selectedImageLocalPath = initialTimeLetterPayload.imageLocalPath
            selectedImageMediaMetadata = initialTimeLetterPayload.imageMediaMetadata
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let entryAccountLease {
            if !validateImagePickerAccountLease(entryAccountLease, at: .request) {
                self.entryAccountLease = nil
            }
        } else {
            entryAccountLease = captureCurrentAccountLease()
        }
        view.backgroundColor = DJDesignTokens.Color.background
        configureTimeLetterDefaults()
        configureTextEntryDefaults()
        configureSheet()
        buildLayout()
        updateSaveButton()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            removeEntryCreatedImageIfNeeded()
        }
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
        titleLabel.text = isTimeLetter
            ? "录入时间信件"
            : (isOwnerTruthSourceEntry ? "提交待确认记忆" : (textEntryTitle ?? "添加文字描述"))
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = isTimeLetter
            ? "写给未来某一天的自己或家人；支持文字和图片，封存后不可删除或修改。"
            : (isOwnerTruthSourceEntry
                ? "内容会先整理为候选记忆，只有你确认后才会成为回响可使用的正式记忆。"
                : (textEntrySubtitle ?? "写下一段想封存的片段，人物、地点、称呼和生活细节都可以。"))
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

        placeholderLabel.text = isTimeLetter
            ? "这封信想说什么？"
            : (isOwnerTruthSourceEntry ? "写下想提交确认的一段记忆" : "这段记忆是什么？")
        placeholderLabel.font = DJDesignTokens.Font.body(16)
        placeholderLabel.textColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.56)

        saveButton.titleLabel?.font = DJDesignTokens.Font.label(16)
        saveButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        saveButton.layer.cornerRadius = 28

        let helperLabel = UILabel()
        helperLabel.text = isTimeLetter
            ? "封存后会按打开时间提醒本人和收件人。"
            : (isOwnerTruthSourceEntry
                ? "仅提交你主动写下的内容；提交后可在“待确认记忆”中确认、更正或拒绝。"
                : "仅保存你主动录入的内容，不会展示聊天原文。")
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
        let canSave = !isSubmittingOwnerTruthSource
            && hasText
            && (!isTimeLetter || !selectedRecipientIds.isEmpty)
        saveButton.isEnabled = canSave
        saveButton.alpha = canSave ? 1 : 0.55
        if isOwnerTruthSourceEntry {
            saveButton.setTitle(
                isSubmittingOwnerTruthSource ? "正在提交..." : "提交待确认",
                for: .normal
            )
            textView.isEditable = !isSubmittingOwnerTruthSource
        }
        draftButton.isEnabled = canSave
        draftButton.alpha = canSave ? 1 : 0.55
    }

    @objc private func cancelTapped() {
        guard !isSubmittingOwnerTruthSource else { return }
        removeEntryCreatedImageIfNeeded()
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        if isTimeLetter {
            saveTimeLetter(with: onSaveTimeLetter)
        } else if isOwnerTruthSourceEntry {
            submitOwnerTruthSource()
        } else {
            save(with: onSave)
        }
    }

    @objc private func saveDraftTapped() {
        saveTimeLetter(with: onSaveDraftTimeLetter)
    }

    private func save(with handler: ((String) -> Void)?) {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty,
              let accountLease = entryAccountLease,
              validateImagePickerAccountLease(accountLease, at: .commit) else {
            updateSaveButton()
            return
        }
        dismiss(animated: true) { [weak self] in
            guard let self,
                  self.validateImagePickerAccountLease(accountLease, at: .ui) else { return }
            handler?(rawText)
        }
    }

    private func submitOwnerTruthSource() {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty,
              let accountLease = entryAccountLease,
              validateImagePickerAccountLease(accountLease, at: .commit),
              let handler = onSubmitOwnerTruthSource else {
            updateSaveButton()
            return
        }

        isSubmittingOwnerTruthSource = true
        updateSaveButton()
        handler(rawText) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.validateImagePickerAccountLease(accountLease, at: .ui) else {
                    self.isSubmittingOwnerTruthSource = false
                    self.updateSaveButton()
                    return
                }
                self.isSubmittingOwnerTruthSource = false
                self.updateSaveButton()
                switch result {
                case .success(let receipt):
                    self.dismiss(animated: true) { [weak self] in
                        self?.onOwnerTruthSourceAccepted?(receipt)
                    }
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "提交未完成",
                        message: error.localizedDescription.isEmpty
                            ? "暂时无法提交待确认记忆，请保持内容后重试。"
                            : error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func saveTimeLetter(with handler: ((TimeLetterEntryPayload) -> Void)?) {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty,
              let accountLease = entryAccountLease,
              validateImagePickerAccountLease(accountLease, at: .commit) else {
            removeEntryCreatedImageIfNeeded()
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
            imageLocalPath: selectedImageLocalPath,
            imageMediaMetadata: selectedImageMediaMetadata
        )
        shouldKeepSelectedImage = true
        dismiss(animated: true) { [weak self] in
            guard let self,
                  self.validateImagePickerAccountLease(accountLease, at: .ui) else {
                self?.shouldKeepSelectedImage = false
                self?.removeEntryCreatedImageIfNeeded()
                return
            }
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
        guard let accountLease = captureImagePickerAccountLease() else {
            imageStatusLabel.text = "账号状态已变化，请重新进入后再选择图片"
            imageStatusLabel.textColor = .systemRed
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = self
        imagePickerAccountLease = accountLease
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        imagePickerAccountLease = nil
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        defer {
            imagePickerAccountLease = nil
            picker.dismiss(animated: true)
        }
        guard let accountLease = imagePickerAccountLease,
              validateImagePickerAccountLease(accountLease, at: .ui) else {
            return
        }
        guard let image = info[.originalImage] as? UIImage,
              let imageData = image.jpegData(compressionQuality: 0.88) else {
            return
        }
        do {
            let mediaMetadata = try commitSelectedImage(imageData, accountLease: accountLease)
            guard validateImagePickerAccountLease(accountLease, at: .ui) else {
                removeMedia(mediaMetadata, accountLease: accountLease)
                return
            }
            removeEntryCreatedImageIfNeeded()
            selectedImageLocalPath = mediaMetadata.relativePath
            selectedImageMediaMetadata = mediaMetadata
            selectedImageCreatedByEntry = true
            shouldKeepSelectedImage = false
            imageStatusLabel.text = "已添加 1 张图片"
            imageStatusLabel.textColor = DJDesignTokens.Color.accentDeep
        } catch {
            if validateImagePickerAccountLease(accountLease, at: .ui) {
                imageStatusLabel.text = "图片保存失败，请重试"
                imageStatusLabel.textColor = .systemRed
            }
        }
    }

    private func captureImagePickerAccountLease() -> AccountLease? {
        guard let accountLease = entryAccountLease,
              validateImagePickerAccountLease(accountLease, at: .request) else {
            return nil
        }
        return accountLease
    }

    private func captureCurrentAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              validateImagePickerAccountLease(accountLease, at: .request) else {
            return nil
        }
        return accountLease
    }

    private func validateImagePickerAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func commitSelectedImage(
        _ imageData: Data,
        accountLease: AccountLease
    ) throws -> ArchiveMediaMetadata {
        guard validateImagePickerAccountLease(accountLease, at: .commit) else {
            throw TimeLetterImageCommitError.accountSessionChanged
        }
        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        guard scope.isValid else { throw TimeLetterImageCommitError.accountSessionChanged }
        let mediaMetadata = try mediaStore.write(
            imageData,
            fileExtension: "jpg",
            scope: scope,
            storageClass: .original
        )
        guard validateImagePickerAccountLease(accountLease, at: .commit) else {
            try? mediaStore.remove(mediaMetadata, scope: scope, storageClass: .original)
            throw TimeLetterImageCommitError.accountSessionChanged
        }
        return mediaMetadata
    }

    private func removeEntryCreatedImageIfNeeded() {
        guard selectedImageCreatedByEntry,
              !shouldKeepSelectedImage,
              let selectedImageMediaMetadata,
              let entryAccountLease else { return }
        removeMedia(selectedImageMediaMetadata, accountLease: entryAccountLease)
        self.selectedImageLocalPath = nil
        self.selectedImageMediaMetadata = nil
        selectedImageCreatedByEntry = false
    }

    private func removeMedia(
        _ mediaMetadata: ArchiveMediaMetadata,
        accountLease: AccountLease
    ) {
        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        try? mediaStore.remove(mediaMetadata, scope: scope, storageClass: .original)
    }
}

private enum TimeLetterImageCommitError: Error {
    case accountSessionChanged
}
