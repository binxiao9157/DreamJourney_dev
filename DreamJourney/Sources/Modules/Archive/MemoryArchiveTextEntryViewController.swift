import UIKit

final class MemoryArchiveTextEntryViewController: UIViewController, UITextViewDelegate {
    var onSave: ((String) -> Void)?

    private let kind: MemoryArchiveItemKind
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private lazy var saveButton = DJComponentFactory.primaryButton(
        title: "保存到档案馆",
        target: self,
        action: #selector(saveTapped)
    )

    private var isTimeLetter: Bool {
        kind == .timeLetter
    }

    init(kind: MemoryArchiveItemKind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        configureSheet()
        buildLayout()
        updateSaveButton()
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
        titleLabel.text = isTimeLetter ? "录入时间信件" : "添加文字描述"
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = isTimeLetter
            ? "写给未来某一天的自己或家人，这会成为之后回响里的情感线索。"
            : "写下一段想封存的片段，人物、地点、称呼和生活细节都可以。"
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
        helperLabel.text = "仅保存你主动录入的内容，不会展示聊天原文。"
        helperLabel.font = DJDesignTokens.Font.label(12)
        helperLabel.textColor = DJDesignTokens.Color.textTertiary
        helperLabel.numberOfLines = 0

        let contentStack = UIStackView(arrangedSubviews: [headerStack, subtitleLabel, inputCard, helperLabel, saveButton])
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
        [contentStack, headerStack, titleLabel, cancelButton, inputCard, textView, placeholderLabel, saveButton].forEach {
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

            saveButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSaveButton()
    }

    private func updateSaveButton() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveButton.isEnabled = hasText
        saveButton.alpha = hasText ? 1 : 0.55
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            updateSaveButton()
            return
        }
        let onSave = onSave
        dismiss(animated: true) {
            onSave?(rawText)
        }
    }
}
