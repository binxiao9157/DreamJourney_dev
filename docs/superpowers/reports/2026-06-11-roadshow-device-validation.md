# Roadshow 真机验证记录

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

设备：`iPhone`，UDID `00008150-001402D60A04401C`

CoreDevice ID：`B7887DD8-3561-5F2A-8D62-A3FEACDC80D9`

## 结论

当前真机连接、iPhoneOS 构建、签名、安装、启动已通过。App 已使用 roadshow reset/seed/offline 参数在真机启动，进程仍在运行，并且已从真机 App 容器抽查到 roadshow seed/offline 标记、登录账号、时空信箱、记忆档案馆和 CareDashboard transcript 数据。

当前剩余事项：

- 本机 keychain 已有 `Apple Development: xbnjupt@163.com (BLVP6JU3M3)`。
- 阶段2工程已持久化 `DEVELOPMENT_TEAM = 2BTR77V3R8`。
- 阶段2工程主 App Bundle ID 已改为 `com.yxj.dreamjourney.app`，Widget Bundle ID 已改为 `com.yxj.dreamjourney.app.widget`。
- Xcode 已创建 `iOS Team Provisioning Profile: com.yxj.dreamjourney.app`。
- 仍需人工逐屏确认首页 Banner、信箱、档案、mock 语音、关怀看板、KBLite 分享包 UI。
- 当前 `devicectl` 版本没有直接截图子命令，本轮没有保存自动截图。

## 设备状态

`xcrun devicectl list devices`：

- 设备名称：`iPhone`
- 状态：`connected`
- 型号：`iPhone 17 (iPhone18,3)`

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

重试命令：

```bash
set -o pipefail
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001402D60A04401C' \
  DEVELOPMENT_TEAM=BLVP6JU3M3 \
  -allowProvisioningUpdates \
  build
```

结果：

- 退出码：`65`
- 新失败原因：`No Account for Team "BLVP6JU3M3". Add a new account in Accounts settings or verify that your accounts have valid credentials.`
- 新失败原因：`No profiles for 'com.dreamjourney.app' were found: Xcode couldn't find any iOS App Development provisioning profiles matching 'com.dreamjourney.app'.`

签名配置同步到阶段2工程后，重试命令：

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001402D60A04401C' \
  -allowProvisioningUpdates \
  build
```

结果：

- 退出码：`0`
- iPhoneOS device build：`** BUILD SUCCEEDED **`
- Signing Identity：`Apple Development: xbnjupt@163.com (BLVP6JU3M3)`
- Provisioning Profile：`iOS Team Provisioning Profile: com.yxj.dreamjourney.app`
- Built app：`/Users/yxj/Library/Developer/Xcode/DerivedData/DreamJourney-harrinatqdphdkhaqmlyfhxjmemq/Build/Products/Debug-iphoneos/DreamJourney.app`

### 3. 签名资产检查

命令：

```bash
security find-identity -v -p codesigning
```

结果：

- `1 valid identities found`
- `Apple Development: xbnjupt@163.com (BLVP6JU3M3)`

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
  --bundle-id com.yxj.dreamjourney.app
```

结果：

- `Apps installed:` 下已有 `寻梦环游`
- Bundle Identifier：`com.yxj.dreamjourney.app`
- Version：`1.0.0`
- Bundle Version：`1`

### 5. 安装与启动

安装命令：

```bash
xcrun devicectl device install app \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  /Users/yxj/Library/Developer/Xcode/DerivedData/DreamJourney-harrinatqdphdkhaqmlyfhxjmemq/Build/Products/Debug-iphoneos/DreamJourney.app
```

结果：

- 退出码：`0`
- `App installed`
- Bundle ID：`com.yxj.dreamjourney.app`

启动命令：

```bash
xcrun devicectl device process launch \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  --terminate-existing \
  --environment-variables '{"DREAMJOURNEY_SEED":"roadshow_demo","DREAMJOURNEY_RESET_DEMO":"1","DREAMJOURNEY_ROADSHOW_OFFLINE":"1"}' \
  com.yxj.dreamjourney.app \
  --reset-roadshow-demo \
  --seed-roadshow-demo \
  --roadshow-offline-mode
```

结果：

- 退出码：`1`
- 失败原因：`Unable to launch com.yxj.dreamjourney.app because it has an invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user.`
- 当前判断：需要在 iPhone 上手动信任开发者 profile 后重试。

信任开发者 profile 后，重试命令同上。

结果：

- 退出码：`0`
- `Launched application with com.yxj.dreamjourney.app bundle identifier.`
- 进程 PID：`30733`
- Launch arguments：
  - `--reset-roadshow-demo`
  - `--seed-roadshow-demo`
  - `--roadshow-offline-mode`
- Environment：
  - `DREAMJOURNEY_SEED=roadshow_demo`
  - `DREAMJOURNEY_RESET_DEMO=1`
  - `DREAMJOURNEY_ROADSHOW_OFFLINE=1`

### 6. 运行态与容器数据抽查

进程检查：

```bash
xcrun devicectl device info processes \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  --filter "executablePath CONTAINS 'DreamJourney'" \
  --columns '*'
```

结果：

- PID：`30733`
- Executable：`/private/var/containers/Bundle/Application/752D7C87-031C-4EDC-950B-4462AC61E348/DreamJourney.app/DreamJourney`

显示与解锁状态：

- 主显示屏：`1206 x 2622`，portrait，backlight active
- 设备状态：`unlockedSinceBoot: true`

Preferences 抽查：

```bash
/usr/libexec/PlistBuddy \
  -c 'Print :dreamjourney.roadshow.seeded.v1' \
  -c 'Print :dreamjourney.roadshow.offlineMode' \
  -c 'Print :dj_is_logged_in' \
  /tmp/dreamjourney_device_container/Preferences/com.yxj.dreamjourney.app.plist
```

结果：

- `dreamjourney.roadshow.seeded.v1 = true`
- `dreamjourney.roadshow.offlineMode = true`
- `dj_is_logged_in = true`

路演账号抽查：

```json
{"avatarName":"person.circle.fill","nickname":"路演家庭","id":"user_0001","phone":"18800000001"}
```

Documents 抽查：

- `conversation_memory.json` 已写入 7 条 roadshow transcript，包含睡眠、孤独、胸闷、档案、时空信箱等 CareDashboard 输入。
- `knowledge_base/kb_graph_user_0001.json` 已写入 KBLite v2 空图谱骨架。
- `dreamjourney.timeMailbox.letters` 已写入 delivered 信件，包含边界文案：不是逝者真实回复。
- `dreamjourney.memoryArchive.items` 已写入 4 条路演档案，包括外滩老照片、口头禅、人格边界说明和外滩合影背景。

## 尚未完成

- 捕获 `[RoadshowDemo]` console 日志
- 首页路演 Banner 截图
- 信箱、档案、mock 语音、关怀看板、KBLite 分享包逐屏 smoke
- 分享包 JSON 真机抽查

## 下一条验证命令

如需重新跑本轮启动验证，执行：

```bash
xcrun devicectl device process launch \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  --terminate-existing \
  --environment-variables '{"DREAMJOURNEY_SEED":"roadshow_demo","DREAMJOURNEY_RESET_DEMO":"1","DREAMJOURNEY_ROADSHOW_OFFLINE":"1"}' \
  com.yxj.dreamjourney.app \
  --reset-roadshow-demo \
  --seed-roadshow-demo \
  --roadshow-offline-mode
```

若 launch 成功，再人工逐屏走查 UI，并保存截图/现场问题。
