# Tencent Digital Human Cloud SDK Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Tencent Cloud Digital Human cloud-rendering SDK into DreamJourney behind the existing digital-human runtime boundary, while keeping the public release hidden and preserving Echo fallback.

**Architecture:** The app keeps backend-issued session contracts as the only product-facing source of truth. iOS imports Tencent SDK behind `TencentDigitalHumanSDKBridge`; Echo talks only to `DigitalHumanRuntime`, so failed SDK setup degrades to audio-only Echo without changing the main conversation flow.

**Tech Stack:** UIKit, CocoaPods, `VirtualmanStreamSDK.xcframework`, `TXLiteAVSDK_TRTC_shuziren_13.0.20262`, FastAPI runtime/session contracts, Swift static QA scripts, simulator smoke, true-device acceptance.

---

## Current Evidence

- Demo zip downloaded locally:
  - `/tmp/dj-tencent-virtualman-demo/virtualman-stream-demo-ios.zip`
  - SHA-256: `3056d8caff1b542a5301b69e8a979608662d4a25502832f7d40477989aaa2d1f`
- Demo root:
  - `/tmp/dj-tencent-virtualman-demo/unzipped/ios-demo`
- SDK framework:
  - `/tmp/dj-tencent-virtualman-demo/unzipped/ios-demo/Frameworks/VirtualmanStreamSDK.xcframework`
- SDK framework slices:
  - `ios-arm64`
  - `ios-arm64_x86_64-simulator`
- Tencent TRTC podspec:
  - `https://liteav.sdk.qcloud.com/pod/liteavsdkspec/customer/TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec`
- Demo APIs observed:
  - `Virtualman(frame:)`
  - `VirtualmanParams(appkey:accesstoken:)`
  - `AssetVirtualmanParams(assetVirtualmanKey:)`
  - `VirtualmanProjectParams(virtualmanProjectId:)`
  - `ExtraInfo(alphaChannelEnable:)`
  - `openByAsset`
  - `open`
  - `chat(ChatParams(text:isNewChat:))`
  - `sendStreamText`
  - `sendAudio(AudioParams(reqId:audio:seq:isFinal:))`
  - `stop`
  - `close`
  - `VirtualmanDelegate`
  - `VirtualmanWsDelegate`

## File Structure

### Existing Files To Modify

- `Podfile`
  - Adds Tencent dedicated TRTC pod only after dependency proof passes.
- `DreamJourney.xcodeproj/project.pbxproj`
  - Adds `VirtualmanStreamSDK.xcframework` as an embedded framework only when binary import is approved.
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift`
  - Keeps SDK-independent protocol and configuration.
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`
  - Uses the bridge without importing Tencent SDK.
- `DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift`
  - Switches to real cloud runtime only when runtime config and bridge are both ready.
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
  - Parses backend session contract fields.
- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
  - Opens/feeds/tears down digital-human runtime under QA/release gating.
- `DreamJourney/Info.plist`
  - Ensures microphone/camera usage strings exist before true-device SDK tests.
- `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
  - Adds optional Tencent cloud SDK gate.

### New Files To Create

- `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
  - Imports `VirtualmanStreamSDK` and maps SDK calls to `TencentDigitalHumanSDKBridge`.
- `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift`
  - Verifies framework/pod/project wiring without requiring a true device.
- `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh`
  - Runs the binary wiring check.
- `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloud-runtime-smoke.swift`
  - Checks the bridge adapter source for required API mappings.
- `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh`
  - Runs adapter mapping checks and a simulator smoke when available.
- `docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-integration-evidence.md`
  - Records SDK version, checksum, build results, true-device evidence, and remaining blockers.

## Task 1: Preserve SDK Artifact Outside Git Until Import Is Approved

