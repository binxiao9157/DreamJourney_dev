# 2026-06-12 数字人对话资源治理

## Manifest 作用

`DreamJourney/Resources/web/avatar_manifest.json` 是当前 iOS 工程内嵌数字人资源的最小可用资源清单。它记录默认形象包使用的 `DHLiveMini` 引擎、`mini2.0` 资源版本、`model_size=184`、`fps=25`、帧数，以及视频、gzip 数据、WASM、JS 和公共贴图文件的相对路径与 sha256。

这个 manifest 用于把散落在 `Resources/web` 下的运行时资源变成可发现、可校验的资产包，降低文件缺失、替换或版本错配时的排障成本。

## 运行命令

```bash
cd /Users/yxj/.config/superpowers/worktrees/DreamJourney_dev/phase2-mock-dialog-engine
python3 Scripts/DigitalHumanAssetVerify/verify_avatar_assets.py
```

脚本只读取 `avatar_manifest.json` 和 manifest 声明的资源文件，不读取 `Info.plist`，也不输出 API Key、token 或其他 secret。

## 当前校验范围

- 检查 manifest 基础字段：`engine=DHLiveMini`、`engine_version=mini2.0`、`model_size=184`、`fps=25`。
- 检查 video、data、wasm、js、common texture 文件存在。
- 计算并匹配每个文件的 sha256。
- 解压 `combined_data.json.gz`，确认 gzip JSON 可读。
- 校验 `combined_data` 包含 `json_data`、`face3D_obj`、`size`、`version`。
- 校验 `size=184`，并确认 `json_data` 长度与 manifest 的 `frame_count` 一致。

## 当前限制

- 未校验 `01.mp4` 的真实编码、分辨率、时长或帧率；当前只用 manifest 的 `fps=25` 描述资源契约。
- 未校验 WASM/JS 的运行时兼容性或 WebGL 能力，只校验文件完整性。
- 未对资源做签名或授权验证，sha256 只能证明本地文件与 manifest 记录一致。
- manifest 暂未接入运行时代码选择逻辑；当前主要作为打包和发布前的资源健康检查。

## 对话功能接入进展

首页 `AIRecordingViewController` 已接入数字人 WebView 容器，加载本地 `DHLiveMini.js`、`DHLiveMini.wasm`、`MiniLive2.js`、`MiniMateLoader.js` 和默认形象包。对话状态已映射到数字人：

- `onDialogStarted` / ASR 中间结果：正在聆听。
- ASR 最终结果 / Chat streaming：正在整理。
- `onTTSStarted`：正在讲述，并用文本长度估算说话动画时长。
- `onTTSFinished` / error / end：清空数字人音频状态并回到聆听或待机。

WebView 内已预留 `window.DreamJourneyAvatar.feedAudioBase64(base64Wav)`，用于后续把 TTS 生成的 WAV 音频直接喂给 `DHLiveMini.wasm`。

## 上游音频桥结论

根据 `kleinlee/DH_live` 上游 `web_demo/static/js/dialog_realtime.js` 的实现，真正口型同步链路不是裸 PCM 或 Float32，而是完整 WAV bytes：

1. 服务端返回 Base64 WAV。
2. 前端转成 `Uint8Array`。
3. 调用 `Module._setAudioBuffer(ptr, byteLength)` 喂给 WASM。
4. 同一段音频再通过 Web Audio `decodeAudioData` 播放。
5. WASM 在渲染循环中由 `Module._updateBlendShape(...)` 生成口型系数。

推荐下一步：将当前实时语音 SDK 的内部播报模式，逐步改成“LLM 文本 + VolcEngine HTTP TTS 生成 16kHz mono PCM16 WAV + WebView 播放/驱动口型”的统一音频队列。这样可以避免原生播放器和数字人口型不同步。

## 2026-06-12 下一步实现

