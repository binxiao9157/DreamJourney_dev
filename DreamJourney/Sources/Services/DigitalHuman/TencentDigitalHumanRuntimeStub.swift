import Foundation
import UIKit

final class TencentDigitalHumanRuntimeStub: DigitalHumanRuntime {
    let contentView: UIView
    var onStateChange: ((DigitalHumanSessionState) -> Void)?
    private(set) var state: DigitalHumanSessionState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var profile: DigitalHumanProfile?

    let provider = "tencent"

    init(contentView: UIView = UIView()) {
        self.contentView = contentView
        self.contentView.backgroundColor = .clear
        self.contentView.accessibilityIdentifier = "digitalHuman.tencentStubView"
    }

    func configure(_ profile: DigitalHumanProfile) throws {
        if profile.lifecycleMode == .silent {
            throw DigitalHumanRuntimeError.silentModeDisabled
        }
        self.profile = profile
        state = .preparing
    }

    func open() throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = .ready
    }

    func sendTextChunk(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = isFinal ? .ready : .speaking(requestID: requestID)
    }

    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard profile != nil else {
            throw DigitalHumanRuntimeError.missingProfile
        }
        state = isFinal ? .ready : .speaking(requestID: requestID)
    }

    func interrupt() {
        state = .interrupting
        state = .ready
    }

    func close() {
        state = .closed
    }
}
