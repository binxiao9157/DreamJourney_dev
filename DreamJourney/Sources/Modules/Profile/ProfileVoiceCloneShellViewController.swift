import UIKit

final class ProfileVoiceCloneShellViewController: UIViewController {
    private let snapshot: VoiceCloneProfileSnapshot
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(snapshot: VoiceCloneProfileSnapshot = VoiceCloneService.shared.voiceCloneShellSnapshot()) {
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "声音克隆"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-voice-clone-shell"
        setupLayout()
    }

    private func setupLayout() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 18,
            leading: DJDesignTokens.Spacing.page,
            bottom: 32,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.addArrangedSubview(makeContractCard())
        contentStack.addArrangedSubview(makeActionCard())
    }

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        let iconView = UIImageView(image: UIImage(systemName: "waveform.badge.mic"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let titleLabel = makeLabel(
            text: "声音克隆",
            font: DJDesignTokens.Font.title(22),
            color: DJDesignTokens.Color.textPrimary
        )

        let subtitleLabel = makeLabel(
            text: "此功能默认隐藏。公开前需要完成授权、声音样本质量、删除/禁用合同和合规验收。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let statusStack = UIStackView()
        statusStack.axis = .vertical
        statusStack.spacing = 10
        statusStack.addArrangedSubview(makeInfoRow(title: "声音样本状态", value: snapshot.sampleStatus.displayText))
        statusStack.addArrangedSubview(makeInfoRow(title: "voiceProfileId", value: snapshot.voiceProfileId))

        card.addSubview(stack)
        [stack, iconView, titleLabel, subtitleLabel, statusStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(statusStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 38),
            iconView.heightAnchor.constraint(equalToConstant: 38),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeContractCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(makeSectionTitle("授权说明"))
        stack.addArrangedSubview(makeBody(snapshot.authorizationCopy))
        stack.addArrangedSubview(makeSectionTitle("删除/禁用合同"))
        stack.addArrangedSubview(makeBody(snapshot.disableContract))
        stack.addArrangedSubview(makeBody(snapshot.deleteContract))

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeActionCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let disableButton = makeDisabledActionButton(title: "禁用声音样本（未开放）")
        let deleteButton = makeDisabledActionButton(title: "删除声音样本（未开放）")
        stack.addArrangedSubview(disableButton)
        stack.addArrangedSubview(deleteButton)

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeInfoRow(title: String, value: String) -> UIView {
        let row = UIStackView()
        row.alignment = .firstBaseline
        row.spacing = 12

        let titleLabel = makeLabel(
            text: title,
            font: DJDesignTokens.Font.label(12),
            color: DJDesignTokens.Color.textTertiary
        )
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = makeLabel(
            text: value,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textSecondary
        )
        valueLabel.textAlignment = .right

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        makeLabel(
            text: text,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
    }

    private func makeBody(_ text: String) -> UILabel {
        makeLabel(
            text: text,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
    }

    private func makeDisabledActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(14)
        button.setTitleColor(DJDesignTokens.Color.textTertiary, for: .disabled)
        button.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        button.layer.cornerRadius = DJDesignTokens.Radius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        button.isEnabled = false
        return button
    }

    private func makeCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.46).cgColor
        return card
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }
}
