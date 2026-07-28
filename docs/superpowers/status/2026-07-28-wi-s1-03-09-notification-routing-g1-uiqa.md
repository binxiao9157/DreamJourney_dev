# WI-S1-03-09 G1：通知与 Deep Link 安全路由模拟器 UIQA

日期：2026-07-28
Work Item：`WI-S1-03-09`
Authority lock：`IOS_COMPOSITION`

## 结论

`G1 = SCOPED_VERIFIED`。

本轮补齐通知和 Deep Link owner routing 的模拟器交互证据。QA harness 使用与
`AppDelegate`、`SceneDelegate` 相同的 `AppCoordinator` ingress，只注入合成且不含私有正文的
opaque route envelope；不调用 APNs、后端、音频、数字人或任何资源详情页。

## 覆盖的路由

1. 合法 `timeLetter` notification response 进入中性“记忆档案”Tab。
2. 合法 `echoDelayedReply` remote notification 进入中性“回响”Tab。
3. 合法 `careSignal` Deep Link 进入中性“记忆档案”Tab。
4. 错误 resource owner、旧 generation 和缺失字段的 Deep Link 均被拒绝，且不改变安全落点。
5. 三条合法 route 消费完成后 inbox 无残留 pending route。

为避免测试在同一个主循环连续切换 Tab 造成 UIKit appearance transition 竞态，三条合法 route
按正常 ingress 的主循环节奏顺序派发；最终结果和截图只在 Archive 画面稳定后写入。该处理仅位于
`UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译分支，不改变生产路由或产品视觉。

## 验证

```bash
bash Scripts/QA/prd-stitch-ui/run-notification-runtime-route-uiqa-smoke.sh
python3 Scripts/QA/product-v4/qa-launch-configuration-static-check.py
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
python3 Scripts/QA/product-v4/notification-runtime-route-static-check.py
bash Scripts/QA/product-v4/run-notification-runtime-route-owner-gate.sh
bash Scripts/QA/product-v4/run-message-notification-widget-account-lifecycle-gate.sh
bash Scripts/QA/product-v4/run-message-notification-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-echo-delayed-reply-owner-scope-gate.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
git diff --check
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath tmp/visual-qa/product-v4/DerivedDataWIS10309G1 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app \
  DREAMJOURNEY_DEVELOPMENT_TEAM=2BTR77V3R8
```

结果：通过。

本轮模拟器产物：

```text
tmp/visual-qa/prd-stitch-ui/notification-runtime-route-uiqa-smoke/20260728-102126/
```

结果 JSON 的关键字段：

```text
completed=true
initialSelectedTabIndex=1
timeLetterRouteSelectedArchive=true
echoRouteSelectedEcho=true
deepLinkRouteSelectedArchive=true
crossOwnerRouteIgnored=true
staleGenerationRouteIgnored=true
malformedDeepLinkIgnored=true
validRouteDeliveryCount=3
rejectedRouteCount=3
pendingRoutesDrained=true
finalSelectedTabIndex=0
```

最终截图已经复核为“记忆档案”内容和 Archive Tab 一致，不再出现测试内连切 Tab 导致的视觉滞后。

## 未关闭 Gate

- `G3`：后端 device subscription、message/deeplink capability、APNs 凭据与服务端资源授权 receipt。
- `G4`：真实设备推送到达、锁屏隐私、错误账户点击、token 轮换/撤销及产品验收。

本 Work Item 没有后端改动，不需要部署。模拟器运行时出现的 `remote-notification UIBackgroundModes`
提示属于 APNs 交付能力的 G3/G4 范围；本轮未为 QA smoke 擅自开启后台远程通知模式。
