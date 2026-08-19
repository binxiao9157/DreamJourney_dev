# PC-D2 Visitor 正式产品闭环

日期：2026-08-19  
状态：`COMPLETE_WITH_EXTERNAL_GATES`

## 1. 实现范围

- Backend `836655d`：新增正式受邀列表和注册账户无凭证准入；产品响应不返回原始 ShareGrant credential、Owner 私有主体 ID 或内部安全调用余额。
- Backend `6d44594`：部署态 smoke 按 `grantId` 精确核对多条授权，消除列表排序造成的误报。
- iOS `17396b9d`：在普通“我的”页面提供“受邀回忆”入口，展示当前账户有效邀请并打开独立 PublicProjection 页面。
- Visitor 只能读取已发布公开副本；授权撤销、过期、发布暂停、账户切换、跨账户或跨 Vault 均失败关闭。
- 页面支持文字查询和普通实时语音播报；明确不创建腾讯数字人 Session，不使用声音复刻 profile，语音请求固定 `voiceProfileId=nil`。
- Family 关系不会自动创建 ShareGrant，产品界面不显示内部限流或成本余额。

## 2. 验证结果

| Gate | 结果 |
|---|---|
| Backend Publication 测试 | 156 项通过 |
| Backend Python compile | 通过 |
| Backend diff check | 通过 |
| iOS Publication XCTest | 24 项通过 |
| iOS 发布态静态 Gate | 通过 |
| iOS `git diff --check` | 通过 |
| generic iPhoneOS build | 通过 |
| 模拟器 Visitor UIQA | 通过 |
| production `/ready` | database/schema/auth/incident 均 ready |
| production PostgreSQL Visitor smoke | 邀请、正式准入、PublicProjection、CAS、撤权和暂停通过 |
| production 路由认证 smoke | 237 条路由通过 |

模拟器截图：

`tmp/visual-qa/prd-stitch-ui/publication-lifecycle-m2-smoke/20260819-222449/01-publication-lifecycle-m2.png`

通用设备构建报告：

`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-pc-d2-visitor-product/report.md`

## 3. 部署记录

- 部署前 Backend：`9a6d85b`
- 功能提交：`836655d`
- 当前服务器与 `origin/main`：`6d44594`
- PostgreSQL migration head：`0104`
- 本轮无 schema 迁移；迁移 dry-run、apply 和 verify 均保持 `0104` ready。

## 4. 外部 Gate

真实用户公开放量仍需完成发布/Visitor 法律、安全和数据地域审批。该 Gate 不影响本轮代码、默认关闭部署和 synthetic/部署态验收结论，也不得被描述为已完成真实用户上线。

## 5. 下一交接点

进入 `PC-E1`：统一稳定 Feature 命名和 Release Policy，移除产品范围对 M1-M4、QA-only、Closed Beta 阶段语义的依赖，同时保留期限明确的旧客户端兼容映射和失败关闭运行 Gate。
