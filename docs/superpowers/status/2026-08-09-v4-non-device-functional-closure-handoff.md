# DreamJourney V4 非真机功能收敛交接

日期：2026-08-09  
状态：`NON_DEVICE_CODE_COMPLETE`

## 1. 结论

V4 当前计划中可在不使用真实设备、真实 COS 凭据、真实短信、强身份/活体 Provider 和 M2 法律放行条件下独立完成的工程开发，已经完成并通过统一回归。

这不等于产品已获准发布。最终证据继续固定为：

- `NON_DEVICE_CODE_COMPLETE`
- `WAITING_EXTERNAL_PROVIDER`
- `WAITING_TRUE_DEVICE`
- `releaseDecision=NO_GO`

`NO_GO` 表示非真机证据不能代替外部服务、产品法律和真实设备验收，不表示本轮代码 Gate 失败。

## 2. 版本基线

| 仓库 | 分支 | 提交 | 状态 |
| --- | --- | --- | --- |
| iOS | `feature/prd-stitch-ui-adaptation` | `f481c2f26a852e220048b7cab6023eaf77888414` | 已推送 |
| 后端 | `main` | `e8eacc5c84fb9863d1b5d35266a9e3945ec7016e` | 已推送、已部署 |

后端部署态 `/ready`、公开 release policy smoke 和合成账号 `audience=visitor` Postgres smoke 均通过。登录访客不会继承 owner 策略，M2 仍以 `publicationVisitorNotApproved` 默认拒绝。

## 3. 统一非真机证据

执行入口：

```bash
bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh \
  --execute \
  --run-id 20260809-final-non-device
```

最终结果：

| Lane | 命令数 | 结果 | 覆盖范围 |
| --- | ---: | --- | --- |
| M0 | 7 | 通过 | 后端全量合同、effect 对账、能力自动停用、导出删除、Candidate、Context、generic iPhoneOS build |
| Stage 2 | 5 | 通过 | 媒体处理、COS/扫描器 fake matrix、OTP fail-closed、媒体状态与模拟器 UIQA |
| M1 | 7 | 通过 | Voice/DH readiness、声音复刻生命周期、Echo binding、账号生命周期与故障边界 |
| M2 | 7 | 通过 | 正式闭测 API、Visitor 隔离、撤回传播、外部清理、default-off 壳层与模拟器 UIQA |
| 合计 | 26 | `26/26` 通过 | 四条 lane 全部通过 |

完整本地证据：

- `tmp/qa/v4-unified-non-device-evidence/20260809-final-non-device/manifest.json`
- `tmp/qa/v4-unified-non-device-evidence/20260809-final-non-device/report.md`
- 同目录下 `m0/`、`stage2/`、`m1/`、`m2/` 的脱敏命令日志与 UIQA 产物

可持久化脱敏摘要：

- `docs/superpowers/status/2026-08-09-v4-non-device-functional-closure-manifest.json`

## 4. 已完成的工程边界

1. M0 Owner Truth 的 Source、Candidate、MemoryVersion、Context、导出、删除和 effect reconciliation 已有统一非真机 Gate。
2. 服务端 cohort、能力级开关、readiness、自动停用和 iOS typed capability consumer 已收敛。
3. 私有媒体已具备真实状态、Provider-neutral COS/扫描器合同、文档处理、失败重试和默认关闭行为；没有伪造 OCR、ASR 或视觉分析成功。
4. OTP、身份、声音复刻和数字人均在外部条件缺失时 fail-closed，不会静默使用错误身份或默认音色冒充成功。
5. Publication/Visitor 正式闭测 API 与 QA API 分离；iOS 只在“我的”受控区域承载，未增加 Tab，Visitor 不会进入私人 Echo、Voice 或 Digital Human。
6. 账号切换、过期、撤回和策略拒绝会清除相应缓存、凭据和运行时状态。

## 5. 外部等待项

以下项目不再属于可独立完成的非真机代码缺口：

- `realIdentityProvider`：真实短信/身份 Provider、签名、模板和送达回执。
- `mediaStorageAndProcessingProvider`：私有 COS bucket、最小权限凭据、SSE/保留策略和真实 ClamAV sidecar。
- `voiceTrainingAndDeletionReceipts`：生产音色槽、训练/查询/删除及 Provider 完成回执。
- `publicationIndexAndProviderCleanupReceipts`：M2 外部索引和 Provider 清理完成回执。
- `adultIdentitySafetyAndRegulatoryReleaseGate`：成年校验、隐私/安全/法律评估和 closed-beta cohort 批准。

## 6. 真实设备等待项

- M0 麦克风、照片权限、前后台恢复、通知导航和设备性能。
- 大文件媒体采集、上传、播放和资源压力。
- 复刻音色听感、扬声器/听筒路由、腾讯数字人口型、打断和麦克风恢复。
- Visitor 与数字人长会话、弱网、并发配额和恢复体验。

## 7. 后续执行规则

1. 外部条件就绪后，只补对应 Provider/设备证据，不重新开发已通过的合同层。
2. M1/M2 在外部 Gate 完成前保持 default-off；不得因本文件的 `NON_DEVICE_CODE_COMPLETE` 提前开放。
3. 每次修改 Source/Candidate/Memory/Context、媒体、声音/数字人或 Publication/Visitor 后，先运行统一非真机 runner，再进入真机或 Provider 验收。
4. 任何失败都从对应 lane 日志定位，不再依赖截图猜测跨模块原因。
