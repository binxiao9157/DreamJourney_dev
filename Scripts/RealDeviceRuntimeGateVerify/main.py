#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift"
DIALOG_FACTORY = ROOT / "DreamJourney/Sources/Services/DialogEngineFactory.swift"
REAL_ACCEPTANCE_GATE = ROOT / "DreamJourney/Sources/Services/RealDeviceAcceptanceGate.swift"
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"RealDeviceRuntimeGate verification failed: {message}", file=sys.stderr)
        sys.exit(1)


map_source = MAP.read_text(encoding="utf-8")
dialog_factory = DIALOG_FACTORY.read_text(encoding="utf-8")
real_acceptance_gate = REAL_ACCEPTANCE_GATE.read_text(encoding="utf-8")
home = HOME.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

make_default_match = re.search(r"static func makeDefault[\s\S]*?\n    \}", dialog_factory)
make_default_body = make_default_match.group(0) if make_default_match else ""
selected_type_match = re.search(r"static func selectedType[\s\S]*?\n    \}", dialog_factory)
selected_type_body = selected_type_match.group(0) if selected_type_match else ""

require(
    "includeDemoExpansionOverride" not in map_source,
    "footprint page should not keep a default-visible demo expansion override path",
)
require(
    "includeDemoExpansion: false" in map_source,
    "footprint page should explicitly request real memory points in normal runtime",
)
require(
    "return .volcengine" in selected_type_body,
    "dialog engine default should be the real VolcEngine path",
)
require(
    "--use-mock-dialog-engine" in selected_type_body
    and "DREAMJOURNEY_DIALOG_ENGINE" in selected_type_body,
    "mock dialog engine should remain opt-in by launch arg or env only",
)
require(
    "RealDeviceAcceptanceGate.isEnabled" in selected_type_body
    and "return .volcengine" in selected_type_body,
    "real-device acceptance should force the real dialog engine path",
)
require(
    "DREAMJOURNEY_REAL_ACCEPTANCE" in real_acceptance_gate
    and "DREAMJOURNEY_REAL_DEVICE_ACCEPTANCE" in real_acceptance_gate
    and "--real-acceptance" in real_acceptance_gate,
    "real-device acceptance gate should support env and launch arg activation",
)
require(
    "guard Self.isDigitalHumanDiagnosticsEnabled else { return }" in home,
    "digital human diagnostics UI should remain gated in normal runtime",
)
require(
    "RoadshowDemoRouteViewController" not in home,
    "home should not expose the roadshow route entry in normal runtime",
)
require(
    "RealDeviceRuntimeGateVerify/main.py" in phase1,
    "phase1 verification should include real-device runtime gate coverage",
)

print("RealDeviceRuntimeGate verification passed")
