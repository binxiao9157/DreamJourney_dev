# PC-A1 测试账号角色与权限验收

日期：2026-08-18
状态：`COMPLETE`
关联：GAP-01、AUTH-003、FAM-001、OPS-001、SEC-001
下一项：PC-A2 Owner Truth V2 facets

## 1. 完成范围

1. 测试白名单的 OTP 登录资格与产品功能权限完全分离；新记录默认 `testRole=null`、`featureEntitlements=[]`。
2. 后端支持 `superTest/ownerTest/familyTest/operatorTest`、显式 Feature entitlement、只作测试引用的 scenario binding、递增 revision、snapshot ID 和脱敏更新审计。
3. Access/Refresh Session 只保存最小 revision/snapshot 标识；每次请求和 refresh 都复核当前服务端 revision。
4. 管理员修改权限后撤销该 Subject 的全部活动 Session；旧 Access/Refresh 均不能继续使用。
5. Release Policy 只允许账号显式拥有的 Feature；角色本身不隐式授权，scenario binding 不构成 Owner、Family 或 Visitor Grant。
6. `superTest/familyTest` 仍经过现有 Owner/Grant 权限层，不能读取任意 `vaultId` 或其他用户私人档案。
7. 内部后台支持角色、Feature 多选和场景 JSON；普通 iOS App 不包含管理路由、字段或用户可见入口。

## 2. 版本与部署

- Backend 功能提交：`d08c537`。
- Backend 迁移顺序修复及部署提交：`aae0b04`。
- iOS 普通 App 管理面静态 Gate：`9cc2196e`。
- 服务器源码：`aae0b04186f4d8ecde760e849159eae136c1721d`，工作区 clean。
- API 镜像：`sha256:1796f2c533f9871198de2e5d94c30de4c5dcb205e9fd9d66f80d043f7024faa2`。
- production-postgres migration head：`0095`。

## 3. 验证结果

### Backend

- 最终完整 `scripts/verify_backend.sh` 通过：2132 项主 unittest 及全部标准 Gate 成功。
- PC-A1/权限专项：170 项通过，覆盖角色矩阵、默认空权限、输入边界、旧 Session 失效、super/family 越权负向、有效 Family/Visitor Grant 负向和审计脱敏。
- migration `0095` dry-run/apply/verify 通过；首次 apply 暴露的旧 contract constraint 顺序问题已修复，失败事务未改变生产数据。
- 隔离 PostgreSQL smoke 通过：默认 entitlement 为空、revision `1 -> 2`、旧 Session 失效、原始凭据不落库，临时数据库已删除。
- 线上 route authentication smoke 通过，217 条路由全部分类；匿名管理写入返回 401。
- `/ready` 的 database/schema/auth/incident 均为 ready；迁移前后备份服务均成功。

### iOS

- `test-account-authorization-surface-check.py` 扫描 139 个 Swift 文件通过，管理面仅存在于后端内部页面。
- `release-qa-package-check.swift` 通过。
- generic iPhoneOS Debug build 通过，Bundle ID 覆盖为 `com.yxj.dreamjourney.app`，Team 为 `2BTR77V3R8`。
- 本 Work Item 不修改产品 UI，不需要模拟器 UIQA 或真机验收。

## 4. 证据与安全边界

- 证据目录：`artifacts/product-confirmed/20260818-pc-a1/PC-A1/`。
- 证据包不包含验证码、手机号、Access/Refresh Token、管理员账号、Provider 凭据、DSN 或业务数据。
- `scenarioBindings` 仅供合成场景定位，不能代替真实 Relationship、Contribution Grant 或 ShareGrant。
- 本次未修改任何现有测试账号角色或 Feature；部署 smoke 使用一次性 PostgreSQL 数据库。

## 5. 回滚与交接

迁移为 additive，不执行 down migration。若管理写入异常，关闭管理页面/路由并 forward-fix；已有 revision 和审计记录保留。旧 Session 已撤销后不得恢复。下一项按主计划进入 `PC-A2`，不得将 V2 facets 提前开放给未完成 PC-A3 隔离验证的 Family/Visitor。
