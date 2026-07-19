# WI-S1-01-06 KBLite Compatibility Read Envelope

日期：2026-07-19

## 结论

`WI-S1-01-06` 的本轮小闭环完成：Owner Truth Projection 现在可以通过默认关闭的
QA-only read envelope 被 iOS 解析和隔离缓存，但旧 KBLite、公开 Archive、Context
Packet 与 Echo 都没有切换。

状态：`INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_SCOPED_EVIDENCE_PRESENT /
IOS_LOCAL_COMMITTED / G1_G3_G4_OPEN`。

## 实现

### 后端

- 增加隐藏的 `GET /v2/vaults/{vault_id}/kblite-compatibility/read-envelope`。
- 只能由已认证 Vault Owner 加 QA header 调用，feature 未开时保持 404。
- 合同版本为 `owner-truth-kblite-read-envelope-v1`；只有 `ready` Projection 才
  给出 `replace`、checkpoint、authority epoch、graph hash 和 facts。
- 仅 `knowledge + standard + confirmed` 的 `claim` 可以成为缓存 fact；敏感或
  不兼容记录只保留无正文过滤原因。
- 增加 route ownership/authentication 库存登记，当前总路由数从 90 更新为 91。

### iOS

- 新增 `OwnerTruthKBLiteCompatibilityReadEnvelope` 和 typed fact/citation 解析。
- 新增 `OwnerTruthKBLiteCompatibilityStore`，单独保存
  `owner_truth_kblite_compatibility_v1.json`，不会导入或写入 legacy
  `kb_graph_<userId>.json`。
- 缓存绑定 subject、vault、session、generation、generation ID、lease epoch、
  Projection epoch/checkpoint 与 SHA-256 graph hash。
- 任一身份变更、A -> B -> A、hash 损坏、非 ready 响应或解码失败都会删除缓存并
  fail closed。
- 新增 `DreamJourneyBackendClient` QA-only typed port；不增加公开按钮、页面或
  Echo 上下文调用。

## 验证

本地已通过：

```bash
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-kblite-compatibility-check.py
bash Scripts/QA/product-v4/run-ios-owner-truth-kblite-compatibility-gate.sh
```

该 gate 包含：静态边界检查、SwiftPM 22 项核心测试和 `generic/platform=iOS`
`build-for-testing`。新增测试覆盖 ready 解析、hash 篡改拒绝、A -> B -> A 缓存
隔离、non-ready discard 和损坏本地文件删除。

后端定向单测 68 项、Python compile 和 `git diff --check` 也已通过。

部署 G2 已完成：

- Backend `162afb0` 已在服务器 fast-forward 并重建 API 容器。
- `/ready` 返回 HTTP 200，database、schema、auth、incident 全部 ready。
- 容器内 `run-backend-owner-truth-postgres-smoke.sh` 通过，包含
  `kbliteCompatibilityReadEnvelope`、knowledge-only、content hash、non-ready
  discard、敏感字段不进入 graph 与 legacy isolation。
- 容器内 `run-backend-route-authentication-postgres-smoke.sh` 通过，
  `routeCount=91`、anonymous/user/machine principal 边界均符合合同。

## 非目标

- 不把 Projection 当作 legacy KBLite 的 Authority 或替换 legacy writer。
- 不把 compatibility facts 注入 `/context/build` 或 Echo。
- 不开放 QA launch argument，不增加 public UI。
- 不宣称真实设备、Provider 或发布验收已完成。

## 下一步

本轮 iOS 与后端已提交，后端已部署并完成 Owner Truth/route-auth Postgres smoke。
之后按路线进入 `WI-S1-01-07`，继续 Owner QA Context 与 typed Citation，仍保持
公开 release scope 不变。
