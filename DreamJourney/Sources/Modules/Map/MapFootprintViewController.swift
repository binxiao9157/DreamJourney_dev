#if (UI_QA_SIMULATOR || RELEASE_SCOPE_SIMULATOR) && targetEnvironment(simulator)
import UIKit

// MARK: - 足迹页面访问模式
enum FootprintViewMode {
    case host
    case guest
}

final class MapFootprintViewController: UIViewController {
    private let viewMode: FootprintViewMode
    private let ownerName: String?

    init(viewMode: FootprintViewMode = .host, ownerId: String, ownerName: String? = nil) {
        self.viewMode = viewMode
        self.ownerName = ownerName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        setupPlaceholder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch viewMode {
        case .host:
            navigationController?.setNavigationBarHidden(true, animated: animated)
        case .guest:
            navigationController?.setNavigationBarHidden(false, animated: animated)
            title = ownerName.map { "\($0)的足迹" } ?? "足迹"
        }
    }

    private func setupPlaceholder() {
        let titleLabel = UILabel()
        titleLabel.text = "足迹"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .warmPrimary

        let messageLabel = UILabel()
        messageLabel.text = "模拟器视觉 QA 暂不加载地图 SDK"
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = TGColors.textSecondary
        messageLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
#else
import UIKit
import MAMapKit
import AMapFoundationKit

// MARK: - 足迹页面访问模式
enum FootprintViewMode {
    case host         // 主态：老人查看自己的足迹，展示全部回忆（含私密）
    case guest        // 客态：亲属查看别人的足迹，仅展示公开回忆
}

// MARK: - MapFootprintViewController：寻梦环游足迹地图页（支持主客态复用）
final class MapFootprintViewController: UIViewController {

    // MARK: - Properties
    private let viewMode: FootprintViewMode
    private let ownerId: String           // 足迹所属用户 ID
    private let ownerName: String?        // 足迹所属用户名称（客态显示用）
    private let accountLease: AccountLease?
    private var mapView: MAMapView?       // 安全可选：缺 ApiKey 等场景下为 nil，避免崩溃
    private var annotations: [MemoryAnnotation] = []
    private var memories: [MemoryModel] = []
    private let presentationStore = MemoryMapPresentationStore.shared
    private var readMemoryIds: Set<String> = []
    private var previouslyBouncedMemoryIds: Set<String> = []

    // MARK: - Init
    init(viewMode: FootprintViewMode = .host, ownerId: String, ownerName: String? = nil) {
        self.viewMode = viewMode
        self.ownerId = ownerId
        self.ownerName = ownerName
        accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: nil)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // 定位按钮
    private lazy var locateButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "location.fill", withConfiguration: config), for: .normal)
        b.tintColor = .warmPrimary
        b.backgroundColor = .white
        b.layer.cornerRadius = 22
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.1
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
        b.layer.shadowRadius = 4
        b.layer.masksToBounds = false
        b.addTarget(self, action: #selector(locateTapped), for: .touchUpInside)
        return b
    }()

