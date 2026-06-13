import UIKit

// MARK: - KBGraphViewController

/// 家族知识图谱可视化 — 力导向布局展示人物关系网络
/// 支持双指缩放、单指拖拽画布、长按拖拽单个节点
final class KBGraphViewController: UIViewController {

    // MARK: - Properties

    private let layoutEngine = KBGraphLayoutEngine()

    /// 所有节点视图 (personId → node)
    private var nodeViews: [String: KBGraphNode] = [:]

    /// 所有连线
    private var edges: [KBGraphEdge] = []

    /// 节点位置（力导向计算结果）
    private var nodePositions: [String: CGPoint] = [:]

    /// 当前被长按拖拽的节点
    private weak var draggingNode: KBGraphNode?

    /// 画布内容视图
    private let canvasView = UIView()

    // MARK: - Empty State

    private lazy var emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "还没有可成图的人物\n\n请在档案馆或对话里补充具体姓名和关系，\n不要只写“妈妈/奶奶”这类称谓。"
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 16)
        l.textColor = .warmSubtitle
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - ScrollView

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 0.5
        sv.maximumZoomScale = 3.0
        sv.delegate = self
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .warmBackground
        sv.bouncesZoom = true
        return sv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家族图谱"
        view.backgroundColor = .warmBackground
        setupScrollView()
        setupGestures()
        buildGraph()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerCanvas()
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.addSubview(canvasView)
    }

    private func setupGestures() {
        // 长按拖拽节点
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        canvasView.addGestureRecognizer(longPress)

        // 点击选中节点
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        canvasView.addGestureRecognizer(tap)
    }

    // MARK: - Build Graph

    private func buildGraph() {
        // 确保有一个"我"节点
        let selfId = "__self__"
        let displayGraph = KBLiteManager.shared.displayGraphForLocalBrowsing()
        var people = displayGraph.people

        let currentUserName = UserManager.shared.currentUser?.nickname ?? "我"
        if !people.contains(where: { $0.id == selfId }) {
            let selfPerson = KBPerson(
                id: selfId,
                name: currentUserName,
                aliases: ["我"],
                relation: nil,
                traits: [],
                relatedPersonIds: people.map { $0.id },
                sourceSessionIds: [],
                createdAt: Date(),
                updatedAt: Date()
            )
            people.insert(selfPerson, at: 0)
        }

        // 人物数 < 2（只有"我"节点），显示空态提示
        guard people.count >= 2 else {
            showEmptyState()
            return
        }

        // 计算布局
        nodePositions = layoutEngine.computeLayout(for: people, graph: displayGraph)

        // 确定画布尺寸
        let canvasSize = calculateCanvasSize()
        canvasView.frame = CGRect(origin: .zero, size: canvasSize)
        scrollView.contentSize = canvasSize

        let center = CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)

        // 创建连线
        buildEdges(people: people, events: displayGraph.events, center: center)

        // 创建节点
        for person in people {
            guard let pos = nodePositions[person.id] else { continue }

            let node = KBGraphNode(person: person)
            let screenPos = CGPoint(x: center.x + pos.x, y: center.y + pos.y)
            node.center = CGPoint(x: screenPos.x, y: screenPos.y - 15)

            canvasView.addSubview(node)
            nodeViews[person.id] = node
        }

        // 更新连线路径
        updateEdgePaths(center: center)
    }

    private func buildEdges(people: [KBPerson], events: [KBEvent], center: CGPoint) {
        // 收集所有需要连线的人物对
        var edgeSet: Set<String> = []

        for person in people {
            for relatedId in person.relatedPersonIds {
                let key = [person.id, relatedId].sorted().joined(separator: "-")
                if !edgeSet.contains(key) {
                    edgeSet.insert(key)
                    let edge = KBGraphEdge(fromPersonId: person.id, toPersonId: relatedId)
                    edges.append(edge)
                    canvasView.layer.insertSublayer(edge.shapeLayer, at: 0)
                    if let labelLayer = edge.labelLayer {
                        canvasView.layer.addSublayer(labelLayer)
                    }
                }
            }
        }

        // 如果没有显式关系边，用事件推断
        if edges.isEmpty {
            let allIds = Set(people.map { $0.id })
            for event in events {
                let participants = event.participantIds.filter { allIds.contains($0) }
                for i in 0..<participants.count {
                    for j in (i + 1)..<participants.count {
                        let key = [participants[i], participants[j]].sorted().joined(separator: "-")
                        if !edgeSet.contains(key) {
                            edgeSet.insert(key)
                            let edge = KBGraphEdge(fromPersonId: participants[i], toPersonId: participants[j])
                            edges.append(edge)
                            canvasView.layer.insertSublayer(edge.shapeLayer, at: 0)
                        }
                    }
                }
            }
        }
    }

    private func updateEdgePaths(center: CGPoint) {
        for edge in edges {
            guard let fromPos = nodePositions[edge.fromPersonId],
                  let toPos = nodePositions[edge.toPersonId] else { continue }

            let from = CGPoint(x: center.x + fromPos.x, y: center.y + fromPos.y)
            let to = CGPoint(x: center.x + toPos.x, y: center.y + toPos.y)
            edge.updatePath(from: from, to: to)
        }
    }

    private func calculateCanvasSize() -> CGSize {
        guard !nodePositions.isEmpty else {
            return CGSize(width: view.bounds.width, height: view.bounds.height)
        }

        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        for pos in nodePositions.values {
            maxX = max(maxX, abs(pos.x))
            maxY = max(maxY, abs(pos.y))
        }

        // 留出节点大小和边距
        let padding: CGFloat = 150
        let width = max((maxX + padding) * 2, view.bounds.width)
        let height = max((maxY + padding) * 2, view.bounds.height)

        return CGSize(width: width, height: height)
    }

    private func centerCanvas() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2.0, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2.0, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: - Empty State

    private func showEmptyState() {
        scrollView.isHidden = true
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Gestures

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: canvasView)

        // 清除之前的选中态
        for node in nodeViews.values {
            node.isSelectedNode = false
        }

        // 查找被点击的节点
        for node in nodeViews.values {
            if node.frame.contains(location) {
                node.isSelectedNode = true
                break
            }
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: canvasView)

        switch gesture.state {
        case .began:
            // 找到被长按的节点
            for node in nodeViews.values {
                if node.frame.contains(location) {
                    draggingNode = node
                    node.isSelectedNode = true

                    // 禁用 scrollView 滚动
                    scrollView.isScrollEnabled = false

                    UIView.animate(withDuration: 0.2) {
                        node.alpha = 0.8
                    }
                    break
                }
            }

        case .changed:
            guard let node = draggingNode else { return }

            // 移动节点
            node.center = location

            // 更新该节点的位置记录
            let canvasCenter = CGPoint(x: canvasView.bounds.width / 2.0,
                                       y: canvasView.bounds.height / 2.0)
            nodePositions[node.person.id] = CGPoint(x: location.x - canvasCenter.x,
                                                    y: location.y - canvasCenter.y)

            // 重新绘制连线
            updateEdgePaths(center: canvasCenter)

        case .ended, .cancelled:
            guard let node = draggingNode else { return }

            UIView.animate(withDuration: 0.2) {
                node.alpha = 1.0
            }

            draggingNode = nil
            scrollView.isScrollEnabled = true

        default:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate

extension KBGraphViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return canvasView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCanvas()
    }
}
