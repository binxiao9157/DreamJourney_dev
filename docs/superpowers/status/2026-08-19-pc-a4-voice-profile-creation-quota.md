# PC-A4 音色独立授权与累计创建上限验收

日期：2026-08-19
状态：`COMPLETE_WITH_EXTERNAL_GATE`
关联：VOICE-001、SEC-001、PCQ-03
下一项：PC-A5 家庭关系解除与数据处置

## 1. 完成范围

1. Backend 以认证声音主体为维度维护累计创建次数，固定上限为 5 次。
2. 每次新 profile 由稳定 `commandId` 原子预留一次创建回执；重复命令幂等返回，不重复训练或计数。
3. 参数、样本和授权校验失败不计数；服务端已受理后即使 Provider 训练失败也计数，删除、禁用或撤销不返还。
4. PostgreSQL 使用主体级 advisory transaction lock、配额行锁和唯一约束，阻止并发绕过上限。
5. 家庭关系和 `family` scope 不能替代声音主体本人授权，家人声音仍需独立主体授权合同。
6. iOS 使用 typed quota contract 展示授权范围、已创建次数和剩余次数；到达上限后隐藏新建动作并显示稳定原因，既有失败 profile 的同代重试不创建新次数。
7. 已接受 profile 的试听、TTS 和 Echo binding 不查询创建配额，因此达到上限不影响既有音色使用。

## 2. API 与数据合同

- `POST /voice/profiles`
  - 新建请求携带稳定 `commandId`。
  - 响应包含 `profile` 和 `creationQuota`。
  - 重复请求返回 `status=deduplicated`。
  - 第 6 次返回 HTTP 409，reason code 为 `voice_profile_creation_limit_reached`。
- `GET /voice/profiles/{userId}`
  - 返回 `profiles` 和同一服务端权威 `creationQuota`。
- 配额 schema：`voice-profile-creation-quota-v1`。
- 回执 schema：`voice-profile-creation-receipt-v1`。
- migration `0097`：新增 `voice_profile_creation_quotas` 和 `voice_profile_creation_commands`，对历史 profile 做兼容回填；迁移为 additive，不保存 Provider 凭据。

## 3. 版本与部署

- Backend 提交：`080e9b8`。
- iOS 提交：`e52267f9`。
- 服务器源码：`080e9b8`，migration head `0097`。
- 迁移前已生成 root-only PostgreSQL 备份：`/var/backups/dreamjourney/postgres/pre-migration/pre-0097-20260819T053109Z.dump`。
- `/ready`：HTTP 200，database、schema、auth、incident 全部 ready。

## 4. 验证结果

### Backend

- `scripts/run-backend-voice-profile-creation-quota-gate.sh`：21/21 通过。
- `scripts/verify_backend.sh`：2,154 项主 unittest 及全部标准 Gate 通过。
- 部署态 `scripts/run-backend-voice-profile-creation-quota-postgres-smoke.sh`：通过。
- Postgres 证据：10 个并发命令恰好 5 个 accepted、5 个 limited；重复命令幂等；`creationCount=5`、`remainingCount=0`、`deletionRefund=false`。
- 非法 WAV、家庭 scope、Provider 失败、删除不返还、迁移回填和旧生命周期回归均通过。
- `git diff --check`、py_compile、FastAPI smoke 通过。

### iOS

- `voice-clone-creation-quota-check.swift`：通过。
- `voice-clone-shell-contract-check.swift`：通过。
- `voice-clone-backend-contract-check.swift`：通过。
- `release-qa-package-check.swift`：通过。
- generic iPhoneOS Debug build：通过；Bundle ID `com.yxj.dreamjourney.app`，Team `2BTR77V3R8`。
- 构建报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-132308-iphoneos-generic-build/report.md`。

## 5. 安全与兼容边界

- iOS 不保存或展示火山 Provider 凭据、speaker slot 或原始 Provider 错误。
- 旧客户端在具有已签名 sample authorization receipt 时由后端派生稳定 legacy command；当前客户端始终显式发送 `commandId`。
- 历史 profile 在 migration 0097 中计入累计次数；历史数量超过 5 时只阻止新建，不破坏既有 profile 使用。
- Provider slot 容量不足发生在创建受理前，不消耗次数；Provider 已接收后的失败按已创建计数。

## 6. 外部 Gate 与交接

强身份/活体 Provider 和真实声音 Provider 的训练、删除回执仍属于外部配置与生产验收，不用 fake 结果冒充完成。本轮代码合同、部署态 PostgreSQL 并发限制和 iOS 消费已关闭，后续直接进入 PC-A5：家庭退出/解除、Grant 撤销和贡献处置。
