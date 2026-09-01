import UIKit

final class NarrativeReadinessViewController: NarrativeScreenViewController {
    private let readiness: NarrativeReadiness
    private weak var coordinator: NarrativeProjectCoordinator?
    private var selectedMemoryVersionIds = Set<String>()
    private let narratorControl = UISegmentedControl(items: ["第三人称传记", "亲历者叙述"])
    private let readerControl = UISegmentedControl(items: ["自己", "家人", "后代"])
    private let privacySwitch = UISwitch()

    init(readiness: NarrativeReadiness, coordinator: NarrativeProjectCoordinator) {
        self.readiness = readiness
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        selectedMemoryVersionIds = Set(readiness.storyClusters.flatMap(\.memoryVersionIds))
        title = readiness.project.title
        addHeading("写作素材", subtitle: "本次写作只使用已确认的正式记忆，并固定为不可变快照。")
        let count = UILabel()
        count.text = "已找到 \(readiness.availableMemoryCount) 条可用正式记忆"
        count.font = .systemFont(ofSize: 20, weight: .medium)
        stackView.addArrangedSubview(count)
        readiness.storyClusters.forEach { cluster in
            let button = makeButton(
                "✓  \(cluster.title)  ·  \(cluster.itemCount) 条",
                action: #selector(clusterTapped(_:)),
                emphasized: false
            )
            button.accessibilityIdentifier = cluster.clusterKey
            stackView.addArrangedSubview(button)
        }
        readiness.gaps.forEach { gap in
            let label = UILabel()
            label.text = gap.echoPrompt ?? gap.code
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            stackView.addArrangedSubview(label)
        }
        if readiness.project.projectType == .taStory {
            let narratorHeading = UILabel()
            narratorHeading.text = "谁来讲述"
            narratorHeading.font = .preferredFont(forTextStyle: .headline)
            stackView.addArrangedSubview(narratorHeading)
            narratorControl.selectedSegmentIndex = readiness.project.narratorType == .controllerWitness ? 1 : 0
            narratorControl.accessibilityLabel = "叙述关系"
            stackView.addArrangedSubview(narratorControl)
            let narratorNote = UILabel()
            narratorNote.text = "亲历者叙述会明确保留“在我记忆中”的讲述位置，不会把你的感受写成 TA 的内心。"
            narratorNote.numberOfLines = 0
            narratorNote.font = .preferredFont(forTextStyle: .footnote)
            narratorNote.textColor = .secondaryLabel
            stackView.addArrangedSubview(narratorNote)
        }
        let readerHeading = UILabel()
        readerHeading.text = "主要写给谁看"
        readerHeading.font = .preferredFont(forTextStyle: .headline)
        stackView.addArrangedSubview(readerHeading)
        readerControl.selectedSegmentIndex = 0
        readerControl.accessibilityLabel = "主要读者"
        stackView.addArrangedSubview(readerControl)
        let privacyRow = UIStackView()
        privacyRow.axis = .horizontal
        privacyRow.alignment = .center
        privacyRow.spacing = 12
        let privacyLabel = UILabel()
        privacyLabel.text = "我确认书稿默认仅自己可见"
        privacyLabel.numberOfLines = 0
        privacyLabel.font = .preferredFont(forTextStyle: .body)
        privacyRow.addArrangedSubview(privacyLabel)
        privacyRow.addArrangedSubview(privacySwitch)
        privacySwitch.accessibilityLabel = "确认书稿默认仅自己可见"
        stackView.addArrangedSubview(privacyRow)
        if readiness.generationAvailable == false {
            let unavailable = UILabel()
            unavailable.text = "写作生成服务当前未开放。你仍可查看已有书稿，服务恢复后再开始新的生成。"
            unavailable.numberOfLines = 0
            unavailable.textColor = .systemOrange
            stackView.addArrangedSubview(unavailable)
        } else if readiness.ready {
            stackView.addArrangedSubview(makeButton("确认素材并开始主笔试镜", action: #selector(confirmTapped)))
        } else {
            stackView.addArrangedSubview(makeButton("返回回响补充经历", action: #selector(backTapped), emphasized: false))
        }
    }

    @objc private func confirmTapped() {
        guard privacySwitch.isOn else {
            let alert = UIAlertController(
                title: "请确认隐私范围",
                message: "首版书稿保持私人状态，不会自动发布或分享。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }
        let narrator: NarrativeNarratorType
        if readiness.project.projectType == .selfAutobiography {
            narrator = .selfFirstPerson
        } else {
            narrator = narratorControl.selectedSegmentIndex == 1 ? .controllerWitness : .thirdPersonBiography
        }
        let readers = ["self", "family", "descendants"]
        coordinator?.send(.confirmSetup, payload: [
            "narratorType": .string(narrator.rawValue),
            "primaryReader": .string(readers[readerControl.selectedSegmentIndex]),
            "privacyScope": .string("private"),
            "privacyConfirmed": .boolean(true),
            "confirmationRulesVersion": .string("narrative-setup-v1"),
            "selectedMemoryVersionIds": .array(selectedMemoryVersionIds.sorted().map(NarrativeJSONValue.string)),
        ])
    }
    @objc private func clusterTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier,
              let cluster = readiness.storyClusters.first(where: { $0.clusterKey == key }) else { return }
        let values = Set(cluster.memoryVersionIds)
        if values.isSubset(of: selectedMemoryVersionIds) {
            selectedMemoryVersionIds.subtract(values)
            sender.setTitle("○  \(cluster.title)  ·  \(cluster.itemCount) 条", for: .normal)
        } else {
            selectedMemoryVersionIds.formUnion(values)
            sender.setTitle("✓  \(cluster.title)  ·  \(cluster.itemCount) 条", for: .normal)
        }
    }
    @objc private func backTapped() { navigationController?.popToRootViewController(animated: true) }
}

final class NarrativeJobProgressViewController: NarrativeScreenViewController {
    private var job: NarrativeJob
    private weak var coordinator: NarrativeProjectCoordinator?
    private let progressLabel = UILabel()
    private let partialStatusLabel = UILabel()
    private let partialStackView = UIStackView()
    private var partialArtifacts: [NarrativeArtifact] = []
    private var timer: Timer?
    private var hasPresentedFailure = false
    private var hasPresentedCompletion = false

    init(job: NarrativeJob, coordinator: NarrativeProjectCoordinator) {
        self.job = job
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "写作进行中"
        addHeading("正在完成写作", subtitle: "页面可暂时离开，任务状态保存在服务端。")
        progressLabel.font = .systemFont(ofSize: 18, weight: .medium)
        progressLabel.numberOfLines = 0
        stackView.addArrangedSubview(progressLabel)
        partialStatusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        partialStatusLabel.numberOfLines = 0
        partialStatusLabel.isHidden = true
        stackView.addArrangedSubview(partialStatusLabel)
        partialStackView.axis = .vertical
        partialStackView.spacing = 12
        partialStackView.isHidden = true
        stackView.addArrangedSubview(partialStackView)
        stackView.addArrangedSubview(makeButton("取消本次写作", action: #selector(cancelTapped), emphasized: false))
        updateLabel()
        refreshPartialAuditions()
        schedulePoll()
    }

    private func schedulePoll() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        coordinator?.poll(job: job) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let job):
                self.job = job
                self.refreshPartialAuditions { [weak self] in
                    guard let self else { return }
                    self.updateLabel()
                    if job.isTerminal {
                        self.timer?.invalidate()
                        if job.state == .failed {
                            self.presentFailureIfNeeded()
                        } else if job.state == .readyForReview {
                            if job.jobType == "auditions" {
                                self.presentCompletionIfNeeded()
                            } else {
                                self.coordinator?.refresh()
                            }
                        } else {
                            self.coordinator?.refresh()
                        }
                    } else {
                        self.schedulePoll()
                    }
                }
            case .failure(let error):
                self.progressLabel.text = error.localizedDescription
                self.schedulePoll()
            }
        }
    }

    private func updateLabel() {
        let names: [String: String] = [
            "queued": "等待开始", "snapshotting": "固定记忆快照", "retrieving": "读取正式记忆",
            "planning": "规划结构", "drafting": "写作初稿", "validatingFacts": "核对事实",
            "editingStyle": "编辑文风", "finalValidation": "完成终检", "readyForReview": "可以审核",
        ]
        if job.progressStage.hasPrefix("auditionsReady:") {
            progressLabel.text = "已有试镜稿完成，正在继续写作"
        } else {
            progressLabel.text = names[job.progressStage] ?? job.progressStage
        }
        if job.state == .failed {
            progressLabel.text = partialArtifacts.isEmpty
                ? "本轮写作未完成，暂未生成可阅读稿件。"
                : "本轮没有全部完成，已生成的试镜稿仍可阅读。"
        }
    }

    private func refreshPartialAuditions(completion: (() -> Void)? = nil) {
        coordinator?.loadArtifacts(type: .writingAudition) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let artifacts) = result {
                    let order = ["documentary", "warmReflection", "thoughtfulMemoir"]
                    self.partialArtifacts = artifacts
                        .filter {
                            $0.state == .readyForReview
                                && $0.memorySnapshotId == self.job.memorySnapshotId
                                && $0.generationJobId == self.job.jobId
                        }
                        .sorted {
                            (order.firstIndex(of: $0.artifactKey) ?? order.count)
                                < (order.firstIndex(of: $1.artifactKey) ?? order.count)
                        }
                    self.renderPartialArtifacts()
                }
                completion?()
            }
        }
    }

