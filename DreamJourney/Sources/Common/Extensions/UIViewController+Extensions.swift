import UIKit

// MARK: - UIViewController 通用扩展
extension UIViewController {

    // Toast 快捷方法
    func showToast(_ message: String, type: TGToast.ToastType = .info) {
        TGToast.show(type: type, message: message)
    }

    // 点击空白区域隐藏键盘
    func hideKeyboardWhenTapped() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // 从隐藏导航栏的一级页 push 进入时，恢复返回上一级入口
    @discardableResult
    func showPreviousLevelNavigationIfNeeded(animated: Bool) -> Bool {
        guard canReturnToPreviousLevel else { return false }
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false

        guard navigationItem.leftBarButtonItem == nil else { return true }
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left", withConfiguration: config),
            style: .plain,
            target: self,
            action: #selector(handlePreviousLevelNavigation)
        )
        item.tintColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        item.accessibilityLabel = "返回上一级"
        navigationItem.leftBarButtonItem = item
        return true
    }

    private var canReturnToPreviousLevel: Bool {
        if let nav = navigationController,
           let first = nav.viewControllers.first,
           first !== self {
            return true
        }
        return presentingViewController != nil || navigationController?.presentingViewController != nil
    }

    @objc private func handlePreviousLevelNavigation() {
        if let nav = navigationController,
           let first = nav.viewControllers.first,
           first !== self {
            nav.popViewController(animated: true)
            return
        }
        dismiss(animated: true)
    }

    // 设置导航栏透明
    func setNavigationBarTransparent(_ transparent: Bool) {
        if transparent {
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.isTranslucent = true
        } else {
            navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
            navigationController?.navigationBar.shadowImage = nil
        }
    }
}

// MARK: - UIView 通用扩展
extension UIView {
    // 快速添加圆角
    func roundCorners(_ radius: CGFloat) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }

    // 添加渐变层
    @discardableResult
    func addGradientLayer(colors: [UIColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = startPoint
        gradient.endPoint = endPoint
        gradient.frame = bounds
        layer.insertSublayer(gradient, at: 0)
        return gradient
    }
}
