import UIKit

final class MemoryArchivePhotoEntryViewController: UIViewController {
    var onChoosePhoto: (() -> Void)?
    var onUseSamplePhoto: (() -> Void)?

    init() {
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
        titleLabel.text = "选择照片"
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "照片本身先保存在本地，后续可补充说明来形成线索，例如人物、地点和场景。"
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

        let previewCard = UIView()
        previewCard.backgroundColor = DJDesignTokens.Color.surface
        previewCard.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        previewCard.layer.borderWidth = 1
        previewCard.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        previewCard.clipsToBounds = true
        DJDesignTokens.applySoftShadow(to: previewCard)

        let imageView = UIImageView(image: UIImage(named: "default_memory_1"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.22)

        let hintLabel = PhotoEntryPaddingLabel(horizontalInset: 12, verticalInset: 7)
        hintLabel.text = "照片将保存到记忆档案馆"
        hintLabel.font = DJDesignTokens.Font.label(12)
        hintLabel.textColor = .white
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        hintLabel.layer.cornerRadius = 14
        hintLabel.layer.masksToBounds = true

        let chooseButton = DJComponentFactory.primaryButton(
            title: "从相册选择",
            target: self,
            action: #selector(choosePhotoTapped)
        )
        chooseButton.titleLabel?.font = DJDesignTokens.Font.label(16)
        chooseButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        chooseButton.layer.cornerRadius = 28

        let helperLabel = UILabel()
        helperLabel.text = "仅保存你主动选择的照片，不展示聊天原文。"
        helperLabel.font = DJDesignTokens.Font.label(12)
        helperLabel.textColor = DJDesignTokens.Color.textTertiary
        helperLabel.numberOfLines = 0

        var arrangedSubviews: [UIView] = [
            headerStack,
            subtitleLabel,
            previewCard,
            helperLabel,
            chooseButton,
        ]

        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        let sampleButton = UIButton(type: .system)
        sampleButton.setTitle("使用样张封存", for: .normal)
        sampleButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        sampleButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        sampleButton.backgroundColor = DJDesignTokens.Color.surfaceContainer
        sampleButton.layer.cornerRadius = 24
        sampleButton.addTarget(self, action: #selector(samplePhotoTapped), for: .touchUpInside)
        arrangedSubviews.append(sampleButton)
        #endif

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
        previewCard.addSubview(imageView)
        previewCard.addSubview(overlay)
        previewCard.addSubview(hintLabel)

        [
            contentStack,
            headerStack,
            titleLabel,
            cancelButton,
            previewCard,
            imageView,
            overlay,
            hintLabel,
            helperLabel,
            chooseButton,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        arrangedSubviews.last?.translatesAutoresizingMaskIntoConstraints = false
        #endif

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),

            previewCard.heightAnchor.constraint(equalToConstant: 190),

            imageView.topAnchor.constraint(equalTo: previewCard.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor),

            overlay.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor),
            overlay.heightAnchor.constraint(equalToConstant: 70),

            hintLabel.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            hintLabel.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16),

            chooseButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if let sampleButton = arrangedSubviews.last {
            sampleButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        }
        #endif
    }

    @objc private func choosePhotoTapped() {
        let onChoosePhoto = onChoosePhoto
        dismiss(animated: true) {
            onChoosePhoto?()
        }
    }

    @objc private func samplePhotoTapped() {
        let onUseSamplePhoto = onUseSamplePhoto
        dismiss(animated: true) {
            onUseSamplePhoto?()
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

private final class PhotoEntryPaddingLabel: UILabel {
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