**Files:**
- Modify: `.gitignore`
- Modify: `docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-handoff.md`
- Test: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-handoff-check.swift`

- [ ] **Step 1: Add a gitignore guard for local SDK staging**

Add these lines to `.gitignore`:

```gitignore
# Tencent Digital Human SDK local staging
Vendor/TencentDigitalHuman/
tmp/tencent-digital-human-sdk/
```

- [ ] **Step 2: Copy the demo package into ignored local staging**

Run:

```bash
mkdir -p tmp/tencent-digital-human-sdk
cp -R /tmp/dj-tencent-virtualman-demo/unzipped/ios-demo tmp/tencent-digital-human-sdk/ios-demo
```

Expected:

```text
tmp/tencent-digital-human-sdk/ios-demo/Frameworks/VirtualmanStreamSDK.xcframework
tmp/tencent-digital-human-sdk/ios-demo/Podfile
```

- [ ] **Step 3: Update handoff evidence**

In `docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-handoff.md`, replace the old demo-risk statement with:

```markdown
The corrected demo URL is available:

`https://vh-data.ivh.qq.com/client/cloudsdk/ios/virtualman-stream-demo-ios.zip`

Downloaded package SHA-256:

`3056d8caff1b542a5301b69e8a979608662d4a25502832f7d40477989aaa2d1f`
```

- [ ] **Step 4: Run handoff check**

Run:

```bash
tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-handoff-check.sh
```

Expected:

```text
tencent-digital-human-sdk-handoff-check passed
```

- [ ] **Step 5: Commit**

Run:

```bash
git add .gitignore docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-handoff.md tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-handoff-check.swift
git commit -m "docs: record tencent digital human sdk package source"
```

## Task 2: Prove CocoaPods Dependency Compatibility Before SDK Import

**Files:**
- Modify: `Podfile`
- Create: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift`
- Create: `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh`
- Modify: `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`

- [ ] **Step 1: Write binary wiring check**

Create `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift`:

```swift
import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func exists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(relativePath).path)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-sdk-binary-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let podfile = try read("Podfile")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(podfile.contains("TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec"), "Podfile must use Tencent digital-human TRTC podspec")
require(project.contains("VirtualmanStreamSDK.xcframework"), "Xcode project must reference VirtualmanStreamSDK.xcframework after binary import")
require(project.contains("Embed Frameworks") || project.contains("PBXCopyFilesBuildPhase"), "VirtualmanStreamSDK must be embedded for device builds")
require(exists("Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework") || exists("DreamJourney/Frameworks/VirtualmanStreamSDK.xcframework"), "SDK xcframework must exist in an approved local path")

print("tencent-digital-human-sdk-binary-check passed")
```

- [ ] **Step 2: Add runner**

Create `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
swift "$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift" "$ROOT_DIR"
```

Run:

```bash
chmod +x tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh
```

- [ ] **Step 3: Run check before implementation**

Run:

```bash
tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh
```

Expected: FAIL with:

```text
Podfile must use Tencent digital-human TRTC podspec
```

- [ ] **Step 4: Add Tencent TRTC pod**

In `Podfile`, under the voice SDK section, add:

```ruby
  # ===== 腾讯云数智人 SDK 依赖 =====
  pod 'TXLiteAVSDK_TRTC', :podspec => 'https://liteav.sdk.qcloud.com/pod/liteavsdkspec/customer/TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec'
```

- [ ] **Step 5: Run pod install**

Run:

```bash
pod install
```

Expected:

```text
Installing TXLiteAVSDK_TRTC (13.0.20262)
Pod installation complete!
```

- [ ] **Step 6: Build without importing Virtualman SDK**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-trtc-compat-build CODE_SIGNING_ALLOWED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 7: Commit**

Run:

```bash
git add Podfile Podfile.lock Pods/Manifest.lock tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
git commit -m "build: add tencent digital human trtc dependency gate"
```

## Task 3: Import `VirtualmanStreamSDK.xcframework` Behind Approval Gate

