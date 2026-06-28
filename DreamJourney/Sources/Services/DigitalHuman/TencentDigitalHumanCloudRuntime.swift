import Foundation
import UIKit

final class TencentDigitalHumanCloudRuntime: DigitalHumanRuntime {
    let contentView: UIView
    private let bridge: TencentDigitalHumanSDKBridge
    private let contract: DigitalHumanSessionContract
    var onStateChange: ((DigitalHumanSessionState) -> Void)?
    private(set) var state: DigitalHumanSessionState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var profile: DigitalHumanProfile?

    private var configuration: TencentDigitalHumanSDKConfiguration?
    private var currentRequestID: String?
    private var isRemoteAudioMuted = false

    init(
        contract: DigitalHumanSessionContract,
        bridge: TencentDigitalHumanSDKBridge,
        contentView: UIView
    ) {
        self.contract = contract
        self.bridge = bridge
        self.contentView = bridge.contentView
        self.contentView.accessibilityIdentifier = "digitalHuman.tencentCloudRuntimeView"
        self.bridge.eventHandler = { [weak self] event in
            self?.handleBridgeEvent(event)
        }
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
        switch state {
        case .connecting, .ready, .buffering, .speaking:
            print("[TencentDigitalHuman] ignored duplicate open while state=\(state)")
            return
        default:
            break
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
        setRemoteAudioMuted(false)
        currentRequestID = requestID
        state = .buffering
        try bridge.sendText(text, requestID: requestID, sequence: sequence, isFinal: isFinal)
    }

    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        setRemoteAudioMuted(false)
        currentRequestID = requestID
        state = .buffering
        try bridge.sendPCM(data, requestID: requestID, sequence: sequence, isFinal: isFinal)
    }

    func setRemoteAudioMuted(_ muted: Bool) {
        guard isRemoteAudioMuted != muted else {
            print("[TencentDigitalHuman] remote audio mute unchanged muted=\(muted)")
            return
        }
        bridge.setRemoteAudioMuted(muted)
        isRemoteAudioMuted = muted
        print("[TencentDigitalHuman] remote audio muted=\(muted)")
    }

    func interrupt() {
        currentRequestID = nil
        switch state {
        case .buffering, .speaking:
            bridge.interrupt()
            state = .interrupting
        case .closed:
            print("[TencentDigitalHuman] ignored provider interrupt while state=closed")
        default:
            print("[TencentDigitalHuman] ignored provider interrupt while state=\(state)")
        }
    }

    func close() {
        setRemoteAudioMuted(false)
        bridge.interrupt()
        bridge.close()
        currentRequestID = nil
        state = .closed
    }

    private func handleOpenResult(_ result: Result<String, Error>) {
        switch result {
        case .success:
            state = .connecting
        case .failure:
            state = .failed(code: "tencent_cloud_open_failed")
        }
    }

    private func handleBridgeEvent(_ event: TencentDigitalHumanSDKBridgeEvent) {
        switch event {
        case .webSocketOpen:
            state = .ready
        case .textStart(let requestID):
            state = .speaking(requestID: requestID ?? currentRequestID ?? contract.sessionId)
        case .textOver:
            currentRequestID = nil
            state = .ready
        case .error(let code, let message):
            if isNonFatalInterruptRejection(code: code, message: message) {
                currentRequestID = nil
                if state != .closed {
                    state = .ready
                }
                print("[TencentDigitalHuman] ignored non-fatal provider interrupt rejection code=\(code)")
                return
            }
            currentRequestID = nil
            state = .failed(code: "tencent_cloud_\(code)_\(message)")
        case .closed:
            currentRequestID = nil
            state = .closed
        }
    }

    private func isNonFatalInterruptRejection(code: Int32, message: String) -> Bool {
        code == 110015 && message.localizedCaseInsensitiveContains("interrupt")
    }
}
