# 用九个独立步骤建立可撤回的 Publication 与 Visitor 文字 Lane

## Problem Definition

当前正式工程没有Publication/Visitor authority，`MemoryModel.isPrivate`、Family关系、TimeLetter收件人或私人KBLite过滤都不能承担公开授权。必须从已确认MemoryVersion显式创建独立副本，并在产品、Privacy/Legal和滥用治理批准前保持default-off。

## Proposed Solution

为`WP-S3-01`建立九个Work Item：

1. `WI-S3-01-01`：产品/Privacy决策、数据分类、AI披露和release policy硬门。
2. `WI-S3-01-02`：Publication/Version/ShareGrant/VisitorSession/Feedback schema与AuthZ。
3. `WI-S3-01-03`：Owner Publish draft/snapshot/review/confirm command与receipt。
4. `WI-S3-01-04`：独立Public Index/projector、对象副本和citation。
5. `WI-S3-01-05`：Visitor identity/session/grant、rate-limit与public query gateway。
6. `WI-S3-01-06`：Visitor文字回答、不知道策略、AI披露、举报与滥用防护。
7. `WI-S3-01-07`：Publication更新、suspend/withdraw、grant revoke和传播receipt。
8. `WI-S3-01-08`：Owner/Visitor UI、聚合指标与default-off公开回归。
9. `WI-S3-01-09`：shadow/canary/cohort、delete/incident/retirement与Stage3 exit gate。

每项16字段完整；Publication只能钉住已确认MemoryVersion并生成独立副本，不实时跟随私人版本。Visitor永不查询private Vault/Projection或写Owner Memory。Voice/DH公开能力不随文字Visitor自动开放。

## Acceptance Criteria

- 九个ID连续唯一、144字段完整。
- private/public存储、index、query和grant边界明确，`isPrivate`和关系不构成授权。
- 发布、更新、撤回、删除和旧版本使用不可变version/receipt，已访问事实只补偿不抹除。
- Visitor session/输入/反馈有TTL、ProcessingBasis、AI披露、限流、prompt injection与举报路径。
- default-off且外部门未关闭时最高`EXTERNAL_BLOCKED`，Owner文字核心完全独立。

## Verification Plan

- 对照Product Spec Stage3、Publication lifecycle、AccessGrant、Visitor policy和API/AuthZ章节。
- 结合独立源码审计校准当前无authority/public index事实及现有可复用UI/消息壳层。
- 检查9项/144字段、private/public负例、withdraw传播、Optional隔离和G0–G4。
- 运行Product V4 API/AuthZ、object/media、rights、migration、docs和diff gates。

## Risks

- `public`命名或布尔值容易让开发直接读private projection；任务必须以独立store/index为DoD。
- 撤回不能收回截图或外部副本，UI和receipt必须诚实披露。
- Visitor身份和未成年人/第三方内容政策尚需产品/法律决定，不能被技术默认值替代。

## Assumptions

- 本票据只写路线图，不建立公开URL或入口。
- 首版Stage3仅文字Visitor；公开声音/数字人是Voice Beta 2独立lane。
