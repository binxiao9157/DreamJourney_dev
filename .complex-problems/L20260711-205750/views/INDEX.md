# Complex Problem Ledger

Ledger: L20260711-205750
Schema: v6
Root: P000 - Task 26：P0 Knowledge Operation Receipt 保留与最小化
Status: doing
Updated: 2026-07-11T14:13:01+00:00

## Problem Tree
- [todo] P000: Task 26：P0 Knowledge Operation Receipt 保留与最小化
  - [done] P001: 子问题：Compact Receipt 与安全重放合同
    - [done] P004: 收敛 Compact Receipt 标记与最小 envelope
  - [done] P002: 子问题：Postgres Receipt Dry-run/Apply 维护
    - [done] P005: Receipt 历史转换与隐私维护兼容合同
    - [done] P006: Postgres Receipt 用户级维护与 CLI
    - [done] P007: Receipt 维护组合回归与运维边界
      - [done] P008: Receipt Maintenance 脏 Compact 与扫描完整性修复
  - [todo] P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口
    - [done] P009: Receipt 最小化跨仓 Gate 与非真机构建
    - [todo] P010: 双仓提交部署与线上 Postgres Receipt 验收
      - [doing] P011: Task 26 双仓提交与远端基线确认
      - [todo] P012: 后端部署与真实 Postgres Receipt 验收

## Active
- [ ] P000: Task 26：P0 Knowledge Operation Receipt 保留与最小化 (todo)
- [ ] P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口 (todo)
- [ ] P010: 双仓提交部署与线上 Postgres Receipt 验收 (todo)
- [ ] P011: Task 26 双仓提交与远端基线确认 (doing)
- [ ] P012: 后端部署与真实 Postgres Receipt 验收 (todo)

## Blocked

## Done
- [x] P001: 子问题：Compact Receipt 与安全重放合同
- [x] P002: 子问题：Postgres Receipt Dry-run/Apply 维护
- [x] P004: 收敛 Compact Receipt 标记与最小 envelope
- [x] P005: Receipt 历史转换与隐私维护兼容合同
- [x] P006: Postgres Receipt 用户级维护与 CLI
- [x] P007: Receipt 维护组合回归与运维边界
- [x] P008: Receipt Maintenance 脏 Compact 与扫描完整性修复
- [x] P009: Receipt 最小化跨仓 Gate 与非真机构建

## Tickets
- [splitting] T000: 实现可重建的知识操作收据压缩 -> P000 (split)
- [done] T001: 实现 Compact Receipt 双读与权威快照重放 -> P001 (one_go)
- [done] T002: 最小化 Compact Receipt 并统一重放标记 -> P004 (one_go)
- [done] T003: 实现 Receipt Dry-run/Apply 维护与现有维护兼容 -> P002 (split)
- [done] T004: 建立 Legacy Receipt 转换与 Compact Privacy 兼容层 -> P005 (one_go)
- [done] T005: 实现 Postgres Receipt 分用户维护与 Dry-run CLI -> P006 (one_go)
- [done] T006: 固化 Receipt Maintenance 组合 Smoke 与运维说明 -> P007 (one_go)
- [done] T007: Canonical Compare 与有界 Keyset 扫描 -> P008 (one_go)
- [splitting] T008: Receipt 最小化跨仓 Gate、构建与部署验收 -> P003 (split)
- [done] T009: 接入 Receipt 跨仓 Release Gate 并完成非真机构建 -> P009 (one_go)
- [splitting] T010: 提交部署并执行真实 Postgres Receipt 验收 -> P010 (split)
- [executing] T011: 审计并提交 Task 26 双仓改动 -> P011 (one_go)

## Latest Checks
- [not_success] C000: P001 当前结果覆盖了核心读写与重放路径，测试证据充分，但尚不能判定成功。Compact replay 的标记语义在 change 重建与 snapshot fallback 两条路径上不一致，且 envelope 仍重复保存 receipt 表已有的身份字段，不满足“结果载荷最小化且语义可稳定消费”的完整标准。
- [success] C001: P004 修复结果满足跟进问题的全部标准：compact envelope 已去除重复身份字段，两条重放路径使用一致诊断语义，legacy/full 与历史 compact 双读保持兼容，且相关与全量回归均通过。
- [success] C002: P001 P001 的 compact receipt 与安全重放合同已完成。初次实现的标记与最小化缺口由 P004 修复；四类 operation 的幂等、冲突、重建和 iOS 兼容响应均有测试证据。现有 privacy maintenance 尚不识别 compact V2 envelope，但该问题已明确归入 P002，且本任务在 P002 完成前不会部署。
- [success] C003: P005 纯转换与 privacy compatibility 问题已解决，结果满足 P005 成功标准，并为后续 Postgres 维护提供了单一、安全、可测试的转换入口。
- [success] C004: P006 P006 的 Postgres 维护与 CLI 合同已完成。实现满足默认 dry-run、分用户锁与事务、失败隔离、幂等和无正文报告要求；真实 Postgres 执行证据明确留给部署阶段，不影响本地实现验收。
- [success] C005: P008 P008 的隐私与扫描阻断已解决。实现不再相信单一版本标记，空 operation ID 和多页用户均有明确测试，满足组合 smoke 的前置条件。
- [success] C006: P007 P007 已完成。组合 smoke、默认 dry-run 静态合同、后端全量回归和运维边界均有直接证据；P008 的阻断问题已关闭。
- [success] C007: P002 P002 全部子问题已关闭，维护路径满足默认只读、用户级锁/事务、失败隔离、幂等和隐私最小化要求，可进入跨仓与线上验收。
- [success] C008: P009 P009 全部成功标准已满足。跨仓合同、release 接入、状态证据和两类非真机构建均有可重复命令与通过报告。
