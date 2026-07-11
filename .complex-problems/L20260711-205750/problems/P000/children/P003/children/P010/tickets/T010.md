# 提交部署并执行真实 Postgres Receipt 验收

## Problem Definition

Task 26 已完成本地实现和跨仓非真机验收，但两仓仍未提交推送，服务器尚未运行新 reader/maintenance 代码，真实 Postgres 的 dry-run、apply、幂等和 replay 证据缺失。

## Proposed Solution

先复核双仓状态与敏感信息，分别提交后端实现和 iOS QA/文档并推送正确分支。按照现有 SSH/部署文档登录服务器，确认当前版本、拉取后端 main、重建并重启服务，验证 health。随后在容器/服务实际环境运行 receipt maintenance dry-run，将脱敏 JSON 保存到本地证据目录；仅当 status=ok、failed/failedUsers=0 且 kind 合法时，以小 batch 执行 apply，再二次 dry-run/apply确认 candidate/updated=0。最后运行线上 duplicate/conflict、privacy maintenance dry-run 和 change-feed receipt barrier smoke，更新状态文档和 ledger。

## Acceptance Criteria

- 两仓提交内容无密钥、私密配置和 tmp 产物，推送成功且远端包含新提交。
- 服务部署到新后端提交，health 返回 200 且 store=postgres。
- Dry-run 报告脱敏保存，异常时停止 apply。
- Apply 不删除 receipt、不修改 payload hash；小 batch 成功，二次运行幂等。
- 线上 duplicate/conflict、privacy maintenance 与 change-feed barrier 验收通过。
- iOS/后端状态文档记录提交、部署版本、命令、结果与剩余风险。

## Verification Plan

执行双仓 git status/log/diff/check、push 后远端 commit 校验；服务器 git rev-parse、容器/服务状态、health；maintenance dry-run/apply JSON 审计；线上 knowledge deployed smoke 和 privacy/change-feed 维护检查；最终双仓状态与 Closure check。

## Risks

- Dry-run 发现异常历史 receipt、锁超时或未知 kind 时必须停止，不允许自动猜测修复。
- JSONB apply 会产生 WAL/旧 tuple，应使用小 batch 并观察数据库。
- 远程私密 token/DSN/SSH 信息只从已忽略私密文件读取，不写入日志或提交。

## Assumptions

- 现有服务器 SSH 与部署私密文档仍有效。
- 用户已授权任务完成后提交、推送和部署。
