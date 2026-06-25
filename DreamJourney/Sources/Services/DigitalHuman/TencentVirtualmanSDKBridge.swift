import Foundation
import UIKit
import VirtualmanStreamSDK
import TXLiteAVSDK_TRTC

final class TencentVirtualmanSDKBridge: NSObject, TencentDigitalHumanSDKBridge {
    let contentView: UIView

    private let virtualman: Virtualman
    private var configuration: TencentDigitalHumanSDKConfiguration?

    override init() {
        let virtualman = Virtualman(frame: .zero)
        virtualman.translatesAutoresizingMaskIntoConstraints = false
        virtualman.backgroundColor = .clear
        self.virtualman = virtualman
        self.contentView = virtualman
        super.init()
        virtualman.setDelegate(self)
        virtualman.setWsDelegate(self)
    }

    static func registerFactory() {
        TencentDigitalHumanSDKBridgeFactory.shared.register { _ in
            TencentVirtualmanSDKBridge()
        }
    }

    func configure(_ configuration: TencentDigitalHumanSDKConfiguration, profile: DigitalHumanProfile) throws {
        self.configuration = configuration

        let params = VirtualmanParams(appkey: configuration.appKey, accesstoken: configuration.accessToken)

        if let assetKey = configuration.assetVirtualmanKey, !assetKey.isEmpty {
            let assetParams = AssetVirtualmanParams(assetVirtualmanKey: assetKey)
            assetParams.extraInfo = ExtraInfo(alphaChannelEnable: configuration.alphaChannelEnable)
            params.assetVirtualmanParams = assetParams
        }

        if let projectId = configuration.virtualmanProjectId, !projectId.isEmpty {
            let projectParams = VirtualmanProjectParams(virtualmanProjectId: projectId)
            projectParams.extraInfo = ExtraInfo(alphaChannelEnable: configuration.alphaChannelEnable)
            params.virtualmanProjectParams = projectParams
        }

        virtualman.initSDK(params: params)
    }

    func openByAsset(completion: @escaping (Result<String, Error>) -> Void) {
        guard configuration?.shouldOpenByAsset == true else {
            completion(.failure(TencentDigitalHumanSDKBridgeError.missingAssetVirtualmanKey))
            return
        }

        virtualman.openByAsset { sessionId, error in
            if let sessionId {
                completion(.success(sessionId))
            } else {
                completion(.failure(Self.providerError(code: 1, message: error ?? "Tencent asset stream failed")))
            }
        }
    }

    func openByProject(completion: @escaping (Result<String, Error>) -> Void) {
        guard configuration?.shouldOpenByProject == true else {
            completion(.failure(TencentDigitalHumanSDKBridgeError.missingVirtualmanProjectId))
            return
        }

        virtualman.open { sessionId, error in
            if let sessionId {
                completion(.success(sessionId))
            } else {
                completion(.failure(Self.providerError(code: 2, message: error ?? "Tencent project stream failed")))
            }
        }
    }

    func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard !text.isEmpty else {
            return
        }

        if sequence <= 1 && isFinal {
            let accepted = virtualman.chat(ChatParams(text: text, isNewChat: true))
            if !accepted {
                throw Self.providerError(code: 3, message: "Tencent chat text was rejected")
            }
            return
        }

        virtualman.sendStreamText(StreamTextParams(reqId: requestID, text: text, seq: sequence, isFinal: isFinal))
    }

    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        let base64Audio = data.base64EncodedString()
        let accepted = virtualman.sendAudio(AudioParams(reqId: requestID, audio: base64Audio, seq: sequence, isFinal: isFinal))
        if !accepted {
            throw Self.providerError(code: 4, message: "Tencent audio chunk was rejected")
        }
    }

    func interrupt() {
        _ = virtualman.stop()
    }

    func close() {
        virtualman.close()
    }

    private static func providerError(code: Int, message: String) -> NSError {
        NSError(
            domain: "TencentVirtualmanSDKBridge",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

extension TencentVirtualmanSDKBridge: VirtualmanDelegate {
    func onRecvSEIMsg(_ userId: String, message: Data) {
        #if DEBUG
        guard message.count > 16 else { return }
        let jsonData = message.subdata(in: 16..<message.count)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[TencentDigitalHuman][SEI] userId=\(userId), data=\(jsonString)")
        }
        #endif
    }

    func onFirstVideoFrame(_ userId: String, streamType: Int32, width: Int32, height: Int32) {
        #if DEBUG
        print("[TencentDigitalHuman] first video frame userId=\(userId), streamType=\(streamType), size=\(width)x\(height)")
        #endif
    }

    func onError(_ errCode: Int32, errMsg: String?) {
        #if DEBUG
        print("[TencentDigitalHuman] TRTC error code=\(errCode), message=\(errMsg ?? "unknown")")
        #endif
    }
}

extension TencentVirtualmanSDKBridge: VirtualmanWsDelegate {
    func onWsOpen() {
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket opened")
        #endif
    }

    func onWsMessage(_ text: String) {
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket message received: \(text)")
        #endif
    }

    func onWsClosed(code: UInt16, reason: String) {
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket closed code=\(code), reason=\(reason)")
        #endif
    }

    func onWsFailure(_ error: Error?) {
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket failed: \(error?.localizedDescription ?? "unknown")")
        #endif
    }
}
