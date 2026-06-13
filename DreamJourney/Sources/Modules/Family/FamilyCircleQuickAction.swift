import Foundation

enum FamilyCircleQuickActionKind: Equatable {
    case careDashboard
    case familyFootprint
}

struct FamilyCircleQuickAction: Equatable {
    let kind: FamilyCircleQuickActionKind
    let title: String
    let subtitle: String
    let iconName: String
    let accessibilityLabel: String

    static let defaultActions: [FamilyCircleQuickAction] = [
        FamilyCircleQuickAction(
            kind: .careDashboard,
            title: "长辈关怀看板",
            subtitle: "查看脱敏信号与问候建议",
            iconName: "heart.text.square",
            accessibilityLabel: "查看长辈关怀看板"
        ),
        FamilyCircleQuickAction(
            kind: .familyFootprint,
            title: "家族足迹地图",
            subtitle: "按代际点亮家族走过的世界",
            iconName: "map",
            accessibilityLabel: "查看家族足迹地图"
        )
    ]
}
