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
    static let unavailableTitle = "家人管理暂不可用"
    static let unavailableMessage = "请确认已经登录并保持网络连接，然后重新进入家人管理。"
    static let voiceCloneUnavailableTitle = "音色复刻暂不可用"
    static let voiceCloneUnavailableMessage = "当前音色服务尚未就绪，请稍后重试。"

    static let familyManagementCapability = Capability(
        title: "家人管理",
        feature: .familyManagement,
        stage: .publicReady(reason: "家人管理面向所有已登录用户开放。"),
        releaseCopy: "登录后可管理与切换家人"
    )

    static let familySpaceCapability = Capability(
        title: "数字人切换",
        feature: .familySpace,
        stage: .publicReady(reason: "已登录用户可以在自己与已加入的家人之间切换。"),
        releaseCopy: "可切换自己与已加入的家人"
    )

    static let passwordChangeCapability = Capability(
        title: "密码与安全",
        feature: .accountPasswordChange,
        stage: .publicReady(reason: "登录用户仅在服务端密码认证能力完整就绪时管理密码。"),
        releaseCopy: "由服务端认证能力决定是否可用"
    )

    static let voiceCloneCapability = Capability(
        title: "音色复刻",
        feature: .voiceCloneShell,
        stage: .publicReady(reason: "已登录用户按服务端授权与音色供应商状态使用。"),
        releaseCopy: "管理本人授权的音色"
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
        passwordAuthentication: BackendPasswordAuthenticationCapability
    ) -> Bool {
        passwordAuthentication.canManagePassword
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