**Files:**
- Create or copy local binary: `Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework`
- Modify: `DreamJourney.xcodeproj/project.pbxproj`
- Modify: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift`
- Test: iOS build

- [ ] **Step 1: Copy SDK to local vendor path**

Run:

```bash
mkdir -p Vendor/TencentDigitalHuman
cp -R /tmp/dj-tencent-virtualman-demo/unzipped/ios-demo/Frameworks/VirtualmanStreamSDK.xcframework Vendor/TencentDigitalHuman/
```

- [ ] **Step 2: Decide whether binary enters git**

Run:

```bash
du -sh Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework
git status --short Vendor/TencentDigitalHuman
```

Expected: binary remains ignored unless product explicitly approves committing SDK artifacts or adopting Git LFS.

- [ ] **Step 3: Add framework to Xcode target**

Use Xcode or a controlled project edit to add:

```text
Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework
Target: DreamJourney
Frameworks, Libraries, and Embedded Content: Embed & Sign
```

- [ ] **Step 4: Run binary check**

Run:

```bash
tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-binary-check.sh
```

Expected:

```text
tencent-digital-human-sdk-binary-check passed
```

- [ ] **Step 5: Build simulator**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-sdk-binary-import-build CODE_SIGNING_ALLOWED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 6: Commit project wiring only**

Run:

```bash
git add DreamJourney.xcodeproj/project.pbxproj tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift
git commit -m "build: wire tencent digital human sdk framework"
```

Do not commit `Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework` unless Git LFS or another artifact policy is approved.

## Task 4: Implement Real Tencent SDK Bridge

**Files:**
- Create: `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
- Modify: `DreamJourney.xcodeproj/project.pbxproj`
- Create: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloud-runtime-smoke.swift`
- Create: `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh`
- Modify: `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`

- [ ] **Step 1: Write adapter mapping check**

Create `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloud-runtime-smoke.swift`:

```swift
import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-cloud-runtime-smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

let bridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(bridge.contains("import VirtualmanStreamSDK"), "real bridge must import Tencent SDK")
require(bridge.contains("import TXLiteAVSDK_TRTC"), "real bridge must import dedicated TRTC SDK")
require(bridge.contains("Virtualman(frame:"), "real bridge must create Virtualman view")
require(bridge.contains("VirtualmanParams(appkey:"), "real bridge must initialize SDK with appkey/accesstoken")
require(bridge.contains("AssetVirtualmanParams(assetVirtualmanKey:"), "real bridge must support AssetVirtualmanKey")
require(bridge.contains("VirtualmanProjectParams(virtualmanProjectId:"), "real bridge must support ProjectId")
require(bridge.contains("ExtraInfo(alphaChannelEnable:"), "real bridge must preserve alpha channel")
require(bridge.contains("openByAsset"), "real bridge must support asset open")
require(bridge.contains(".open"), "real bridge must support project open")
require(bridge.contains("chat(ChatParams"), "real bridge must map text drive")
require(bridge.contains("sendStreamText"), "real bridge must map stream text")
require(bridge.contains("sendAudio"), "real bridge must map audio drive or explicitly gate it")
require(bridge.contains("stop()"), "real bridge must map interrupt")
require(bridge.contains("close()"), "real bridge must map close")
require(project.contains("TencentVirtualmanSDKBridge.swift in Sources"), "real bridge must be compiled into app target")

print("tencent-digital-human-cloud-runtime-smoke passed")
```

- [ ] **Step 2: Run adapter check before implementation**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloud-runtime-smoke.swift "$PWD"
```

Expected: FAIL because `TencentVirtualmanSDKBridge.swift` does not exist.

- [ ] **Step 3: Create real bridge implementation**

First extend the SDK-independent credential/configuration models so credentials come from backend session contracts, not source code:

In `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`, extend `DigitalHumanSessionCredential`:

```swift
struct DigitalHumanSessionCredential {
    let mode: String
    let expiresAt: Date?
    let appKey: String?
    let accessToken: String?

    init(json: [String: Any]?) {
        mode = json?["mode"] as? String ?? "unknown"
        appKey = json?["appkey"] as? String ?? json?["appKey"] as? String
        accessToken = json?["accesstoken"] as? String ?? json?["accessToken"] as? String
        if let expiresAtValue = json?["expiresAt"] as? String {
            expiresAt = BackendDateParser.date(from: expiresAtValue)
        } else {
            expiresAt = nil
        }
    }
}
```

In `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift`, extend `TencentDigitalHumanSDKConfiguration`:

