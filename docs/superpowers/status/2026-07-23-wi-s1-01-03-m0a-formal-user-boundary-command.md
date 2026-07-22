# WI-S1-01-03 M0-A 正式用户边界命令

- 日期：2026-07-23
- 范围：私有访谈的 Owner 控制命令 `skipOnce`、`cooldown`、`doNotAsk`。
- 状态：该子闭环的 G0/G2 已验证并部署；公开 Echo 行为和 Provider 路径未改变。

## 已实现边界

后端新增默认不公开的 Owner-scoped 写入路由：

```text
POST /v2/vaults/{vaultId}/interview-sessions/{sessionId}/boundary
```

请求严格只接受 `commandId`、`threadId`、`expectedSessionVersion` 和
`boundary` 四个字段。允许的边界只有 `skipOnce`、`cooldown`、`doNotAsk`；
`open`、自由文本 reason、消息正文和其他扩展字段均返回稳定的 400 合同错误。

该路由复用自然输入的认证和捕获发布策略边界：

1. QA 才能使用 QA header 路径。
2. 非 QA 必须存在当前用户的已捕获 `echoTextInput` 发布策略。
3. 缺少捕获策略时 fail-closed，不会回退到 QA。
4. Owner、session version 和 command id 均由现有 Conversation service 校验。
5. 回执只含状态、thread/session 版本和边界，不回显叙事文本、Candidate、
   Memory、疲劳计数或 Provider 信息。

`skipOnce` 保持会话可继续；`cooldown` 和 `doNotAsk` 进入持久化 paused
状态。重新打开会话不是本次路由的能力，必须由独立产品决策和合同引入。

## iOS 合同

`OwnerTruthInterviewBoundaryCommand` 是没有自由文本的 typed command。它拒绝
`.open`，只生成四字段 payload。`DreamJourneyBackendClient` 复用既有
`ownerTruthInterviewNaturalInputTransport()`：非 QA 需要捕获策略，QA 才携带
QA header。该切片没有接入新的公开 UI。

现有 UIQA in-memory client 只模拟最小回执，不会发出私有写入、语音 turn 或
数字人请求。

## 验证

本地通过：

```text
PYTHONPATH=. .venv/bin/python -m unittest tests.test_owner_truth_interview_input_api tests.test_route_ownership_registry
./scripts/verify_backend.sh
xcodebuild test -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'platform=iOS Simulator,id=F54C960B-005F-434A-81E2-557D21AF14ED' -derivedDataPath tmp/visual-qa/v4-formal-boundary-command -only-testing:DreamJourneyTests/OwnerTruthContractsTests
xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet
git diff --check
```

结果：后端 focused tests 16 项通过、全量 `verify_backend.sh` 1072 项通过；
iOS `OwnerTruthContractsTests` 60 项通过；generic iPhoneOS Debug build 通过。

部署验证：

```text
backend main@a45170d
/ready -> status=ready
container isolated Postgres smoke -> passed
formalBoundaryPersisted=true
formalBoundaryDeduplicated=true
formalBoundaryPausedStateVerified=true
formalBoundaryPausedPresentationVerified=true
productionBusinessDataMutated=false
```

部署 smoke 在 API 容器内创建并清理独立临时 Postgres 数据库，未修改现有业务
数据。

## 非目标与剩余 Gate

- 不生成问题、不会写 Candidate 或 MemoryVersion，也不会调用 Provider。
- 不新增或暴露公开 Echo 控件，产品入口仍由既有 release policy 控制。
- 本证据只关闭该子切片的 scoped G0/G2；`WI-S1-01-03` 的 G1/G3/G4 仍需按
  独立范围验证，不能由本次命令路由推导关闭。
