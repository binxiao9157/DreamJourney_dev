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
    private let includeDemoExpansionOverride: Bool?
    private var mapView: MAMapView?       // 安全可选：缺 ApiKey 等场景下为 nil，避免崩溃
    private var annotations: [MemoryAnnotation] = []
    private var footprintAnnotations: [FamilyFootprintAnnotation] = []
    private var memories: [MemoryModel] = []
    private var footprintPoints: [FamilyFootprintPoint] = []
    private var selectedGeneration: FamilyFootprintGeneration = .all
    private var selectedIlluminationScope: FootprintIlluminationScope = .nation
    private var illuminatedRegionOverlays: [MAPolygon] = []
    private var illuminatedRegionStyles: [ObjectIdentifier: FootprintIlluminationStyle] = [:]
    private var illuminationRequestSerial = 0
    private var playbackTimer: Timer?
    private var didEncounterMapLoadingFailure = false
    private let fallbackIlluminationView = FootprintIlluminationCanvasView()
    private let isFootprintPosterPreviewEnabled = false

    // 已读回忆 ID（持久化在 UserDefaults，点击后 NEW 标签不再展示）
    private static let readMemoriesKey = "dj.readMemoryIds"
    private var readMemoryIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.readMemoriesKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.readMemoriesKey) }
    }

    // 历次冷启已跳动过的回忆 ID（持久化）。
    // previousBouncedIds 在进程启动后只初始化一次（lazy static），
    // 保证：本次冷启内多次进入页面 NEW 仍跳动；下次冷启进入时不再跳动。
    private static let bouncedMemoriesKey = "dj.bouncedMemoryIds"
    private static let previousBouncedIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: bouncedMemoriesKey) ?? [])
    }()
    private func markBounced(_ id: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: Self.bouncedMemoriesKey) ?? [])
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: Self.bouncedMemoriesKey)
    }

    // 默认图：用户未上传图片时按索引循环使用 4 张内置默认图
    private static let defaultImageNames = [
        "default_memory_1", "default_memory_2",
        "default_memory_3", "default_memory_4"
    ]

    // MARK: - Init
    init(
        viewMode: FootprintViewMode = .host,
        ownerId: String,
        ownerName: String? = nil,
        includeDemoExpansionOverride: Bool? = nil
    ) {
        self.viewMode = viewMode
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.includeDemoExpansionOverride = includeDemoExpansionOverride
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        playbackTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

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

    private lazy var posterButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        b.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.backgroundColor = UIColor(hex: "#1FAEBB")
        b.layer.cornerRadius = 22
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.18
        b.layer.shadowOffset = CGSize(width: 0, height: 3)
        b.layer.shadowRadius = 8
        b.layer.masksToBounds = false
        b.isHidden = true
        b.accessibilityLabel = "生成家族足迹海报"
        b.addTarget(self, action: #selector(posterTapped), for: .touchUpInside)
        return b
    }()

    // 底部统计栏
    private lazy var statsBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.74)
        v.layer.cornerRadius = 22
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.26
        v.layer.shadowOffset = CGSize(width: 0, height: -8)
        v.layer.shadowRadius = 18
        return v
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 0
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

    private lazy var generationControl: UISegmentedControl = {
        let items = FamilyFootprintTimeline.displayGenerations.map(\.title)
        let c = UISegmentedControl(items: items)
        c.selectedSegmentIndex = 0
        c.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        c.selectedSegmentTintColor = .warmPrimary
        c.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: TGColors.textPrimary
        ], for: .normal)
        c.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.white
        ], for: .selected)
        c.addTarget(self, action: #selector(generationChanged), for: .valueChanged)
        return c
    }()

    private lazy var illuminationScopeControl: UISegmentedControl = {
        let items = FootprintIlluminationScope.allCases.map(\.title)
        let c = UISegmentedControl(items: items)
        c.selectedSegmentIndex = FootprintIlluminationScope.allCases.firstIndex(of: selectedIlluminationScope) ?? 1
        c.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        c.selectedSegmentTintColor = UIColor(hex: "#2ED6E3").withAlphaComponent(0.9)
        c.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.82)
        ], for: .normal)
        c.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.86)
        ], for: .selected)
        c.addTarget(self, action: #selector(illuminationScopeChanged), for: .valueChanged)
        return c
    }()

    private lazy var journeyCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.94)
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowOffset = CGSize(width: 0, height: 3)
        v.layer.shadowRadius = 8
        return v
    }()

    private let journeyTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.textColor = TGColors.textPrimary
        l.numberOfLines = 1
        return l
    }()

    private let journeyBodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = TGColors.textSecondary
        l.numberOfLines = 2
        return l
    }()

    private lazy var posterFallbackCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.70)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor(hex: "#55F3FF").withAlphaComponent(0.28).cgColor
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowOffset = CGSize(width: 0, height: 5)
        v.layer.shadowRadius = 12
        v.isHidden = true
        return v
    }()

    private let posterFallbackTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.textColor = .white
        l.numberOfLines = 1
        l.text = "家族足迹点亮预览"
        return l
    }()

    private let posterFallbackBodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.72)
        l.numberOfLines = 2
        l.text = "地图暂时不可用时，也能先看城市、迁徙路线和点亮区域。"
        return l
    }()

    private lazy var posterFallbackButton: UIButton = {
        let b = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "预览"
        config.image = UIImage(systemName: "photo.on.rectangle.angled")
        config.imagePadding = 5
        config.baseBackgroundColor = UIColor(hex: "#1FAEBB")
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        b.configuration = config
        b.accessibilityLabel = "预览家族足迹海报"
        b.addTarget(self, action: #selector(posterFallbackTapped), for: .touchUpInside)
        return b
    }()

    private lazy var playbackButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        b.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .warmAccent
        b.layer.cornerRadius = 18
        b.accessibilityLabel = "播放家族足迹"
        b.addTarget(self, action: #selector(playbackTapped), for: .touchUpInside)
        return b
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
            title = "\(ownerName ?? "亲属")的足迹"
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
        guard AppConfiguration.string(forKey: "AMapAPIKey") != nil else {
            mapView = nil
            mapPlaceholderLabel.text = "地图暂时不可用\n请检查网络或 AMapAPIKey 配置"
            return
        }
        let map = MAMapView(frame: view.bounds)
        map.delegate = self
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // ====== 暗色足迹底图：用卫星底图压低信息密度，再叠加家族点亮面层 ======
        map.mapType = .satellite
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
        if let mapView {
            view.insertSubview(fallbackIlluminationView, aboveSubview: mapView)
        } else {
            view.insertSubview(fallbackIlluminationView, at: 0)
        }
        view.addSubview(statsBar)
        view.addSubview(locateButton)
        view.addSubview(posterButton)
        view.addSubview(mapPlaceholderLabel)
        view.addSubview(titleLabel)
        view.addSubview(illuminationScopeControl)
        view.addSubview(generationControl)
        view.addSubview(journeyCard)
        view.addSubview(posterFallbackCard)
        statsBar.addSubview(statsLabel)
        journeyCard.addSubview(journeyTitleLabel)
        journeyCard.addSubview(journeyBodyLabel)
        journeyCard.addSubview(playbackButton)
        posterFallbackCard.addSubview(posterFallbackTitleLabel)
        posterFallbackCard.addSubview(posterFallbackBodyLabel)
        posterFallbackCard.addSubview(posterFallbackButton)

        [fallbackIlluminationView,
         statsBar, locateButton, posterButton, statsLabel, mapPlaceholderLabel, titleLabel,
         illuminationScopeControl, generationControl, journeyCard,
         journeyTitleLabel, journeyBodyLabel, playbackButton,
         posterFallbackCard, posterFallbackTitleLabel, posterFallbackBodyLabel, posterFallbackButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // 2. 再统一激活约束
        let statsBottom = statsBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
        statsBarBottomConstraint = statsBottom
        NSLayoutConstraint.activate([
            fallbackIlluminationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fallbackIlluminationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fallbackIlluminationView.topAnchor.constraint(equalTo: view.topAnchor),
            fallbackIlluminationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 顶部左上标题（host 模式可见；与"寻梦环游""亲友" Tab 完全相同的字号、间距）
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            illuminationScopeControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            illuminationScopeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            illuminationScopeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            illuminationScopeControl.heightAnchor.constraint(equalToConstant: 34),

            generationControl.topAnchor.constraint(equalTo: illuminationScopeControl.bottomAnchor, constant: 10),
            generationControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            generationControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            generationControl.heightAnchor.constraint(equalToConstant: 36),

            journeyCard.topAnchor.constraint(equalTo: generationControl.bottomAnchor, constant: 10),
            journeyCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            journeyCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            journeyCard.heightAnchor.constraint(equalToConstant: 82),

            journeyTitleLabel.topAnchor.constraint(equalTo: journeyCard.topAnchor, constant: 14),
            journeyTitleLabel.leadingAnchor.constraint(equalTo: journeyCard.leadingAnchor, constant: 16),
            journeyTitleLabel.trailingAnchor.constraint(equalTo: playbackButton.leadingAnchor, constant: -12),

            journeyBodyLabel.topAnchor.constraint(equalTo: journeyTitleLabel.bottomAnchor, constant: 6),
            journeyBodyLabel.leadingAnchor.constraint(equalTo: journeyTitleLabel.leadingAnchor),
            journeyBodyLabel.trailingAnchor.constraint(equalTo: journeyTitleLabel.trailingAnchor),

            playbackButton.centerYAnchor.constraint(equalTo: journeyCard.centerYAnchor),
            playbackButton.trailingAnchor.constraint(equalTo: journeyCard.trailingAnchor, constant: -16),
            playbackButton.widthAnchor.constraint(equalToConstant: 36),
            playbackButton.heightAnchor.constraint(equalToConstant: 36),

            posterFallbackCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            posterFallbackCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -76),
            posterFallbackCard.bottomAnchor.constraint(equalTo: statsBar.topAnchor, constant: -16),
            posterFallbackCard.heightAnchor.constraint(equalToConstant: 90),

            posterFallbackTitleLabel.topAnchor.constraint(equalTo: posterFallbackCard.topAnchor, constant: 14),
            posterFallbackTitleLabel.leadingAnchor.constraint(equalTo: posterFallbackCard.leadingAnchor, constant: 16),
            posterFallbackTitleLabel.trailingAnchor.constraint(equalTo: posterFallbackButton.leadingAnchor, constant: -12),

            posterFallbackBodyLabel.topAnchor.constraint(equalTo: posterFallbackTitleLabel.bottomAnchor, constant: 5),
            posterFallbackBodyLabel.leadingAnchor.constraint(equalTo: posterFallbackTitleLabel.leadingAnchor),
            posterFallbackBodyLabel.trailingAnchor.constraint(equalTo: posterFallbackTitleLabel.trailingAnchor),

            posterFallbackButton.centerYAnchor.constraint(equalTo: posterFallbackCard.centerYAnchor),
            posterFallbackButton.trailingAnchor.constraint(equalTo: posterFallbackCard.trailingAnchor, constant: -14),
            posterFallbackButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 76),
            posterFallbackButton.heightAnchor.constraint(equalToConstant: 34),

            // 底部统计栏（直接锚定 view.bottomAnchor，constant 由 viewDidLayoutSubviews 动态计算
            // -(56 + home indicator)，避免 hidesBottomBarWhenPushed 引起的 safeArea 污染）
            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBottom,
            statsBar.heightAnchor.constraint(equalToConstant: 118),

            statsLabel.leadingAnchor.constraint(equalTo: statsBar.leadingAnchor, constant: 22),
            statsLabel.trailingAnchor.constraint(equalTo: statsBar.trailingAnchor, constant: -22),
            statsLabel.topAnchor.constraint(equalTo: statsBar.topAnchor, constant: 18),

            // 定位按钮（依赖 statsBar，必须在 statsBar 已 addSubview 后激活）
            locateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            locateButton.bottomAnchor.constraint(equalTo: statsBar.topAnchor, constant: -16),
            locateButton.widthAnchor.constraint(equalToConstant: 44),
            locateButton.heightAnchor.constraint(equalToConstant: 44),

            posterButton.trailingAnchor.constraint(equalTo: locateButton.trailingAnchor),
            posterButton.bottomAnchor.constraint(equalTo: locateButton.topAnchor, constant: -12),
            posterButton.widthAnchor.constraint(equalToConstant: 44),
            posterButton.heightAnchor.constraint(equalToConstant: 44),

            // 地图加载失败占位提示
            mapPlaceholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mapPlaceholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mapPlaceholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            mapPlaceholderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        // 地图未成功创建时显示提示，并隐藏定位按钮
        if mapView == nil {
            fallbackIlluminationView.isHidden = false
            locateButton.isHidden = true
        }
        posterButton.isHidden = true
        posterFallbackCard.isHidden = true
        updatePosterFallbackVisibility()
    }

    // MARK: - Load Memories
    private func loadMemories() {
        var allMemories = MemoryRepository.shared.getAllByOwner(ownerId)
        // 兜底：主态登录用户 ID 与 mock 数据 user_001 不一致时，回退使用 user_001 的演示足迹
        if viewMode == .host && allMemories.isEmpty {
            allMemories = MemoryRepository.shared.getAllByOwner("user_001")
        }
        switch viewMode {
        case .host:
            memories = allMemories   // 主态：展示全部（含私密）
        case .guest:
            memories = allMemories.filter { !$0.isPrivate }  // 客态：仅展示公开
        }
        footprintPoints = FamilyFootprintTimeline.points(
            from: memories,
            ownerName: ownerName,
            includeDemoExpansion: shouldIncludeDemoExpansion
        )
        print("[MemoirSync] MapFootprintVC.loadMemories: ownerId=\(ownerId), viewMode=\(viewMode), allMemories=\(allMemories.count), memories=\(memories.count), firstId=\(memories.first?.id ?? "nil"), firstTitle=\(memories.first?.title ?? "nil")")
        updateStats()
        updateJourneyCard()
        updatePosterFallbackVisibility()
        updateIlluminationLayer()
        addAnnotations()
    }

    private func addAnnotations() {
        guard let mapView = mapView else { return }
        // 移除旧标注
        mapView.removeAnnotations(annotations)
        mapView.removeAnnotations(footprintAnnotations)
        annotations.removeAll()
        footprintAnnotations.removeAll()

        guard !selectedGeneration.usesScriptedFootprintRange else { return }

        let visiblePoints = FamilyFootprintTimeline.filtered(footprintPoints, by: selectedGeneration)
        for point in visiblePoints {
            let annotation = FamilyFootprintAnnotation(point: point)
            footprintAnnotations.append(annotation)
        }
        mapView.addAnnotations(footprintAnnotations)

        // 调整地图视野包含所有标注
        if !footprintAnnotations.isEmpty {
            mapView.showAnnotations(
                footprintAnnotations,
                edgePadding: UIEdgeInsets(top: 190, left: 40, bottom: 100, right: 40),
                animated: true
            )
        }
    }

    private func updateStats() {
        statsLabel.attributedText = FootprintIlluminationCatalog.statsText(
            scope: selectedIlluminationScope,
            points: footprintPoints,
            generation: selectedGeneration,
            isGuest: viewMode == .guest
        )
    }

    private func updateJourneyCard() {
        let summary = FamilyFootprintTimeline.journeySummary(
            for: footprintPoints,
            generation: selectedGeneration
        )
        journeyTitleLabel.text = summary.title
        journeyBodyLabel.text = "\(summary.routeText)\n\(summary.detailText) · \(summary.scaleText)"
    }

    private var shouldIncludeDemoExpansion: Bool {
        if let includeDemoExpansionOverride {
            return includeDemoExpansionOverride
        }
        guard viewMode == .host else { return false }
        return RoadshowDemoSeed.runtimeStatus().isActive || memories.contains { $0.id.hasPrefix("mem_") }
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
        let memId = (notification.object as? MemoryModel)?.id ?? "nil"
        print("[MemoirSync] MapFootprintVC.handleNewMemory: receive .djNewMemoryCreated, memoryId=\(memId), thread=\(Thread.isMainThread ? "main" : "bg")")
        // 通知可能在子线程派发（如 MemoirService 的 generateQueue），地图刷新必须切回主线程
        DispatchQueue.main.async { [weak self] in
            self?.loadMemories()
        }
    }

    // MARK: - Actions
    @objc private func locateTapped() {
        guard let mapView = mapView else { return }
        if !illuminatedRegionOverlays.isEmpty {
            mapView.showOverlays(
                illuminatedRegionOverlays,
                edgePadding: selectedIlluminationScope.edgePadding,
                animated: true
            )
            return
        }
        if !footprintAnnotations.isEmpty {
            mapView.showAnnotations(
                footprintAnnotations,
                edgePadding: UIEdgeInsets(top: 190, left: 40, bottom: 100, right: 40),
                animated: true
            )
        }
    }

    @objc private func generationChanged() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        let generations = FamilyFootprintTimeline.displayGenerations
        let index = max(0, min(generationControl.selectedSegmentIndex, generations.count - 1))
        applyGeneration(generations[index])
    }

    @objc private func illuminationScopeChanged() {
        let scopes = FootprintIlluminationScope.allCases
        let index = max(0, min(illuminationScopeControl.selectedSegmentIndex, scopes.count - 1))
        selectedIlluminationScope = scopes[index]
        updateStats()
        updateIlluminationLayer()
        addAnnotations()
    }

    @objc private func playbackTapped() {
        if playbackTimer != nil {
            playbackTimer?.invalidate()
            playbackTimer = nil
            playbackButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            return
        }

        playbackButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        applyGeneration(.ancestors)
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            let next = FamilyFootprintTimeline.nextPlaybackGeneration(after: self.selectedGeneration)
            self.applyGeneration(next)
            if next == .all {
                timer.invalidate()
                self.playbackTimer = nil
                self.playbackButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            }
        }
    }

    @objc private func posterTapped() {
        guard isFootprintPosterPreviewEnabled else { return }
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        presentFootprintPosterPreview()
    }

    @objc private func posterFallbackTapped() {
        guard isFootprintPosterPreviewEnabled else { return }
        presentFootprintPosterPreview()
    }

    private func presentFootprintPosterPreview() {
        let descriptor = FamilyFootprintSharePosterDescriptor.make(
            ownerName: ownerName ?? UserManager.shared.currentUser?.nickname,
            scope: selectedIlluminationScope,
            generation: selectedGeneration,
            allPoints: footprintPoints
        )
        guard let mapView,
              mapView.bounds.width > 1,
              mapView.bounds.height > 1,
              !didEncounterMapLoadingFailure else {
            presentFootprintPosterPreview(descriptor: descriptor, mapSnapshot: nil)
            return
        }

        mapView.takeSnapshot(in: mapView.bounds, timeoutInterval: 1.5) { [weak self] image, state in
            DispatchQueue.main.async {
                self?.presentFootprintPosterPreview(
                    descriptor: descriptor,
                    mapSnapshot: state == 1 ? image : nil
                )
            }
        }
    }

    private func presentFootprintPosterPreview(
        descriptor: FamilyFootprintSharePosterDescriptor,
        mapSnapshot: UIImage?
    ) {
        let image = FamilyFootprintSharePosterRenderer.render(
            descriptor: descriptor,
            mapSnapshot: mapSnapshot
        )
        let preview = FamilyFootprintSharePosterPreviewViewController(image: image, descriptor: descriptor)
        preview.title = "足迹海报"
        navigationController?.pushViewController(preview, animated: true)
    }

    private func updatePosterFallbackVisibility() {
        posterButton.isHidden = true
        posterFallbackCard.isHidden = true
        if mapView == nil || didEncounterMapLoadingFailure || AppConfiguration.string(forKey: "AMapAPIKey") == nil {
            mapPlaceholderLabel.isHidden = true
            fallbackIlluminationView.isHidden = false
            locateButton.isHidden = true
        } else {
            fallbackIlluminationView.isHidden = true
            locateButton.isHidden = false
        }
    }

    private func applyGeneration(_ generation: FamilyFootprintGeneration) {
        selectedGeneration = generation
        if let index = FamilyFootprintTimeline.displayGenerations.firstIndex(of: generation) {
            generationControl.selectedSegmentIndex = index
        }
        updateStats()
        updateJourneyCard()
        updateIlluminationLayer()
        addAnnotations()
    }

    private func updateIlluminationLayer() {
        let visiblePoints = FamilyFootprintTimeline.filtered(footprintPoints, by: selectedGeneration)
        let pointsForRender = selectedGeneration.usesScriptedFootprintRange
            ? []
            : (visiblePoints.isEmpty ? footprintPoints : visiblePoints)
        illuminationRequestSerial += 1
        let requestSerial = illuminationRequestSerial

        guard let mapView, !didEncounterMapLoadingFailure else {
            fallbackIlluminationView.render(
                regions: [],
                points: pointsForRender,
                scope: selectedIlluminationScope,
                generation: selectedGeneration,
                isLoading: shouldPreferAmapDistrictBoundary
            )
            requestAmapIlluminationRegions(
                scope: selectedIlluminationScope,
                generation: selectedGeneration,
                points: pointsForRender,
                requestSerial: requestSerial,
                fallbackToLocal: true
            )
            return
        }

        if shouldPreferAmapDistrictBoundary {
            clearIlluminationRegions(on: mapView)
            requestAmapIlluminationRegions(
                scope: selectedIlluminationScope,
                generation: selectedGeneration,
                points: pointsForRender,
                requestSerial: requestSerial,
                fallbackToLocal: true
            )
            return
        }

        let localRegions = FootprintIlluminationCatalog.regions(
            scope: selectedIlluminationScope,
            points: pointsForRender,
            generation: selectedGeneration
        )
        renderIlluminationRegions(localRegions, on: mapView)
        requestAmapIlluminationRegions(
            scope: selectedIlluminationScope,
            generation: selectedGeneration,
            points: pointsForRender,
            requestSerial: requestSerial,
            fallbackToLocal: false
        )
    }

    private var shouldPreferAmapDistrictBoundary: Bool {
        AppConfiguration.string(forKey: "AMapWebServiceKey") != nil
    }

    private func clearIlluminationRegions(on mapView: MAMapView) {
        if !illuminatedRegionOverlays.isEmpty {
            mapView.removeOverlays(illuminatedRegionOverlays)
        }
        illuminatedRegionOverlays.removeAll()
        illuminatedRegionStyles.removeAll()
    }

    private func renderIlluminationRegions(
        _ regions: [FootprintIlluminationRegion],
        on mapView: MAMapView
    ) {
        clearIlluminationRegions(on: mapView)

        for region in regions {
            for overlaySpec in region.overlaySpecs {
                var coordinates = overlaySpec.coordinates
                guard coordinates.count >= 3,
                      let polygon = MAPolygon(coordinates: &coordinates, count: UInt(coordinates.count)) else {
                    continue
                }
                illuminatedRegionOverlays.append(polygon)
                illuminatedRegionStyles[ObjectIdentifier(polygon)] = overlaySpec.style
            }
        }

        guard !illuminatedRegionOverlays.isEmpty else { return }
        mapView.addOverlays(illuminatedRegionOverlays, level: .aboveLabels)
        mapView.showOverlays(
            illuminatedRegionOverlays,
            edgePadding: selectedIlluminationScope.edgePadding,
            animated: true
        )
    }

    private func requestAmapIlluminationRegions(
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        points: [FamilyFootprintPoint],
        requestSerial: Int,
        fallbackToLocal: Bool
    ) {
        guard AppConfiguration.string(forKey: "AMapWebServiceKey") != nil
            || AppConfiguration.string(forKey: "AMapAPIKey") != nil else {
            return
        }

        Task { [weak self] in
            let regions = await AmapDistrictBoundaryProvider.shared.regions(
                scope: scope,
                points: points,
                generation: generation
            )
            await MainActor.run { [weak self] in
                guard let self,
                      self.illuminationRequestSerial == requestSerial,
                      self.selectedIlluminationScope == scope,
                      self.selectedGeneration == generation else {
                    return
                }
                let completedRegions = self.completedIlluminationRegions(
                    regions,
                    scope: scope,
                    generation: generation,
                    points: points
                )

                if completedRegions.isEmpty {
                    guard fallbackToLocal else { return }
                    let localRegions = FootprintIlluminationCatalog.regions(
                        scope: scope,
                        points: points,
                        generation: generation
                    )
                    if let mapView = self.mapView, !self.didEncounterMapLoadingFailure {
                        self.renderIlluminationRegions(localRegions, on: mapView)
                    } else {
                        self.fallbackIlluminationView.render(
                            regions: localRegions,
                            points: points,
                            scope: scope,
                            generation: generation,
                            isLoading: false
                        )
                    }
                    return
                }
                if let mapView = self.mapView, !self.didEncounterMapLoadingFailure {
                    self.renderIlluminationRegions(completedRegions, on: mapView)
                } else {
                    self.fallbackIlluminationView.render(
                        regions: completedRegions,
                        points: points,
                        scope: scope,
                        generation: generation,
                        isLoading: false
                    )
                }
            }
        }
    }

    private func completedIlluminationRegions(
        _ remoteRegions: [FootprintIlluminationRegion],
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        points: [FamilyFootprintPoint]
    ) -> [FootprintIlluminationRegion] {
        guard generation.usesScriptedFootprintRange else {
            return remoteRegions
        }

        let localRegions = FootprintIlluminationCatalog.regions(
            scope: scope,
            points: points,
            generation: generation
        )
        guard !remoteRegions.isEmpty else { return localRegions }

        var completed = remoteRegions
        var existingNames = Set(remoteRegions.map { canonicalRegionName($0.name) })
        for region in localRegions {
            let name = canonicalRegionName(region.name)
            guard !existingNames.contains(name) else { continue }
            completed.append(region)
            existingNames.insert(name)
        }
        return completed
    }

    private func canonicalRegionName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "区", with: "")
            .replacingOccurrences(of: "县", with: "")
            .replacingOccurrences(of: "特别行政", with: "")
    }
}

