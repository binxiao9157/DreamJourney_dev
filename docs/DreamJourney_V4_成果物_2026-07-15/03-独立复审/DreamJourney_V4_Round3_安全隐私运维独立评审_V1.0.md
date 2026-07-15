# DreamJourney V4 Round 3 安全/隐私/运维/过度设计独立评审

版本：V1.0  
日期：2026-07-12  
状态：独立只读评审输入；尚未经过主控 disposition  
范围：Product Spec 6-12/16-21/23-26/31-34、Decision Register、Evidence Matrix和指定实现/运维证据；未修改工作区，未输出凭据值

> 本报告不是法律意见，不替代 Privacy/Legal、供应商合同、真实生产、渗透测试、灾难恢复或真机外部门，也不关闭任何外部决定。

## 1. 结论摘要

- `BLOCKER`：4 项（SOR-01、SOR-02、SOR-05、SOR-08）。
- `HIGH`：4 项（SOR-03、SOR-04、SOR-06、SOR-07）。
- 必须现在解决：AuthZ fail-closed、客户端/Provider credential、删除/rights/audit、真实数据出站门、最小成本/事件证据、backup/restore/RPO/RTO 基线。
- 可延后：Visitor、公开 Voice、Digital Human 扩量、复杂 Family/Care/TimeLetter、Provider A/B 和增长指标目标值。
- 应简化：system/API token兼容、私人过滤视图公开、通用任意文本 Voice synthesis、单一 ready/deleted 布尔、大爆炸迁移和第二 Authority。

## 2. Findings

### SOR-01 — BLOCKER：全局 AuthZ 尚未 deny-by-default

- **分类**：principal/grant/purpose、system绕过、跨租户授权。
- **行动**：`MUST_NOW`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/core/config.py:32-35,82-94`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:365-450`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/authorization_policy.py:98-128`
  - Evidence Matrix 7.1；Spec 8、12、16、25。
- **问题/影响**：ownership 默认 shadow，未分类/策略异常/anonymous/system 路径可能继续执行；攻击者可篡改 userId/path/query/header 尝试跨账号读写、删除或 Provider 操作。
- **建议**：生产强制 enforce；unknown/policy error deny；移除通用 system principal，拆短期 WorkAuthorization/DataRightsAuthorization/ProviderCapability；敏感 route 校验 principal、tenant、owner、purpose、grant、expiry和scope。

### SOR-02 — BLOCKER：客户端长期 token 与 Provider credential

- **分类**：credential边界与潜在泄漏。
- **行动**：`MUST_NOW + EXTERNAL_GATE`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:2632-2645,3835-3846`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:197-204`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/docs/backend/server-deployment-guide.md:196-246`
  - Spec 16、20、33、34。
- **问题/影响**：Bundle/API token fallback 和下发 Provider app credential 会扩大到旧 App、抓包、日志和所有用户；响应中的 expiresAt 不能证明底层 static credential 真正短期化。部署文档中的凭据型内容应按潜在暴露处理，本文不复述其值。
- **建议**：轮换潜在暴露凭据；删除客户端 API token fallback；用户 session 或 Provider 真短期 scope credential；DH由后端broker，不能安全broker则blocked；扫描 Git、artifact、Info.plist、header、日志和备份。

### SOR-03 — HIGH：Publication/Visitor 不应由私人过滤视图或 flag 实现

- **分类**：公开域、Feature Flag fail-open和范围过度。
- **行动**：`REMOVE_OR_SIMPLIFY`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/App/FeatureFlagService.swift:30-41`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:1568-1578`
  - Evidence Matrix 5.1/6.1；Spec 9、10、12、19。
- **问题/影响**：当前没有独立 Publication/Public Index/Visitor grant；若以 `isPrivate=false`、KB snapshot过滤或客户端flag开放，会直接公开私人 Projection且无法可靠撤回。
- **建议**：关闭公开/伪公开入口；Stage 3 只以独立版本化脱敏 Publication、AccessGrant、Public Index和撤回状态实现；Visitor与Owner Echo/私人Context隔离。

### SOR-04 — HIGH：第三方/未成年人和 Voice/DH purpose grant 未关闭

- **分类**：第三方/未成年人、主体证明、用途授权。
- **行动**：`EXTERNAL_GATE`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:1020-1029,1107-1135`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/voice_clone.py:76-159`
  - DR-022/031/036/037；Spec 8、12、16、17、21。
- **问题/影响**：单一 authorizationConfirmed/版本字段不等于年龄、主体和每项用途授权；第三方、家庭代录或未成年人声音可能被错误送入训练、合成、DH或公开。
- **建议**：外部门关闭前禁止相关真实数据出站；独立 ConsentRecord、ProcessingBasis、AccessGrant、ProviderCapability 和 Voice training/private/public/DH purpose grant；未通过时只用synthetic fixture。

### SOR-05 — BLOCKER：本地 tombstone 不能证明完整删除

- **分类**：假删除、Provider retention/delete、rights/audit/incident。
- **行动**：`MUST_NOW`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:118-124,1314-1345,2040-2120`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/docs/backend/server-deployment-guide.md:642-659`
  - Spec 13、16、17、26、32、33。
