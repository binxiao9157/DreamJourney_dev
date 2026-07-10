# Audit Gate、提交与部署证据

## Problem

全路由策略需要稳定 QA、文档和线上 Postgres 证据，否则路由新增或部署漂移会绕过审计。

## Success Criteria

- 新增静态审计 guard、HTTP smoke 和 release 可选 gate。
- 后端全量测试、simulator/generic iPhoneOS build、diff check 通过。
- 两仓库提交推送，后端重新部署并确认 commit/store/shadow/runtime。
- 线上 owner mismatch、system-only 和 delegated smoke 通过且不泄漏 token/正文。
