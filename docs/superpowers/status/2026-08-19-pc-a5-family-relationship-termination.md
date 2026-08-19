# PC-A5 家庭关系解除与数据处置验收

日期：2026-08-19
状态：`COMPLETE`
关联：FAM-001、FAM-003、SEC-001、PCQ-05
下一项：PC-B1 正式记忆总览与二次确认编辑

## 1. 完成范围

1. Owner 可以解除指定家庭关系，Member 可以退出自己已加入的家庭；两种操作都要求显式二次确认。
2. 操作只解除关系和关系派生授权，不删除 Owner、Member 或 FamilyMember 对应账户。
3. 服务端在同一事务内撤销 Relationship、ShareGrant-compatible access authority 和 Contribution Grant，并推进 relationship/grant epoch。
4. 未接受贡献立即变为 `withdrawn`、不再出现在双方待审核列表，并写入处置队列；已接受贡献生成的 Source 继续保留且维持来源审计。
5. Publication Grant 不随家庭关系解除而隐式撤销，必须由 Owner 在发布域另行操作。
6. iOS 在确认页列明访问授权、贡献授权、待审核贡献、角色切换及已发布分享的影响；成功后清理本地授权状态并触发知识和数字人上下文重算。

## 2. API 与数据合同

- `GET /family/relationships`
  - 只返回当前认证 Principal 作为 Owner 或 Member 参与的关系。
  - Member 退出不依赖其是否拥有 Contribution Grant。
- `POST /family/relationships/{relationshipId}/terminate`
  - 请求要求 `commandId`、`expectedEpoch`、`secondConfirmation=true` 和 `publicationGrantAction=preserve`。
  - 响应 schema：`family-relationship-termination-v1`。
  - 同一 commandId 幂等；相同关系的并发 Owner/Member 请求只执行一次撤权。
- migration `0098`
  - 新增 append-only `family_relationship_termination_receipts`。
  - 新增 `owner_truth.family_contribution_disposal_queue`。
  - 迁移为 additive，不删除已有账户、Source 或 PublicationVersion。

## 3. 版本与部署

- Backend 提交：`b20e22c`，已推送 `main` 并部署到 production-postgres。
- iOS 提交：`0bbf0df0`，已推送 `feature/prd-stitch-ui-adaptation`。
- 服务器 migration head：`0098`。
- API image：`sha256:c4becd0447c07c4edd25afd63b4f6332638a7f39568db818e4df8c8a533804d2`。
- 迁移前已验证备份 schema head `0097`；迁移后已验证备份 schema head `0098`。
- `/ready`：HTTP 200，database、schema、auth、incident 全部 ready。

## 4. 验证结果

### Backend

- `scripts/run-backend-family-relationship-termination-gate.sh`：25 项通过。
- `scripts/verify_backend.sh`：2,160 项主 unittest 及全部标准 Gate 通过。
- production-postgres `backend-family-relationship-termination-postgres-smoke.py`：通过。
- 并发证据：Owner/Member 同时解除时恰好一次 `terminated`、一次 `alreadyTerminated`，授权只撤销一次。
- 账户仍可登录、第三方不可解除、epoch 冲突、命令冲突、重复请求、待审核/已接受贡献和 Publication 保留均有覆盖。
- `py_compile`、FastAPI smoke、`git diff --check` 通过。

### iOS

- `profile-family-account-lifecycle-check.swift`：通过。
- `OwnerTruthContractsTests` 全套：222 项通过；新增 membership/termination 定向测试 2 项通过。
- generic iPhoneOS Debug build：通过。
- 构建报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-140905-iphoneos-generic-build/report.md`。
- 家庭/角色 release boundary 模拟器 UIQA：通过；本机 Bundle ID 固定为 `com.yxj.dreamjourney.app`，截图见 `artifacts/product-confirmed/20260819-pc-a5/PC-A5/uiqa-profile-release-boundary.png`。
- 本轮未做真机操作；解除按钮与二次确认使用现有家庭页设计体系，最终逐像素视觉仍遵循 UI-05 Gate。

## 5. 安全与回滚边界

- API 只接受关系参与者的用户 Session；machine token、其他账户和仅知道 relationshipId 的请求均不能执行。
- iOS 使用 AccountLease 与 generation 校验，账户切换后的旧响应不能写回当前账户。
- 回滚 API/入口不恢复已经撤销的 Relationship 或 Grant。数据恢复只能通过审计回执和独立授权重新建立，不能把旧 epoch 重新激活。
- migration `0098` 保留回执和处置队列；若需要代码回退，采用 forward-fix，禁止删除生产审计数据。

## 6. 交接

PC-A5 已关闭，Gate A 的工程和 production-postgres 条件已通过。下一项为 PC-B1：统一正式记忆列表、current + 3 历史版本及二次确认纠正。PC-A0 的真实短信 Provider 仍是独立外部 Gate，不阻塞 PC-B1。
