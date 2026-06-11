# Roadshow Device Smoke Preflight

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

## 结论

当前机器未连接可用 iPhone/iPad/iPod 真机，因此不能完成“真机逐屏 smoke”。已新增并验证真机 preflight 脚本，iPhoneOS build gate 通过；下一步需要接入真机后执行 Xcode Run、截图和日志留档。

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

## 真机接入后执行方式

```bash
Scripts/roadshow_device_smoke_preflight.sh
```

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

## 逐屏验收口径

1. 控制台出现 `[RoadshowDemo] seed applied` 或 reset/seed 相关日志。
2. 信箱：至少一封 delivered 演示信件，回声边界文案可讲清。
3. 档案：文本、性格/口头禅、照片 mock analysis 可打开。
4. 回忆：offline mode 下走 mock dialog，不依赖 Speech SDK 或外部网络。
5. 亲友：关怀看板展示脱敏观察报告、观测窗口和建议信号。
6. 分享：知识库/同步分享包入口可生成 sanitized package，并抽查不含 localOnly 原文。
7. 全程截图/日志留档，主线控制在 6 分钟内。

## 阻塞项

- 需要物理 iPhone/iPad/iPod。
- 需要 Xcode target 选择有效 Apple Developer Team。
- 需要手动或脚本化保存截图、控制台日志和分享包 JSON 样本。
