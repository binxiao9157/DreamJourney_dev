# WI-S0-01-08C 账号注销本地显式数据清理

## 状态

- Work Item：`WI-S0-01-08`
- 子闭环：`WI-S0-01-08C account deletion local purge`
- Authority：`ACCOUNT_LOCAL_STATE`
- 状态上限：`INTERNAL_READY`
- G0：已通过
- G1：已有模拟器编译/安装证据，真实交互验收仍开放
- G3：外部 Provider 删除回执仍开放
- G4：真实设备、产品、隐私和法律验收仍开放

本闭环只处理后端 soft delete 成功后的 iOS 本地生命周期，不改变普通退出登录或切换账号的保留语义，也不把本地清理结果当作远端删除完成。

## 实现内容

1. 注销流程先捕获旧 `AccountLease`，完成 session fence，再按 13 个生命周期模块执行 teardown；所有模块进入 terminal receipt 后才允许 session actor 转为 signed out。
2. Archive、私有媒体、Memoir、Memory items 和 Memory map presentation 使用旧账号的 subject/vault/generation scope 清理本地数据及对应 quarantine，不读取当前账号重新推导 scope。
3. 普通 logout/switch 继续保留旧 owner 草稿并锁定访问；只有 `accountDeletion` 事件进入显式草稿 purge。
4. 后端删除成功但本地清理失败、远端 Provider receipt pending/unsupported 或旧回调过期时，返回 cleanup-pending/failed 证据，不显示为完整删除成功。
5. 删除异步回调在账号切换、generation 变化或生命周期 fence 不匹配时被忽略，避免旧账号结果写入新账号。

## 相关文件

- `DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift`
- `DreamJourney/Sources/Services/UserManager.swift`
- `DreamJourney/Sources/Services/AccountPrivateMediaStore.swift`
- `DreamJourney/Sources/Services/MemoryRepository.swift`
- `DreamJourney/Sources/Memoir/MemoirRepository.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- `Scripts/QA/product-v4/account-explicit-draft-deletion-purge-check.py`
- `Scripts/QA/product-v4/run-account-explicit-draft-deletion-purge-gate.sh`
- `Scripts/QA/product-v4/account-deletion-lifecycle-static-check.py`
- `Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift`

## 验证

- `bash Scripts/QA/product-v4/run-account-explicit-draft-deletion-purge-gate.sh`：通过。
- `bash Scripts/QA/product-v4/run-account-deletion-lifecycle-gate.sh`：通过；13 modules、stale callback、residual cleanup、logout draft retention 均通过。
- `bash Scripts/QA/product-v4/run-account-lifecycle-coordinator-gate.sh`：通过。
- `bash Scripts/QA/product-v4/run-account-lifecycle-module-registry-gate.sh`：通过；29/29 inventory surfaces mapped，0 gaps。
- `git diff --check`：通过。
- `bash Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh`：通过。
- `SIMULATOR_NAME='iPhone 17 Pro' bash Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh`：通过，编译、安装和 mobile credential artifact check 均通过。

证据路径：

- `tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260718-175907-iphoneos-generic-build/report.md`
- `tmp/visual-qa/prd-stitch-ui/installable-simulator-uiqa/20260718-175946/install.env`

## 未声明事项

- 未修改后端，因此不需要部署或线上 smoke。
- 未声明真实设备交互、远端对象/Provider/备份删除完成。
- 未关闭 G1/G3/G4 外部门。

## 下一步

进入计划中的 `WI-S0-05-01`，先做 access-first rights/deletion lifecycle 的现有合同盘点和最小可验证闭环；保持 M1-M4 默认关闭。
