# Reader-first 后端部署结果

## Summary

后端 `4c0538b` 已部署到现有服务器，API 容器重建成功，Postgres/Redis 数据容器保持运行；公开健康、runtime 和 deployed knowledge smoke 均通过，尚未执行 receipt apply。

## Done

- 服务器仓库从 `32607ec` fast-forward 到 `4c0538b`。
- 仅重建/recreate API 服务，Postgres 和 Redis 未重建。
- API 日志显示应用正常启动，无 schema/startup 异常。
- `/health` 返回 200、environment=production、store=postgres。
- `/config/runtime` 鉴权访问成功，kbSync=true。
- Deployed knowledge smoke 验证登录、V2 mutation/tombstone、幂等 retry、payload conflict、稳定分页、generation context 和 token/用户标识脱敏。

## Verification

- Server commit：`4c0538bf3d2c90cf0ce9d3ca0dfbcb2138c73e85`。
- API/Postgres/Redis compose services 均 Up，Postgres healthy。
- Deployed smoke `completed=true`、`conflictVerified=true`、`idempotentRetry=true`。

## Gaps

- 真实 Postgres receipt dry-run/apply 尚未执行，属于 P014。

## Artifacts

- Backend commit `4c0538b`
- Public health `https://dreamjourney-api.liftora.cn/health`
