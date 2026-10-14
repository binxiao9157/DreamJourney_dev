# 三项 iOS 协议装配回归

范围仅测试与夹具。正式 `LiveRecoveryEnabled` 必须保持 true；不要通过修改 Info.plist 运行旧协议场。

- `testCandidateInboxUIKitKeepsSecondDetailWhenPolicyExpiresBeforeWrite`：明确主题入口，保留两详情、权限到期和只写一次的业务断言。
- `testCandidateThemesRejectInvalidContractsAndNeverWriteOnReadFailure`：错误 schema/vault/HTTP 拒绝，无 POST。
- `testCAP06CoordinatorConflictKeepsCaptureAndPersistsLaterTurnsAndCloseIntent`：显式旧协议兼容。
- `testCAP06RecoveryConflictKeepsAllElevenBodiesAndCloseIntent`：恢复开启，同一冲突后 11 条正文、序号、身份、确认水位、落盘重建及关闭意图。冲突时 finalSequence 必须为空，不伪造完整冻结。
- `testRecoveryMissingOrWrongGenerationStartPreservesOutboxAndRefusesLegacyFallback`：非法协商不降级，正文与恢复坐标仍在。
- CAP15 旧 helper 的全部 8 个调用者显式传协议；新模式由下面的实际 HTTP gate 验证。

## 实际 API / Worker / PostgreSQL

先启动专用的空 PostgreSQL 实例，仅监听 127.0.0.1。以下脚本创建随机命名数据库并应用当前全部迁移；不使用线上账号。合成模型只监听本机；Worker 使用生产模块 CLI，API 使用正式 lifespan。脚本会生成 `/private/tmp/dj-three-tests-recovery-config.json`（短期合成凭据，权限600），停止时删除该配置。不要并行启动第二份相同 gate。

```sh
DJ_TEST_BACKEND_ROOT=/absolute/path/to/DreamJourneyBackend \
DJ_TEST_PG_ADMIN_DSN=postgresql://djtest@127.0.0.1:55541/postgres \
LAB_LOCAL_OUT=/absolute/new/evidence-directory \
/absolute/path/to/DreamJourneyBackend/.venv/bin/python \
Scripts/QA/three-ios-protocol-regression/local_recovery_server.py
```

看到 READY 后用模拟器跑 `OwnerTruthContractsTests/testCAP15RecoveryActualHTTPShortThenLogicalTenMinutes`。构建明确指定 `DREAMJOURNEY_BACKEND_BASE_URL=http://127.0.0.1:3100`，避免把占位 URL 的登录测试误当作配置完成。该 URL 只用于普通 App 启动；场次 API 地址从隔离配置读取。不要改正式源码/发布地址。

本次场次顺序固定：独立 short6（6轮/12正文）→ logical10（30轮/60正文、逻辑600秒）。先完成短场发布、主题确认及正式冷读，才允许长场开始。长场是逻辑时间输入，不是十分钟物理时长或真实声学验收。

数据库逐条比对消息 ID、序号、角色、正文哈希及 canonical handoff，检查已发布快照的末序号、连续范围和缺口；再核对主题成员、决策回执、正式版本及完整事实集合。另记录真实 start 协议、close 位置、旧 end/ACK/admit 请求必须为零。未配置此 gate 会明确 SKIP，不能记 PASS。

测试结束后向脚本 PID 发 SIGTERM，脚本停止 Worker/API 并删除临时配置；对该合成数据库做 dump 后停止专用 PostgreSQL。保留证据目录。

## 发布开关保护

```sh
python3 Scripts/QA/three-ios-protocol-regression/verify_release_config.py \
  --repo /absolute/path/to/DreamJourney_dev \
  --app /absolute/path/to/Debug-iphonesimulator/DreamJourney.app
```

两个 plist 都必须为布尔 true。结合 XCTest 的 `testReleaseRecoveryFlagRemainsEnabled` 使用。检查实际执行数和用例名；测试类选择参数不得带末尾 `/`（会导致0项）。

完整设计及验收记录：liftora/02-问题修复/测试与验收/2026-10-14-三项iOS回归配置漂移/。

## 受控 SDK 编译专项

告别播放边界、PCM排空和Provider错误尾部保存三个测试位于 `#if LIVE_MANAGER_CONTROLLED_SDK`，普通构建不会生成，不能因选择名存在而记为已执行。使用同一源码，额外构建参数 `OTHER_SWIFT_FLAGS=$(inherited) -D LIVE_MANAGER_CONTROLLED_SDK`（整个参数作为一个命令行参数传入），选择以下三项及 `testReleaseRecoveryFlagRemainsEnabled`：

- `testLiveFarewellPlaybackBoundariesKeepSavedTail`
- `testLiveFarewellUsesCurrentProviderAndWaitsForPCMDrain`
- `testLiveFarewellProviderErrorStillSealsTail`

这些是本地受控 SDK 验证，不是实际供应商或手机声学验证。2026-10-14普通配置94项及本配置4项均通过；恢复开关检查重复1项，唯一测试合计97项。
