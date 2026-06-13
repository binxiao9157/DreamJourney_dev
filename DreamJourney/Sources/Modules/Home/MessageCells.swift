import UIKit

// MARK: - AI/用户消息气泡Cell
final class TGMessageCell: UITableViewCell {
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let topPadding: CGFloat = 8
    static let timestampHeight: CGFloat = 13
    static let timestampTopPadding: CGFloat = 4
    static let bottomPadding: CGFloat = 6
    static let avatarSize: CGFloat = 32
    static let avatarMargin: CGFloat = 10

    // MARK: - 气泡
    private let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = false
        return v
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16)
        l.lineBreakMode = .byCharWrapping
        l.clipsToBounds = true
        return l
    }()

    // MARK: - AI 头像（渐变球）
    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        v.isHidden = true
        return v
    }()

    private let avatarGradient: CAGradientLayer = {
        let l = CAGradientLayer()
        // UI稿风格：迎光紫蓝渐变
        l.colors = [
            UIColor(red: 0.75, green: 0.65, blue: 0.90, alpha: 1.0).cgColor,
            UIColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 1.0).cgColor
        ]
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 1, y: 1)
        return l
    }()

    // MARK: - 时间戳
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = UIColor(white: 0.6, alpha: 1.0)
        return l
    }()

    private var isUserMessage = false
    private var currentText = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(avatarView)
        avatarView.layer.addSublayer(avatarGradient)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)
        [bubbleView, messageLabel, avatarView, timeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(text: String, isUser: Bool, timestamp: Date? = nil) {
        isUserMessage = isUser
        currentText = text

        messageLabel.attributedText = Self.attributedMessage(text, isUser: isUser)

        if isUser {
            // 用户气泡：深棕色、左下直角
            bubbleView.backgroundColor = UIColor(red: 0.22, green: 0.16, blue: 0.11, alpha: 1.0)
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            bubbleView.layer.shadowOpacity = 0
            avatarView.isHidden = true
        } else {
            // AI 气泡：纯白、深阴影、右下直角
            bubbleView.backgroundColor = .white
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            bubbleView.layer.shadowColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08).cgColor
            bubbleView.layer.shadowOpacity = 1
            bubbleView.layer.shadowOffset = CGSize(width: 0, height: 2)
            bubbleView.layer.shadowRadius = 8
            avatarView.isHidden = false
        }

        if let ts = timestamp {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            timeLabel.text = fmt.string(from: ts)
            timeLabel.isHidden = false
        } else {
            timeLabel.isHidden = true
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let availableWidth = max(contentView.bounds.width, UIScreen.main.bounds.width)
        let maxWidth = Self.maxBubbleWidth(for: availableWidth)
        let textSize = Self.messageTextSize(for: currentText, isUser: isUserMessage, maxBubbleWidth: maxWidth)
        let bubbleWidth = min(max(textSize.width + Self.horizontalPadding * 2, 44), maxWidth)
        let bubbleHeight = textSize.height + Self.verticalPadding * 2

        if isUserMessage {
            let x = contentView.bounds.width - bubbleWidth - 16
            bubbleView.frame = CGRect(x: x, y: Self.topPadding, width: bubbleWidth, height: bubbleHeight)
            timeLabel.frame = CGRect(x: x, y: bubbleView.frame.maxY + Self.timestampTopPadding, width: bubbleWidth, height: Self.timestampHeight)
            timeLabel.textAlignment = .right
        } else {
            let bubbleX: CGFloat = 16 + Self.avatarSize + Self.avatarMargin
            bubbleView.frame = CGRect(x: bubbleX, y: Self.topPadding, width: bubbleWidth, height: bubbleHeight)
            // 头像对齐气泡底部
            avatarView.frame = CGRect(
                x: 16,
                y: bubbleView.frame.maxY - Self.avatarSize,
                width: Self.avatarSize,
                height: Self.avatarSize
            )
            avatarGradient.frame = avatarView.bounds
            timeLabel.frame = CGRect(x: bubbleX, y: bubbleView.frame.maxY + Self.timestampTopPadding, width: bubbleWidth, height: Self.timestampHeight)
            timeLabel.textAlignment = .left
        }

        messageLabel.frame = CGRect(
            x: Self.horizontalPadding,
            y: Self.verticalPadding,
            width: bubbleView.bounds.width - Self.horizontalPadding * 2,
            height: bubbleView.bounds.height - Self.verticalPadding * 2
        ).integral
        messageLabel.preferredMaxLayoutWidth = messageLabel.bounds.width
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let maxWidth = Self.maxBubbleWidth(for: size.width)
        let textSize = Self.messageTextSize(for: currentText, isUser: isUserMessage, maxBubbleWidth: maxWidth)
        // bubble高度 + top间距 + 时间戳高度 + bottom间距
        return CGSize(
            width: size.width,
            height: textSize.height + Self.verticalPadding * 2 + Self.topPadding + Self.timestampHeight + Self.timestampTopPadding + Self.bottomPadding
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        currentText = ""
        timeLabel.text = nil
        avatarView.isHidden = true
    }

    static func maxBubbleWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.72, 220), availableWidth - 74)
    }

    static func attributedMessage(_ text: String, isUser: Bool) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.lineBreakMode = .byCharWrapping
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: isUser
                ? UIColor(white: 1.0, alpha: 0.95)
                : UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ])
    }

    static func messageTextSize(for text: String, isUser: Bool, maxBubbleWidth: CGFloat) -> CGSize {
        let maxTextWidth = max(maxBubbleWidth - horizontalPadding * 2, 40)
        let bounds = attributedMessage(text, isUser: isUser).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }
}

