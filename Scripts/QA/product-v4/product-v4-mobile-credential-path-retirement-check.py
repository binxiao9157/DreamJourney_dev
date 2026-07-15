#!/usr/bin/env python3
import os
import plistlib
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
    "DreamJourneyVolcengineAppId",
    "DreamJourneyVolcengineAppKey",
    "DreamJourneyVolcengineAppToken",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def configured_xcconfig_keys(path: Path) -> set[str]:
    if not path.exists():
        return set()
    keys = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or "=" not in stripped:
            continue
        keys.add(stripped.split("=", 1)[0].strip())
    return keys


def check_local_files() -> None:
    local_plist = ROOT / "DreamJourney/Resources/LocalConfig.plist"
    if local_plist.exists():
        with local_plist.open("rb") as handle:
            keys = set(plistlib.load(handle))
        forbidden = sorted(keys & FORBIDDEN_INFO_KEYS)
        require(not forbidden, "LocalConfig contains retired mobile credential keys: " + ", ".join(forbidden))

    for relative_path in (
        "DreamJourney/Config/Backend.local.xcconfig",
        "DreamJourney/Config/VoiceSDK.local.xcconfig",
    ):
        configured = configured_xcconfig_keys(ROOT / relative_path)
        forbidden = sorted(configured & FORBIDDEN_BUILD_SETTINGS)
        require(not forbidden, f"{relative_path} contains retired mobile credential keys: " + ", ".join(forbidden))


def check_release_artifact() -> None:
    app_path = os.environ.get("MOBILE_CREDENTIAL_RETIREMENT_APP_PATH", "").strip()
    if not app_path:
        return
    info_path = Path(app_path) / "Info.plist"
    require(info_path.exists(), "Release artifact Info.plist is missing")
    with info_path.open("rb") as handle:
        keys = set(plistlib.load(handle))
    forbidden = sorted(keys & FORBIDDEN_INFO_KEYS)
    require(not forbidden, "Release artifact contains retired credential keys: " + ", ".join(forbidden))


def main() -> None:
    project = read("DreamJourney.xcodeproj/project.pbxproj")
    info_plist = read("DreamJourney/Resources/Info.plist")
    backend_example = read("DreamJourney/Config/Backend.example.xcconfig")
    voice_example = read("DreamJourney/Config/VoiceSDK.example.xcconfig")
    backend_client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    dialog_engine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
    deepseek = read("DreamJourney/Sources/Memoir/DeepSeekService.swift")

    for key in sorted(FORBIDDEN_BUILD_SETTINGS):
        require(key not in project, f"Xcode project still declares retired mobile setting {key}")
    for key in sorted(FORBIDDEN_INFO_KEYS):
        require(key not in info_plist, f"Info.plist still packages retired credential key {key}")

    require("DREAMJOURNEY_BACKEND_API_TOKEN" not in backend_example, "Backend example still instructs mobile shared-token injection")
    for key in ("VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"):
        require(key not in voice_example, f"Voice SDK example still instructs direct Provider credential injection: {key}")

    require("DreamJourneyBackendAPIToken" not in backend_client, "backend client still reads a packaged shared token")
    require("func configure(token: String)" not in dialog_engine, "dialog engine still exposes direct token injection")
    require("private var config = Config()" in dialog_engine, "dialog engine credential-bearing SDK config must be private")
    require("providerCredentialBlocked" in dialog_engine, "dialog engine must retain explicit fail-closed state")
    require("directProviderDisabled" in deepseek, "DeepSeek direct-provider facade must remain disabled")

    check_local_files()
    check_release_artifact()
    print("Product V4 mobile credential path retirement check passed")


if __name__ == "__main__":
    main()
