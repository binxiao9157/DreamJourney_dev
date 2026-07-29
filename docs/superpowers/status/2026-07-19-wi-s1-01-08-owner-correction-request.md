# WI-S1-01-08 Owner 回答纠正候选

## 本轮范围

为已验证的 Owner Truth 回答引用增加一个默认关闭的 iOS 客户端合同。请求只会创建待审核
Candidate；候选可在 QA-only Candidate Inbox 中被定位，但终态必须走专用 correction resolver，
不能直接修改 Archive、KBLite、MemoryVersion 或公开 Echo 上下文。

## 已实现

- `OwnerTruthCorrectionRequestCommand` 只能从同一份已验证的
  `OwnerTruthAnswerCitationReceipt` 取得 citation、MemoryVersion 和 Vault。
- `OwnerTruthCorrectionRequestReceipt` 解析服务端实际返回的引用绑定、纠正文哈希和长度，
  并仅从已验证请求命令继承 Vault 绑定；不保存回答、查询、记忆正文、纠正文或服务端
  不存在的命令/原因哈希。
- `OwnerTruthCorrectionRequestUseCase` 具备 AccountLease request/commit fence、旧回调
  generation fence 和失败闭合状态。
- iOS 调用已部署的
  `POST /v2/vaults/{vaultId}/memories/{memoryId}/corrections`，使用用户鉴权与
  `X-DreamJourney-QA-Owner-Truth: 1`。
- 纠正写操作使用独立启动参数
  `DJEnableOwnerTruthCorrectionRequestQA`；即使 Context/Citation QA 已开启，未显式开启
  本参数也不能创建 Candidate。
- `OwnerTruthCorrectionCandidateInboxHandoffUseCase` 只保存
  `correctionRequestId/candidateId`，提交成功后刷新既有 Candidate Inbox，并要求同一
  Vault 的 pending Candidate 实际出现后才进入 ready。它不再向外暴露 generic terminal review。
- `OwnerTruthCorrectionResolutionUseCase` 只能从已验证的 pending request receipt 取得
  Vault、Candidate、预期版本和 correction request ID；它调用已部署的
  `POST /v2/vaults/{vaultId}/correction-requests/{correctionRequestId}/resolve`。
- resolver 仅支持 `correct/reject`。`correct` 必须回传同一 Memory 的 successor
  MemoryVersion 与 outdated Answer event；`reject` 不得回传 successor metadata。两条路径都
  经 AccountLease request/commit fence、operation generation fence 和独立 QA gate 失败闭合。
- 静态 gate 断言该类型尚未进入 `Sources/Modules`，因此默认公开 Echo、档案、KBLite
  和现有编辑入口均不变。

## 验证证据

| 验证 | 结果 |
| --- | --- |
| `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-answer-correction-check.py` | 通过 |
| `swift test --package-path . --scratch-path .build/product-v4-owner-truth-answer-correction` | 41 项通过，含 36 项 Owner Truth 合同测试 |
| `bash Scripts/QA/product-v4/run-ios-owner-truth-answer-correction-gate.sh` | 通过；含 generic iPhoneOS `build-for-testing` |
| `bash Scripts/QA/product-v4/run-ios-owner-truth-candidate-client-gate.sh` | 通过；确认既有隐藏 Candidate Inbox 审核链未被桥接破坏 |
| `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_owner_truth_correction_request tests.test_owner_truth_candidate_review_api -v` | 11 项通过 |
| `git diff --check` | 通过 |

### 2026-07-29 resolver 增补

| 验证 | 结果 |
| --- | --- |
| `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-answer-correction-check.py` | 通过；检查专用 resolver、默认关闭、用户鉴权、value-free receipt 和公开模块隔离 |
| `xcodebuild test ... -only-testing:DreamJourneyTests/OwnerTruthContractsTests` | 模拟器 76 项通过，含 resolver 命令、回执、QA gate 和 AccountLease stale completion |
| `xcodebuild build-for-testing ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` | 通过 |
| `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_owner_truth_correction_request tests.test_owner_truth_candidate_review_api -v` | 11 项通过，确认已存在后端 resolver 仍保持同 Memory successor/reject 不写入语义 |

`swift test --package-path .` 仍因现有 SwiftPM target 未纳入 `AppLaunchPreparer`、
`AppLaunchPreparing` 和 `AppComposition` 而失败；Xcode 的实际 iOS target 编译和上述 76 项
目标测试均通过。该 SwiftPM manifest 缺口未在本轮修改，不能据此宣称整包 SwiftPM 回归通过。

本轮没有修改后端仓库。`/corrections` 路由与 pending Candidate 服务已在后端
`main@162afb0` 中存在并已部署，因此不触发重新部署；本地回归只确认该既有合同仍满足
当前 iOS 解析边界。

## Gate 状态

- **G0**：完成（本地合同）。iOS typed request/resolver contract、独立 QA gate、客户端
  鉴权/Vault 绑定与后端本地回归已验证。
- **G1**：完成（本地合同）。Answer/Citation 纠正回执中的 `candidateId` 已被刷新并定位到
  既有 QA-only Candidate Inbox；专用 resolver 负责终态，并拒绝把 correction Candidate 送入
  generic activation 路径。测试覆盖候选可见、候选缺失失败、QA gate 和账户租约闭合。该结论
  不等同于公开纠错体验完成。
- **G2**：完成（部署 Postgres）。2026-07-20 在后端 `main@162afb0` 的 API 容器内运行
  `scripts/run-backend-owner-truth-postgres-smoke.sh`，一次性数据库 smoke 以
  `schemaHead=0023`、`status=passed` 结束。它验证 Answer/Citation→Correction Request→
  pending Candidate→专用 resolver→同一 Memory 的 successor version→outdated Answer evidence→
  projection rebuild，且确认请求幂等、不可变、值无泄露、旧版本冲突失败闭合。
  运行时 `api/postgres` healthy，`OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=false`，未改变公开开关。
- **G4**：公开纠错入口、审核体验和 cohort 策略仍等待产品确认，默认保持关闭。

## 不能宣称完成的内容

- 尚未把纠正入口公开给普通用户。
- 尚未执行真实生产账号的在线纠正写入/收件箱读取 smoke。
- 真实生产账号的 dedicated correction resolver 在线 smoke 尚未运行；本轮没有新增公开 UI
  或重新部署该服务。

## 部署证据边界

本次服务器 smoke 创建并删除隔离 PostgreSQL 数据库，脚本不向应用业务库写入测试记录。
它证明的是已部署容器中的 schema/service/transaction 纠正链，不等同于打开 QA-only HTTP
路由或为普通用户开放纠错体验。后者仍受两个客户端 QA gate 与服务端
`OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED` 控制。
