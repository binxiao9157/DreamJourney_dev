# PC-E2 Rollback

PC-E2 只新增 QA、部署 smoke 和证据分类，不改变产品开放范围。

1. 如 QA 脚本误阻断合法证据，回退 iOS `8cd337f1` 或后端 PC-E2 测试提交，并先保留失败日志。
2. 不得通过回滚重新开放 `digitalHumanLivePanel`、`timeLetters` 或 `echoDelayedReplies`。
3. 后端运行异常时优先保持上述 Feature 为 `productClosed`，停止相关 Worker 副作用，再 forward-fix。
4. Worker 镜像必须与数据库 migration head `0104` 相容；不得恢复会产生 `migrationHeadAhead` 的旧镜像。
5. 回滚后重新运行 `/ready`、关闭能力 deployed smoke 和稳定 Feature smoke。
