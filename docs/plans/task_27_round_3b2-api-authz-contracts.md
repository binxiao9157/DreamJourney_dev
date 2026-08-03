# Round 3B2：Identity、AuthZ 与 /v2 API 合同

## Problem

当前 API 广泛使用无类型字典，登录/恢复缺强身份证明，system token 和 anonymous fail-open 可绕过 owner policy。需要定义 typed `/v2` command/query、principal、六类 authorization object、错误/幂等/并发/分页和 legacy compatibility。

## Success Criteria

- 定义 user、service/machine、operator/break-glass principal 和 fail-closed authentication。
- OTP/identity binding、access/refresh session、revoke/restore 和 service credential 合同明确。
- ProcessingBasis/Consent、AccessGrant、WorkAuthorization、DataRightsAuthorization、RetentionHold 的决策公式可执行。
- `/v2` 覆盖 Identity、Source、Candidate/Memory、Conversation、DataRights 的核心 command/query。
- commandId/expectedVersion/error/receipt/cursor/cancel 规则明确，跨 owner 统一拒绝且不泄漏存在性。
- 旧 58 route 仅作为 compatibility facade，客户端 system/provider secret 退役路径明确。
- 该问题属于 T023，因为它负责安全地暴露数据 authority。
