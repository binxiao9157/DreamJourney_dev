#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
VERIFY = ROOT / "Scripts/verify_phase1.sh"

home = HOME.read_text(encoding="utf-8")
phase1 = VERIFY.read_text(encoding="utf-8")

missing = []

required_fragments = [
    ("private static var isDigitalHumanDiagnosticsEnabled: Bool", "home should define an explicit diagnostics gate"),
    ('"--show-digital-human-diagnostics"', "diagnostics gate should support a launch argument"),
    ('"DREAMJOURNEY_SHOW_DIGITAL_HUMAN_DIAGNOSTICS"', "diagnostics gate should support an environment override"),
    ("if Self.isDigitalHumanDiagnosticsEnabled {", "diagnostics UI/evidence should be guarded by the gate"),
    ("configureDigitalHumanDiagnosticsIfNeeded()", "diagnostics setup should be isolated behind a helper"),
    ("guard Self.isDigitalHumanDiagnosticsEnabled else { return }", "diagnostics tap should no-op unless explicitly enabled"),
    ("DigitalHumanDiagnosticsGateVerify/main.py", "phase1 verification should include the diagnostics gate check"),
]

for fragment, message in required_fragments:
    haystack = phase1 if fragment.endswith("main.py") else home
    if fragment not in haystack:
        missing.append(message)

if "DigitalHumanReadinessReport.make().persistEvidenceFiles()" in home:
    guarded_pattern = re.compile(
        r"if Self\.isDigitalHumanDiagnosticsEnabled \{\s*DigitalHumanReadinessReport\.make\(\)\.persistEvidenceFiles\(\)\s*\}",
        re.S,
    )
    if not guarded_pattern.search(home):
        missing.append("home should not persist diagnostics evidence during ordinary startup")

setup_layout = re.search(
    r"private func setupLayout\(\) \{(?P<body>[\s\S]*?)\n    private func configureDigitalHumanDiagnosticsIfNeeded",
    home,
)
if not setup_layout:
    missing.append("setupLayout should exist before the diagnostics gate helper")
elif "view.addSubview(digitalHumanDiagnosticsButton)" in setup_layout.group("body"):
    missing.append("diagnostics button should not be added unconditionally to the home UI")

helper = re.search(
    r"private func configureDigitalHumanDiagnosticsIfNeeded\(\) \{(?P<body>[\s\S]*?)\n    \}",
    home,
)
if helper and "guard Self.isDigitalHumanDiagnosticsEnabled else { return }" not in helper.group("body"):
    missing.append("diagnostics helper should guard before adding the button")

if re.search(r"NSLayoutConstraint\.activate\(\[[\s\S]*digitalHumanDiagnosticsButton\.widthAnchor\.constraint", home):
    if not helper or "digitalHumanDiagnosticsButton.widthAnchor.constraint" not in helper.group("body"):
        missing.append("diagnostics constraints should live inside the gated setup helper")

if missing:
    for message in missing:
        print(f"DigitalHumanDiagnosticsGate verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHumanDiagnosticsGate verification passed")
