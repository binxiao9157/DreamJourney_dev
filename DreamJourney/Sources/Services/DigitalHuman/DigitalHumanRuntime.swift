import Foundation
import UIKit

enum DigitalHumanSessionState: Equatable {
    case idle
    case preparing
    case connecting
    case ready
    case listening
    case thinking
    case buffering
    case speaking(requestID: String)
    case interrupting
    case reconnecting
    case degraded
    case failed(code: String)
    case closed
}

struct DigitalHumanProfile: Equatable {
    var provider: String
    var personaId: String
    var displayName: String
    var lifecycleMode: DigitalHumanMode
    var driveMode: String
    var alphaEnabled: Bool
    var smartActionEnabled: Bool
    var assetKey: String?

    init(
        provider: String,
        personaId: String,
        displayName: String,
        lifecycleMode: DigitalHumanMode,
        driveMode: String = "streamText",
        alphaEnabled: Bool = true,
        smartActionEnabled: Bool = false,
        assetKey: String? = nil
    ) {
        self.provider = provider
        self.personaId = personaId
        self.displayName = displayName
        self.lifecycleMode = lifecycleMode
        self.driveMode = driveMode
        self.alphaEnabled = alphaEnabled
        self.smartActionEnabled = smartActionEnabled
        self.assetKey = assetKey
    }
}

protocol DigitalHumanRuntime: AnyObject {
    var contentView: UIView { get }
    var state: DigitalHumanSessionState { get }
    var profile: DigitalHumanProfile? { get }
    var onStateChange: ((DigitalHumanSessionState) -> Void)? { get set }

    func configure(_ profile: DigitalHumanProfile) throws
    func open() throws
    func sendTextChunk(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws
    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws
    func interrupt()
    func close()
}

enum DigitalHumanRuntimeError: Error, Equatable {
    case missingProfile
    case silentModeDisabled
    case unsupportedOperation(String)
}
