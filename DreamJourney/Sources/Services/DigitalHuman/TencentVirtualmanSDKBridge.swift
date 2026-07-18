import Foundation
import UIKit
import TXLiteAVSDK_TRTC
import VirtualmanStreamSDK

final class TencentVirtualmanSDKBridge: NSObject, TencentDigitalHumanSDKBridge {
    let contentView: UIView
    var eventHandler: ((TencentDigitalHumanSDKBridgeEvent) -> Void)?

    private let virtualman: Virtualman
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
        _ = configuration
        _ = profile
        throw TencentDigitalHumanSDKBridgeError.credentialBrokerUnavailable
    }

    func openByAsset(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(TencentDigitalHumanSDKBridgeError.credentialBrokerUnavailable))
    }

    func openByProject(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(TencentDigitalHumanSDKBridgeError.credentialBrokerUnavailable))
    }

    func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        guard !text.isEmpty || isFinal else {
            return
        }

        if isFinal, !text.isEmpty {
            let accepted = virtualman.sendText(TextParams(text: text, reqId: requestID))
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "textSent",
                states: [
                    "accepted": accepted ? "true" : "false",
                    "isFinal": "true",
                ],
                counts: ["textUTF8ByteCount": text.utf8.count],
                correlations: ["request": requestID]
            )
            guard accepted else {
                throw Self.providerError(code: 5, message: "Tencent text was rejected")
            }
            return
        }

        let accepted = virtualman.sendStreamText(StreamTextParams(reqId: requestID, text: text, seq: sequence, isFinal: isFinal))
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "streamTextSent",
            states: [
                "accepted": accepted ? "true" : "false",
                "isFinal": isFinal ? "true" : "false",
            ],
            counts: [
                "sequence": sequence,
                "textUTF8ByteCount": text.utf8.count,
            ],
            correlations: ["request": requestID]
        )
        guard accepted else {
            throw Self.providerError(code: 5, message: "Tencent stream text was rejected")
        }
    }

    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        let base64Audio = data.base64EncodedString()
        let accepted = virtualman.sendAudio(AudioParams(reqId: requestID, audio: base64Audio, seq: sequence, isFinal: isFinal))
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "pcmSent",
            states: [
                "accepted": accepted ? "true" : "false",
                "isFinal": isFinal ? "true" : "false",
            ],
            counts: [
                "audioByteCount": data.count,
                "sequence": sequence,
            ],
            correlations: ["request": requestID]
        )
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
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "remoteAudioMuteUpdated",
            states: [
                "muted": muted ? "true" : "false",
                "target": userIds.isEmpty ? "all" : "knownRemotes",
            ],
            counts: ["remoteUserCount": userIds.count]
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
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "seiReceived",
            counts: ["payloadByteCount": max(0, message.count - 16)]
        )
        #endif
    }

    func onFirstVideoFrame(_ userId: String, streamType: Int32, width: Int32, height: Int32) {
        rememberRemoteAudioUserId(userId)
        #if DEBUG
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "firstVideoFrame",
            counts: [
                "streamType": Int(streamType),
                "width": Int(width),
                "height": Int(height),
            ]
        )
        #endif
    }

    func onError(_ errCode: Int32, errMsg: String?) {
        eventHandler?(.error(code: errCode, message: errMsg ?? "unknown"))
        #if DEBUG
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "trtcError",
            counts: ["code": Int(errCode)]
        )
        #endif
    }

    private func rememberRemoteAudioUserId(_ userId: String) {
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let inserted = remoteAudioUserIds.insert(normalized).inserted
        guard inserted, isRemoteAudioMuted else { return }
        TRTCCloud.sharedInstance().muteRemoteAudio(normalized, mute: true)
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "remoteAudioMuteApplied",
            states: ["muted": "true"],
            counts: ["remoteUserCount": remoteAudioUserIds.count]
        )
    }
}

extension TencentVirtualmanSDKBridge: VirtualmanWsDelegate {
    func onWsOpen() {
        eventHandler?(.webSocketOpen)
        #if DEBUG
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "webSocketOpened"
        )
        #endif
    }

    func onWsMessage(_ text: String) {
        emitBridgeEventIfNeeded(from: text)

        #if DEBUG
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "webSocketMessageReceived",
            counts: ["payloadUTF8ByteCount": text.utf8.count]
        )
        #endif
    }

    func onWsClosed(code: UInt16, reason: String) {
        eventHandler?(.closed)
        #if DEBUG
        _ = reason
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "webSocketClosed",
            counts: ["code": Int(code)]
        )
        #endif
    }

    func onWsFailure(_ error: Error?) {
        eventHandler?(.error(code: -1, message: error?.localizedDescription ?? "unknown"))
        #if DEBUG
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "webSocketFailure",
            states: ["failure": "transportFailure"]
        )
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
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerAudioStarted",
                correlations: ["request": requestID]
            )
        case "WaitingTextOver", "SentenceStart", "SentenceNext", "WaitingTextStart", "WaitingAudioStart", "WaitingAudioOver":
            if let status = payload["SpeakStatus"] as? String {
                eventHandler?(.speechProgress(requestID: requestID, status: status))
            }
        case "TextOver":
            eventHandler?(.textOver(requestID: requestID))
        case "AudioOver":
            eventHandler?(.audioOver(requestID: requestID))
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerAudioCompleted",
                correlations: ["request": requestID]
            )
        default:
            break
        }
    }
}
