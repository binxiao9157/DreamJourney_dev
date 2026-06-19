import UIKit

final class MemoryArchiveVideoEntryViewController: UIViewController {
    var onCreateMockVideoArchive: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        configureSheet()
        buildLayout()
    }

    private func configureSheet() {
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DJDesignTokens.Radius.extraLarge
        }
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "录入视频片段"
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "视频素材暂为隐藏候选入口，等待选择、压缩、缩略图、存储和后端媒体策略确认后再开放。"
        subtitleLabel.font = DJDesignTokens.Font.body(15)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("关闭", for: .normal)
        cancelButton.titleLabel?.font = DJDesignTokens.Font.label(14)
        cancelButton.setTitleColor(DJDesignTokens.Color.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), cancelButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 12

        let card = UIView()
        card.backgroundColor = DJDesignTokens.Color.surface
        card.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        card.layer.borderWidth = 1
        card.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        DJDesignTokens.applySoftShadow(to: card)

        let iconContainer = UIView()
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        iconContainer.layer.cornerRadius = 28

        let iconView = UIImageView(image: UIImage(systemName: "video"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        let statusLabel = UILabel()
        statusLabel.text = "分析状态：\(MemoryArchiveAnalysisStatus.pending.archiveDisplayName)"
        statusLabel.font = DJDesignTokens.Font.title(18)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = "当前不会打开系统视频选择、不会上传视频；隐藏 QA 可生成 mock 视频档案，用来验证缩略图、上传状态和分析状态合同。单个视频上限 \(MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB)MB。"
        detailLabel.font = DJDesignTokens.Font.body(14)
        detailLabel.textColor = DJDesignTokens.Color.textSecondary
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let generateButton = UIButton(type: .system)
        generateButton.setTitle("生成测试视频档案", for: .normal)
        generateButton.titleLabel?.font = DJDesignTokens.Font.label(15)
        generateButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        generateButton.backgroundColor = DJDesignTokens.Color.surfaceContainer
        generateButton.layer.cornerRadius = 24
        generateButton.accessibilityIdentifier = "archive-video-entry-generate-mock"
        generateButton.addTarget(self, action: #selector(generateMockVideoArchiveTapped), for: .touchUpInside)

        let cardStack = UIStackView(arrangedSubviews: [iconContainer, statusLabel, detailLabel, generateButton])
        cardStack.axis = .vertical
        cardStack.alignment = .center
        cardStack.spacing = 14

        let helperLabel = UILabel()
        helperLabel.text = "后端存储合同：\(MemoryArchiveMediaReleaseReadiness.backendMediaStorageContract)。公开视频能力需要完成真机视频选择、压缩、缩略图、隐私文案和后端媒体策略验收。"
        helperLabel.font = DJDesignTokens.Font.label(12)
        helperLabel.textColor = DJDesignTokens.Color.textTertiary
        helperLabel.numberOfLines = 0

        let contentStack = UIStackView(arrangedSubviews: [
            headerStack,
            subtitleLabel,
            card,
            helperLabel,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 30,
            leading: DJDesignTokens.Spacing.page,
            bottom: 28,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(contentStack)
        card.addSubview(cardStack)
        iconContainer.addSubview(iconView)

        [
            contentStack,
            headerStack,
            titleLabel,
            cancelButton,
            card,
            cardStack,
            iconContainer,
            iconView,
            statusLabel,
            detailLabel,
            generateButton,
            helperLabel,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),

            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),

            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            generateButton.heightAnchor.constraint(equalToConstant: 48),
            generateButton.leadingAnchor.constraint(greaterThanOrEqualTo: cardStack.leadingAnchor),
            generateButton.trailingAnchor.constraint(lessThanOrEqualTo: cardStack.trailingAnchor),
        ])

        view.accessibilityIdentifier = "archive-video-entry-shell"
        statusLabel.accessibilityIdentifier = "archive-video-entry-status"
        detailLabel.accessibilityIdentifier = "archive-video-entry-boundary"
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func generateMockVideoArchiveTapped() {
        let handler = onCreateMockVideoArchive
        dismiss(animated: true) {
            handler?()
        }
    }
}
