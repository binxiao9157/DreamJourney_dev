import Foundation

enum RoadshowDemoRoute {
    struct Step: Equatable, Hashable {
        let id: String
        let title: String
        let tabTitle: String
        let durationText: String
        let talkingPoint: String
        let acceptance: String
        let fallback: String
        let iconName: String
        let targetTabIndex: Int
        let evidenceFile: String
    }

    struct EvidenceArtifact: Equatable, Hashable {
        enum Requirement: String, Equatable, Hashable {
            case capture = "现场采集"
            case diagnostic = "诊断复制"
            case export = "导出样本"
            case privacy = "隐私抽查"
            case generated = "脚本生成"
        }

        let category: String
        let title: String
        let path: String
        let note: String
        let requirement: Requirement

        init(
            category: String,
            title: String,
            path: String,
            note: String,
            requirement: Requirement = .capture
        ) {
            self.category = category
            self.title = title
            self.path = path
            self.note = note
            self.requirement = requirement
        }
    }

    struct EvidenceClosureSummary: Equatable {
        let totalCount: Int
        let captureCount: Int
        let diagnosticCount: Int
        let exportCount: Int
        let privacyCount: Int
        let generatedCount: Int

        var manualEvidenceCount: Int {
            captureCount + diagnosticCount + exportCount + privacyCount
        }

        var headline: String {
            "需补齐 \(manualEvidenceCount) 项人工证据，脚本生成 \(generatedCount) 项报告"
        }

        var detail: String {
            "截图/录屏 \(captureCount) · 诊断 \(diagnosticCount) · 分享包 \(exportCount) · 隐私抽查 \(privacyCount)"
        }
    }

    struct CompletionSummary: Equatable {
        let completedCount: Int
        let totalCount: Int
        let nextStepID: String?
        let nextStepTitle: String?

        var progressText: String {
            "演示进度 \(completedCount)/\(totalCount)"
        }

        var compactProgressText: String {
            "\(completedCount)/\(totalCount)"
        }

        var completionPercent: Int {
            guard totalCount > 0 else { return 0 }
            return Int((Double(completedCount) / Double(totalCount) * 100).rounded())
        }

        var hostStatusText: String {
            if let nextStepTitle {
                return "下一步：\(nextStepTitle) · 完成 \(completionPercent)%"
            }
            return "六步闭环已完成 · 可复制验收清单"
        }

        var primaryActionTitle: String {
            nextStepTitle == nil ? "复盘" : "下一步"
        }
    }

    static let completionKeyPrefix = "dreamjourney.roadshow.route.completed."

