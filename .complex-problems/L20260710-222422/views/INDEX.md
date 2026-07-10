# Complex Problem Ledger

Ledger: L20260710-222422
Schema: v6
Root: P000 - P0 全路由 Ownership 审计与 Principal 绑定
Status: done
Updated: 2026-07-10T14:53:13+00:00

## Problem Tree
- [done] P000: P0 全路由 Ownership 审计与 Principal 绑定
  - [done] P001: 全路由注册表与覆盖测试
  - [done] P002: Principal 绑定与 iOS 调度收敛
    - [done] P004: 后端 Principal 强绑定
    - [done] P005: iOS 时间信件调度职责收敛
  - [done] P003: Audit Gate、提交与部署证据
    - [done] P006: Ownership Audit Gate 固化
    - [done] P007: Ownership 版本提交部署与线上证据

## Active

## Blocked

## Done
- [x] P000: P0 全路由 Ownership 审计与 Principal 绑定
- [x] P001: 全路由注册表与覆盖测试
- [x] P002: Principal 绑定与 iOS 调度收敛
- [x] P003: Audit Gate、提交与部署证据
- [x] P004: 后端 Principal 强绑定
- [x] P005: iOS 时间信件调度职责收敛
- [x] P006: Ownership Audit Gate 固化
- [x] P007: Ownership 版本提交部署与线上证据

## Tickets
- [done] T000: 完成全路由 ownership 审计与 principal 绑定 -> P000 (split)
- [done] T001: 实现全路由 ownership registry -> P001 (one_go)
- [done] T002: 将路由 ownership 注册表接入 principal 强绑定 -> P002 (split)
- [done] T003: 接入注册表并强制 principal-bound 决策 -> P004 (one_go)
- [done] T004: 移除 App 生产路径的全局时间信件调度 -> P005 (one_go)
- [done] T005: 固化 Ownership Audit Gate 并生成部署证据 -> P003 (split)
- [done] T006: 新增 Ownership 静态与部署 Smoke Gate -> P006 (one_go)
- [done] T007: 提交推送、部署 API 并运行线上 Ownership Gate -> P007 (one_go)

## Latest Checks
- [success] C000: P001 结果 R000 满足 P001 的全部成功标准。注册表覆盖当前全部 54 条业务路由，并通过实际路径匹配、owner 提取、高风险分类和无 PII 摘要测试。
- [success] C001: P004 R001 满足 P004 的全部成功标准。授权行为已由路由注册表驱动，且全量后端测试证明 owner、system、delegated 三类边界没有相互覆盖。
- [success] C002: P005 R002 满足 P005 的全部成功标准。公开 App 不再要求 system-only 调度能力，且现有 mailbox 提醒体验通过模拟器 smoke。
- [success] C003: P002 R003 及其子结果 R001、R002 完整满足 P002：安全边界已生效，合法 owner/delegated/system 兼容，客户端不再调用全局调度。
- [success] C004: P006 R004 满足 P006 的全部标准。静态、HTTP 与 release gate 可重复运行，报告脱敏，默认回归不依赖部署环境。
- [success] C005: P007 R005 满足 P007 的全部成功标准。远端版本、服务器版本、Postgres 运行态和脱敏 smoke 证据一致。
- [success] C006: P003 R006 与子结果 R004、R005 完整满足 P003，QA gate 和线上交付证据均已闭环。
- [success] C007: P000 R007 及全部子问题结果满足根问题全部成功标准。实现、QA、提交、部署和线上证据一致，且没有越过 global enforce 的产品边界。
