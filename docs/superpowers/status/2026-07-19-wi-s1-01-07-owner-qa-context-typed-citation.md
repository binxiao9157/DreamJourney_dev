# WI-S1-01-07 Owner QA Context 与 Typed Citation

日期：2026-07-19

## 结论

`WI-S1-01-07` 完成了限定的 G0 合同闭环：iOS 可以在默认关闭的
Owner QA 模式下调用既有 Context Shadow 与 Answer Citation 接口，严格解析
Confirmed Memory / Projection 的无正文引用证据，并把摘要映射到现有 Echo QA
evidence 结构。

状态：`INTERNAL_READY / G0_TYPED_CONTRACT_VERIFIED /
G1_QA_TEXT_EVIDENCE_SIMULATOR_VERIFIED / IOS_LOCAL_COMMITTED / G2_G3_OPEN`。

本轮没有修改公开 `/context/build`、公开 Echo UI、Archive/KBLite writer、数字人或
音色链路。生产用户无法通过此合同读取个人记忆正文。

## 实现

### 已有后端合同

后端已部署的以下 QA-only route 是本轮唯一依赖：

- `POST /v2/vaults/{vaultId}/context-shadow/build`
- `POST /v2/vaults/{vaultId}/answer-citation-receipts`

它们要求已认证 Owner 和 `X-DreamJourney-QA-Owner-Truth: 1`，默认关闭，且返回
MemoryVersion、Source、rank、过滤原因、hash、authority epoch 与 checkpoint；不返回
query、answer 或记忆正文。

### iOS

- 新增 Context Shadow、Citation、ranking、authority 与 receipt 的强类型解析。
- QA gate 为 `DJEnableOwnerTruthContextCitationQA`，release build 一律关闭。
- `DreamJourneyBackendClient` 只用 owner-authenticated `userRequired` 请求调用隐藏端点。
- 解析器拒绝 raw content key、legacy Context read、跨 Vault 引用、selected/filtered
重叠、hash/authority 不一致及无效 citation。
- 整数字段支持真实 `JSONSerialization` 的 `NSNumber`，但拒绝 Boolean、小数、溢出值。
- 新增无正文 `OwnerTruthContextCitationTraceSummary`，可映射到既有 Echo QA evidence，
不改变公开 Echo 上下文来源。
- G1 增加 `OwnerTruthContextCitationQAEvidenceReadout`：只导出 Context / policy /
  authority 摘要、计数和单向哈希后的 MemoryVersion 引用；不导出 query、answer、
  memory value、原始引用或 projection checkpoint。
- Echo QA 面板只在 Debug/UIQA 且带 `DJEnableOwnerTruthContextCitationQA` 时出现该摘要；
  面板固定在话筒上方的可滚动容器中，Owner Truth 摘要优先显示，避免遮挡公开 Echo
  的话筒和底部导航。

## 验证

通过：

```bash
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-context-citation-check.py
Scripts/QA/product-v4/run-ios-owner-truth-context-citation-text-evidence-gate.sh
Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh
git diff --check
```

验证覆盖：

- 合法 Projection citation 与 raw content / cross-vault 拒绝。
- Context hash、query hash、answer hash、authority epoch、checkpoint 的精确绑定。
- JSON 往返后的整数解析，以及 Boolean / 小数拒绝。
- 后端默认隐藏、Owner ownership、重建投影与 replay 边界。
- 无正文 QA readout 的哈希化、导出和首屏可读性；导出 JSON 不包含原始 MemoryVersion。
- SwiftPM 29 项测试、`generic/platform=iOS build-for-testing` 和模拟器 UIQA smoke 通过。

模拟器证据：

```text
tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260719-233143/
```

其中 `01-echo-qa-evidence-bundle-export-smoke.png` 显示 QA 容器未遮挡话筒或底部导航；
`echo-qa-evidence-bundle.json` 包含 `owner-truth-context-citation-readout-v1` 和哈希引用，
不包含原始 MemoryVersion。

后端本轮没有代码变化；服务器上的既有 QA contract 不需要重新部署。

## 剩余 Gate

- `G1`：已完成 QA-only 文本 readout、导出和模拟器交互验证；公开 UI 保持不变。
- `G2`：Context V4 的性能、容量、线上 shadow 观察与 citation resolve 压测尚未执行。
- `G3`：模型回答质量与 Retrieval ranking 仍未验收。
- `G4`：不适用于本轮内部 QA 合同；未来公开/隐私评审另行处理。

## 下一步

继续同一 Work Item 的 G2：在已部署的 QA-only Context Shadow 合同上完成受控线上
shadow 观察、性能/容量和 citation resolve 证据，仍不改变公开 Echo 或把 legacy/private
JSON 当作 Authority。
