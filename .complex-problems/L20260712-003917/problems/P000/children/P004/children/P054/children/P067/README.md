# Round 4D3：Composite Migration Drills 工作项

## Problem

Product Spec已有W/I/P/Q/O/V/C波次和多个专项检查，但尚需把跨平面的inventory、restore、cohort、go/no-go、rollback、reconcile、contract/revoke和retirement收敛为唯一组合门，避免每个团队各自宣布迁移完成。

## Success Criteria

- 为`WP-MIG-01`建立覆盖C00–C11的原子工作项，并引用而不复制W/I/P/Q/O/V既有门。
- 明确唯一migration controller/decision record/evidence manifest，不创建第二business Authority或schema runner。
- 覆盖backup/isolated restore/replay、old client/route/timer/store/credential/provider in-flight、cohort、MRT和retirement manifest。
- 对MemoryVersion、Inbox/APNs、Publication、Voice/DH、object/provider delete等不可逆事实使用compensation/reconcile，不做时间倒流式rollback。
- 当前没有生产分布、观察窗或approver证据时保持`PLANNED/EXTERNAL_BLOCKED`。
