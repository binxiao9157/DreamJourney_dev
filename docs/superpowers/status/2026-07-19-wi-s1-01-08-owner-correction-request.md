# WI-S1-01-08 Owner 回答纠正候选

## 本轮范围

为已验证的 Owner Truth 回答引用增加一个默认关闭的 iOS 客户端合同。Owner 可以在
后续 QA 入口中提交“该回答需要纠正”的候选请求；请求只会创建待审核 Candidate，不能
直接修改 Archive、KBLite、MemoryVersion 或公开 Echo 上下文。

## 已实现

- `OwnerTruthCorrectionRequestCommand` 只能从同一份已验证的
  `OwnerTruthAnswerCitationReceipt` 取得 citation、MemoryVersion 和 Vault。
- `OwnerTruthCorrectionRequestReceipt` 只解析服务端实际返回的引用绑定、纠正文哈希和
  长度；不保存回答、查询、记忆正文、纠正文或服务端不存在的命令/原因哈希。
- `OwnerTruthCorrectionRequestUseCase` 具备 AccountLease request/commit fence、旧回调
  generation fence 和失败闭合状态。
- iOS 调用已部署的
  `POST /v2/vaults/{vaultId}/memories/{memoryId}/corrections`，使用用户鉴权与
  `X-DreamJourney-QA-Owner-Truth: 1`。
- 纠正写操作使用独立启动参数
  `DJEnableOwnerTruthCorrectionRequestQA`；即使 Context/Citation QA 已开启，未显式开启
  本参数也不能创建 Candidate。
- 静态 gate 断言该类型尚未进入 `Sources/Modules`，因此默认公开 Echo、档案、KBLite
  和现有编辑入口均不变。

## 验证证据

| 验证 | 结果 |
| --- | --- |
| `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-answer-correction-check.py` | 通过 |
| `swift test --package-path . --scratch-path .build/product-v4-owner-truth-answer-correction` | 38 项通过，含 33 项 Owner Truth 合同测试 |
| `bash Scripts/QA/product-v4/run-ios-owner-truth-answer-correction-gate.sh` | 通过；含 generic iPhoneOS `build-for-testing` |
| `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_owner_truth_correction_request tests.test_owner_truth_candidate_review_api -v` | 11 项通过 |
| `git diff --check` | 通过 |

本轮没有修改后端仓库。`/corrections` 路由与 pending Candidate 服务已在后端
`main@162afb0` 中存在并已部署，因此不触发重新部署；本地回归只确认该既有合同仍满足
当前 iOS 解析边界。

## Gate 状态

- **G0**：完成。iOS  typed contract、独立 QA gate、客户端鉴权/Vault 绑定与后端本地回归
  已验证。
- **G1**：未开始。下一小闭环是把该 use case 接入既有 QA-only Candidate Inbox 流程，
  并验证由 Answer/Citation 创建的 pending Candidate 可被查看和审核。
- **G2**：既有路由已部署；本轮未修改后端，未重复执行线上 Postgres 写入 smoke。
- **G4**：公开纠错入口、审核体验和 cohort 策略仍等待产品确认，默认保持关闭。

## 不能宣称完成的内容

- 尚未把纠正入口公开给普通用户。
- 尚未执行真实生产账号的在线写入 smoke。
- Candidate 接受后生成 superseding MemoryVersion 的后端能力已有回归覆盖，但本轮没有
  新增公开 UI 或重新部署该服务。
