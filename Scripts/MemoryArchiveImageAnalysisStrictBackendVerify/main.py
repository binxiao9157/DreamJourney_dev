#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

vc_file = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

vc_text = vc_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

missing = []

match = re.search(
    r"private func analyzePhotoViaBackendOrDirect\([\s\S]*?\n    private func analyzePhotoDirectly",
    vc_text,
)
if not match:
    raise SystemExit(f"{vc_file.name}: missing analyzePhotoViaBackendOrDirect implementation")

body = match.group(0)

required_fragments = [
    "PrivacyScopePolicy.canUse(metadata: item.privacyMetadata, surface: .remoteExtraction)",
    "guard DreamJourneyBackendClient.shared.isConfigured else",
    "setKnowledgeDepositStatus(\"结构化建库：照片分析使用本机 DeepSeek 直连\")",
    "analyzePhotoDirectly(imageBase64: imageBase64, completion: completion)",
    "setKnowledgeDepositStatus(\"结构化建库：照片分析使用后端代理\")",
    "DreamJourneyBackendClient.shared.analyzeArchiveImage",
    "case .failure(let error):",
    "setKnowledgeDepositStatus(\"结构化建库：后端代理照片分析失败，不做本机兜底\")",
    "completion(.failure(error))",
]
for fragment in required_fragments:
    if fragment not in body:
        missing.append(f"{vc_file.name}: strict backend photo analysis missing {fragment!r}")

failure_match = re.search(
    r"case \.failure\(let error\):(?P<body>[\s\S]*?)\n            \}",
    body,
)
if not failure_match:
    missing.append(f"{vc_file.name}: cannot inspect backend failure branch")
else:
    failure_body = failure_match.group("body")
    prohibited_failure_fragments = [
        "analyzePhotoDirectly(",
        "DeepSeekService.shared.analyzeImage",
        "回落本机",
        "fallback",
    ]
    for fragment in prohibited_failure_fragments:
        if fragment in failure_body:
            missing.append(
                f"{vc_file.name}: backend-configured image analysis failure must not silently fall back via {fragment!r}"
            )

if "MemoryArchiveImageAnalysisStrictBackendVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing MemoryArchiveImageAnalysisStrictBackendVerify/main.py")

if missing:
    raise SystemExit("\n".join(missing))

print("MemoryArchiveImageAnalysisStrictBackend verification passed")