已新增 `DigitalHumanSpeechService`，用于把实时对话中 `onTTSStarted(text:)` 拿到的短句文本，调用 VolcEngine HTTP TTS 合成为 WAV，并通过 `window.DreamJourneyAvatar.feedAudioBase64(...)` 喂给 WebView 数字人。

实现策略：

- `VolcEngineTTSRequestFactory` 支持 `mp3` 和 `wav` 两种 encoding。
- 回忆录 TTS 仍默认输出 MP3，不改变已有存储和播放逻辑。
- 首页数字人 TTS 只在 `VolcEngineAPIKey` 与 `VolcEngineVoiceType` 都可用时启用。
- 启用后会关闭实时 SDK 内置播放器，改由 WebView 数字人播放 WAV，避免双播。
- 每次 TTS 请求带本地 request id，旧请求慢返回时会被丢弃，避免上一句串到下一轮。

当前仍需真机验证：

- 实时 SDK 关闭内置播放器后，是否仍稳定回调 `onTTSStarted(text:)`。
- VolcEngine `/api/v1/tts` 在 `encoding=wav` 下是否稳定返回 `RIFF/WAVE` 音频。
- WKWebView WebAudio 在真机首次点击麦克风之后是否允许播放。
- 数字人口型与 WebAudio 播放是否同步。

## 2026-06-12 追加推进

已把数字人“说话”链路从 SDK TTS start 的脆弱触发点前移到 Chat final text：

- `DialogEngineDelegate` 新增 `onAssistantFinalText(text:)` 默认回调。
- `DialogEngineManager` 在 `SEEventChatEnded` 或 streaming + TTS start 汇合点发布最终 assistant 文本，并用 `deliveredAssistantFinalText` 防止后续 TTS start 重复展示/重复合成。
- `AIRecordingViewController` 将 `onAssistantFinalText` 与 `onTTSStarted` 收敛到同一个 `publishAssistantResponse`，同一轮 assistant 文本只展示、入库、触发数字人 TTS 一次。
- `onTTSFinished` 不再直接清理 WebView 数字人音频；如果正在等待数字人 WAV/WebAudio 播放结束，则由 WebView 回传后再回到聆听态。
- WebView 数字人运行时新增 `audio_ended` 与 `speech_envelope_ended` 健康事件，分别对应真实 WAV 播放结束与兜底口型动画结束。
- Mock 对话引擎验证已覆盖 assistant final text 必须早于 TTS finished 出现。

真机验证时重点观察日志：

- `[DigitalHuman] { type: audio_buffered, ... }`
- `[DigitalHuman] { type: audio_ended, ... }`
- `[DigitalHuman] { type: speech_envelope_ended, ... }`
- 不应出现同一段 AI 回复重复插入消息流或重复触发 WAV 合成。

## 2026-06-12 路演稳态保护

本轮按多 agent 审查结论补齐数字人对话的 demo 兜底：

- 数字人 WAV TTS 启用时，实时 SDK 内置播放器仍保持关闭，避免双播；如果 VolcEngine HTTP TTS 合成失败，Native 会继续驱动数字人口型动画，并用 `AVSpeechSynthesizer` 播放同一段文本作为听觉兜底。
- WebView 回传 `audio_error`、`audio_decode_error`、`audio_fallback` 或 `evaluateJavaScript` 失败时，统一进入系统 TTS 兜底，不再只停留在“嘴动没声”。
- 每次数字人播报会挂一个 14 到 28 秒的 watchdog；如果 WebAudio、WASM 或系统兜底没有回调结束，会自动清理状态并回到“可以继续说”，避免卡在“正在讲述”。
- `onError`、后台、登出、安全事件和会话结束都会统一停止系统兜底播报、取消 watchdog、清理 WebView 音频，并确保并行录音停止。
- 增加结构化日志：`assistant_final`、`wav_synth_success`、`wav_synth_failed`、`webview_audio_failed`、`playback_timeout`、`playback_finished`，真机现场可以快速判断当前轮走的是 WebAudio、系统 TTS 还是超时兜底。
- 新增自动落盘证据：首页启动和诊断页打开会把脱敏诊断写入 `Documents/diagnostics/digital_human_readiness.txt/json`；运行时会把脱敏后的播放生命周期标记写入 `Documents/diagnostics/digital_human_playback.log`。这些文件只保存配置状态、request id、source、字节数/字符数等技术元数据，不保存用户正文、API Key、Token、voice id、请求头或原始服务错误；preflight 会尝试把它们直接拷贝到 evidence 目录，控制台 grep 只作为兜底。

