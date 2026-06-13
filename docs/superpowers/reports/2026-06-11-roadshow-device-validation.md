# Roadshow 真机验证记录

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

设备：`iPhone`，UDID `00008150-001402D60A04401C`

CoreDevice ID：`B7887DD8-3561-5F2A-8D62-A3FEACDC80D9`

## 结论

当前真机连接、iPhoneOS 构建、签名、安装、启动已通过。App 已使用 roadshow reset/seed/offline 参数在真机启动，并且已从真机 App 容器抽查到 roadshow seed/offline 标记、登录账号、时空信箱、记忆档案馆、CareDashboard transcript、对话记忆数据和数字人 readiness 诊断。最新路演包已替换 AppIcon，并把 mock 亲友统一为陈氏家族线。

当前剩余事项：

- 本机 keychain 已有 `Apple Development: xbnjupt@163.com (BLVP6JU3M3)`。
- 阶段2工程已持久化 `DEVELOPMENT_TEAM = 2BTR77V3R8`。
- 阶段2工程主 App Bundle ID 已改为 `com.yxj.dreamjourney.app`，Widget Bundle ID 已改为 `com.yxj.dreamjourney.app.widget`。
- Xcode 已创建 `iOS Team Provisioning Profile: com.yxj.dreamjourney.app`。
- 仍需人工逐屏确认首页 Banner、信箱、档案、mock/真实语音、数字人播放、关怀看板、KBLite 分享包 UI。
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

备注：`xcrun xctrace list devices` 同时把设备列在 `Devices Offline`，但 `devicectl`、`xcodebuild -showdestinations`、`xcodebuild -showBuildSettings` 和 preflight 均能识别该真机目标。2026-06-12 已把 preflight 调整为三路设备探测，避免因为 `xctrace` offline 误报阻断真机安装/启动。

## 已执行验证

### 1. 真机 preflight

命令：

```bash
bash Scripts/roadshow_device_smoke_preflight.sh
```

结果：

- 检测到物理 iOS 设备：`iPhone (26.6)`；当 `xctrace` offline 时可从 `xcodebuild -showdestinations` 与 `devicectl list devices` 兜底解析。
- iPhoneOS build gate：`** BUILD SUCCEEDED **`
- 最新脚本结论：`PASS: Physical iOS device detected, iPhoneOS build gate passed, and install/launch evidence was captured.`
- 最新证据目录：`/tmp/dreamjourney_roadshow_smoke_20260612_220440`
- 最新启动结果：`com.yxj.dreamjourney.app` 已安装并用 roadshow reset/seed/offline 参数启动；本轮 `devicectl` launch 日志确认启动成功，但未输出 PID 行。
- 最新 evidence status：`needs_manual_evidence`，证据完整度 `55%`，已存在 `17/31` 项，缺人工截图、录屏、数字人播放日志、分享包样本和隐私抽查日志；隐私扫描命中为 `0`。
- 数字人 readiness 诊断已从真机容器自动同步为 `diagnostics/digital_human_readiness.txt` 和 `diagnostics/digital_human_readiness.json`，状态为“可演示”：本机演示引擎、数字人口型 TTS 已就绪、实时语音三件套已就绪、OpenAvatar 后端未配置但不阻断阶段1主线。
- 数字人播放日志 `diagnostics/digital_human_playback.log` 尚未生成；自动 preflight 只负责启动 App，不会代替真人触发数字人播报。完成 WebAudio、系统 TTS 兜底或 timeout 演练后重跑 preflight，才会同步该文件。

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

- `conversation_memory.json` 已写入 7 条 roadshow transcript，包含睡眠、孤独、胸闷、档案、时空信箱等 CareDashboard 输入；最新抽查确认文本使用 `陈予`，未保留旧 `小予`。
- `knowledge_base/kb_graph_user_0001.json` 已写入 KBLite v2 空图谱骨架。
- `dreamjourney.timeMailbox.letters` 已写入 delivered 信件，收件人为 `爷爷`，包含边界文案：不是逝者真实回复。
- `dreamjourney.memoryArchive.items` 已写入 4 条路演档案，包括外滩老照片、口头禅、人格边界说明和外滩合影背景；最新抽查确认 detectedPeople 为 `陈树安`、`陈静文`、`陈岚`。
- 最新 AppIcon asset catalog 已替换为家族树/记忆盒图标，全部 PNG 尺寸匹配，且 `hasAlpha: no`。

