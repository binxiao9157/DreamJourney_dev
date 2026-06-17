import UIKit

// MARK: - WarmTabBarController
// Warm Vintage 自定义 TabBar，隐藏系统 TabBar，使用自定义 WarmTabBarView
final class WarmTabBarController: UITabBarController, UINavigationControllerDelegate {

    // MARK: - Properties
    private let warmTabBar: WarmTabBarView

    init(items: [WarmTabBarView.TabItem] = WarmTabBarView.defaultItems) {
        self.warmTabBar = WarmTabBarView(items: items)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // 隐藏系统 TabBar
        suppressSystemTabBar()
        // ⚠️ 不在此处统一设置 additionalSafeAreaInsets.bottom：
        // 当 child 是 UINavigationController 嵌 VC 时，这里的设置传播到孙级 VC 时机不稳定，
        // 会导致首次进入 child VC 的 safeArea bottom 为 0，UI 被 TabBar 遮挡。
        // 改为每个 child VC（AIRecording / Map.host / FamilyCircle）自行设置 56pt 底部 inset。
        setupWarmTabBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        suppressSystemTabBar()
        attachNavigationDelegatesIfNeeded()
        let safeBottom = view.safeAreaInsets.bottom
        let horizontalInset: CGFloat = DJDesignTokens.Spacing.page
        let bottomInset: CGFloat = 16 + safeBottom
        let barHeight: CGFloat = WarmTabBarView.tabBarHeight
        warmTabBar.frame = CGRect(
            x: horizontalInset,
            y: view.bounds.height - bottomInset - barHeight,
            width: view.bounds.width - horizontalInset * 2,
            height: barHeight
        )
        // ⚠️ 关键：UITabBarController 切换 child VC 时会把 child view 加到顶层，
        // 必须每次布局后把自定义 TabBar 提到最前，否则按钮会被 child 遮挡导致点击无效。
        updateWarmTabBarVisibility()
    }

    // MARK: - UITabBarControllerDelegate
    // 切换 tab 后立即把自定义 TabBar 提到最前（双保险）
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        suppressSystemTabBar()
        attachNavigationDelegatesIfNeeded()
        updateWarmTabBarVisibility()
    }

    // MARK: - Setup
    private func setupWarmTabBar() {
        view.addSubview(warmTabBar)
        warmTabBar.onTabSelected = { [weak self] index in
            guard let self = self else { return }
            self.selectedIndex = index
            self.warmTabBar.updateSelection(index)
            // 切换后强制把 TabBar 提到最前（child VC view 会被 UIKit 重新加到顶层）
            self.updateWarmTabBarVisibility()
        }
    }

    // MARK: - Override selectedIndex
    override var selectedIndex: Int {
        didSet {
            suppressSystemTabBar()
            warmTabBar.updateSelection(selectedIndex)
            updateWarmTabBarVisibility()
        }
    }

    private func suppressSystemTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.isUserInteractionEnabled = false
        tabBar.accessibilityElementsHidden = true
        tabBar.subviews.forEach { subview in
            subview.isHidden = true
            subview.alpha = 0
            subview.isUserInteractionEnabled = false
            subview.accessibilityElementsHidden = true
        }
    }

    // MARK: - UINavigationControllerDelegate
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard navigationController === selectedViewController else { return }
        updateWarmTabBarVisibility(for: viewController, animated: animated)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard navigationController === selectedViewController else { return }
        updateWarmTabBarVisibility(for: viewController, animated: false)
    }

    private func attachNavigationDelegatesIfNeeded() {
        viewControllers?
            .compactMap { $0 as? UINavigationController }
            .forEach { navigationController in
                if navigationController.delegate == nil || navigationController.delegate === self {
                    navigationController.delegate = self
                }
            }
    }

    private func updateWarmTabBarVisibility(for viewController: UIViewController? = nil, animated: Bool = false) {
        let selectedNavigationController = selectedViewController as? UINavigationController
        let activeViewController = viewController
            ?? selectedNavigationController?.topViewController
            ?? selectedViewController
        let shouldHide = activeViewController?.hidesBottomBarWhenPushed == true
            && (selectedNavigationController?.viewControllers.count ?? 1) > 1

        let changes = { [weak self] in
            guard let self = self else { return }
            self.warmTabBar.alpha = shouldHide ? 0 : 1
            self.warmTabBar.isHidden = shouldHide
            if !shouldHide {
                self.view.bringSubviewToFront(self.warmTabBar)
            }
        }

        if animated {
            if !shouldHide {
                warmTabBar.isHidden = false
            }
            UIView.animate(withDuration: 0.18, animations: changes)
        } else {
            changes()
        }
    }
}

