import UIKit

final class ProfileElderCareDashboardViewController: UIViewController {

    private let snapshot: ProfileCareSnapshot
    private let context: DigitalHumanContext
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(snapshot: ProfileCareSnapshot, context: DigitalHumanContext) {
        self.snapshot = snapshot
        self.context = context
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "长辈关怀"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "elderCareDashboard"
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
            bottom: 40,
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
        contentStack.setCustomSpacing(22, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeSummaryCard())
        if let dataStateCard = makeDataStateCard(snapshot.dataState) {
            contentStack.addArrangedSubview(dataStateCard)
        }
        contentStack.addArrangedSubview(makeMetricGrid())
        contentStack.addArrangedSubview(makeRiskCard())
        contentStack.addArrangedSubview(makePrivacyCard())
    }

    private func makeHeader() -> UIView {
        let container = UIView()

        let eyebrowLabel = makeLabel(
            text: context.isSelfAssistant ? "个人状态" : "\(context.resolvedDisplayName) 的关怀看板",
            font: DJDesignTokens.Font.label(12),
            color: DJDesignTokens.Color.textTertiary
        )
        let titleLabel = makeLabel(
            text: "长辈关怀",
            font: DJDesignTokens.Font.display(30),
            color: DJDesignTokens.Color.textPrimary
        )
        let subtitleLabel = makeLabel(
            text: "仅查看结果，不查看聊天内容。这里呈现情绪、认知、睡眠、孤独感和风险提醒等聚合信号，帮助家人更温和地陪伴。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        subtitleLabel.lineSpacing = 4

        let stack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, subtitleLabel])
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

    private func makeSummaryCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(
            text: snapshot.moodTitle,
            font: DJDesignTokens.Font.title(18),
            color: DJDesignTokens.Color.textPrimary
        )
        let statusLabel = makePill(text: snapshot.moodStatus)
        let bodyLabel = makeLabel(
            text: snapshot.syncCaption,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        bodyLabel.lineSpacing = 4

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12

        let stack = UIStackView(arrangedSubviews: [header, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 12

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

    private func makeDataStateCard(_ state: ProfileCareDataState) -> UIView? {
        let title: String
        let message: String

        switch state {
        case .available:
            return nil
        case .loading:
            title = "正在同步关怀信号"
            message = state.message
        case .empty:
            title = "暂无可用关怀信号"
            message = state.message
        case .stale:
            title = "数据可能不是最新"
            message = state.message
        case .failed:
            title = "关怀信号加载失败"
            message = state.message
        }

        return makeStateCard(title: title, message: message)
    }

    private func makeStateCard(title: String, message: String) -> UIView {
        let card = makeCard()
        card.backgroundColor = DJDesignTokens.Color.surfaceLow

        let titleLabel = makeLabel(
            text: title,
            font: DJDesignTokens.Font.title(16),
            color: DJDesignTokens.Color.textPrimary
        )
        let bodyLabel = makeLabel(
            text: message,
            font: DJDesignTokens.Font.body(13),
            color: DJDesignTokens.Color.textSecondary
        )
        bodyLabel.lineSpacing = 3

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    private func makeMetricGrid() -> UIView {
        let container = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let metrics = [
            CareDashboardMetric(title: "情绪指数", valueText: ProfileCareCopy.signalPercent(snapshot.emotionalIndex), value: snapshot.emotionalIndex),
            CareDashboardMetric(title: "认知指数", valueText: ProfileCareCopy.signalPercent(snapshot.cognitiveIndex), value: snapshot.cognitiveIndex),
            CareDashboardMetric(title: "睡眠状态", valueText: snapshot.sleepStatus, value: nil),
            CareDashboardMetric(title: "孤独指数", valueText: ProfileCareCopy.signalPercent(snapshot.lonelinessIndex), value: snapshot.lonelinessIndex),
        ]

        for rowMetrics in stride(from: 0, to: metrics.count, by: 2) {
            let first = makeMetricCard(metrics[rowMetrics])
            let second = rowMetrics + 1 < metrics.count ? makeMetricCard(metrics[rowMetrics + 1]) : UIView()
            let row = UIStackView(arrangedSubviews: [first, second])
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 10
            stack.addArrangedSubview(row)
        }

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

    private func makeMetricCard(_ metric: CareDashboardMetric) -> UIView {
        let card = makeCard()

        let titleLabel = makeLabel(
            text: metric.title,
            font: DJDesignTokens.Font.label(12),
            color: DJDesignTokens.Color.textTertiary
        )
        let valueLabel = makeLabel(
            text: metric.valueText,
            font: DJDesignTokens.Font.title(metric.value == nil ? 17 : 22),
            color: DJDesignTokens.Color.textPrimary
        )
        valueLabel.minimumScaleFactor = 0.82
        valueLabel.adjustsFontSizeToFitWidth = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 6

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        if let value = metric.value {
            let bar = CareDashboardSignalBar(value: value)
            stack.addArrangedSubview(bar)
            bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        }

        return card
    }

    private func makeRiskCard() -> UIView {
        let card = makeCard()

        let titleLabel = makeLabel(
            text: "风险提醒",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
        let bodyLabel = makeLabel(
            text: snapshot.riskReminder,
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        bodyLabel.lineSpacing = 4

        let noteLabel = makeLabel(
            text: "如出现自伤、伤人或其他紧急情况，请立即联系当地急救、警方、医院或身边可信赖的人。",
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.danger
        )
        noteLabel.lineSpacing = 3

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 10

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

    private func makePrivacyCard() -> UIView {
        let card = makeCard()
        card.backgroundColor = DJDesignTokens.Color.surfaceLow

        let titleLabel = makeLabel(
            text: "隐私边界",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        )
        let bodyLabel = makeLabel(
            text: "子女端仅查看结果，不查看聊天内容。系统只呈现聚合后的关怀信号，避免把长辈与数字人的私密表达直接暴露给家人。",
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

    private func makeCard() -> UIView {
        let card = DJComponentFactory.cardView(radius: DJDesignTokens.Radius.large)
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.5).cgColor
        return card
    }

    private func makePill(text: String) -> UILabel {
        let label = CareDashboardPaddingLabel(insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        label.text = text
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.65)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
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

private final class CareDashboardPaddingLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}

private struct CareDashboardMetric {
    let title: String
    let valueText: String
    let value: Double?
}

private final class CareDashboardSignalBar: UIView {
    private let value: CGFloat
    private let fillView = UIView()

    init(value: Double) {
        self.value = min(max(CGFloat(value), 0), 1)
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillView.frame = CGRect(x: 0, y: 0, width: bounds.width * value, height: bounds.height)
        fillView.layer.cornerRadius = bounds.height / 2
    }

    private func setupView() {
        backgroundColor = DJDesignTokens.Color.surfaceContainer
        layer.cornerRadius = 4
        layer.masksToBounds = true

        fillView.backgroundColor = DJDesignTokens.Color.accent
        addSubview(fillView)
    }
}

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
