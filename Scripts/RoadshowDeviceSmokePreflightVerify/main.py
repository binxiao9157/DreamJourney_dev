#!/usr/bin/env python3
import os
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFLIGHT = ROOT / "Scripts/roadshow_device_smoke_preflight.sh"


def fail(message: str) -> int:
    print(f"RoadshowDeviceSmokePreflight verification failed: {message}", file=sys.stderr)
    return 1


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def create_fake_tools(bin_dir: Path) -> None:
    write_executable(
        bin_dir / "xcodebuild",
        textwrap.dedent(
            """\
            #!/usr/bin/env bash
            set -euo pipefail

            if [[ " $* " == *" -showdestinations "* ]]; then
              if [[ "${DREAMJOURNEY_FAKE_DEVICE_MODE:-no_device}" == "device" || "${DREAMJOURNEY_FAKE_DEVICE_MODE:-no_device}" == "xctrace_offline" ]]; then
                cat <<DESTINATIONS
            Available destinations for the "DreamJourney" scheme:
                    { platform:iOS, arch:arm64, id:00008150-001402D60A04401C, name:iPhone }
                    { platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
            DESTINATIONS
              else
                cat <<DESTINATIONS
            Available destinations for the "DreamJourney" scheme:
                    { platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
            DESTINATIONS
              fi
              exit 0
            fi

            if [[ " $* " == *" -showBuildSettings "* ]]; then
              cat <<SETTINGS
                PRODUCT_BUNDLE_IDENTIFIER = com.yxj.dreamjourney.app
                DEVELOPMENT_TEAM = TEAM123456
                CODE_SIGN_STYLE = Automatic
                IPHONEOS_DEPLOYMENT_TARGET = 15.0
                SDKROOT = iphoneos
                TARGET_BUILD_DIR = /tmp/dreamjourney_fake_device_build
                FULL_PRODUCT_NAME = DreamJourney.app
            SETTINGS
              exit 0
            fi

            mkdir -p /tmp/dreamjourney_fake_device_build/DreamJourney.app
            echo "** BUILD SUCCEEDED **"
            """
        ),
    )

    write_executable(
        bin_dir / "xcrun",
        textwrap.dedent(
            """\
            #!/usr/bin/env python3
            import os
            import sys
            from pathlib import Path


            args = sys.argv[1:]
            mode = os.environ.get("DREAMJOURNEY_FAKE_DEVICE_MODE", "no_device")

            if args[:3] == ["xctrace", "list", "devices"]:
                if mode == "device":
                    print("== Devices ==")
                    print("Dream iPhone (17.6) (B7887DD8-3561-5F2A-8D62-A3FEACDC80D9)")
                    print("== Simulators ==")
                    print("iPhone 17 Pro (simulator)")
                elif mode == "xctrace_offline":
                    print("== Devices ==")
                    print("My Mac (00008142-001468362E2B401C)")
                    print("== Devices Offline ==")
                    print("Dream iPhone (17.6) (00008150-001402D60A04401C)")
                    print("== Simulators ==")
                    print("iPhone 17 Pro (simulator)")
                else:
                    print("== Devices ==")
                    print("My Mac (00008142-001468362E2B401C)")
                    print("== Simulators ==")
                    print("iPhone 17 Pro (simulator)")
                sys.exit(0)

            if args and args[0] == "devicectl":
                if args[:3] == ["devicectl", "list", "devices"]:
                    if mode in {"device", "xctrace_offline"}:
                        print("Name     Hostname                  Identifier                             State                Model")
                        print("------   -----------------------   ------------------------------------   ------------------   ----------------------")
                        print("iPhone   iPhone.coredevice.local   B7887DD8-3561-5F2A-8D62-A3FEACDC80D9   available (paired)   iPhone 17 (iPhone18,3)")
                    else:
                        print("Name     Hostname                  Identifier                             State                Model")
                        print("------   -----------------------   ------------------------------------   ------------------   ----------------------")
                    sys.exit(0)

                if args[:4] == ["devicectl", "device", "copy", "from"]:
                    destination = None
                    source = None
                    for index, value in enumerate(args):
                        if value == "--destination" and index + 1 < len(args):
                            destination = args[index + 1]
                        if value == "--source" and index + 1 < len(args):
                            source = args[index + 1]
                    if not destination:
                        print("missing --destination", file=sys.stderr)
                        sys.exit(2)
                    destination_path = Path(destination)
                    destination_path.parent.mkdir(parents=True, exist_ok=True)
                    if source and source.endswith(".plist"):
                        destination_path.write_text(
                            '''<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>dreamjourney.roadshow.seeded.v1</key><true/>
              <key>dreamjourney.roadshow.offlineMode</key><true/>
              <key>dj_is_logged_in</key><true/>
              <key>dreamjourney.roadshow.route.completed.voice_companion</key><true/>
              <key>dreamjourney.roadshow.route.completed.time_mailbox</key><true/>
              <key>dreamjourney.roadshow.route.completed.memory_archive</key><true/>
              <key>dreamjourney.roadshow.route.completed.family_footprint</key><true/>
              <key>dreamjourney.roadshow.route.completed.care_dashboard</key><true/>
              <key>dreamjourney.roadshow.route.completed.family_share</key><true/>
            </dict>
            </plist>
            ''',
                            encoding="utf-8",
                        )
                    else:
                        destination_path.write_text("{}\\n", encoding="utf-8")
                    print(f"copied {source or 'file'} to {destination}")
                    sys.exit(0)

                print("devicectl fake success: " + " ".join(args[1:]))
                sys.exit(0)

            print("xcrun fake success: " + " ".join(args))
            sys.exit(0)
            """
        ),
    )


