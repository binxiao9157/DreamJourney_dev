# 实现后台 session 宽限 lease

## Problem

当前 `didEnterBackground` 立即关闭腾讯 runtime，短暂切换应用会反复创建 session；同时必须避免后台长期占用并发。

## Success Criteria

- 后台进入只暂停交互并安排带 generation 的短时释放 lease。
- 宽限期内回前台取消 lease，保留 provider view/session，不自动启动麦克风。
- lease 到期且 generation/context 仍匹配时才关闭 runtime。
- 页面退出仍立即关闭 runtime并取消 lease。
- 模拟器 lifecycle UIQA 可重复验证取消与过期两条路径。