## 2026-06-12 故障恢复 UI

数字人故障恢复已从“后台兜底”升级为“路演可见的恢复体验”：

- `DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(reason:)` 把 WAV 合成失败、WebAudio 解码/播放失败和 watchdog 超时映射为非技术化文案。
- 首页新增数字人故障恢复卡，展示“已切换到系统语音 / 播放已自动收尾”等状态，明确“不影响继续对话”。
- 恢复卡提供“重试数字人”和“继续语音”两个动作：前者会停止系统兜底并重新合成当前回答；即使 watchdog 已经 `playback_timeout -> playback_finished source=timeout` 自动收尾，也会保留本轮回答文本用于重试。后者隐藏提示、清理重试缓存并保持主线可继续。
- `onError` 不再直接 toast 底层 `localizedDescription`，避免真机路演出现 API、网络或 SDK 原始错误文案。
- `DigitalHumanFallbackUIVerify` 已接入阶段2验证，静态锁住故障卡、恢复动作、friendly fallback presentation 和 raw technical error 防暴露。

## 2026-06-12 真机诊断中心

为降低真机路演排障成本，首页右上新增“数字人真机诊断”入口：

- `DigitalHumanReadinessReport` 汇总当前对话引擎、数字人口型 TTS、实时语音凭证和 OpenAvatar 后端状态。
- 诊断状态只显示“已就绪 / 可演示 / 需配置”、认证模式、资源 ID、localhost 真机风险和逐项修复建议，不输出任何 API Key、Token、Secret 或 realtime request header。
- `DigitalHumanDiagnosticsViewController` 以 sheet 形式展示诊断结果，支持复制脱敏排障文本和 JSON，便于现场快速反馈配置问题。
- 诊断页新增“音频链路验收”卡，列出三种真机收口日志：`wav_synth_success -> playback_finished source=web_audio`、`fallback=systemTTS -> playback_finished source=system_tts`、`playback_timeout -> playback_finished source=timeout`；复制文本和 JSON 同步包含这些验收口径。
- 路演证据中心和 preflight manifest 新增 `diagnostics/digital_human_readiness.txt`、`diagnostics/digital_human_readiness.json`、`diagnostics/digital_human_playback.log`，`roadshow_evidence_report.py` 会把自动/手动诊断文本、诊断 JSON 和自动/兜底播放日志纳入完整度报告。
- 保存到 evidence 目录后，诊断文本/JSON 会再经过 `roadshow_evidence_report.py` 的隐私扫描；如混入 token/key/secret 形态内容，报告进入 `needs_privacy_review`，只展示文件、行号和模式类别，不展示原始值。
- `DigitalHumanReadinessVerify` 覆盖 modern API Key、legacy 三件套、mock/offline、missing 配置、localhost 后端风险、修复建议、音频链路验收清单、JSON 证据和脱敏输出。
- `DigitalHumanDiagnosticsUIVerify` 覆盖首页入口、sheet 展示、音频链路验收卡、复制文本/JSON 脱敏诊断和“不展示密钥”文案。

## 2026-06-14 冷启动稳定层

为解决首页打开时数字人从 loading/shell 明显切到真人画面的观感问题，本轮把数字人 WebView 启动策略改为“真人 poster 首屏稳定展示 + live canvas 第一帧后淡入”：

