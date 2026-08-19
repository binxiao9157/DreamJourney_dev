# PC-E1 稳定 Feature 命名与 Release Policy

日期：2026-08-19
状态：`COMPLETE_WITH_COMPATIBILITY_WINDOW`
下一交接点：`PC-E2 关闭能力零调用与全量回归`

## 完成范围

- 产品与后端统一使用 `publication`、`publicationGrantManagement`、`publicationVisitor`。
- 发布内容、Owner Grant 管理和 Visitor 访问拥有独立服务端决策，不再共用含混的 `visitorAccess` 权限键。
- 旧客户端名称仅由后端兼容层映射，兼容截止时间固定为 2026-11-30；iOS 不保留第二套映射或权限规则。
- `releaseStage` 与 `defaultClosedStages` 只保留为旧客户端元数据，`defaultClosedStageEffectsEnforced=false`；默认关闭由显式稳定 Feature 集合执行。
- iOS 发布能力为非持久化、服务端策略管理能力。本地设置最多发起一次受控请求，不能覆盖过期、紧急关闭、能力缺失或服务端拒绝。
- 产品态类名、运行日志、错误码和发布服务说明已移除 M2/Closed Beta 语义；历史 UIQA launch arg 和 smoke 名称继续保留，避免破坏既有自动化。

## 兼容边界

| 旧名称 | 稳定名称 | 说明 |
|---|---|---|
| `publicationManagementM2` | `publication` | Owner 发布能力 |
| `publicationGrantManagementM2` | `publicationGrantManagement` | Owner 授权管理 |
| `publicationVisitorM2` | `publicationVisitor` | Visitor 读取与查询 |
| `visitorAccess` | 按 audience 映射 | Owner 映射到 Grant 管理，Visitor 映射到 Visitor；不生成新权限规则 |

旧名称兼容在 2026-11-30 后应结合客户端版本分布和服务端调用观测执行删除，不应无期限保留。

## 提交与部署

- iOS：`6a49ae44950295f24804d8b6fff6c0d9b30d6019`
- Backend 功能：`0c05acf057f3befb412571c7099a7a62c8c0db8c`
- Backend 部署 smoke：`9b43a722eed559d023e82dcb99306ab4bcf27356`
- 服务器仓库与 API 镜像：`9b43a72`
- PostgreSQL migration head：`0104`

## 验证结果

- Backend Release Policy、正式发布路由和路由认证定向测试：66 项通过。
- Backend Publication 全域测试：156 项通过。
- Backend Python compileall 与两仓库 `git diff --check`：通过。
- iOS 发布/Visitor/Lifecycle 定向 XCTest：27 项通过，0 failure。
- iOS 发布静态 Gate、Release Policy cache contract/model smoke：通过。
- generic iPhoneOS build：通过。
- 模拟器 Publication lifecycle UIQA：通过；受邀回忆页面保持三 Tab 结构，普通语音不接数字人或复刻音色。
- production readiness：database/schema/auth/incident 均为 ready。
- production PostgreSQL Publication Visitor smoke：通过。
- production 路由认证：237 条路由通过。
- stable Feature deployed smoke：新名称、旧别名等价、兼容截止日、未知 Feature 默认拒绝和阶段元数据不参与授权均通过。

模拟器截图：

`tmp/visual-qa/prd-stitch-ui/publication-lifecycle-m2-smoke/20260819-pc-e1-stable-feature-policy/01-publication-lifecycle-m2.png`

generic iPhoneOS 报告：

`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-pc-e1-stable-feature-policy-final/report.md`

## 说明

旧的 `backend-release-policy-command-deployed-smoke.py` 使用机器 token 调用用户业务写路由，现被更严格的 Route Authentication 在 Release Policy 前正确拒绝。PC-E1 使用新稳定 Feature deployed smoke 验证策略合同；该旧脚本后续应在 PC-E2 回归清单中迁移到合法用户 Principal，而不能降低路由认证要求。

## 剩余项

- PC-E2 验证产品关闭能力零创建、零续约、零调度，并执行最终非真机全量回归。
- 旧 Feature 兼容映射到期前采集脱敏调用观测并制定删除提交。
- 真实短信、APNs、COS、内容安全扫描器、视觉 Provider、发布法律/安全和真机证据继续作为独立外部 Gate。
