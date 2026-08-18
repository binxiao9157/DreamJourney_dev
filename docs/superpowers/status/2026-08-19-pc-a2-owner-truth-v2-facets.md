# PC-A2 Owner Truth V2 facets 验收

日期：2026-08-19
状态：`COMPLETE`
关联：GAP-02、MEM-001、MEM-003、MEM-004
下一项：PC-A3 Family/Visitor V4 权限路由

## 1. 完成范围

1. 后端新增 `owner-truth-v2`，覆盖 people、time、places、relationships、emotions、values、personality 和总体 confidence。
2. Candidate 提取、DeepSeek 整理、Owner 人工纠正与 MemoryVersion 激活均保留 V2 facets；AI 线索必须标记 `evidenceMode=inferred`。
3. 关系 facet 仅是描述性证据，不参与 Owner、Family、Visitor 或 Grant 权限判断。
4. MemoryProjection 和私有 SearchDocument 持久化 schema version；只将 allowlist facet `value` 规范化到 `structured_terms`。
5. V1 继续可读且不伪造 facets；未知 schema 进入 quarantine，不能进入正式投影。
6. iOS 待确认详情、纠正编辑和正式记忆历史支持 V2 facets，并区分本人表达、系统推断、V1 未提取、非法数据和未知 schema。

## 2. 版本与部署

- Backend 功能提交：`6965dd4a5d3734abd834b753ea6d98dd0e7fe176`。
- Backend 部署 smoke 修复：`3a7f5ba9`、`b964e0c5e76738f3dab92706956791745308c46c`。
- iOS 提交：`4325fcd2be2518308009d13c01c3f4ccaab06c7b`。
- 服务器源码：`b964e0c5e76738f3dab92706956791745308c46c`，工作区 clean。
- API 镜像：`sha256:eebafa4607a2af64eaba02cf906d74805e69de9dd33d45821535cc150b03929f`。
- production-postgres migration head：`0096`。
- Candidate extraction / Memory projection Worker：均为 ready、running。

## 3. 验证结果

### Backend

- `scripts/verify_backend.sh` 全量通过：2139 项主 unittest 及全部标准 Gate 成功。
- schema 正负样本、V1/V2 兼容、未知 schema quarantine、inferred 标识、人工纠正和不可变 MemoryVersion 测试通过。
- migration `0096` dry-run、apply、verify 通过；迁移前后加密备份均成功。
- production-postgres 隔离 smoke 通过：V1 可读、V2 facets 可检索、跨 Owner 拒绝、投影 digest fail-closed、subject/grant 扩展字段不入索引。
- `/ready` 的 database、schema、auth、incident 均为 ready。

### iOS

- `OwnerTruthContractsTests`：221/221 通过。
- Product V4 typed client 静态检查和 Swift parse 通过。
- Candidate inbox UIQA 通过，`structuredFacetsVisible=true`；详情截图无重叠，显示“本人表达/系统推断”和 confidence。
- generic iPhoneOS Debug build 通过，Bundle ID 为 `com.yxj.dreamjourney.app`。

截图：

- `tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke/20260819-pc-a2-v2-facets/01-owner-truth-candidate-inbox.png`
- `tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke/20260819-pc-a2-v2-facets/02-owner-truth-candidate-structured-detail.png`

## 4. 安全与兼容边界

- facets 不构成身份、亲属关系或授权事实；PC-A3 完成前不得向 Family/Visitor 暴露私人 V2 facets。
- V1 不自动升级或补空 facets，避免把“未提取”误报为“已分析无结果”。
- iOS 的原始 JSON transport 保留未知扩展字段，但未知 schema 不展示为有效正式记忆。
- 搜索响应只返回 value-free citation、hash 和命中元数据，不返回私有正文、查询词或内部 search text。
- 证据包不保存 Token、手机号、DSN、Provider 凭据或真实业务 payload。

## 5. 回滚与交接

`0096` 为 additive migration，不执行生产 down migration。若 V2 写入或索引出现异常，停止新 V2 writer/Worker 并 forward-fix；保留已写入的不可变 MemoryVersion 和审计证据。旧 API 可忽略新增 schema/index 列，但不得把 V2 强制降写为 V1。下一项进入 PC-A3，先关闭 Family/Visitor 私人域隔离再继续公开与共享能力。