// MARK: - 照片卡片Cell
final class TGPhotoCell: UITableViewCell {

    /// 照片内容容器（右对齐，带阴影）
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 14
        v.layer.masksToBounds = false
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.10
        v.layer.shadowOffset = CGSize(width: 0, height: 3)
        v.layer.shadowRadius = 8
        return v
    }()

    /// 照片缩略图
    private let photoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 12
        iv.layer.masksToBounds = true
        iv.clipsToBounds = true
        return iv
    }()

    /// 时间戳
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = UIColor(white: 0.6, alpha: 1.0)
        l.textAlignment = .right
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(containerView)
        containerView.addSubview(photoImageView)
        contentView.addSubview(timeLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    static let photoSize: CGFloat = 200
    static let cellHeight: CGFloat = 200 + 8 + 17 + 6  // photo + top + time + bottom

    override func layoutSubviews() {
        super.layoutSubviews()
        let photoSize: CGFloat = TGPhotoCell.photoSize
        let right: CGFloat = 16
        let top: CGFloat = 8
        let x = contentView.bounds.width - photoSize - right

        containerView.frame = CGRect(x: x, y: top, width: photoSize, height: photoSize)
        photoImageView.frame = containerView.bounds
        timeLabel.frame = CGRect(x: x, y: containerView.frame.maxY + 4, width: photoSize, height: 13)
    }

    func configure(imagePath: String, timestamp: Date? = nil) {
        if let image = UIImage(contentsOfFile: imagePath) {
            photoImageView.image = image
        } else {
            photoImageView.image = UIImage(systemName: "photo")
        }
        if let ts = timestamp {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            timeLabel.text = fmt.string(from: ts)
            timeLabel.isHidden = false
        } else {
            timeLabel.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        timeLabel.text = nil
    }
}

// MARK: - 隐私确认卡片Cell
final class TGPrivacyCell: UITableViewCell {

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.warmDivider
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        return v
    }()

    private let privacyLabel: UILabel = {
        let l = UILabel()
        l.text = "🔒 这条回忆会保存在您的家族圈内，其他成员可见。如需私密保存请前往隐私设置。"
        l.font = .systemFont(ofSize: 13)
        l.textColor = .warmPrimary
        l.numberOfLines = 0
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(containerView)
        containerView.addSubview(privacyLabel)
        [containerView, privacyLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            privacyLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            privacyLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            privacyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            privacyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
