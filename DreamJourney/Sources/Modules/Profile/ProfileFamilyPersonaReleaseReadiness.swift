import Foundation

enum ProfileFamilyPersonaReleaseReadiness {
    enum Stage: Equatable {
        case hiddenReady(feature: DJFeature, qaLaunchArgument: String, reason: String)
    }

    struct Capability: Equatable {
        let title: String
        let feature: DJFeature
        let stage: Stage
        let releaseCopy: String
    }

    static let hiddenBranchesLaunchArgument = "DJEnableProfileHiddenBranches"
    static let unavailableTitle = "家人管理暂未开放"
    static let unavailableMessage = "当前版本先保留入口，完整家人空间会在后续版本开放。"

    static let familyManagementCapability = Capability(
        title: "家人管理",
        feature: .familyManagement,
        stage: .hiddenReady(
            feature: .familyManagement,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "默认发布态不展示家人管理，避免误承诺邀请、权限、成员管理和家族空间能力。"
        ),
        releaseCopy: unavailableTitle
    )

    static let familySpaceCapability = Capability(
        title: "数字人切换",
        feature: .familySpace,
        stage: .hiddenReady(
            feature: .familySpace,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "人格切换已可用于内部 QA，但公开前仍需要家人授权、访问控制和真机验收。"
        ),
        releaseCopy: unavailableTitle
    )

    static func isFamilyManagementRowVisible(
        isFamilyManagementEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isFamilyManagementEnabled
    }

    static func canOpenFamilyPersonaSwitcher(
        isFamilySpaceEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isFamilySpaceEnabled
    }
}
