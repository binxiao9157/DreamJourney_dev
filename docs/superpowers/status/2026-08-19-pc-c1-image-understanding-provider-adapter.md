# PC-C1 图片理解 Provider Adapter 闭环

日期：2026-08-19  
状态：`COMPLETE_CODE_CLOSURE_WAITING_EXTERNAL_CONFIGURATION`  
所属 Work Item：`PC-C1 首版图片/文档理解`

## 完成内容

- 保留旧图片 OCR `{"text": ...}` 响应兼容，不要求 iOS 感知具体视觉 Provider。
- 新增严格的 `owner-truth-image-understanding-v1` 服务端合同，接收图片描述、OCR 文本以及人物、时间、地点候选。
- Provider 只接收用户明确同意后的私有图片字节、MIME 和媒体类型；不发送文件名、Owner、Vault、对象 URL 或客户端标识。
- 描述与 OCR 生成带 `image` locator、字符数和内容 hash 的私有 Source 证据片段。
- 人物、时间、地点统一标记 `evidenceMode=inferred`，经过 Owner Truth V2 ontology 和 `candidateFacetsHash` 校验后，才能生成待用户确认的 Candidate。
- 图片 Candidate 使用 `perspectiveType=inferred`、`epistemicStatus=inferred` 和单条确认模式；Provider 无法直接生成正式 Memory。
- 结构化响应字段缺失、未知字段、非法置信度、空结果、元数据篡改或 hash 不一致时失败关闭，不回退到响应中的旧 `text` 字段，也不生成空 Candidate。
- 普通文档、音频文本 Provider 和旧 OCR 文本路径保持兼容；没有结构化线索的既有结果 hash 不受新增字段影响。

## 验证

- Backend 定向合同、媒体 Worker 和 Candidate Worker：47 个测试通过。
- `scripts/run-backend-owner-truth-media-processing-gate.sh`：216 个媒体处理测试和 33 个业务消息投影测试通过。
- Python compile 与 `git diff --check`：通过。
- Backend 提交并推送：`f936181 feat: add reviewable image understanding contract`。
- 服务器从正式 Git 提交 `f936181bdc5d41ed3424f62a7333acfa8c88dc39` 重建 API 容器。
- 部署态 `/ready`：database、schema、auth、incident 全部 `ready`；migration head 保持 `0100`。
- 部署态 runtime capability smoke：通过；线上 `owner_truth_media_image_ocr_provider=disabled`，身份为 `disabledImageOCR/v1`，未伪造视觉能力。

## 未完成的外部 Gate

- 配置真实私有对象存储、SSE、最小权限凭据和删除回执。
- 配置内容安全扫描器并完成真实用户媒体链路验收。
- 选择并配置支持图片描述/OCR的视觉 Provider，完成真实人物、时间、地点质量和地域/保留策略验收。
- Provider 未配置前，公开运行态必须继续显示不可用/可重试，不得使用 mock 结果冒充成功。

## 后续交接

PC-C1 不再阻塞不依赖外部媒体配置的开发。连续执行进入 `PC-C2 正式记忆 Markdown 导出`；外部 Gate 配置完成后再回补 PC-C1 真实上传、扫描、视觉处理和删除的部署态 E2E。