    // 底部统计栏
    private lazy var statsBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        v.layer.cornerRadius = 16
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowOffset = CGSize(width: 0, height: -2)
        v.layer.shadowRadius = 8
        return v
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = TGColors.textPrimary
        l.textAlignment = .center
        return l
    }()

    // 地图加载失败时的占位提示（缺 ApiKey 等场景）
    private lazy var mapPlaceholderLabel: UILabel = {
        let l = UILabel()
        l.text = "地图加载失败\n请检查网络或 AMapAPIKey 配置"
        l.font = .systemFont(ofSize: 14)
        l.textColor = TGColors.textSecondary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    // 顶部左上自定义标题（host 模式使用，与"寻梦环游""亲友" Tab 统一样式）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "足迹"
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = .warmPrimary
        return l
    }()

    /// statsBar 底部约束引用，viewDidLayoutSubviews 中动态更新 constant 跟随 home indicator
    private var statsBarBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        // ⚠️ 不在此设置 additionalSafeAreaInsets：detail 页 hidesBottomBarWhenPushed 触发的
        // safeArea 重算会与该值叠加，导致返回足迹页后 statsBar 偏离 TabBar 顶部。
        // 改为在 viewDidLayoutSubviews 用 keyWindow 的系统级 home indicator inset 直接计算。
        setupMapView()
        setupUI()
        configureForViewMode()
        loadMemories()
        setupNotifications()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // host 模式：让 statsBar 紧贴自定义 WarmTabBar 顶部（56pt + home indicator 高）
        guard viewMode == .host else { return }
        let bottomOffset = WarmTabBarView.tabBarHeight + Self.systemBottomSafeInset
        statsBarBottomConstraint?.constant = -bottomOffset
    }

    /// 通过 keyWindow 获取纯系统 home indicator 高度，避免受任何 VC 的 additionalSafeAreaInsets 污染
    private static var systemBottomSafeInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        // host 模式仿"寻梦环游""亲友" Tab：隐藏系统 navigationBar，使用自绘标题；
        // guest 模式（被 push 进入）保持系统 navigationBar，展示返回按钮 + "{ownerName}的足迹"
        switch viewMode {
        case .host:
            navigationController?.setNavigationBarHidden(true, animated: animated)
        case .guest:
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    // MARK: - Configure for ViewMode
    private func configureForViewMode() {
        switch viewMode {
        case .host:
            // 主态：使用 view 内自绘 titleLabel "足迹"，隐藏系统 navigationBar
            title = nil
            navigationItem.rightBarButtonItem = nil
            titleLabel.isHidden = false
        case .guest:
            title = ownerName.map { "\($0)的足迹" } ?? "足迹"
            titleLabel.isHidden = true
        }
    }

    // MARK: - 回忆录入口

    @objc private func memoirListTapped() {
        MemoirFlowManager.shared.pushMemoirList(from: self)
    }

    // MARK: - Setup MapView
    private func setupMapView() {
        // ⚠️ AMap3DMap 8.1.0+：必须先在 AppDelegate 调用隐私合规接口；
        //    且 Info.plist 中 AMapAPIKey 必须为有效 Key，否则地图将无法正常加载。
        let map = MAMapView(frame: view.bounds)
        map.delegate = self
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // ====== 极简地图模式：不展示详细地名/POI/路况/楼块 ======
        map.mapType = .standard
        map.isShowsLabels = false           // 关闭地名/POI 文字标签（极简关键开关）
        map.isShowTraffic = false           // 关闭路况
        map.isShowsBuildings = false        // 关闭 3D 楼块
        map.touchPOIEnabled = false         // 禁止点击 POI 弹气泡
        map.showsCompass = false
        map.showsScale = false
        map.showsUserLocation = false
        map.isRotateEnabled = false
        map.isRotateCameraEnabled = false   // 禁用 3D 倾斜，纯平面观感

        // 默认视野：覆盖中国大陆
        map.zoomLevel = 4.5
        map.centerCoordinate = CLLocationCoordinate2D(latitude: 33.5, longitude: 110.0)

        // 必须插到所有 UI 控件之下，避免遮挡按钮/统计栏
        view.insertSubview(map, at: 0)
        self.mapView = map
    }

    // MARK: - Setup UI
    private func setupUI() {
        // 1. 先把所有视图加入层级（约束激活前必须保证视图已加入同一父视图）
        view.addSubview(statsBar)
        view.addSubview(locateButton)
        view.addSubview(mapPlaceholderLabel)
        view.addSubview(titleLabel)
        statsBar.addSubview(statsLabel)

        [statsBar, locateButton, statsLabel, mapPlaceholderLabel, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // 2. 再统一激活约束
        let statsBottom = statsBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
        statsBarBottomConstraint = statsBottom
        NSLayoutConstraint.activate([
            // 顶部左上标题（host 模式可见；与"寻梦环游""亲友" Tab 完全相同的字号、间距）
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // 底部统计栏（直接锚定 view.bottomAnchor，constant 由 viewDidLayoutSubviews 动态计算
            // -(56 + home indicator)，避免 hidesBottomBarWhenPushed 引起的 safeArea 污染）
            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBottom,
            statsBar.heightAnchor.constraint(equalToConstant: 60),

            statsLabel.centerXAnchor.constraint(equalTo: statsBar.centerXAnchor),
            statsLabel.topAnchor.constraint(equalTo: statsBar.topAnchor, constant: 12),

            // 定位按钮（依赖 statsBar，必须在 statsBar 已 addSubview 后激活）
            locateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            locateButton.bottomAnchor.constraint(equalTo: statsBar.topAnchor, constant: -16),
            locateButton.widthAnchor.constraint(equalToConstant: 44),
            locateButton.heightAnchor.constraint(equalToConstant: 44),

            // 地图加载失败占位提示
            mapPlaceholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mapPlaceholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mapPlaceholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            mapPlaceholderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        // 地图未成功创建时显示提示，并隐藏定位按钮
        if mapView == nil {
            mapPlaceholderLabel.isHidden = false
            locateButton.isHidden = true
        }
    }

    // MARK: - Load Memories
    private func loadMemories() {
        let normalizedOwnerId = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let accountLease,
              !normalizedOwnerId.isEmpty,
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed,
              viewMode != .host || normalizedOwnerId == accountLease.subjectId else {
            clearMemories()
            return
        }
        switch viewMode {
        case .host:
            memories = MemoryRepository.shared.getAllByOwner(
                normalizedOwnerId,
                accountLease: accountLease
            )
        case .guest:
            memories = MemoryRepository.shared.getPublicByOwner(
                normalizedOwnerId,
                accountLease: accountLease
            )
        }
        guard AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            clearMemories()
            return
        }
        let presentationState = presentationStore.load(
            ownerId: normalizedOwnerId,
            accountLease: accountLease
        )
        readMemoryIds = presentationState.readMemoryIds
        previouslyBouncedMemoryIds = presentationState.bouncedMemoryIds
        print("[MemoirSync] MapFootprintVC.loadMemories: ownerId=\(ownerId), viewMode=\(viewMode), memories=\(memories.count), firstId=\(memories.first?.id ?? "nil"), firstTitle=\(memories.first?.title ?? "nil")")
        updateStats()
        addAnnotations()
    }

    private func clearMemories() {
        memories = []
        readMemoryIds = []
        previouslyBouncedMemoryIds = []
        updateStats()
        addAnnotations()
    }

    @discardableResult
    private func markRead(_ memoryId: String) -> Bool {
        guard let accountLease,
              presentationStore.markRead(
                  memoryId: memoryId,
                  ownerId: ownerId,
                  accountLease: accountLease
              ) else {
            return false
        }
        readMemoryIds.insert(memoryId)
        return true
    }

    @discardableResult
    private func markBounced(_ memoryId: String) -> Bool {
        guard let accountLease else { return false }
        return presentationStore.markBounced(
            memoryId: memoryId,
            ownerId: ownerId,
            accountLease: accountLease
        )
    }

    private func addAnnotations() {
        guard let mapView = mapView else { return }
        // 移除旧标注
        mapView.removeAnnotations(annotations)
        annotations.removeAll()

        for memory in memories {
            let annotation = MemoryAnnotation(memory: memory)
            annotations.append(annotation)
        }
        mapView.addAnnotations(annotations)

        // 调整地图视野包含所有标注
        if !annotations.isEmpty {
            mapView.showAnnotations(
                annotations,
                edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 100, right: 40),
                animated: true
            )
        }
    }

    private func updateStats() {
        let count = memories.count
        let cities = Set(memories.map { $0.location }).count
        let years = memories.count > 0 ? (memories.map { $0.year }.max() ?? 0) - (memories.map { $0.year }.min() ?? 0) : 0

        switch viewMode {
        case .host:
            statsLabel.text = "共 \(count) 段回忆 · \(cities) 个城市 · 跨越 \(years) 年"
        case .guest:
            statsLabel.text = "公开回忆 \(count) 段 · \(cities) 个城市 · 跨越 \(years) 年"
        }
    }

    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewMemory),
            name: .djNewMemoryCreated,
            object: nil
        )
    }

    @objc private func handleNewMemory(_ notification: Notification) {
        guard let accountLease,
              AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed,
              let createdMemory = notification.object as? MemoryModel,
              createdMemory.authorId == ownerId else {
            return
        }
        print("[MemoirSync] MapFootprintVC.handleNewMemory: receive .djNewMemoryCreated, memoryId=\(createdMemory.id), thread=\(Thread.isMainThread ? "main" : "bg")")
        // 通知可能在子线程派发（如 MemoirService 的 generateQueue），地图刷新必须切回主线程
        DispatchQueue.main.async { [weak self] in
            self?.loadMemories()
        }
    }

    // MARK: - Actions
    @objc private func locateTapped() {
        guard let mapView = mapView else { return }
        if !annotations.isEmpty {
            mapView.showAnnotations(
                annotations,
                edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 100, right: 40),
                animated: true
            )
        }
    }
}

