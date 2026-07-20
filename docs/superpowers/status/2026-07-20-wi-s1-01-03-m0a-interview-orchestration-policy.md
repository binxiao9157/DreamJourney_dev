# WI-S1-01-03 M0-A 引导式访谈策略基础

日期：2026-07-20

## 本次闭环

终版需求的 M0-A 不能继续把旧 Echo 的随机开场问题或本地 KBLite 摘要当作访谈编排器。
本切片新增后端纯领域模块：

```text
app/domain/owner_truth/interview_orchestration.py
```

它在 `Conversation/Source` 与自然语言响应层之间提供无副作用的策略决策：

- `LISTEN`、`DEEPEN`、`CLARIFY`、`BROADEN`、`SUMMARIZE`、`PAUSE` 的稳定枚举；
- 当前 `InterviewSession` 的生命周期、当前 thread 的 opaque identity、深挖轮数、候选批次轮数、疲劳及用户边界的输入合同；
- 同一线索最多 4 次深挖；在安全且信息不完整时允许继续，在第 4 次后强制总结；
- 对 `skipOnce`、`cooldown`、`doNotAsk`、敏感内容、疲劳和用户换题的 fail-closed 行为；
- 5 轮后或会话结束时仅给出 `reviewBatchDue` 提示，绝不直接创建 Candidate、DecisionReceipt 或 MemoryVersion；
- 可写入 trace/evidence 的 value-free 摘要，不返回 thread、vault、owner、topic 或用户原文。

## 明确不做的事

本切片不持久化 Conversation、Message、Thread、Session、偏好或编排决策；不接 `/context/build`、
LLM、ASR/TTS、数字人或任何 Provider；不生成问题文本；不改变 iOS Echo 全屏视觉；不向公开用户展示
主题目录、疲劳分数、待办或候选审核。

因此它只是 M0-A 的 G0 策略基座，不能宣称引导访谈、批量确认或知识地图已经完成。

## 验证

新增：

```text
DreamJourneyBackend/tests/test_owner_truth_interview_orchestration.py
```

覆盖安全深挖、2–4 轮总结、澄清优先级、跳过/冷却/禁问、敏感内容、疲劳收束、换题暂停、批次提示、
终态会话和 value-free 摘要。

本地执行：

```bash
PYTHONPATH=. .venv/bin/python -m unittest tests.test_owner_truth_interview_orchestration
bash scripts/verify_backend.sh
git diff --check
```

结果：专用单测 `10` 项通过；完整后端验证 `949` 项通过，FastAPI、知识库、异步副作用与备份 smoke 均通过。

后端提交 `85ee9e2 feat(v4): add guided interview policy core` 已推送并部署。服务器 API 容器内的模块导入和
确定性 `DEEPEN` 决策 smoke 通过；公开 `/ready` 返回 `status=ready`，database、schema、auth、incident
均为 `ready`。生产镜像不复制 `tests/` 目录，因此容器验证使用模块 smoke，不把这项限制误报为测试失败。

## Gate 状态

| Gate | 状态 | 含义 |
| --- | --- | --- |
| G0 | 完成 | 纯策略、边界优先级和 value-free trace 均已由单测证明。 |
| G1 | 未开始 | 尚未接入 Echo UI/QA diagnostics。 |
| G2 | 未开始 | 尚无 Conversation/Session 持久化、版本 CAS 或隔离 Postgres replay。 |
| G3/G4 | 不适用 | 本切片不发起 Provider 请求，也不涉及真机。 |

## 下一子切片

进入 `WI-S1-01-03-M0A-01-CONVERSATION_SESSION_BOOTSTRAP`：建立 owner-scoped、default-off 的
`Conversation + Message + InterviewSession` 持久化基础，使用 `commandId` 幂等和 `expectedVersion` CAS。
初版 `currentThreadId` 可以为空，且仍禁止 Message 自动升格为 Source、Candidate 或 MemoryVersion。
