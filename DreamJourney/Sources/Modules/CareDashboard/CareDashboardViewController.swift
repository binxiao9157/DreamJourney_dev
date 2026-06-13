import UIKit

final class CareDashboardViewController: UIViewController {

    private let analyzer = CareSignalAnalyzer()
    private let viewerFamilyMemberID: String?
    private let viewerIdentitySource: FamilyAccessIdentityResolver.Source?
    private var snapshot: CareSignalSnapshot?
    private var snapshotSourceText = "本机近况"

    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }()

    init(viewerFamilyMemberID: String? = nil) {
        if let viewerFamilyMemberID {
            self.viewerFamilyMemberID = viewerFamilyMemberID
            self.viewerIdentitySource = nil
        } else {
            let identity = FamilyRepository.shared.currentViewerIdentity()
            self.viewerFamilyMemberID = identity?.familyMemberID
            self.viewerIdentitySource = identity?.source
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        let identity = FamilyRepository.shared.currentViewerIdentity()
        self.viewerFamilyMemberID = identity?.familyMemberID
        self.viewerIdentitySource = identity?.source
        super.init(coder: coder)
    }

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
        let refreshItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
        let shareItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareReportTapped)
        )
        refreshItem.tintColor = .warmAccent
        shareItem.tintColor = .warmAccent
        navigationItem.rightBarButtonItems = [shareItem, refreshItem]
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

    @objc private func shareReportTapped() {
        guard let snapshot else {
            showToast("暂无可分享的关怀周报", type: .info)
            return
        }
        let descriptor = CareDashboardShareReportDescriptor.make(
            snapshot: snapshot,
            viewerName: viewerDisplayName()
        )
        let activityVC = UIActivityViewController(
            activityItems: [descriptor.plainText],
            applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(activityVC, animated: true)
    }

    private func reloadSnapshot() {
        let turns = CareDashboardInputPolicy.eligibleInputTurns(
            from: ConversationMemoryManager.shared.getCurrentTranscript(),
            viewerFamilyMemberID: viewerFamilyMemberID
        )
        let localSnapshot = analyzer.analyze(turns: turns)
        snapshot = localSnapshot
        snapshotSourceText = "本机近况"
        render()

        if localSnapshot.userTurnCount > 0 {
            syncSnapshotToBackend(localSnapshot)
        } else {
            fetchSnapshotHistoryFromBackend()
        }
    }

    private func syncSnapshotToBackend(_ snapshot: CareSignalSnapshot) {
        guard DreamJourneyBackendClient.shared.isConfigured,
              let userId = UserManager.shared.currentUser?.id else {
            return
        }
        DreamJourneyBackendClient.shared.syncCareSnapshot(
            userId: userId,
            viewerFamilyMemberID: viewerFamilyMemberID,
            snapshot: snapshot
        ) { result in
            if case .failure(let error) = result {
                print("[CareDashboard] 后端快照同步失败: \(error.localizedDescription)")
            }
        }
    }

    private func fetchLatestSnapshotFromBackend() {
        guard DreamJourneyBackendClient.shared.isConfigured,
              let userId = UserManager.shared.currentUser?.id else {
            return
        }
        DreamJourneyBackendClient.shared.fetchLatestCareSnapshot(
            userId: userId,
            viewerFamilyMemberID: viewerFamilyMemberID
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.applyRemoteSnapshotIfUseful(response.item.snapshot, sourceText: "服务器同步快照")
                case .failure(let error):
                    print("[CareDashboard] 后端快照拉取失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func fetchSnapshotHistoryFromBackend() {
        guard DreamJourneyBackendClient.shared.isConfigured,
              let userId = UserManager.shared.currentUser?.id else {
            return
        }
        DreamJourneyBackendClient.shared.fetchCareSnapshotHistory(
            userId: userId,
            viewerFamilyMemberID: viewerFamilyMemberID,
            limit: 7
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let latest = response.items.first?.snapshot {
                        self?.applyRemoteSnapshotIfUseful(
                            latest,
                            sourceText: "服务器同步历史 \(response.items.count) 条"
                        )
                    } else {
                        self?.fetchLatestSnapshotFromBackend()
                    }
                case .failure(let error):
                    print("[CareDashboard] 后端历史快照拉取失败: \(error.localizedDescription)")
                    self?.fetchLatestSnapshotFromBackend()
                }
            }
        }
    }

    private func applyRemoteSnapshotIfUseful(_ remoteSnapshot: CareSignalSnapshot, sourceText: String) {
        guard (snapshot?.userTurnCount ?? 0) == 0, remoteSnapshot.userTurnCount > 0 else {
            return
        }
        snapshot = remoteSnapshot
        snapshotSourceText = sourceText
        render()
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
            ("观测天数", "\(snapshot.windowDayCount) 天"),
            ("字数", "\(snapshot.characterCount)"),
            ("词汇丰富度", String(format: "%.0f%%", snapshot.lexicalDiversity * 100)),
            ("重复表达", String(format: "%.0f%%", snapshot.repetitionRatio * 100)),
            ("情绪信号", "\(snapshot.negativeEmotionMentions)"),
            ("睡眠信号", "\(snapshot.sleepMentions)"),
            ("身体信号", "\(snapshot.bodyDiscomfortMentions)"),
        ]
        stackView.addArrangedSubview(makeMetricGrid(metrics))
        stackView.addArrangedSubview(makeTrendCard(snapshot))
        stackView.addArrangedSubview(makeWeeklyReport(snapshot))
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

        let coverageLabel = UILabel()
        let coverageSummary = snapshot.dataCoverageSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let viewerPrefix = viewerDescriptionText()
        coverageLabel.text = "\(viewerPrefix)数据来源 \(snapshotSourceText) · 数据覆盖 \(coverageSummary.isEmpty ? "暂无覆盖说明" : coverageSummary)"
        coverageLabel.font = .systemFont(ofSize: 12)
        coverageLabel.textColor = .warmSubtitle
        coverageLabel.numberOfLines = 0

        var headerItems: [UIView] = [titleLabel, summaryLabel, timeLabel, coverageLabel]
        if let windowStart = snapshot.windowStart, let windowEnd = snapshot.windowEnd {
            let windowLabel = UILabel()
            let startText = CareDashboardViewController.windowDateFormatter.string(from: windowStart)
            let endText = CareDashboardViewController.windowDateFormatter.string(from: windowEnd)
            windowLabel.text = "观测窗口 \(startText)-\(endText)"
            windowLabel.font = .systemFont(ofSize: 12)
            windowLabel.textColor = .warmSubtitle
            headerItems.append(windowLabel)
        }

        let stack = UIStackView(arrangedSubviews: headerItems)
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

    private func viewerDescriptionText() -> String {
        guard let viewerFamilyMemberID,
              let member = FamilyRepository.shared.get(by: viewerFamilyMemberID) else {
            return ""
        }

        if viewerIdentitySource == nil {
            return "查看身份 \(member.name) · "
        }
        return "当前身份 \(member.name) · "
    }

    private func viewerDisplayName() -> String? {
        guard let viewerFamilyMemberID,
              let member = FamilyRepository.shared.get(by: viewerFamilyMemberID) else {
            return nil
        }
        return member.name
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

    private func makeTrendCard(_ snapshot: CareSignalSnapshot) -> UIView {
        let container = makeSurface()

        let titleLabel = UILabel()
        titleLabel.text = "7天趋势"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .warmPrimary

        let summaryLabel = UILabel()
        summaryLabel.text = snapshot.trendSummary
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .warmSubtitle
        summaryLabel.numberOfLines = 0

        let trendStack = UIStackView()
        trendStack.axis = .horizontal
        trendStack.spacing = 8
        trendStack.alignment = .bottom
        trendStack.distribution = .fillEqually

        let points = snapshot.dailyTrend.isEmpty ? [] : snapshot.dailyTrend
        if points.isEmpty {
            trendStack.addArrangedSubview(makeEmptyTrendLabel())
        } else {
            points.forEach { point in
                trendStack.addArrangedSubview(makeTrendColumn(point))
            }
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, trendStack])
        stack.axis = .vertical
        stack.spacing = 12
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

    private func makeEmptyTrendLabel() -> UILabel {
        let label = UILabel()
        label.text = "暂无趋势数据"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .warmSubtitle
        label.textAlignment = .center
        return label
    }

    private func makeTrendColumn(_ point: CareSignalDailyTrendPoint) -> UIView {
        let dayLabel = UILabel()
        dayLabel.text = CareDashboardViewController.dayFormatter.string(from: point.date)
        dayLabel.font = .systemFont(ofSize: 10, weight: .medium)
        dayLabel.textColor = .warmSubtitle
        dayLabel.textAlignment = .center

        let score = point.signalScore + (point.repetitionRatio >= 0.4 ? 1 : 0)
        let valueLabel = UILabel()
        valueLabel.text = score == 0 ? "日常" : "\(score)"
        valueLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        valueLabel.textColor = point.hasSignals ? .warmAccent : .warmSubtitle
        valueLabel.textAlignment = .center

        let bar = UIView()
        bar.backgroundColor = point.hasSignals ? UIColor.warmAccent.withAlphaComponent(0.85) : UIColor.warmDivider
        bar.layer.cornerRadius = 4
        bar.translatesAutoresizingMaskIntoConstraints = false
        let barHeight = CGFloat(min(48, max(12, 12 + score * 10)))
        bar.heightAnchor.constraint(equalToConstant: barHeight).isActive = true
        bar.widthAnchor.constraint(greaterThanOrEqualToConstant: 12).isActive = true

        let column = UIStackView(arrangedSubviews: [valueLabel, bar, dayLabel])
        column.axis = .vertical
        column.spacing = 5
        column.alignment = .center
        return column
    }

    private func makeWeeklyReport(_ snapshot: CareSignalSnapshot) -> UIView {
        let container = makeSurface()

        let title = UILabel()
        title.text = "脱敏观察报告"
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .warmPrimary

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(title)

        if snapshot.weeklyHighlights.isEmpty {
            stack.addArrangedSubview(makeBulletLabel("暂无可展示的脱敏观察摘要。"))
        } else {
            snapshot.weeklyHighlights.forEach { highlight in
                stack.addArrangedSubview(makeBulletLabel(highlight))
            }
        }

        if !snapshot.riskSignalDescriptions.isEmpty {
            let riskTitle = UILabel()
            riskTitle.text = "需关注信号"
            riskTitle.font = .systemFont(ofSize: 15, weight: .semibold)
            riskTitle.textColor = .warmPrimary
            stack.addArrangedSubview(riskTitle)

            snapshot.riskSignalDescriptions.forEach { description in
                stack.addArrangedSubview(makeBulletLabel(description))
            }
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
            stack.addArrangedSubview(makeBulletLabel(suggestion))
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

    private func makeBulletLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = "• \(text)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .warmPrimary
        label.numberOfLines = 0
        return label
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

    private static let windowDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
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