    static func steps() -> [Step] {
        [
            Step(
                id: "voice_companion",
                title: "语音陪伴与数字人",
                tabTitle: "回忆",
                durationText: "1 分钟",
                talkingPoint: "从一句日常近况开始，展示 AI 只做倾听、复述和整理，不做诊断、不冒充亲人。",
                acceptance: "能看到对话/数字人状态变化；mock 或真实语音异常时主线仍可继续。",
                fallback: "断网或语音 SDK 异常时切到 mock 对话，说明这是本机演示链路。",
                iconName: "mic.circle.fill",
                targetTabIndex: 0,
                evidenceFile: "screens/03_memory_voice_digital_human.png"
            ),
            Step(
                id: "time_mailbox",
                title: "时空信箱边界",
                tabTitle: "信箱",
                durationText: "1 分钟",
                talkingPoint: "打开已投递信件，强调回声来自授权记忆线索，不是逝者真实回复。",
                acceptance: "信件可打开，回声文案包含边界说明，私密正文不进入分享包。",
                fallback: "若无 seed 信件，使用 reset+seed 参数重启；若仍为空，直接展示文档里的边界口播。",
                iconName: "envelope.open.fill",
                targetTabIndex: 3,
                evidenceFile: "screens/04_time_mailbox_delivered_letter.png"
            ),
            Step(
                id: "memory_archive",
                title: "记忆档案馆",
                tabTitle: "档案",
                durationText: "1 分钟",
                talkingPoint: "展示文字、口头禅、旧照片分析，说明哪些素材可生成，哪些只留本机。",
                acceptance: "至少有文本和照片条目；照片分析可展示人物、场景、年代或 mock 分析结果。",
                fallback: "没有网络时使用 seed 的 analyzed/mock analyzed 结果，不现场上传新照片。",
                iconName: "archivebox.fill",
                targetTabIndex: 4,
                evidenceFile: "screens/05_memory_archive_photo_analysis.png"
            ),
            Step(
                id: "family_footprint",
                title: "家族足迹点亮",
                tabTitle: "足迹",
                durationText: "1 分钟",
                talkingPoint: "切换城市、全国、世界和不同代际，展示一家人的世界如何被一代代点亮。",
                acceptance: "地图有青色点亮区域；海报按钮能生成当前筛选状态的分享图。",
                fallback: "地图底图不可用时，仍用本地海报合成图讲清楚足迹变迁。",
                iconName: "map.fill",
                targetTabIndex: 1,
                evidenceFile: "screens/06_family_footprint_world_generation.png"
            ),
            Step(
                id: "care_dashboard",
                title: "亲友关怀看板",
                tabTitle: "亲友",
                durationText: "1 分钟",
                talkingPoint: "展示睡眠、情绪、身体等脱敏聚合信号和 7 天趋势，强调不是医疗诊断。",
                acceptance: "看板展示观测窗口、数据覆盖、7 天趋势、脱敏观察报告和建议；分享周报不展示完整原文。",
                fallback: "若真实对话不足，使用 roadshow seed transcript 生成看板。",
                iconName: "person.2.wave.2.fill",
                targetTabIndex: 2,
                evidenceFile: "screens/07_family_care_dashboard_member.png"
            ),
            Step(
                id: "family_share",
                title: "分享包与隐私收口",
                tabTitle: "档案",
                durationText: "1 分钟",
                talkingPoint: "导出全体亲友或单个成员分享包，说明只分享授权摘要和脱敏信号。",
                acceptance: "分享对象可选择；分享包不含 localOnly、私密原文或未授权成员内容。",
                fallback: "现场不导出文件时，展示清单中的三条边界文案作为收口。",
                iconName: "square.and.arrow.up.fill",
                targetTabIndex: 4,
                evidenceFile: "screens/08_share_package_export_sheet.png"
            )
        ]
    }

    static func boundaryNotices() -> [String] {
        RoadshowDemoSeed.makePackage().boundaryNotices
    }

    static func launchRecipe(status: RoadshowDemoSeed.RuntimeStatus) -> String {
        if status.offlineMode {
            return "--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode"
        }
        return "--reset-roadshow-demo --seed-roadshow-demo"
    }

    static func completionKey(for stepID: String) -> String {
        completionKeyPrefix + stepID
    }

    static func completionSummary(
        steps: [Step] = RoadshowDemoRoute.steps(),
        userDefaults: UserDefaults = .standard
    ) -> CompletionSummary {
        let completedSteps = steps.filter { userDefaults.bool(forKey: completionKey(for: $0.id)) }
        let nextStep = nextIncompleteStep(steps: steps, userDefaults: userDefaults)
        return CompletionSummary(
            completedCount: completedSteps.count,
            totalCount: steps.count,
            nextStepID: nextStep?.id,
            nextStepTitle: nextStep?.title
        )
    }

    static func nextIncompleteStep(
        steps: [Step] = RoadshowDemoRoute.steps(),
        userDefaults: UserDefaults = .standard
    ) -> Step? {
        steps.first { !userDefaults.bool(forKey: completionKey(for: $0.id)) }
    }

