# 声音复刻独占槽与逻辑 Profile 合同

日期：2026-07-10

## 结论

声音复刻已从“iOS/接口直接使用火山 `S_` ID + 后端哈希选槽”升级为两层身份：

- `voiceProfileId`：产品逻辑 ID，新建格式 `vp_...`，用于本人/家人绑定、Echo 路由和 API。
- `providerSpeakerId`：火山真实 `S_...`，仅保存在后端，不下发给 iOS。

## 独占分配

- Postgres 表：`voice_clone_slots`。
- provider speaker 为主键，逻辑 profile 为唯一绑定。
- 分配使用 CTE、`FOR UPDATE SKIP LOCKED` 和唯一约束。
- 同 profile 重试复用原槽。
- 容量耗尽返回 HTTP 409，不覆盖其他人的声音。
- 删除后状态为 `retired`，不自动回池。
- 账号超过恢复期被最终清理时，对应槽位同样转为 `retired`，避免残留声音被新用户继承。

## 合成授权

`POST /voice/synthesis` 只允许：

- profile 属于请求 `userId`；
- `sampleStatus=ready`；
- `isEnabled=true`；
- provider 已就绪；
- `qualityAcceptanceRequired=false`；
- 存在 provider binding，或属于 legacy `S_` profile。

## 兼容边界

- 已持久化的旧 `voiceProfileId=S_...` 继续作为 legacy direct profile 使用。
- 新 profile 不再使用 `S_` 前缀。
- deployed smoke 必须提供逻辑 profile ID 和 owner user ID，不会删除真实 profile。
- 试用槽扩容、购买和 provider 数据清除仍属于外部运营动作。

## 验证结果

- 后端 `verify_backend.sh`：141 项测试、编译、声音复刻合同 smoke、FastAPI smoke、`git diff --check` 全部通过。
- iOS：10 个声音复刻/家人/Echo QA guard 通过。
- iOS Debug 模拟器通用构建通过，使用本地 `com.yxj.dreamjourney.app` 覆盖，不改工程共享签名。
- 真机验收按当前决策延期，本轮完成部署与非真机组合门禁。

## 部署要求

- 后端包含新表与 API 合同，必须重新构建并部署服务器容器，不能只重启旧镜像。
- 部署后确认 `/config/runtime` 返回 `contractVersion=2`、`speakerSlotAllocationMode=exclusivePersistentSlot`。
- 线上 smoke 必须使用已存在逻辑 profile 的 owner：`VOICE_CLONE_READY_PROFILE_ID` + `VOICE_CLONE_READY_PROFILE_USER_ID`，且不会创建或删除真实音色。

## 线上部署结果

- 后端 `main` 已部署到 `166e7e7`，API 容器完成重新构建，Postgres/Redis/API 运行正常。
- Postgres 已创建 `voice_clone_slots`。
- `/config/runtime.voiceClone` 已返回 `contractVersion=2`、`speakerSlotAllocationMode=exclusivePersistentSlot`、`speakerSlotReusePolicy=retireOnDelete`。
- 真实 ready profile 已通过 `/voice/synthesis`，输出 `pcm16kMono`、16kHz、16-bit、mono。
- 腾讯数智人 session deployed smoke 通过，使用后端 session 与 asset 来源。
- 数字人 + 复刻音色非真机组合 gate 通过；iOS synthesis 与 Tencent runtime mock 均显式携带 profile owner，PCM 分块、顺序、final chunk 和打断清理通过。

证据路径：

- `tmp/visual-qa/prd-stitch-ui/backend-voice-clone-deployed-smoke/20260710-exclusive-slots-deployed/`
- `tmp/visual-qa/prd-stitch-ui/backend-digital-human-session-smoke/20260710-post-deploy-digital-human-session/`
- `tmp/visual-qa/prd-stitch-ui/digital-human-voice-clone-combo-gate/20260710-post-deploy-dh-voice-combo-final/`

## 验证入口

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
./scripts/verify_backend.sh

cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/backend-voice-clone-deployed-smoke-check.swift .
```