def run_preflight(evidence_dir: Path, bin_dir: Path, *args: str, device_mode: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    env["ROADSHOW_SMOKE_EVIDENCE_DIR"] = str(evidence_dir)
    env["DREAMJOURNEY_FAKE_DEVICE_MODE"] = device_mode
    return subprocess.run(
        ["bash", str(PREFLIGHT), *args],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
        timeout=60,
    )


def require_file(path: Path, message: str) -> None:
    if not path.exists():
        raise AssertionError(message)


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(f"{message}: missing {needle!r}")


def verify_no_device_requires_allow(tmp: Path, bin_dir: Path) -> None:
    evidence_dir = tmp / "no_device_blocked"
    result = run_preflight(evidence_dir, bin_dir, device_mode="no_device")
    if result.returncode != 2:
        raise AssertionError(f"no-device run without allow should return 2, got {result.returncode}: {result.stdout}\n{result.stderr}")
    assert_contains(result.stdout, "FAIL: Physical-device smoke is blocked", "no-device run should explain the blocker")
    require_file(evidence_dir / "evidence_manifest.json", "blocked no-device run should still write manifest")
    require_file(evidence_dir / "iphoneos_build_gate.log", "blocked no-device run should keep build gate log")
    require_file(evidence_dir / "evidence_status.json", "blocked no-device run should write evidence status")


def verify_no_device_allow(tmp: Path, bin_dir: Path) -> None:
    evidence_dir = tmp / "no_device_allowed"
    result = run_preflight(evidence_dir, bin_dir, "--allow-no-device", device_mode="no_device")
    if result.returncode != 0:
        raise AssertionError(f"no-device allow run should pass with concerns, got {result.returncode}: {result.stdout}\n{result.stderr}")
    assert_contains(result.stdout, "PASS_WITH_CONCERNS: Script and iPhoneOS build gate passed", "allow-no-device should pass with concerns")
    require_file(evidence_dir / "archive_package_next_steps.txt", "allow-no-device should write archive next steps")
    require_file(evidence_dir / "route_completion/route_acceptance_checklist.md", "allow-no-device should write route acceptance template")
    require_file(evidence_dir / "evidence_status.md", "allow-no-device should write markdown status")


def verify_fake_device_success(tmp: Path, bin_dir: Path, device_mode: str = "device") -> None:
    evidence_dir = tmp / f"fake_{device_mode}"
    result = run_preflight(evidence_dir, bin_dir, device_mode=device_mode)
    if result.returncode != 0:
        raise AssertionError(f"fake-device run should pass for {device_mode}, got {result.returncode}: {result.stdout}\n{result.stderr}")
    assert_contains(result.stdout, "PASS: Physical iOS device detected", "fake-device run should report PASS")
    for relative_path in [
        "devicectl_list_devices.log",
        "xcodebuild_destinations.txt",
        "device_signed_build.log",
        "devicectl_install_app.log",
        "devicectl_launch_app.log",
        "devicectl_copy_digital_human_readiness_text.log",
        "devicectl_copy_digital_human_readiness_json.log",
        "devicectl_copy_digital_human_playback_log.log",
        "console_capture_next_steps.txt",
        "device_app_path.txt",
        "route_completion/route_completion_preferences.txt",
        "evidence_status.json",
    ]:
        require_file(evidence_dir / relative_path, f"fake-device run should write {relative_path}")

    preferences = (evidence_dir / "route_completion/route_completion_preferences.txt").read_text(encoding="utf-8")
    for key in [
        "dreamjourney.roadshow.route.completed.voice_companion=true",
        "dreamjourney.roadshow.route.completed.time_mailbox=true",
        "dreamjourney.roadshow.route.completed.memory_archive=true",
        "dreamjourney.roadshow.route.completed.family_footprint=true",
        "dreamjourney.roadshow.route.completed.care_dashboard=true",
        "dreamjourney.roadshow.route.completed.family_share=true",
    ]:
        assert_contains(preferences, key, "fake-device preferences should export completed route keys")

    console_steps = (evidence_dir / "console_capture_next_steps.txt").read_text(encoding="utf-8")
    assert_contains(console_steps, "--console", "fake-device console next steps should include console capture")
    assert_contains(console_steps, "diagnostics/digital_human_playback.log", "fake-device console next steps should extract playback evidence")
    assert_contains(
        console_steps,
        "Scripts/roadshow_digital_human_playback_audit.py",
        "fake-device console next steps should include strict playback audit",
    )


def main() -> int:
    try:
        with tempfile.TemporaryDirectory(prefix="dreamjourney_preflight_verify_") as tmp_name:
            tmp = Path(tmp_name)
            bin_dir = tmp / "bin"
            create_fake_tools(bin_dir)
            verify_no_device_requires_allow(tmp, bin_dir)
            verify_no_device_allow(tmp, bin_dir)
            verify_fake_device_success(tmp, bin_dir)
            verify_fake_device_success(tmp, bin_dir, device_mode="xctrace_offline")
    except AssertionError as error:
        return fail(str(error))

    print("RoadshowDeviceSmokePreflight verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