    static func completionChecklistText(
        steps: [Step] = RoadshowDemoRoute.steps(),
        userDefaults: UserDefaults = .standard
    ) -> String {
        let summary = completionSummary(steps: steps, userDefaults: userDefaults)
        var lines = [
            "路演验收进度 \(summary.completedCount)/\(summary.totalCount)",
            "启动参数：\(launchRecipe(status: RoadshowDemoSeed.runtimeStatus(userDefaults: userDefaults)))",
            ""
        ]
        lines.append(contentsOf: steps.map { step in
            let mark = userDefaults.bool(forKey: completionKey(for: step.id)) ? "[x]" : "[ ]"
            return "\(mark) \(step.title) - \(step.acceptance) 证据：\(step.evidenceFile)"
        })
        lines.append(contentsOf: ["", "边界声明"])
        lines.append(contentsOf: boundaryNotices().map { "- \($0)" })
        return lines.joined(separator: "\n")
    }

    static func resetCompletions(
        steps: [Step] = RoadshowDemoRoute.steps(),
        userDefaults: UserDefaults = .standard
    ) {
        steps.forEach { userDefaults.removeObject(forKey: completionKey(for: $0.id)) }
    }

    static func targetTabIndex(for stepID: String) -> Int? {
        steps().first(where: { $0.id == stepID })?.targetTabIndex
    }

    static func evidenceArtifacts(steps: [Step] = RoadshowDemoRoute.steps()) -> [EvidenceArtifact] {
        let routeScreens = [
            EvidenceArtifact(
                category: "截图",
                title: "首页路演入口",
                path: "screens/01_home_banner.png",
                note: "显示路演 Banner、进度、下一步和继续/路线入口。"
            ),
            EvidenceArtifact(
                category: "截图",
                title: "路演路线清单",
                path: "screens/02_route_checklist.png",
                note: "显示六阶段路线、完成勾选和证据中心。"
            )
        ]
        let stepScreens = steps.map { step in
            EvidenceArtifact(
                category: "截图",
                title: step.title,
                path: step.evidenceFile,
                note: step.acceptance
            )
        }
        let supportingArtifacts = [
            EvidenceArtifact(
                category: "录屏",
                title: "六分钟主线录屏",
                path: "recordings/roadshow_6min_run.mp4",
                note: "从首页主持驾驶舱开始，按六阶段跑完整主线。"
            ),
            EvidenceArtifact(
                category: "验收",
                title: "路线验收清单",
                path: "route_completion/route_acceptance_checklist.md",
                note: "粘贴 App 内“复制验收”的文本输出。"
            ),
            EvidenceArtifact(
                category: "分享包",
                title: "全体亲友分享包",
                path: "share_packages/all_family.json",
                note: "用于抽查不含 localOnly、私密原文和完整对话。",
                requirement: .export
            ),
            EvidenceArtifact(
                category: "分享包",
                title: "单成员分享包",
                path: "share_packages/selected_member.json",
                note: "用于抽查成员级裁剪和未授权成员清理。",
                requirement: .export
            ),
            EvidenceArtifact(
                category: "隐私",
                title: "分享包隐私抽查",
                path: "share_packages/privacy_check.log",
                note: "记录分享包 JSON 抽查结果。",
                requirement: .privacy
            ),
            EvidenceArtifact(
                category: "日志",
                title: "控制台样本",
                path: "app_console_sample.log",
                note: "保留 RoadshowDemo、DigitalHumanSpeech 和安全兜底关键日志。"
            ),
            EvidenceArtifact(
                category: "诊断",
                title: "数字人诊断文本",
                path: "diagnostics/digital_human_readiness.txt",
                note: "粘贴 App 内数字人诊断“复制”输出，确认配置状态且不含密钥。",
                requirement: .diagnostic
            ),
            EvidenceArtifact(
                category: "诊断",
                title: "数字人诊断 JSON",
                path: "diagnostics/digital_human_readiness.json",
                note: "粘贴 App 内数字人诊断“复制 JSON”输出，用于机器可读排障。",
                requirement: .diagnostic
            ),
            EvidenceArtifact(
                category: "诊断",
                title: "数字人播放日志",
                path: "diagnostics/digital_human_playback.log",
                note: "保留 native_audio、system_tts、timeout 三种音频链路收口日志样本。",
                requirement: .diagnostic
            ),
            EvidenceArtifact(
                category: "报告",
                title: "证据完整度 JSON",
                path: "evidence_status.json",
                note: "由 roadshow_evidence_report.py 生成的机器可读状态。",
                requirement: .generated
            ),
            EvidenceArtifact(
                category: "报告",
                title: "证据完整度 Markdown",
                path: "evidence_status.md",
                note: "给路演/复盘查看的缺失项报告。",
                requirement: .generated
            )
        ]
        return routeScreens + stepScreens + supportingArtifacts
    }

