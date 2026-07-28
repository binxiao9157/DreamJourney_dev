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

        state = .failed(code: "credential_broker_unavailable")
        throw DigitalHumanRuntimeError.unsupportedOperation(
            "credentialBrokerUnavailable: Tencent runtime requires a revocable scoped session credential."
        )
    }

    func open() throws {
        guard configuration != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        switch state {
        case .connecting, .ready, .buffering, .speaking:
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "duplicateOpenIgnored"
            )
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
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "remoteAudioMuteUnchanged",
                states: ["muted": muted ? "true" : "false"]
            )
            return
        }
        bridge.setRemoteAudioMuted(muted)
        isRemoteAudioMuted = muted
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "runtimeRemoteAudioMuteUpdated",
            states: ["muted": muted ? "true" : "false"]
        )
    }

    func interrupt() {
        currentRequestID = nil
        switch state {
        case .buffering, .speaking:
            bridge.interrupt()
            state = .interrupting
        case .closed:
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerInterruptIgnored",
                states: ["reason": "closed"]
            )
        default:
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerInterruptIgnored",
                states: ["reason": "notInterruptible"]
            )
        }
    }

    func interruptPlaybackIfNeeded(reason: String) {
        currentRequestID = nil
        switch state {
        case .ready, .buffering, .speaking:
            bridge.interrupt()
            if case .ready = state {
                state = .ready
            } else {
                state = .interrupting
            }
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerPlaybackInterrupted",
                states: ["reason": reason]
            )
        case .closed:
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerPlaybackInterruptIgnored",
                states: ["reason": "closed"]
            )
        default:
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerPlaybackInterruptIgnored",
                states: ["reason": "notInterruptible"]
            )
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
        case .failure(let error):
            state = .failed(code: openFailureCode(for: error))
        }
    }

    private func openFailureCode(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("LimitExceeded")
            || message.localizedCaseInsensitiveContains("Quota")
            || message.contains("超过配额")
            || message.contains("并发配额") {
            return "tencent_cloud_quota_exceeded"
        }
        return "tencent_cloud_open_failed"
    }

    private func handleBridgeEvent(_ event: TencentDigitalHumanSDKBridgeEvent) {
        switch event {
        case .webSocketOpen:
            state = .ready
        case .textStart(let requestID):
            state = .speaking(requestID: requestID ?? currentRequestID ?? contract.sessionId)
        case .audioStart(let requestID):
            state = .speaking(requestID: requestID ?? currentRequestID ?? contract.sessionId)
        case .speechProgress(let requestID, let status):
            state = .speaking(requestID: requestID ?? currentRequestID ?? contract.sessionId)
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerSpeechProgress",
                states: ["status": status],
                correlations: ["request": requestID ?? currentRequestID]
            )
        case .textOver(let requestID):
            handleProviderTextOver(requestID: requestID)
        case .audioOver(let requestID):
            handleProviderAudioOver(requestID: requestID)
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
            state = .failed(code: "tencent_cloud_\(code)")
        case .closed:
            currentRequestID = nil
            state = .closed
        }
    }

    private func handleProviderTextOver(requestID: String?) {
        guard matchesCurrentProviderRequest(requestID) else {
            return
        }
        // TextOver only means that the provider consumed the text. Audio may
        // still be playing, so ownership and microphone recovery stay put
        // until the request-specific AudioOver event arrives.
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "providerTextCompletedAwaitingAudio",
            correlations: ["request": requestID]
        )
    }

    private func handleProviderAudioOver(requestID: String?) {
        guard let currentRequestID,
              matchesCurrentProviderRequest(requestID) else {
            return
        }
        self.currentRequestID = nil
        state = .completed(requestID: currentRequestID)
        state = .ready
    }

    private func matchesCurrentProviderRequest(_ providerRequestID: String?) -> Bool {
        guard let currentRequestID else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerTerminalEventIgnored",
                states: ["reason": "noCurrentRequest"],
                correlations: ["providerRequest": providerRequestID]
            )
            return false
        }
        guard let providerRequestID = providerRequestID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !providerRequestID.isEmpty else {
            // Terminal events without a provider request ID cannot be safely
            // attributed. The existing timeout will recover the current turn.
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerTerminalEventIgnored",
                states: ["reason": "missingProviderRequest"],
                correlations: ["currentRequest": currentRequestID]
            )
            return false
        }
        guard providerRequestID == currentRequestID else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerTerminalEventIgnored",
                states: ["reason": "requestMismatch"],
                correlations: [
                    "currentRequest": currentRequestID,
                    "providerRequest": providerRequestID,
                ]
            )
            return false
        }
        return true
    }

    private func isNonFatalInterruptRejection(code: Int32, message: String) -> Bool {
        code == 110015 && message.localizedCaseInsensitiveContains("interrupt")
    }
}
