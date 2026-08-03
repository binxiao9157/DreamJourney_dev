# 用 C00–C11 十二个证据门编排唯一 Composite Migration

## Problem Definition

Product Spec已有W/I/P/Q/O/V各分面波次和C00–C11组合Runbook，静态检查覆盖较完整，但当前没有原子`WI-MIG-*`、真实DB backup/isolated restore/readiness、组合go/no-go执行、生产cohort或retirement manifest。现有checkout旧commit式回滚在Authority cutover后可能复活legacy writer，必须用phase fence重写语义。

## Proposed Solution

为`WP-MIG-01`建立与C00–C11一一对应的12项：

1. C00当前build/schema/config/writer/client/timer/store/object/provider/credential/in-flight inventory。
2. C01 UoW/migrator/readiness/backup/isolated restore/replay与实测MRT基础门。
3. C02 strong identity/account/AuthZ与cross-vault promotion。
4. C03 snapshot/store/quarantine确定性backfill。
5. C04 tail/outbox/object/provider无副作用shadow。
6. C05 read/command/copy parity shadow。
7. C06非权威canary、阈值批准和rollback-plane drill。
8. C07 pre-go授权→epoch/API CAS cutover→post-completion record两阶段门。
9. C08 projection/business worker/object/provider optional lane激活与独立rollback。
10. C09 Rights/delete/exit/restore/replay组合演练。
11. C10只生成retirement candidate与zero-use/drain证据，不删除实现。
12. C11独立批准后的contract/revoke/removal、final restore与post-monitor。

统一使用一个`MigrationGoNoGoRecord(scope=composite, phase=candidate|authorization|completion)`，不新建第二record表；每项只聚合/授权/封存既有W/I/P/Q/O/V证据，不实现业务writer或第二migration runner。

## Acceptance Criteria

- 12项/192字段完整且C00–C11连续，无循环依赖。
- C07区分pre-go authorization与post-cutover completion；执行者不依赖“C07已完成”才能执行C07。
- C10只批准candidate，实际删除/contract/revoke只在C11。
- restore证据链覆盖backup→isolated restore→migrate head→replay range→invariant→RPO/RTO/MRT，不以`.env`备份或`/health`替代。
- W08/epoch后rollback不checkout旧writer；不可逆MemoryVersion/Inbox/Provider/Delete/Public access只compensate/reconcile。
- 当前缺生产证据保持`PLANNED/NO-GO`，只有C00可立即开始。

## Verification Plan

- 对照Product Spec W/I/P/Q/O/V/C、34.3不可逆事实、Round3 migration评审和Evidence Matrix状态。
- 校准现有部署/QA/checker只能证明哪些内容，列出禁止推断。
- 检查12项/192字段、C编号、phase fence、C10/11、restore chain、no second runner和G2–G4。
- 运行全部Product V4 migration/provider/object/job checks和diff gate。

## Risks

- 文档体量大可能给出“已经可迁移”的错觉；每项必须写current state与真实evidence缺口。
- 组合门若复制分面阈值/logic会漂移；只引用evidence ID/hash和批准结果。
- contract/removal不可通过普通代码回滚恢复，必须独立批准并有新环境restore/old-binary证据。

## Assumptions

- 本轮只写路线，不执行backup、migration、部署或provider操作。
- 实际阈值、观察窗、RPO/RTO/MRT要由环境测量与approver批准，文档不虚构数字。
