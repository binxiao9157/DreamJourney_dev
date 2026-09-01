import UIKit

final class NarrativeProjectCoordinator {
    private weak var navigationController: UINavigationController?
    private let accountLease: AccountLease
    private let context: DigitalHumanContext
    private let service: NarrativeBackendServicePort
    private(set) var project: NarrativeProject?

    private var subjectPersonaId: String {
        context.isSelfAssistant ? accountLease.subjectId : context.ownerId
    }

    init(
        navigationController: UINavigationController,
        accountLease: AccountLease,
        context: DigitalHumanContext,
        service: NarrativeBackendServicePort = NarrativeBackendService.shared
    ) {
        self.navigationController = navigationController
        self.accountLease = accountLease
        self.context = context
        self.service = service
    }

    func start() {
        let loading = NarrativeLoadingViewController(titleText: context.isSelfAssistant ? "我的自传" : "TA 的故事")
        push(loading)
        service.listProjects(accountLease: accountLease, subjectPersonaId: subjectPersonaId) { [weak self, weak loading] result in
            guard let self else { return }
            switch result {
            case .success(let projects):
                if let project = projects.first(where: { $0.projectType == self.projectType }) {
                    self.route(project)
                } else {
                    self.createProject()
                }
            case .failure(let error):
                loading?.showFailure(message: error.localizedDescription) { [weak self] in self?.start() }
            }
        }
    }

    func refresh() {
        guard let project else { start(); return }
        service.project(
            accountLease: accountLease,
            projectId: project.projectId,
            subjectPersonaId: subjectPersonaId
        ) { [weak self] result in
            switch result {
            case .success(let project): self?.route(project)
            case .failure(let error): self?.present(error)
            }
        }
    }

