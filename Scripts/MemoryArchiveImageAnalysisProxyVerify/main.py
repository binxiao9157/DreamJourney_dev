#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
backend_main_file = ROOT / "DreamJourneyBackend/app/main.py"
backend_service_file = ROOT / "DreamJourneyBackend/app/services/deepseek.py"
backend_tests_file = ROOT / "DreamJourneyBackend/tests/test_core_services.py"
roadshow_preflight_file = ROOT / "Scripts/roadshow_device_smoke_preflight.sh"
current_report_file = ROOT / "docs/superpowers/reports/2026-06-13-phase1-continuous-progress.md"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

missing = []

client_text = client_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
backend_main_text = backend_main_file.read_text(encoding="utf-8")
backend_service_text = backend_service_file.read_text(encoding="utf-8") if backend_service_file.exists() else ""
backend_tests_text = backend_tests_file.read_text(encoding="utf-8")
roadshow_preflight_text = roadshow_preflight_file.read_text(encoding="utf-8")
current_report_text = current_report_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

required_client_fragments = [
    "func analyzeArchiveImage",
    'path: "archive/image-analysis"',
    "imageBase64",
    "KBImageAnalysisResult",
]

required_vc_fragments = [
    "analyzePhotoViaBackendOrDirect",
    "DreamJourneyBackendClient.shared.analyzeArchiveImage",
    "DeepSeekService.shared.analyzeImage",
]

required_backend_fragments = [
    '@app.post("/archive/image-analysis")',
    "DeepSeekImageAnalysisProxy",
    "image_base64",
    "dryRun",
]

required_service_fragments = [
    "class DeepSeekImageAnalysisProxy",
    "def build_request",
    "def request_analysis",
    "data:image/jpeg;base64,",
    "estimatedDecade",
    "extract_json_substring",
]

required_backend_test_fragments = [
    "test_archive_image_analysis_dry_run_redacts_secret",
    "test_archive_image_analysis_requires_image_base64",
    "test_archive_image_analysis_without_key_returns_unavailable",
    "/archive/image-analysis",
    "Authorization",
    "DEEPSEEK_API_KEY is not configured",
]

prohibited_validation_fragments = [
    "mock photo analysis",
    "照片 mock analysis",
]

for fragment in required_client_fragments:
    if fragment not in client_text:
        missing.append(f"{client_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
for fragment in required_backend_fragments:
    if fragment not in backend_main_text:
        missing.append(f"{backend_main_file.name}: missing {fragment!r}")
for fragment in required_service_fragments:
    if fragment not in backend_service_text:
        missing.append(f"{backend_service_file.name}: missing {fragment!r}")
for fragment in required_backend_test_fragments:
    if fragment not in backend_tests_text:
        missing.append(f"{backend_tests_file.name}: missing {fragment!r}")
if "MemoryArchiveImageAnalysisProxyVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing MemoryArchiveImageAnalysisProxyVerify/main.py")
for fragment in prohibited_validation_fragments:
    if fragment in roadshow_preflight_text:
        missing.append(f"{roadshow_preflight_file.name}: prohibited stale validation wording {fragment!r}")
    if fragment in current_report_text:
        missing.append(f"{current_report_file.name}: prohibited stale validation wording {fragment!r}")

if missing:
    raise SystemExit("\n".join(missing))

print("MemoryArchiveImageAnalysisProxy verification passed")