    private func renderPartialArtifacts() {
        partialStackView.arrangedSubviews.forEach {
            partialStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let count = partialArtifacts.count
        partialStatusLabel.isHidden = count == 0
        partialStackView.isHidden = count == 0
        partialStatusLabel.text = count == 3
            ? "三篇试镜稿已全部完成"
            : "已完成 \(count)/3，可先阅读；其余稿件继续生成"
        for artifact in partialArtifacts {
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.textColor = .label
            label.backgroundColor = .secondarySystemBackground
            label.layer.cornerRadius = 6
            label.layer.masksToBounds = true
            let title: String
            switch artifact.artifactKey {
            case "documentary": title = "纪实主笔"
            case "warmReflection": title = "温情主笔"
            case "thoughtfulMemoir": title = "思辨主笔"
            default: title = "主笔试镜"
            }
            label.text = "  \(title)\n\n  \(artifact.contentText ?? "")  "
            partialStackView.addArrangedSubview(label)
        }
    }

    private func presentFailureIfNeeded() {
        guard !hasPresentedFailure else { return }
        hasPresentedFailure = true
        let message: String
        if !partialArtifacts.isEmpty {
            message = "已有 \(partialArtifacts.count) 篇试镜稿完成并保留，剩余稿件暂未通过校验。你可以先阅读已完成内容，再重新生成。"
        } else if job.errorCode == "each audition must match its key and contain 200-300 characters"
            || job.errorCode?.hasPrefix("audition_contract_invalid:") == true {
            message = "主笔试镜未通过格式校验，本轮内容没有写入书稿。请返回写作素材后重新生成。"
        } else {
            message = "本轮写作没有生成可审核书稿。请稍后返回写作素材重试。"
        }
        let alert = UIAlertController(title: "写作未完成", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "返回写作素材", style: .default) { [weak self] _ in
            self?.coordinator?.refresh()
        })
        present(alert, animated: true)
    }

