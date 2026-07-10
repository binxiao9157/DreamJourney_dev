# 2026-06-29 Backend Voice Clone Deployed Smoke

## 目标

把声音复刻部署后端验收固化成可重复脚本，避免继续靠手动 curl 判断链路是否可用。

## 运行方式

```bash
RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE=1 \
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
./Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

也可以单独运行：

```bash
./Scripts/QA/prd-stitch-ui/run-backend-voice-clone-deployed-smoke.sh
```

脚本优先读取环境变量 `BACKEND_BASE_URL` / `BACKEND_API_TOKEN`，其次读取 `DreamJourney/Config/Backend.local.xcconfig`，再尝试读取后端仓库的私密 `deployed-backend-access.md`。token 只用于请求，不会写入报告。

## 当前探针音色

当前不再在脚本里默认写死真实 `S_` 音色 ID。豆包/火山声音复刻 2.0 试用槽位存在训练次数耗尽和过期风险，deployed smoke 必须显式指定后端已持久化的逻辑 profile 和它的 owner。新 profile 通常使用 `vp_...`；迁移前的 profile 可能仍使用 legacy `S_...`。

示例：

```bash
VOICE_CLONE_READY_PROFILE_ID=<ready logical profile id> \
VOICE_CLONE_READY_PROFILE_USER_ID=<profile owner user id> \
VOICE_CLONE_NON_READY_PROFILE_ID=<optional non-ready logical profile id> \
VOICE_CLONE_NON_READY_PROFILE_USER_ID=<optional profile owner user id> \
./Scripts/QA/prd-stitch-ui/run-backend-voice-clone-deployed-smoke.sh
```

2026-07-03 槽位更新：`S_PhXlHqB52` 已耗尽训练次数；服务器槽位池应切换为 `S_URAKGqB52,S_TRAKGqB52,S_SRAKGqB52`。新用户或重新训练会从新槽位池分配；已有旧音色不会自动迁移，需要重新训练并保存新的 ready `voiceProfileId`。

2026-07-10 合同升级：配置槽改为后端持久化独占分配。deployed smoke 不再创建、覆盖或删除真实 ready profile；它只 refresh 指定 owner 的已持久化 profile，必要时完成质量确认，然后合成验证。三个试用槽只代表最多三个未退休绑定，不能作为无限用户生产容量。

## 验证范围

- `/health` 可达。
- `/config/runtime.voiceClone` 显示：
  - `provider=volcengineVoiceCloneV3`
  - `realProviderReady=true`
  - `synthesisProviderReady=true`
  - `speakerIdMode=trialSpeakerIdPool`
  - `voiceClone2TrialReady=true`
  - `ttsResourceId=seed-icl-2.0`
  - `tencentAudioDrive.supported=true`
- ready 音色通过 `/voice/profiles/.../refresh` 返回 `sampleStatus=ready`。
- ready profile 的 owner 必须与 synthesis 请求 `userId` 一致。
- ready 音色调用 `/voice/synthesis`，请求 `outputMode=tencentAudioDrive`。
- 合成响应返回 `pcm16kMono`、16kHz、16-bit、mono、`byteCount > 0`。
- non-ready 音色如果仍未 ready，调用合成应返回可诊断失败；如果之后变为 ready，脚本会记录诊断探针已变 ready。

## 安全边界

- 不输出音频原始数据。
- 不保存合成音频文件。
- 报告只记录 `byteCount`、格式、状态、provider log id。
- 不输出 `BACKEND_API_TOKEN`。
- 不创建、覆盖或删除真实已训练 profile。

## 产物路径

默认输出到：

```text
tmp/visual-qa/prd-stitch-ui/backend-voice-clone-deployed-smoke/<RUN_ID>/
```

包含：

- `backend-voice-clone-deployed-smoke-result.json`
- `backend-voice-clone-deployed-smoke.log`
- `report.md`

## 和真机验收的边界

该 smoke 只证明“部署后端能用 ready 音色返回腾讯 audio-drive 兼容 PCM”。它不证明：

- 真机扬声器有声音。
- 腾讯数字人口型实际被 PCM 驱动。
- stop 能打断。
- 结束后麦克风能恢复。

这些仍需真机验收。