// MARK: - WarmTabBarView
// 自定义 TabBar 视图：注入式 Tab 按钮 + 深棕/米白配色
final class WarmTabBarView: UIView {

    /// WarmTabBar 内容区域固定高度（不含 home indicator）
    static let tabBarHeight: CGFloat = DJDesignTokens.Spacing.tabBarHeight

    struct TabItem {
        let iconName: String        // SF Symbol 名称（未选态）
        let iconNameFill: String    // SF Symbol 名称（选中态，filled）
        let title: String
    }

    static let defaultItems: [TabItem] = [
        TabItem(iconName: "folder", iconNameFill: "folder.fill", title: "记忆档案"),
        TabItem(iconName: "building.columns", iconNameFill: "building.columns.fill", title: "回响"),
        TabItem(iconName: "person", iconNameFill: "person.fill", title: "我的"),
    ]

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    private let items: [TabItem]
    private var buttons: [UIButton] = []
    private var selectedCircles: [UIView] = []
    var onTabSelected: ((Int) -> Void)?

    // MARK: - Init
    init(items: [TabItem] = WarmTabBarView.defaultItems) {
        self.items = items
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setupView() {
        backgroundColor = .clear
        layer.cornerRadius = Self.tabBarHeight / 2
        layer.borderWidth = 1
        layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.32).cgColor
        layer.shadowColor = UIColor(hex: "#8C7B6D").cgColor
        layer.shadowOpacity = 0.055
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 14
        clipsToBounds = false

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.backgroundColor = DJDesignTokens.Color.background.withAlphaComponent(0.38)
        blurView.layer.cornerRadius = Self.tabBarHeight / 2
        blurView.layer.masksToBounds = true
        addSubview(blurView)

        // 创建三个 Tab 按钮
        for (index, item) in items.enumerated() {
            let circle = makeCircleView()
            selectedCircles.append(circle)

            let btn = makeTabButton(item: item, tag: index)
            buttons.append(btn)

            addSubview(circle)
            addSubview(btn)
        }

        updateSelection(0)
    }

    private func makeCircleView() -> UIView {
        let v = UIView()
        v.backgroundColor = .warmPrimary
        v.layer.cornerRadius = 18
        v.isUserInteractionEnabled = false
        v.alpha = 0
        return v
    }

    private func makeTabButton(item: TabItem, tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()

        let tabWidth = bounds.width / CGFloat(items.count)
        let tabAreaHeight = bounds.height

        for (index, btn) in buttons.enumerated() {
            let x = tabWidth * CGFloat(index)
            btn.frame = CGRect(x: x, y: 0, width: tabWidth, height: tabAreaHeight)

            // 选中圆背景（36×36）
            let circle = selectedCircles[index]
            let circleSize: CGFloat = 36
            circle.frame = CGRect(
                x: x + (tabWidth - circleSize) / 2,
                y: (tabAreaHeight - circleSize) / 2,
                width: circleSize,
                height: circleSize
            )
            circle.layer.cornerRadius = circleSize / 2
        }
    }

    private func updateShadowPath() {
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.tabBarHeight / 2).cgPath
    }

    // MARK: - Update Selection
    func updateSelection(_ index: Int) {
        for (i, btn) in buttons.enumerated() {
            let isSelected = (i == index)
            let item = items[i]
            let circle = selectedCircles[i]

            UIView.animate(withDuration: 0.2) {
                circle.alpha = 0  // 始终隐藏圆圈背景
            }

            // 重新构建按钮内容
            configureButton(btn, item: item, isSelected: isSelected)
        }
    }

    private func configureButton(_ btn: UIButton, item: TabItem, isSelected: Bool) {
        btn.subviews.forEach { if $0 is UILabel || $0 is UIImageView { $0.removeFromSuperview() } }

        let iconName = isSelected ? item.iconNameFill : item.iconName
        let iconColor: UIColor = isSelected ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.textTertiary.withAlphaComponent(0.65)
        let titleColor: UIColor = isSelected ? DJDesignTokens.Color.accentDeep : DJDesignTokens.Color.textTertiary.withAlphaComponent(0.65)
        let titleFont: UIFont = DJDesignTokens.Font.label(12)

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .semibold : .regular)
        let iconImage = UIImage(systemName: iconName, withConfiguration: config)

        let iconView = UIImageView(image: iconImage)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.textAlignment = .center

        btn.addSubview(iconView)
        btn.addSubview(titleLabel)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: btn.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 23),
            iconView.heightAnchor.constraint(equalToConstant: 23),

            titleLabel.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 3),
        ])
    }

    // MARK: - Actions
    @objc private func tabTapped(_ sender: UIButton) {
        onTabSelected?(sender.tag)
    }
}
