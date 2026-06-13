#!/usr/bin/env python3
from pathlib import Path
import sys

vc = Path("DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift").read_text()
models = Path("DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift").read_text()

share_function = vc.split("@objc private func shareReportTapped()", 1)[-1].split("private func reloadSnapshot()", 1)[0]

checks = [
    (
        "care dashboard should expose both refresh and share navigation actions",
        "rightBarButtonItems" in vc
        and "shareReportTapped" in vc
        and "refreshTapped" in vc,
    ),
    (
        "share action should use the sanitized report descriptor",
        "CareDashboardShareReportDescriptor.make" in vc
        and "descriptor.plainText" in vc,
    ),
    (
        "share action should use system share sheet for report text",
        "UIActivityViewController" in vc
        and "activityItems: [descriptor.plainText]" in vc,
    ),
    (
        "share action should not directly share raw transcript or input turns",
        "activityItems: [turns" not in share_function
        and "activityItems: [snapshot" not in share_function
        and "getCurrentTranscript()" not in share_function,
    ),
    (
        "share action should reject insufficient-data snapshots instead of exporting an empty report",
        "canShareCareReport(snapshot)" in share_function
        and "真实关怀数据不足" in share_function,
    ),
    (
        "care dashboard should show a real-data empty state for insufficient local care input",
        "makeInsufficientDataState" in vc
        and "亲友范围" in vc
        and "真实对话" in vc,
    ),
    (
        "report descriptor should state no raw chat content and no medical diagnosis",
        "不包含原始聊天内容" in models
        and "不是医疗诊断" in models,
    ),
    (
        "report descriptor should be built from CareSignalSnapshot fields",
        "snapshot.summary" in models
        and "snapshot.suggestions" in models
        and "snapshot.riskSignalDescriptions" in models,
    ),
    (
        "care dashboard should render aggregate trend from snapshot daily trend points",
        "makeTrendCard(snapshot)" in vc
        and "snapshot.dailyTrend" in vc
        and "snapshot.trendSummary" in vc
        and "CareSignalDailyTrendPoint" in vc,
    ),
    (
        "share report should include trend observation from snapshot",
        "趋势观察" in models
        and "snapshot.trendSummary" in models,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"CareDashboardShareReportUI verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("CareDashboardShareReportUI verification passed")