    private func presentCompletionIfNeeded() {
        guard !hasPresentedCompletion else { return }
        hasPresentedCompletion = true
        let alert = UIAlertController(
            title: "写作全部完成",
            message: "三篇主笔试镜稿已经完成，现在可以完整阅读并选择喜欢的主笔。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "查看全部试镜稿", style: .default) { [weak self] _ in
            self?.coordinator?.refresh()
        })
        present(alert, animated: true)
    }

    @objc private func cancelTapped() {
        coordinator?.cancel(job: job) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let job):
                self.job = job
                self.timer?.invalidate()
                self.updateLabel()
                self.coordinator?.refresh()
            case .failure(let error): self.progressLabel.text = error.localizedDescription
            }
        }
    }
}

final class NarrativeMaterialSelectionViewController: NarrativeScreenViewController {
    private let readiness: NarrativeReadiness
    private weak var coordinator: NarrativeProjectCoordinator?
    private var selectedMemoryVersionIds = Set<String>()

    init(readiness: NarrativeReadiness, coordinator: NarrativeProjectCoordinator) {
        self.readiness = readiness
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "更换写作素材"
        addHeading("重新选择故事簇", subtitle: "会固定一份新的正式记忆快照，再让三位主笔重新试镜。")
        readiness.storyClusters.forEach { cluster in
            let button = makeButton(
                "○  \(cluster.title)  ·  \(cluster.itemCount) 条",
                action: #selector(clusterTapped(_:)),
                emphasized: false
            )
            button.accessibilityIdentifier = cluster.clusterKey
            stackView.addArrangedSubview(button)
        }
        stackView.addArrangedSubview(makeButton("使用所选素材重新试镜", action: #selector(confirmTapped)))
    }

    @objc private func clusterTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier,
              let cluster = readiness.storyClusters.first(where: { $0.clusterKey == key }) else { return }
        let values = Set(cluster.memoryVersionIds)
        if values.isSubset(of: selectedMemoryVersionIds) {
            selectedMemoryVersionIds.subtract(values)
            sender.setTitle("○  \(cluster.title)  ·  \(cluster.itemCount) 条", for: .normal)
        } else {
            selectedMemoryVersionIds.formUnion(values)
            sender.setTitle("✓  \(cluster.title)  ·  \(cluster.itemCount) 条", for: .normal)
        }
    }

    @objc private func confirmTapped() {
        guard !selectedMemoryVersionIds.isEmpty else {
            let alert = UIAlertController(title: "请选择素材", message: "至少选择一个故事簇。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }
        coordinator?.send(.generateAuditions, payload: [
            "selectedMemoryVersionIds": .array(selectedMemoryVersionIds.sorted().map(NarrativeJSONValue.string)),
        ])
    }
}

final class NarrativeAuditionsViewController: NarrativeScreenViewController {
    private let project: NarrativeProject
    private weak var coordinator: NarrativeProjectCoordinator?
    private var selected: NarrativeArtifact?

    init(project: NarrativeProject, coordinator: NarrativeProjectCoordinator) {
        self.project = project
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "主笔试镜"
        addHeading("选择你的主笔", subtitle: "三位主笔使用同一份正式记忆快照，各写一段不同气质的试镜稿。")
        let auditions = project.artifacts?.filter { $0.artifactType == .writingAudition && $0.state == .readyForReview } ?? []
        auditions.forEach { artifact in
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.font = .systemFont(ofSize: 17)
            button.setTitle("\(artifact.displayTitle)\n\n\(artifact.contentText ?? "")", for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 6
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            button.configuration = configuration
            button.accessibilityIdentifier = artifact.artifactVersionId
            button.addTarget(self, action: #selector(auditionTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        stackView.addArrangedSubview(makeButton("三段里有我喜欢的部分", action: #selector(partlyLikedTapped), emphasized: false))
        stackView.addArrangedSubview(makeButton("三段都不合适", action: #selector(noneLikedTapped), emphasized: false))
        stackView.addArrangedSubview(makeButton("更换这次写作素材", action: #selector(changeMaterialTapped), emphasized: false))
        stackView.addArrangedSubview(makeButton("请三位主笔重新试镜", action: #selector(regenerateTapped), emphasized: false))
    }

    @objc private func auditionTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        selected = project.artifacts?.first { $0.artifactVersionId == id }
        let alert = UIAlertController(title: "选择这位主笔", message: "下一步会独立写一篇黄金样章供你确认。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
            self?.coordinator?.send(.selectAudition, payload: ["artifactVersionId": .string(id)])
        })
        present(alert, animated: true)
    }
    @objc private func partlyLikedTapped() {
        presentFeedbackPrompt(
            title: "哪些部分打动了你？",
            message: "可以写下喜欢的语气、节奏或表达，下一轮会作为文字反馈使用。",
            command: .generateAuditions
        )
    }
    @objc private func noneLikedTapped() {
        presentFeedbackPrompt(
            title: "告诉主笔哪里不对",
            message: "只反馈文字气质，不会改变正式记忆里的事实。",
            command: .generateAuditions
        )
    }
    @objc private func changeMaterialTapped() { coordinator?.chooseReplacementMaterial() }
    @objc private func regenerateTapped() { coordinator?.send(.generateAuditions) }

    private func presentFeedbackPrompt(
        title: String,
        message: String,
        command: NarrativeCommandType
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "写下你的感受" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新试镜", style: .default) { [weak self, weak alert] _ in
            let feedback = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !feedback.isEmpty else { return }
            self?.coordinator?.send(command, payload: ["styleFeedback": .string(feedback)])
        })
        present(alert, animated: true)
    }
}

final class NarrativeArtifactReviewViewController: NarrativeScreenViewController, UITextViewDelegate {
    enum Mode { case goldenSample, outline }
    private let project: NarrativeProject
    private let mode: Mode
    private weak var coordinator: NarrativeProjectCoordinator?
    private let feedbackView = UITextView()
    private let feedbackKind = UISegmentedControl(items: ["文字表达", "事实不对"])

    init(project: NarrativeProject, mode: Mode, coordinator: NarrativeProjectCoordinator) {
        self.project = project
        self.mode = mode
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let type: NarrativeArtifactType = mode == .goldenSample ? .goldenSample : .outline
        let artifact = project.artifacts?.filter { $0.artifactType == type && $0.state != .superseded && $0.state != .stale }.max(by: { $0.versionNumber < $1.versionNumber })
        title = mode == .goldenSample ? "黄金样章" : "全书大纲"
        addHeading(title ?? "写作审核", subtitle: mode == .goldenSample ? "先确认事实，再确认这是不是你希望全书保持的文风。" : "章节结构确认后才进入逐章写作。")
        let constitution = project.artifacts?
            .filter { $0.artifactType == .writingConstitution && $0.state != .superseded && $0.state != .stale }
            .max(by: { $0.versionNumber < $1.versionNumber })
        if mode == .outline, let constitution {
            let heading = UILabel()
            heading.text = "写作约定"
            heading.font = .preferredFont(forTextStyle: .headline)
            stackView.addArrangedSubview(heading)
            let rules = UILabel()
            if case .array(let values)? = constitution.payload["rules"] {
                rules.text = values.compactMap {
                    guard case .string(let value) = $0 else { return nil }
                    return "• \(value)"
                }.joined(separator: "\n")
            }
            rules.numberOfLines = 0
            rules.font = .preferredFont(forTextStyle: .body)
            stackView.addArrangedSubview(rules)
            let edit = makeButton("调整写作约定", action: #selector(editTapped(_:)), emphasized: false)
            edit.accessibilityIdentifier = constitution.artifactVersionId
            stackView.addArrangedSubview(edit)
        }
        if let artifact {
            let body = UILabel()
            body.text = artifact.contentText ?? renderedPayload(artifact.payload)
            body.font = .systemFont(ofSize: 18)
            body.numberOfLines = 0
            stackView.addArrangedSubview(body)
            feedbackView.font = .systemFont(ofSize: 16)
            feedbackView.backgroundColor = .secondarySystemBackground
            feedbackView.layer.cornerRadius = 6
            feedbackView.heightAnchor.constraint(equalToConstant: 120).isActive = true
            feedbackKind.selectedSegmentIndex = 0
            feedbackKind.accessibilityLabel = "反馈类型"
            stackView.addArrangedSubview(feedbackKind)
            stackView.addArrangedSubview(feedbackView)
            let title = mode == .goldenSample ? "确认文风并生成大纲" : "确认大纲并开始逐章写作"
            let button = makeButton(title, action: #selector(confirmTapped))
            button.accessibilityIdentifier = artifact.artifactVersionId
            stackView.addArrangedSubview(button)
            let revise = makeButton("提交修改意见", action: #selector(reviseTapped), emphasized: false)
            revise.accessibilityIdentifier = artifact.artifactVersionId
            stackView.addArrangedSubview(revise)
            if mode == .outline {
                let edit = makeButton("直接编辑当前大纲", action: #selector(editTapped(_:)), emphasized: false)
                edit.accessibilityIdentifier = artifact.artifactVersionId
                stackView.addArrangedSubview(edit)
                let history = makeButton("查看大纲历史版本", action: #selector(historyTapped(_:)), emphasized: false)
                history.accessibilityIdentifier = artifact.artifactVersionId
                stackView.addArrangedSubview(history)
            }
        } else if mode == .outline && project.state == .toneConfirmed {
            stackView.addArrangedSubview(makeButton("生成全书大纲", action: #selector(generateOutlineTapped)))
        } else {
            let empty = UILabel()
            empty.text = "当前版本尚无可审核内容。"
            empty.textColor = .secondaryLabel
            stackView.addArrangedSubview(empty)
        }
    }

    @objc private func confirmTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        if mode == .goldenSample {
            coordinator?.send(.confirmGoldenSample, payload: [
                "artifactVersionId": .string(id),
                "styleFeedback": .string(feedbackView.text ?? ""),
            ])
        } else {
            coordinator?.send(.confirmOutline, payload: ["artifactVersionId": .string(id)])
        }
    }

    @objc private func reviseTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              !(feedbackView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if mode == .goldenSample {
            let isFact = feedbackKind.selectedSegmentIndex == 1
            var payload: [String: NarrativeJSONValue] = [
                "artifactVersionId": .string(id),
            ]
            payload[isFact ? "factFeedback" : "styleFeedback"] = .string(feedbackView.text)
            coordinator?.send(
                .submitArtifactFeedback,
                payload: payload,
                successMessage: isFact
                    ? "事实更正已进入待确认记忆链路；审核通过前不会改写书稿事实。"
                    : "文字反馈已记录，可继续重写或确认样章。"
            )
        } else {
            coordinator?.send(.reviseOutline, payload: [
                "artifactVersionId": .string(id),
                "artifactType": .string(NarrativeArtifactType.outline.rawValue),
                "styleFeedback": .string(feedbackView.text),
            ])
        }
    }
    @objc private func editTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let artifact = project.artifacts?.first(where: { $0.artifactVersionId == id }) else { return }
        coordinator?.edit(artifact)
    }
    @objc private func historyTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let artifact = project.artifacts?.first(where: { $0.artifactVersionId == id }) else { return }
        coordinator?.showHistory(for: artifact)
    }
    @objc private func generateOutlineTapped() { coordinator?.send(.generateOutline) }

    private func renderedPayload(_ payload: [String: NarrativeJSONValue]) -> String {
        payload.map { "\($0.key)：\(String(describing: $0.value))" }.joined(separator: "\n")
    }
}

final class NarrativeProjectBlockedViewController: NarrativeScreenViewController {
    private let project: NarrativeProject
    private weak var coordinator: NarrativeProjectCoordinator?
    init(project: NarrativeProject, coordinator: NarrativeProjectCoordinator) {
        self.project = project; self.coordinator = coordinator; super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeading(project.title, subtitle: "当前状态：\(project.state.rawValue)")
        if project.state == .paused {
            stackView.addArrangedSubview(makeButton("继续写作", action: #selector(resumeTapped)))
            stackView.addArrangedSubview(makeButton("归档这本书", action: #selector(archiveTapped), emphasized: false))
        } else if project.state != .archived && project.state != .deleted {
            stackView.addArrangedSubview(makeButton("刷新状态", action: #selector(refreshTapped), emphasized: false))
        }
        if project.state != .deleted {
            stackView.addArrangedSubview(makeButton("删除写作项目", action: #selector(deleteTapped), emphasized: false))
        }
    }
    @objc private func refreshTapped() { coordinator?.refresh() }
    @objc private func resumeTapped() { coordinator?.send(.resumeProject) }
    @objc private func archiveTapped() { coordinator?.send(.archiveProject) }
    @objc private func deleteTapped() {
        let alert = UIAlertController(
            title: "删除写作项目？",
            message: "正式记忆不会被删除，但项目书稿和版本将不再可用。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.coordinator?.deleteProject()
        })
        present(alert, animated: true)
    }
}
