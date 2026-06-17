# P0 真机与后端验收就绪包

## Problem Definition

PRD 的核心闭环已经具备模拟器级别的档案到回响验证，但真实验收还缺少一个稳定、可重复的就绪包来区分三类事情：

- 可以由当前工程自动证明的配置与脚本合约。
- 必须在真实后端环境运行的接口、鉴权、同步和回退验收。
- 必须在真机上完成的麦克风、照片、语音权限和系统行为验收。

如果继续只依赖模拟器截图或本地后端，容易把环境缺口误写成实现完成，也容易在后续 Stitch UI 或 PRD 逻辑更新后重复遗漏同一批检查。

## Proposed Solution

新增一份 P0 验收就绪说明，并配套一个轻量静态检查脚本：

- 文档明确真机验收、后端验收、阻塞条件、执行命令和产物路径。
- 文档要求真实密钥只通过 `DreamJourney/Config/Backend.local.xcconfig` 或运行时环境变量注入，不提交真实 token。
- 检查脚本验证隐私权限、后端 build setting、`Backend.local.xcconfig` 忽略规则、后端 smoke 脚本强制 token、核心闭环脚本存在。
- 更新 PRD 缺口图，把 Task 3 标记为“就绪包完成，真实验收待环境/真机”而不是“已完成真机验收”。
- 不修改用户可见 UI，不触碰后端真实地址，不引入破坏兼容的数据迁移。

## Acceptance Criteria

- `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md` 存在，并覆盖真机验收、后端验收、阻塞条件、执行步骤和验收产物。
- 文档明确 `DREAMJOURNEY_BACKEND_BASE_URL`、`DREAMJOURNEY_BACKEND_API_TOKEN`、`Backend.local.xcconfig`、`run-backend-env-smoke.sh`、`run-archive-to-echo-smoke.sh` 的使用方式。
- 文档明确真实 token 不得提交，且当前缺真实后端/真机时只能声明“验收就绪”，不能声明“真机已验收”。
- 静态检查脚本能验证 Info.plist 隐私声明、后端配置忽略规则、后端 smoke token 要求和核心 QA 脚本存在。
- PRD 缺口图引用该验收就绪说明。

## Verification Plan

- 先运行新增静态检查脚本并确认在文档缺失时失败。
- 补齐文档和 PRD 缺口图后重新运行新增静态检查脚本。
- 运行既有后端配置检查：
  - `swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 运行提交清单检查：
  - `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 运行 `git diff --check`。
- 本任务只改文档和检查脚本，不要求 iOS 重新构建；真实后端 smoke 和真机验收在用户提供环境后执行。

## Risks

- 如果后续后端接口字段变化，文档和 smoke 脚本需要同步更新。
- 真机验收依赖 Apple 开发者签名、设备、系统权限弹窗和真实语音能力，不能由当前模拟器自动替代。
- 如果用户提供的后端 token 权限不足，后端 smoke 会失败，但这属于环境或权限问题，需要单独定位。

## Assumptions

- 当前分支继续以 `run-archive-to-echo-smoke.sh` 作为档案到回响核心闭环回归。
- 真实后端 base URL 和 token 不应写入仓库。
- 暂不公开家庭/persona 切换、账号注销、医生联系等未完全闭环功能。
