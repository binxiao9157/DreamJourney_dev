# WI-S0-01-01 私有状态与测试承载面清单证据

## 结论

- 状态：`INTERNAL_READY / G0_EXECUTABLE_MODEL_VERIFIED / IOS_LOCAL_COMMITTED / SECURITY_DATA_REVIEW_OPEN`
- iOS 实现基线：`feature/prd-stitch-ui-adaptation@af9cf12`
- 后端：无业务代码变更、无需部署
- 本项只建立版本化 inventory、自动发现检查和现有 owner-isolation 组合 gate；不实现 `AccountSessionActor`、不迁移数据、不删除 legacy 数据。
- Registry 继续保持保守状态；Security/Data 外部审查尚未完成，但不阻止后续内部实现。

## 清单结果

1. 固定 17 个数据类别，登记 28 个具体私有、派生、短期或远程 effect surface。
2. 每个 surface 都包含 `surfaceId/dataClass/ownerScope/storage/pathOrKey/writer/readers/cleanup/migration/retention/testOwner`，并明确后续 Work Item。
3. 登记 51 个源码文件；扫描 `DreamJourney/Sources` 与 `DreamJourneyWidget` 后发现 43 个候选文件，结果为 `unknownPrivateSurface=0`。
4. 清单同时覆盖 Keychain、UserDefaults、App Group、Documents/Application Support/Cache/Temporary 文件、通知、Timer、数字人 lease、语音 Provider artifact、QA evidence 和日志 sink。
5. `registrationIsNotImplementation=true`：清理与迁移描述是待履行义务，不代表当前实现已经安全。

## 已知高风险与归属

- Archive 的 `legacy_unassigned` 自动认领、媒体字节清理与时间信件/通知生命周期：`WI-S0-01-05/08`。
- `ConversationMemoryManager`、`MemoirRepository`、`MemoryRepository`、Map 的全局路径和 `user_001` 兼容：`WI-S0-01-06`。
- VoiceClone 全局 profile key、轮询 callback、预览临时音频和远程 Provider artifact：`WI-S0-01-07`。
- Digital Human conversation/prompt/provider bridge/session lease 与 AccountLease 绑定：`WI-S0-01-07`。
- Knowledge 临时 JSON/PDF 分享文件、QA Documents evidence、日志最小化、Widget/通知清理：`WI-S0-01-08`。
- Keychain session、profile/release-policy cache 的单一账号激活边界：`WI-S0-01-02`。

## 验证证据

- `python3 -m json.tool Scripts/QA/product-v4/account-store-inventory-v1.json`：通过。
- `python3 Scripts/QA/product-v4/product-v4-account-store-inventory-check.py`：通过；`catalogCategories=17`、`registeredSurfaces=28`、`registeredSourceFiles=51`、`discoveredPrivateSurfaceFiles=43`、`unknownPrivateSurface=0`。
- `Scripts/QA/product-v4/run-account-store-inventory-gate.sh`：通过。
- auth session ownership、Archive ownership、Knowledge semantic cache、Family authorization freshness、Widget snapshot、Echo trace owner isolation smoke：全部通过。
- `product-v4-ios-account-store-rollout-check.py`：通过；`risks=11`、`stores=17`、`waves=9`、`scenarios=20`。
- Python compile、shell syntax、JSON parse、`git diff --check`：通过。
- `DreamJourney.xcworkspace` Debug generic iOS Simulator 构建：通过；只有既有第三方/deprecation warning。

## 验证边界

- 当前 test carrier 是静态检查与确定性 model smoke，不等价于 Simulator A/B 切号、后台恢复或异步竞态证明。
- 运行时 A/B、注销、删除、文件保护、备份排除和竞态 corpus 由后续 `WI-S0-01-02..08` 实现；正式 XCTest 承载面归属 `WI-S1-03-01`。
- 未运行真机、Provider 或 APNs 到达验证，本项也不依赖这些门。
- iOS 提交未推送，符合当前长期目标约束。
