# Complex Problem Ledger

Ledger: L20260711-005948
Schema: v6
Root: P000 - P1 知识删除 Tombstone 与三方合并
Status: done
Updated: 2026-07-10T17:58:09+00:00

## Problem Tree
- [done] P000: P1 知识删除 Tombstone 与三方合并
  - [done] P001: 后端知识 Mutation V2 与 Tombstone
  - [done] P002: iOS 远端基线、三方合并与 Delta 生成
  - [done] P003: 知识 V2 跨仓库 QA 与交付收敛

## Active

## Blocked

## Done
- [x] P000: P1 知识删除 Tombstone 与三方合并
- [x] P001: 后端知识 Mutation V2 与 Tombstone
- [x] P002: iOS 远端基线、三方合并与 Delta 生成
- [x] P003: 知识 V2 跨仓库 QA 与交付收敛

## Tickets
- [done] T000: 知识 Mutation V2 与三方合并实施票 -> P000 (split)
- [done] T001: 后端知识 Mutation V2 实施票 -> P001 (one_go)
- [done] T002: iOS 知识三方合并与 Delta 同步 -> P002 (one_go)
- [done] T003: 知识 V2 跨仓库 QA 与交付收敛 -> P003 (one_go)

## Latest Checks
- [success] C000: P001 结果已满足 P001 的全部合同与验证标准；线上部署不属于该子问题的完成条件，不阻断本地实现闭环。
- [success] C001: P002 R001 满足 P002 的每用户基线、三方合并、delta、隐私边界和 v1 fallback 标准；主控复核后补充的编辑/删除冲突测试也通过。
- [success] C002: P003 R002 满足 P003 的组合 gate、部署形态合同、文档和提交要求；公网部署明确不在本轮自动执行范围内。
- [success] C003: P000 R003 汇总的三个子闭环已全部通过独立检查，并满足根票对后端原子 delta、iOS 三方合并、隐私边界、兼容性和非真机验证的要求。
