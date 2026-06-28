import UIKit
import WebKit

enum DigitalHumanLiveInteractionState: String {
    case idle
    case listening
    case thinking
    case speaking
    case stopped
    case failed
}

struct DigitalHumanLivePanelSnapshot {
    let ready: Bool
    let rendererReady: Bool
    let failed: Bool
    let stateName: String
    let audioLevel: Double
    let personaName: String
    let personaSubtitle: String
    let hasRealDigitalHumanAsset: Bool
    let assetVideoReady: Bool
    let hasFallbackAvatar: Bool
    let audioLevelSource: String
    let lipSyncSource: String
    let currentMouthShape: String
    let lipSyncFrameCount: Int

    init(object: [String: Any]) {
        ready = object["ready"] as? Bool ?? false
        rendererReady = object["rendererReady"] as? Bool ?? false
        failed = object["failed"] as? Bool ?? false
        stateName = object["stateName"] as? String ?? "unknown"
        audioLevel = object["audioLevel"] as? Double ?? 0
        audioLevelSource = object["audioLevelSource"] as? String ?? DigitalHumanAudioLevelSource.idle.rawValue
        lipSyncSource = object["lipSyncSource"] as? String ?? DigitalHumanAudioLevelSource.idle.rawValue
        currentMouthShape = object["currentMouthShape"] as? String ?? "neutral"
        lipSyncFrameCount = object["lipSyncFrameCount"] as? Int ?? 0
        personaName = object["personaName"] as? String ?? ""
        personaSubtitle = object["personaSubtitle"] as? String ?? ""
        hasRealDigitalHumanAsset = object["hasRealDigitalHumanAsset"] as? Bool ?? false
        assetVideoReady = object["assetVideoReady"] as? Bool ?? false
        hasFallbackAvatar = object["hasFallbackAvatar"] as? Bool ?? true
    }
}

