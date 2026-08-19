# PC-C1 Markdown 文档处理闭环

日期：2026-08-19
状态：`COMPLETE_SUB_CLOSURE`
所属 Work Item：`PC-C1 首版图片/文档理解`

## 完成内容

- 后端文档上传合同新增 `text/markdown`，并继续拒绝声明类型与实际魔数不一致的伪装文件。
- Markdown 与 TXT 共用受资源限制的 UTF-8 隔离解析路径，输出版本化 processor 身份、结果 hash 和按行来源片段。
- Markdown 处理成功后沿用既有 `Source -> ExtractionResult -> Candidate -> Owner 确认` 链路，不直接生成正式记忆。
- 空内容、损坏 UTF-8、超限、删除竞争、重复任务和跨账号行为继续沿用现有 fail-closed 处理。
- iOS 文档选择器开放 `.txt/.md/.markdown/.pdf/.docx`，`.md/.markdown` 映射为 `text/markdown`。
- 文档使用服务端本地隔离 parser，不再弹出或发送外部 Provider 处理同意；图片仍保留用途明确的外部 AI 分析同意。

## 修复的问题

此前 iOS 将文档归类为可外部处理，并可能提交 `allowExternalProcessing=true`；后端只允许图片或音频携带该字段，因此用户选择“允许文档解析”会被上传意图接口拒绝。当前两端合同已统一：文档始终由服务端隔离 parser 处理，外部处理字段为 `false`。

## 验证

- Backend targeted Markdown tests：通过。
- `scripts/run-backend-owner-truth-media-processing-gate.sh`：245 个测试通过。
- iOS `OwnerTruthContractsTests.testOwnerTruthMediaCreationPolicyRequiresExplicitProcessingChoice`：通过。
- `product-confirmed-first-release-scope-check.py`：通过。
- `product-v4-ios-owner-media-unified-creation-check.py`：通过。
- `git diff --check`：两仓库通过。

## PC-C1 剩余内容

- 图片 OCR/描述 Provider Adapter 需要输出带来源的人物、时间、地点候选。
- 图片 Provider 缺失或失败时必须保留 Source，只显示不可用/可重试，不生成空 Candidate。
- 腾讯 COS、内容安全扫描器、Worker 和图片 Provider 的真实部署态 E2E 仍需外部配置。
- 音频和视频普通入口、上传与处理继续保持产品关闭。
