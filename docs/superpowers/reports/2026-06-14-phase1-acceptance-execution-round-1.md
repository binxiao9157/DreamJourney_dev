# 阶段一真机验收计划执行记录 Round 1 - 2026-06-14

执行计划：`docs/superpowers/plans/2026-06-14-phase1-true-device-acceptance.md`  
执行方式：主控 agent + 3 个只读审计 agent  
当前结论：代码侧具备进入 P0/P1 真机验收的基础；本轮已完成自动基线、后端非敏感 smoke、真机可用性探测和多模块审计。2026-06-14 18:19 已完成真机构建、安装和启动；下一步进入 P0 手工真机验收。

## 1. 本轮已执行

### 1.1 多 agent 审计

| Agent | 范围 | 结论 |
| --- | --- | --- |
| Gauss | P0 记忆档案馆 | 文本、照片、截图 OCR、语音素材、声纹样本、KBLite 入库、后端 metadata sync 均有代码链路；仍需真机相册/语音/后端 metadata 响应证据。 |
| Sagan | P0 数字人记忆约束 | prompt-safe 图谱、RAG payload、无证据不编造、结束沉淀已有代码和局部验证；仍需真机 3-5 轮录屏和设备日志。 |
| Plato | P1 信箱/关怀/P2 后端 | 信箱 metadata-only、关怀脱敏快照、亲友 active/accepted 权限、后端 token middleware 均有代码链路；仍需两台真机和线上 token 配置证据。 |

### 1.2 自动基线验证

命令：

```bash
bash Scripts/verify_phase1.sh > /tmp/dreamjourney_phase1_before_true_device_acceptance.log 2>&1
```

结果：通过。

关键日志：

- `MemoryArchiveBackendSync verification passed`
- `MemoryArchiveImageAnalysisStrictBackend verification passed`
- `MemoryArchiveVoiceProfile verification passed`
- `DialogMemoryGrounding verification passed`
- `DialogRealtimeRAGFinalASR verification passed`
- `DialogMemoryRAGPayload verification passed`
- `KBLitePromptGraphSanitization verification passed`
- `CareDashboardBackendSync verification passed`
- `TimeMailboxPayloadPrivacy verification passed`
- `RealDeviceRuntimeGate verification passed`
- `RealDeviceAcceptance verification passed`
- `** BUILD SUCCEEDED **`

### 1.3 后端 smoke

使用部署文档里的当前公开入口：

```text
https://www.mmdd10.tech/dreamjourney-api
```

本地 shell 未导出：

- `DREAMJOURNEY_BACKEND_BASE_URL`
- `DREAMJOURNEY_BACKEND_API_TOKEN`
- `DREAMJOURNEY_TEST_USER_ID`

已生成证据：

- `docs/superpowers/evidence/phase1-backend-smoke/health-http.txt`
- `docs/superpowers/evidence/phase1-backend-smoke/runtime-without-token.txt`
- `docs/superpowers/evidence/phase1-backend-smoke/local-env-status.txt`

观测结果：

- `/health` 返回 `200`，服务为 `DreamJourney Backend`，环境为 `production`，store 为 `postgres`。
- `/config/runtime` 未带 token 也返回 `200`，说明线上后端当前未启用 `BACKEND_API_TOKEN` 或网关未拦截该接口。
- 返回内容未泄露真实 key/token，只暴露 configured/missing 风格能力状态。

P2 缺口：

- 服务器需配置 `BACKEND_API_TOKEN`。
- iOS 需配置同值的 `DreamJourneyBackendAPIToken`。
- 配置后重新验证：除 `/health` 外，未带 token 应返回 `401`。

### 1.4 App 后端配置探测

当前 `Info.plist` 已有：

- `DreamJourneyBackendBaseURL`

当前本地 `LocalConfig.plist` 没有：

- `DreamJourneyBackendBaseURL`
- `DreamJourneyBackendAPIToken`

当前 `Info.plist` 没有：

- `DreamJourneyBackendAPIToken`

结论：如果服务器暂未启用 token，App 可连当前公开后端；一旦服务器开启 `BACKEND_API_TOKEN`，App 必须同步配置 `DreamJourneyBackendAPIToken`。

### 1.5 真机探测

`xcodebuild -showdestinations` 识别到真机：

```text
{ platform:iOS, arch:arm64, id:00008150-001402D60A04401C, name:iPhone }
```

`devicectl list devices` 识别为：

```text
iPhone ... available (paired) ... iPhone 17
```

首次真机 Debug 构建失败：

```text
xcodebuild: error: Timed out waiting for all destinations matching the provided destination specifier to become available
The developer disk image could not be mounted on this device.
```

结论：当前不是代码编译错误，而是 Xcode/设备 Developer Disk Image 挂载问题。真机安装和 P0/P1 手工验收需要先解决该设备环境问题。

2026-06-14 18:18 设备重新连接后复测：

- `xcrun xctrace list devices` 已显示 `iPhone (26.6) (00008150-001402D60A04401C)`，不再是 offline。
- `xcrun devicectl list devices` 显示 `connected`。
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'platform=iOS,id=00008150-001402D60A04401C' build` 通过。
- `xcrun devicectl device install app --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 .../DreamJourney.app` 通过。
- `xcrun devicectl device process launch --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 com.yxj.dreamjourney.app` 通过。

证据日志：

- `/tmp/dreamjourney_true_device_build_retry.log`
- `/tmp/dreamjourney_true_device_install.log`
- `/tmp/dreamjourney_true_device_launch.log`

## 2. 本轮修正

1. 修正 `Task 4` 真机步骤：时空信箱当前代码强制最短投递延迟为 5 分钟，不是 1 分钟。
2. 补充后端鉴权说明：服务器环境变量是 `BACKEND_API_TOKEN`，iOS 配置 key 是 `DreamJourneyBackendAPIToken`。

## 3. 当前状态判断

| 模块 | 当前状态 | 下一步 |
| --- | --- | --- |
| 记忆档案馆 | 自动验证通过，代码具备真机验收条件。 | 等真机可安装后执行真实文字/照片/语音素材验收。 |
| 数字人记忆约束 | 自动验证通过，RAG/prompt-safe 代码具备。 | 等真机可安装后执行 3-5 轮真实对话录屏。 |
| 长辈关怀 | 自动验证通过，后端权限链路具备。 | 需要两台真机或两个真实账号做邀请/撤回验收。 |
| 时空信箱 | 自动验证通过，metadata-only 代码具备。 | 按 5 分钟最短延迟执行真实投递验收。 |
| 后端 smoke | `/health` 正常，Postgres 正常。 | 配置 `BACKEND_API_TOKEN` 后补 authenticated smoke。 |
| 真机安装 | 已完成真机构建、安装、启动。 | 继续 P0 真机手工验收。 |

## 4. 后续执行顺序

1. 执行 P0-1 记忆档案馆真实素材建库验收。
2. 执行 P0-2 数字人对话记忆约束验收。
3. 配置服务器 `BACKEND_API_TOKEN` 与 iOS `DreamJourneyBackendAPIToken`。
4. 重新运行后端 authenticated smoke。
5. 执行 P1-1 关怀看板跨设备验收。
6. 执行 P1-2 时空信箱真实信件验收。
7. 汇总阶段一证据包。
