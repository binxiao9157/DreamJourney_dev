# 跨仓 QA、提交部署与线上存量验收

## Problem

新写入与存量清洗合同需要进入 release 防回退，并在生产 Postgres 上以 dry-run/apply/dry-run 顺序完成可审计验收。

## Success Criteria

- 跨仓 gate 与 release package guard 覆盖 canonical mutation 和 maintenance。
- 后端全量、release regression、Simulator/generic iPhoneOS build 通过。
- 双仓分别提交推送，后端部署。
- 线上 dry-run、apply、post-apply dry-run 均输出脱敏聚合；post-apply 待更新数为 0。
- 不做真机、Widget/Family/compaction 或 source identity 迁移。
