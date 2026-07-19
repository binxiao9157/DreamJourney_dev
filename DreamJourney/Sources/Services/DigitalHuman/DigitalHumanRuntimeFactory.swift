import Foundation
import UIKit

struct DigitalHumanRuntimeSelection {
    let runtime: DigitalHumanRuntime
    let selectedProvider: String
    let selectedMode: String
    let fallbackReason: String?
    let isRealSDKBacked: Bool
}

final class DigitalHumanRuntimeFactory {
    private static let realTencentProviderModes: Set<String> = [
        "tencentSDK",
        "cloudRender",
    ]

    private init() {}

    static func makeRuntime(
        for contract: DigitalHumanSessionContract,
        capability: DigitalHumanRuntimeCapability? = nil,
        contentView: UIView = UIView()
    ) -> DigitalHumanRuntimeSelection {
        if contract.provider == "tencent", contract.providerMode == "mockContract" {
            return DigitalHumanRuntimeSelection(
                runtime: TencentDigitalHumanRuntimeStub(contentView: contentView),
                selectedProvider: contract.provider,
                selectedMode: contract.providerMode,
                fallbackReason: nil,
                isRealSDKBacked: false
            )
        }

        if contract.provider == "tencent",
           realTencentProviderModes.contains(contract.providerMode) {
            guard let capability,
                  capability.allowsScopedMobileSession,
                  contract.isUsableForClientRuntime else {
                let readinessMessage = capability?.sdkReadinessMessage ?? "Digital-human runtime capability is missing."
                return DigitalHumanRuntimeSelection(
                    runtime: AudioOnlyDigitalHumanRuntime(contentView: contentView),
                    selectedProvider: contract.provider,
                    selectedMode: contract.providerMode,
                    fallbackReason: readinessMessage.isEmpty
                        ? "Tencent scoped mobile session credential is not verified."
                        : readinessMessage,
                    isRealSDKBacked: false
                )
            }

            if capability.sdkAdapterLinked == false {
                return DigitalHumanRuntimeSelection(
                    runtime: AudioOnlyDigitalHumanRuntime(contentView: contentView),
                    selectedProvider: contract.provider,
                    selectedMode: contract.providerMode,
                    fallbackReason: "Tencent SDK adapter is not linked.",
                    isRealSDKBacked: false
                )
            }

            if let bridge = TencentDigitalHumanSDKBridgeFactory.shared.makeBridge(contentView: contentView) {
                return DigitalHumanRuntimeSelection(
                    runtime: TencentDigitalHumanCloudRuntime(
                        contract: contract,
                        bridge: bridge,
                        contentView: contentView
                    ),
                    selectedProvider: contract.provider,
                    selectedMode: contract.providerMode,
                    fallbackReason: nil,
                    isRealSDKBacked: true
                )
            }

            return DigitalHumanRuntimeSelection(
                runtime: TencentDigitalHumanSDKRuntimeUnavailable(contentView: contentView),
                selectedProvider: contract.provider,
                selectedMode: contract.providerMode,
                fallbackReason: TencentDigitalHumanSDKRuntimeUnavailable.unavailableReason,
                isRealSDKBacked: false
            )
        }

        return DigitalHumanRuntimeSelection(
            runtime: AudioOnlyDigitalHumanRuntime(contentView: contentView),
            selectedProvider: contract.provider,
            selectedMode: contract.providerMode,
            fallbackReason: "Tencent SDK adapter is not linked; falling back to audio-only mode.",
            isRealSDKBacked: false
        )
    }
}
