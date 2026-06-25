import Foundation
import UIKit

final class TencentDigitalHumanCloudRuntime: DigitalHumanRuntime {
    let contentView: UIView
    private let bridge: TencentDigitalHumanSDKBridge
    private let contract: DigitalHumanSessionContract
    private(set) var state: DigitalHumanSessionState = .idle
    private(set) var profile: DigitalHumanProfile?

    private var configuration: TencentDigitalHumanSDKConfiguration?

    init(
        contract: DigitalHumanSessionContract,
        bridge: TencentDigitalHumanSDKBridge,
        contentView: UIView
    ) {
        self.contract = contract
        self.bridge = bridge
        self.contentView = bridge.contentView
        self.contentView.accessibilityIdentifier = "digitalHuman.tencentCloudRuntimeView"
    }

    func configure(_ profile: DigitalHumanProfile) throws {
        if profile.lifecycleMode == .silent {
            throw DigitalHumanRuntimeError.silentModeDisabled
        }

        guard let appKey = contract.credential.appKey, !appKey.isEmpty,
              let accessToken = contract.credential.accessToken, !accessToken.isEmpty else {
            state = .failed(code: "missing_tencent_sdk_credential")
            throw DigitalHumanRuntimeError.unsupportedOperation("Tencent SDK credential is missing from backend session contract.")
        }

        let configuration = TencentDigitalHumanSDKConfiguration(
            sessionId: contract.sessionId,
            appKey: appKey,
            accessToken: accessToken,
            assetVirtualmanKey: contract.assetKey ?? contract.providerAssetId,
            virtualmanProjectId: contract.providerProjectId,
            alphaChannelEnable: contract.alphaEnabled,
            smartActionEnabled: contract.smartActionEnabled,
            driveMode: contract.driveMode,
            credentialMode: contract.credential.mode
        )

        try bridge.configure(configuration, profile: profile)
        self.profile = profile
        self.configuration = configuration
        state = .preparing
    }

    func open() throws {
        guard configuration != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }

        state = .connecting
        if configuration?.shouldOpenByAsset == true {
            bridge.openByAsset { [weak self] result in
                self?.handleOpenResult(result)
            }
        } else if configuration?.shouldOpenByProject == true {
            bridge.openByProject { [weak self] result in
                self?.handleOpenResult(result)
            }
        } else {
            state = .failed(code: "missing_tencent_virtualman_asset")
            throw DigitalHumanRuntimeError.unsupportedOperation("Tencent digital human requires asset_virtualman_key or virtualman_project_id.")
        }
    }

    func sendTextChunk(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .speaking(requestID: requestID)
        try bridge.sendText(text, requestID: requestID, sequence: sequence, isFinal: isFinal)
        if isFinal {
            state = .ready
        }
    }

    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .speaking(requestID: requestID)
        try bridge.sendPCM(data, requestID: requestID, sequence: sequence, isFinal: isFinal)
        if isFinal {
            state = .ready
        }
    }

    func interrupt() {
        bridge.interrupt()
        state = .interrupting
    }

    func close() {
        bridge.close()
        state = .closed
    }

    private func handleOpenResult(_ result: Result<String, Error>) {
        switch result {
        case .success:
            state = .ready
        case .failure:
            state = .failed(code: "tencent_cloud_open_failed")
        }
    }
}
