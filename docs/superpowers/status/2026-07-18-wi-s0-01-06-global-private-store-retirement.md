# WI-S0-01-06 Global Private Store Retirement

状态：`INTERNAL_READY / IOS_LOCAL_COMMITTED / G0_VERIFIED / G1_SIMULATOR_VERIFIED / G4_OPEN`

## 结论

`WI-S0-01-06` 已在 iOS 本地层停止 Conversation、Memoir、Memory/Map 和 Home 私有媒体的全局新写路径。目标 store 现在由有效 `AccountLease` 派生 owner scope；无法证明 Owner 归属、固定 fallback、损坏或不匹配的 legacy 数据不会自动挂载到当前账号，而是进入 quarantine、留给其可证明 Owner，或按既定策略 discard，并留下确定性 receipt。

本结论只覆盖已提交 iOS 本地实现及其 G0/G1 证据。它不建立服务端 Conversation/Message、Memoir 或 Canonical Memory 权威，不证明生产后端隔离，也不关闭 G4。

## 提交基线

| Commit | 收敛内容 |
| --- | --- |
| `bc81b7e` | Conversation owner-scoped envelope、AccountLease fence、legacy quarantine |
| `691fa43` | Memoir JSON/recording owner-scoped store、迁移 receipt 与 quarantine |
| `6e9d56a` | Memory 与 Map presentation owner-scoped store、legacy retirement |
| `f6107ae` | 保留 owner-scoped Memoir bridge，拒绝绕回全局 writer |
| `5048a5c` | Memory legacy receipt 改为确定且幂等 |
| `046690b` | Home 照片与录音 staging 改为账号私有媒体 store，退役旧全局目录 |
| `38ba20c` | 聚合前置门、四个子门和 no-new-global-write 静态门禁 |
| `fef51cf` | 增加可安装模拟器 A/B 隔离 UIQA、结果 JSON、截图及总 Gate 中的 UIQA 静态检查 |

G0/G1 的实现提交基线为 `feature/prd-stitch-ui-adaptation@fef51cf`。

## 本地 Store 结果

| Surface | 已实现行为 | 保留边界 |
| --- | --- | --- |
| Conversation | `ConversationMemoryManager` 通过 `ConversationLocalStorage` 写入 `subject + vault + owner + persona` scope 的 Application Support envelope；切号后旧 generation 不能 commit；可证明为本人所有的 scoped legacy 可 copy-on-write，其余 global、family owner-only、fallback 或损坏数据 quarantine | 仅为本地 conversation cache；服务端 Message authority、历史重取和最终 Conversation Domain 未由本项实现 |
| Memoir | JSON draft 与 recording 使用 `subject + vault + explicit owner` scope；Owner 必须显式传入；只有 owner-matching legacy 可迁移，other-owner 内容不挂载并留给其可证明 Owner，seed、ownerless、corrupt 和 orphan recording quarantine | 仍是本地草稿/录音实现，不是后端 Memoir authority；账号级统一 purge 归 `WI-S0-01-08` |
| Memory / Map | `MemoryRepository` 与 Map read/bounce presentation 使用同一 owner-scoped UserDefaults envelope；旧 `dj.persistedMemories`、`dj.readMemoryIds`、`dj.bouncedMemoryIds` 不再作为生产 live store；legacy item receipt 可重复观察而不重复生成 | 这是 legacy Memory/Map 本地投影，不是 V4 `ConfirmedMemoryVersion` / Canonical Memory authority；账号级统一 purge 归 `WI-S0-01-08` |
| Home private media | Home 照片写入 scoped Application Support，录音 staging 写入 scoped Caches，并在 request/commit 阶段校验原始 lease；旧 `Documents/photos` 照片 quarantine，临时 `TGSessionRecordings` discard，二者均保留确定性 receipt | 不覆盖 Archive Source/Object 后端、Provider 上传或全账号 purge；后续生命周期归 `WI-S0-01-08` |

固定 `user_001` 不能形成生产 scope。总静态门禁同时拒绝目标 writer 中的全局 I/O、全局 key/path、默认 Owner、Map fallback 和 release 源码中的非精确 allowlist 字面量；`38ba20c` 只接受 6 个 QA fixture 或 reserved-owner deny guard 中的精确出现。

## G0 验证

在实现文件与 `fef51cf` 一致的工作树上复跑：

```bash
bash Scripts/QA/product-v4/run-global-private-store-retirement-gate.sh
```

结果：`PASS`。

- AccountLease runtime 与 `WI-S0-01-05` Archive/Media 前置门通过。
- Conversation、Memoir、Memory/Map、Home account-private media 四个 model/static 子门通过。
- A/B owner 隔离、stale lease fail-closed、legacy ambiguous/corrupt、reserved fallback 拒绝、quarantine/discard receipt 与幂等性均在确定性模型中通过。
- 聚合静态检查输出：`Global private store retirement static check passed (6 exact user_001 literal allowance(s))`。

以上为 G0 源码、静态和确定性模型证据，不是模拟器、真机、后端或产品批准。

## G1 验证

证据：

- JSON：`tmp/visual-qa/product-v4/global-private-store-retirement/20260718-130256/global-private-store-retirement-uiqa-result.json`
- 截图：`tmp/visual-qa/product-v4/global-private-store-retirement/20260718-130256/01-global-private-store-retirement.png`
- runtime log：`tmp/visual-qa/product-v4/global-private-store-retirement/20260718-130256/runtime.log`
- OS log：`tmp/visual-qa/product-v4/global-private-store-retirement/20260718-130256/oslog.log`

结果：`completed=true`，账号对为 `uiqa-account-a` / `uiqa-account-b`。

| 断言 | 结果 |
| --- | --- |
| Conversation A/B 隔离与 generation continuity | `true` / `true` |
| Memoir A/B 隔离 | `true` |
| Memory 与 Map presentation A/B 隔离 | `true` / `true` |
| Home private photo A/B 隔离 | `true` |
| stale lease 拒绝 | `true` |
| global legacy Conversation quarantine | `true` |
| Home legacy media retirement | `true`，`legacyReceiptCount=2` |
| reserved fallback owner 拒绝 | `true` |

该结果只证明模拟器运行时的目标场景；不替代真机文件/权限行为、生产数据迁移或外部评审。

## 构建验证

- `generic/platform=iOS Simulator`、Debug、`CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`。
- `generic/platform=iOS`、Debug、`CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`。
- 新增告警/错误：无；输出中的 Pods、腾讯 SDK umbrella header 和 UIKit deprecated 告警为既有依赖告警。

## Gate 与非声明边界

- `G0`：`VERIFIED`，证据绑定 `38ba20c` 干净提交快照。
- `G1`：`VERIFIED`，证据绑定指定的 `20260718-130256` 模拟器 JSON、截图和日志。
- `G2/G3`：本项没有可用于升级成熟度的后端或 Provider 证据；不得从 G0/G1 推导服务端权威或生产隔离。
- `G4`：`OPEN / EXTERNAL_BLOCKED`。路线定义中的开放项是“是否允许用户显式认领 legacy 数据”的产品文案决策；当前继续 fail closed，未开放 claim UI。
- `WI-S0-01-08` 仍负责账号删除时的统一 scoped purge、剩余私有导出/日志/通知等生命周期收敛；本项不能表述为全 App 私有状态已全部退役。
- `DR-035` 的 Security / Privacy / Architecture 复核仍保持开放；本文不是发布批准。

结论：`WI-S0-01-06` 的 iOS 本地目标范围达到 `INTERNAL_READY`，G0/G1 已验证；G4 和所有后端权威声明继续保持开放。
