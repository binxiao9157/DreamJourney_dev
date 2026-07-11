# Task 22：P0 家庭关系授权与知识候选隔离

## 目标

让家庭角色、家庭知识读取和跨用户知识导入只信任当前账号下由后端手机号邀请合同确认的关系。对话或档案中识别出的 `KBPerson` 只能形成关系候选，不能自动成为可选择、可收信、可使用音色或可进入 Echo 家庭上下文的 `active + accepted` 家庭成员；账号切换、旧异步响应、legacy 本地数据和无授权 JSON 分享包必须 fail closed。

## 现状审计

- `FamilyRepository.syncFromKnowledgeBase()` 会把所有新 `KBPerson` 直接追加为 `FamilyMember`。
- `FamilyMember` 本地 initializer 与 legacy decoder 缺少状态时默认 `accessStatus=active`、`invitationStatus=accepted`，导致知识候选被误判为已授权家人。
- `FamilyRepository` 没有 active owner/generation；登录、退出或切换账号后，旧成员和迟到的后端响应可能继续留在单例中。
- mode/voice override 使用全局 UserDefaults key，成员 ID 相同或账号切换时可能跨账号复用本地覆盖。
- `KBLiteMultiUser` 可从剪贴板/文件导入任意 `SharePackage` 或裸 `KBLiteGraph`，没有 accepted family、owner、persona、evidence 或后端 grant 校验。
- `KBPersonaIdentityResolver` 仍可仅因 `relation` 为“本人/自己/我”把非 self context 推断成 personal，进而打开 personal local fallback。
- `DigitalHumanContextStore` 恢复持久化 context 时只校验 viewer，未重新证明 family owner 是当前账号 accepted member。
- knowledge sync 的通用 `isSyncable` 主要检查 privacy scope，ownerless legacy、wrong-owner 或未授权 family persona 缺少统一出入站边界。
- 后端 `/context/build` 已有 pending family viewer 阻断和 accepted member 放行测试，应保留并作为服务端授权来源，不重复创建另一套关系推断。

## P0 合同

1. `FamilyMember` 必须记录关系 owner 与 authority source；只有以下组合可被公开业务视为已授权：
   - owner 精确匹配当前登录用户；
   - authority source 为后端手机号邀请；
   - `accessStatus=active` 且 `invitationStatus=accepted`。
2. legacy 解码、缺失 owner/source、本地普通 initializer 和 `KBPerson` 候选默认均未授权；不得用兼容默认值静默提升权限。
3. QA fixture 只能在显式 UIQA/debug 策略下使用，不得满足公开 release 的授权判断。
4. `KBPerson` 同步进入独立 `FamilyRelationshipCandidate` 集合，不进入 `FamilyRepository.getAll()`，不参与 Echo 角色、时间信件收件人、家庭音色、care 或消息中心。
5. `FamilyRepository` 绑定 active owner 与 generation：登录/切换/退出先清空旧成员、候选和内存覆盖；旧 generation 的 refresh/invite 回调不得合并。
6. mode/voice override 必须按 owner 分区；没有 owner 时不得读取或写入覆盖。
7. 后端列表/邀请响应必须携带匹配 owner；owner 缺失或不匹配的响应拒绝进入已授权仓库。
8. legacy 本地知识分享导入默认关闭；裸 graph 永远拒绝。后续若开放，必须使用后端签发、绑定 owner/source member/expiry 的 grant，而不是信任 JSON 自报身份。
9. 后端 Context 继续要求 accepted family viewer；pending/failed/revoked 或伪造 viewer 不得读取 family Archive、care 或 KB facts。
10. personal identity 只能来自显式 self assistant 或 owner/viewer 精确一致；不得仅凭自然语言 relation 推断 personal。
11. 持久化 family digital-human context 恢复、Echo 请求和角色切换都必须重新查询当前 owner 的 accepted member；无效时回退当前用户 self context，并且不得发送 family `/context/build` 请求。
12. knowledge sync 出站与 authoritative merge 必须验证当前 owner/persona：wrong-owner 和未授权 family persona 拒绝同步；ownerless legacy 仅允许保留在当前用户本地兼容域，不得上传或跨 persona 生成。

## 实现范围

### iOS 模型与仓库

