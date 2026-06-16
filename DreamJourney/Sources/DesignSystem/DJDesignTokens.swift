import UIKit

enum DJDesignTokens {
    enum Color {
        static let background = UIColor(hex: "#fff9f0")
        static let surface = UIColor(hex: "#ffffff")
        static let surfaceLow = UIColor(hex: "#f9f3ea")
        static let surfaceContainer = UIColor(hex: "#f3ede4")
        static let textPrimary = UIColor(hex: "#1d1b16")
        static let textSecondary = UIColor(hex: "#564334")
        static let textTertiary = UIColor(hex: "#897362")
        static let accent = UIColor(hex: "#ff8c00")
        static let accentDeep = UIColor(hex: "#904d00")
        static let divider = UIColor(hex: "#ddc1ae")
        static let danger = UIColor(hex: "#ba1a1a")
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let unit: CGFloat = 8
        static let page: CGFloat = 24
        static let card: CGFloat = 16
        static let section: CGFloat = 32
        static let tabBarHeight: CGFloat = 64
    }

    enum Font {
        static func display(_ size: CGFloat = 28) -> UIFont {
            .systemFont(ofSize: size, weight: .light)
        }

        static func title(_ size: CGFloat = 20) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }

        static func body(_ size: CGFloat = 15) -> UIFont {
            .systemFont(ofSize: size, weight: .regular)
        }

        static func label(_ size: CGFloat = 12) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }
    }

    static func applySoftShadow(to view: UIView) {
        view.layer.shadowColor = UIColor(hex: "#8C7B6D").cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 24
    }
}
