# WI-S1-01-04 Candidate Review / DecisionReceipt 证据

日期：2026-07-19

## 本次完成边界

后端已完成 Owner Truth 的内部审核闭环：

```text
pending Candidate -> accept | correct | reject -> immutable DecisionReceipt
```

实现是默认关闭的 QA-only 后端合同。它不创建 `MemoryVersion`、不更新 KBLite、
不发布内容，也没有公开 iOS 入口。

## 后端合同与安全边界

仅在服务端开启 `OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=true` 且请求同时带
`X-DreamJourney-QA-Owner-Truth: 1` 时，具备 user session 的 Owner 可访问：

```text
GET  /v2/vaults/{vaultId}/candidates
POST /v2/vaults/{vaultId}/candidates/{candidateId}/decisions
```

命令固定为 `commandId`、`expectedCandidateVersion`、`action`、可选
`correctedValue`、`reasonCode`。`correct` 必须带更正值；返回不回显原始更正文本。

后端会在同一 Unit of Work 内校验 vault/candidate owner、Source 是否仍有效、epoch 与
乐观锁版本，并将 terminal Candidate 变更和唯一不可变 `DecisionReceipt` 一起持久化。
重复 command replay 原 receipt；跨 vault、stale version、已终态 Candidate 均 fail-closed。

## 已验证

- 后端实现与部署 commit：`44b06b0`。
- 本地后端完整 `scripts/verify_backend.sh` 通过：`668` 个单测、FastAPI smoke 和既有
  contract/credential 检查均通过。
- 线上 Postgres Owner Truth smoke 已通过：

  ```text
  candidateReviewConcurrentSingleWriter=true
  candidateReviewIdempotent=true
  correctedDecisionRequiresValue=true
  candidateCorrectionSeparate=true
  schemaHead=0014
  status=passed
  ```

- 线上 route-authentication Postgres smoke 已通过，新路由只接受 user session，拒绝
  anonymous/machine credential，路由登记总数为 `80`。
- `/ready` 的 database/schema/auth/incident 均为 ready。

## iOS 影响与后续依赖

原始 `WI-S1-01-04` 后端提交不提前实现公开 iOS Candidate Inbox，也不改变公开 UI。
后续 `WI-S1-03-04` 的 hidden QA 组合层已经提供了 Archive 内的 typed Inbox/review
use case，仍需显式 QA launch argument 才可见。

`WI-S1-01-05` 随后已完成并部署。因此当前聚合行为为：`accept`/`correct` 在同一
事务中同时返回不可变 `DecisionReceipt` 和已激活的 `MemoryVersion`；`reject` 保持
“不创建 memory”。这不是把 Candidate 审核公开化，也不允许客户端绕过 Owner Truth
合同写入事实。

本页记录的是 `WI-S1-01-04` 的原始审核合同；当前 iOS action-level UIQA 的补充证据
见 `2026-07-19-wi-s1-01-04-candidate-inbox-action-uiqa.md`，MemoryVersion 激活的
事务边界见 `2026-07-19-wi-s1-01-05-memory-activation.md`。

## Gate 状态

`WI-S1-01-04` 达到内部 `G0/G2`：数据合同、幂等、跨 vault 防护、terminal CAS 和真实
Postgres 并发单写均有证据。隐藏 iOS action-level UIQA 已验证一条 `accept` 命令可消费
回执、激活 MemoryVersion 并从 pending Inbox 移除。`G1/G4` 仍开放，公开审核入口与
发布策略均未启用。

## 2026-07-22 正式确认权限审计补充

后端 `b94e541`、`70fee28`、`a954ac9` 为默认关闭的正式确认路径补充了最小化授权证据：

- 根确认命令记录 release-policy / account-generation / decision 的哈希化证明，不保存
  bearer token、原始 session 或原始 decision ID。
