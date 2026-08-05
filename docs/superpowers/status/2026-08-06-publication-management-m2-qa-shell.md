# P2-S3b：发布管理 QA 壳层

日期：2026-08-06
范围：P2-S3b，仅限 M2 closed-beta 的内部 QA 读取界面。

## 已完成

1. 在既有“我的”页加入 `发布管理` QA 入口，仅在 Debug/UI-QA 且启动参数 `DJEnablePublicationManagementM2QA` 存在时显示。
2. 新页面仅读取后端已冻结的 owner publication 和 grant 摘要：公开预览、发布生命周期、授权状态、到期时间及剩余次数。
3. 客户端在请求和提交结果时均校验 AccountLease、vault ID 与固定 schema；不匹配、过期或读取失败会拒绝展示结果。
4. 数据仅保存在内存；不写缓存、不创建索引、不进入私人 Echo，也不包含访客身份、grant credential、私有 Source、Candidate、Memory 或 KBLite 内容。
5. 页面包含加载、空、失败和重试文本态；未新增第四 Tab、公开 URL 或深链。

## 验证证据

| 检查 | 结果 |
| --- | --- |
| `bash Scripts/QA/product-v4/run-ios-publication-management-scope-gate.sh` | 通过 |
| `bash Scripts/QA/product-v4/run-ios-publication-visitor-scope-gate.sh` | 通过 |
| `bash Scripts/QA/prd-stitch-ui/run-publication-visitor-public-entry-g1-check.sh` | 通过 |
| `xcodebuild test ... -only-testing:DreamJourneyTests/PublicationManagementAccessTests` | 5 项通过 |
| `bash Scripts/QA/prd-stitch-ui/run-publication-management-m2-smoke.sh` | 通过 |
| `xcodebuild build ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` | 通过 |

模拟器截图：

`tmp/visual-qa/prd-stitch-ui/publication-management-m2-smoke/20260806-041951/01-publication-management-m2.png`

## 发布边界

- 这是 default-off 的内部 QA 壳层，不构成公开 M2 Visitor 产品面。
- 发布管理失败不回退到私人 Echo，也不显示私有记忆内容。
- P2-S4 将处理撤回、争议和删除传播；在其完成前，不得将该 QA 入口公开。
