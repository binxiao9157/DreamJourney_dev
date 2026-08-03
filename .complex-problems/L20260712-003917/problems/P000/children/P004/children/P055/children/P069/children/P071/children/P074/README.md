# Round 4E1A2：补齐 Persona 与真实媒体 Authority 路线

## Problem

Stage 1 已覆盖 Owner Truth、异步 Effect 与 iOS Composition，但缺少三个独立结果：Owner 可控的 Persona Authority、真实 SourceObject 摄入，以及媒体处理器从对象到 Candidate 的流水线。当前路线容易把 Provider runtime 状态误当人格事实，也可能把 mock/local-only 媒体误标成 uploaded 或 confirmed memory。

## Success Criteria

- 在 `WP-S1-01` 新增 `WI-S1-01-11` Persona Authority 和 `WI-S1-01-12` SourceObject 摄入。
- 在 `WP-S1-02` 新增 `WI-S1-02-11` Media Processor。
- 三项各有完整 16 字段；分别固定 Owner 控制、对象存在证明、Candidate-only 输出、失败/重试/删除 receipt 和 Provider 边界。
- Stage 1 计数由 30 项/480 字段更新为 33 项/528 字段；Stage 1 checker、批次和 Owner 文字核心非阻断边界同步。
- `FR-MEM-003/004` 不被媒体任务伪装为当前完成，仍由后续价值门延迟。

## Verification

- 校验新增三个 ID 的顺序、唯一性、16 字段和 package owner。
- 校验 mock/local-only 不等于 uploaded，processor 输出不直接成为 confirmed memory。
- 运行 Stage 1 checker、全量 Product V4 检查及 `git diff --check`。

## Boundaries

- 只修改路线和检查器，不开发对象存储、视觉 Provider 或 iOS 媒体功能。
- Media/Persona 后置项不得阻断 Owner 文字核心 `R3`。
