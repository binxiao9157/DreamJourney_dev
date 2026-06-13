import UIKit

// MARK: - Digital Human Diagnostics

final class DigitalHumanDiagnosticsViewController: UIViewController {
    private let report: DigitalHumanReadinessReport

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(report: DigitalHumanReadinessReport = .make()) {
        self.report = report
        super.init(nibName: nil, bundle: nil)
        title = report.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "复制 JSON",
            style: .plain,
            target: self,
            action: #selector(copyDiagnosticsJSON)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "复制",
            style: .plain,
            target: self,
            action: #selector(copyDiagnostics)
        )
        setupLayout()
        renderReport()
        report.persistEvidenceFiles()
    }

    private func setupLayout() {
        scrollView.alwaysBounceVertical = true
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.layoutMargins = UIEdgeInsets(top: 18, left: 20, bottom: 28, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true

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
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func renderReport() {
        let hero = makeHeroCard()
        contentStack.addArrangedSubview(hero)
        report.items.forEach { item in
            contentStack.addArrangedSubview(makeStatusRow(item))
        }
        contentStack.addArrangedSubview(makePlaybackEvidenceCard())
        contentStack.addArrangedSubview(makeBoundaryCard())
        contentStack.addArrangedSubview(makeLocalTestDataCleanupCard())
    }

    private func makeHeroCard() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = report.primaryStatus.title
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = statusColor(report.primaryStatus)

        let subtitleLabel = UILabel()
        subtitleLabel.text = report.subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.textColor = .warmSubtitle
        subtitleLabel.numberOfLines = 0

        let noteLabel = UILabel()
        noteLabel.text = "用于真机排障和真实联调检查；不会显示 API Key、Token 或 Secret。"
        noteLabel.font = .systemFont(ofSize: 13, weight: .regular)
        noteLabel.textColor = UIColor(red: 0.49, green: 0.42, blue: 0.35, alpha: 1)
        noteLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 6
        return wrapCard(stack)
    }

    private func makeStatusRow(_ item: DigitalHumanReadinessReport.Item) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: iconName(item.status)))
        iconView.tintColor = statusColor(item.status)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "\(item.title) · \(item.status.title)"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.24, green: 0.18, blue: 0.13, alpha: 1)
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = item.detail
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .warmSubtitle
        detailLabel.numberOfLines = 0

        let recommendationLabel = UILabel()
        recommendationLabel.text = "建议：\(item.recommendation)"
        recommendationLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        recommendationLabel.textColor = UIColor(red: 0.45, green: 0.34, blue: 0.23, alpha: 1)
        recommendationLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, recommendationLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [iconView, textStack])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 10
        return wrapCard(row)
    }

    private func makePlaybackEvidenceCard() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "音频链路验收"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.24, green: 0.18, blue: 0.13, alpha: 1)

        let introLabel = UILabel()
        introLabel.text = "真机验证时保存控制台日志，重点看以下播放收口标记。"
        introLabel.font = .systemFont(ofSize: 12, weight: .medium)
        introLabel.textColor = .warmSubtitle
        introLabel.numberOfLines = 0

        let rows = DigitalHumanSpeechPlaybackPolicy.roadshowEvidenceChecks().map(makePlaybackEvidenceRow)
        let stack = UIStackView(arrangedSubviews: [titleLabel, introLabel] + rows)
        stack.axis = .vertical
        stack.spacing = 9
        return wrapCard(stack)
    }

    private func makePlaybackEvidenceRow(_ check: DigitalHumanSpeechPlaybackPolicy.EvidenceCheck) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "\(check.title) · \(check.source)"
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .warmAccent
        titleLabel.numberOfLines = 0

        let logLabel = UILabel()
        logLabel.text = check.expectedLog
        logLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        logLabel.textColor = UIColor(red: 0.31, green: 0.24, blue: 0.18, alpha: 1)
        logLabel.numberOfLines = 0

        let acceptanceLabel = UILabel()
        acceptanceLabel.text = check.acceptance
        acceptanceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        acceptanceLabel.textColor = .warmSubtitle
        acceptanceLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, logLabel, acceptanceLabel])
        stack.axis = .vertical
        stack.spacing = 3
        return stack
    }

    private func makeBoundaryCard() -> UIView {
        let label = UILabel()
        label.text = "真实验证口径：真实语音未就绪时直接暴露配置问题；数字人口型不可用时会退回系统语音；任何状态下都不冒充亲人、不做医疗诊断。"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(red: 0.39, green: 0.32, blue: 0.26, alpha: 1)
        label.numberOfLines = 0
        return wrapCard(label, backgroundColor: UIColor(red: 1.0, green: 0.96, blue: 0.89, alpha: 1))
    }

    private func makeLocalTestDataCleanupCard() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "真机测试数据"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.24, green: 0.18, blue: 0.13, alpha: 1)

        let detailLabel = UILabel()
        detailLabel.text = "清理本机演示残留、档案素材、时空信箱、知识库、对话记忆和足迹已读状态；不会清除 API Key、后端地址或登录信息。"
        detailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = .warmSubtitle
        detailLabel.numberOfLines = 0

        var configuration = UIButton.Configuration.filled()
        configuration.title = "清理本机测试数据"
        configuration.image = UIImage(systemName: "trash")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = UIColor(red: 0.80, green: 0.24, blue: 0.18, alpha: 1)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(confirmLocalTestDataCleanup), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, button])
        stack.axis = .vertical
        stack.spacing = 10
        return wrapCard(stack, backgroundColor: UIColor(red: 1.0, green: 0.95, blue: 0.93, alpha: 1))
    }

    private func wrapCard(_ content: UIView, backgroundColor: UIColor = .white) -> UIView {
        let card = UIView()
        card.backgroundColor = backgroundColor
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.89, green: 0.84, blue: 0.78, alpha: 0.8).cgColor
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func statusColor(_ status: DigitalHumanReadinessReport.Status) -> UIColor {
        switch status {
        case .ready:
            return UIColor(red: 0.14, green: 0.55, blue: 0.36, alpha: 1)
        case .warning:
            return .warmAccent
        case .missing:
            return UIColor(red: 0.80, green: 0.24, blue: 0.18, alpha: 1)
        }
    }

    private func iconName(_ status: DigitalHumanReadinessReport.Status) -> String {
        switch status {
        case .ready:
            return "checkmark.seal.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .missing:
            return "xmark.octagon.fill"
        }
    }

    @objc private func copyDiagnostics() {
        UIPasteboard.general.string = report.copyableText
        showToast("已复制脱敏诊断信息", type: .success)
    }

    @objc private func copyDiagnosticsJSON() {
        UIPasteboard.general.string = report.evidenceJSONText
        showToast("已复制诊断 JSON", type: .success)
    }

    @objc private func confirmLocalTestDataCleanup() {
        let alert = UIAlertController(
            title: "清理本机测试数据？",
            message: "将删除本机演示残留、知识库、档案素材、时空信箱、对话记忆、回忆录和足迹已读状态。API Key、后端地址和登录信息会保留。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清理", style: .destructive) { [weak self] _ in
            let result = LocalTestDataCleaner.cleanForRealDeviceTesting()
            self?.showToast(result.summary, type: .success)
        })
        present(alert, animated: true)
    }
}
