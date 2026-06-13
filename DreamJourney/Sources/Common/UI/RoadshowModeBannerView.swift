import UIKit

final class RoadshowModeBannerView: UIView {
    var onRouteTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let view = UIImageView(image: UIImage(systemName: "sparkles.rectangle.stack.fill", withConfiguration: config))
        view.tintColor = .warmAccent
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .warmPrimary
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .warmSubtitle
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .warmAccent
        label.textAlignment = .center
        label.layer.cornerRadius = 9
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var routeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "清单"
        config.image = UIImage(systemName: "list.bullet.clipboard")
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        config.baseBackgroundColor = .warmPrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.accessibilityLabel = "查看演示清单"
        button.addTarget(self, action: #selector(routeTapped), for: .touchUpInside)
        return button
    }()

    private lazy var continueButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "下一步"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        config.baseBackgroundColor = .warmAccent
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.accessibilityLabel = "进入下一步演示"
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(
        status: RoadshowDemoSeed.RuntimeStatus,
        summary: RoadshowDemoRoute.CompletionSummary = RoadshowDemoRoute.completionSummary()
    ) {
        let nextTitle = summary.nextStepTitle ?? "复盘演示闭环"
        titleLabel.text = "演示向导"
        detailLabel.text = "下一步：\(nextTitle)\n\(status.userFacingDetail)"
        badgeLabel.text = summary.compactProgressText
        continueButton.configuration?.title = summary.primaryActionTitle
        continueButton.accessibilityLabel = summary.nextStepTitle.map { "进入下一步演示：\($0)" } ?? "复盘演示清单"
        accessibilityLabel = "演示向导，下一步：\(nextTitle)，\(status.userFacingDetail)，可进入下一步或查看演示清单"
    }

    private func setup() {
        backgroundColor = UIColor.warmSurface.withAlphaComponent(0.92)
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.warmDivider.cgColor

        let titleStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 8
        titleStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [titleStack, badgeLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let buttonRow = UIStackView(arrangedSubviews: [continueButton, routeButton])
        buttonRow.axis = .horizontal
        buttonRow.alignment = .fill
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [topRow, detailLabel, buttonRow])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 8
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = contentStack.topAnchor.constraint(equalTo: topAnchor)
        let bottomConstraint = contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        topConstraint.priority = .defaultHigh
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
            continueButton.heightAnchor.constraint(equalToConstant: 32),
            routeButton.heightAnchor.constraint(equalToConstant: 32),

            topConstraint,
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint,
        ])
    }

    @objc private func routeTapped() {
        onRouteTapped?()
    }

    @objc private func continueTapped() {
        onContinueTapped?()
    }
}

private extension RoadshowDemoSeed.RuntimeStatus {
    var userFacingDetail: String {
        if offlineMode {
            return "本机素材已准备，适合稳定演示；边界：不复活、不诊断、不展示私密原文。"
        }
        return "演示素材已准备，可按清单走完整主线；边界：不复活、不诊断。"
    }
}
