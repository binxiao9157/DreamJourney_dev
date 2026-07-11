# Task 18：P1 Knowledge Change Feed 稳定水位分页

## 目标

把当前一次性返回全部 `/kb/changes` 的实现升级为稳定水位分页，并让 iOS 在完整终页验证后才提交权威图谱、清理 pending 和发送本地 mutation。分页期间发生的本地知识写入必须通过 mutation version/CAS 保留，旧用户、旧 generation 和异常页不能污染当前知识库。

## 产品与兼容边界

- 旧客户端不传 `limit` 时继续获得原完整响应，不强制切换。
- 新客户端显式传 `limit`，首请求由后端固定 `targetRevision`；后续请求携带相同 target，只读取 `sinceRevision < revision <= targetRevision`。
- 分页游标使用 revision 水位，不使用不透明正文 cursor；URL 参数必须安全编码和严格校验。
- 每条 change 仍携带完整权威 graph，本轮不改变 change 内容格式或引入 delta replay。
- 中间页不持久化 iOS remote base、不清 pending、不写 KBLite、不发送 mutation/governance。
- 不持久化中间页；进程重启从已提交 base revision 重新拉取。
- 不改变公开 UI，不做真机、不做 change compaction；代码验收后按用户要求提交推送并部署后端。

## 后端合同

新分页请求：

```text
GET /kb/changes/{userId}?sinceRevision=10&limit=50&targetRevision=120
```

响应增量字段：

```json
{
  "userId": "...",
  "sinceRevision": 10,
  "currentRevision": 120,
  "targetRevision": 120,
  "nextSinceRevision": 60,
  "hasMore": true,
  "pageLimit": 50,
  "changes": []
}
```

- 首次没有 `targetRevision` 时固定为请求时 snapshot revision。
- `targetRevision` 必须非负且不高于当前 revision；`sinceRevision` 不得高于 target。
- `limit` 范围 1...100；未传 limit 保持 legacy 全量模式。
- Memory/Postgres 按 revision ASC、target 上界和 limit 查询。
- `hasMore` 由 `nextSinceRevision < targetRevision` 判定；非终页必须有进展。
- 账号/ownership 规则保持不变。

## iOS 合同

- 增加严格 `KnowledgeChangePage` 与 `KnowledgeChangeFeedReducer` 纯模型。
- Reducer 校验用户、稳定 target、revision 严格递增、页首连续、页尾/hasMore 一致、空页、最大页数和循环。
- 只保留最终权威 graph/revision，不累计全部 graph body。
- Coordinator 统一正常同步与 409 refresh 的分页拉取状态机，使用 `userId + generation + pullSessionId` 丢弃旧页。
- 终页完成后执行一次三方 merge；分页中 enqueue 的更新只设置 `needsResync`。
- KBLiteManager 暴露 graph snapshot mutation version，并用 CAS apply；版本变化时重新读取 local graph、重算 merge，有限重试，绝不覆盖分页期间新知识。
- Legacy 后端缺少分页字段时，只接受为单页终态，并继续兼容。

## 验收清单

- [x] 后端分页参数、稳定 target、水位字段与 legacy 兼容。
- [x] Memory/Postgres bounded query 与边界测试。
- [x] 后端分页 smoke 覆盖三页、并发新增、异常参数和用户隔离。
- [x] iOS typed page/reducer 与异常页纯模型 smoke。
- [x] KBLite graph mutation version/CAS 与并发写保护 smoke。
- [x] Coordinator 统一分页 pull，终页前无副作用。
- [x] 409 refresh 复用分页状态机且只重试一次。
- [x] generation/user/pull session 失效保护。
- [x] Release regression 与 QA package 接入。
- [x] 后端全量、跨仓 gate、Simulator/generic iPhoneOS build 通过。
- [x] 分仓提交推送；后端部署并完成真实 Postgres smoke；不做真机。

## 非目标

- Change feed compaction、保留策略或 snapshot fallback。
- 增量 graph patch replay。
- 中间页持久化或崩溃恢复 journal。
- 公开知识治理 UI、真机、部署。

## 成功标准

- 大型 change feed 可按固定 target 多页读取，不重复、不遗漏、不追逐请求后的新 revision。
- iOS 只有终页完成后才推进 base 和发送 mutation。
- 分页期间产生的本地知识不会被终页 apply 覆盖。
- 旧后端、旧客户端和现有治理/operation receipt 合同保持兼容。