final class DigitalHumanLivePanelView: UIView {
    private let webView: WKWebView
    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.text = "数字人预览准备中"
        label.font = DJDesignTokens.Font.label(12)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.accessibilityIdentifier = "digitalHumanLiveFallback"
        return label
    }()

    private var pendingScripts: [String] = []
    private(set) var isReady = false
    private(set) var didFail = false
    private var hostedProviderView: UIView?
    private var providerModeEnabled = false
    private var localPreviewEnabled = false

    override init(frame: CGRect) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frame)
        configureView()
        loadHTML()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setInteractionState(_ state: DigitalHumanLiveInteractionState) {
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setState('\(state.rawValue)')")
        if state == .idle || state == .stopped || state == .failed {
            setAudioLevel(0, source: .idle)
        }
    }

    func setAudioLevel(_ level: Double, source: DigitalHumanAudioLevelSource = .idle) {
        let clamped = max(0, min(1, level))
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setAudioLevel(\(clamped), '\(source.rawValue)')")
    }

    func setMouthShape(
        _ mouthShape: String,
        intensity: Double,
        source: DigitalHumanPlaybackSource = .providerVisemeTimeline
    ) {
        let encodedMouthShape = Self.javaScriptStringLiteral(mouthShape)
        let clampedIntensity = max(0, min(1, intensity))
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setMouthShape(\(encodedMouthShape), \(clampedIntensity), '\(source.rawValue)')")
    }

    func setVisemeTimeline(_ timeline: DigitalHumanLipSyncTimeline) {
        guard let payload = try? timeline.javaScriptLiteral() else {
            setMouthShape("neutral", intensity: 0, source: .providerVisemeTimeline)
            return
        }
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setVisemeTimeline(\(payload))")
    }

    func applyPlaybackEvent(_ event: DigitalHumanPlaybackEvent) {
        switch event {
        case .audioLevel(let level, let source):
            setAudioLevel(level, source: Self.audioLevelSource(from: source))
        case .visemeTimeline(let timeline):
            setVisemeTimeline(timeline)
        case .stopped:
            setInteractionState(.stopped)
        case .failed:
            setInteractionState(.failed)
        }
    }

    func setPersona(name: String, subtitle: String) {
        let encodedName = Self.javaScriptStringLiteral(name)
        let encodedSubtitle = Self.javaScriptStringLiteral(subtitle)
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setPersona(\(encodedName), \(encodedSubtitle))")
    }

    func hostProviderView(_ providerView: UIView) {
        hostedProviderView?.removeFromSuperview()
        hostedProviderView = providerView
        providerView.accessibilityIdentifier = "digitalHumanLiveProviderView"
        providerView.translatesAutoresizingMaskIntoConstraints = false
        providerView.backgroundColor = .clear
        providerView.isOpaque = false
        setLocalPreviewEnabled(false)
        setProviderModeEnabled(true)
        webView.isHidden = true
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        fallbackLabel.isHidden = true
        addSubview(providerView)
        NSLayoutConstraint.activate([
            providerView.topAnchor.constraint(equalTo: topAnchor),
            providerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            providerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            providerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func removeHostedProviderView(showFallbackMessage message: String? = nil) {
        hostedProviderView?.removeFromSuperview()
        hostedProviderView = nil
        setProviderModeEnabled(false)
        setLocalPreviewEnabled(false)
        webView.isHidden = true
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        if let message {
            fallbackLabel.text = message
            fallbackLabel.isHidden = false
        } else {
            fallbackLabel.isHidden = true
        }
    }

    func showProviderPlaceholder(_ message: String = "正在连接腾讯数智人") {
        hostedProviderView?.removeFromSuperview()
        hostedProviderView = nil
        setLocalPreviewEnabled(false)
        setProviderModeEnabled(true)
        webView.isHidden = true
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        fallbackLabel.text = message
        fallbackLabel.isHidden = false
    }

    func setLocalPreviewEnabled(_ enabled: Bool) {
        localPreviewEnabled = enabled
        if enabled, hostedProviderView == nil {
            setProviderModeEnabled(false)
        }
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setLocalPreviewEnabled(\(enabled ? "true" : "false"))")
        guard hostedProviderView == nil else { return }
        webView.isHidden = !enabled
        webView.alpha = enabled ? 1 : 0
        webView.isUserInteractionEnabled = enabled
        if enabled {
            fallbackLabel.isHidden = true
        }
    }

    private func setProviderModeEnabled(_ enabled: Bool) {
        providerModeEnabled = enabled
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setProviderMode(\(enabled ? "true" : "false"))")
    }

    func snapshot(completion: @escaping (DigitalHumanLivePanelSnapshot?) -> Void) {
        guard isReady else {
            if didFail {
                completion(DigitalHumanLivePanelSnapshot(object: [
                    "ready": false,
                    "rendererReady": false,
                    "failed": true,
                    "stateName": DigitalHumanLiveInteractionState.failed.rawValue,
                    "audioLevel": 0,
                    "audioLevelSource": DigitalHumanAudioLevelSource.unavailable.rawValue,
                    "lipSyncSource": DigitalHumanAudioLevelSource.unavailable.rawValue,
                    "currentMouthShape": "neutral",
                    "lipSyncFrameCount": 0,
                    "personaName": "",
                    "personaSubtitle": "",
                    "hasRealDigitalHumanAsset": false,
                    "assetVideoReady": false,
                    "hasFallbackAvatar": false
                ]))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.snapshot(completion: completion)
            }
            return
        }
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.snapshot()") { result, _ in
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            completion(DigitalHumanLivePanelSnapshot(object: object))
        }
    }

    private func configureView() {
        backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.32)
        layer.cornerRadius = 28
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.16).cgColor
        accessibilityIdentifier = "digitalHumanLivePanel"

        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.accessibilityIdentifier = "digitalHumanLiveWebView"
        webView.isHidden = true
        webView.alpha = 0
        webView.isUserInteractionEnabled = false

        addSubview(webView)
        addSubview(fallbackLabel)
        [webView, fallbackLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),

            fallbackLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            fallbackLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            fallbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            fallbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    private func loadHTML() {
        guard let url = Bundle.main.url(forResource: "DigitalHumanLive", withExtension: "html") else {
            markFailed("数字人资源缺失")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func markFailed(_ message: String) {
        didFail = true
        fallbackLabel.text = message
        fallbackLabel.isHidden = false
        setInteractionState(.failed)
    }

    private func evaluate(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        let work = { [weak self] in
            guard let self = self else { return }
            guard self.isReady else {
                self.pendingScripts.append(script)
                completion?(nil, nil)
                return
            }
            self.webView.evaluateJavaScript(script, completionHandler: completion)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func flushPendingScripts() {
        let scripts = pendingScripts
        pendingScripts.removeAll()
        scripts.forEach { evaluate($0) }
    }

    private static func javaScriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let encoded = String(data: data, encoding: .utf8),
              encoded.count >= 2 else {
            return "\"\""
        }
        return String(encoded.dropFirst().dropLast())
    }

    private static func audioLevelSource(from source: DigitalHumanPlaybackSource) -> DigitalHumanAudioLevelSource {
        switch source {
        case .avAudioPlayerMetering:
            return .avAudioPlayerMetering
        case .sdkTTSPlaybackFallback:
            return .sdkTTSPlaybackFallback
        case .providerVisemeTimeline:
            return .providerVisemeTimeline
        }
    }
}

extension DigitalHumanLivePanelView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        if providerModeEnabled {
            setProviderModeEnabled(true)
        } else if localPreviewEnabled {
            fallbackLabel.isHidden = true
        } else {
            webView.isHidden = true
            webView.alpha = 0
            webView.isUserInteractionEnabled = false
        }
        flushPendingScripts()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        markFailed("数字人加载失败")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        markFailed("数字人加载失败")
    }
}
