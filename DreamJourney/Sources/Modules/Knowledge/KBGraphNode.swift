import UIKit

// MARK: - KBGraphNode

/// 家族知识图谱中的人物节点视图
/// 圆形，直径 60pt，背景色按关系分色，显示姓名首字 + 底部标签
final class KBGraphNode: UIView {

    // MARK: - Constants

    static let diameter: CGFloat = 60.0

    // MARK: - Properties

    let person: KBPerson

    /// 当前是否处于选中态
    var isSelectedNode: Bool = false {
        didSet { updateSelectionAppearance() }
    }

    // MARK: - Subviews

    private let circleView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        return v
    }()

    private let initialLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textColor = .white
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textColor = .warmPrimary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let relationLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 9, weight: .regular)
        l.textColor = .warmSubtitle
        l.numberOfLines = 1
        return l
    }()

    // MARK: - Init

    init(person: KBPerson) {
        self.person = person
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter + 30))
        setupUI()
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        let d = Self.diameter

        // 圆形节点
        circleView.layer.cornerRadius = d / 2.0
        addSubview(circleView)
        circleView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circleView.topAnchor.constraint(equalTo: topAnchor),
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.widthAnchor.constraint(equalToConstant: d),
            circleView.heightAnchor.constraint(equalToConstant: d),
        ])

        // 首字
        circleView.addSubview(initialLabel)
        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            initialLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
        ])

        // 姓名标签
        addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 2),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])

        // 关系标签
        addSubview(relationLabel)
        relationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            relationLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            relationLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            relationLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])

        // 默认边框
        circleView.layer.borderWidth = 2.0
        circleView.layer.borderColor = UIColor.white.cgColor
    }

    private func configure() {
        // 首字
        initialLabel.text = String(person.name.prefix(1))

        // 标签
        nameLabel.text = person.name
        relationLabel.text = person.relation ?? ""

        circleView.backgroundColor = colorForRelation(person.relation)
    }

    // MARK: - Selection

    private func updateSelectionAppearance() {
        if isSelectedNode {
            circleView.layer.borderWidth = 3.5
            circleView.layer.borderColor = UIColor.warmAccent.cgColor

            UIView.animate(withDuration: 0.4,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.8,
                           options: [],
                           animations: {
                self.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            })
        } else {
            circleView.layer.borderWidth = 2.0
            circleView.layer.borderColor = UIColor.white.cgColor

            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.5,
                           options: [],
                           animations: {
                self.transform = .identity
            })
        }
    }

    // MARK: - Helpers

    /// 根据关系返回对应颜色
    /// 直系（父母、祖父母）→ 橙色；旁系（叔伯姑舅姨）→ 蓝色；其他 → 灰色
    private func colorForRelation(_ relation: String?) -> UIColor {
        guard let r = relation else {
            // 没有关系 → 可能是"我"自己，用强调色
            return .warmAccent
        }

        let directKeywords = ["父", "母", "爸", "妈", "祖父", "祖母", "外公", "外婆",
                              "爷爷", "奶奶", "姥姥", "姥爷", "儿", "女", "子", "孙"]
        let collateralKeywords = ["叔", "伯", "姑", "舅", "姨", "堂", "表", "侄"]

        if directKeywords.contains(where: { r.contains($0) }) {
            // 直系 → 橙色
            return UIColor(red: 0.92, green: 0.55, blue: 0.20, alpha: 1.0)
        } else if collateralKeywords.contains(where: { r.contains($0) }) {
            // 旁系 → 蓝色
            return UIColor(red: 0.30, green: 0.55, blue: 0.78, alpha: 1.0)
        } else {
            // 其他 → 灰色
            return UIColor(red: 0.60, green: 0.57, blue: 0.54, alpha: 1.0)
        }
    }

    // MARK: - Hit Test

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 扩大点击区域
        let expanded = bounds.insetBy(dx: -10, dy: -10)
        return expanded.contains(point)
    }
}
