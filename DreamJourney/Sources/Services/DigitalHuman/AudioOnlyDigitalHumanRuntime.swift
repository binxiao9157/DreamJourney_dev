import Foundation
import UIKit

final class AudioOnlyDigitalHumanRuntime: DigitalHumanRuntime {
    let contentView: UIView
    var onStateChange: ((DigitalHumanSessionState) -> Void)?
    private(set) var state: DigitalHumanSessionState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var profile: DigitalHumanProfile?

    init(contentView: UIView = UIView()) {
        self.contentView = contentView
        self.contentView.isHidden = true
        self.contentView.accessibilityIdentifier = "digitalHuman.audioOnlyFallbackView"
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
        state = .ready
    }

    func close() {
        state = .closed
    }
}
