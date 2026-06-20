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

    init(object: [String: Any]) {
        ready = object["ready"] as? Bool ?? false
        rendererReady = object["rendererReady"] as? Bool ?? false
        failed = object["failed"] as? Bool ?? false
        stateName = object["stateName"] as? String ?? "unknown"
        audioLevel = object["audioLevel"] as? Double ?? 0
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
    private var simulatedAudioTimer: Timer?
    private var simulatedPhase: Double = 0
    private(set) var isReady = false
    private(set) var didFail = false

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

    deinit {
        stopSimulatedAudioLevels()
    }

    func setInteractionState(_ state: DigitalHumanLiveInteractionState) {
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setState('\(state.rawValue)')")
        if state == .speaking || state == .listening {
            startSimulatedAudioLevels()
        } else {
            stopSimulatedAudioLevels()
            setAudioLevel(0)
        }
    }

    func setAudioLevel(_ level: Double) {
        let clamped = max(0, min(1, level))
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setAudioLevel(\(clamped))")
    }

    func setPersona(name: String, subtitle: String) {
        let encodedName = Self.javaScriptStringLiteral(name)
        let encodedSubtitle = Self.javaScriptStringLiteral(subtitle)
        evaluate("window.DreamJourneyDigitalHuman && window.DreamJourneyDigitalHuman.setPersona(\(encodedName), \(encodedSubtitle))")
    }

    func startSimulatedAudioLevels() {
        guard simulatedAudioTimer == nil else { return }
        simulatedAudioTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.simulatedPhase += 0.48
            let wave = (sin(self.simulatedPhase) + 1) / 2
            let level = 0.18 + wave * 0.72
            self.setAudioLevel(level)
        }
        if let timer = simulatedAudioTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopSimulatedAudioLevels() {
        simulatedAudioTimer?.invalidate()
        simulatedAudioTimer = nil
        simulatedPhase = 0
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
}

extension DigitalHumanLivePanelView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        fallbackLabel.isHidden = true
        flushPendingScripts()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        markFailed("数字人加载失败")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        markFailed("数字人加载失败")
    }
}
