#!/usr/bin/env python3
from pathlib import Path
import sys

home_vc = Path("DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift").read_text()
diagnostics_vc = Path("DreamJourney/Sources/Modules/Home/DigitalHumanDiagnosticsViewController.swift").read_text()
report = Path("DreamJourney/Sources/Services/DigitalHumanReadinessReport.swift").read_text()
project = Path("DreamJourney.xcodeproj/project.pbxproj").read_text()

checks = [
    (
        "home screen exposes a diagnostics button",
        "digitalHumanDiagnosticsButton" in home_vc
        and "accessibilityLabel = \"数字人真机诊断\"" in home_vc
        and "digitalHumanDiagnosticsTapped" in home_vc,
    ),
    (
        "diagnostics button opens a sheet-style diagnostics controller",
        "DigitalHumanReadinessReport.make()" in home_vc
        and "DigitalHumanDiagnosticsViewController(report: report)" in home_vc
        and "sheet.detents = [.medium(), .large()]" in home_vc,
    ),
    (
        "diagnostics page is scrollable and copyable",
        "UIScrollView()" in diagnostics_vc
        and "contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)" in diagnostics_vc
        and "copyDiagnostics" in diagnostics_vc
        and "copyDiagnosticsJSON" in diagnostics_vc
        and "UIPasteboard.general.string = report.copyableText" in diagnostics_vc,
    ),
    (
        "diagnostics page exposes remediation and JSON evidence copy",
        "建议：" in diagnostics_vc
        and "UIPasteboard.general.string = report.evidenceJSONText" in diagnostics_vc
        and "已复制诊断 JSON" in diagnostics_vc,
    ),
    (
        "diagnostics page exposes playback evidence checklist",
        "makePlaybackEvidenceCard" in diagnostics_vc
        and "音频链路验收" in diagnostics_vc
        and "DigitalHumanSpeechPlaybackPolicy.roadshowEvidenceChecks()" in diagnostics_vc
        and "makePlaybackEvidenceRow" in diagnostics_vc
        and "expectedLog" in diagnostics_vc,
    ),
    (
        "diagnostics page states no secrets are displayed",
        "不会显示 API Key、Token 或 Secret" in diagnostics_vc
        and "已复制脱敏诊断信息" in diagnostics_vc,
    ),
    (
        "readiness report avoids raw realtime headers",
        "requestHeadersJSON" not in report
        and "copyableText" in report
        and "不包含任何 API Key、Token 或 Secret" in report,
    ),
    (
        "readiness report copies playback evidence into text and JSON",
        "音频链路验收" in report
        and "playbackEvidenceChecks" in report
        and "roadshowEvidenceChecks" in report,
    ),
    (
        "diagnostics evidence is persisted for device preflight copy",
        "report.persistEvidenceFiles()" in diagnostics_vc
        and "DigitalHumanReadinessReport.make().persistEvidenceFiles()" in home_vc
        and 'static let evidenceTextRelativePath = "diagnostics/digital_human_readiness.txt"' in report
        and 'static let evidenceJSONRelativePath = "diagnostics/digital_human_readiness.json"' in report
        and "try? copyableText.write" in report
        and "try? evidenceJSONText.write" in report,
    ),
    (
        "new Swift files are part of the Xcode project",
        "DigitalHumanReadinessReport.swift in Sources" in project
        and "DigitalHumanDiagnosticsViewController.swift in Sources" in project,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"DigitalHumanDiagnosticsUI verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHumanDiagnosticsUI verification passed")
