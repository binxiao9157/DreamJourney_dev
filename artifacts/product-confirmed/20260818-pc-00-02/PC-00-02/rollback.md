# PC-00-02 回滚

产品确认结果是关闭时光信和延迟回复。回归时优先 forward-fix 以下不变量：

1. `timeLetters` 和 `echoDelayedReplies` 固定 `productClosed`。
2. 新建与调度接口失败关闭，旧记录只读和清理操作保留。
3. 时光信调度脚本在打开 Store 前返回零结果。
4. iOS 普通路径不恢复、创建、调度或展示这两类消息。
5. 家庭邀请、关怀、系统通知和其他普通 InAppMessage 不受影响。

不得通过恢复旧 feature flag、旧策略快照、定时器或客户端 QA 参数重新开放。重新开放属于新的产品决策与独立 Work Item。