- **问题/影响**：Voice disable/delete 和 Archive local mutation 未证明 Provider sample/model、GeneratedAudio、对象、备份、客户端cache或日志删除；撤销普通session后又可能丢失继续删除的授权。
- **建议**：状态拆为 access_revoked/pending/partial/unsupported/completed；删除DAG和各module/provider/backup/client receipt；访问先撤；以最小DataRightsAuthorization+WorkAuthorization继续；unsupported持续披露。

### SOR-06 — HIGH：真实数据 dual-send、Voice通用合成和Provider退出

- **分类**：Provider exit、purpose binding和过度设计。
- **行动**：`EXTERNAL_GATE + REMOVE_OR_SIMPLIFY`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:1348-1370`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/voice_clone.py:101-149`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/runtime_config.py:119-204`
  - Spec 17、26、33。
- **问题/影响**：任意文本 synthesis 与 configured/ready 可能被误当业务可用、可删、可迁移；真实声音/正文A/B dual-send扩大暴露；Voice/DH资产可能无法导出。
- **建议**：Voice/DH在条款、region、retention、delete/export和成本前保持Beta/blocked；synthesis绑定answerId/purpose/policy/profileVersion/requestHash/idempotency；比较仅synthetic/专项opt-in；建立Provider exit manifest。

### SOR-07 — HIGH：Rights/Audit/Incident、指标分母和成本证据不足

- **分类**：可观测性、SLO和成本控制。
- **行动**：`MUST_NOW`；增长目标值可 `DEFER`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/runtime_config.py:14-21,24-83`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/docs/backend/server-deployment-guide.md:652-659`
  - Evidence Matrix 7.1；DR-019/027/032/039；Spec 6、18、19。
- **问题/影响**：无法可靠证明成功率分母、Provider成本、删除SLA和incident完整性；只统计成功样本或UI fallback会美化结果，Voice/DH成本也可能失控。
- **建议**：最小服务端operation/outbox事件，记录owner hash、purpose、provider version、状态、成本、错误、receipt；指标必须含样本/分母/窗口/环境/取消重试；optional Provider配置日/月预算、并发、quota和熔断。

### SOR-08 — BLOCKER：没有可证明的灾难恢复与渐进迁移基础

- **分类**：RPO/RTO、备份恢复、大爆炸迁移和部署运维。
- **行动**：`MUST_NOW + REMOVE_OR_SIMPLIFY`。
- **证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/docker-compose.yml:15-35`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:459-462`
  - Evidence Matrix 7.2/7.3；DR-034/040；Spec 20、31、34。
- **问题/影响**：当前 compose/启动路径不能证明 backup、restore、versioned migration、replica、RPO/RTO和receipt replay；一次性改变schema/owner/projection/provider/client会产生代码回滚无法撤销的外部effect。
- **建议**：拒绝大爆炸；先inventory、versioned migration、backup校验、隔离restore和hash/replay；未知owner/writer/credential/effect quarantine；C07/C10/C11前no-go并实测RPO/RTO/MRT。

## 3. 压力测试

### 攻击

- 篡改 userId/path/query/header，未登录/过期/策略异常，system/API/Provider credential重放，跨账号Voice/Archive/KB/DH访问，callback重放和私人Projection误公开。
- 当前静态证据不足以证明全部fail-closed。

### 数据权利

- 删除Source/Voice/Account后访问是否立即停止；撤权后rights job是否继续；Provider unsupported、backup/cache/offline时是否partial；第三方/minor是否有主体证明、限制、异议和回执。
- 当前没有完整RightsRequest、分层receipt和Provider delete evidence。

### Provider退出

- credential泄漏、disable-only、asset不可导出、成本/region/retention不合规、双Provider比较。
- 当前只能证明adapter/contract，不能证明退出与资产可携带。

### 灾难恢复

- Postgres volume损坏、DB commit与Provider effect不一致、restore缺receipt、cutover后旧客户端写、迁移重跑、删除后错误复活访问。
- 当前RPO/RTO、restore/replay、旧客户端窗和rollback drill未验证。

## 4. 行动分类

### MUST_NOW

- AuthZ enforce、移除客户端长期token、轮换潜在暴露凭据。
- 删除/rights/audit/incident和Provider unknown/partial。
- 禁止未成年人、第三方和未批准Provider真实数据出站。
- 最小成本/事件/分母管线。
- backup、隔离restore、RPO/RTO和migration inventory。

### DEFER

- Visitor、公开Voice、Digital Human扩量。
- 复杂Family/Care/TimeLetter主线。
- OCR/ASR/公开分享增长指标和大规模Provider A/B。
- 精确商业目标值，等待真实基线。

### REMOVE_OR_SIMPLIFY

- 客户端system/API token兼容。
- `isPrivate`公开语义和legacy MemoryRepository Authority。
- 通用任意文本Voice synthesis。
- 单一ready/configured/deleted布尔。
- 大爆炸迁移和第二套平行Authority。

### EXTERNAL_GATE

- DR-022/023/024/026/027/028/031/035/036/037/039/040 仍需Product、Privacy/Legal、Security、Operations、Finance或Provider证据关闭。