- 从默认 `01.mp4` 抽取 `avatar_poster.png`，做透明抠像和绿色溢色压制，并加入 Xcode Resources。
- `avatar_manifest.json` 新增 poster sha256，`DigitalHumanAssetVerify` 会同时校验 poster、JS、WASM、视频和 gzip 数据。
- `AIRecordingViewController` 中 WebView 不再以空白 alpha 等待 live canvas，而是首屏直接展示透明真人 poster；`loadingSpinner` 和 `startMessage` 默认隐藏，不再在用户首屏露出“正在加载/已就绪”文案。
- `MiniMateLoader.js` 不再在 Qt onLoaded 阶段强行显示 spinner；live canvas 只在 `avatar_video_surface_ready` 后淡入，poster 同步淡出。
- `DigitalHumanStartupRevealVerify` 新增 gate：检查 poster 资源、Xcode resource entry、loading 文案隐藏、poster 不放在初始隐藏的 `screen2` 中、禁止 timeout 或 first-frame 过早 reveal。

验证命令：

```bash
bash Scripts/verify_phase2.sh
```

结果：阶段2脚本通过，iPhoneOS Debug build 通过。`TGToast.swift` 已迁移到 `connectedScenes` / `UIWindowScene` 获取 key window，`Copy LocalConfig.plist` build phase 已增加 output marker，并由 `BuildWarningCleanupVerify` 锁定回归。

## 2026-06-15 音视频节奏同步与 DH_live/MatesX 校准 PoC

本轮把数字人音视频能力拆成两层推进：

1. 先保证可验收的中期效果：嘴部/人物动作跟声音节奏一致。
2. 再开启 DH_live/MatesX 口型 retarget 数据链路，但默认只做校准观测，不直接把高风险 3D 嘴部贴片画到真人脸上。

### 当前音频播放与节奏同步链路

当前真实声音由 iOS 原生 `AVAudioPlayer` 播放，不再依赖 WebAudio 作为唯一出声路径。WebView 数字人层拿到同一段 WAV 做口型/节奏输入：

- `DigitalHumanSpeechService` 生成 Base64 WAV。
- `AIRecordingViewController.startDigitalHumanNativeAudio(...)` 解码同一份 WAV。
- `DigitalHumanSpeechEnvelope` 从 WAV PCM16 数据中解析 20fps 左右的能量包络。
- `DigitalHumanAvatarView.bufferSpeechAudioBase64(...)` 调用 Web 侧 `bufferAudioBase64ForLipSync(...)`，只把同源 WAV 传给 `Module._setAudioBuffer`，不在 WebAudio 里再次播放，避免双播。
- `DigitalHumanAvatarView.playSpeechEnvelope(duration:prompt:envelope:)` 把原生播放器时长和能量包络传给 `DreamJourneyAvatar.playSpeechEnvelope(durationSeconds, energyEnvelope)`。
- `MiniLive2.js` 的 `DreamJourneyMiniLive.playForDuration(durationSeconds, energyEnvelope)` 根据能量包络调制真人视频播放、暂停和 `playbackRate`。

这个阶段的能力边界是“音频能量级同步”：有声段动作更明显，停顿段会减弱或停住，整体跟随同一段 TTS WAV 的播放时长。它不是逐音素/viseme 级真口型同步，不能保证每个字母、声母、韵母对应不同嘴型。

### DH_live/MatesX 校准模式

为继续验证 DH_live/MatesX 路线，当前默认把 `CONFIG.faceRetargetEnabled` 打开，但把 `CONFIG.faceRetargetMode` 固定为 `calibration`：

- `off`：完全关闭 retarget 链路。
- `calibration`：运行 DH_live 的 `Module._updateBlendShape(...)`，上报嘴部系数和人脸区域，但不绘制 3D 嘴部贴片。
- `overlay`：尝试绘制嘴部贴片，仅用于后续手动校准；绘制前会检查区域大小、边界、黑块比例和 alpha，有异常就触发安全抑制。

