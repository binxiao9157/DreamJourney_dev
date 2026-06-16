import UIKit

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
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DJDesignTokens.Radius.large
        }
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "封存新记忆"
        titleLabel.font = DJDesignTokens.Font.title(24)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "选择一种素材，把它整理进记忆档案馆。"
        subtitleLabel.font = DJDesignTokens.Font.body(14)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        stackView.axis = .vertical
        stackView.spacing = 12

        options.forEach { option in
            stackView.addArrangedSubview(makeOptionButton(option))
        }

        let contentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, stackView])
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 28,
            leading: DJDesignTokens.Spacing.page,
            bottom: 24,
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
        control.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return control
    }

    @objc private func optionTapped(_ sender: MemoryArchiveCreationOptionControl) {
        let option = sender.option
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
        accessibilityTraits = .button
        accessibilityLabel = option.title

        cardView.backgroundColor = DJDesignTokens.Color.surface
        cardView.layer.cornerRadius = DJDesignTokens.Radius.medium
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.45).cgColor

        let iconContainer = UIView()
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceLow
        iconContainer.layer.cornerRadius = DJDesignTokens.Radius.medium

        let iconView = UIImageView(image: UIImage(systemName: option.iconName))
        iconView.tintColor = DJDesignTokens.Color.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = option.title
        titleLabel.font = DJDesignTokens.Font.title(16)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 1

        let subtitleLabel = UILabel()
        subtitleLabel.text = option.subtitle
        subtitleLabel.font = DJDesignTokens.Font.body(13)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DJDesignTokens.Color.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [iconContainer, textStack, chevron])
        rowStack.alignment = .center
        rowStack.spacing = 12
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

            rowStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            rowStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            rowStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])
    }
}
