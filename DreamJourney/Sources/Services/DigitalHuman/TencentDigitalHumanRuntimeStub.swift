import Foundation
import UIKit

struct TencentDigitalHumanPCMChunkRecord {
    let requestID: String
    let sequence: Int
    let byteCount: Int
    let isFinal: Bool
}

final class TencentDigitalHumanRuntimeStub: DigitalHumanRuntime {
    let contentView: UIView
    var onStateChange: ((DigitalHumanSessionState) -> Void)?
    private(set) var state: DigitalHumanSessionState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var profile: DigitalHumanProfile?
    private(set) var sentPCMChunks: [TencentDigitalHumanPCMChunkRecord] = []
    private(set) var interruptCount = 0

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
        sentPCMChunks.append(TencentDigitalHumanPCMChunkRecord(
            requestID: requestID,
            sequence: sequence,
            byteCount: data.count,
            isFinal: isFinal
        ))
        state = isFinal ? .ready : .speaking(requestID: requestID)
    }

    func interrupt() {
        interruptCount += 1
        state = .interrupting
        state = .ready
    }

    func close() {
        state = .closed
    }
}
