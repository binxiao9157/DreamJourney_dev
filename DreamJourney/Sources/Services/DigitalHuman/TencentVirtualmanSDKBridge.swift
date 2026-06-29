import Foundation
import UIKit
import TXLiteAVSDK_TRTC
import VirtualmanStreamSDK

final class TencentVirtualmanSDKBridge: NSObject, TencentDigitalHumanSDKBridge {
    let contentView: UIView
    var eventHandler: ((TencentDigitalHumanSDKBridgeEvent) -> Void)?

    private let virtualman: Virtualman
    private var configuration: TencentDigitalHumanSDKConfiguration?
    private var remoteAudioUserIds = Set<String>()
    private var isRemoteAudioMuted = false

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
        guard !text.isEmpty || isFinal else {
            return
        }

        if isFinal, !text.isEmpty {
            let accepted = virtualman.sendText(TextParams(text: text, reqId: requestID))
            print(
                "[TencentDigitalHuman] sendText requestID=\(requestID) " +
                "accepted=\(accepted) textLength=\(text.count)"
            )
            guard accepted else {
                throw Self.providerError(code: 5, message: "Tencent text was rejected")
            }
            return
        }

        let accepted = virtualman.sendStreamText(StreamTextParams(reqId: requestID, text: text, seq: sequence, isFinal: isFinal))
        print(
            "[TencentDigitalHuman] sendStreamText requestID=\(requestID) " +
            "accepted=\(accepted) sequence=\(sequence) isFinal=\(isFinal) textLength=\(text.count)"
        )
        guard accepted else {
            throw Self.providerError(code: 5, message: "Tencent stream text was rejected")
        }
    }

    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        let base64Audio = data.base64EncodedString()
        let accepted = virtualman.sendAudio(AudioParams(reqId: requestID, audio: base64Audio, seq: sequence, isFinal: isFinal))
        if !accepted {
            throw Self.providerError(code: 4, message: "Tencent audio chunk was rejected")
        }
    }

    func setRemoteAudioMuted(_ muted: Bool) {
        isRemoteAudioMuted = muted
        let trtc = TRTCCloud.sharedInstance()
        let userIds = remoteAudioUserIds.sorted()
        if userIds.isEmpty {
            trtc.muteAllRemoteAudio(muted)
        } else {
            for userId in userIds {
                trtc.muteRemoteAudio(userId, mute: muted)
            }
        }
        print(
            "[TencentDigitalHuman] TRTC remote audio muted=\(muted) " +
            "userIds=\(userIds.isEmpty ? "all" : userIds.joined(separator: ","))"
        )
    }

    func interrupt() {
        _ = virtualman.stop()
    }

    func close() {
        _ = virtualman.stop()
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
        rememberRemoteAudioUserId(userId)
        #if DEBUG
        guard message.count > 16 else { return }
        let jsonData = message.subdata(in: 16..<message.count)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[TencentDigitalHuman][SEI] userId=\(userId), data=\(jsonString)")
        }
        #endif
    }

    func onFirstVideoFrame(_ userId: String, streamType: Int32, width: Int32, height: Int32) {
        rememberRemoteAudioUserId(userId)
        #if DEBUG
        print("[TencentDigitalHuman] first video frame userId=\(userId), streamType=\(streamType), size=\(width)x\(height)")
        #endif
    }

    func onError(_ errCode: Int32, errMsg: String?) {
        eventHandler?(.error(code: errCode, message: errMsg ?? "unknown"))
        #if DEBUG
        print("[TencentDigitalHuman] TRTC error code=\(errCode), message=\(errMsg ?? "unknown")")
        #endif
    }

    private func rememberRemoteAudioUserId(_ userId: String) {
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let inserted = remoteAudioUserIds.insert(normalized).inserted
        guard inserted, isRemoteAudioMuted else { return }
        TRTCCloud.sharedInstance().muteRemoteAudio(normalized, mute: true)
        print("[TencentDigitalHuman] TRTC remote audio mute applied to new userId=\(normalized)")
    }
}

extension TencentVirtualmanSDKBridge: VirtualmanWsDelegate {
    func onWsOpen() {
        eventHandler?(.webSocketOpen)
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket opened")
        #endif
    }

    func onWsMessage(_ text: String) {
        emitBridgeEventIfNeeded(from: text)

        #if DEBUG
        print("[TencentDigitalHuman] WebSocket message received: \(text)")
        #endif
    }

    func onWsClosed(code: UInt16, reason: String) {
        eventHandler?(.closed)
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket closed code=\(code), reason=\(reason)")
        #endif
    }

    func onWsFailure(_ error: Error?) {
        eventHandler?(.error(code: -1, message: error?.localizedDescription ?? "unknown"))
        #if DEBUG
        print("[TencentDigitalHuman] WebSocket failed: \(error?.localizedDescription ?? "unknown")")
        #endif
    }

    private func emitBridgeEventIfNeeded(from text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["Payload"] as? [String: Any] else {
            return
        }

        let requestID = payload["ReqId"] as? String
        if let errorCode = payload["ErrorCode"] as? Int,
           errorCode != 0 {
            eventHandler?(.error(code: Int32(errorCode), message: payload["ErrorMsg"] as? String ?? "unknown"))
            return
        }

        switch payload["SpeakStatus"] as? String {
        case "TextStart":
            eventHandler?(.textStart(requestID: requestID))
        case "AudioStart":
            eventHandler?(.audioStart(requestID: requestID))
        case "WaitingTextOver", "SentenceStart", "SentenceNext", "WaitingTextStart", "WaitingAudioStart", "WaitingAudioOver":
            if let status = payload["SpeakStatus"] as? String {
                eventHandler?(.speechProgress(requestID: requestID, status: status))
            }
        case "TextOver":
            eventHandler?(.textOver(requestID: requestID))
        case "AudioOver":
            eventHandler?(.audioOver(requestID: requestID))
        default:
            break
        }
    }
}
