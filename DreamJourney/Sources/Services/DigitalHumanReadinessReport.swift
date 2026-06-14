import Foundation

// MARK: - Digital Human Readiness Report

struct DigitalHumanReadinessReport: Equatable {
    enum Status: String, Equatable {
        case ready
        case warning
        case missing

        var title: String {
            switch self {
            case .ready:
                return "已就绪"
            case .warning:
                return "需关注"
            case .missing:
                return "需配置"
            }
        }
    }

    struct Item: Equatable {
        let title: String
        let status: Status
        let detail: String
        let recommendation: String
    }

    let title: String
    let subtitle: String
    let items: [Item]

    static let evidenceTextRelativePath = "diagnostics/digital_human_readiness.txt"
    static let evidenceJSONRelativePath = "diagnostics/digital_human_readiness.json"

    var primaryStatus: Status {
        if items.contains(where: { $0.status == .missing }) { return .missing }
        if items.contains(where: { $0.status == .warning }) { return .warning }
        return .ready
    }

    var compactTitle: String {
        "\(primaryStatus.title) · \(subtitle)"
    }

    var copyableText: String {
        var lines = [
            "数字人真机诊断",
            "总体：\(primaryStatus.title)",
            "摘要：\(subtitle)"
        ]
        lines.append(contentsOf: items.map { "- \($0.title)：\($0.status.title)，\($0.detail)" })
        lines.append(contentsOf: ["", "修复建议"])
        lines.append(contentsOf: items.map { "- \($0.title)：\($0.recommendation)" })
        lines.append(contentsOf: ["", "音频链路验收"])
        lines.append(contentsOf: DigitalHumanSpeechPlaybackPolicy.playbackEvidenceChecks().map { check in
            "- \(check.title)：日志 \(check.expectedLog)；验收：\(check.acceptance)"
        })
        lines.append("说明：诊断文本只呈现配置状态，不包含任何 API Key、Token 或 Secret。")
        return lines.joined(separator: "\n")
    }

    func persistEvidenceFiles(fileManager: FileManager = .default) {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let textURL = documentsURL.appendingPathComponent(Self.evidenceTextRelativePath)
        let jsonURL = documentsURL.appendingPathComponent(Self.evidenceJSONRelativePath)
        let diagnosticsURL = textURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        try? copyableText.write(to: textURL, atomically: true, encoding: .utf8)
        try? evidenceJSONText.write(to: jsonURL, atomically: true, encoding: .utf8)
    }

