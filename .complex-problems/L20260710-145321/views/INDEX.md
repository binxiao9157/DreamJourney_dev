# Complex Problem Ledger

Ledger: L20260710-145321
Schema: v6
Root: P000 - P0 Digital-human session lease and concurrency control
Status: done
Updated: 2026-07-10T07:20:25+00:00

## Problem Tree
- [done] P000: P0 Digital-human session lease and concurrency control
  - [done] P001: 后端数字人 Lease 持久化与并发仲裁
  - [done] P002: 完成 Session Lease API、iOS 消费与组合验收

## Active

## Blocked

## Done
- [x] P000: P0 Digital-human session lease and concurrency control
- [x] P001: 后端数字人 Lease 持久化与并发仲裁
- [x] P002: 完成 Session Lease API、iOS 消费与组合验收

## Tickets
- [done] T000: 建立数字人 Session Lease 与并发控制闭环 -> P000 (split)
- [done] T001: 实现内存与 Postgres Session Lease Store -> P001 (one_go)
- [done] T002: 交付 Session Lease v2 API 与 iOS 生命周期消费 -> P002 (one_go)

## Latest Checks
- [success] C000: P001 判定成功。R000 覆盖内存/Postgres 一致语义、数据库原子锁、安全元数据和全部要求的状态转换。
- [not_success] C001: P000 判定未完成。Store 层已关闭，但原问题还要求 API、iOS 生命周期消费和端到端非真机 gate。
- [success] C002: P002 非真机 Session Lease API、iOS 消费与组合验收已完整闭环
- [success] C003: P000 P0 Session Lease 与并发控制在非真机范围内完成