```swift
struct TencentDigitalHumanSDKConfiguration: Equatable {
    let sessionId: String
    let appKey: String
    let accessToken: String
    let assetVirtualmanKey: String?
    let virtualmanProjectId: String?
    let alphaChannelEnable: Bool
    let smartActionEnabled: Bool
    let driveMode: String
    let credentialMode: String
}
```

In `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`, fail closed when the backend omits credentials:

```swift
guard let appKey = contract.credential.appKey, !appKey.isEmpty,
      let accessToken = contract.credential.accessToken, !accessToken.isEmpty else {
    state = .failed(code: "missing_tencent_sdk_credential")
    throw DigitalHumanRuntimeError.unsupportedOperation("Tencent SDK credential is missing from backend session contract.")
}
```

Create `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`:

```swift
import Foundation
import UIKit
import VirtualmanStreamSDK
import TXLiteAVSDK_TRTC

final class TencentVirtualmanSDKBridge: NSObject, TencentDigitalHumanSDKBridge {
    let contentView: UIView
    private let virtualman: Virtualman
    private var configuration: TencentDigitalHumanSDKConfiguration?

    override init() {
        let virtualman = Virtualman(frame: .zero)
        virtualman.translatesAutoresizingMaskIntoConstraints = false
        self.virtualman = virtualman
        self.contentView = virtualman
        super.init()
    }

    func configure(_ configuration: TencentDigitalHumanSDKConfiguration, profile: DigitalHumanProfile) throws {
        self.configuration = configuration
        let params = VirtualmanParams(appkey: configuration.appKey, accesstoken: configuration.accessToken)

        if let assetKey = configuration.assetVirtualmanKey, !assetKey.isEmpty {
            let assetParams = AssetVirtualmanParams(assetVirtualmanKey: assetKey)
            assetParams.extraInfo = ExtraInfo(alphaChannelEnable: configuration.alphaChannelEnable)
            params.assetVirtualmanParams = assetParams
        }

        if let projectId = configuration.virtualmanProjectId, !projectId.isEmpty {
            let projectParams = VirtualmanProjectParams(virtualmanProjectId: projectId)
            projectParams.extraInfo = ExtraInfo(alphaChannelEnable: configuration.alphaChannelEnable)
            params.virtualmanProjectParams = projectParams
        }

        virtualman.initSDK(params: params)
    }

    func openByAsset(completion: @escaping (Result<String, Error>) -> Void) {
        virtualman.openByAsset { sessionId, error in
            if let sessionId {
                completion(.success(sessionId))
            } else {
                completion(.failure(NSError(domain: "TencentVirtualmanSDKBridge", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: error ?? "Tencent asset stream failed"
                ])))
            }
        }
    }

    func openByProject(completion: @escaping (Result<String, Error>) -> Void) {
        virtualman.open { sessionId, error in
            if let sessionId {
                completion(.success(sessionId))
            } else {
                completion(.failure(NSError(domain: "TencentVirtualmanSDKBridge", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: error ?? "Tencent project stream failed"
                ])))
            }
        }
    }

    func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        if sequence <= 1 && isFinal {
            _ = virtualman.chat(ChatParams(text: text, isNewChat: true))
        } else {
            virtualman.sendStreamText(StreamTextParams(reqId: requestID, text: text, seq: sequence, isFinal: isFinal))
        }
    }

    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        let base64 = data.base64EncodedString()
        virtualman.sendAudio(AudioParams(reqId: requestID, audio: base64, seq: sequence, isFinal: isFinal))
    }

    func interrupt() {
        _ = virtualman.stop()
    }

    func close() {
        virtualman.close()
    }
}
```

The app must not read long-lived Tencent credentials from `LocalConfig.plist`. If the SDK requires `appkey/accesstoken`, the backend session contract must provide a scoped credential payload for the QA build, and release approval must confirm no long-lived secret is printed in logs or stored in source.

- [ ] **Step 4: Register bridge factory**

Register only in builds where the SDK is linked. Add this after app launch configuration:

