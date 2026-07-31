# V4 M0-A 正式结束分享与待确认批次

日期：2026-07-31

## 本轮范围

将既有访谈结束接口从 QA-only 自动化路径收敛为正式、受策略控制的产品合同；同时在现有“今天想聊点什么？”自然输入 sheet 内提供受控的“结束这次分享”动作。

这次只完成 M0-A 的“退出时形成待确认批次”小闭环，不改变 Echo 全屏视觉、不会公开候选原文，也不会将候选直接写入正式记忆。

## 合同与边界

- 后端 `POST /v2/vaults/{vaultId}/interview-sessions/{sessionId}/end` 复用自然输入的 `echoTextInput` 捕获策略；无捕获策略时拒绝请求。
- 正式结束在同一 Unit of Work 内结束会话，并在策略允许时创建隐藏的 `sessionExit` review batch。响应只保留 value-minimized session receipt，不返回候选、批次或叙述正文。
- QA header 仍可得到已有 QA-only 自动化摘要；该摘要不会进入正式产品路径。
- iOS 的 typed `OwnerTruthInterviewEndCommand` 只包含命令 ID、thread/session ID 与乐观版本；客户端不传文本、结束原因、候选 ID 或批次状态。
- “结束这次分享”仅在产品 sheet 已成功保存至少一条叙述、会话仍 active/open 且允许继续时出现。关闭 sheet、取消输入和空会话均不会结束访谈。
- 成功结束后，客户端刷新 continuation 为 `reviewPending`，并隐藏结束动作。此时“本轮不可继续”，但 `canContinueLater=true` 明确表示以后可开启新的叙述；待确认记忆入口仍由独立的 `ownerTruthCandidateReview` 发布策略控制。

## 验证

- 后端正式策略负向与隐藏批次回归：
  `tests.test_owner_truth_interview_input_api.OwnerTruthInterviewInputAPITests.test_formal_end_requires_captured_policy_and_creates_hidden_session_exit_batch`
- 后端结束 Gate：`scripts/run-backend-owner-truth-interview-end-g0-gate.sh`，98 项通过。
- iOS 单测：
  - `testInterviewNaturalInputUseCaseEndsPersistedSessionAndRefreshesContinuation`
  - `testNaturalInputProductSheetEndsOnlyPersistedNarrative`
- 产品边界静态检查：
  `Scripts/QA/product-v4/owner-truth-interview-product-boundary-surface-check.py`
- 模拟器产品交互回归：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`
- 通用 iPhoneOS Debug 构建：
  `Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh`
- `git diff --check` 已通过。
- iOS workspace 定向单测通过；QA fixture 与正式合同均使用“本轮不可继续、以后可新开叙述”的同一语义。

## 线上部署验收

- 后端已推送并部署至 `main@cab554e`。
- 生产环境 schema 已从 `0065` 前向迁移至 `0070`；迁移只新增/收敛结构与约束，不删除业务记录。
- 在 API 容器内执行
  `DREAMJOURNEY_DEPLOYED_CONTAINER_SMOKE=1 BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn bash scripts/run-backend-owner-truth-interview-natural-input-deployed-smoke.sh`
  通过。
- 线上 smoke 使用临时数据库，确认正式结束、隐藏 `sessionExit` review batch、重复结束幂等和 `reviewPending` 展示态；`productionBusinessDataMutated=false`。
- `https://dreamjourney-api.liftora.cn/ready` 返回 ready，数据库、schema、auth 与 incident 探针均通过。

本轮 UIQA 截图：

`tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-181721/01-owner-truth-interview-natural-input-product-surface.png`

## 未声明完成的事项

- 未声称 Candidate 提取、确认或正式 MemoryVersion 激活已经公开发布。
- 未触发真实 Provider、数字人、语音、APNs 或真机验收。

## 下一步

按终版计划选择下一个未完成的 M0-A Owner Truth 小闭环；保持 Candidate 审核、MemoryVersion 激活和公开发布策略独立过 Gate。