    var evidenceJSONText: String {
        let payload: [String: Any] = [
            "title": title,
            "status": primaryStatus.rawValue,
            "statusTitle": primaryStatus.title,
            "subtitle": subtitle,
            "items": items.map { item in
                [
                    "title": item.title,
                    "status": item.status.rawValue,
                    "statusTitle": item.status.title,
                    "detail": item.detail,
                    "recommendation": item.recommendation
                ]
            },
            "playbackEvidenceChecks": DigitalHumanSpeechPlaybackPolicy.playbackEvidenceChecks().map { check in
                [
                    "title": check.title,
                    "source": check.source,
                    "expectedLog": check.expectedLog,
                    "acceptance": check.acceptance
                ]
            },
            "redaction": "No API Key, Token, Secret, or realtime request header is included."
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func make(
        infoDictionary: [String: Any] = AppConfiguration.mergedInfoDictionary(),
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DigitalHumanReadinessReport {
        let ttsItem = makeTTSItem(infoDictionary: infoDictionary)
        let realtimeItem = makeRealtimeItem(infoDictionary: infoDictionary)
        let dialogItem = makeDialogItem(
            realtimeItem: realtimeItem,
            arguments: arguments,
            environment: environment
        )
        let backendItem = makeDreamJourneyBackendItem(infoDictionary: infoDictionary)

        let readyCount = [ttsItem, realtimeItem, dialogItem, backendItem]
            .filter { $0.status == .ready }
            .count
        let subtitle: String
        if dialogItem.status == .warning {
            subtitle = "本机测试引擎 · \(readyCount)/4 项就绪"
        } else if ttsItem.status == .ready && realtimeItem.status == .ready {
            subtitle = "真实语音链路 · \(readyCount)/4 项就绪"
        } else {
            subtitle = "降级可用 · \(readyCount)/4 项就绪"
        }

        return DigitalHumanReadinessReport(
            title: "数字人真机诊断",
            subtitle: subtitle,
            items: [dialogItem, ttsItem, realtimeItem, backendItem]
        )
    }

    private static func makeTTSItem(infoDictionary: [String: Any]) -> Item {
        let hasAPIKey = VolcEngineCredentialProvider.apiKey(infoDictionary: infoDictionary) != nil
        let hasVoiceType = VolcEngineCredentialProvider.voiceType(infoDictionary: infoDictionary) != nil

        switch (hasAPIKey, hasVoiceType) {
        case (true, true):
            return Item(
                title: "数字人口型 TTS",
                status: .ready,
                detail: "WAV 合成可走新版 API Key 和已配置音色",
                recommendation: "可直接真机验证 WAV 出声、口型同步和断网兜底。"
            )
        case (true, false):
            return Item(
                title: "数字人口型 TTS",
                status: .warning,
                detail: "API Key 已有，但缺少 VolcEngineVoiceType；会退回系统语音",
                recommendation: "补充 VolcEngineVoiceType，例如控制台音色或 speaker id。"
            )
        case (false, true):
            return Item(
                title: "数字人口型 TTS",
                status: .warning,
                detail: "音色已配置，但缺少 VolcEngineAPIKey；会退回系统语音",
                recommendation: "补充 VolcEngineAPIKey；不要把 key 写入 Info.plist。"
            )
        case (false, false):
            return Item(
                title: "数字人口型 TTS",
                status: .missing,
                detail: "缺少 VolcEngineAPIKey 和 VolcEngineVoiceType",
                recommendation: "补齐 VolcEngineAPIKey 和 VolcEngineVoiceType 后再测数字人口型。"
            )
        }
    }

    private static func makeRealtimeItem(infoDictionary: [String: Any]) -> Item {
        guard let credentials = VolcEngineRealtimeCredentialProvider.credentials(from: infoDictionary) else {
            return Item(
                title: "实时语音对话",
                status: .missing,
                detail: "缺少实时 API Key 或旧式 AppID/AppKey/Token 三件套",
                recommendation: "优先补齐 VolcEngineAppID、VolcEngineAppKey、VolcEngineAppToken；如控制台提供实时 API Key 再配 VolcEngineRealtimeAPIKey。"
            )
        }

        if credentials.isModernAPIKeyMode {
            return Item(
                title: "实时语音对话",
                status: .ready,
                detail: "使用实时 API Key 模式，资源：\(credentials.resourceID)",
                recommendation: "可直接真机验证 ASR、LLM 回复和播报生命周期。"
            )
        }
        return Item(
            title: "实时语音对话",
            status: .ready,
            detail: "使用旧式三件套模式，资源：\(credentials.resourceID)",
            recommendation: "当前配置适合优先联调火山实时对话 SDK。"
        )
    }

    private static func makeDialogItem(
        realtimeItem: Item,
        arguments: [String],
        environment: [String: String]
    ) -> Item {
        let engineValue = environment["DREAMJOURNEY_DIALOG_ENGINE"]?.lowercased()
        let usesMock = arguments.contains("--use-mock-dialog-engine") ||
            engineValue == "mock"

        if usesMock {
            return Item(
                title: "当前对话引擎",
                status: .warning,
                detail: "当前使用本机测试对话引擎",
                recommendation: "真实验证请移除 mock 启动参数，并确认实时语音凭证已配置。"
            )
        }
        if realtimeItem.status == .ready {
            return Item(
                title: "当前对话引擎",
                status: .ready,
                detail: "将尝试使用火山实时对话 SDK",
                recommendation: "保持网络可用，开始真机语音 smoke。"
            )
        }
        return Item(
            title: "当前对话引擎",
            status: .missing,
            detail: "真实引擎缺凭证，无法进行端到端语音联调",
            recommendation: "补齐实时语音凭证后再进行真机 smoke。"
        )
    }

    private static func makeDreamJourneyBackendItem(infoDictionary: [String: Any]) -> Item {
        guard let configuredURL = validString(infoDictionary["DreamJourneyBackendBaseURL"] as? String) else {
            return Item(
                title: "DreamJourney 后端",
                status: .warning,
                detail: "未配置 DreamJourneyBackendBaseURL，知识同步停留在本机",
                recommendation: "真机测试先配置为 https://www.mmdd10.tech/dreamjourney-api；正式域名放行后切到 dreamjourney-api.liftora.cn。"
            )
        }

        let lowercased = configuredURL.lowercased()
        if lowercased.contains("localhost") || lowercased.contains("127.0.0.1") {
            return Item(
                title: "DreamJourney 后端",
                status: .warning,
                detail: "配置为本机地址；真机需改为局域网 IP 或可访问域名",
                recommendation: "把 DreamJourneyBackendBaseURL 改成 HTTPS 后端地址。"
            )
        }
        return Item(
            title: "DreamJourney 后端",
            status: .ready,
            detail: "已配置真机可访问的业务后端地址",
            recommendation: "可验证 runtime、KBLite 同步、高德代理和实时语音配置接口。"
        )
    }

    private static func validString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let uppercased = trimmed.uppercased()
        guard !uppercased.hasPrefix("YOUR_"),
              !uppercased.hasPrefix("$("),
              !uppercased.contains("PLACEHOLDER"),
              !uppercased.contains("填入"),
              !uppercased.contains("你的") else {
            return nil
        }
        return trimmed
    }
}
