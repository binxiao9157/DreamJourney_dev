import UIKit

final class MemoryArchiveDetailViewController: UIViewController {
    private let item: MemoryArchiveItem
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    init(item: MemoryArchiveItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "档案详情"
        view.backgroundColor = DJDesignTokens.Color.background
        setupLayout()
    }

    private func setupLayout() {
        scrollView.backgroundColor = DJDesignTokens.Color.background
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.spacing = DJDesignTokens.Spacing.card
        contentStack.layoutMargins = UIEdgeInsets(
            top: DJDesignTokens.Spacing.page,
            left: DJDesignTokens.Spacing.page,
            bottom: DJDesignTokens.Spacing.section,
            right: DJDesignTokens.Spacing.page
        )
        contentStack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        [scrollView, contentStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

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

        contentStack.addArrangedSubview(makeHeaderCard())

        if let mediaCard = makeMediaCard() {
            contentStack.addArrangedSubview(mediaCard)
        }

        contentStack.addArrangedSubview(makeTextCard(title: "原始内容", body: item.note))
        contentStack.addArrangedSubview(makeAnalysisCard())
    }

    private func makeHeaderCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        let stack = UIStackView()
        stack.alignment = .top
        stack.spacing = 14

        let iconContainer = makeIconContainer(iconName: item.kind.archiveIconName)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = DJDesignTokens.Font.display(28)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let badgeStack = UIStackView()
        badgeStack.spacing = 8
        badgeStack.alignment = .center
        badgeStack.addArrangedSubview(makeBadge(text: item.kind.archiveDisplayName))
        badgeStack.addArrangedSubview(makeBadge(
            text: item.analysisStatus.archiveDisplayName,
            textColor: DJDesignTokens.Color.textSecondary,
            backgroundColor: DJDesignTokens.Color.surfaceContainer
        ))

        let dateLabel = UILabel()
        dateLabel.text = Self.dateFormatter.string(from: item.createdAt)
        dateLabel.font = DJDesignTokens.Font.body(13)
        dateLabel.textColor = DJDesignTokens.Color.textTertiary

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(badgeStack)
        textStack.addArrangedSubview(dateLabel)

        card.addSubview(stack)
        [stack, iconContainer, textStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeMediaCard() -> UIView? {
        guard item.kind == .photo,
              let localPath = item.localPath,
              let image = UIImage(contentsOfFile: localPath) else {
            return nil
        }

        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = DJDesignTokens.Radius.small

        card.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.74),
        ])

        return card
    }

    private func makeTextCard(title: String, body: String) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let titleLabel = DJComponentFactory.sectionLabel(title)

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DJDesignTokens.Font.body(15)
        bodyLabel.textColor = DJDesignTokens.Color.textSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        card.addSubview(stack)
        [stack, titleLabel, bodyLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bodyLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeAnalysisCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.medium)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        let titleLabel = DJComponentFactory.sectionLabel("分析线索")

        let summaryLabel = UILabel()
        summaryLabel.text = item.analysisSummary ?? "暂未生成分析摘要。"
        summaryLabel.font = DJDesignTokens.Font.body(15)
        summaryLabel.textColor = DJDesignTokens.Color.textSecondary
        summaryLabel.numberOfLines = 0

        let tagSection = makeChipSection(
            title: "标签",
            values: item.tags,
            emptyText: "暂无标签"
        )

        let peopleSection = makeChipSection(
            title: "人物线索",
            values: item.detectedPeople,
            emptyText: item.analysisStatus == .pending ? "等待识别" : "暂无人物线索"
        )

        card.addSubview(stack)
        [stack, titleLabel, summaryLabel, tagSection, peopleSection].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(summaryLabel)
        stack.addArrangedSubview(tagSection)
        stack.addArrangedSubview(peopleSection)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeChipSection(title: String, values: [String], emptyText: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DJDesignTokens.Font.label(12)
        titleLabel.textColor = DJDesignTokens.Color.textTertiary

        let chipStack = UIStackView()
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .leading

        let displayValues = values.isEmpty ? [emptyText] : values
        displayValues.forEach { value in
            chipStack.addArrangedSubview(makeBadge(
                text: value,
                textColor: values.isEmpty ? DJDesignTokens.Color.textTertiary : DJDesignTokens.Color.accentDeep,
                backgroundColor: DJDesignTokens.Color.surfaceLow
            ))
        }

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(chipStack)
        return stack
    }

    private func makeIconContainer(iconName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = DJDesignTokens.Color.surfaceLow
        container.layer.cornerRadius = DJDesignTokens.Radius.medium

        let imageView = UIImageView(image: UIImage(systemName: iconName))
        imageView.tintColor = DJDesignTokens.Color.accent
        imageView.contentMode = .scaleAspectFit

        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
        ])

        return container
    }

    private func makeBadge(
        text: String,
        textColor: UIColor = DJDesignTokens.Color.accentDeep,
        backgroundColor: UIColor = DJDesignTokens.Color.surfaceLow
    ) -> UILabel {
        let label = DetailPaddingLabel(horizontalInset: 9, verticalInset: 5)
        label.text = text
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = textColor
        label.backgroundColor = backgroundColor
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }
}

private final class DetailPaddingLabel: UILabel {
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
