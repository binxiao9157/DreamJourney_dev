# PC-00-01 数字人普通产品路径关闭验收

日期：2026-08-18
状态：COMPLETE
关联：GAP-11、DH-001
下一项：PC-00-02 时光信与延迟回复统一关闭

## 1. 完成范围

1. 后端将 `digitalHumanLivePanel` 定义为产品确认关闭能力，普通用户与过期策略快照均不能重新开放。
2. `/v2/release-policy` 固定返回 `enabled=false`、`releaseVisible=false`、`reason=productClosed`。
3. `/config/runtime` 固定返回数字人 `enabled=false`、`releaseVisible=false`、`productState=closed`、`reason=productClosed`。
4. `/digital-human/sessions` 对普通已登录用户返回 `403 release_policy_denied/productClosed`，且不进入 Session 创建逻辑。
5. 旧 Session 的 release 路由仍可用于清理历史租约；create 和 heartbeat 不可绕过关闭策略。
6. iOS 普通产品路径在 capability/session 调用前失败关闭，不展示数字人容器、连接状态或 fallback 提示。
7. QA 合成入口继续保留，但只由显式 QA launch argument 触发，不复用普通登录资格。
8. 数字人关闭后，普通 Echo 仍可使用文字与火山本地语音链路。

## 2. 版本

- iOS 实现提交：`84339ab8`（`fix: close digital human public product path`）
- Backend 实现提交：`0a8d5a8`（`fix: enforce digital human product closure`）
- Backend 远端与服务器部署源码：`0a8d5a80`
- iOS 文档基线：`d7b3804a`

## 3. 验证结果

### 后端

- 专项 Gate：68 个相关测试通过。
- Release Policy：46 个测试通过。
- Digital Human Sessions：9 个测试通过。
- Runtime Capabilities：13 个测试通过。
- 线上 `/ready`：`ready`，database/schema/auth/incident 均 ready。
- 线上 Release Policy：`digitalHumanLivePanel=false`，reason 为 `productClosed`。
- 线上 Runtime：数字人能力关闭，productState 为 `closed`。
- 线上普通用户负向请求：创建 Session 返回 403，reason 为 `productClosed`；测试会话随后立即吊销。

通用 `backend-credential-response-deployed-smoke.py` 仍包含独立的 `realtimeToken=false` 环境假设，而服务器当前该能力为 true，因此本轮不把它作为 PC-00-01 的判定 Gate；数字人相关合同已由专项线上断言覆盖。

### iOS

- 产品关闭静态检查通过。
- 数字人 runtime abstraction 检查通过。
- 数字人 live panel 检查通过。
- Public Release Scope model smoke 通过。
- Generic iPhoneOS Debug workspace build 通过，`BUILD SUCCEEDED`。
- 普通 Echo 模拟器连续对话 UIQA 通过冷启动和进程重启两轮：
  - 首轮与次轮对话完成；
  - stop 后回到 idle；
  - stale reply 被拒绝；
  - 切离/返回 Echo 正常；
  - `digitalHumanPanelVisible=false`；
  - `audioOwner=volcengineLocalTTS`。

## 4. 证据

- 仓库证据包：`artifacts/product-confirmed/20260818-pc-00-01/PC-00-01/`
- 普通 Echo 可视复核：`artifacts/product-confirmed/20260818-pc-00-01/PC-00-01/uiqa/ordinary-echo-no-digital-human.jpg`
- 原始本机 UIQA 输出：`/tmp/dreamjourney-pc-00-01-uiqa/20260818-pc-00-01/`

证据包只保存脱敏合同摘要，不包含 token、手机号、Provider 凭据或用户正文。

## 5. 回滚与后续

产品决策为关闭数字人，因此常规回滚应恢复本次 fail-closed 实现，而不是重新开放数字人。若客户端回退，服务端 Release Policy 和 Session 路由仍保持最终拒绝；若服务端回退，iOS 产品关闭集合仍阻止普通路径调用。

下一项按连续执行队列进入 `PC-00-02`，关闭时光信和延迟回复的新建、投递与普通 UI 入口。
