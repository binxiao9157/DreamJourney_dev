# 双仓提交部署与线上 Postgres Receipt 验收

## Problem

本地实现需要形成可追溯双仓提交并部署到现有服务器，真实 Postgres 必须先 dry-run 再决定 apply，同时验证线上重放和维护组合合同。

## Success Criteria

- iOS 与后端分别提交并推送正确分支，状态干净且无密钥/临时产物。
- 服务器拉取新后端并重建/重启成功，`/health` 正常。
- 线上 receipt maintenance dry-run 报告脱敏保存，`status=ok`、failed=0 才允许 apply。
- Apply 使用小 batch；二次运行 candidate/updated=0。
- 线上 duplicate/conflict、privacy maintenance 和 change-feed receipt barrier 验证通过。
- 失败时停止 apply 并记录真实 blocker，不删除 receipt 行。
