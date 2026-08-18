# PC-00-02 时光信与延迟回复关闭验收

日期：2026-08-18
状态：COMPLETE
关联：GAP-12、NOTI-001
下一项：PC-00-03 首版可见范围收敛

## 1. 完成范围

1. 后端将 `timeLetters` 和 `echoDelayedReplies` 定义为产品确认关闭能力，cohort、旧策略快照和客户端声明均不能重新开放。
2. `/v2/release-policy` 和 `/config/runtime` 对两项能力固定返回 `enabled=false`、`providerReady=false`、`releaseVisible=false`、`reason=productClosed`。
3. 时光信与延迟回复的新建、调度接口对普通产品流量失败关闭；低层合同只在隔离测试中保留。
4. 已安装的时光信调度脚本在打开 Store 前直接返回 `productClosed`，不扫描旧记录、不生成消息、不触发 APNs。
5. 旧开发/测试记录继续只读，用户仍可完成已读或归档清理；关闭不会造成读取权限回归。
6. iOS 普通 Echo 不恢复、创建、调度或对账延迟回复；消息中心不展示时光信或 Echo 延迟回信。
7. 家庭邀请、关怀提醒、系统通知、普通 push token 注册和 InAppMessage 仍按原合同工作。
8. release regression 默认不再运行已关闭功能的正向 UIQA，新增关闭语义静态 Gate。

## 2. 历史数据与迁移确认

时光信和延迟回复从未作为正式生产功能发布，当前没有需要迁移、补发或回填的生产历史数据。仓库和测试环境中的开发/QA 记录不视为历史用户数据，本项未执行数据库迁移、生产 backfill 或补发任务。

兼容策略是：旧记录可读和可清理，但不能新建或投递。重新开放属于新的产品决策和独立 Work Item，不能通过恢复定时器、旧 feature flag 或客户端本地开关完成。

## 3. 版本

- iOS 实现提交：`80d88d95`（`fix: close time letters and delayed replies`）
- Backend 实现提交：`13081af`（`fix: close time letters and delayed replies`）
- Backend 测试维护提交：`4a8200e`（`test: stabilize provider cost evidence window`）
- Backend 远端与服务器部署源码：`4a8200eccfdfbcbaf51c3796ce43bcd6319cbd97`
- Backend 部署镜像：`sha256:a80be1bebb03bed171591e83df1ee751ba92abc422224a50ff4b204be7f38dfa`

## 4. 验证结果

### 后端

- PC-00-02 专项 Gate：6 个测试通过。
- 全量内存 Store 测试：2107 个测试通过。
- Provider cost evidence 独立测试：7 个测试通过。
- `git diff --check` 通过。
- 线上 `/ready`：database/schema/auth/incident 均为 ready，schema reason 为 `migrationHeadVerified`。
- 线上 Release Policy deployed smoke 通过。
- 线上 Runtime 专项断言通过：两项 capability 和别名均关闭，reason 为 `productClosed`。
- 服务器调度脚本返回 `itemCount=0`、`reminderCount=0`、`providerDeliveryAttempted=false`，且在打开 Store 前结束。

通用 runtime capability deployed smoke 还会检查独立的 `voiceCloneShell` 发布可见性。当前生产 Runtime 与 Release Policy 对该能力的可见性结论不一致，因此通用 smoke 在声音复刻断言处失败；PC-00-02 的两项关闭断言在此之前已通过。该漂移不由本轮引入，也未被本轮擅自修改。

### iOS

- 产品关闭静态检查通过。
- Runtime capability snapshot model smoke 通过。
- Public Release Scope model smoke 通过。
- 延迟回复 callsite、owner scope 和时光信通知生命周期 Gate 通过。
- Debug generic iOS Simulator workspace build 通过，`BUILD SUCCEEDED`。
- Release 模拟器 Public Scope UIQA 通过，使用本机 Bundle ID `com.yxj.dreamjourney.app`：隐藏 deep-link 绕过数为 0，自定义 URL scheme 数为 0。
- `git diff --check` 通过。

## 5. 证据

- 仓库证据包：`artifacts/product-confirmed/20260818-pc-00-02/PC-00-02/`
- UIQA 结果：`artifacts/product-confirmed/20260818-pc-00-02/PC-00-02/uiqa/result.json`
- UIQA 截图：`artifacts/product-confirmed/20260818-pc-00-02/PC-00-02/uiqa/01-authentication-gate-entry.png`

证据包只保存脱敏合同摘要，不包含 token、手机号、用户正文、Provider 凭据或媒体 URL。

## 6. 回滚与后续

产品决策是关闭时光信和延迟回复。出现回归时应 forward-fix 恢复 `productClosed`、零创建和零投递，不得通过恢复旧定时器或客户端开关重新开放。

下一项按连续执行队列进入 `PC-00-03`，统一关闭普通产品流量中的音频/视频入口，隐藏 KBLite 用户界面，并将客户端完整账户导出收敛为仅运维侧延期能力。
