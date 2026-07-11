# 接入 iOS Knowledge Governance Release QA Gate

## Problem Definition

治理模型、client、outbox 和 coordinator 检查均可独立运行，但 release QA package 不知道这些资产，`run-release-regression.sh` 也没有跨仓库组合开关或公开 UI 防误暴露 guard。

## Proposed Solution

新增 governance release boundary 静态 guard，检查治理 API 仅位于 Services、没有被公开 ViewController/Archive/Echo/Profile 页面调用。将 model/client/coordinator 和 boundary guard 加入日常静态步骤；新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1`，开启时额外运行 outbox、three-way/proposal/context 兼容 smoke 以及 sibling backend governance source-cascade runner。同步更新 release report 配置、scope 和 evidence。

## Acceptance Criteria

- release QA package 声明并校验所有 governance 脚本资产。
- 标准 release regression 默认运行轻量 governance model/client/coordinator/boundary guard。
- 可选组合 gate 调用完整 iOS governance/outbox/merge smoke 和后端 deterministic runner。
- boundary guard 证明公开 UI 模块未调用 `performGovernance` 或出现治理入口文案。
- package check、标准 regression（可关闭耗时 UI smoke）、开启组合 gate、Simulator workspace build、generic iPhoneOS 无签名 build通过。

## Verification Plan

先单独运行新增 boundary 和 package check；再运行最小标准 release regression 与 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 组合 regression；最后运行两种通用构建和 `git diff --check`。

## Risks

- `run-release-regression.sh` 较大，新增步骤需沿用 `run_step` 和 report 结构，避免破坏现有开关。
- 公开 UI guard 应限定产品模块，不应误报 Services 中的合法治理类型和错误文案。

## Assumptions

- sibling 后端默认路径为 `../DreamJourneyBackend`，也允许 `BACKEND_ROOT` 覆盖。
- 本问题不启动模拟器交互、不连接真机或线上后端。
