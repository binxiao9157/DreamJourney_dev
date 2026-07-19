# WI-S1-03-08 VoiceClone Runtime Operation Boundary

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-08`
- 子切片：`WI-S1-03-08-VOICECLONE_STATE_RUNTIME_BOUNDARY_G0`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 结果：`G0_VERIFIED / G1_G3_G4_OPEN`

## 完成内容

- `VoiceCloneService` 不再把训练 runtime 拆散保存为 `speakerId`、persona 和账户 lease 三个可独立更新的字段。
  新的 `VoiceCloneTrainingRuntimeOperation` 统一包含 operation id、单调 `runtimeGeneration`、speaker id、
  persona target 与捕获的 `AccountLease`。
- 每次训练或等待训练完成都会创建新的 runtime generation，并会先失效旧 operation。旧轮询 timer、旧后端
  回调和旧 completion 只有在 operation、账户 lease 与当前 persona 三者均匹配时才可继续。
- `DigitalHumanContextStore` 的角色变更通知会立即失效不再匹配的训练 operation；不会等待下一次五秒轮询。
  这不会取消 Provider 已接收的训练任务，只会停止客户端将旧结果写入当前角色、当前 UI 或当前轮询状态。
- `queryStatus` 在训练路径中显式携带 operation token。后端返回的 pending/ready/failed 结果在本地持久化、
  UI 回调和 timeout 前均重新验证 token；切换本人/家人或账户 generation 后的旧回调被忽略。
- 前台补查、timer 完成、失败、未找到和 timeout 共用 operation-bound completion 清理。旧 timer 的清理不能
  释放新 generation 的 operation；同角色同账户的等待方只附加到当前 operation，不会重新创建 Provider 轮询。
- `S10.voice-training-poll-runtime` inventory 已更新为 AccountLease + persona + runtime generation 的真实边界，
  不再把已移除的散落字段描述为当前实现。

## 验证

执行：

```bash
swift Scripts/QA/prd-stitch-ui/voice-clone-stale-ready-state-check.swift
bash Scripts/QA/product-v4/run-voice-clone-local-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-dh-account-lifecycle-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
python3 Scripts/QA/product-v4/product-v4-account-store-inventory-check.py
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
python3 Scripts/QA/product-v4/product-v4-docs-check.py
git diff --check
xcodebuild build-for-testing \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

结果：全部通过，`TEST BUILD SUCCEEDED`。

- 新增模型覆盖同一 speaker 的本人/家人快速切换、旧 timer 尝试清理新 generation、账户 generation 切换、
  context change 后旧 ready 回调以及不生成默认个人 profile 的 fail-closed 行为；
- 既有“stale ready”release QA 检查已迁移到 operation token 语义，仍固定 ready/quality gate 与公开 UI
  不夸大训练结果的约束；
- 构建仍包含既有第三方地图静态库 object-file warning，本切片未新增该类 warning。

## 保持开放的边界

- 本切片不修改火山训练/查询 API、Provider 配额、音色槽、语音试听、TTS 合成、腾讯数字人 session 或音频
  owner 行为。
- 训练任务在 Provider 侧完成后，若用户已切换角色或账户，客户端会拒绝旧回调；后续回到对应角色时需由权威
  后端 profile 刷新状态，不在本地重新认领旧 runtime。
- provider failed/unknown 状态、runtime capability expiry、真实 Provider 与真机行为仍属于 `WI-S1-03-08`
  后续 G0/G1/G3/G4 范围，不能由本切片关闭。

## 下一步

继续 `WI-S1-03-08-PROVIDER_CAPABILITY_EXPIRY_G0`：对 VoiceClone/Digital Human runtime capability 的
failed/unknown/expiry 结果建立 typed、fail-closed 的本地边界和 QA 证据；保持公开 UI、Provider 行为和真机范围不变。
