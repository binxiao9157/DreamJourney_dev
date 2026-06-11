# Roadshow 真机验证记录

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

设备：`iPhone`，UDID `00008150-001402D60A04401C`

CoreDevice ID：`B7887DD8-3561-5F2A-8D62-A3FEACDC80D9`

## 结论

当前真机连接和 iPhoneOS 构建门禁已通过，但尚未完成安装、启动、截图和逐屏 smoke。

阻断原因是本机缺少 Apple 签名资产：

- Xcode target `DreamJourney` 未配置 `DEVELOPMENT_TEAM`。
- 本机 keychain 中 `0 valid identities found`。
- `~/Library/MobileDevice/Provisioning Profiles` 下没有可用 provisioning profile。
- Xcode 偏好设置中没有已保存 Apple Developer account/team。

## 设备状态

`xcrun devicectl list devices`：

- 设备名称：`iPhone`
- 状态：`available`
- 型号：`iPhone18,3`

`xcrun devicectl device info details --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9`：

- `reality: physical`
- `marketingName: iPhone 17`
- `osVersionNumber: 26.6`
- `bootState: booted`
- `developerModeStatus: enabled`
- `pairingState: paired`
- `transportType: wired`
- `tunnelState: connected`
- `ddiServicesAvailable: true`

备注：`xcrun xctrace list devices` 同时把设备列在 `Devices Offline`，但 `devicectl`、`xcodebuild -showBuildSettings` 和 preflight 均能识别该真机目标。

## 已执行验证

### 1. 真机 preflight

命令：

```bash
bash Scripts/roadshow_device_smoke_preflight.sh
```

结果：

- 检测到物理 iOS 设备：`iPhone (26.6) (00008150-001402D60A04401C)`
- iPhoneOS build gate：`** BUILD SUCCEEDED **`
- 脚本结论：`PASS: Physical iOS device detected and iPhoneOS build gate passed. Continue with manual Xcode Run and screenshot/log capture.`

### 2. 真机目标 build

命令：

```bash
set -o pipefail
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001402D60A04401C' \
  -allowProvisioningUpdates \
  build
```

结果：

- 退出码：`65`
- 失败原因：`Signing for "DreamJourney" requires a development team. Select a development team in the Signing & Capabilities editor.`

### 3. 签名资产检查

命令：

```bash
security find-identity -v -p codesigning
```

结果：

- `0 valid identities found`

命令：

```bash
find ~/Library/MobileDevice/Provisioning\ Profiles -name '*.mobileprovision' -maxdepth 1 -print | wc -l
```

结果：

- `0`

命令：

```bash
defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists
```

结果：

- `IDE.Identifiers.Prod = ();`

### 4. 已安装 App 检查

命令：

```bash
xcrun devicectl device info apps \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  --bundle-id com.dreamjourney.app
```

结果：

- `Apps installed:` 下无 `com.dreamjourney.app`。
- 因此无法绕过安装步骤直接启动旧包。

## 尚未完成

- 真机安装 `DreamJourney.app`
- 使用 roadshow launch 参数启动：
  - `--reset-roadshow-demo`
  - `--seed-roadshow-demo`
  - `--roadshow-offline-mode`
- 捕获 `[RoadshowDemo]` console 日志
- 首页路演 Banner 截图
- 信箱、档案、mock 语音、关怀看板、KBLite 分享包逐屏 smoke
- 分享包 JSON 真机抽查

## 解除阻断后的下一条命令

在 Xcode 登录 Apple ID 并给 `DreamJourney` target 选择 Team 后，重新执行：

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001402D60A04401C' \
  -allowProvisioningUpdates \
  build
```

若 build 成功，再用 Xcode Run 或 `devicectl` 安装/启动，并带上 roadshow 参数继续逐屏 smoke。
