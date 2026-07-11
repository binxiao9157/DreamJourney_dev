# Echo Trace 账号隔离成功检查

## Summary

结论为成功。实现覆盖原问题的四类持久化数据、导出文件、页面缓存、账号事务和异步 provider 回调，且默认发布回归与两类构建均通过。

## Evidence

- Result `R000` 记录了实现文件、测试命令和模拟器证据路径。
- owner isolation model smoke 验证 A/B 读写隔离、旧 owner 晚到写入拒绝、切换/登出清理、原始 ID 不进入 key/path。
- 三条实际 Simulator UIQA 导出 smoke 验证生产 Store 的 JSON 写入、解码和 QA harness 兼容性。
- 默认 release regression 在最终代码上运行并包含新增 model/static guard。
- Simulator 和 generic iPhoneOS 构建成功；`git diff --check` 通过。
- 两轮独立复审发现的五类竞态与残留问题均已修复，末轮唯一 nickname-only 竞态已通过 expectedUserId 边界收敛。

## Criteria Map

- A 不能读取/导出 B：active-owner scope、owner digest key、package owner 一致性和 model smoke 覆盖。
- A -> B 清理 A：UserDefaults、manifest、确定性默认 owner 导出目录和 Echo 页面缓存同时清理。
- 登出清理当前账号：UserManager 串行事务先失效 Echo owner，再清本地记录和 runtime/session。
- 旧 callback 不重建：session/voice 捕获 request owner，回调校验当前 owner，Store 再拒绝 inactive owner。
- 冷启动和 legacy：恢复用户后激活唯一 owner，旧全局 key/临时文件只清除不迁移。
- QA 能力不回归：trace、evidence package、QA bundle 模拟器 smoke 均通过。

## Execution Map

- 数据层：`EchoTraceOwnerScope`、`EchoOwnerScopedDefaultsStore` 和四类 Store。
- 证据层：runtime snapshot、session/voice summary、evidence package 的 owner 绑定。
- 账号层：`UserManager` 的递归锁事务及 expectedUserId profile guard。
- 页面层：Echo account lifecycle reset、旧 runtime 无 diagnostics 释放、request owner 回调检查。
- QA 层：新增 model/static guard并接入 release regression/release QA package。

## Stress Test

- 模型执行 A 写入、B 越权写入、A -> B 切换、A 晚到写入、B 导出、A 越权导出、B 登出和 B 晚到写入。
- evidence owner 分别注入 runtime、session、synthesis 不一致，全部拒绝。
- 导出文件在切换和登出后检查实际文件不存在。
- 独立复审模拟账号切换夹在 profile 保存及 provider callback 之间，相关路径已增加事务或 request owner 校验。

## Residual Risk

- 未做真机验证，但本任务只改变本地诊断数据生命周期，Simulator、generic iPhoneOS 和默认 release regression 足以覆盖计划内非真机验收。
- UIQA 临时账号复制到 Documents 的内容全部为 harness 构造的 mock 数据，不用于生产账号导出。
- operation receipt 保留周期是独立知识库维护问题，不影响本任务成功判定。

## Result IDs

- `R000`
