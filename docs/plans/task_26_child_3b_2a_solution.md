# 部署 Compact Receipt Reader 并验证服务基线

## Problem Definition

线上必须先运行支持 compact/full 双读的新 reader，确保旧数据和新 writer 可共存，才能安全执行历史 receipt 最小化。

## Proposed Solution

读取现有私密 SSH/部署指南，连接服务器并确认仓库、分支和当前容器。拉取 `origin/main` 到 `4c0538b`，使用既有 compose/部署命令重建重启，不打印 `.env`。验证容器状态、日志中无启动异常、公开 `/health` 和 `/config/runtime`，再运行不会修改 receipt 的基础 deployed knowledge smoke。

## Acceptance Criteria

- 服务代码 commit 为 `4c0538b`。
- 容器/服务健康，公开 health 200/store=postgres。
- Runtime config 和基础 knowledge smoke 通过。
- 未调用 receipt maintenance `--apply`。
- 私密配置不出现在聊天、提交或证据日志。

## Verification Plan

远程 rev-parse、compose ps/logs、curl health/runtime、已有 deployed smoke；保存只含版本/状态的本地报告。

## Risks

- 服务器工作树如有未提交运维修改，不覆盖；先审计再拉取。
- 重建失败时保留旧容器并停止进入 P014。

## Assumptions

- 现有 SSH 指南和服务器路径仍有效。
