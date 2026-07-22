# WI-S1-01-03 M0A-25：正式访谈边界用例的 AccountLease 围栏

日期：2026-07-23  
iOS 基线：`feature/prd-stitch-ui-adaptation@07ef43e`  
后端基线：`main@a45170d`（本轮未变更）

## 本轮范围

将已部署的正式访谈边界命令接入 `OwnerTruthInterviewNaturalInputUseCase`，仅处理
`skipOnce`、`cooldown`、`doNotAsk` 三种 owner 控制。

- 请求开始时校验 QA gate、vault 和 `AccountLease`。
- 异步回调提交时再次校验 generation 与 `AccountLease`；账号或 vault 重绑定后的旧结果不得提交。
- 回执必须匹配 thread、session、boundary、版本和预期生命周期：`skipOnce` 保持 `active`，其余两种控制为 `paused`。
- 成功后仅拉取 value-minimized continuation；不保留输入文本，不创建 Candidate、Memory 或 Provider effect。

## 明确不包含

- 不新增公开 Echo 控件或默认可见入口。
- 不允许 `open`/重新开启命令。
- 不改后端路由、不部署后端、不改变生产 Authority。
- 不涉及 Provider、数字人、语音或 Memory promotion。

## 验证

1. `OwnerTruthContractsTests`：62 个测试通过，覆盖正常 cooldown、paused continuation、`open` 本地拒绝、回执 boundary 不匹配，以及账号重绑定后的延迟回调丢弃。
2. `swiftc -parse`：`OwnerTruthContracts.swift` 与测试文件通过。
3. `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`：Debug 构建通过。
4. `git diff --check`：工作区通过。

## Gate 结论

- 本轮新增的是 scoped G0 iOS use-case 证据。
- 已部署的后端 G2 正式边界路由仍以 `a45170d` 为准；本轮没有新的后端部署需求。
- G1/G3/G4、公开发布与生产 Authority 切流仍保持未完成状态。
