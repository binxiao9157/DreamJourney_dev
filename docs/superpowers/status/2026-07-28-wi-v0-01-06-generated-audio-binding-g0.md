# WI-V0-01-06 G0：GeneratedAudio 绑定预检

日期：2026-07-28
Work Item：`WI-V0-01-06`

## 本轮范围

后端提交 `fe51e12` 新增默认关闭的
`voice_generated_audio_binding_shadow`。它为未来的 GeneratedAudio 建立
hash-only 请求绑定：

- `commandId`、内部 profile/version、purpose、policy、来源哈希和文本哈希；
- output mode、格式、采样率、声道和短 TTL；
- 腾讯 audio-drive 只接受 `pcm16kMono / 16kHz / mono`；
- 同一稳定 command 的重放和冲突可观察；跨 owner/vault/profile version 不可提升。

该模块不接收原文或音频字节，不调用火山，不写对象存储、缓存、GeneratedAudio、receipt 或
公开接口。现有 `/voice/synthesis` 兼容链路未改动。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-generated-audio-binding-g0-gate.sh
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-dh-authority-g0-gate.sh
env STORE_BACKEND=memory /tmp/dreamjourney-backend-test-venv/bin/python \
  -m unittest -v tests.test_core_services.VoiceCloneProfileAPITests
git diff --check
```

结果：新增 7 项 G0 测试、既有 11 项 Voice/DH authority 测试和 23 项声音复刻接口测试均通过。

## 未关闭 Gate

- `G1`：iOS 缓存 envelope 尚未消费此绑定和 TTL。
- `G2`：无 GeneratedAudio / provider receipt 持久化或对象存储。
- `G3`：无真实火山 TTS receipt、地区、成本或删除证据。
- `G4`：无真机听感与腾讯 PCM-drive 验收。

因此本项只登记为 scoped G0，不部署、不推送、不提升为公开语音能力。
