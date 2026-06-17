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
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = attributedTitle(title, font: DJDesignTokens.Font.label(15))
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = DJDesignTokens.Color.accent
        configuration.background.cornerRadius = 22
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        button.configuration = configuration
        button.layer.cornerRadius = 22
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    static func iconButton(systemName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemName, withConfiguration: symbolConfiguration)
        configuration.baseForegroundColor = DJDesignTokens.Color.textSecondary
        configuration.background.backgroundColor = DJDesignTokens.Color.surfaceLow
        configuration.background.cornerRadius = 22
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        button.configuration = configuration
        button.tintColor = DJDesignTokens.Color.textSecondary
        button.layer.cornerRadius = 22
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

    private static func attributedTitle(_ title: String, font: UIFont) -> AttributedString {
        var attributedTitle = AttributedString(title)
        attributedTitle.font = font
        return attributedTitle
    }
}