// MARK: - MAMapViewDelegate
extension MapFootprintViewController: MAMapViewDelegate {

    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        if annotation is MAUserLocation { return nil }
        guard let memoryAnnotation = annotation as? MemoryAnnotation else { return nil }

        let reuseId = "MemoryAnnotationView"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MemoryAnnotationView
        if annotationView == nil {
            annotationView = MemoryAnnotationView(annotation: memoryAnnotation, reuseIdentifier: reuseId)
        }

        // 仅当是最新一条且未被点击过时，展示 NEW 与跳动。
        let isLatest = memoryAnnotation.memory.id == memories.first?.id
        let isUnread = !readMemoryIds.contains(memoryAnnotation.memory.id)
        let isNew = isLatest && isUnread
        let isHost = viewMode == .host

        let shouldBounce = isNew && !previouslyBouncedMemoryIds.contains(memoryAnnotation.memory.id)
        if shouldBounce {
            markBounced(memoryAnnotation.memory.id)
        }

        annotationView?.configure(with: memoryAnnotation.memory,
                                  isNew: isNew,
                                  shouldBounce: shouldBounce,
                                  isHost: isHost,
                                  accountLease: isHost ? accountLease : nil)

        // 显式点击回调：标记已读 + 跳详情页（兜底 didSelect 不触发）
        annotationView?.onTap = { [weak self, weak annotationView] in
            guard let self = self else { return }
            guard self.markRead(memoryAnnotation.memory.id) else { return }
            // 让 view 层级回归，避免遮挡其他卡片
            annotationView?.layer.zPosition = 0
            // 跳详情
            self.openDetail(for: memoryAnnotation.memory)
        }

