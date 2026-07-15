#!/usr/bin/env python3
"""Prevent QA/build tooling from reintroducing long-lived credentials into iOS artifacts."""

from __future__ import annotations

import os
import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]

FORBIDDEN_BUILD_SETTINGS = {
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
}
FORBIDDEN_INFO_KEYS = {
    "DreamJourneyBackendAPIToken",
    "DreamJourneyDeepSeekAPIKey",
    "DreamJourneyVoiceSDKAppId",
    "DreamJourneyVoiceSDKAppKey",
    "DreamJourneyVoiceSDKAppToken",
}

APP_BUILD_SCRIPTS = (
    "Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh",
    "Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh",
    "Scripts/QA/prd-stitch-ui/run-true-device-archive-audio-preflight.sh",
    "Scripts/QA/prd-stitch-ui/run-true-device-voice-preflight.sh",
)
STRICT_NO_CREDENTIAL_REFERENCE_SCRIPTS = {
    "Scripts/QA/prd-stitch-ui/run-true-device-archive-audio-preflight.sh",
    "Scripts/QA/prd-stitch-ui/run-true-device-voice-preflight.sh",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def configured_yaml_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        key = stripped.split(":", 1)[0].strip()
        if key in FORBIDDEN_BUILD_SETTINGS:
            keys.add(key)
    return keys


def check_generator_source() -> None:
    configured = configured_yaml_keys(ROOT / "project.yml")
    require(
        not configured,
        "project.yml can regenerate retired credential build settings: "
        + ", ".join(sorted(configured)),
    )


def check_app_build_scripts() -> None:
    for relative_path in APP_BUILD_SCRIPTS:
        path = ROOT / relative_path
        require(path.is_file(), f"missing app build script: {relative_path}")
        content = path.read_text(encoding="utf-8")

        for key in FORBIDDEN_BUILD_SETTINGS:
            assignment = re.compile(rf"(?:^|\s){re.escape(key)}\s*=", re.MULTILINE)
            require(
                not assignment.search(content),
                f"{relative_path} still assigns retired mobile build setting {key}",
            )
        for key in FORBIDDEN_INFO_KEYS:
            require(
                key not in content,
                f"{relative_path} still writes retired Info.plist key {key}",
            )
        if relative_path in STRICT_NO_CREDENTIAL_REFERENCE_SCRIPTS:
            for key in FORBIDDEN_BUILD_SETTINGS:
                require(
                    key not in content,
                    f"{relative_path} still requires retired mobile credential {key}",
                )

    installer = (ROOT / APP_BUILD_SCRIPTS[0]).read_text(encoding="utf-8")
    require(
        "product-v4-qa-mobile-credential-artifact-check.py" in installer,
        "shared simulator installer must scan every built .app before installation",
    )
    require(
        "QA_MOBILE_CREDENTIAL_APP_PATH" in installer,
        "shared simulator installer must pass the built .app to the artifact guard",
    )


def check_app_artifact() -> None:
    raw_path = os.environ.get("QA_MOBILE_CREDENTIAL_APP_PATH", "").strip()
    if not raw_path:
        return

    app_path = Path(raw_path)
    require(app_path.is_dir(), "QA_MOBILE_CREDENTIAL_APP_PATH must point to a built .app")
    bundles = [app_path, *sorted(app_path.rglob("*.appex"))]
    for bundle in bundles:
        info_path = bundle / "Info.plist"
        require(info_path.is_file(), f"built bundle Info.plist is missing: {bundle.name}")
        with info_path.open("rb") as handle:
            info = plistlib.load(handle)
        forbidden = sorted(set(info) & FORBIDDEN_INFO_KEYS)
        require(
            not forbidden,
            f"built bundle {bundle.name} contains retired credential keys: "
            + ", ".join(forbidden),
        )

        executable_name = str(info.get("CFBundleExecutable") or "").strip()
        require(executable_name, f"built bundle CFBundleExecutable is missing: {bundle.name}")
        executable = bundle / executable_name
        require(executable.is_file(), f"built bundle executable is missing: {bundle.name}")
        binary = executable.read_bytes()
        for key in sorted(FORBIDDEN_INFO_KEYS | FORBIDDEN_BUILD_SETTINGS):
            require(
                key.encode("utf-8") not in binary,
                f"built bundle {bundle.name} still references retired credential surface {key}",
            )


def main() -> None:
    check_generator_source()
    check_app_build_scripts()
    check_app_artifact()
    print("Product V4 QA mobile credential artifact check passed")


if __name__ == "__main__":
    main()
