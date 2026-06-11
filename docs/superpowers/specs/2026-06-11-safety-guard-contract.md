# Safety Guard Contract Spec

日期：2026-06-11

来源：阶段2 Safety agent 只读审查结果。

## 当前覆盖

- `SafetyMonitor` 已在本地识别 `medium/high` 风险，其中 `high` 阻断角色扮演。
- `DialogEngineManager` 已在 ASR、LLM query、Chat streaming、TTS 句子开始等回调链路做本地 safety。
- `AIRecordingViewController` 已在危机触发后丢弃当前会话、停止录音，并阻止回忆录生成。
- `TimeMailbox` 和 `MemoryArchive` 已在本地保存前阻断高风险文字。
- `CareDashboard` 只展示聚合信号，不展示原文。

## 关键缺口

- `SEEventChatTextQueryConfirmed` 可能发生在远端 LLM 前后，本地无法证明高风险文本没有进入远端链路。
- `DeepSeekService.chat`、知识抽取、图片分析、回忆录生成和 TTS 尚无统一服务端前置 guard。
- `SafetyAssessment` 当前包含 `userText` 原文，不适合作为审计存储模型。

## API 合约

### `POST /v1/safety/evaluate`

Request:

```json
{
  "request_id": "uuid",
  "client_event_id": "uuid",
  "session_id": "opaque",
  "user_id_hash": "hmac-sha256",
  "device_id_hash": "hmac-sha256",
  "surface": "dialog|mailbox|memory_archive|photo_analysis|memoir|knowledge|tts",
  "stage": "user_input_pre_llm|assistant_output_pre_ui|tts_input_pre_synth|local_save_pre_persist|image_pre_analysis|analysis_summary_pre_persist",
  "content_type": "text|transcript|image|summary",
  "text": "transient only",
  "media_ref": "optional upload token",
  "locale": "zh-CN",
  "sdk_event_type": "SEEventChatTextQueryConfirmed",
  "target": "volcengine_dialog|deepseek|volcengine_tts|local_only",
  "no_store_raw": true
}
```

Response:

```json
{
  "decision_id": "uuid",
  "risk_level": "safe|low|medium|high|critical",
  "action": "allow|allow_with_care|block|escalate",
  "categories": ["self_harm", "grief_boundary", "violence", "abuse", "privacy"],
  "policy_version": "safety-2026-06-11",
  "reason_code": "SELF_HARM_EXPLICIT",
  "safe_replacement_key": "crisis_intervention_default",
  "can_persist": false,
  "can_send_to_llm": false,
  "can_send_to_tts": false,
  "can_show_in_family_dashboard": false,
  "audit": {
    "raw_content_stored": false,
    "content_hmac_sha256": "server-keyed-hmac",
    "content_length": 42,
    "evaluated_at": "iso8601",
    "latency_ms": 35
  }
}
```

## 客户端接入原则

- 新增 `SafetyGuardClient.evaluate(...)`，所有远端 LLM/TTS/图片分析/知识抽取/回忆录入口必须通过该客户端。
- 本地 `SafetyMonitor` 作为 quick check；本地 high 立即危机阻断，不排队重试原文。
- 服务端不可用时，远端 LLM/TTS/图片分析/知识抽取 fail closed。
- 本地私密保存可在离线时按本地 guard 保存，但标记 `local_only_pending`。
- Volcengine SDK 若无法证明最终 ASR 在远端 LLM 前可拦截，则不能作为阶段2高安全验收链路。

## 最小验收矩阵

- 高风险 ASR 不进入角色回复、不写 transcript/KBLite/CareDashboard。
- 高风险助手输出不进入 UI 正式消息、不进入 TTS、不写 memory。
- 高风险信箱正文不创建 letter，不保存原文。
- 高风险档案文字不保存 item，不写 Stage1。
- 图片分析摘要高风险不写 archive/KBLite/transcript。
- 回忆录 transcript/prose 高风险不生成、不保存、不进入 TTS。
- 服务端不可用时远端模型/TTS fail closed。
- 审计中 `raw_content_stored=false`，日志不含原文片段。

## 分级

Must:

- 服务端 `/safety/evaluate` 合约。
- iOS `SafetyGuardClient`。
- 所有 LLM/TTS/图片分析/知识抽取/回忆录入口接入 guard。
- 高风险不进入回忆录、知识库、亲友看板和 TTS。

Should:

- medium 风险进入 care mode。
- 下游服务强制校验 `decision_id`。
- HMAC 内容指纹用于审计关联。

Later:

- 多模型 safety classifier。
- 人工复核后台。
- 区域化危机资源配置。
