# M0-B 引导推荐展示边界 G0

日期：2026-07-30

## 本轮完成

- 后端新增受登录会话、Vault 范围和独立 ReleasePolicy 保护的
  `GET /v2/vaults/{vault_id}/guided-recommendations`。
- 接口最多返回两条可展示提示，字段严格限定为 `slot`、`label`、`question`；
  不返回候选、证据引用、reason code、知识维度、策略版本或记忆正文。
- iOS 使用严格解码和 `AccountLease` 双重校验；账号、Vault 或 Authority epoch
  在请求期间变化时，旧结果不会进入界面。
- 展示仅复用现有“今天想聊点什么？”自然输入 Sheet：点击提示只预填文本，仍由用户主动发送。
  没有修改全屏 Echo 的视觉结构或导航。

## 默认发布边界

`echoGuidedRecommendations` 同时受 iOS feature flag 与后端 ReleasePolicy 约束：

1. iOS 将它列为 non-persistent feature，默认关闭。
2. 后端 closed-pilot 策略默认拒绝该路由，QA header 不能绕过。
3. 任一侧未显式放行时，不发请求、不显示入口；因此本轮不是公开功能发布。

## 验证

- 后端聚焦合约/认证/运行时测试：105 passed。
- 后端 `scripts/verify_backend.sh`：通过，含 FastAPI smoke、静态 Gate、编译和 diff 检查。
- iOS `OwnerTruthContractsTests`：93 passed（含严格字段、默认关闭、当前 lease 和 stale-result 测试）。
- iOS `generic/platform=iOS` Debug build：通过。
- 路由认证库存已从 133 更新到 134，线上 Postgres smoke 的显式期望值同步更新。

## 未声明完成

- 未部署后端、未修改服务器策略、未开启公开 release。
- 未新增推荐算法、持久化反馈、人生地图、语义搜索或真实用户评测。
- 未执行真实设备、Provider 或生产 Postgres 验收。

## 后续 Gate

公开放行前必须先完成 M0-B 的真实 scoped projection、持久化 replay、推荐负向语料与产品
ReleasePolicy 决策；仅靠本轮 G0 合约不能开启入口。