## 风险矩阵

| 类别 | 当前状态 | 证据/命令 | 路演含义 |
| --- | --- | --- | --- |
| 已自动证明 | iPhoneOS Debug build、签名、安装、roadshow 参数启动、容器 seed/offline/login 抽样已通过。 | `Scripts/roadshow_device_smoke_preflight.sh`、`xcodebuild ... build`、`devicectl install/launch`、Preferences/Documents 抽样。 | 工程可装可启，路演 seed 数据能进入真机容器。 |
| 已自动证明 | 阶段1主流程代码 gate 已通过：路线、seed、数字人 readiness/runtime log、分享包隐私、足迹 fallback/poster、证据包归档 gate。 | `bash Scripts/verify_phase2.sh`；其中包含 `RoadshowSharePackageSampleVerify`、`DigitalHumanRuntimeLogVerify`、`FamilyFootprintFallbackVerify`、`RoadshowEvidencePackageVerify`。 | 脚本能防止明显回归，但不能替代现场 UI 观感和真实音频/地图表现。 |
| 需真机证明 | 6 阶段逐屏 UI smoke、首页 Banner、路线勾选、截图/录屏、分享面板、DocumentPicker/ActivityViewController 交互。 | 按 `route_screen_checklist.md` 保存 `screens/*.png`、`recordings/roadshow_6min_run.mp4`、`route_completion/route_acceptance_checklist.md`。 | 路演 demo 是否顺滑、是否能 6 分钟跑完，只能现场验证。 |
| 已自动证明 | 数字人 readiness 诊断会在首页启动/诊断页打开时自动写入 `Documents/diagnostics/digital_human_readiness.txt/json`，并可由 preflight 同步到 evidence 目录。 | `/tmp/dreamjourney_roadshow_smoke_20260612_220440/diagnostics/digital_human_readiness.txt`、`diagnostics/digital_human_readiness.json`。 | 真机上已能拿到脱敏诊断，不需要现场手动复制 key 状态；诊断显示 TTS 与实时语音配置可演示。 |
| 需真机+key 证明 | 数字人 WAV 真实出声、WebAudio 口型同步、系统 TTS 兜底不双播、watchdog timeout 收口。 | App 会自动写 `Documents/diagnostics/digital_human_playback.log`，preflight 可拷贝到 evidence 目录；随后运行 `python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json`。 | 当前代码已有诊断、兜底、自动落盘日志和 gate；真实声音/口型仍取决于 VolcEngine key、音色和真机 WebAudio 行为。 |
| 需真机证明 | 真机导出的 `share_packages/all_family.json`、`share_packages/selected_member.json` 和隐私收据截图。 | 运行 `python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> --write-log <evidence-dir>/share_packages/privacy_check.log`，再跑 `roadshow_evidence_report.py --write --fail-on-missing`。 | 自动规则可查 JSON 结构和泄漏标记，但真实导出文件必须来自真机流程。 |
| 需产品/数据替换 | 足迹真实行政区边界数据或高德 DistrictSearch provider。 | 当前 `FamilyFootprintPosterVerify` / `FamilyFootprintFallbackVerify` 只证明离线海报、点线 bounds 和 fallback 稳定。 | 路演可用 demo 边界讲清概念；正式产品需替换真实边界数据源。 |

## 尚未完成

- 捕获 `[RoadshowDemo]` console 日志
- 首页路演 Banner 截图和 6 阶段逐屏截图
- 信箱、档案、mock/真实语音、数字人、足迹、关怀看板、KBLite 分享包逐屏 smoke
- 数字人播放日志和三链路严格审计；readiness 文本/JSON 已可由 preflight 自动同步
- 分享包 JSON 真机抽查和 `privacy_check.log`
- 6 分钟主线录屏与 evidence zip 归档

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
