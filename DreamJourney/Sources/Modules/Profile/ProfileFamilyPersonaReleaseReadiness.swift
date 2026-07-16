import Foundation

enum ProfileFamilyPersonaReleaseReadiness {
    enum Stage: Equatable {
        case publicReady(reason: String)
        case hiddenReady(feature: DJFeature, qaLaunchArgument: String, reason: String)
    }

    struct Capability: Equatable {
        let title: String
        let feature: DJFeature
        let stage: Stage
        let releaseCopy: String
    }

    #if DEBUG || UI_QA_SIMULATOR
    static let hiddenBranchesLaunchArgument = "DJEnableProfileHiddenBranches"
    #else
    static let hiddenBranchesLaunchArgument = ""
    #endif
    static let unavailableTitle = "家人管理暂未开放"
    static let unavailableMessage = "当前版本先保留入口，完整家人空间会在后续版本开放。"
    static let voiceCloneUnavailableTitle = "音色复刻暂不可用"
    static let voiceCloneUnavailableMessage = "当前版本暂不公开音色复刻；内部验证仍通过后端代理执行训练、查询、合成、禁用和删除。"

    static let familyManagementCapability = Capability(
        title: "家人管理",
        feature: .familyManagement,
        stage: .hiddenReady(
            feature: .familyManagement,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "V4 Closed Pilot 暂不公开家庭关系写入；手机号邀请和状态合同保留供内部验证。"
        ),
        releaseCopy: "家人管理暂未开放"
    )

    static let familySpaceCapability = Capability(
        title: "数字人切换",
        feature: .familySpace,
        stage: .hiddenReady(
            feature: .familySpace,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "家庭授权、角色切换和生命周期仍需后续 Gate，当前只保留 QA 壳层。"
        ),
        releaseCopy: "家人空间暂未开放"
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
        title: "音色复刻",
        feature: .voiceCloneShell,
        stage: .hiddenReady(
            feature: .voiceCloneShell,
            qaLaunchArgument: hiddenBranchesLaunchArgument,
            reason: "V4 Closed Pilot 暂不公开音色复刻；授权、Provider 质量和外部门完成前只允许 QA 验证。"
        ),
        releaseCopy: "音色复刻暂未开放"
    )

    static func isFamilyManagementRowVisible(
        isFamilyManagementEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        if isHiddenBranchesEnabled { return true }
        let snapshot = RuntimeCapabilitySnapshotStore.shared.snapshot(for: .familyManagement)
        return isFamilyManagementEnabled && snapshot?.isPubliclyAvailable == true
    }

    static func canOpenFamilyPersonaSwitcher(
        isFamilyManagementEnabled: Bool,
        isFamilySpaceEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        if isHiddenBranchesEnabled { return true }
        let management = RuntimeCapabilitySnapshotStore.shared.snapshot(for: .familyManagement)
        let familySpace = RuntimeCapabilitySnapshotStore.shared.snapshot(for: .familySpace)
        return (isFamilyManagementEnabled && management?.isPubliclyAvailable == true)
            || (isFamilySpaceEnabled && familySpace?.isPubliclyAvailable == true)
    }

    static func canOpenFamilyPersonaSwitcher(
        isFamilySpaceEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        if isHiddenBranchesEnabled { return true }
        let snapshot = RuntimeCapabilitySnapshotStore.shared.snapshot(for: .familySpace)
        return isFamilySpaceEnabled && snapshot?.isPubliclyAvailable == true
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
        if isHiddenBranchesEnabled { return true }
        let snapshot = RuntimeCapabilitySnapshotStore.shared.snapshot(for: .voiceCloneShell)
        return isVoiceCloneEnabled && snapshot?.isPubliclyAvailable == true
    }
}
