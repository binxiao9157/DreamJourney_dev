#!/usr/bin/env python3
from pathlib import Path
import sys

toast = Path("DreamJourney/Sources/Common/UI/TGToast.swift").read_text()
project = Path("DreamJourney.xcodeproj/project.pbxproj").read_text()
preflight = Path("Scripts/roadshow_device_smoke_preflight.sh").read_text()

checks = [
    (
        "TGToast should use UIWindowScene instead of deprecated UIApplication.shared.windows",
        "UIApplication.shared.windows" not in toast
        and "connectedScenes" in toast
        and "UIWindowScene" in toast
        and "first { $0.isKeyWindow }" in toast,
    ),
    (
        "Copy LocalConfig build phase should declare a marker output",
        "Copy LocalConfig.plist" in project
        and "$(DERIVED_FILE_DIR)/LocalConfig.copy.done" in project
        and 'MARKER=\\"${DERIVED_FILE_DIR}/LocalConfig.copy.done\\"' in project,
    ),
    (
        "Copy LocalConfig build phase should always write the marker",
        'date > \\"$MARKER\\"' in project
        and 'mkdir -p \\"$(dirname \\"$MARKER\\")\\"' in project,
    ),
    (
        "preflight should ask for digital-human diagnostics evidence",
        "diagnostics/digital_human_readiness.txt" in preflight
        and "diagnostics/digital_human_readiness.json" in preflight
        and "Documents/diagnostics/digital_human_readiness.txt" in preflight
        and "Documents/diagnostics/digital_human_readiness.json" in preflight,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"BuildWarningCleanup verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("BuildWarningCleanup verification passed")
