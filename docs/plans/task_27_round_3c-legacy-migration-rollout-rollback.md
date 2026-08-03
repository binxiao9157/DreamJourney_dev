# Round 3C Legacy 迁移、Rollout、Rollback 与退役方案

## Problem Definition

Round 3A/3B 已冻结目标模块边界、核心 Authority、`/v2`、AuthZ、Job/Outbox、对象存储和 Provider 合同，但当前 iOS 与后端仍运行在单 target、旧 route、JSONB authority、KBLite/Archive 事实混用、共享 token、启动时建表和同步 Provider 调用之上。需要设计一条从当前提交基线到 V4 目标的可逆迁移路径，避免大爆炸重写、跨版本客户端失配、双写分叉、不可回滚 schema、凭据泄漏和“已切流但无法证明一致”的假完成。

## Proposed Solution

在 V4 Product Spec 增加完整迁移章，并同步证据矩阵、决策登记册和静态门禁。采用 `stabilize → expand → backfill → shadow → limited dual-write → cutover → contract → retire` 的 Strangler 顺序：

1. 冻结当前 iOS/后端/DB 基线、兼容客户端范围、authority owner 和外部 Provider 配置快照，先修 fail-open、跨 owner upsert、单连接 DB、隐式建表和静态 credential blocker。
2. 使用版本化 migration 只做向前兼容 expand；新增 typed table/FK/index/outbox/job/session，不立即删除 JSONB 或旧列。
3. 为 Source、Candidate、DecisionReceipt、MemoryVersion、Identity/Session、Conversation/Citation、TimeLetter/Inbox、Provider receipt 定义 deterministic backfill、checkpoint、checksum、重跑和 quarantine 规则。
4. 旧 route 保持兼容 facade；新 `/v2` 先 shadow read/command validation，不产生第二 authority。比较 old/new canonical projection，记录 mismatch、owner、authorityEpoch 和 correlation ID。
5. 仅在能够证明同事务/同 commandId 幂等时启用有限 dual-write；不满足时采用单 Authority 写入 + 派生投影/outbox，禁止业务层裸双写。
6. 按 Owner 文字核心、档案导入、Echo、账号、TimeLetter/Family/Care、Voice/DigitalHuman 分切片 canary；定义流量比例、客户端最低版本、capability/feature flag、read fallback 和自动暂停阈值。
7. 将 rollback 分为 UI exposure、client routing、API traffic、worker/provider、schema/data 五类，逐类定义触发条件、动作、最大恢复时间和不可逆边界。已确认 MemoryVersion、发送出的 Inbox、外部 Provider 训练/删除等事实不得通过数据库回滚抹除，只能补偿或对账。
8. 只有在兼容窗口结束、旧客户端低于阈值、backfill/mismatch/dead-letter 清零或豁免、备份恢复演练通过、数据权利闭环和 owner 证明齐全后，才 contract schema、关闭 facade、轮换旧 credential 并退役 legacy 代码/定时器/feature flag。
9. 输出逐阶段 migration wave 表、cutover/rollback runbook、数据不变量、观测指标、证据包、责任人/批准门和退役清单；把所有未确认产品决策映射到 DR 编号而不是自行拍板。

## Acceptance Criteria

- Product Spec 明确当前基线、迁移原则、至少 8 个迁移 wave 及每个 wave 的前置条件、变更、验证、cutover、rollback 和退出证据。
- 核心数据对象具有 deterministic backfill、checkpoint、checksum、quarantine 和重跑规则；跨 vault、版本链、terminal decision、active version 等不变量在迁移期间持续成立。
- 明确禁止无事务保证的业务双写，并给出 single authority + projection/outbox 的默认模式。
- `/v1`/旧 route 与 `/v2`、旧 iOS 与新 iOS 的兼容窗口、版本门、shadow compare、canary 和 retirement 条件可执行。
- Identity/AuthZ 从 shared/anonymous shadow 到 production enforce 的切换顺序 fail-closed，包含 token rotation、session migration 和紧急撤回。
- Job/Outbox/Object/Provider 的迁移不会重复业务副作用，未知 Provider 结果进入 reconcile/dead-letter。
- 每类 rollback 都有触发阈值、动作、验证和不可逆数据处理；不得用 rollback 删除已确认事实或伪造 Provider 删除完成。
- 旧 schema、旧 route、旧 timer、旧凭据、旧 feature flag 和 legacy store 的退役均有证据门，不能只以“代码未再调用”判定。
- 增加 migration/rollback 静态检查脚本，验证 wave、backfill、cutover、rollback、retirement 和验收场景完整性。
- 更新当前实现证据矩阵，清楚区分 `DESIGNED`、`NOT_IMPLEMENTED`、`EXTERNAL_ACCEPTANCE`，不把迁移方案误标为代码完成。

## Verification Plan

- 静态门禁验证迁移章包含 wave、状态、owner、authorityEpoch、checkpoint、checksum、quarantine、shadow、canary、rollback、retirement 和不可逆边界。
- 将每个高风险当前实现项映射到一个 migration wave 和一个 rollback/补偿动作，检查无遗漏。
- 用表格演练至少 15 个故障场景：backfill 中断、双写分叉、旧客户端写入、跨 owner 冲突、token 轮换失败、worker 崩溃、Provider 超时未知、TimeLetter 重复投递、对象孤儿、数智人 lease 漂移、数据删除部分完成、schema contract 失败等。
- 运行全部 Product V4 文档门禁和 `git diff --check`。
- 本轮不执行生产 migration；真实 Postgres backup/restore、canary、Provider 和真机属于后续路线图验收任务。

## Risks

- 当前 schema/数据量和线上分布没有完整快照，时间与批次大小只能先定义合同，不能伪造容量结论。
- 旧客户端长期存活会延迟 schema contract 和 route retirement。
- JSONB 历史数据可能无法无损映射，必须 quarantine 并保留人工裁决通道。
- 外部 Provider 不支持幂等查询或删除时，只能采用补偿与人工对账，不能承诺自动 rollback。
- 迁移章过度细化为具体 SQL 会在实现前锁死方案；本轮固定不变量和执行门，SQL 由对应实现任务评审。

## Assumptions

- 继续采用 UIKit/Stitch UI、FastAPI 模块化单体、Postgres、同镜像 worker 和私有对象存储的目标边界。
- 现有 PRD、V3 蓝图和分析文档可更新，但最终 authority 是五份 V4 成果物。
- Owner 文字核心优先，Family/Care/TimeLetter 与 Voice/DigitalHuman 按独立 capability/feature gate 迁移。
- 不在本轮提交 iOS/后端生产代码、部署服务、修改真实数据或执行真机测试。