        return annotationView
    }

    /// NEW 标签的标注 view 强制前置，避免被相邻卡片覆盖
    func mapView(_ mapView: MAMapView!, didAddAnnotationViews views: [Any]!) {
        for case let view as MemoryAnnotationView in (views ?? []) {
            if view.layer.zPosition >= 1000 {
                view.superview?.bringSubviewToFront(view)
            }
        }
    }

    func mapView(_ mapView: MAMapView!, didSelect view: MAAnnotationView!) {
        guard let memoryAnnotation = view.annotation as? MemoryAnnotation else { return }
        // 取消选中态（避免 SDK 锁定 selected 状态导致下次点击不触发）
        mapView.deselectAnnotation(view.annotation, animated: false)
        // 同步标记已读 + 关闭 NEW
        guard markRead(memoryAnnotation.memory.id) else { return }
        (view as? MemoryAnnotationView)?.dismissNewBadgeAnimated()
        // 跳详情
        openDetail(for: memoryAnnotation.memory)
    }

    /// 公共跳详情入口（onTap 与 didSelect 共用）
    private func openDetail(for memory: MemoryModel) {
        guard let accountLease,
              memory.authorId == ownerId,
              AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed else {
            return
        }
        let detailViewMode: MemoryDetailViewMode = (viewMode == .host) ? .host : .guest
        print("[MemoirSync] MapFootprintVC.openDetail: id=\(memory.id), title=\(memory.title), location=\(memory.location), authorId=\(memory.authorId), images=\(memory.imageNames.count), audio=\(memory.audioName ?? "nil"), viewMode=\(detailViewMode)")
        let detailVC = MemoryDetailViewController(memory: memory, viewMode: detailViewMode)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
#endif
