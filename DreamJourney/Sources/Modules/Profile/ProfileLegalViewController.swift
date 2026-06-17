import UIKit

final class ProfileLegalViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "法律法规"
        view.backgroundColor = DJDesignTokens.Color.background
        configureScrollView()
        buildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: DJDesignTokens.Color.textPrimary,
            .font: DJDesignTokens.Font.title(18),
        ]
    }

    private func configureScrollView() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 24,
            leading: DJDesignTokens.Spacing.page,
            bottom: 36,
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
    }

    private func buildContent() {
        contentStack.addArrangedSubview(makeHeader())
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last!)

        legalSections.forEach { section in
            contentStack.addArrangedSubview(makeSectionCard(section))
        }
    }

    private func makeHeader() -> UIView {
        let container = UIView()

        let titleLabel = makeLabel(
            text: "使用说明与免责声明",
            font: DJDesignTokens.Font.title(22),
            color: DJDesignTokens.Color.textPrimary
        )
        let subtitleLabel = makeLabel(
            text: "寻梦环游用于陪伴、回忆整理与关怀信号展示。以下内容帮助你理解 AI 辅助能力的边界。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeSectionCard(_ section: LegalSection) -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor

        let titleLabel = makeLabel(
            text: section.title,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
        let bodyLabel = makeLabel(
            text: section.body,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        bodyLabel.lineSpacing = 4

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8

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

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }
}

private struct LegalSection {
    let title: String
    let body: String
}

private let legalSections: [LegalSection] = [
    LegalSection(
        title: "AI 辅助说明",
        body: "寻梦环游会基于你主动提供的对话、图片说明和记忆档案生成陪伴回复与回忆线索。AI 内容可能存在遗漏或表达偏差，重要信息请以本人确认和真实资料为准。"
    ),
    LegalSection(
        title: "心理支持边界",
        body: "心境追踪和关怀提醒只用于日常陪伴与风险提示，不是医疗诊断，也不能替代心理医生、精神科医生或其他专业机构的评估。"
    ),
    LegalSection(
        title: "隐私与数据",
        body: "长辈关怀仅展示情绪指数、认知指数、睡眠状态、孤独指数和风险提醒等结果信号，不展示聊天原文。请在获得家人知情同意后再上传或分享个人资料。"
    ),
    LegalSection(
        title: "数字人与伦理",
        body: "数字人形象和语音能力应当用于纪念、陪伴和家庭沟通，不应冒充真实本人进行欺骗、商业授权或未经同意的公开传播。"
    ),
    LegalSection(
        title: "紧急情况",
        body: "如果出现自伤、伤人、严重抑郁风险或其他紧急情况，请立即联系当地急救、警方、医院或身边可信赖的家人朋友，应用内提示不能替代紧急救助。"
    ),
]

private extension UILabel {
    var lineSpacing: CGFloat {
        get { 0 }
        set {
            guard let text else { return }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = newValue
            paragraphStyle.lineBreakMode = lineBreakMode
            attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: font as Any,
                    .foregroundColor: textColor as Any,
                    .paragraphStyle: paragraphStyle,
                ]
            )
        }
    }
}
