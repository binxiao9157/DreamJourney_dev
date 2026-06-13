import UIKit

final class RoadshowDemoRouteViewController: UIViewController {
    private let status: RoadshowDemoSeed.RuntimeStatus
    private let steps: [RoadshowDemoRoute.Step]
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let progressLabel = UILabel()
    private var checkButtons: [String: UIButton] = [:]

    init(
        status: RoadshowDemoSeed.RuntimeStatus = RoadshowDemoSeed.runtimeStatus(),
        steps: [RoadshowDemoRoute.Step] = RoadshowDemoRoute.steps()
    ) {
        self.status = status
        self.steps = steps
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "路演路线"
        view.backgroundColor = .warmBackground
        setupNavigation()
        setupLayout()
        render()
        updateProgress()
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "复制参数",
            style: .plain,
            target: self,
            action: #selector(copyLaunchRecipe)
        )
    }

    private func setupLayout() {
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 28, right: 18)

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func render() {
        stackView.addArrangedSubview(makeHeaderCard())
        stackView.addArrangedSubview(makeEvidenceCenterCard())
        steps.forEach { step in
            stackView.addArrangedSubview(makeStepCard(step))
        }
        stackView.addArrangedSubview(makeBoundaryCard())
    }

    private func makeHeaderCard() -> UIView {
        let card = makeCard()
        let title = makeLabel(font: .systemFont(ofSize: 20, weight: .bold), color: .warmPrimary, lines: 1)
        title.text = status.title
        let detail = makeLabel(font: .systemFont(ofSize: 14, weight: .medium), color: .warmSubtitle, lines: 0)
        detail.text = status.detail
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        progressLabel.textColor = .warmAccent
        progressLabel.numberOfLines = 0

        let recipeLabel = makeLabel(font: .systemFont(ofSize: 13, weight: .semibold), color: .warmPrimary, lines: 0)
        recipeLabel.text = "推荐启动参数：\(RoadshowDemoRoute.launchRecipe(status: status))"

        let copyChecklistButton = makeHeaderActionButton(
            title: "复制验收",
            imageName: "doc.on.doc.fill",
            action: #selector(copyAcceptanceChecklist)
        )
        copyChecklistButton.accessibilityIdentifier = "copy_acceptance_checklist"
        let resetChecklistButton = makeHeaderActionButton(
            title: "清空验收",
            imageName: "arrow.counterclockwise.circle.fill",
            action: #selector(resetAcceptanceChecklist)
        )
        resetChecklistButton.accessibilityIdentifier = "reset_acceptance_checklist"
        let actionRow = UIStackView(arrangedSubviews: [copyChecklistButton, resetChecklistButton])
        actionRow.axis = .horizontal
        actionRow.spacing = 10
        actionRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [title, detail, progressLabel, recipeLabel, actionRow])
        stack.axis = .vertical
        stack.spacing = 8
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeHeaderActionButton(title: String, imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: imageName)
        configuration.imagePadding = 5
        configuration.baseForegroundColor = .warmAccent
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeEvidenceCenterCard() -> UIView {
        let card = makeCard()
        let title = makeLabel(font: .systemFont(ofSize: 17, weight: .bold), color: .warmPrimary, lines: 1)
        title.text = "证据中心"

        let summary = makeLabel(font: .systemFont(ofSize: 13, weight: .medium), color: .warmSubtitle, lines: 0)
        let closureSummary = RoadshowDemoRoute.evidenceClosureSummary(steps: steps)
        summary.text = [
            closureSummary.headline,
            closureSummary.detail,
            "逐屏 smoke 后，把截图、录屏、分享包、诊断和验收清单放入 evidence 目录，最后生成 evidence_status.md。"
        ].joined(separator: "\n")

        let copyButton = makeHeaderActionButton(
            title: "复制证据清单",
            imageName: "checklist.checked",
            action: #selector(copyEvidenceGuide)
        )
        copyButton.accessibilityIdentifier = "copy_evidence_guide"

        let checkCommandTitle = makeLabel(font: .systemFont(ofSize: 12, weight: .bold), color: .warmPrimary, lines: 1)
        checkCommandTitle.text = "检查命令"
        let checkCommand = makeCommandLabel()
        checkCommand.text = RoadshowDemoRoute.evidenceReportCommand()

        let archiveCommandTitle = makeLabel(font: .systemFont(ofSize: 12, weight: .bold), color: .warmPrimary, lines: 1)
        archiveCommandTitle.text = "归档命令"
        let archiveCommand = makeCommandLabel()
        archiveCommand.text = RoadshowDemoRoute.evidenceArchiveCommand()

        let archiveNote = makeLabel(font: .systemFont(ofSize: 12, weight: .medium), color: .warmSubtitle, lines: 0)
        archiveNote.text = "complete 后生成 zip，包内 archive_inventory.json 可复核每个证据文件的 size/sha256。"

        let statusTitle = makeLabel(font: .systemFont(ofSize: 12, weight: .bold), color: .warmPrimary, lines: 1)
        statusTitle.text = "收口状态"
        let statusRows = RoadshowDemoRoute.evidenceStatusGuide().map(makeEvidenceStatusRow)
        let statusStack = UIStackView(arrangedSubviews: [statusTitle] + statusRows)
        statusStack.axis = .vertical
        statusStack.spacing = 5

        let previewRows = RoadshowDemoRoute.evidenceArtifacts()
            .prefix(5)
            .map(makeEvidencePreviewRow)
        let previewStack = UIStackView(arrangedSubviews: Array(previewRows))
        previewStack.axis = .vertical
        previewStack.spacing = 6

        let stack = UIStackView(arrangedSubviews: [
            title,
            summary,
            copyButton,
            statusStack,
            previewStack,
            checkCommandTitle,
            checkCommand,
            archiveCommandTitle,
            archiveCommand,
            archiveNote
        ])
        stack.axis = .vertical
        stack.spacing = 10
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeEvidencePreviewRow(_ artifact: RoadshowDemoRoute.EvidenceArtifact) -> UIView {
        let title = makeLabel(font: .systemFont(ofSize: 12, weight: .bold), color: .warmPrimary, lines: 1)
        title.text = "\(artifact.requirement.rawValue) · \(artifact.category) · \(artifact.title)"
        let path = makeLabel(font: .monospacedSystemFont(ofSize: 11, weight: .medium), color: .warmSubtitle, lines: 1)
        path.text = artifact.path
        path.numberOfLines = 0
        path.lineBreakMode = .byCharWrapping
        let stack = UIStackView(arrangedSubviews: [title, path])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func makeEvidenceStatusRow(_ row: (status: String, meaning: String)) -> UIView {
        let status = makeLabel(font: .monospacedSystemFont(ofSize: 11, weight: .bold), color: .warmAccent, lines: 1)
        status.text = row.status
        status.setContentCompressionResistancePriority(.required, for: .horizontal)

        let meaning = makeLabel(font: .systemFont(ofSize: 12, weight: .medium), color: .warmSubtitle, lines: 0)
        meaning.text = row.meaning

        let stack = UIStackView(arrangedSubviews: [status, meaning])
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = 8
        return stack
    }

    private func makeCommandLabel() -> UILabel {
        let label = makeLabel(font: .monospacedSystemFont(ofSize: 12, weight: .medium), color: .warmPrimary, lines: 0)
        label.lineBreakMode = .byCharWrapping
        return label
    }

    private func makeStepCard(_ step: RoadshowDemoRoute.Step) -> UIView {
        let card = makeCard()

        let icon = UIImageView(image: UIImage(systemName: step.iconName))
        icon.tintColor = .warmAccent
        icon.contentMode = .scaleAspectFit

        let title = makeLabel(font: .systemFont(ofSize: 17, weight: .bold), color: .warmPrimary, lines: 0)
        title.text = step.title
        let meta = makeLabel(font: .systemFont(ofSize: 12, weight: .semibold), color: .warmAccent, lines: 1)
        meta.text = "\(step.tabTitle) · \(step.durationText)"

        let titleStack = UIStackView(arrangedSubviews: [title, meta])
        titleStack.axis = .vertical
        titleStack.spacing = 3

        let checkButton = UIButton(type: .system)
        checkButton.tintColor = .warmAccent
        checkButton.accessibilityLabel = "标记\(step.title)完成"
        checkButton.addTarget(self, action: #selector(toggleStep(_:)), for: .touchUpInside)
        checkButton.accessibilityIdentifier = step.id
        checkButtons[step.id] = checkButton

        let enterButton = UIButton(type: .system)
        var enterConfiguration = UIButton.Configuration.filled()
        enterConfiguration.title = "进入"
        enterConfiguration.image = UIImage(systemName: "arrow.right.circle.fill")
        enterConfiguration.imagePadding = 4
        enterConfiguration.baseBackgroundColor = .warmAccent
        enterConfiguration.baseForegroundColor = .white
        enterConfiguration.cornerStyle = .capsule
        enterButton.configuration = enterConfiguration
        enterButton.accessibilityLabel = "进入\(step.title)"
        enterButton.accessibilityIdentifier = "enter_\(step.id)"
        enterButton.addTarget(self, action: #selector(enterStep(_:)), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [icon, titleStack, enterButton, checkButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let talking = makeBodyBlock(title: "口播", body: step.talkingPoint)
        let acceptance = makeBodyBlock(title: "验收", body: step.acceptance)
        let fallback = makeBodyBlock(title: "兜底", body: step.fallback)

        let stack = UIStackView(arrangedSubviews: [topRow, talking, acceptance, fallback])
        stack.axis = .vertical
        stack.spacing = 11
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),
            enterButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            enterButton.heightAnchor.constraint(equalToConstant: 32),
            checkButton.widthAnchor.constraint(equalToConstant: 34),
            checkButton.heightAnchor.constraint(equalToConstant: 34),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        update(button: checkButton, completed: isCompleted(step.id))
        return card
    }

    private func makeBoundaryCard() -> UIView {
        let card = makeCard()
        let title = makeLabel(font: .systemFont(ofSize: 17, weight: .bold), color: .warmPrimary, lines: 1)
        title.text = "收口边界"
        let body = makeLabel(font: .systemFont(ofSize: 14, weight: .medium), color: .warmSubtitle, lines: 0)
        body.text = RoadshowDemoRoute.boundaryNotices()
            .map { "• \($0)" }
            .joined(separator: "\n")

        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = 10
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeBodyBlock(title: String, body: String) -> UIView {
        let titleLabel = makeLabel(font: .systemFont(ofSize: 12, weight: .bold), color: .warmPrimary, lines: 1)
        titleLabel.text = title
        let bodyLabel = makeLabel(font: .systemFont(ofSize: 13, weight: .medium), color: .warmSubtitle, lines: 0)
        bodyLabel.text = body

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .warmSurface
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.warmDivider.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8
        return card
    }

    private func makeLabel(font: UIFont, color: UIColor, lines: Int) -> UILabel {
        let label = UILabel()
        label.font = font
        label.textColor = color
        label.numberOfLines = lines
        return label
    }

    @objc private func toggleStep(_ sender: UIButton) {
        guard let stepID = sender.accessibilityIdentifier else { return }
        let completed = !isCompleted(stepID)
        UserDefaults.standard.set(completed, forKey: RoadshowDemoRoute.completionKey(for: stepID))
        update(button: sender, completed: completed)
        updateProgress()
    }

    @objc private func enterStep(_ sender: UIButton) {
        guard let rawIdentifier = sender.accessibilityIdentifier else { return }
        let stepID = rawIdentifier.replacingOccurrences(of: "enter_", with: "")
        if stepID == "family_share" {
            let viewController = KBSyncViewController(autoPresentExportPicker: true)
            viewController.title = "分享包收口"
            navigationController?.pushViewController(viewController, animated: true)
            return
        }
        guard let targetIndex = RoadshowDemoRoute.targetTabIndex(for: stepID) else { return }
        navigationController?.popToRootViewController(animated: false)
        tabBarController?.selectedIndex = targetIndex
    }

    private func update(button: UIButton, completed: Bool) {
        let imageName = completed ? "checkmark.circle.fill" : "circle"
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.accessibilityValue = completed ? "已完成" : "未完成"
    }

    private func isCompleted(_ stepID: String) -> Bool {
        UserDefaults.standard.bool(forKey: RoadshowDemoRoute.completionKey(for: stepID))
    }

    private func updateProgress() {
        let summary = RoadshowDemoRoute.completionSummary(steps: steps)
        progressLabel.text = "\(summary.progressText) · \(summary.hostStatusText)"
    }

    @objc private func copyLaunchRecipe() {
        UIPasteboard.general.string = RoadshowDemoRoute.launchRecipe(status: status)
        showToast("启动参数已复制", type: .success)
    }

    @objc private func copyAcceptanceChecklist() {
        UIPasteboard.general.string = RoadshowDemoRoute.completionChecklistText(steps: steps)
        showToast("验收清单已复制", type: .success)
    }

    @objc private func copyEvidenceGuide() {
        UIPasteboard.general.string = RoadshowDemoRoute.evidenceGuideText(steps: steps)
        showToast("证据清单已复制", type: .success)
    }

    @objc private func resetAcceptanceChecklist() {
        RoadshowDemoRoute.resetCompletions(steps: steps)
        checkButtons.forEach { stepID, button in
            update(button: button, completed: isCompleted(stepID))
        }
        updateProgress()
        showToast("验收状态已清空", type: .info)
    }
}
