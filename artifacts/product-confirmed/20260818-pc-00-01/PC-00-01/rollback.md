# PC-00-01 回滚

产品确认结果是普通产品路径关闭数字人。出现回归时，优先 forward-fix 恢复以下不变量：

1. 服务端 `digitalHumanLivePanel` 固定 `productClosed`。
2. 创建与续约 Session 失败关闭；历史 release 路由只用于释放租约。
3. iOS 普通路径不启动 RuntimeFactory，不展示数字人状态或 fallback。
4. QA 合成路径只能由显式 QA launch argument 进入。

不得通过恢复旧 Provider 配置、旧 Session、旧策略快照或 authenticated-owner rollout 来“回滚”。若只回退 iOS，服务端继续拒绝会话；若只回退服务端，iOS 产品关闭集合继续阻止普通调用。重新开放数字人属于新的产品决策和 Work Item，不属于本项回滚。
