# WI-S1-02-11 已验证媒体处理器 G0 Admission 预检

日期：2026-07-21

## 本轮范围

后端 `main@de8f284` 新增默认关闭的
`owner_truth_verified_media_processor_shadow`。它只为未来
`sourceExtraction` effect 计算一个脱敏、可复现的 admission plan：

- 父 SourceObject 必须已经通过现有 private/verified/checksum/HEAD/magic-MIME/
  scan receipt 边界；未验证、已撤权、已删除、legacy/mock/temporary object 一律
  不进入处理器。
- plan 绑定 `mediaKind`、processor/version、policy version 和 verified object
  fingerprint，避免旧 callback 或不同 processor/policy 复用同一请求。
- 已成功、可重试失败、终态失败和 unknown attempt 分别映射为 deduplicate、retry、
  terminal record 和 query/reconcile；unknown 不允许盲目重发。
- 返回值只包含状态、配置标识和 hash，不含 owner、vault、object key、URL、媒体
  内容、转写文本或 Provider credential。

## 明确未做

- 不读取文件字节、不调用 OCR/ASR/vision Provider、不访问对象存储。
- 不创建 SourceObject、job、outbox、ExtractionResult、Candidate、Memory、Persona 或
  任何公开 API。
- 不改变既有 Archive、image-analysis、音频、视频、KBLite 或 Echo 行为。
- 默认仍是关闭状态；`execution_mode=synthetic` 仅用于合同验证，真实 Provider mode
  直接保持 unavailable。

## 验证与部署

- `bash scripts/run-backend-verified-media-processor-shadow-gate.sh`：19 项相关测试
  通过，验证 default-off、verified parent、policy/mediaKind、retry/terminal/unknown/
  stale attempt 和无副作用约束。
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh`：1009 tests passed，新增 Gate
  已接入总验证。
- 已推送并部署后端提交 `de8f284`；服务器 `/ready` 返回 database/schema/auth/incident
  全部 ready。
- 部署 API 容器内 synthetic smoke 通过：状态为
  `would_enqueue_source_extraction`，但 `sourceExtractionEnqueued=false`、
  `candidateProposalPerformed=false`、`providerCallPerformed=false`。

## Gate 边界

这是 `WI-S1-02-11` 的 G0 admission 预检，不是完整媒体处理器完成：

1. `ExtractionResult`、SourceObject 持久化、真实 worker/outbox 和 Candidate proposal
   command 仍未接通。
2. 真实对象存储、scan、Provider 质量/成本/留存/delete、媒体权限和敏感媒体政策仍分别
   需要 G1-G4 证据。
3. 因此 Registry 仍保持 `PLANNED/STOP`，本条不加入 current handoff 的
   `evidenceItems`，V4 已实现证据计数仍为 `78/115`。
