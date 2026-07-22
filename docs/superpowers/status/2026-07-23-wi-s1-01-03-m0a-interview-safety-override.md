# WI-S1-01-03 M0A-29: 正式访谈危机安全覆盖

## 范围

`POST /v2/vaults/{vault_id}/interview-sessions/{session_id}/messages`
在创建 `AppendInterviewMessageCommand` 前执行既有 `SafetyPolicy`。

当输入命中明确高风险表达时，接口返回值最小化的
`owner-truth-interview-safety-override-v1`，HTTP `409`，并附带已有的
中性安全决策。该响应固定 `persisted=false`、`retryable=false` 和
`Cache-Control: no-store`。

## 已验证行为

- 危机文本不会进入 Conversation/Interview 持久化写入，也不会增加 turn 或版本。
- 响应不回显原始文本，只返回已有 `SafetyDecision` 与中性安全文本。
- 后续普通叙述仍可用原始 optimistic version 正常提交。
- 不启动 Persona、复刻声音、数字人或其他 Provider effect。

## 证据

- 后端提交：`4ebeda0 fix(m0): intercept crisis interview narratives`
- 本地：30 项 Owner Truth / Safety 相关单测通过；`py_compile` 和 `git diff --check` 通过。
- 部署：后端 `main@4ebeda0` 已拉取、API 容器重建并健康；迁移头保持 `0038`。
- 线上：部署容器内隔离 Postgres smoke 通过，返回
  `formalCrisisNarrativeSafetyOverridden=true` 和
  `formalCrisisNarrativeNotPersisted=true`，未修改生产业务数据。

## 非声明项

- 这不是临床危机干预或紧急联系人闭环。
- 不增加公开访谈入口；自然输入和边界控制继续受既有 ReleasePolicy/默认关闭策略约束。
- 不解决 topic identity、`doNotAsk` 跨会话再识别，或 `cooldown` 到期策略；这些仍需独立产品合同。