```swift
TencentDigitalHumanSDKBridgeFactory.shared.register { _ in
    TencentVirtualmanSDKBridge()
}
```

- [ ] **Step 5: Add file to Xcode target**

Add `TencentVirtualmanSDKBridge.swift` to the `DreamJourney` target Sources phase.

- [ ] **Step 6: Run adapter mapping check**

Run:

```bash
tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh
```

Expected:

```text
tencent-digital-human-cloud-runtime-smoke passed
```

- [ ] **Step 7: Build simulator**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-sdk-bridge-build CODE_SIGNING_ALLOWED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 8: Commit**

Run:

```bash
git add DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift DreamJourney.xcodeproj/project.pbxproj tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloud-runtime-smoke.swift tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
git commit -m "feat: add tencent digital human sdk bridge"
```

## Task 5: Backend Real-Provider Readiness Contract

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/runtime_config.py`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_digital_human_sessions.py`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/run-digital-human-session-contract-smoke.sh`

- [ ] **Step 1: Add failing backend test for asset readiness**

In `tests/test_digital_human_sessions.py`, add:

```python
def test_runtime_config_marks_real_provider_ready_with_asset_env(self):
    with patch.dict(os.environ, {
        "TENCENT_DIGITAL_HUMAN_APP_KEY": "app-key",
        "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN": "access-token",
        "TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY": "asset-key",
    }, clear=False):
        response = client.get("/config/runtime")

    self.assertEqual(response.status_code, 200)
    body = response.json()["digitalHuman"]
    self.assertTrue(body["realProviderReady"])
    self.assertEqual(body["providerMode"], "tencentSDK")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
python -m unittest tests.test_digital_human_sessions.DigitalHumanSessionAPITests.test_runtime_config_marks_real_provider_ready_with_asset_env -v
```

Expected: FAIL while provider mode still reports `mockContract`.

- [ ] **Step 3: Implement runtime readiness**

In `app/services/runtime_config.py`, compute:

```python
has_auth = bool(os.getenv("TENCENT_DIGITAL_HUMAN_APP_KEY") and os.getenv("TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN"))
has_asset = bool(os.getenv("TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY") or os.getenv("TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID"))
real_provider_ready = has_auth and has_asset
provider_mode = "tencentSDK" if real_provider_ready else "mockContract"
```

- [ ] **Step 4: Add session contract asset/project fields**

In `app/main.py`, include:

```python
"assetKey": os.getenv("TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY") or None,
"providerAssetId": os.getenv("TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY") or None,
"providerProjectId": os.getenv("TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID") or None,
```

- [ ] **Step 5: Run backend session smoke**

Run:

```bash
scripts/run-digital-human-session-contract-smoke.sh
```

Expected:

```text
OK
```

- [ ] **Step 6: Commit**

Run:

```bash
git add app/services/runtime_config.py app/main.py tests/test_digital_human_sessions.py
git commit -m "feat: enable tencent digital human provider readiness contract"
```

## Task 6: Simulator QA With SDK Linked But Provider Hidden

**Files:**
- Modify: `tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh`
- Modify: `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- Test artifact: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-hidden-smoke/<RUN_ID>/`

- [ ] **Step 1: Add launch arg for SDK-hidden smoke**

Use existing launch arg pattern:

```text
DJRunDigitalHumanRuntimeStubSmoke
DJShowDigitalHumanLivePanel
```

Do not enable public release flag.

- [ ] **Step 2: Run simulator smoke**

Run:

```bash
RUN_ID=YYYYMMDD-tencent-sdk-hidden-smoke tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh
```

Expected JSON fields:

```json
{
  "completed": true,
  "provider": "tencent",
  "runtimeIsRealSDKBacked": false,
  "fallbackMode": "audioOnly",
  "defaultReleaseVisible": false
}
```

- [ ] **Step 3: Commit QA wiring**

Run:

```bash
git add tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
git commit -m "test: keep tencent digital human sdk hidden release gate"
```

## Task 7: True-Device Cloud Rendering Acceptance

**Files:**
- Create: `docs/superpowers/status/2026-06-25-tencent-digital-human-true-device-acceptance.md`
- Test artifact: `tmp/visual-qa/prd-stitch-ui/true-device-tencent-digital-human/<RUN_ID>/`

- [ ] **Step 1: Prepare required secrets and assets**

Server `.env` must contain non-empty values for the two auth fields and one asset field. Verify presence with a redacted command; do not print secret values:

```bash
python - <<'PY'
import os
required = [
    "TENCENT_DIGITAL_HUMAN_APP_KEY",
    "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN",
]
asset_any = [
    "TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY",
    "TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID",
]
missing = [key for key in required if not os.getenv(key)]
if not any(os.getenv(key) for key in asset_any):
    missing.append("one of " + ",".join(asset_any))
