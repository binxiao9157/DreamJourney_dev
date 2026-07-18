# WI-S0-01-08A Account Lifecycle Coordinator 证据

## 1. 状态

- Work Item：`WI-S0-01-08`
- 子闭环：`WI-S0-01-08A coordinator / module registry / receipt model`
- Authority：`ACCOUNT_LOCAL_STATE`
- 提交：`aa33ed1 feat(WI-S0-01-08): add account lifecycle coordinator`
- 结论：统一生命周期内核、29 个私有 surface 到 13 个 lifecycle module 的确定性映射和 G0 可执行 Gate 已完成；`WI-S0-01-08` 仍为 `IN_PROGRESS`，下一子闭环是 08B 的 switch/logout/suspend/cold-start 真实入口接管。
- 状态上限：本轮没有改变用户登录、退出或注销行为，也没有声明 G1/G4 完成。

## 2. 实现

### 2.1 统一生命周期内核

- 新增 `AccountLifecycleCoordinator`，覆盖 cold-start recovery、switch、logout、private suspension 和 account deletion 五类事件。
- 固定执行阶段：fence、cancel effects、unmount runtime、clear projection、clear notification、retain/purge draft、finalize。
- 同一个 operationId 可从已持久化的部分 receipt 恢复，已完成 operation 重放不重复执行模块。
- 模块失败生成 terminal failure receipt，但不会中断后续模块收敛。
- 同 operationId 若被另一个 event/generation 重用，fail closed。
- account deletion 若仍有本地数据，不允许被报告为成功。

### 2.2 值最小化 receipt

- operation receipt 只记录 operationId、事件、旧 generation、模块、阶段、结果、remainingLocalData、detailCode 和时间。
- receipt 不保存 subject、vault、session、token、credential 或业务正文。
- detailCode 只允许规范化标识字符，避免错误文本带入值数据。
- receipt 最多保留最近 30 次操作，只用于恢复/验收，不作为身份或业务 Authority。

### 2.3 Lifecycle module registry

- 从 AccountStoreInventory 的 29 个 surface 生成 13 个 lifecycle module，覆盖数为 29/29。
- switch/logout 对同 owner 显式草稿执行 retainedLocked/unmounted，不删除草稿。
- logout 清 runtime/cache/export/notification。
- account deletion 要求本地用户数据 purge；外部数据必须生成 deletion/unsupported receipt，不能静默保留。
- 新增 lifecycle receipt surface，并继续保持 AccountStoreInventory 无未知私有面。

## 3. 多 Agent 协作

- 主控：生产 coordinator、Xcode target、receipt store、inventory 收敛和最终审查。
- QA agent：coordinator 静态检查与可执行模型 smoke。
- Registry agent：29 个 inventory surface 的生命周期模块映射与全覆盖 checker。
- 三个写入范围互不重叠，最终由主控统一运行 Gate 和构建。

## 4. 验证

- `run-account-lifecycle-coordinator-gate.sh`：通过。
- `run-account-lifecycle-module-registry-gate.sh`：通过，`inventorySurfaces=29`、`mappedSurfaces=29`、`modules=13`、`phases=7`、`gaps=0`。
- `run-account-store-inventory-gate.sh`：通过，`registeredSurfaces=29`、`unknownPrivateSurface=0`。
- production Swift typecheck：通过。
- `git diff --check`：通过。
- generic iOS Simulator Debug build：通过，日志为 `tmp/visual-qa/prd-stitch-ui/wi-s0-01-08a/simulator-build.log`。
- generic iPhoneOS Debug build：通过，日志为 `tmp/visual-qa/prd-stitch-ui/wi-s0-01-08a/iphoneos-build.log`。
- 两个构建均通过命令行使用本机覆盖 `com.yxj.dreamjourney.app / 2BTR77V3R8`，未修改共享签名配置。

## 5. 后续交接

08B 将 coordinator 接入 `UserManager`、`AppCoordinator` 和 private-access suspension：先旋转 generation/撤销 lease，再按 registry 取消 runtime、卸载 projection、清 Widget/通知，最后开放新账号挂载。08C 再单独接 account deletion purge，避免把普通 logout 与不可逆删除混为一体。
