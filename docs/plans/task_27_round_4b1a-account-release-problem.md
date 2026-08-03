# Round 4B1A：Account/Local Isolation 与 Release Scope

## Problem

iOS 当前已有 UserManager、BackendAuthSessionStore、多个局部 generation/store 和 feature flag/runtime config，但缺统一 AccountLease、全量 owner-scoped store envelope、legacy quarantine 与 server release fail-closed 路线。

## Success Criteria

- 基于当前 iOS 证据形成 `WP-S0-01`、`WP-S0-06` 的 atomic Work Items，16 字段完整。
- 路线覆盖 session/account generation、store inventory/envelope、legacy auto-claim quarantine、A/B/logout/delete/cold-start 和 stale callback。
- 路线覆盖 server release policy、flag TTL/offline deny、future/Beta default-off、公开 release smoke 与 alias retirement。
- 明确 fake/G0/G1 可先实施，强身份/session/G2 仍是 Exit Gate。
- 不要求 UIKit/Stitch UI 重写，不删除现有 QA-only 入口的可控能力。
