# Roadshow Device Smoke Preflight

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

## 结论

当前 preflight 已能在连接 iPhone 时完成真机 build、安装、启动和容器抽样证据采集。设备识别不再只依赖 `xcrun xctrace list devices`：当 `xctrace` 把真机列入 `Devices Offline` 时，脚本会继续从 `xcodebuild -showdestinations` 与 `xcrun devicectl list devices` 解析可用物理设备，并分别使用 Xcode destination id 和 CoreDevice id 完成后续动作。下一步仍需要人工逐屏 UI smoke、截图、录屏、数字人播放日志和分享包样本留档。

## 本次执行

```bash
Scripts/roadshow_device_smoke_preflight.sh --allow-no-device
```

结果：

- `xcrun devicectl list devices`：`No devices found.`
- `xcrun xctrace list devices`：仅发现本机 Mac 和 iOS Simulators，未发现物理 iOS 设备。
- `PRODUCT_BUNDLE_IDENTIFIER = com.dreamjourney.app`
- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM` 未在当前命令输出中显示；真机 Run 前需要在 Xcode 中选择有效 Team。
- iPhoneOS build gate：`** BUILD SUCCEEDED **`
- 脚本最终状态：`PASS_WITH_CONCERNS: Script and iPhoneOS build gate passed, but no physical-device smoke was performed.`

## 2026-06-12 最新真机执行

命令：

```bash
Scripts/roadshow_device_smoke_preflight.sh
```

结果：

- 证据目录：`/tmp/dreamjourney_roadshow_smoke_20260612_220440`
- `xcrun xctrace list devices`：真机仍显示在 offline 区域，因此仅作为原始探测证据保存。
- `xcodebuild -showdestinations`：解析到可用于 device build 的 iPhone destination。
- `xcrun devicectl list devices`：解析到可用于安装、启动和容器抽样的 CoreDevice。
- iPhoneOS generic build gate：`** BUILD SUCCEEDED **`
- 真机签名 build：`** BUILD SUCCEEDED **`
- App 安装和 roadshow reset/seed/offline 启动成功，Bundle ID 为 `com.yxj.dreamjourney.app`；本轮 `devicectl` launch 日志确认已启动，但未输出 PID 行。
- 已导出 `<bundle-id>.plist` 与 `conversation_memory.json`，并自动生成 `route_completion/route_completion_preferences.txt`；App 已自动写入并由 preflight 成功同步 `Documents/diagnostics/digital_human_readiness.txt` 与 `Documents/diagnostics/digital_human_readiness.json`。
- `Documents/diagnostics/digital_human_playback.log` 本轮未同步成功，原因是自动 preflight 只启动 App，未触发数字人实际播放；完成 WebAudio、系统 TTS 兜底或 timeout 演练后，App 才会生成播放生命周期日志。
- `evidence_status` 当前为 `needs_manual_evidence`：自动 preflight 已通过，证据完整度 `55%`，已存在 `17/31` 项，仍缺人工截图、录屏、数字人播放日志、分享包样本和隐私抽查日志；隐私扫描命中为 `0`。

## 2026-06-12 脚本能力增强

脚本现在默认创建证据目录：

```text
/tmp/dreamjourney_roadshow_smoke_<timestamp>
```

也可通过环境变量指定目录：

```bash
ROADSHOW_SMOKE_EVIDENCE_DIR=/tmp/dreamjourney_roadshow_smoke_manual \
  Scripts/roadshow_device_smoke_preflight.sh --allow-no-device
