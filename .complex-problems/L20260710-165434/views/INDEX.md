# Complex Problem Ledger

Ledger: L20260710-165434
Schema: v6
Root: P000 - P0 Auth Session and Ownership Shadow Mode
Status: done
Updated: 2026-07-10T09:27:08+00:00

## Problem Tree
- [done] P000: P0 Auth Session and Ownership Shadow Mode
  - [done] P001: 后端 opaque auth session 合同
  - [done] P002: Principal 解析与 ownership shadow
  - [done] P003: iOS Keychain 消费与非真机 gate

## Active

## Blocked

## Done
- [x] P000: P0 Auth Session and Ownership Shadow Mode
- [x] P001: 后端 opaque auth session 合同
- [x] P002: Principal 解析与 ownership shadow
- [x] P003: iOS Keychain 消费与非真机 gate

## Tickets
- [done] T000: 实现用户会话与 ownership shadow 小闭环 -> P000 (split)
- [done] T001: 实现后端 opaque auth session 合同 -> P001 (one_go)
- [done] T002: 实现 principal 解析与 ownership shadow -> P002 (one_go)
- [done] T003: 接入 iOS Keychain auth session 与非真机 gate -> P003 (one_go)

## Latest Checks
- [success] C000: P001 opaque 会话签发、轮换、撤销和安全持久化合同已完成
- [success] C001: P002 principal 双轨解析和 ownership shadow 诊断达到子问题目标
- [success] C002: P003 iOS Keychain session 消费、刷新和非真机 gate 已达到子问题目标
- [success] C003: P000 Auth Session 与 Ownership Shadow 的后端、iOS 和非真机验收闭环完成