- 每个 terminal `DecisionReceipt` 与根命令、派生子命令哈希、准入 Source 版本建立不可变
  关联；QA 根命令不能被正式确认请求重放。
- `0036` 已在线上 Postgres 应用并验证，`/ready` 的 database/schema/auth/incident 均为
  `ready`。首次部署发现 Postgres 63 字符对象名截断冲突；两次失败尝试均确认没有留下
  schema 半结构后才清除失败运行记录，最终迁移成功。
- 本地完整 `scripts/verify_backend.sh` 通过（`1065` tests）。正式 disposable Postgres
  route smoke 已随代码部署，但服务器尚未配置独立
  `OWNER_TRUTH_FORMAL_SMOKE_ADMIN_DATABASE_URL`，因此未执行；不会回退使用业务
  `DATABASE_URL`。

该补充不开放产品入口、不改变 iOS UI，也不将 `G1/G4` 或独立正式烟测标记为完成。

## 2026-07-22 原子性与并发证据补充

对正式确认路径进行了范围受限的权限/回执审计，未发现可利用的 QA 重放、跨 Owner、
authority epoch、Source/version 或错误完成声明缺口。审计后补齐两项此前缺少的隔离
Postgres 验证，后端提交为 `d5c5977`：

- 两个带不同 fresh policy decision 的正式请求并发使用同一个 `commandId` 时，只能产生
  一组 root command、DecisionReceipt 和 receipt link，另一请求必须幂等返回。
- 两条 Candidate 的批量确认中，若数据库在第二条 receipt link 处注入失败，root command、
  两个 terminal Candidate receipt、已写入的 link 和 Candidate decision 都必须在同一 UoW
  回滚，两个 Candidate 保持 `pending`。

`scripts/verify_backend.sh` 已通过（`1065` tests、FastAPI smoke、合同 gate、编译与
`git diff --check`）。`d5c5977` 已推送、部署，线上 `/ready` 的
database/schema/auth/incident 均为 `ready`。隔离正式路由 smoke 仍刻意要求独立
`OWNER_TRUTH_FORMAL_SMOKE_ADMIN_DATABASE_URL`；当前服务器没有该专用连接，因此新增
并发/回滚断言尚未对真实 disposable Postgres 执行，不得据此提升 `G2` 或 Registry 状态。

## 2026-07-22 正式确认 feature 约束补充

审计发现一个仅在未来内部复用时可能出现的边界缺口：正式确认服务此前只要求
`authorization_capture.feature` 非空，因此其他 feature 的正式 capture 理论上可被错误传入。
现有 HTTP 正式路由始终固定传入 `ownerTruthCandidateReview`，未发现已知外部绕过；但该
服务不应依赖调用方约定。

后端 `0ab1e73` 已以双层约束修复：

- 服务层在进入 Unit of Work 前拒绝任何非 `ownerTruthCandidateReview` 的正式 capture，
  因此不会写 root、receipt、link 或 Candidate terminal decision。
- 新增向前兼容的 `0037` migration：保留 `{}` 作为 legacy QA-only 证据形态，对所有
  非空证据要求 feature 精确为 `ownerTruthCandidateReview`；数据库约束和 insert trigger
  均执行同一规则。
- 正式 disposable Postgres smoke 增加“结构完整但 feature 错误”的直接插入负向断言，
  供专用临时数据库配置后执行。

验证结果：本地 `scripts/verify_backend.sh` 通过（`1067` tests、FastAPI smoke、所有现有
contract gate、编译与 `git diff --check`）。`0ab1e73` 已推送并部署；服务器 dry-run、apply
和 verify 均显示 schema head 为 `0037`，`/ready` 全组件为 `ready`，新约束为 validated，
线上已有非空证据中非目标 feature 计数为 `0`。

这仍不是 disposable Postgres 正式路由 smoke 的替代，也不提升 `G2` 或 Registry 状态；它只
收紧了已部署正式确认路径的 authority evidence 边界。
