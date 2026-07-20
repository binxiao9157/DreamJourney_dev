# WI-S1-01-03 M0-A 自然输入 iOS QA 客户端

## 本轮范围

本轮完成的是已部署私有访谈 `naturalInput` 后端合同的 iOS 受控消费端。它仅在
DEBUG/UI-QA 启动参数下可达，不增加公开 Echo、档案或个人页入口，也不改变现有全屏
Echo 的视觉结构。

后端合同保持为：

```text
POST /v2/vaults/{vault_id}/interview-sessions
POST /v2/vaults/{vault_id}/interview-sessions/{session_id}/messages
```

## 已实现边界

- 新增严格解码的自然输入回执、开始/追加命令、客户端协议和 use case。
- 每一次请求和异步回调均绑定当前 `AccountLease`；账号租约变化或旧回调会被丢弃。
- 追加命令受线程/会话版本栅栏保护，输入长度与后端上限一致（20,000 字符）。
- ViewState 只保留回执元数据，不保留用户输入正文；提交一个有效输入后，输入框立即清空。
- 运输层只在既有 QA Gate 明确开启时发送 Owner Truth QA header；Gate 关闭时 fail-closed。
- 新增 `DJRunOwnerTruthInterviewNaturalInputSmoke`，其 fake client 只验证本地合同和 UI
  渲染，不会访问生产后端。

该流程不会创建 Source、Candidate、DecisionReceipt、MemoryVersion、Projection、provider
请求、数字人 session，也不会写入 legacy Archive/KBLite。

## 验证证据

- `OwnerTruthContractsTests` 定向 XCTest 通过：回执最小化解析、开始/追加不保留正文、
  stale AccountLease 回调丢弃、QA Gate 关闭 fail-closed。
- `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-smoke.sh` 通过。
- UIQA 结果：`completed=true`、`sessionCreated=true`、`inputRecorded=true`、
  `messageSequence=1`、`transcriptCleared=true`。
- 截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-natural-input-smoke/20260720-233835/01-owner-truth-interview-natural-input.png`。

截图只显示会话状态、版本和回执元数据；提交文本为空，未被回显。

## Gate 结论

- G0：私有、最小化、租约绑定的 iOS 命令消费端已验证。
- G1：仅 QA 模拟器 UI 已验证；公开 Echo 未接入。
- G2：后端自然输入命令已部署并通过 Postgres smoke，见
  `2026-07-20-wi-s1-01-03-m0a-natural-input-backend-command.md`。
- G3：provider 生成仍独立且未启用。

## 后续边界

下一步必须先选择并记录 M0-A 的产品 surface Gate，才可以讨论把受控自然输入接入公开
Echo。未完成该 Gate 前，本实现继续保持 QA-only/default-off。
