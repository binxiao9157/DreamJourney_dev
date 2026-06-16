import UIKit

enum DJComponentFactory {
    static func cardView(radius: CGFloat = DJDesignTokens.Radius.large) -> UIView {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.surface
        view.layer.cornerRadius = radius
        view.layer.masksToBounds = false
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }

    static func primaryButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.accent
        button.layer.cornerRadius = 22
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    static func iconButton(systemName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = DJDesignTokens.Color.textSecondary
        button.backgroundColor = DJDesignTokens.Color.surfaceLow
        button.layer.cornerRadius = 22
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    static func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.title(18)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 0
        return label
    }
}
