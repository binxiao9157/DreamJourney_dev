"""Run unchanged production invitation helpers in an explicitly booted simulator; no network."""
from pathlib import Path
import subprocess, tempfile, sys
qa = Path(__file__).resolve().parent
root = qa.parents[3]
if len(sys.argv) != 3:
    raise SystemExit('usage: python3 run.py SIMULATOR_UDID OUTPUT_DIRECTORY')
output = Path(sys.argv[2]).resolve(); output.mkdir(parents=True, exist_ok=True)
source = (root / 'DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift').read_text()
helper = source[source.index('// MARK: - Invitation-only sharing'):]
with tempfile.TemporaryDirectory() as directory:
    main = Path(directory) / 'main.swift'
    binary = Path(directory) / 'check'
    main.write_text((qa / 'tests.swift').read_text() + '\n' + helper)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    subprocess.run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-target', 'arm64-apple-ios18.0-simulator', '-sdk', sdk, '-module-cache-path', '/private/tmp/dj-invitation-share-module-cache', str(main), '-o', str(binary)], check=True)
    subprocess.run(['xcrun', 'simctl', 'spawn', sys.argv[1], str(binary), str(output)], check=True)
