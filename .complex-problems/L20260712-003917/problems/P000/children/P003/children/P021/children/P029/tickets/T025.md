# Round 3B2 Identity、AuthZ 与 /v2 API 合同方案

## Problem Definition

当前手机号即可创建/恢复账号、认证配置缺省 fail-open、客户端兼容 system token 可绕过 owner policy，业务请求以无类型字典进入 JSONB。需要定义不依赖供应商选择的强身份流程、user/service/operator principal、可执行授权公式和 typed `/v2` contract，同时保留旧客户端渐进兼容。

## Proposed Solution

1. Identity：challenge/verify 模式抽象 SMS OTP、Sign in with Apple 等强身份证明；密码仅可作为已验证账号的次级凭据。
2. Session：opaque access/refresh、rotation、reuse detection、device/session list、logout/revoke-all、删除/恢复时全撤销。
3. Principal：user、visitor、service/machine、operator、break-glass 分离；iOS 永不获得 service/system/provider credential。
4. AuthZ：定义 owner、delegated、machine work、data rights、visitor 和 operator 判定公式，正交使用 basis/consent/grant/work/data-rights/hold。
5. `/v2`：使用 typed camelCase DTO、strict unknown-field rejection、commandId/expectedVersion/receipt、cursor、problem+json error、correlation 和 capability contract。
6. 核心 route 覆盖 Identity、Source、Candidate/Memory、Conversation、DataRights；legacy 58 route 做 facade/shadow/read-only 迁移，不随机生成新 authority command ID。

## Acceptance Criteria

- 身份 challenge、session、principal、credential 生命周期和 fail-closed 启动明确。
- owner/delegated/machine/data-rights/visitor/operator 六类 AuthZ 公式和拒绝行为明确。
- 至少 20 个 `/v2` command/query endpoint 有方法、路径、request/response/权限/幂等语义。
- 错误、分页、并发、取消、版本、兼容和 capability 契约明确。
- 当前三个 auth/provider blocker 有明确退役路径。

## Verification Plan

1. 走查注册/登录/refresh reuse/logout/revoke-all/delete/restore。
2. 走查 Owner、家庭 delegated、machine job、rights deletion、Visitor share、Operator metadata。
3. 走查重复 command、version conflict、跨 vault、资源枚举、未知字段、rate limit。
4. 静态检查 endpoint/公式/error/compatibility 数量。

## Risks

- 提前选定 SMS/Apple 供应商；合同只固定证明等级，不固定商业 provider。
- machine principal 重新成为通用 system token；必须同时需要 scoped work authorization。
- 旧客户端兼容过久，形成双 authority。

## Assumptions

- 首发身份方式仍需 DR-023 产品/安全确认；架构支持至少一个强证明 provider。
- 本轮不实现 OTP provider 或修改现有 route。
