import UIKit

private enum ArchiveCreationSheetLayout {
    static let titleFontSize: CGFloat = 28
    static let subtitleFontSize: CGFloat = 14
    static let contentTopMargin: CGFloat = 24
    static let contentBottomMargin: CGFloat = 24
    static let contentStackSpacing: CGFloat = 12
    static let optionSpacing: CGFloat = 12
    static let optionCardInset: CGFloat = 14
    static let optionRowSpacing: CGFloat = 12
    static let optionIconSize: CGFloat = 40
    static let optionIconSymbolSize: CGFloat = 20
    static let optionMinHeight: CGFloat = 76
    static let optionTitleFontSize: CGFloat = 16
    static let optionSubtitleFontSize: CGFloat = 13
    static let optionTextSpacing: CGFloat = 4
}

protocol MemoryArchiveCreationSheetViewControllerDelegate: AnyObject {
    func memoryArchiveCreationSheet(
        _ viewController: MemoryArchiveCreationSheetViewController,
        didSelect option: MemoryArchiveCreationOption
    )
}

final class MemoryArchiveCreationSheetViewController: UIViewController {
    weak var delegate: MemoryArchiveCreationSheetViewControllerDelegate?

    private let options: [MemoryArchiveCreationOption]
    private let stackView = UIStackView()

    init(options: [MemoryArchiveCreationOption]) {
        self.options = options
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
            sheet.detents = options.count > 4 ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DJDesignTokens.Radius.extraLarge
        }
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "封存新记忆"
        titleLabel.font = DJDesignTokens.Font.display(ArchiveCreationSheetLayout.titleFontSize)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "选择一种素材，把它整理进记忆档案馆。这些片段会继续补足称呼、关系、偏好与生活线索。"
        subtitleLabel.font = DJDesignTokens.Font.body(ArchiveCreationSheetLayout.subtitleFontSize)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stackView.axis = .vertical
        stackView.spacing = ArchiveCreationSheetLayout.optionSpacing

        options.forEach { option in
            stackView.addArrangedSubview(makeOptionButton(option))
        }

        let contentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, stackView])
        contentStack.axis = .vertical
        contentStack.spacing = ArchiveCreationSheetLayout.contentStackSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ArchiveCreationSheetLayout.contentTopMargin,
            leading: DJDesignTokens.Spacing.page,
            bottom: ArchiveCreationSheetLayout.contentBottomMargin,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func makeOptionButton(_ option: MemoryArchiveCreationOption) -> UIControl {
        let control = MemoryArchiveCreationOptionControl(option: option)
        if option.isAvailable {
            control.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        }
        return control
    }

    @objc private func optionTapped(_ sender: MemoryArchiveCreationOptionControl) {
        let option = sender.option
        guard option.isAvailable else { return }
        let delegate = delegate
        dismiss(animated: true) {
            delegate?.memoryArchiveCreationSheet(self, didSelect: option)
        }
    }
}

private final class MemoryArchiveCreationOptionControl: UIControl {
    let option: MemoryArchiveCreationOption

    private let cardView = UIView()

    init(option: MemoryArchiveCreationOption) {
        self.option = option
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            cardView.backgroundColor = isHighlighted
                ? DJDesignTokens.Color.surfaceContainer
                : DJDesignTokens.Color.surface
        }
    }

    private func setupView() {
        isEnabled = option.isAvailable
        accessibilityTraits = option.isAvailable ? .button : [.button, .notEnabled]
        accessibilityLabel = option.title
        accessibilityValue = option.isAvailable ? nil : "暂不可用"

        cardView.backgroundColor = DJDesignTokens.Color.surface
        cardView.layer.cornerRadius = DJDesignTokens.Radius.large
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        cardView.isUserInteractionEnabled = false
        DJDesignTokens.applySoftShadow(to: cardView)

        let iconContainer = UIView()
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        iconContainer.layer.cornerRadius = DJDesignTokens.Radius.medium

        let iconView = UIImageView(image: UIImage(systemName: option.iconName))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = option.title
        titleLabel.font = DJDesignTokens.Font.title(ArchiveCreationSheetLayout.optionTitleFontSize)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1

        let subtitleLabel = UILabel()
        subtitleLabel.text = option.subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(ArchiveCreationSheetLayout.optionSubtitleFontSize)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = ArchiveCreationSheetLayout.optionTextSpacing

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DJDesignTokens.Color.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isHidden = !option.isAvailable

        if !option.isAvailable {
            cardView.alpha = 0.58
        }

        let rowStack = UIStackView(arrangedSubviews: [iconContainer, textStack, chevron])
        rowStack.alignment = .center
        rowStack.spacing = ArchiveCreationSheetLayout.optionRowSpacing
        rowStack.isUserInteractionEnabled = false

        addSubview(cardView)
        cardView.addSubview(rowStack)
        iconContainer.addSubview(iconView)

        [cardView, rowStack, iconContainer, iconView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            rowStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: ArchiveCreationSheetLayout.optionCardInset),
            rowStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: ArchiveCreationSheetLayout.optionCardInset),
            rowStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -ArchiveCreationSheetLayout.optionCardInset),
            rowStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -ArchiveCreationSheetLayout.optionCardInset),

            iconContainer.widthAnchor.constraint(equalToConstant: ArchiveCreationSheetLayout.optionIconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: ArchiveCreationSheetLayout.optionIconSize),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: ArchiveCreationSheetLayout.optionIconSymbolSize),
            iconView.heightAnchor.constraint(equalToConstant: ArchiveCreationSheetLayout.optionIconSymbolSize),

            heightAnchor.constraint(greaterThanOrEqualToConstant: ArchiveCreationSheetLayout.optionMinHeight),
        ])
    }
}