    static func evidenceClosureSummary(steps: [Step] = RoadshowDemoRoute.steps()) -> EvidenceClosureSummary {
        let artifacts = evidenceArtifacts(steps: steps)
        return EvidenceClosureSummary(
            totalCount: artifacts.count,
            captureCount: artifacts.filter { $0.requirement == .capture }.count,
            diagnosticCount: artifacts.filter { $0.requirement == .diagnostic }.count,
            exportCount: artifacts.filter { $0.requirement == .export }.count,
            privacyCount: artifacts.filter { $0.requirement == .privacy }.count,
            generatedCount: artifacts.filter { $0.requirement == .generated }.count
        )
    }

    static func evidenceStatusGuide() -> [(status: String, meaning: String)] {
        [
            ("needs_preflight", "脚手架或自动 build/device 上下文缺失，先重跑 preflight。"),
            ("needs_privacy_review", "证据文本疑似带出 key/token/secret，先删除或脱敏。"),
            ("needs_manual_evidence", "还缺逐屏截图、录屏、诊断或分享包样本。"),
            ("complete", "清单内证据齐全，且隐私扫描未发现 token 形态内容。")
        ]
    }

    static func evidenceReportCommand(evidenceDirectory: String = "<evidence-dir>") -> String {
        "python3 Scripts/roadshow_evidence_report.py \(evidenceDirectory) --write --fail-on-missing"
    }

    static func evidenceArchiveCommand(evidenceDirectory: String = "<evidence-dir>") -> String {
        "python3 Scripts/roadshow_evidence_report.py \(evidenceDirectory) --write --archive --fail-on-missing"
    }

    static func evidenceGuideText(steps: [Step] = RoadshowDemoRoute.steps()) -> String {
        var lines = [
            "路演证据中心",
            "启动参数：\(launchRecipe(status: RoadshowDemoSeed.runtimeStatus()))",
            evidenceClosureSummary(steps: steps).headline,
            evidenceClosureSummary(steps: steps).detail,
            "",
            "收口顺序",
            "1. 运行 Scripts/roadshow_device_smoke_preflight.sh 生成 evidence 目录。",
            "2. 按路线补齐截图、录屏、分享包、诊断文本和诊断 JSON。",
            "3. 运行 roadshow_evidence_report.py --write --fail-on-missing。",
            "4. 若状态为 needs_privacy_review，先脱敏日志/JSON 后再归档。",
            "",
            "状态说明"
        ]
        lines.append(contentsOf: evidenceStatusGuide().map { "- \($0.status)：\($0.meaning)" })
        lines.append(contentsOf: [
            "",
            "证据文件清单"
        ])
        lines.append(contentsOf: evidenceArtifacts(steps: steps).map { artifact in
            "- [\(artifact.requirement.rawValue)/\(artifact.category)] \(artifact.title)：\(artifact.path) - \(artifact.note)"
        })
        lines.append(contentsOf: [
            "",
            "收口命令",
            evidenceReportCommand(),
            "",
            "归档命令",
            evidenceArchiveCommand(),
            "生成 dreamjourney_roadshow_evidence.zip；包内 archive_inventory.json 记录每个证据文件的 sizeBytes 和 sha256。",
            "",
            "目标状态：complete；若出现 needs_privacy_review，不外发 evidence 包。"
        ])
        return lines.joined(separator: "\n")
    }
}
