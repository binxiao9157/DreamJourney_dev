# 以三个后置 Work Item 补齐 Persona 与媒体 Authority

## Problem Definition

现有 Stage 1 路线缺少 Owner 可控 Persona、真实 SourceObject 摄入和媒体处理器三个单结果边界，容易让 provider/runtime 状态、mock upload 或模型抽取直接冒充用户人格、云对象或确认记忆。

## Proposed Solution

在 `WP-S1-01` 增加 Persona Authority 与 SourceObject 摄入两项，在 `WP-S1-02` 增加 Media Processor 一项；三项均位于 R3 Owner 文字核心之后的 R4/后置切片。同步更新 Stage 1 数量、包内批次、跨包批次和检查器，使 Optional/Provider/真机门不能进入 Owner 文字核心退出闭包。

## Acceptance Criteria

- 新增 `WI-S1-01-11`、`WI-S1-01-12`、`WI-S1-02-11`，每项完整 16 字段。
- Persona 只接受 Owner 明确确认的 allowlisted 属性；runtime/provider状态不进人格事实。
- SourceObject 只有在真实 commit/HEAD/checksum/MIME/scan合同后才可称 uploaded。
- Processor 只生成带 provenance 的 Candidate/ExtractionResult，不能直接 confirmed。
- Stage 1 更新为 33项/528字段，checker和实施批次一致；R3 Owner文字核心不依赖三项或G3/G4。

## Verification Plan

运行更新后的 Stage 1 checker、字段/依赖定向检查、全部 Product V4 checks 和 `git diff --check`；对 mock上传、processor直接confirmed和Optional反向依赖做负向文本断言。

## Risks

- 把媒体放入 Stage 1 可能被误解为 R3 必做，必须明确其为 R4 post-core。
- Persona 若复用 Family/DH 客户端 JSON 会形成第二 Authority，必须要求 typed owner command/receipt。

## Assumptions

- 首个可发布闭环仍是文字 Source→Review→Memory→QA→Correction→Rights。
- 对象存储、OCR/ASR/vision Provider 与真机媒体质量尚未批准或验收。