private final class FootprintIlluminationCanvasView: UIView {
    private var regions: [FootprintIlluminationRegion] = []
    private var points: [FamilyFootprintPoint] = []
    private var scope: FootprintIlluminationScope = .nation
    private var generation: FamilyFootprintGeneration = .all
    private var isLoading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: "#061A1E")
        isOpaque = true
        isHidden = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(
        regions: [FootprintIlluminationRegion],
        points: [FamilyFootprintPoint],
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        isLoading: Bool
    ) {
        self.regions = regions
        self.points = points
        self.scope = scope
        self.generation = generation
        self.isLoading = isLoading
        isHidden = false
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        drawBackground(in: context, rect: rect)

        let mapRect = visibleMapRect(in: rect)
        drawGrid(in: context, rect: mapRect)

        let visiblePoints = FamilyFootprintTimeline.filtered(points, by: generation)
        let renderPoints = generation.usesScriptedFootprintRange
            ? []
            : (visiblePoints.isEmpty ? points : visiblePoints)
        let bounds = coordinateBounds(regions: regions, points: renderPoints)

        context.saveGState()
        let clipPath = UIBezierPath(roundedRect: mapRect, cornerRadius: 24)
        clipPath.addClip()
        drawRoute(in: context, rect: mapRect, points: renderPoints, bounds: bounds)
        drawRegions(in: context, rect: mapRect, bounds: bounds)
        drawPoints(in: context, rect: mapRect, points: renderPoints, bounds: bounds)
        context.restoreGState()

        drawCaption(in: mapRect)
    }

    private func visibleMapRect(in rect: CGRect) -> CGRect {
        let top = max(190, safeAreaInsets.top + 160)
        let bottom: CGFloat = 190
        let height = max(260, rect.height - top - bottom)
        return CGRect(x: 24, y: top, width: rect.width - 48, height: height)
    }

    private func drawBackground(in context: CGContext, rect: CGRect) {
        let colors = [
            UIColor(hex: "#07171B").cgColor,
            UIColor(hex: "#0B2C31").cgColor,
            UIColor(hex: "#07171B").cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.48, 1]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
        }
    }

    private func drawGrid(in context: CGContext, rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 24)
        UIColor(hex: "#0B3438").withAlphaComponent(0.72).setFill()
        path.fill()

        context.setStrokeColor(UIColor(hex: "#23575C").withAlphaComponent(0.20).cgColor)
        context.setLineWidth(0.6)
        for step in 1..<6 {
            let x = rect.minX + rect.width * CGFloat(step) / 6
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for step in 1..<6 {
            let y = rect.minY + rect.height * CGFloat(step) / 6
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        context.strokePath()
    }

    private func drawRegions(
        in context: CGContext,
        rect: CGRect,
        bounds: CoordinateBounds
    ) {
        for region in regions {
            for overlay in region.overlaySpecs where overlay.coordinates.count >= 3 {
                let path = UIBezierPath()
                for (index, coordinate) in overlay.coordinates.enumerated() {
                    let point = project(coordinate, in: rect, bounds: bounds)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.close()

                context.saveGState()
                context.setShadow(
                    offset: .zero,
                    blur: 12,
                    color: UIColor(hex: "#55F3FF").withAlphaComponent(0.42).cgColor
                )
                overlay.style.fillColor.setFill()
                path.fill()
                context.restoreGState()

                overlay.style.strokeColor.setStroke()
                path.lineWidth = max(1.0, overlay.style.lineWidth)
                path.stroke()
            }

            let center = project(region.center, in: rect, bounds: bounds)
            drawRegionLabel(region.name, at: center)
        }
    }

    private func drawRoute(
        in context: CGContext,
        rect: CGRect,
        points: [FamilyFootprintPoint],
        bounds: CoordinateBounds
    ) {
        let sorted = points.sorted { $0.year < $1.year }
        guard sorted.count >= 2 else { return }

        let route = UIBezierPath()
        for (index, point) in sorted.enumerated() {
            let projected = project(
                CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                in: rect,
                bounds: bounds
            )
            if index == 0 {
                route.move(to: projected)
            } else {
                route.addLine(to: projected)
            }
        }
        UIColor(hex: "#8AFBFF").withAlphaComponent(0.48).setStroke()
        route.lineWidth = 2
        route.stroke()
    }

    private func drawPoints(
        in context: CGContext,
        rect: CGRect,
        points: [FamilyFootprintPoint],
        bounds: CoordinateBounds
    ) {
        for point in points {
            let center = project(
                CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                in: rect,
                bounds: bounds
            )
            context.saveGState()
            context.setShadow(
                offset: .zero,
                blur: 10,
                color: point.generation.tintColor.withAlphaComponent(0.50).cgColor
            )
            point.generation.tintColor.withAlphaComponent(0.92).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)).fill()
            context.restoreGState()
        }
    }

    private func drawCaption(in rect: CGRect) {
        let title: String
        if regions.isEmpty {
            title = isLoading ? "正在拉取高德行政区边界..." : "行政区点亮准备中"
        } else {
            title = "\(scope.title)行政区点亮 · \(regions.count) 个区域"
        }
        let subtitle = "使用高德 WebService 边界自绘，优先保证足迹点亮效果"
        drawText(
            title,
            at: CGPoint(x: rect.minX + 16, y: rect.minY + 16),
            font: .systemFont(ofSize: 15, weight: .bold),
            color: .white
        )
        drawText(
            subtitle,
            at: CGPoint(x: rect.minX + 16, y: rect.minY + 40),
            font: .systemFont(ofSize: 11, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.64)
        )
    }

    private func drawRegionLabel(_ text: String, at point: CGPoint) {
        let font = UIFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let bubble = CGRect(
            x: point.x - size.width / 2 - 8,
            y: point.y - size.height / 2 - 5,
            width: size.width + 16,
            height: size.height + 10
        )
        UIColor(hex: "#0B2F33").withAlphaComponent(0.72).setFill()
        UIBezierPath(roundedRect: bubble, cornerRadius: bubble.height / 2).fill()
        (text as NSString).draw(
            at: CGPoint(x: bubble.minX + 8, y: bubble.minY + 5),
            withAttributes: attrs
        )
    }

    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    private func coordinateBounds(
        regions: [FootprintIlluminationRegion],
        points: [FamilyFootprintPoint]
    ) -> CoordinateBounds {
        let regionCoordinates = regions.flatMap { region in
            [region.center] + region.overlaySpecs.flatMap(\.coordinates)
        }
        let pointCoordinates = points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let coordinates = regionCoordinates + pointCoordinates
        guard !coordinates.isEmpty else {
            return CoordinateBounds(minLat: 18, maxLat: 54, minLon: 73, maxLon: 135)
        }
        let minLat = coordinates.map(\.latitude).min() ?? 18
        let maxLat = coordinates.map(\.latitude).max() ?? 54
        let minLon = coordinates.map(\.longitude).min() ?? 73
        let maxLon = coordinates.map(\.longitude).max() ?? 135
        let latPad = max(0.08, (maxLat - minLat) * 0.16)
        let lonPad = max(0.08, (maxLon - minLon) * 0.16)
        return CoordinateBounds(
            minLat: minLat - latPad,
            maxLat: maxLat + latPad,
            minLon: minLon - lonPad,
            maxLon: maxLon + lonPad
        )
    }

    private func project(
        _ coordinate: CLLocationCoordinate2D,
        in rect: CGRect,
        bounds: CoordinateBounds
    ) -> CGPoint {
        let lonSpan = max(0.0001, bounds.maxLon - bounds.minLon)
        let latSpan = max(0.0001, bounds.maxLat - bounds.minLat)
        let x = rect.minX + CGFloat((coordinate.longitude - bounds.minLon) / lonSpan) * rect.width
        let y = rect.maxY - CGFloat((coordinate.latitude - bounds.minLat) / latSpan) * rect.height
        return CGPoint(x: x, y: y)
    }

    private struct CoordinateBounds {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
    }
}

