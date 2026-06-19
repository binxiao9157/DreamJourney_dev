# Voice Clone Backend Contract

日期：2026-06-19

## 目标

补齐声音克隆壳层的后端合同，覆盖 `voiceProfileId`、样本状态、授权确认、禁用/删除生命周期，并保持默认发布态隐藏。

## 合同范围

- `POST /voice/profiles`
  - 保存 mock voice profile 合同。
  - 必须带 `authorizationConfirmed=true`。
  - 仅允许 `generationAllowed` 或 `familyCircle` 隐私范围。
  - 过滤 `rawSampleURL`、`sampleLocalPath`、`audioBase64` 等本地/原始样本字段。
- `GET /voice/profiles/{user_id}`
  - 拉取用户 voice profile 列表。
- `POST /voice/profiles/{user_id}/{voice_profile_id}/disable`
  - 将样本状态置为 `disabled`，不执行真实 provider 操作。
- `DELETE /voice/profiles/{user_id}/{voice_profile_id}`
  - 将样本状态置为 `deleted` 并保存 tombstone，作为后续真实删除样本、训练产物和授权记录的合同占位。

## 发布策略

- `DJFeature.voiceCloneShell` 默认不启用。
- QA 可通过 `DJEnableProfileHiddenBranches` 或显式 feature flag 查看壳层。
- 本轮不做真实声音克隆训练、质量验收、真实音频样本上传或 provider 删除。

## 验证入口

```bash
swift tmp/visual-qa/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-clone-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

后端测试：

```bash
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_core_services.VoiceCloneProfileAPITests
.venv/bin/python -m unittest tests.test_postgres_store.PostgresStoreTests.test_store_persists_voice_profiles_disable_and_delete_states
```
