import UIKit

// MARK: - KBGraphEdge

/// 家族知识图谱中连接两个人物节点的边
/// 使用 CAShapeLayer 绘制贝塞尔曲线
final class KBGraphEdge {

    // MARK: - Properties

    let fromPersonId: String
    let toPersonId: String
    let relationLabel: String?

    /// 连线图层
    let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.warmDivider.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 1.5
        layer.lineCap = .round
        return layer
    }()

    /// 可选的关系标签
    private(set) var labelLayer: CATextLayer?

    // MARK: - Init

    init(fromPersonId: String, toPersonId: String, relationLabel: String? = nil) {
        self.fromPersonId = fromPersonId
        self.toPersonId = toPersonId
        self.relationLabel = relationLabel

        if let text = relationLabel, !text.isEmpty {
            setupLabelLayer(text: text)
        }
    }

    // MARK: - Public

    /// 更新连线路径
    /// - Parameters:
    ///   - from: 起点节点中心坐标
    ///   - to: 终点节点中心坐标
    func updatePath(from: CGPoint, to: CGPoint) {
        let path = UIBezierPath()
        path.move(to: from)

        // 贝塞尔曲线：控制点偏移，产生弧度
        let midX = (from.x + to.x) / 2.0
        let midY = (from.y + to.y) / 2.0

        // 垂直方向偏移量（让曲线有弧度）
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        let offset = min(dist * 0.15, 30.0)

        // 控制点：在中点处沿法线方向偏移
        let nx = -dy / max(dist, 1.0)
        let ny = dx / max(dist, 1.0)

        let controlPoint = CGPoint(x: midX + nx * offset, y: midY + ny * offset)

        path.addQuadCurve(to: to, controlPoint: controlPoint)

        shapeLayer.path = path.cgPath

        // 更新标签位置
        if let label = labelLayer {
            let labelSize = label.frame.size
            label.frame = CGRect(
                x: midX - labelSize.width / 2.0,
                y: midY - labelSize.height / 2.0 - 8,
                width: labelSize.width,
                height: labelSize.height
            )
        }
    }

    // MARK: - Private

    private func setupLabelLayer(text: String) {
        let layer = CATextLayer()
        layer.string = text
        layer.fontSize = 9
        layer.foregroundColor = UIColor.warmSubtitle.cgColor
        layer.backgroundColor = UIColor.warmBackground.withAlphaComponent(0.8).cgColor
        layer.cornerRadius = 3
        layer.alignmentMode = .center
        layer.contentsScale = UIScreen.main.scale

        // 计算文字大小
        let font = UIFont.systemFont(ofSize: 9)
        let size = (text as NSString).size(withAttributes: [.font: font])
        layer.frame = CGRect(x: 0, y: 0, width: size.width + 8, height: size.height + 4)

        labelLayer = layer
    }
}
