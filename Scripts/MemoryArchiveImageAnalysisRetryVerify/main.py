#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"

view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

missing = []

required_fragments = [
    ("func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)", "archive list should handle item selection"),
    ("presentArchiveItemActions(for:", "selection should route through an item action presenter"),
    ("retryImageAnalysis(for:", "image materials should expose a retry analysis action"),
    ('UIImage(contentsOfFile: localPath)', "retry should load the archived local image file"),
    ("analyzePhoto(image, item: item)", "retry should reuse the real photo analysis pipeline with privacy metadata"),
    ("PrivacyScopePolicy.canUse(metadata: item.privacyMetadata, surface: .remoteExtraction)", "retry should not bypass the remote extraction privacy gate"),
    ("重新分析照片", "photo retry action should be user-facing"),
    ("重新分析截图", "screenshot retry action should be user-facing"),
    ("照片分析失败，素材已保存", "analysis failure copy should remain visible"),
    ("MemoryArchiveImageAnalysisRetryVerify/main.py", "phase1 verification should include image analysis retry coverage"),
]

for fragment, message in required_fragments:
    haystack = phase1 if fragment.endswith("main.py") else view
    if fragment not in haystack:
        missing.append(message)

retry_match = re.search(r"private func retryImageAnalysis\(for item: MemoryArchiveItem\) \{(?P<body>[\s\S]*?)\n    \}", view)
if not retry_match:
    missing.append("retryImageAnalysis should be implemented as a focused helper")
else:
    retry_body = retry_match.group("body")
    if ".photo || item.kind == .screenshot" not in retry_body:
        missing.append("retry should only accept photo and screenshot materials")
    if "setKnowledgeDepositStatus(\"结构化建库：正在重新分析" not in retry_body:
        missing.append("retry should leave a persistent in-page status while analysis runs")

if missing:
    for message in missing:
        print(f"MemoryArchiveImageAnalysisRetry verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("MemoryArchiveImageAnalysisRetry verification passed")