// MARK: - MAMapViewDelegate
extension MapFootprintViewController: MAMapViewDelegate {

    func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
        guard let polygon = overlay as? MAPolygon,
              let renderer = MAPolygonRenderer(polygon: polygon) else {
            return nil
        }
        let style = illuminatedRegionStyles[ObjectIdentifier(polygon)] ?? .cityFill
        renderer.fillColor = style.fillColor
        renderer.strokeColor = style.strokeColor
        renderer.lineWidth = style.lineWidth
        return renderer
    }

    func mapViewDidFinishLoadingMap(_ mapView: MAMapView!) {
        didEncounterMapLoadingFailure = false
        mapView.isHidden = false
        updatePosterFallbackVisibility()
        updateIlluminationLayer()
    }

    func mapViewDidFailLoadingMap(_ mapView: MAMapView!, withError error: Error!) {
        didEncounterMapLoadingFailure = true
        mapView.isHidden = true
        mapPlaceholderLabel.text = "正在使用行政区点亮模式"
        updatePosterFallbackVisibility()
        updateIlluminationLayer()
    }

    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        if annotation is MAUserLocation { return nil }
        if let footprintAnnotation = annotation as? FamilyFootprintAnnotation {
            let reuseId = "FamilyFootprintAnnotationView"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? FamilyFootprintAnnotationView
            if annotationView == nil {
                annotationView = FamilyFootprintAnnotationView(annotation: footprintAnnotation, reuseIdentifier: reuseId)
            }
            annotationView?.configure(with: footprintAnnotation.point)
            annotationView?.onTap = { [weak self] in
                self?.openFootprintPoint(footprintAnnotation.point)
            }
            return annotationView
        }
        guard let memoryAnnotation = annotation as? MemoryAnnotation else { return nil }

        let reuseId = "MemoryAnnotationView"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MemoryAnnotationView
        if annotationView == nil {
            annotationView = MemoryAnnotationView(annotation: memoryAnnotation, reuseIdentifier: reuseId)
        }

        // 仅当：是最新一条 + 未被点击过 + 不是 mock 数据时，才展示 NEW 与跳动
        // mock 数据 (id 以 "mem_" 开头) 的 createdAt 在 seed 时几乎同时，排序不稳定，
        // 不能把"恰好排在第一位的 mock"当作 NEW；NEW 只对用户真实新生成的回忆生效。
        let isMock = memoryAnnotation.memory.id.hasPrefix("mem_")
        let isLatest = memoryAnnotation.memory.id == memories.first?.id
        let isUnread = !readMemoryIds.contains(memoryAnnotation.memory.id)
        let isNew = !isMock && isLatest && isUnread
        let isHost = viewMode == .host

        // 默认图：按 memories 中的索引循环使用 4 张内置默认图（用户未上传图时使用）
        let idx = memories.firstIndex(where: { $0.id == memoryAnnotation.memory.id }) ?? 0
        let fallbackImage = Self.defaultImageNames[idx % Self.defaultImageNames.count]

        // 跳动条件：本次冷启首次曝光的 NEW 才跳动；下次冷启时该 ID 已在 previousBouncedIds → 不再跳
        let shouldBounce = isNew && !MapFootprintViewController.previousBouncedIds.contains(memoryAnnotation.memory.id)
        if shouldBounce {
            markBounced(memoryAnnotation.memory.id)
        }

        annotationView?.configure(with: memoryAnnotation.memory,
                                  isNew: isNew,
                                  shouldBounce: shouldBounce,
                                  isHost: isHost,
                                  fallbackImageName: fallbackImage)

        // 显式点击回调：标记已读 + 跳详情页（兜底 didSelect 不触发）
        annotationView?.onTap = { [weak self, weak annotationView] in
            guard let self = self else { return }
            // 标记已读
            var ids = self.readMemoryIds
            ids.insert(memoryAnnotation.memory.id)
            self.readMemoryIds = ids
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
        for case let view as FamilyFootprintAnnotationView in (views ?? []) {
            if view.layer.zPosition >= 500 {
                view.superview?.bringSubviewToFront(view)
            }
        }
    }

    func mapView(_ mapView: MAMapView!, didSelect view: MAAnnotationView!) {
        if let footprintAnnotation = view.annotation as? FamilyFootprintAnnotation {
            mapView.deselectAnnotation(view.annotation, animated: false)
            openFootprintPoint(footprintAnnotation.point)
            return
        }
        guard let memoryAnnotation = view.annotation as? MemoryAnnotation else { return }
        // 取消选中态（避免 SDK 锁定 selected 状态导致下次点击不触发）
        mapView.deselectAnnotation(view.annotation, animated: false)
        // 同步标记已读 + 关闭 NEW
        var ids = readMemoryIds
        ids.insert(memoryAnnotation.memory.id)
        readMemoryIds = ids
        (view as? MemoryAnnotationView)?.dismissNewBadgeAnimated()
        // 跳详情
        openDetail(for: memoryAnnotation.memory)
    }

    /// 公共跳详情入口（onTap 与 didSelect 共用）
    private func openDetail(for memory: MemoryModel) {
        let detailViewMode: MemoryDetailViewMode = (viewMode == .host) ? .host : .guest
        print("[MemoirSync] MapFootprintVC.openDetail: id=\(memory.id), title=\(memory.title), location=\(memory.location), authorId=\(memory.authorId), images=\(memory.imageNames.count), audio=\(memory.audioName ?? "nil"), viewMode=\(detailViewMode)")
        let detailVC = MemoryDetailViewController(memory: memory, viewMode: detailViewMode)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func openFootprintPoint(_ point: FamilyFootprintPoint) {
        if let memoryId = point.sourceMemoryId,
           let memory = memories.first(where: { $0.id == memoryId }) {
            var ids = readMemoryIds
            ids.insert(memory.id)
            readMemoryIds = ids
            openDetail(for: memory)
            return
        }

        let message = "\(point.timeText) · \(point.generation.title) · \(point.ownerName)\n\n\(point.subtitle)"
        let alert = UIAlertController(title: point.location, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

private final class FamilyFootprintAnnotation: MAPointAnnotation {
    let point: FamilyFootprintPoint

    init(point: FamilyFootprintPoint) {
        self.point = point
        super.init()
        coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        title = point.location
        subtitle = "\(point.year) · \(point.generation.title)"
    }
}

private final class FamilyFootprintAnnotationView: MAAnnotationView {
    private let dotSize: CGFloat = 34
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let dotView = UIView()
    private let ringView = UIView()
    private let iconLabel = UILabel()

    var onTap: (() -> Void)?

    override init!(annotation: MAAnnotation!, reuseIdentifier: String!) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with point: FamilyFootprintPoint) {
        titleLabel.text = point.location
        metaLabel.text = "\(point.year) · \(point.generation.title)"
        let color = point.generation.tintColor
        dotView.backgroundColor = color
        ringView.layer.borderColor = color.withAlphaComponent(0.36).cgColor
        iconLabel.text = point.generation.iconText
        cardView.layer.borderColor = point.isPrivate ? UIColor(hex: "#d9d9d9").cgColor : UIColor.clear.cgColor
        cardView.layer.borderWidth = point.isPrivate ? 1 : 0
        layer.zPosition = point.generation.sortOrder == 4 ? 600 : 500
        accessibilityLabel = "\(point.location)，\(point.year)年，\(point.generation.title)"
    }

    private func setupUI() {
        backgroundColor = .clear
        canShowCallout = false
        frame = CGRect(x: 0, y: 0, width: 132, height: 72)
        centerOffset = CGPoint(x: 0, y: -36)

        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.14
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cardView.layer.shadowRadius = 7

        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = TGColors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        metaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        metaLabel.textColor = TGColors.textSecondary

        ringView.backgroundColor = .clear
        ringView.layer.cornerRadius = dotSize / 2
        ringView.layer.borderWidth = 4

        dotView.layer.cornerRadius = 12

        iconLabel.font = .systemFont(ofSize: 12, weight: .bold)
        iconLabel.textAlignment = .center
        iconLabel.textColor = .white

        addSubview(cardView)
        cardView.addSubview(ringView)
        cardView.addSubview(dotView)
        cardView.addSubview(iconLabel)
        cardView.addSubview(titleLabel)
        cardView.addSubview(metaLabel)

        [cardView, ringView, dotView, iconLabel, titleLabel, metaLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.heightAnchor.constraint(equalToConstant: 58),

            ringView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            ringView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            ringView.widthAnchor.constraint(equalToConstant: dotSize),
            ringView.heightAnchor.constraint(equalToConstant: dotSize),

            dotView.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            dotView.centerYAnchor.constraint(equalTo: ringView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 24),
            dotView.heightAnchor.constraint(equalToConstant: 24),

            iconLabel.centerXAnchor.constraint(equalTo: dotView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: dotView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 11),

            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])
    }

    @objc private func handleTap() {
        onTap?()
    }
}

private extension FamilyFootprintGeneration {
    var tintColor: UIColor {
        switch self {
        case .all: return .warmAccent
        case .ancestors: return UIColor(hex: "#8B5E3C")
        case .parents: return UIColor(hex: "#2F80A8")
        case .current: return UIColor(hex: "#4E8F57")
        case .next: return UIColor(hex: "#9B5DB7")
        }
    }

    var iconText: String {
        switch self {
        case .all: return "家"
        case .ancestors: return "祖"
        case .parents: return "父"
        case .current: return "今"
        case .next: return "远"
        }
    }
}
