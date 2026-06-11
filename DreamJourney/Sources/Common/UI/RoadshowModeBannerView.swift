import UIKit

final class RoadshowModeBannerView: UIView {
    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let view = UIImageView(image: UIImage(systemName: "play.rectangle.fill", withConfiguration: config))
        view.tintColor = .warmAccent
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .warmPrimary
        label.numberOfLines = 1
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .warmSubtitle
        label.numberOfLines = 2
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(status: RoadshowDemoSeed.RuntimeStatus) {
        titleLabel.text = status.title
        detailLabel.text = status.detail
        badgeLabel.text = status.offlineMode ? "离线兜底" : "Demo Seed"
        accessibilityLabel = "\(status.title)，\(status.detail)"
    }

    private func setup() {
        backgroundColor = UIColor.warmSurface.withAlphaComponent(0.92)
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.warmDivider.cgColor

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack, badgeLabel])
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

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

            topConstraint,
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint,
        ])
    }
}
