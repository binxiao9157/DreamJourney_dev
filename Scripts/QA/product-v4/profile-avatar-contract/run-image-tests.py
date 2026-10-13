"""Run unchanged production image processor in an explicitly supplied booted simulator."""
from pathlib import Path
import subprocess, tempfile, sys
qa = Path(__file__).resolve().parent
root = qa.parents[3]
if len(sys.argv) != 2:
    raise SystemExit("usage: python3 run-image-tests.py SIMULATOR_UDID (does not boot a device)")
source = (root / "DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift").read_text()
processor = source[source.index("enum ProfileAvatarImageProcessor {"):]
with tempfile.TemporaryDirectory() as directory:
    main = Path(directory) / "main.swift"
    binary = Path(directory) / "check"
    main.write_text((qa / "image-tests.swift").read_text() + "\n" + processor)
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
    subprocess.run(["xcrun", "--sdk", "iphonesimulator", "swiftc", "-target", "arm64-apple-ios18.0-simulator", "-sdk", sdk, "-module-cache-path", "/private/tmp/dj-avatar-image-cache", str(main), "-o", str(binary)], check=True)
    subprocess.run(["xcrun", "simctl", "spawn", sys.argv[1], str(binary)], check=True)
