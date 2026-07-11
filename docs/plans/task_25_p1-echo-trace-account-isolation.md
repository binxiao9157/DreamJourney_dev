# Task 25：P1 Echo Trace 账号隔离与登出清理

## 目标

消除 Echo QA trace、runtime diagnostics、evidence package 和 QA bundle 使用全局 `UserDefaults` 造成的跨账号读取风险。所有诊断数据必须绑定当前账号，登出或账号切换时清理，旧账号异步回调不得在失效后重新写入。

## 范围

- 为四类 Echo 诊断 store 使用 owner digest 派生的账号级 storage key，不在 key 中暴露原始 user ID。
- record/read/export 必须绑定明确 owner；非当前账号写入被拒绝。
- UserManager 冷启动、登录、账号切换和登出驱动统一 account scope。
- 登出和账号切换清理旧账号的 trace/runtime/evidence/bundle，并删除旧版全局 key。
- QA 导出文件使用 owner digest 目录，切换/登出同步删除持久化记录和临时 JSON。
- 保持现有 QA 面板和 JSON 导出能力，但只能导出当前账号数据。
- session/voice evidence 记录请求发起时的 owner；旧请求 callback 由 lifecycle token、request owner 和 active-owner store 三层拒绝。
- UserManager 将账号字段、Echo scope、KBLite/Knowledge 切换和通知收敛到同一串行事务。

## 验收标准

- A 账号记录无法被 B 账号读取或导出。
- 切换 A -> B 后 A 数据被清理；登出后四类 store 均为空。
- 登出/切换后到达的 A 账号异步写入被拒绝，不会重建旧数据。
- A 的数字人 runtime/session/voice capability 页面缓存不会出现在 B 的 snapshot 或 evidence 中。
- A 的 QA 导出 JSON 在 A -> B 或登出后被删除。
- 冷启动恢复登录态后只激活该账号；legacy 全局 key 被安全清除而非跨账号迁移。
- QA smoke 使用显式 owner，不破坏现有 Echo trace/evidence 导出。
- 相关 model/static checks、release regression、Simulator 和 generic iPhoneOS 构建通过。

## 非目标

- 不改变公开 Echo UI。
- 不上传 trace 到后端。
- 不做真机验证。
- 不处理 operation receipt 生命周期；该项列为后续 Task 26 候选。
