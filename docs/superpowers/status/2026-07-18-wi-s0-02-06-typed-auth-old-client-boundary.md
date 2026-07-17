# WI-S0-02-06 Typed Auth 与旧客户端边界证据

## 结论

- 状态：`INTERNAL_READY / BACKEND_DEPLOYED / G2_POSTGRES_VERIFIED / IOS_LOCAL_COMMITTED / G4_EXTERNAL_BLOCKED`
- iOS：`feature/prd-stitch-ui-adaptation@4ec3715`
- 后端：`main@ab668a7`，已推送并部署到生产服务器
- 生产兼容模式：`observe`
- Registry 保持保守 `PLANNED/STOP`；本文只记录当前实现证据，不替代真实登录体验 G4。

## 已实现边界

1. iOS 私有页面只接受可用的 typed user session；无 session、过期 refresh、账号不匹配或后端验证失败时停留在 signed-out/public UI。
2. 私有请求由 endpoint descriptor 声明 auth、purpose、owner binding，并校验 session user；不恢复 mobile shared/system token、离线私人登录或 client-derived owner authority。
3. 冷启动先在线轮换 refresh credential，验证成功后才挂载私有 store 和三个主 Tab。
4. 后端 USER 路由拒绝 machine principal；退役的 `/auth/login`、`/auth/restore` 返回稳定 `426 upgrade_required`。
5. 旧客户端写请求以最小 build 合同处理。生产先使用 `observe` 收集无值指标，读请求继续兼容；尚未直接切换全局 `enforce`。
6. `401/403/426`、最低 build、兼容决策和 route-auth 原因可观察，不记录 token、正文或个人内容。

## 验证证据

### iOS

- typed-auth cutover、client auth boundary、login identity、identity challenge、token family 检查通过。
- auth session ownership、route ownership、backend auth token 检查通过。
- Release artifact 的 mobile credential retirement 与 credential response boundary 检查通过。
- `release-qa-package-check.swift` 通过；历史视觉证据目录缺失项按脚本合同跳过，不属于本次代码失败。
- Debug Simulator 构建通过：`/tmp/DreamJourney-WI-S0-02-06-auth-cutover-build-2.log`。
- Release generic iPhoneOS 构建通过：`/tmp/DreamJourney-WI-S0-02-06-release-build-final.log`。
- `git diff --check` 通过。

### 后端本地

- focused suite：69 tests passed。
- `./scripts/verify_backend.sh`：518 tests、FastAPI、knowledge、credential、backup 和 compile checks 全部通过。
- 完整日志：`/tmp/DreamJourneyBackend-WI-S0-02-06-verify.log`。
- `git diff --check` 通过。

### 部署与线上 Postgres

- `GET /health`：`200`，`store=postgres`。
- `GET /ready`：database、schema、auth 均为 `ready`。
- identity challenge deployed smoke：通过，生产保持 fail-closed。
- route authentication Postgres smoke：通过；`routeCount=68`、`unclassifiedCount=0`，匿名、machine/user 交叉越权均被拒绝。
- client compatibility deployed smoke：通过；`mode=observe`，旧客户端 mutation probes 无持久化写入。

## 未覆盖与后续归属

- G4 真实登录体验、旧客户端真实分布和强制升级窗口仍为 `EXTERNAL_BLOCKED`；安全边界不依赖该门。
- 生产兼容策略暂不切为 `enforce`，需先积累 observe 指标并单独执行 rollout。
- `MemoryRepository`、`MemoirRepository`、`ConversationMemoryManager`、Map 等仍存在全局 key、seed 或 `user_001` 兼容路径；归属 `WI-S0-01-01..08`，不能把本项描述为本地账号隔离已经完成。
- 本项未创建 `AccountSessionActor`，避免越权重复实现；下一 Work Item 从私有状态 inventory 开始。
- iOS 提交未推送，符合当前长期目标约束。
