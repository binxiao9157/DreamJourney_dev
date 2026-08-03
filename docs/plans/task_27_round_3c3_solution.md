# Round 3C3 Job、对象存储与 Provider 副作用迁移方案

## Problem Definition

当前 TimeLetter 依赖宿主机 timer 且 delivered/mailbox 非原子，Echo/Voice/DH/provider 多为同步或本地状态，Compose 无 worker/outbox；媒体 upload intent 为 mock，对象/scan/delete receipt 不存在；Provider timeout/credential/callback/delete 状态不统一。若直接启用新 worker、对象存储或 Provider adapter，可能出现旧/新 timer 双跑、重复投递/训练/收费、对象孤儿、删除假完成和静态 credential 泄漏。

## Proposed Solution

将 Round 3B 第 26 节合同迁移为三条独立轨道：

1. **Job/Outbox/Timer**：先让旧业务 command 同事务写 outbox，再以 shadow consumer 验证 dedupe/lease/reconcile；按 job type 切 worker owner，先停旧 timer 后启新 active consumer，保留 one-active-scheduler lease 与 heartbeat。
2. **Object Storage/Media**：引入 private object namespace、signed intent/commit/HEAD/checksum/scan；按 metadata → copy/upload → verify → reference cutover 迁现有媒体，未验证/丢失/本地-only 只保留 Source metadata；orphan/delete reconciler 产生 receipt。
3. **Provider Effect/Credential**：每类 Provider 使用稳定 request ID、typed receipt、query/callback binding、unknown-result reconcile 和 deletion lifecycle；先 rotate/move secret server-side，再 shadow/dry-run/canary；不支持幂等/query/delete 的高风险操作默认 manual review。

三条轨道使用同一 `jobId/outboxEventId/resourceRef/purpose/authorityEpoch/workAuthorization/providerRequestId` 关联，但不能共享一个泛化“成功”状态。业务完成、Provider accepted、Provider terminal、用户可用和物理删除分开。

## Acceptance Criteria

- 明确当前 timer/同步调用/mock storage/Provider credential 与状态缺口。
- Job/Outbox 迁移包含 legacy timer inventory、shadow consumer、one-active scheduler、cutover、rollback和 retirement。
- TimeLetter/Inbox、Echo delayed reply、notification 等业务副作用具有事务 outbox 与幂等 consumer 路径。
- Object migration 覆盖 intent/upload/commit/checksum/scan/reference cutover/orphan/delete/backup lifecycle。
- 现有 local/mock/base64 媒体不会被静默标成 verified cloud object。
- 10 类 Provider 均有 credential、request、query/callback、unknown、delete、canary和exit迁移策略。
- 旧/new worker/provider 不能同时产生同一业务 effect；unknown outcome 不盲重试。
- 至少 15 个跨 worker/object/provider 故障场景。
- 增加 Product Spec、Evidence Matrix 与静态门禁。

## Verification Plan

- 分别对 Job/Outbox、Object、Provider 建目录与门禁，再由父结果检查关联 ID/状态一致。
- 独立 reviewer 攻击 timer 双跑、lease crash、provider timeout unknown、callback replay、object orphan、delete partial和credential rotation。
- 运行全部 Product V4 门禁与 `git diff --check`。
- 本轮不接真实对象存储/Provider、不部署 worker；真实 sandbox/Postgres/Provider deletion 是路线图外部验收。

## Risks

- 某些 Provider 不支持 query/idempotency/delete，无法实现自动 rollback，只能对账和人工处理。
- 当前线上 timer/service 状态未重新 SSH 验证，不能假定旧 scheduler 已停止。
- 媒体原始文件可能仅在设备或已丢失，迁移率必须如实报告。
- Provider asset/license 可能无法迁移，adapter 不能消除商业锁定。

## Assumptions

- Round 3B Job/Object/Provider 合同和 Round 3C1 authorityEpoch 是目标输入。
- API 与 worker 使用同镜像/模块化单体，但部署进程与最小权限分离。
- Optional Voice/DH/Family/TimeLetter 失败不影响 Owner 文字核心。
