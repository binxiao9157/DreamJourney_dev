# WI-S1-01-03 M0A-27：本轮跳过一次性恢复

日期：2026-07-23
后端基线：`main@5b2bafd`
iOS 基线：`feature/prd-stitch-ui-adaptation@303e168`（本轮无 iOS 代码变更）

## 问题与范围

产品定义中，`skipOnce` 只应跳过当前一次追问机会。此前正式边界命令可写入
`skipOnce`，但后续 owner narrative 不会恢复边界，导致一次性选择残留在会话内。

本轮只收敛该恢复语义：

- `skipOnce` 写入后保持 `active`，等待当前机会的 owner 输入。
- 下一条 `owner + narrative` 成功写入时，在同一次 session 更新中恢复 `boundary=open`。
- 非 owner 输入不会消费该边界。
- 重复同一 append command 仍返回既有 receipt，不重复写入或改变版本。
- 不开放客户端写入 `open`，不增加路由、迁移、Provider 调用、Candidate、Memory
  或公开 Echo UI。

## 实现

`OwnerTruthConversationRepository` 的 in-memory 与 Postgres append 实现使用同一
typed 条件：仅当当前边界为 `skipOnce`，且 append record 为 owner narrative 时，
将本次 append 的回执和持久化 session 边界写为 `open`。Postgres 路径在既有
版本围栏与消息写入事务内完成，避免先落入叙事再单独改边界的中间状态。

## 验证

本地：

1. 先新增 API 回归测试，修复前断言 `boundary=open` 失败，实际返回 `skipOnce`。
2. `tests.test_owner_truth_interview_input_api`、`tests.test_owner_truth_interview_pacing_state`、
   `tests.test_owner_truth_interview_session_orchestration`、
   `tests.test_owner_truth_interview_orchestration`：28 项通过。
3. `py_compile`、`bash -n` 与 `git diff --check`：通过。

部署：

1. 后端已推送并部署为 `main@5b2bafd`。
2. `/ready`：`status=ready`，API/Postgres/Redis 均健康。
3. 在部署 API 容器内运行
   `scripts/run-backend-owner-truth-interview-natural-input-deployed-smoke.sh`：通过。
4. 隔离临时数据库验证：
   `skipOnce -> next owner narrative -> open`、append replay dedup、cooldown、
   content-free state/presentation 均通过。
5. smoke 输出：`productionBusinessDataMutated=false`。

## Gate 结论

- 该子闭环为 `WI-S1-01-03` 的 scoped G0/G2 证据。
- M0-A 仍默认关闭；G1 的公开体验、G3 Provider 与 G4 发布/真实用户 Gate 均未因
  本轮关闭。
