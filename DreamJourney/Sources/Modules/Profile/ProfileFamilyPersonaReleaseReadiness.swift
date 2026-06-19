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
    static let voiceCloneUnavailableTitle = "声音克隆暂未开放"
    static let voiceCloneUnavailableMessage = "当前版本先保留声音授权、voiceProfileId、样本状态和删除/禁用合同，真实声音克隆需要完成授权、样本质量和合规验收后开放。"

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

    static let passwordChangeCapability = Capability(
        title: "修改密码",
        feature: .accountPasswordChange,
        stage: .hiddenReady(
            feature: .accountPasswordChange,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "App 内修改密码已建立页面壳层和后端合同，但默认发布态不展示，避免在真实认证、安全审计和后端接口验收前误承诺。"
        ),
        releaseCopy: "当前环境暂不支持修改密码"
    )

    static let voiceCloneCapability = Capability(
        title: "声音克隆",
        feature: .voiceCloneShell,
        stage: .hiddenReady(
            feature: .voiceCloneShell,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "默认发布态不展示声音克隆，避免在授权、样本质量、voiceProfileId 删除/禁用合同和合规验收前误承诺。"
        ),
        releaseCopy: voiceCloneUnavailableTitle
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

    static func isPasswordChangeVisible(
        isPasswordChangeEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isPasswordChangeEnabled
    }

    static func isVoiceCloneVisible(
        isVoiceCloneEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isVoiceCloneEnabled
    }
}
