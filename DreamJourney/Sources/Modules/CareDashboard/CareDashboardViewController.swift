import UIKit

final class CareDashboardViewController: UIViewController {

    private let analyzer = CareSignalAnalyzer()
    private var snapshot: CareSignalSnapshot?

    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "长辈关怀看板"
        view.backgroundColor = .warmBackground
        setupNavigation()
        setupLayout()
        reloadSnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .warmAccent
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        [scrollView, stackView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -28),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -36),
        ])
    }

    @objc private func refreshTapped() {
        reloadSnapshot()
        showToast("关怀信号已刷新", type: .success)
    }

    private func reloadSnapshot() {
        let turns = ConversationMemoryManager.shared.getCurrentTranscript().filter {
            isCareEligibleTurn($0)
        }.map {
            CareSignalInputTurn(role: $0.role, text: $0.text, timestamp: $0.timestamp)
        }
        snapshot = analyzer.analyze(turns: turns)
        render()
    }

    private func isCareEligibleTurn(_ turn: ConversationTurn) -> Bool {
        guard PrivacyScopePolicy.canUse(metadata: turn.privacyMetadata, surface: .careDashboard) else {
            return false
        }
        guard turn.role.lowercased() == "user" else { return true }
        let excludedPrefixes = [
            "时空信箱写给",
            "记忆档案馆保存",
            "记忆档案馆上传旧照片"
        ]
        return !excludedPrefixes.contains { turn.text.hasPrefix($0) }
    }

    private func render() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard let snapshot = snapshot else { return }

        stackView.addArrangedSubview(makeHeader(snapshot))
        stackView.addArrangedSubview(makePrivacyNotice())

        let metrics = [
            ("用户发言", "\(snapshot.userTurnCount) 轮"),
            ("字数", "\(snapshot.characterCount)"),
            ("词汇丰富度", String(format: "%.0f%%", snapshot.lexicalDiversity * 100)),
            ("重复表达", String(format: "%.0f%%", snapshot.repetitionRatio * 100)),
            ("情绪信号", "\(snapshot.negativeEmotionMentions)"),
            ("睡眠信号", "\(snapshot.sleepMentions)"),
            ("身体信号", "\(snapshot.bodyDiscomfortMentions)"),
        ]
        stackView.addArrangedSubview(makeMetricGrid(metrics))
        stackView.addArrangedSubview(makeSuggestions(snapshot.suggestions))
    }

    private func makeHeader(_ snapshot: CareSignalSnapshot) -> UIView {
        let container = makeSurface()

        let titleLabel = UILabel()
        titleLabel.text = snapshot.riskLevel.displayTitle
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = snapshot.riskLevel.tintColor

        let summaryLabel = UILabel()
        summaryLabel.text = snapshot.summary
        summaryLabel.font = .systemFont(ofSize: 15)
        summaryLabel.textColor = .warmPrimary
        summaryLabel.numberOfLines = 0

        let timeLabel = UILabel()
        timeLabel.text = "生成时间 \(CareDashboardViewController.timeFormatter.string(from: snapshot.generatedAt))"
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .warmSubtitle

        let stack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, timeLabel])
        stack.axis = .vertical
        stack.spacing = 8
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    private func makePrivacyNotice() -> UIView {
        let label = UILabel()
        label.text = "仅展示脱敏统计信号，不展示原始聊天内容；本页不是医疗诊断，异常信号应通过家人联系和专业支持确认。"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return paddedSurface(label)
    }

    private func makeMetricGrid(_ metrics: [(String, String)]) -> UIView {
        let container = makeSurface()
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10

        for row in stride(from: 0, to: metrics.count, by: 2) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually
            rowStack.addArrangedSubview(makeMetricCard(title: metrics[row].0, value: metrics[row].1))
            if row + 1 < metrics.count {
                rowStack.addArrangedSubview(makeMetricCard(title: metrics[row + 1].0, value: metrics[row + 1].1))
            } else {
                rowStack.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(rowStack)
        }

        container.addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    private func makeMetricCard(title: String, value: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .warmSubtitle

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = .warmPrimary

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.backgroundColor = UIColor.warmBackground.withAlphaComponent(0.55)
        stack.layer.cornerRadius = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return stack
    }

    private func makeSuggestions(_ suggestions: [String]) -> UIView {
        let container = makeSurface()

        let title = UILabel()
        title.text = "关怀建议"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .warmPrimary

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(title)

        for suggestion in suggestions {
            let label = UILabel()
            label.text = "• \(suggestion)"
            label.font = .systemFont(ofSize: 14)
            label.textColor = .warmPrimary
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    private func paddedSurface(_ content: UIView) -> UIView {
        let container = makeSurface()
        container.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        return container
    }

    private func makeSurface() -> UIView {
        let view = UIView()
        view.backgroundColor = .warmSurface
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.warmDivider.cgColor
        return view
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
}

private extension CareSignalRiskLevel {
    var displayTitle: String {
        switch self {
        case .insufficientData: return "数据不足"
        case .stable: return "状态稳定"
        case .watch: return "建议关注"
        case .attention: return "需要尽快确认"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .insufficientData: return .warmSubtitle
        case .stable: return .warmPrimary
        case .watch: return .warmAccent
        case .attention: return UIColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 1.0)
        }
    }
}