if missing:
    raise SystemExit("missing: " + ", ".join(missing))
print("Tencent digital human env is present; values redacted.")
PY
```

- [ ] **Step 2: Build with local signing override**

Use the existing local signing override:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' DEVELOPMENT_TEAM=2BTR77V3R8 PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: Run device acceptance**

Manual actions:

1. Launch app with QA digital-human flag.
2. Open Echo.
3. Start Tencent session through QA-only entry.
4. Verify first video frame appears.
5. Send text.
6. Verify mouth/animation responds.
7. Tap stop.
8. Verify stop interrupts speech.
9. Background app.
10. Foreground app.
11. Verify session either resumes or fails with visible fallback.
12. Close Echo.
13. Verify backend/session logs include provider mode and no long-lived secret in client logs.

- [ ] **Step 4: Save evidence**

Save:

```text
tmp/visual-qa/prd-stitch-ui/true-device-tencent-digital-human/<RUN_ID>/device-screenshot-01.png
tmp/visual-qa/prd-stitch-ui/true-device-tencent-digital-human/<RUN_ID>/device-log.txt
tmp/visual-qa/prd-stitch-ui/true-device-tencent-digital-human/<RUN_ID>/backend-session-log-redacted.txt
```

- [ ] **Step 5: Commit evidence doc**

Run:

```bash
git add docs/superpowers/status/2026-06-25-tencent-digital-human-true-device-acceptance.md
git commit -m "docs: record tencent digital human true-device acceptance"
```

## Task 8: Release Gate And Product Decision

**Files:**
- Modify: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Modify: `tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift`
- Modify: `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`

- [ ] **Step 1: Keep release default hidden**

In release matrix, keep:

```markdown
| digitalHumanLivePanel | hidden | QA launch arg only | Tencent SDK true-device acceptance required before public release |
```

- [ ] **Step 2: Add public-release promotion checklist**

Promotion requires:

```markdown
- backend realProviderReady=true
- SDK binary linked
- real bridge enabled
- true-device first-video-frame evidence
- text drive evidence
- stop/close evidence
- fallback evidence
- no client-side long-lived secret exposure
```

- [ ] **Step 3: Run final regression**

Run:

```bash
RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE=1 RUN_STANDARD_BUILD=1 RUN_SIMULATOR_SMOKE=0 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

Expected:

```text
[release-regression] Report: /Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/release-regression/<RUN_ID>/report.md
```

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/status/2026-06-17-release-feature-matrix.md tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
git commit -m "test: gate tencent digital human public release"
```

## Self-Review

- Spec coverage: covers SDK artifact staging, CocoaPods compatibility, xcframework import, real bridge, backend real-provider contract, hidden simulator QA, true-device acceptance, and public release promotion gate.
- Placeholder scan: no `TBD` / `TODO` placeholders remain in executable tasks.
- Type consistency:
  - Bridge names align with existing `TencentDigitalHumanSDKBridge`.
  - Runtime route aligns with existing `TencentDigitalHumanCloudRuntime`.
  - Backend fields align with existing `providerAssetId`, `providerProjectId`, `assetKey`, and `providerMode`.
- Known product blocker:
  - A real `asset_virtualman_key` or `virtualman_project_id` is required before true Tencent cloud-rendering acceptance.
- Known engineering blocker:
  - Committing SDK binaries requires an artifact policy decision: Git LFS, ignored local vendor path, or external download step.