```

基础探测和无真机时会保存：

- `xctrace_devices.txt`：`xcrun xctrace list devices` 原始输出。
- `xcodebuild_destinations.txt`：`xcodebuild -showdestinations` 原始输出，用于 `xctrace` 误报 offline 时解析 Xcode 可用真机 destination。
- `devicectl_list_devices.log`：`xcrun devicectl list devices` 原始输出，用于解析 CoreDevice id。
- `physical_ios_devices.txt`：过滤后的物理 iOS 设备列表；无真机时为空。
- `build_settings.txt` 和 `bundle_identifier.txt`：当前 iPhoneOS build settings 关键上下文。
- `iphoneos_build_gate.log`、`iphoneos_build_gate.command`、`iphoneos_build_gate.exit_code`：generic iPhoneOS build gate 的日志、命令和退出码。
- `evidence_manifest.json`：路演启动参数、环境变量、8 张截图、6 段路线证据文件和补充产物的机器可读清单。
- `expected_screens.txt`：8 张逐屏截图的固定文件名。
- `expected_state_keys.txt`：roadshow seeded/offline/login 和 6 段 route completion key。
- `route_screen_checklist.md`：截图、录屏、分享包和状态证明的 evidence 填写说明。
- `route_completion/route_acceptance_checklist.md`：用于粘贴 App 内“复制验收”结果的模板，并列出 6 段路线到截图文件的对应关系。
- `route_completion/route_completion_preferences.txt`：有真机容器 plist 时自动导出 6 段 route completion key 的当前值，缺失的 key 标记为 `missing`。
- `evidence_status.json`、`evidence_status.md`：由 `Scripts/roadshow_evidence_report.py` 生成的证据完整度报告，列出已存在、缺失的截图、录屏、分享包、数字人诊断、数字人播放日志、自动上下文和验收文件；报告顶部有 Roadshow Readiness 摘要，并通过 `Stage Evidence` 按自动上下文、路演阶段、补充证据归组复盘。
- `Archive Package` / `archivePlan`：证据报告会输出可归档状态、zip 文件名、包含文件列表和打包命令；只有状态为 `complete` 且无隐私/质量问题时才允许生成归档包。归档 zip 内含 `archive_inventory.json`，记录每个证据文件的 `sizeBytes` 和 `sha256`。
- `Quality Review`：证据报告会检查截图必须是真 PNG、录屏必须是真 MP4，避免占位文本改扩展名后误归档；`route_completion/route_completion_preferences.txt` 中 6 段 route completion key 是否全部为 `true`；未完成、缺失或 false 时状态保持 `needs_manual_evidence`，不能归档。报告也会检查 `route_completion/route_acceptance_checklist.md` 是否已经粘贴 App 内“复制验收”的真实结果，必须包含 `路演验收进度 6/6`、6 个已勾选阶段、6 个固定截图文件和边界声明；保留模板占位或缺项时同样不能归档。`diagnostics/digital_human_readiness.json` 必须是有效 JSON，且包含 `items`、`playbackEvidenceChecks` 和脱敏 `redaction` 说明；报告也会检查 `diagnostics/digital_human_playback.log` 是否包含至少一条完整播放收口链；如果只有空泛日志或缺少 `wav_synth_success/fallback=systemTTS/playback_timeout` 与对应 `playback_finished`，同样不能归档。报告还会检查 `share_packages/all_family.json` 和 `share_packages/selected_member.json` 是否为真实分享包：外层必须包含 `sourceUserId`、`sourceNickname`、`exportDate`、`graphJSON`，内层 `graphJSON` 必须可解析且包含 `people`、`places`、`events`、`facts` 数组，同时不含 `PRIVATE_`、`LOCAL_`、`GENERATION_`、`RAW_TRANSCRIPT`、`FULL_LETTER`、`UNAUTHORIZED_` 等泄漏标记；`share_packages/privacy_check.log` 必须记录 `PASS share package privacy check`、两个 JSON 文件名和 no private/raw transcript/unauthorized 结论。
- `evidence_status.json`、`evidence_status.md` 同时会扫描清单内文本类证据（日志、JSON、Markdown、命令文件、诊断文本）；若发现 token/key/secret 形态内容，状态进入 `needs_privacy_review`，报告只保留文件、行号和模式类别，不保留匹配原文。
- `diagnostics/digital_human_readiness.txt/json`：App 首页启动和诊断页打开时都会自动写入 `Documents/diagnostics/`，preflight 会尝试拷贝到 evidence 目录；手动复制仍可作为兜底。
- `diagnostics/digital_human_playback.log`：真机数字人播放日志证据，App 会自动写入 `Documents/diagnostics/digital_human_playback.log`，preflight 会尝试拷贝到 evidence 目录；日志只包含 `assistant_final`、`wav_synth_success`、`fallback=systemTTS`、`playback_timeout`、`playback_finished source=...` 等结构化标记，不包含对话正文、API Key、Token、voice id 或原始请求头。完整验收建议保留 `web_audio`、`system_tts`、`timeout` 三类样本。`console_capture_next_steps.txt` 仍保留从 `app_console_sample.log` grep 提取播放证据日志的兜底命令，并可继续运行 `python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json` 做严格演练审计：要求三类收口样本都存在，且不回显任何 key/token/secret 原值。
- `screens/`、`recordings/`、`share_packages/`、`route_completion/`：真机 smoke 后需要补齐的证据目录。
- 终端输出中的 `No-device next steps`：接入真机后的人工 checklist 和重跑方式。

有真机时会额外保存：

- `devicectl_device_details.log`、`devicectl_device_displays.log`、`devicectl_device_lock_state.log`：设备状态证据。
- `device_build_settings.log`、`device_signed_build.log`、`device_app_path.txt`：真机签名 build 和安装包路径。
- `devicectl_install_app.log`、`devicectl_launch_app.log`、`devicectl_installed_app.log`：安装和 roadshow 参数启动结果。
- `devicectl_processes_sample.log`：运行进程抽样。
- `devicectl_container_files_root.log`、`devicectl_container_files_documents.log`：App data container 文件列表。
- `<bundle-id>.plist`、`container_preferences_sample.txt`：容器 Preferences plist 及 `dreamjourney.roadshow.seeded.v1`、`dreamjourney.roadshow.offlineMode`、`dj_is_logged_in` 抽样。
- `route_completion/route_completion_preferences.txt`：从容器 Preferences plist 自动抽取 `dreamjourney.roadshow.route.completed.*` 六个完成状态，便于和 App 内复制验收文本交叉核对。
- `conversation_memory.json`：如设备容器中存在，则拷贝对话记忆样本。
- `diagnostics/digital_human_readiness.txt`、`diagnostics/digital_human_readiness.json`、`diagnostics/digital_human_playback.log`：如设备容器中存在，则从 `Documents/diagnostics/` 自动拷贝，减少现场手动复制诊断和抓控制台的风险。
- `console_capture_next_steps.txt`：自动日志不存在或需要复核完整 console 时的 `devicectl --console` 命令，以及从完整 console 生成 `diagnostics/digital_human_playback.log` 的 grep 兜底提取命令。
- `archive_package_next_steps.txt`：完整补齐证据后的一键归档命令，成功时生成 `dreamjourney_roadshow_evidence.zip` 和内置 `archive_inventory.json` 校验清单。

状态语义保持为：

- `xctrace` 未列出在线设备，但 `xcodebuild -showdestinations` 或 `devicectl list devices` 能解析到物理 iOS 设备：继续按真机路径执行，并保留三路探测日志供复核。
- 无真机且未传 `--allow-no-device`：`FAIL`，退出码 `2`，同时保留 evidence 目录。
- 无真机且传 `--allow-no-device`：`PASS_WITH_CONCERNS`，表示脚本/build gate 通过但未执行真机 smoke。
- 有真机但签名 build、安装、启动或容器抽样存在失败：`PASS_WITH_CONCERNS`，表示前置 gate 通过但证据链不完整。
- 有真机且自动 build/install/launch/container 抽样均成功：`PASS`。

本轮未连接真机；验证方式为 shell 语法检查和 stub dry-run：

- `bash -n Scripts/roadshow_device_smoke_preflight.sh`
- `python3 Scripts/RoadshowEvidencePackageVerify/main.py`，确认 evidence report 在缺失证据、完整证据、截图/录屏格式伪造、路线完成状态未全 true、路线验收清单仍是模板或缺项、数字人 readiness JSON 无效或缺项、播放日志内容不足、分享包 JSON 无效、分享包 schema/graphJSON 无效、分享包 sentinel 泄漏和隐私抽查日志未明确 PASS 状态下都能稳定输出 JSON/Markdown 和退出码，并把截图、录屏、`route_completion/route_completion_preferences.txt`、`route_completion/route_acceptance_checklist.md`、`diagnostics/digital_human_readiness.json`、`diagnostics/digital_human_playback.log`、`share_packages/*.json` 与 `share_packages/privacy_check.log` 作为内容质量 gate；真机导出两个分享包样本后，可运行 `python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> --write-log <evidence-dir>/share_packages/privacy_check.log` 生成 PASS 抽查日志；完整证据时 `--archive` 会生成 `dreamjourney_roadshow_evidence.zip`，并在 zip 内写入 `archive_inventory.json` 的 size/sha256 清单，质量/隐私/缺失证据未通过时拒绝打包。
- `python3 Scripts/RoadshowEvidencePackageVerify/main.py` 同时覆盖隐私扫描：证据日志混入 key/token/secret 形态内容时进入 `needs_privacy_review`，`--fail-on-missing` 返回失败，并确认 Markdown/JSON 不回显原始值。
- `python3 Scripts/RoadshowEvidenceScaffoldVerify/main.py`
- `xcrun swiftc ... Scripts/RoadshowRouteVerify/main.swift`，确认 App 内路线 step 的 `evidenceFile` 与 preflight 证据文件名一致。
- `python3 Scripts/RoadshowDeviceSmokePreflightVerify/main.py`，使用 fake `xcrun/xcodebuild/devicectl` 锁住 preflight dry-run：无真机且未传 `--allow-no-device` 必须退出 2 并保留 manifest/build/status；无真机加 `--allow-no-device` 必须输出 `PASS_WITH_CONCERNS` 并生成脚手架；假真机分支和 `xctrace` offline 但 `xcodebuild/devicectl` 可用分支都必须生成 device build/install/launch/container 证据、带严格播放审计命令的 `console_capture_next_steps.txt` 和 6 段 `route_completion_preferences.txt=true`。
- stub 无真机场景：确认创建 evidence 目录、保存 `iphoneos_build_gate.log`，并输出 `PASS_WITH_CONCERNS`。
- stub 真机场景：模拟 iPhone、签名 build、install、launch、container plist 拷贝成功，确认保存安装/启动/容器证据并输出 `PASS`。

## 真机接入后执行方式

```bash
Scripts/roadshow_device_smoke_preflight.sh
```

脚本会在检测到真机后尝试使用 `xcodebuild` 完成签名真机构建，并用 `devicectl` 完成安装和 roadshow 参数启动。若 `xctrace` 把设备列为 offline，但 Xcode destinations / CoreDevice 仍可用，脚本会继续执行并把三路探测结果写入 evidence 目录。Xcode 手动 Run 仍用于逐屏 UI、截图/录屏、控制台观察和现场节奏演练。

逐屏 smoke 或分享包取样后，可重复运行：

```bash
python3 Scripts/roadshow_evidence_report.py /tmp/dreamjourney_roadshow_smoke_<timestamp> --write
```

如果需要把完整证据包作为 release gate，可使用：

```bash
python3 Scripts/roadshow_evidence_report.py /tmp/dreamjourney_roadshow_smoke_<timestamp> --fail-on-missing
```

状态语义：

- `needs_preflight`：脚手架或自动 build/device 上下文缺失，需要重新运行 preflight。
- `needs_privacy_review`：证据文本中出现 token/key/secret 形态内容，需要先删除或脱敏后再归档/分享。
- `needs_manual_evidence`：preflight 已有，但仍缺逐屏截图、录屏或分享包样本。
- `complete`：manifest 中的截图、录屏、分享包和自动上下文均已补齐。

Xcode Run 参数：

```text
--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode
```

Xcode Run 环境变量：

```text
DREAMJOURNEY_SEED=roadshow_demo
DREAMJOURNEY_RESET_DEMO=1
DREAMJOURNEY_ROADSHOW_OFFLINE=1
```

## 6 阶段路演可执行 Checklist

1. `[自动]` 运行 `Scripts/roadshow_device_smoke_preflight.sh`，确认物理 iOS 设备、Bundle ID、签名设置和 iPhoneOS build gate。
2. `[自动]` 运行 `Scripts/verify_phase2.sh`，确认 `RoadshowRouteVerify`、`RoadshowDemoVerify` 和 `SharePackagePrivacyVerify` 通过。
3. `[人工真机]` 在 Xcode 选择已连接 iPhone 和有效 Team。
4. `[人工真机]` 添加启动参数：`--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode`。
5. `[人工真机]` 添加环境变量：`DREAMJOURNEY_SEED=roadshow_demo`、`DREAMJOURNEY_RESET_DEMO=1`、`DREAMJOURNEY_ROADSHOW_OFFLINE=1`。
6. `[人工真机]` Run 到设备并捕获包含 `[RoadshowDemo]` 的控制台日志，确认 reset/seed/offline 生效。
7. `[人工真机]` 首页确认“演示向导”卡片可见，文案为“下一步/清单”入口，不出现“路演模式”“兜底”等工程词。
8. `[人工真机]` 在路线页点击“清空验收”，截图保存为 `screens/02_route_checklist.png`；每完成一段后勾选对应阶段，最后点击“复制验收”并粘贴到 `route_completion/route_acceptance_checklist.md`。
9. `[人工真机]` 阶段1“语音陪伴与数字人”：进入“回忆”，触发 mock/voice 对话，确认消息流和数字人状态变化，保存 `screens/03_memory_voice_digital_human.png`。
10. `[半自动真机]` 阶段1日志：首页启动会自动写数字人诊断文本/JSON；先完成数字人 WebAudio、系统 TTS 兜底和 timeout 演练，App 会把结构化事件写入 `Documents/diagnostics/digital_human_playback.log`；随后重跑 preflight 或用 `devicectl copy from` 同步到 evidence 目录。若自动日志缺失，再按 `console_capture_next_steps.txt` 保存 `app_console_sample.log` 并 grep 生成 `diagnostics/digital_human_playback.log`。播放日志至少包含一种收口路径，完整验收建议覆盖 `wav_synth_success -> playback_finished source=web_audio`、`fallback=systemTTS -> playback_finished source=system_tts`、`playback_timeout -> playback_finished source=timeout`，并运行 `python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json` 确认三类样本齐全且无 credential-shaped 日志内容。
11. `[人工真机]` 阶段1边界：确认口播或页面表达为“不做诊断、不冒充亲人”。
12. `[人工真机]` 阶段2“时空信箱”：进入“信箱”，打开 delivered 演示信件，保存 `screens/04_time_mailbox_delivered_letter.png`。
13. `[人工真机]` 阶段2边界：确认回声文案包含“不是逝者真实回复”，且不把私密正文作为分享内容展示。
14. `[人工真机]` 阶段3“记忆档案馆”：进入“档案”，确认文本、口头禅/性格、旧照片条目可打开。
15. `[人工真机]` 阶段3照片：确认人物、场景、年代或 mock analysis 展示正常，不依赖现场上传，保存 `screens/05_memory_archive_photo_analysis.png`。
16. `[人工真机]` 阶段4“家族足迹点亮”：进入“足迹”，切换城市/全国/世界和全家/祖辈/父辈/我们/下一代；地图不可用时确认显示“家族足迹点亮预览”而不是工程兜底文案，保存 `screens/06_family_footprint_world_generation.png`。
17. `[人工真机]` 阶段4分享：确认点亮区域、统计变化、海报预览/分享/导出入口可用；海报中应能看懂“点亮区域 / 到过的城市 / 迁徙路线”图例。
18. `[人工真机]` 阶段5“亲友关怀看板”：进入“亲友”及成员视角看板，确认观测窗口、数据覆盖、7 天趋势、脱敏观察报告和建议展示，保存 `screens/07_family_care_dashboard_member.png`。
19. `[人工真机]` 阶段5隐私：确认看板和分享周报不展示完整原始对话句子。
20. `[人工真机]` 阶段6“分享包与隐私收口”：导出全体亲友和单个成员分享包，保存 `screens/08_share_package_export_sheet.png`。
21. `[半自动/人工取样]` 抽查分享包 JSON，不含 `localOnly`、私密信件正文、完整对话原文、未授权成员内容；样本保存到 `share_packages/all_family.json` 和 `share_packages/selected_member.json`，运行 `python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> --write-log <evidence-dir>/share_packages/privacy_check.log`，把 PASS 抽查结论写入 `share_packages/privacy_check.log`。
22. `[人工真机]` 全程计时：6 阶段主线控制在 6 分钟内，断网兜底复走控制在 2 分钟内，并保存 `recordings/roadshow_6min_run.mp4`、截图、日志和失败点。

自动检查可以覆盖：构建 gate、设备连接、签名配置可见性、6 阶段 route 合约、seed 内容、边界文案、分享包 JSON 隐私 sentinel。人工真机必须检查：实际启动后的 Banner、逐屏导航、数字人/语音状态、地图渲染、分享面板、截图录屏、现场口播边界、6 分钟节奏，以及断网后的 UI 体验是否顺畅。

## 阻塞项

- 需要物理 iPhone/iPad/iPod。
- 需要 Xcode target 选择有效 Apple Developer Team。
- 需要手动或脚本化保存截图、控制台日志和分享包 JSON 样本。