默认选择 `calibration` 的原因是：之前直接启用贴片时出现黑块遮嘴、坐标错位和视觉突兀。本轮先收集 DH_live 的真实数据证据，确认音频驱动和人脸定位是否稳定，再决定是否进入 `overlay` 调参。

### 新增运行时健康事件

真机日志重点看这些事件：

```text
[DigitalHuman] { type: lip_audio_buffered, ... }
[DigitalHuman] { type: avatar_chroma_key_stats, ... }
[DigitalHuman] { type: avatar_retarget_calibration, ... }
[DigitalHuman] { type: retarget_overlay_suppressed, ... }
[DigitalHuman] { type: avatar_retarget_mode_changed, ... }
[DigitalHuman] { type: avatar_retarget_overlay_drawn, ... }
```

字段判断口径：

- `lip_audio_buffered`：同一段 WAV 已传给 DHLiveMini WASM。若没有出现，说明音频没有进入 DH_live 引擎。
- `avatar_chroma_key_stats`：透明抠像采样。应看到画面既有透明样本，也有不透明人物样本；如果长期全不透明或全透明，说明绿幕参数或画布绘制有问题。
- `avatar_retarget_calibration.bsMax / bsMean`：DH_live 嘴部 blendshape 变化。说话时数值应随音频变化；如果一直为 0 或固定值，说明 `_setAudioBuffer -> _updateBlendShape` 链路没有真正驱动起来。
- `avatar_retarget_calibration.rect / rectAreaRatio`：人脸/嘴部区域定位。若区域过大、越界或跳动明显，说明贴片坐标不能直接启用。
- `retarget_overlay_suppressed`：安全抑制生效。`calibration_mode` 是预期行为；`suspicious_overlay_pixels` 表示贴片像素仍有黑块或 alpha 异常。
- `avatar_retarget_overlay_drawn`：只有切到 `overlay` 且安全检查通过时出现。

### 真机验收方式

1. 安装当前分支。
2. 打开首页，确认真人透明数字人首屏没有绿色背景、黑色嘴块或卡通兜底脸。
3. 点麦克风，让数字人播报一段 8-15 秒回答。
4. 观察声音与人物动作：声音停顿时人物动作应明显减弱或停住，回答结束后动作停止。
5. 从控制台或播放日志中查：
   - `lip_audio_buffered`
   - `avatar_chroma_key_stats`
   - `avatar_retarget_calibration`
   - `playback_finished source=...`
6. 暂不要求出现 `avatar_retarget_overlay_drawn`。当前默认不绘制贴片，避免影响观感。

### 下一步分支

如果真机日志显示：

- `lip_audio_buffered` 出现，且 `bsMax/bsMean` 随说话变化：说明 DH_live 音频驱动链路可用，下一步进入 `overlay` 模式做贴片区域、纹理 alpha、黑块抑制和坐标校准。
- `lip_audio_buffered` 出现，但 `bsMax/bsMean` 长期不变：重点排查 `Module._setAudioBuffer` 的 WAV 格式、采样率、WASM 音频消费时机。
- `avatar_chroma_key_stats` 显示透明/不透明样本异常：优先调绿幕 `similarity / smoothness / spill`，不进入贴片校准。
- `overlay` 一启用就被 `suspicious_overlay_pixels` 抑制：说明当前贴片输出仍有黑块或 alpha 异常，需要先修 DH_live 贴片纹理/混合方式。

新增验证：

```bash
python3 Scripts/DigitalHumanRetargetCalibrationVerify/main.py
xcrun swiftc DreamJourney/Sources/Services/DigitalHumanSpeechEnvelope.swift Scripts/DigitalHumanSpeechEnvelopeVerify/main.swift -o /tmp/dreamjourney_digital_human_speech_envelope_verify
/tmp/dreamjourney_digital_human_speech_envelope_verify
python3 Scripts/DigitalHumanSpeechEnvelopeIntegrationVerify/main.py
```

这些脚本已接入 `Scripts/verify_phase1.sh` 的数字人验证区块。
