# Complex Problem Ledger

Ledger: L20260711-205750
Schema: v6
Root: P000 - Task 26：P0 Knowledge Operation Receipt 保留与最小化
Status: done
Updated: 2026-07-11T14:43:26+00:00

## Problem Tree
- [done] P000: Task 26：P0 Knowledge Operation Receipt 保留与最小化
  - [done] P001: 子问题：Compact Receipt 与安全重放合同
    - [done] P004: 收敛 Compact Receipt 标记与最小 envelope
  - [done] P002: 子问题：Postgres Receipt Dry-run/Apply 维护
    - [done] P005: Receipt 历史转换与隐私维护兼容合同
    - [done] P006: Postgres Receipt 用户级维护与 CLI
    - [done] P007: Receipt 维护组合回归与运维边界
      - [done] P008: Receipt Maintenance 脏 Compact 与扫描完整性修复
  - [done] P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口
    - [done] P009: Receipt 最小化跨仓 Gate 与非真机构建
    - [done] P010: 双仓提交部署与线上 Postgres Receipt 验收
      - [done] P011: Task 26 双仓提交与远端基线确认
      - [done] P012: 后端部署与真实 Postgres Receipt 验收
        - [done] P013: Reader-first 后端部署与健康验证
        - [done] P014: 真实 Postgres Receipt Dry-run、Apply 与幂等验收
          - [done] P015: 线上 Receipt Baseline 与 Dry-run 硬门
          - [done] P016: 线上 Receipt Apply、幂等与关联 Smoke

## Active

## Blocked

## Done
- [x] P000: Task 26：P0 Knowledge Operation Receipt 保留与最小化
- [x] P001: 子问题：Compact Receipt 与安全重放合同
- [x] P002: 子问题：Postgres Receipt Dry-run/Apply 维护
- [x] P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口
- [x] P004: 收敛 Compact Receipt 标记与最小 envelope
- [x] P005: Receipt 历史转换与隐私维护兼容合同
- [x] P006: Postgres Receipt 用户级维护与 CLI
- [x] P007: Receipt 维护组合回归与运维边界
- [x] P008: Receipt Maintenance 脏 Compact 与扫描完整性修复
- [x] P009: Receipt 最小化跨仓 Gate 与非真机构建
- [x] P010: 双仓提交部署与线上 Postgres Receipt 验收
- [x] P011: Task 26 双仓提交与远端基线确认
- [x] P012: 后端部署与真实 Postgres Receipt 验收
- [x] P013: Reader-first 后端部署与健康验证
- [x] P014: 真实 Postgres Receipt Dry-run、Apply 与幂等验收
- [x] P015: 线上 Receipt Baseline 与 Dry-run 硬门
- [x] P016: 线上 Receipt Apply、幂等与关联 Smoke

## Tickets
- [done] T000: 实现可重建的知识操作收据压缩 -> P000 (split)
- [done] T001: 实现 Compact Receipt 双读与权威快照重放 -> P001 (one_go)
- [done] T002: 最小化 Compact Receipt 并统一重放标记 -> P004 (one_go)
- [done] T003: 实现 Receipt Dry-run/Apply 维护与现有维护兼容 -> P002 (split)
- [done] T004: 建立 Legacy Receipt 转换与 Compact Privacy 兼容层 -> P005 (one_go)
- [done] T005: 实现 Postgres Receipt 分用户维护与 Dry-run CLI -> P006 (one_go)
- [done] T006: 固化 Receipt Maintenance 组合 Smoke 与运维说明 -> P007 (one_go)
- [done] T007: Canonical Compare 与有界 Keyset 扫描 -> P008 (one_go)
- [done] T008: Receipt 最小化跨仓 Gate、构建与部署验收 -> P003 (split)
- [done] T009: 接入 Receipt 跨仓 Release Gate 并完成非真机构建 -> P009 (one_go)
- [done] T010: 提交部署并执行真实 Postgres Receipt 验收 -> P010 (split)
- [done] T011: 审计并提交 Task 26 双仓改动 -> P011 (one_go)
- [done] T012: 部署 Reader-first 后端并安全最小化线上 Receipt -> P012 (split)
- [done] T013: 部署 Compact Receipt Reader 并验证服务基线 -> P013 (one_go)
- [done] T014: 以聚合指纹守护真实 Postgres Receipt 最小化 -> P014 (split)
- [done] T015: 采集脱敏聚合并审计线上 Dry-run -> P015 (one_go)
- [done] T016: 小批 Apply、二次幂等与线上关联回归 -> P016 (one_go)

## Latest Checks
- [success] C008: P009 P009 全部成功标准已满足。跨仓合同、release 接入、状态证据和两类非真机构建均有可重复命令与通过报告。
- [success] C009: P011 P011 已完成。两仓提交边界清楚、敏感信息与临时产物未纳入、远端分支与本地提交一致。
- [success] C010: P013 P013 已成功。线上运行目标 reader 提交，服务与既有 knowledge 主链路正常，且未提前执行 receipt apply。
- [success] C011: P015 P015 验收通过，可以作为后续 apply 的硬门证据，但本轮按用户要求在当前小任务完成后暂停，不执行 apply。
- [success] C012: P016 P016 验收通过。历史 receipt 已完成最小化，幂等、身份保持、新 writer 和相邻知识维护合同均有线上 Postgres 证据。
- [success] C013: P014 P014 成功标准全部满足，线上 apply 由无失败 dry-run 硬门保护，并已证明身份保持和重复执行幂等。
- [success] C014: P012 P012 成功标准全部满足，部署顺序、真实 SQL 行为、幂等和相邻合同均有生产证据。
- [success] C015: P010 P010 的代码提交、部署、dry-run-first apply、幂等与关联 smoke 标准均已满足。
- [success] C016: P003 P003 全部成功标准满足，开发期 gate 与生产维护流程均已形成可重复证据。
- [success] C017: P000 Task 26 成功标准全部满足。Compact receipt 不再持久化 graph、实体正文或原始 mutation upserts；安全重放、冲突、治理、删除和 change-feed 屏障保持兼容，线上历史数据已完成幂等压缩。
