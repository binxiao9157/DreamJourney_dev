# 将公开副本、声音/数字人与组合迁移拆成三个独立可停止 Lane

## Problem Definition

Publication、Voice/DH和Composite Migration分别承担公开访问、高敏外部Provider和跨域cutover风险。当前工程已有分享/家庭/声音/数字人原型、Provider适配和大量迁移runbook，但任何一项都不能因“代码存在”直接进入公开或生产，也不能成为Owner文字核心的hard dependency。

## Proposed Solution

1. 将Round4D拆为三个互不替代的工作包：
   - `WP-S3-01 Publication`：Owner显式发布独立versioned snapshot，Public Index/Visitor grant物理或逻辑隔离于private Projection。
   - `WP-V0-01 Voice/DH Governance`：purpose/consent、sample/profile/generated audio、credential broker、Provider receipt、quality/真机、delete/exit完整闭环。
   - `WP-MIG-01 Composite Migration Drills`：编排既有W/I/P/Q/O/V工作面和C00–C11证据，不拥有业务状态或另建runner。
2. 每包建立连续原子Work Item并填满16字段；外部门缺失时最高`INTERNAL_READY/EXTERNAL_BLOCKED`。
3. Publication default-off，绝不通过查询过滤直接暴露private Projection；撤回先停止访问，再传播Public Index/CDN/cache。
4. Voice/DH default-off且高敏数据只发给有purpose/consent/region/retention/delete合同的单一Provider；默认音色、mock、local lease、配置存在或安装成功均不能替代真实质量/真机证据。
5. Migration以C00 inventory和真实backup/isolated restore开始，每个cohort有go/pause/no-go、authority epoch和retirement manifest；已确认MemoryVersion、已投递Inbox、Provider accepted和物理删除不可被普通rollback抹除。
6. 三个lane可暂停、回滚或长期不发布，Owner text core仍按Round4C完成路径运行。

## Acceptance Criteria

- 三个package各有稳定Work Item、16字段、独立release policy、G0–G4与明确non-goals。
- Publication覆盖snapshot/version/grant/Public Index/Visitor/AuthZ/revoke/delete/citation，private Projection永不成为公共索引。
- Voice/DH覆盖consent/purpose/profile/sample/training/TTS/generated audio/DH session/audio owner/provider receipt/quality/delete/exit和真机边界。
- MIG覆盖C00–C11、W/I/P/Q/O/V/C evidence、restore/replay、go/no-go、cohort、contract/revoke、retirement和不可逆compensation。
- 每包当前实现与目标事实分开，default-off且不阻断Owner核心。
- 产品、Privacy/Legal、Provider、Finance、Operations和真机门均不能由静态检查关闭。

## Verification Plan

1. 对照Product Spec Publication/Visitor、Voice/DH、W/I/P/Q/O/V/C和Round3评审响应。
2. 独立审计当前iOS/backend/share/family/voice/DH/provider/deploy/QA路径，校准现有能力与缺口。
3. 机器检查ID、16字段、独立lane、default-off、private/public隔离、不可逆rollback和外部门。
4. 运行现有Provider/Object/Job/Migration/Product V4检查与`git diff --check`。
5. Round4E全量追踪，Round5复审隐私、过度设计、Provider锁定和可执行性。

## Risks

- “公开给家人”和“家庭成员已有读取”容易混淆；Publication必须以snapshot+grant定义，不沿用private owner route。
- Voice/DH跨火山/腾讯存在音频、计费和删除事实；必须以receipt/quality gate处理，不以UI状态代替。
- Composite Migration已有大量文档，若再建runner会分裂Authority；本包只产生组合decision/evidence。

## Assumptions

- 本轮只完善路线图，不公开入口、不调用Provider、不部署或真机测试。
- Family/Care/TimeLetter仍不自动升级成新公开package；需要产品决策时由Decision Register管理。
- 当前基线继续是iOS `8a1922b`与backend `4c0538b`，任何代码漂移需重跑证据检查。
