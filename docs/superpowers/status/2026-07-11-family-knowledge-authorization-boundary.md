# 家庭关系授权与知识候选隔离

日期：2026-07-11  
分支：`feature/prd-stitch-ui-adaptation`  
状态：非真机实现与全量回归完成，等待最终提交。

## 问题

旧实现把对话/图片提取到的 `KBPerson` 自动转成默认 `active + accepted` 家庭成员；FamilyRepository 没有账号 generation，legacy JSON、启动 mock、迟到后端响应和本地 override 可能跨账号残留。Echo relation 文本和持久化 context 也没有统一复核 accepted member；整库 JSON 分享与通用 sync 只依赖自报身份/privacy scope。

这与 PRD/canonical 架构的核心规则冲突：知识人物只能是候选，家庭关系必须来自手机号邀请、接受状态和后端授权合同。

## 已实现合同

### 家庭关系 authority

- `FamilyRelationshipAuthorizationPolicy` 统一验证 owner、authority source、access/invitation status。
- 生产只接受当前 owner 的 `backendInvitation + active + accepted`。
- initializer、legacy decoder、knowledge candidate、本地失败尝试和 QA fixture 在生产默认拒绝。
- 后端 FamilyMember parser 绑定 `ownerUserId/userId`，不再把缺状态对象静默提升权限。

### 账号与候选生命周期

- FamilyRepository 使用 active owner + generation；登录、切换、退出清空旧成员/候选。
- refresh/invite 的迟到响应被 generation 拒绝；后端列表按 owner/source 校验后权威替换。
- KBPerson 只进入 `FamilyRelationshipCandidate`，不进入家庭列表、Echo、收件人、音色或 care。
- mode/voice override 使用 owner-scoped key；release 不再注入 accepted mock 家庭成员。

### Echo 与数字人 Context

- relation 文本不能授予 personal identity；只有显式 self 或 owner/viewer exact match 是 personal。
- DigitalHumanContextStore 按用户存储，并在 get/set 时复核 accepted family member。
- Echo 每轮 `/context/build` 前和 stale turn submit 前复核 authorized identity；失败记录 `familyRelationshipUnauthorized`，不发送 family 请求。
- accepted family 请求携带 member ID，后端 Context Builder 再次验证 active + accepted。

### Knowledge sync 与 legacy share

- `KnowledgeSyncAuthorizationScope` 成为 bootstrap/merge/delta/payload 的必填参数，并以当前账号 personal + 全部后端 accepted family persona 的不可变快照运行，不再绑定当前 Echo persona。
- 授权 family 集合变化会清除旧 base/pending 并从 revision 0 重拉；切换 persona 不会把另一已授权 persona 的远端知识误判为 tombstone。
- 远端同步与本地 base 只保存 owner/persona/digitalHuman exact-match 实体；wrong-owner、ownerless legacy 和未授权 family persona 不上传、不落入 remote base。
- 无 owner 证明的 `kb_graph.json` 移入 quarantine；已进入用户文件但仍缺 owner/evidence 的 legacy 实体可保留为本地兼容数据，但不能获得 generation/sync 权限。
- release 默认关闭完整图谱导出和无后端 grant 导入；裸 graph 永远拒绝，UI 不显示伪成功。

### 审查补强

- 图片分析写入的人物/地点现在绑定当前授权 persona identity 与 `observed` evidence，避免新照片知识永久停留在不可同步状态。
- FamilyRepository 在冷启动和登录后主动刷新后端关系；只有 owner 匹配的 accepted backend invitation 能恢复 family Echo context。
- 家庭授权只在主线程生成不可变同步快照，后台 sync queue 不再直接读取可变 FamilyRepository，避免账号切换竞态和 main/sync queue 互锁。
- release 隐藏无可用后端 grant 的旧“家族同步”入口，不再保留零操作死页面。

### 运行期新鲜度与并发边界

- `FamilyAuthorizationFreshness` 使用 unknown/refreshing/ready/failed 与 generation；前台恢复先刷新家庭 authority，完成后才启动知识同步，失败时 family 权限 fail closed。
- 同账号并发 refresh 额外捕获请求级 freshness generation；旧成功、旧失败和重复 callback 都不能覆盖最新 authority snapshot。
- Conversation 结束前在主线程捕获 persona identity、user/persona/family generation；`finishExtraction` 只比较锁内不可变 token，不在后台读取 FamilyRepository 或当前 Context。
- governance queue 使用 account-level authorization + queue-owned persona；账号、角色和 family refresh 会先轮换 lock-protected authorization epoch，再同步失效 queue generation，旧 callback 不能修改 graph/base/outbox。
- 当前 family context 被撤销或刷新失败时，持久化 Context 主动写回本人并广播；Echo 释放旧 runtime、刷新档案上下文并准备本人角色。正常 accepted family 不产生额外回退通知。

## 验证入口

```bash
Scripts/QA/prd-stitch-ui/run-family-relationship-authorization-policy-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-family-authorization-freshness-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-family-context-reconciliation-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-family-repository-authorization-lifecycle-check.sh
Scripts/QA/prd-stitch-ui/run-echo-family-context-authorization-check.sh
Scripts/QA/prd-stitch-ui/run-family-context-reconciliation-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-family-sync-import-authorization-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-async-authorization-snapshot-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-coordinator-authorization-epoch-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-three-way-merge-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-context-policy-model-smoke.sh
```

以上 gates 均纳入默认 release regression/release QA package。

最终全量回归：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task22-family-authorization-final8/report.md
```

结果包括：全部静态/model 守卫、iOS/后端 `git diff --check`、Simulator Debug build、generic iPhoneOS build、Archive -> Echo smoke、延迟回信通知 smoke 全部通过。后端 memory targeted tests 3/3 通过；独立并发复核确认 refresh 乱序和 governance callback 两个 P0 已关闭。

## 后端影响

本轮不需要后端行为改动。现有 `/family/invite`、accept 合同和 Context Builder 已把 pending/failed/revoked viewer 阻断、accepted viewer 放行；本轮只让 iOS 在发请求和同步前消费相同 authority。仍需运行后端 targeted tests 作为回归证据，但不需要重新部署服务器。

## 保留边界

- 不新增公开“知识人物转家人”入口；未来只能进入手机号邀请流程。
- 不实现解除/删除家庭关系。
- 不开放整库跨账号分享；未来必须设计后端签名、owner/source member/expiry 绑定和审计。
- 不做真机，不改 Stitch UI。
