import Foundation
import UIKit

struct TencentDigitalHumanSDKConfiguration: Equatable {
    let sessionId: String
    let appKey: String
    let accessToken: String
    let assetVirtualmanKey: String?
    let virtualmanProjectId: String?
    let alphaChannelEnable: Bool
    let smartActionEnabled: Bool
    let driveMode: String
    let credentialMode: String

    var shouldOpenByAsset: Bool {
        !(assetVirtualmanKey ?? "").isEmpty
    }

    var shouldOpenByProject: Bool {
        !(virtualmanProjectId ?? "").isEmpty
    }
}

protocol TencentDigitalHumanSDKBridge: AnyObject {
    var contentView: UIView { get }
    var eventHandler: ((TencentDigitalHumanSDKBridgeEvent) -> Void)? { get set }

    func configure(_ configuration: TencentDigitalHumanSDKConfiguration, profile: DigitalHumanProfile) throws
    func openByAsset(completion: @escaping (Result<String, Error>) -> Void)
    func openByProject(completion: @escaping (Result<String, Error>) -> Void)
    func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws
    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws
    func setRemoteAudioMuted(_ muted: Bool)
    func interrupt()
    func close()
}

enum TencentDigitalHumanSDKBridgeEvent: Equatable {
    case webSocketOpen
    case textStart(requestID: String?)
    case textOver(requestID: String?)
    case error(code: Int32, message: String)
    case closed
}

enum TencentDigitalHumanSDKBridgeError: Error, Equatable {
    case missingAssetVirtualmanKey
    case missingVirtualmanProjectId
    case bridgeUnavailable
    case unsupportedPCMDrive
}

final class TencentDigitalHumanSDKBridgeFactory {
    static let shared = TencentDigitalHumanSDKBridgeFactory()

    private var maker: ((UIView) -> TencentDigitalHumanSDKBridge?)?

    private init() {}

    func register(_ maker: @escaping (UIView) -> TencentDigitalHumanSDKBridge?) {
        self.maker = maker
    }

    func clear() {
        maker = nil
    }

    func makeBridge(contentView: UIView) -> TencentDigitalHumanSDKBridge? {
        maker?(contentView)
    }
}
