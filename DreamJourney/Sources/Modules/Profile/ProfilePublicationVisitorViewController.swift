import UIKit

/// Neutral text reader for one server-admitted PublicationVersion. The page
/// only receives the redacted projection and deterministic public answer.
final class ProfilePublicationVisitorViewController: UIViewController {
    private enum State {
        case loading
        case loaded(PublicationVisitorProjection, PublicationVisitorAnswer?)
        case failed(String)
    }

    private let runtime: PublicationVisitorRuntime
    private let readerClient: PublicationVisitorReaderClient
    private let accountLeaseProvider: () -> AccountLease?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private weak var questionField: UITextField?
    private weak var submitButton: UIButton?
    private var readUseCase: PublicationVisitorReadUseCase?
    private var projection: PublicationVisitorProjection?

    init(
        runtime: PublicationVisitorRuntime = .shared,
        readerClient: PublicationVisitorReaderClient = DreamJourneyBackendClient.shared,
        accountLeaseProvider: @escaping () -> AccountLease? = {
            AccountLeaseRuntime.shared.capture(forSubjectId: UserManager.shared.currentUser?.id)
        }
    ) {
        self.runtime = runtime
        self.readerClient = readerClient
        self.accountLeaseProvider = accountLeaseProvider
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "受邀回忆"
        view.backgroundColor = DJDesignTokens.Color.background
        view.accessibilityIdentifier = "profile-publication-visitor-shell"
        configureLayout()
        render(.loading)
        openInvitation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
    }

    private func configureLayout() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.spacing = 16
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

    private func openInvitation() {
        guard PublicationVisitorM2AccessGate.isRouteAllowed else {
            runtime.clear(reason: .policyDenied)
            render(.failed(PublicationVisitorAccessError.disabled.localizedDescription))
            return
        }
        guard let accountLease = accountLeaseProvider() else {
            runtime.clear(reason: .accountLeaseInvalid)
            render(.failed(PublicationVisitorAccessError.accountLeaseInvalid.localizedDescription))
            return
        }
        runtime.open(accountLease: accountLease) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    let useCase = self.runtime.makeReadUseCase(client: self.readerClient)
                    self.readUseCase = useCase
                    useCase.loadProjection { [weak self] result in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch result {
                            case .success(let projection):
                                self.projection = projection
                                self.render(.loaded(projection, nil))
                            case .failure(let error):
                                self.render(.failed(self.message(for: error)))
                            }
                        }
                    }
                case .failure(let error):
                    self.render(.failed(self.message(for: error)))
                }
            }
        }
    }

    @objc private func submitQuestion() {
        guard let question = questionField?.text,
              let projection,
              let readUseCase else { return }
        submitButton?.isEnabled = false
        readUseCase.answer(question) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.submitButton?.isEnabled = true
                switch result {
                case .success(let response):
                    self.projection = response.projection
                    self.render(.loaded(response.projection, response.answer))
                case .failure(let error):
                    if self.runtime.snapshot().session.isActive {
                        self.render(.loaded(projection, nil))
                    } else {
                        self.render(.failed(self.message(for: error)))
                    }
                }
            }
        }
    }

    @objc private func retry() {
        render(.loading)
        openInvitation()
    }

    private func render(_ state: State) {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        contentStack.addArrangedSubview(makeHeader())
        switch state {
        case .loading:
            contentStack.addArrangedSubview(makeStatusCard(
                title: "正在验证访问权限",
                message: "",
                showsSpinner: true
            ))
        case .failed(let message):
            contentStack.addArrangedSubview(makeStatusCard(
                title: "暂时无法打开",
                message: message,
                showsRetry: runtime.hasPendingInvitation
            ))
        case .loaded(let projection, let answer):
            contentStack.addArrangedSubview(makeProjectionCard(projection))
            contentStack.addArrangedSubview(makeQuestionCard(answer: answer))
        }
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.addArrangedSubview(makeLabel(
            text: "受邀回忆",
            font: DJDesignTokens.Font.title(24),
            color: DJDesignTokens.Color.textPrimary
        ))
        let disclosure = makeLabel(
            text: "内容来自本人确认的公开副本。",
            font: DJDesignTokens.Font.body(14),
            color: DJDesignTokens.Color.textSecondary
        )
        disclosure.accessibilityIdentifier = "profile-publication-visitor-disclosure"
        stack.addArrangedSubview(disclosure)
        return stack
    }

    private func makeProjectionCard(_ projection: PublicationVisitorProjection) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-visitor-projection"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(makeLabel(
            text: projection.title,
            font: DJDesignTokens.Font.title(19),
            color: DJDesignTokens.Color.textPrimary
        ))
        stack.addArrangedSubview(makeLabel(
            text: projection.body,
            font: DJDesignTokens.Font.body(15),
            color: DJDesignTokens.Color.textPrimary
        ))
        stack.addArrangedSubview(makeLabel(
            text: projection.aiDisclosure,
            font: DJDesignTokens.Font.body(12),
            color: DJDesignTokens.Color.textSecondary
        ))
        pin(stack, to: card)
        return card
    }

    private func makeQuestionCard(answer: PublicationVisitorAnswer?) -> UIView {
        let card = makeCard()
        card.accessibilityIdentifier = "profile-publication-visitor-question-card"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(makeLabel(
            text: "询问这段回忆",
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        ))

        let field = UITextField()
        field.placeholder = "输入一个问题"
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .send
        field.accessibilityIdentifier = "profile-publication-visitor-question-field"
        questionField = field
        stack.addArrangedSubview(field)

        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "发送"
        configuration.baseBackgroundColor = DJDesignTokens.Color.accent
        configuration.baseForegroundColor = .white
        button.configuration = configuration
        button.accessibilityIdentifier = "profile-publication-visitor-question-submit"
        button.addTarget(self, action: #selector(submitQuestion), for: .touchUpInside)
        submitButton = button
        stack.addArrangedSubview(button)

        if let answer {
            let answerLabel = makeLabel(
                text: answer.text,
                font: DJDesignTokens.Font.body(15),
                color: DJDesignTokens.Color.textPrimary
            )
            answerLabel.accessibilityIdentifier = "profile-publication-visitor-answer"
            stack.addArrangedSubview(answerLabel)
            stack.addArrangedSubview(makeLabel(
                text: answer.identityDisclosure,
                font: DJDesignTokens.Font.body(12),
                color: DJDesignTokens.Color.textSecondary
            ))
        }
        pin(stack, to: card)
        return card
    }

    private func makeStatusCard(
        title: String,
        message: String,
        showsSpinner: Bool = false,
        showsRetry: Bool = false
    ) -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        if showsSpinner {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            stack.addArrangedSubview(spinner)
        }
        stack.addArrangedSubview(makeLabel(
            text: title,
            font: DJDesignTokens.Font.title(17),
            color: DJDesignTokens.Color.textPrimary
        ))
        if !message.isEmpty {
            let label = makeLabel(
                text: message,
                font: DJDesignTokens.Font.body(14),
                color: DJDesignTokens.Color.textSecondary
            )
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }
        if showsRetry {
            let button = UIButton(type: .system)
            button.setTitle("重新验证", for: .normal)
            button.addTarget(self, action: #selector(retry), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        pin(stack, to: card)
        return card
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = DJDesignTokens.Radius.medium
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.35).cgColor
        return card
    }

    private func pin(_ stack: UIStackView, to card: UIView) {
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func message(for error: Error) -> String {
        if let accessError = error as? PublicationVisitorAccessError {
            return accessError.localizedDescription
        }
        return "受邀回忆暂时不可用"
    }
}
