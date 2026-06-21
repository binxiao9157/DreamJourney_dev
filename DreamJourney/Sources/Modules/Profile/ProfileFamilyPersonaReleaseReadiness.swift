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

    static let hiddenBranchesLaunchArgument = "DJEnableProfileHiddenBranches"
    static let unavailableTitle = "家人管理暂未开放"
    static let unavailableMessage = "当前版本先保留入口，完整家人空间会在后续版本开放。"
    static let voiceCloneUnavailableTitle = "音色复刻暂不可用"
    static let voiceCloneUnavailableMessage = "当前环境未完成后端语音服务配置；音色复刻入口已公开，但训练、查询、禁用和删除都必须通过后端代理执行。"

    static let familyManagementCapability = Capability(
        title: "家人管理",
        feature: .familyManagement,
        stage: .publicReady(
            reason: "家人管理已按最新 PRD 公开基础能力：通过手机号邀请，展示邀请中、已加入、失败状态；成员不可删除，退出或解除关系暂未开放。"
        ),
        releaseCopy: "手机号邀请家人"
    )

    static let familySpaceCapability = Capability(
        title: "数字人切换",
        feature: .familySpace,
        stage: .publicReady(
            reason: "基础家人空间随家人管理公开；高级生命周期、解除关系和继承规则仍不开放。"
        ),
        releaseCopy: "家人空间"
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
        stage: .publicReady(
            reason: "音色复刻已按产品决策公开；入口默认可见，但必须先完成用户授权，训练、查询、合成、禁用和删除均通过后端代理，voiceProfileId 由后端返回和管理，不在 iOS 暴露火山密钥。"
        ),
        releaseCopy: "需授权后提交样本"
    )

    static func isFamilyManagementRowVisible(
        isFamilyManagementEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isFamilyManagementEnabled
    }

    static func canOpenFamilyPersonaSwitcher(
        isFamilyManagementEnabled: Bool,
        isFamilySpaceEnabled: Bool,
        isHiddenBranchesEnabled: Bool
    ) -> Bool {
        isHiddenBranchesEnabled || isFamilyManagementEnabled || isFamilySpaceEnabled
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
