# WI-S1-03-10 数字人 Runtime Stub Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / AUTHENTICATED_RUNTIME_STUB_BOUNDARY_VERIFIED`
- `DigitalHumanRuntimeStubSmoke` 已使用共享 `QAEchoScenarioRunner`，并完成真实 iOS
  V2 登录、AccountLease、客户端发布策略、后端权限和 scoped-broker fallback 的串联验证。
- 该结果只证明本地隔离模拟器能抵达并正确处理后端拒绝边界；不证明腾讯 Provider、scoped
  credential broker、真实数字人 session、音频或真机能力已可用。

## 本次范围

1. `AppDelegate` 的 runtime-stub 场景不再用普通本地登录替代后端会话。它在
   `UI_QA_SIMULATOR` 下执行 synthetic V2 challenge、验证 response、接管 verified credential，
   再通过 `AccountSessionActor` 发布真实的测试 AccountLease。
2. 修正 `BackendAuthSessionStore.strictInt` 对 JSON `NSNumber` 的解析：数值 `1` 不再被误判为
   `Bool`，V2 sessionVersion 可以正常读取。该修复保留对 JSON boolean 的拒绝。
3. 模拟器 UIQA 构建没有 production Keychain entitlement 时，verified V2 session 仅保存于进程内；
   真机和 production 仍要求 Keychain 成功持久化。
4. runtime-stub 专用请求携带无身份值、显式的“在世成年人本人已授权”资格 fixture。此 fixture
   仅位于 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译块；产品 Echo 不会自行伪造
   `subjectEligibility`。
5. smoke 启动独立 memory backend，并且仅在该子进程中临时允许
   `digitalHumanLivePanel` 通过 closed-pilot feature snapshot，目的是验证请求可抵达服务端
   scoped-broker stop condition。脚本退出后进程和临时策略均消失；正式发布策略没有变更。
6. 后端仍返回 `503 digital_human_credential_broker_unavailable`，iOS 映射为
   `scopedBrokerRequired + textOnly`，不会虚假创建 runtime 或宣称 SDK 已准备好。

## 安全边界

- 缺少真实 age/liveness/consent 的生产请求仍由后端 hard deny；本子切片没有把 QA fixture
  提升为产品资格来源。
- `digitalHumanLivePanel` 在公开 release 仍 default-off；临时 policy allowance 不能被部署或
  传递给正常 App 进程。
- 不读取、不写入任何腾讯 appkey、access token、资产 key 或 Provider credential。
- 这个 smoke 不能替代 G3 Provider、G4 真机、主体资格产品流程或法律/隐私审批。

## 验证

```bash
swift Scripts/QA/prd-stitch-ui/digital-human-session-client-check.swift "$PWD"
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
bash Scripts/QA/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh
git diff --check
```

结果：`PASS`。

- 结果文件：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260719-122334/digital-human-runtime-stub-smoke-result.json`
- 结果包含：`completed=true`、`boundaryState=scopedBrokerRequired`、`provider=tencent`、
  `providerMode=blockedUntilScopedBroker`、`runtimeProvider=none`、
  `runtimeIsRealSDKBacked=false`、`fallbackMode=textOnly`、`selectedTabIndex=1`。
- 截图：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260719-122334/01-digital-human-runtime-stub.png`
  显示数字人区域已经稳定降级为普通回响，没有加载任何临时或真实 Provider 素材。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-TENCENT-BACKEND-PCM-DRIVE-RUNNER-PARITY`。

只迁移已有 `TencentBackendPCMDriveMockSmoke` 的 root/Echo 路由到共享 runner，并保持 mock PCM、
audio owner、打断探针和公开 UI 行为不变；不接入真实腾讯会话、复刻 Provider 或真机。
