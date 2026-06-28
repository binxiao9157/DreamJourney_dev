import Foundation
import UIKit

final class TencentDigitalHumanSDKRuntimeUnavailable: DigitalHumanRuntime {
    static let unavailableReason = "Tencent SDK adapter is not linked in the current iOS build; TencentDigitalHumanSDKBridgeFactory returned no bridge."

    let contentView: UIView
    var onStateChange: ((DigitalHumanSessionState) -> Void)?
    private(set) var state: DigitalHumanSessionState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var profile: DigitalHumanProfile?

    init(contentView: UIView = UIView()) {
        self.contentView = contentView
        self.contentView.isHidden = true
        self.contentView.accessibilityIdentifier = "digitalHuman.tencentSDKUnavailableView"
    }

    func configure(_ profile: DigitalHumanProfile) throws {
        if profile.lifecycleMode == .silent {
            throw DigitalHumanRuntimeError.silentModeDisabled
        }
        self.profile = profile
        state = .degraded
    }

    func open() throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .degraded
        throw DigitalHumanRuntimeError.unsupportedOperation(Self.unavailableReason)
    }

    func sendTextChunk(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .failed(code: "tencent_sdk_adapter_unavailable")
        throw DigitalHumanRuntimeError.unsupportedOperation(Self.unavailableReason)
    }

    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .failed(code: "tencent_sdk_adapter_unavailable")
        throw DigitalHumanRuntimeError.unsupportedOperation(Self.unavailableReason)
    }

    func interrupt() {
        state = .degraded
    }

    func close() {
        state = .closed
    }
}
