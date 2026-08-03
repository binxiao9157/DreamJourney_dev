# Round 3C3B 对象存储与媒体迁移方案

## Problem Definition

当前 Archive/Voice/TTS/视频等媒体存在设备路径、metadata、mock upload intent、base64响应或Provider临时URL，没有统一private object、checksum/scan/delete receipt。迁移若只改状态或URL，会把丢失/未验证/恶意文件错误标成云端可用，也可能在DB失败时留下孤儿或删除时继续通过缓存/签名URL访问。

## Proposed Solution

在Product Spec新增Object/Media migration章：

1. 编制文字、照片、音频、视频、文档、TimeLetter附件、Voice sample、GeneratedAudio、avatar、thumbnail/derived、export/evidence和Provider资产分类。
2. 定义private随机namespace、server-generated object key、signed PUT/GET、size/MIME/checksum、HEAD commit、quarantine/scan、encryption和region/retention合同。
3. 迁移先建metadata与source/object link，不凭local path/mockURL/base64/providerURL标verified。
4. 设备local-only文件仅在同一verified account、用户显式submit/restore时上传；服务器无法自动backfill设备文件。
5. 对服务器可访问旧对象执行copy/re-upload→checksum/scan→new reference shadow→read canary→reference cutover；DB失败/无引用由orphan reconciler清理。
6. 删除先撤销访问和signed GET，再按object version/cache/derivative/backup/provider receipt异步清理；partial如实披露。
7. 按O00–O11 waves迁移，旧mock/base64/永久URL最后退役。

## Acceptance Criteria

- 至少12类media/object有current state、target、migration、verification、delete/retention策略。
- upload intent/commit/HEAD/checksum/MIME/scan/authz/TTL/namespace规则完整。
- local-only/mock/missing/provider-temp明确不可升级verified。
- object DB/link/reference/read/delete/orphan/backups有cutover/rollback。
- processing/search/QA只读verified且purpose授权对象。
- signed GET每次重新AuthZ，Publication使用独立copy，不泄露private Source URL。
- 至少10个migration waves、15个upload/crash/scan/orphan/delete/permission场景。
- Evidence Matrix与静态门禁明确未实现/外部门。

## Verification Plan

- 静态门禁检查media目录、object lifecycle、waves、delete矩阵和场景。
- 对照当前Archive/Voice/TTS/video/upload-intent实现，确认每种legacy representation有明确去向。
- 独立reviewer攻击path注入、SSRF、MIME spoof、checksum、DB crash、orphan、signed URL、cross-vault、delete/backup。
- 运行全部V4门禁与`git diff --check`。
- 本轮不选择/接入真实对象存储、不上传用户文件；sandbox/performance/delete/region为路线图外部验收。

## Risks

- 大量媒体只在设备且可能已丢失，无法承诺迁移率。
- Provider临时试听/数字人素材可能受许可约束，不能复制到自有bucket。
- Backup/object version删除具有延迟和合同限制，不能承诺立即物理删除。
- 视频/文档处理成本和安全扫描Provider尚未确认。

## Assumptions

- Private Object Storage是后端port，具体云厂商由DR-026/031和成本评审决定。
- 文字Source可使用加密typed/versioned content，不强制对象化。
- Job/Outbox迁移由3C3A提供verify/scan/delete/reconcile执行基础。