- 增加纯 `FamilyRelationshipAuthorizationPolicy`、authority source 和 candidate 模型。
- `FamilyMember` 后端解析绑定 `ownerUserId`，legacy/default deny。
- `FamilyRepository` 增加 active owner/generation、账号通知、owner-scoped overrides、stale response guard 和独立候选集合。
- 移除启动时公开 mock 家庭成员；现有 UIQA fixture 显式标记并只在 QA 策略下可用。
- Echo、时间信件、家庭列表和声音复刻继续消费 `isAcceptedFamilyMember`，但该属性改为 owner/authority-aware 结果。
- `KBPersonaIdentityResolver` 移除 relation-only personal 推断；`DigitalHumanContextStore` 与 Echo 在恢复/请求前执行 accepted-member guard。
- knowledge sync 增加 owner/persona authorization policy，复用同一家庭 authority source，避免 UI、Echo 和同步各写一套判断。
- 前台恢复先刷新家庭 authority；请求级 refresh generation 阻断同账号乱序响应。
- extraction 捕获 user/persona/family generation snapshot；coordinator 使用 authorization epoch 阻断旧治理 callback。
- family authority 失效时主动持久化回本人 Context，并复用 Echo observer 释放旧 runtime。

### Legacy family share

- `KBLiteMultiUser` 引入默认拒绝的 import policy/result；不再直接合并裸 graph。
- `KBSyncViewController` 在没有后端授权 grant 时不显示可执行导入动作，不把失败伪装成成功。
- 导出/导入完整图谱保持非公开或 QA-only，避免把它误当成生产家庭同步合同。

### 后端与 QA

- 复用并强化现有 family invitation + Context pending/accepted/revoked 测试，不新增推断式家庭关系。
- 新增 iOS 纯模型 smoke：默认拒绝、后端 accepted 放行、owner/source/status/QA/legacy 组合拒绝。
- 新增 repository/static gate：KB candidate 不进入 members、账号切换清理、generation 防迟到、owner-scoped override。
- 新增 legacy share gate：裸 graph 和无 grant package 默认拒绝。
- 新增 Echo/sync gate：relation spoof 不得变 personal、未授权 family context 不请求后端、wrong-owner/unaccepted-family graph 不得同步。
- 接入默认 release regression 与 release QA package，运行 Simulator 和 generic iPhoneOS build。

## 验收清单

- [x] `KBPerson` 只能形成候选，不能出现在 accepted family 列表。
- [x] legacy/local/default `FamilyMember` 不再自动 accepted。
- [x] 只有当前 owner 的 backend invitation accepted member 可用于 Echo、收件人、音色和关怀。
- [x] 切换账号/登出清空旧成员，迟到响应不能覆盖新账号。
- [x] mode/voice overrides 按 owner 隔离。
- [x] 裸 graph 与无授权 share package 默认拒绝导入。
- [x] pending/failed/revoked family Context 仍 fail closed，accepted 合同仍通过。
- [x] relation spoof 不能开启 personal fallback；失效的持久化 family context 回退 self。
- [x] wrong-owner、ownerless legacy 和未授权 family graph 不进入远端 sync/generation。
- [x] 模型 smoke、静态 gate、release QA、Simulator/generic iPhoneOS build、git diff check 通过。
- [x] iOS 变更已由 `f790313` 提交并推送；后端本轮无行为变化，无需部署或新增 Postgres smoke。

## 最终非真机证据

- Full regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task22-family-authorization-final8/report.md`
- Simulator Debug build：通过。
- Generic iPhoneOS build：通过。
- Archive -> Echo Simulator smoke：通过。
- Echo delayed reply notification Simulator smoke：通过。
- iOS/backend `git diff --check`：通过。
- 后端本轮无行为修改，不需要重新部署；既有 family/context targeted tests 3/3 通过。

## 非目标

- 不新增公开“知识人物转家人”按钮；未来必须从手机号邀请流程发起。
- 不实现家庭解除/删除关系，PRD 尚未明确。
- 不开放整库跨账号分享，不设计端到端加密分享协议。
- 不改 Stitch UI，不做真机验证。
- 不处理 semantic cache、change-feed retention/compaction 或历史 sourceRef 迁移。
