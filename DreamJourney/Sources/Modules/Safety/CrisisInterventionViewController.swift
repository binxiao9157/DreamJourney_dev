import UIKit

final class CrisisInterventionViewController: UIViewController {
    private let assessment: SafetyAssessment

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "heart.fill", withConfiguration: config))
        imageView.tintColor = .warmPrimary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "你现在不是一个人"
        label.font = .boldSystemFont(ofSize: 28)
        label.textColor = .warmPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "我不能继续当前角色扮演内容。此刻真实的人类支持更重要，请联系你信任的人，或拨打专业求助电话。"
        label.font = .systemFont(ofSize: 17)
        label.textColor = .warmSubtitle
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .warmSubtitle.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var safeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("我现在安全", for: .normal)
        button.setTitleColor(.warmPrimary, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 17)
        button.backgroundColor = .warmSurface
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.warmPrimary.withAlphaComponent(0.18).cgColor
        button.addTarget(self, action: #selector(safeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var callButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("拨打求助电话", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 17)
        button.backgroundColor = .warmPrimary
        button.layer.cornerRadius = 14
        button.addTarget(self, action: #selector(callButtonTapped), for: .touchUpInside)
        return button
    }()

    init(assessment: SafetyAssessment) {
        self.assessment = assessment
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        reasonLabel.text = assessment.reason
        setupLayout()
    }

    private func setupLayout() {
        let contentStack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, reasonLabel])
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 18

        let buttonStack = UIStackView(arrangedSubviews: [callButton, safeButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        [contentStack, buttonStack].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),

            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -76),

            messageLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            safeButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    @objc private func safeButtonTapped() {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func callButtonTapped() {
        guard let url = URL(string: "tel://988"),
              UIApplication.shared.canOpenURL(url) else {
            TGToast.show(type: .info, message: "当前设备无法拨打电话，请直接联系 988 或当地紧急联系人")
            return
        }

        UIApplication.shared.open(url)
    }
}