    func checkReadiness() {
        guard let project else { return }
        service.readiness(
            accountLease: accountLease,
            projectId: project.projectId,
            subjectPersonaId: subjectPersonaId
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let readiness):
                self.project = readiness.project
                self.replaceTop(with: NarrativeReadinessViewController(readiness: readiness, coordinator: self))
            case .failure(let error): self.present(error)
            }
        }
    }

    func send(
        _ type: NarrativeCommandType,
        payload: [String: NarrativeJSONValue] = [:],
        successMessage: String? = nil
    ) {
        guard let project else { return }
        do {
            try NarrativeStateMachine.require(type, from: project.state)
            let command = try NarrativeCommandEnvelope(
                commandID: UUID(),
                commandType: type,
                expectedProjectVersion: project.projectVersion,
                confirmed: true,
                payload: payload
            )
            service.command(
                accountLease: accountLease,
                projectId: project.projectId,
                subjectPersonaId: subjectPersonaId,
                command: command
            ) { [weak self] result in
                switch result {
                case .success(let value):
                    if let next = value.project { self?.route(next) }
                    else if let job = value.job { self?.showProgress(job: job) }
                    else { self?.refresh() }
                    if let successMessage { self?.presentMessage(successMessage) }
                case .failure(let error): self?.present(error)
                }
            }
        } catch {
            present(error)
        }
    }

    func chooseReplacementMaterial() {
        guard let project else { return }
        service.readiness(
            accountLease: accountLease,
            projectId: project.projectId,
            subjectPersonaId: subjectPersonaId
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let readiness):
                self.push(NarrativeMaterialSelectionViewController(
                    readiness: readiness,
                    coordinator: self
                ))
            case .failure(let error): self.present(error)
            }
        }
    }

    func openReader() {
        guard let project else { return }
        let reader = NarrativeReaderViewController(
            project: project,
            subjectPersonaId: subjectPersonaId,
            accountLease: accountLease,
            service: service
        )
        push(reader)
    }

    func edit(_ artifact: NarrativeArtifact) {
        if artifact.artifactType == .outline {
            push(NarrativeOutlineEditorViewController(artifact: artifact, coordinator: self))
        } else {
            push(NarrativeArtifactEditorViewController(artifact: artifact, coordinator: self))
        }
    }

    func showHistory(for artifact: NarrativeArtifact) {
        push(NarrativeVersionHistoryViewController(
            project: project,
            artifact: artifact,
            coordinator: self
        ))
    }

    func loadArtifacts(
        type: NarrativeArtifactType? = nil,
        completion: @escaping (Result<[NarrativeArtifact], Error>) -> Void
    ) {
        guard let project else {
            completion(.failure(NarrativeBackendServiceError.malformedResponse))
            return
        }
        service.artifacts(
            accountLease: accountLease,
            projectId: project.projectId,
            subjectPersonaId: subjectPersonaId,
            artifactType: type,
            completion: completion
        )
    }

    func exportBook(from presenter: UIViewController) {
        let choices = UIAlertController(
            title: "导出当前书稿",
            message: "可读文本适合阅读和保存；数据清单保留版本与正式记忆引用。",
            preferredStyle: .actionSheet
        )
        choices.addAction(UIAlertAction(title: "可读文本（TXT）", style: .default) { [weak self, weak presenter] _ in
            guard let self, let presenter else { return }
            self.performExport(from: presenter, format: .plainText)
        })
        choices.addAction(UIAlertAction(title: "数据清单（JSON）", style: .default) { [weak self, weak presenter] _ in
            guard let self, let presenter else { return }
            self.performExport(from: presenter, format: .machineReadable)
        })
        choices.addAction(UIAlertAction(title: "取消", style: .cancel))
        choices.popoverPresentationController?.sourceView = presenter.view
        choices.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.maxY - 80,
            width: 1,
            height: 1
        )
        presenter.present(choices, animated: true)
    }

    private enum ExportFormat {
        case plainText
        case machineReadable
    }

    private func performExport(from presenter: UIViewController, format: ExportFormat) {
        guard let project else { return }
        service.export(
            accountLease: accountLease,
            projectId: project.projectId,
            subjectPersonaId: subjectPersonaId
        ) { [weak self, weak presenter] result in
            guard let self, let presenter else { return }
            switch result {
            case .success(let value):
                let safeTitle = project.title.replacingOccurrences(of: "/", with: "-")
                let fileExtension: String
                let data: Data
                switch format {
                case .plainText:
                    fileExtension = "txt"
                    data = Data(value.plainText.utf8)
                case .machineReadable:
                    fileExtension = "json"
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                    guard let encoded = try? encoder.encode(value) else {
                        self.present(NarrativeBackendServiceError.malformedResponse)
                        return
                    }
                    data = encoded
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(safeTitle).\(fileExtension)")
                do {
                    try data.write(to: url, options: .atomic)
                    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    controller.popoverPresentationController?.sourceView = presenter.view
                    controller.popoverPresentationController?.sourceRect = CGRect(
                        x: presenter.view.bounds.midX,
                        y: presenter.view.bounds.maxY - 80,
                        width: 1,
                        height: 1
                    )
                    presenter.present(controller, animated: true)
                } catch {
                    self.present(error)
                }
            case .failure(let error): self.present(error)
            }
        }
    }

    func deleteProject() {
        guard let project else { return }
        service.deleteProject(
            accountLease: accountLease,
            projectId: project.projectId,
            expectedProjectVersion: project.projectVersion,
            subjectPersonaId: subjectPersonaId
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.project = nil
                self.navigationController?.popToRootViewController(animated: true)
            case .failure(let error):
                self.present(error)
            }
        }
    }

    func poll(job: NarrativeJob, completion: @escaping (Result<NarrativeJob, Error>) -> Void) {
        service.job(
            accountLease: accountLease,
            projectId: job.projectId,
            jobId: job.jobId,
            subjectPersonaId: subjectPersonaId,
            completion: completion
        )
    }

    func cancel(job: NarrativeJob, completion: @escaping (Result<NarrativeJob, Error>) -> Void) {
        service.cancelJob(
            accountLease: accountLease,
            projectId: job.projectId,
            jobId: job.jobId,
            subjectPersonaId: subjectPersonaId,
            completion: completion
        )
    }

    private var projectType: BookProjectType { context.isSelfAssistant ? .selfAutobiography : .taStory }
    private var narratorType: NarrativeNarratorType { context.isSelfAssistant ? .selfFirstPerson : .thirdPersonBiography }

    private func createProject() {
        let title = context.isSelfAssistant ? "我的自传" : "\(context.resolvedDisplayName)的故事"
        service.createProject(
            accountLease: accountLease,
            subjectPersonaId: subjectPersonaId,
            projectType: projectType,
            narratorType: narratorType,
            title: title
        ) { [weak self] result in
            switch result {
            case .success(let project): self?.route(project)
            case .failure(let error): self?.present(error)
            }
        }
    }

    private func route(_ project: NarrativeProject) {
        self.project = project
        switch project.state {
        case .notStarted, .checkingReadiness, .needsMoreMemory, .readyForConfirmation:
            checkReadiness()
        case .generatingAuditions, .generatingGoldenSample:
            replaceTop(with: NarrativeLoadingViewController(titleText: "正在整理写作材料"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.refresh()
            }
        case .auditionsReady:
            replaceTop(with: NarrativeAuditionsViewController(project: project, coordinator: self))
        case .goldenSampleReview:
            replaceTop(with: NarrativeArtifactReviewViewController(project: project, mode: .goldenSample, coordinator: self))
        case .toneConfirmed, .outlineReview:
            replaceTop(with: NarrativeArtifactReviewViewController(project: project, mode: .outline, coordinator: self))
        case .writing, .updateAvailable:
            replaceTop(with: NarrativeWorkbenchViewController(project: project, coordinator: self))
        case .paused, .disputed, .suspended:
            replaceTop(with: NarrativeProjectBlockedViewController(project: project, coordinator: self))
        case .archived, .deleted:
            replaceTop(with: NarrativeProjectBlockedViewController(project: project, coordinator: self))
        }
    }

    private func showProgress(job: NarrativeJob) {
        replaceTop(with: NarrativeJobProgressViewController(job: job, coordinator: self))
    }

    private func push(_ viewController: UIViewController) {
        viewController.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func replaceTop(with viewController: UIViewController) {
        viewController.hidesBottomBarWhenPushed = true
        guard let navigationController else { return }
        var controllers = navigationController.viewControllers
        if controllers.last is NarrativeScreenViewController {
            controllers[controllers.count - 1] = viewController
            navigationController.setViewControllers(controllers, animated: false)
        } else {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    private func present(_ error: Error) {
        guard let top = navigationController?.topViewController else { return }
        let alert = UIAlertController(title: "暂时无法继续", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        top.present(alert, animated: true)
    }

    private func presentMessage(_ message: String) {
        guard let top = navigationController?.topViewController else { return }
        let alert = UIAlertController(title: "已提交", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        top.present(alert, animated: true)
    }
}

class NarrativeScreenViewController: UIViewController {
    let scrollView = UIScrollView()
    let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        stackView.axis = .vertical
        stackView.spacing = 18
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -36),
        ])
    }

    func addHeading(_ text: String, subtitle: String? = nil) {
        let title = UILabel()
        title.text = text
        title.font = .systemFont(ofSize: 32, weight: .semibold)
        title.numberOfLines = 0
        stackView.addArrangedSubview(title)
        if let subtitle {
            let label = UILabel()
            label.text = subtitle
            label.font = .systemFont(ofSize: 16)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            stackView.addArrangedSubview(label)
        }
    }

    func makeButton(_ title: String, action: Selector, emphasized: Bool = true) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 6
        button.backgroundColor = emphasized ? UIColor(red: 0.56, green: 0.30, blue: 0.05, alpha: 1) : .secondarySystemBackground
        button.setTitleColor(emphasized ? .white : .label, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

final class NarrativeLoadingViewController: NarrativeScreenViewController {
    private let titleText: String
    private let activity = UIActivityIndicatorView(style: .large)
    private var retry: (() -> Void)?

    init(titleText: String) { self.titleText = titleText; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        addHeading(titleText, subtitle: "正在读取已确认的正式记忆")
        activity.startAnimating()
        stackView.addArrangedSubview(activity)
    }

    func showFailure(message: String, retry: @escaping () -> Void) {
        self.retry = retry
        activity.stopAnimating()
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(makeButton("重新加载", action: #selector(retryTapped)))
    }

    @objc private func retryTapped() { retry?() }
}
