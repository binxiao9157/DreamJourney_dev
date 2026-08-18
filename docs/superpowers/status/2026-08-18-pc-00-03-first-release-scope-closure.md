# PC-00-03 首版可见范围收敛验收

日期：2026-08-18
状态：COMPLETE
关联：ARCH-004、DATA-001、KB-001、PCQ-09、PCQ-11、PCQ-12
下一项：PC-A0 密码与手机号验证码双登录

## 1. 完成范围

1. 后端将普通用户音频上传、视频上传、KBLite 用户面和完整账户导出固定为 `productClosed`，任何 audience、cohort 或旧策略输入都不能重新开放。
2. `/config/runtime` 对四项能力统一返回关闭状态；KBLite 内部 `kbSync` 保持开启，不改变既有账户、Vault 和 Grant 隔离合同。
3. Owner Truth V2 上传按媒体类型分类：图片和文档继续进入首版媒体能力，音频和视频在策略层及摄入服务层失败关闭。
4. 普通 iOS 创建入口只展示文字、图片和文档；音频、视频只允许由显式 internal UIQA 开关构造，Release 不展示占位或“即将开放”。
5. iOS 重启恢复和失败重试不再对音频、视频发起后台网络请求；客户端在请求构造前再次执行产品关闭校验。
6. KBLite 页面与路由只保留显式内部 QA 路径，普通用户无入口；后端读写能力没有被误删或改权。
7. “我的”页不展示完整账户导出入口，账号注销说明也不再暗示用户可下载完整 ZIP。正式记忆 Markdown 导出保留给后续 `PC-C2`，运维脱敏完整导出继续 `DEFERRED`。
8. 图片、文档、普通消息中心、三 Tab、普通 Echo、档案与家人功能未因范围收敛被关闭。

## 2. 版本与部署

- iOS 实现提交：`e4e5034b`（`feat: enforce confirmed first release scope`）
- Backend 实现提交：`6d542f9`（`feat: enforce confirmed first release scope`）
- Backend smoke 维护提交：`9759f1b`（`test: align runtime smoke with confirmed scope`）
- Backend 远端与服务器部署源码：`9759f1bf1a3ab288a04a70da332acb7ef23e5fff`
- Backend 部署镜像：`sha256:988e4462dbe64ac6efbb75c9f190cfabda14e40f843aeec1716cb10ee3d9360d`
- 数据库 migration head：`0093`，本项无 schema 变更、无 backfill、无历史记录删除。

## 3. 验证结果

### 后端

- PC-00-03 实现相关 Gate：69 项通过。
- 全量 unittest discovery：2111 项通过。
- deployed smoke 维护后的相关测试：18 项通过。
- 服务器 deployment preflight、迁移 dry-run/apply/verify 和前后备份通过。
- 线上 `/ready`：database/schema/auth/incident 均为 ready。
- 线上 Runtime Capability deployed smoke 通过。
- 线上 Public Release Scope deployed smoke 通过。
- 线上快照确认：音频、视频、KBLite 用户面、完整账户导出均关闭；`kbSync=true`；普通 Owner 媒体类型仅为 `document`、`image`。
- `git diff --check` 通过。

### iOS

- 首版范围、媒体创建、档案信息架构、账号生命周期、Release feature matrix 和 Group 3 静态 Gate 全部通过。
- Owner Truth 媒体定向测试 2 项通过。
- Debug generic iOS Simulator workspace build 通过，`BUILD SUCCEEDED`。
- Release 模拟器 Public Scope UIQA 通过：Bundle ID 为 `com.yxj.dreamjourney.app`，隐藏 deep-link 绕过数为 0，自定义 URL scheme 数为 0，Release 包不含 QA 编译条件。
- `git diff --check` 通过。

独立观察：`OwnerTruthContractsTests` 全类在 iOS 26.5 仍有两项既有 Candidate Inbox 展示测试失败；它们可在本轮媒体改动之外独立复现，本轮定向测试和应用构建均通过，未在本项做无关修复。

## 4. 证据

- 仓库证据包：`artifacts/product-confirmed/20260818-pc-00-03/PC-00-03/`
- UIQA 结果：`artifacts/product-confirmed/20260818-pc-00-03/PC-00-03/uiqa/result.json`
- UIQA 截图：`artifacts/product-confirmed/20260818-pc-00-03/PC-00-03/uiqa/01-authentication-gate-entry.png`

证据包只保存脱敏合同摘要，不包含 token、手机号、用户正文、媒体 URL、对象键或 Provider 凭据。

## 5. 回滚与后续

回归时应 forward-fix 恢复 `productClosed`、Release 零入口和后台零误调用，不得通过旧 feature flag、QA 参数或 mock Provider 重新开放。内部音视频代码继续保留用于未来独立产品决策和测试，不作为当前完成态。

Phase 0 三项关闭边界均已完成，`Gate P0` 通过。连续执行队列进入 `PC-A0`，实现密码与手机号验证码双登录；真实短信 Provider 继续作为 OTP 的外部 Gate，不阻塞密码合同与非真机开发。
