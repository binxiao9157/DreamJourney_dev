# 后端 Principal 强绑定

## Problem

路由 ownership 目前已分类但尚未参与中间件决策，user bearer 在 shadow 模式下仍可能跨 owner 访问，或调用 system-only 任务。

## Success Criteria

- ownerBody/ownerPath mismatch 在 shadow 模式下即时返回 403。
- systemOnly 对 user principal 即时返回 403，backend system token 保持可用。
- owner match 与 family/time-letter/invitation/care delegated 访问保持可用。
- profile、archive、mailbox、voice、KB、session、push、echo、family 有代表性正负向测试。
- 授权拒绝日志继续只记录 hash。
