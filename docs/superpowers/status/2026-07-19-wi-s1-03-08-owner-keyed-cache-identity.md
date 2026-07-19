# WI-S1-03-08 Owner-Keyed Memoir TTS Cache Identity

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-08`
- 子切片：`WI-S1-03-08-OWNER_KEYED_CACHE_IDENTITY_G0`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 结果：`G0_VERIFIED / G1_G3_G4_OPEN`

## 完成内容

- `MemoirTTSCacheEntry` 现在带有不可缺失的 `MemoirTTSCacheIdentity`。identity 包含
  `memoirId`、persona owner、role、`voiceProfileId`、`textHash`、音频格式和 Provider mode。
- 缓存音频与元数据文件名使用 identity digest，而非只使用 `memoirId`。同一账户、同一回忆录的不同
  音色、文本、格式或 Provider 不再覆盖或复用同一份音频。
- 读取缓存必须同时匹配当前回忆录 owner、`memoir` role、当前请求/可用的 voice profile 与当前文本。
  不再提供仅按 `memoirId` 查询的读取 API。
- 后端返回的 `voiceProfileId` 必须与本次请求一致；不一致会明确失败，不会把默认音色或其他 profile
  的音频写入当前回忆录缓存。
- metadata envelope 已升级到 schema v3；旧的 v2 memoir-id-only metadata 无法通过读取校验，会被
  忽略并在需要时从权威文本重新生成，不迁移、不播放。
- 删除回忆录朗读时，会删除当前 owner 下该 memoir 的所有有效 profile/provider 变体；孤立音频或不完整
  identity 不会被重新认领。
- Echo 获取同文本 viseme timeline 时，如果发现多个 voice profile 的有效候选，会返回空并降级到已有
  metering/SDK 路径，避免跨音色错配时间线。
- `S11.generated-audio-and-timeline-cache` inventory 已同步为 owner-keyed v3 cache contract。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-memoir-tts-cache-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
python3 Scripts/QA/product-v4/product-v4-account-store-inventory-check.py
git diff --check
xcodebuild build-for-testing \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

结果：全部通过，`TEST BUILD SUCCEEDED`。

- owner-scope 模型覆盖同一文本不同音色、文本变更、Provider 变更、账户 generation 变更和跨账户读取；
- 静态检查固定 owner/profile/text lookup、response profile 一致性、identity-derived file path 与 timeline
  ambiguity fallback；
- Voice/TTS/Digital Human 聚合 Gate 与 Account Store Inventory Gate 通过；
- 构建仍有既有第三方地图静态库 object-file warning，本切片未新增该类 warning。

## 保持开放的边界

- 未迁移 `VoiceCloneService` 的训练轮询、状态 timer 或本地 profile state；这是同一 Work Item 的后续
  runtime boundary 收敛任务。
- 未执行真实 Provider 合成、试听、Tencent digital-human session、PCM audio-drive 或真机音频验收。
- 旧 v2 cache 仅被拒绝读取；物理清理由既有账号 lifecycle purge 负责，未在本切片执行不可逆迁移。
- G1、G3、G4 仍不能由本次 G0 结果关闭。

## 下一步

在 `WI-S1-03-08` 内继续收敛 `VoiceCloneService` 的 profile/state timer 与 runtime generation 绑定，确保
快速角色切换或账号切换时，旧 profile readiness 回调不能覆盖当前角色；保持 Provider、公开 UI 和真机范围不变。
