# DreamJourney V4 Round 5A 安全隐私运维独立复审

基线：Round5A-Risk-Agent｜2026-07-12｜iOS `8a1922b`｜backend `4c0538b`

## Summary

本轮独立风险复审识别出2项P0、6项P1、0项P2。12个canonical risk均已有路线Package承接，但当前实现仍存在8类暴露；其中身份/AuthZ fail-open与Provider credential下发客户端为P0。报告只记录风险和路线承接状态，不在本轮修改生产代码或关闭外部门。

## Findings

### R5A-RISK-001

- Severity：`P0`
- 结论：未形成生产级身份与对象AuthZ，存在fail-open越权路径。
- 证据：产品证据矩阵§7.1/7.5；`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:365`、`app/main.py:398`、`app/services/authorization_policy.py:51`。
- 攻击/失败路径：缺少token、route未登记、policy evaluator异常或客户端提交其他`userId`时，进入非终止fallback或system path。
- 影响：跨Owner Vault读取/写入、数据权利任务越权、Visitor/Family边界失效。
- 建议控制：强身份；server-derived principal；所有路由/资源deny-by-default；system scope独立且最小化；异常/fallback一律deny。
- Suggested Owner：Security + Backend。
- 验证方式：无token、跨账号token、未分类route、策略异常、system scope corpus全部返回401/403，并通过真实Postgres G2。
- 分类：当前实现暴露；路线充分承接（CR-02/WP-S0-02），尚未退出；外部身份决策依赖。

### R5A-RISK-002

- Severity：`P0`
- 结论：Provider credential仍可能下发客户端。
- 证据：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:188`、`app/services/tokens.py:14`、`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:3831`。
- 攻击/失败路径：提取App网络响应、构建产物或运行时配置后重放provider credential。
- 影响：供应商冒用、成本失控、声音/数字人滥用及不可审计出站。
- 建议控制：服务端代理或真短期、资源绑定、用途绑定credential；移除客户端/system token；撤销旧credential。
- Suggested Owner：Security + Provider Owner。
- 验证方式：Release `.app/.appex`、网络抓包、日志和配置扫描；验证credential TTL、scope、rotation和replay rejection。
- 分类：当前实现暴露；路线充分承接（CR-03/WP-S0-03）；需外部轮换/Provider broker验收。

### R5A-RISK-003

- Severity：`P1`
- 结论：账号切换/登出后的本地业务数据隔离与删除不完整。
- 证据：产品证据矩阵§6.1；`DreamJourney/Sources/Services/UserManager.swift:167`、`DreamJourney/Sources/Services/MemoryRepository.swift:14`。
- 攻击/失败路径：A logout后B登录，旧UserDefaults/内存对象仍可由未owner-scoped读取路径访问；删除账号后本地副本继续存在。
- 影响：跨账号隐私泄漏、删除权不完整、legacy数据被错误自动认领。
- 建议控制：AccountLease、owner-scoped stores、logout/delete lifecycle coordinator、legacy quarantine和全量A/B测试。
- Suggested Owner：iOS + Privacy。
- 验证方式：账号A/B切换、logout、delete、crash/relaunch、离线pending、notification/cache/export全矩阵。
- 分类：当前实现暴露；路线充分承接（CR-01/CR-10/WP-S0-01/WP-S0-05）。

### R5A-RISK-004

- Severity：`P1`
- 结论：Optional能力当前默认暴露，未由server ReleasePolicy统一止损。
- 证据：`DreamJourney/Sources/App/FeatureFlagService.swift:30`、`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/runtime_config.py:22`、产品证据矩阵§6.1/7.1。
- 攻击/失败路径：新安装或旧flag持久化用户直接进入尚未通过真实Provider、隐私或安全门的能力。
- 影响：真实敏感数据被送入未批准路径；mock/contract被误认为可用能力。
- 建议控制：服务端签名ReleasePolicy、future default-off、offline deny、TTL/cohort；mock仅QA。
- Suggested Owner：Product + Security + iOS/Backend。
- 验证方式：fresh install、旧版本升级、无网络、Provider未配置、policy过期和capability mismatch smoke。
- 分类：当前实现暴露；路线充分承接（CR-08/WP-S0-06）；Publication/Voice仍外部阻断。

### R5A-RISK-005

- Severity：`P1`
- 结论：通知/TimeLetter将本地状态标为delivered，存在副作用丢失。
- 证据：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:2522`、产品证据矩阵§7.6。
- 攻击/失败路径：状态commit后mailbox/APNs/provider写入失败、进程崩溃或重复调度。
- 影响：用户看到已送达但实际未送达；无法重试、对账或证明失败分母。
- 建议控制：transactional outbox、Inbox/business receipt、job lease、UNKNOWN状态和reconcile。
- Suggested Owner：Backend + Operations。
- 验证方式：commit/provider crash、duplicate worker、延迟/超时、重启恢复和APNs arrival corpus。
- 分类：当前实现暴露；路线充分承接（CR-06/WP-S1-02）；通知Provider为外部依赖。

### R5A-RISK-006

- Severity：`P1`
- 结论：数据库连接、migration与health不能支撑并发/恢复承诺。
- 证据：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:47`、`:3283`、`:3311`，`app/main.py:464`。
- 攻击/失败路径：并发请求共享事务状态、异常后连接污染、schema漂移或DB已故障但health仍返回ok。
- 影响：数据错写、锁/配额异常、恢复时误判可用，SLA/RPO/RTO无法成立。
- 建议控制：request/job UoW、连接池、版本化migration、DB/schema readiness、隔离restore/replay。
- Suggested Owner：Backend + Operations。
- 验证方式：真实Postgres并发、连接故障、migration rollback、readiness、backup restore和replay。
- 分类：当前实现暴露；路线充分承接（CR-04/WP-S0-04）；恢复环境与RPO/RTO为外部/运营依赖。

### R5A-RISK-007

- Severity：`P1`
- 结论：媒体上传仍是mock metadata，不能证明对象所有权或删除闭环。
- 证据：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:872`、`:914`、产品证据矩阵§7.7。
- 攻击/失败路径：客户端提交metadata或伪造本地路径后被视为已上传/可处理对象。
- 影响：媒体丢失、越权引用、恶意文件处理、删除/恢复无法证明。
- 建议控制：private namespace、signed PUT/GET、HEAD、sha256/MIME/scan、quota、object/version/backup分层receipt。
- Suggested Owner：Backend + Media/Privacy。
- 验证方式：真实对象存储恶意文件、跨vault key、过期URL、大文件、删除和restore drill。
- 分类：当前实现暴露；路线充分承接（CR-04/CR-10/WP-S0-04/WP-S0-05 + R4）；对象存储/扫描/地域/SLA为外部依赖。

### R5A-RISK-008

- Severity：`P1`
- 结论：Voice/DH缺少完整purpose、危机和Provider exit约束。
- 证据：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:1414`、`:1427`、产品证据矩阵§6/7、产品决策登记册DR-025/DR-031/DR-037。
- 攻击/失败路径：任意文本进入声音合成；删除后Provider资产仍存；危机表达进入延迟回信或人格模拟。
- 影响：声音冒用、敏感数据留存、危机用户得到延迟/不适当响应。
- 建议控制：purpose grant、AI disclosure、危机即时安全响应、Provider deletion receipt、asset portability/exit、Beta default-off。
- Suggested Owner：Product + Safety/Privacy + Provider。
- 验证方式：危机语句corpus、未授权purpose、paused/deleted profile、Provider failure/delete/exit和成本熔断测试。
- 分类：当前实现暴露；路线承接但未退出（CR-09/WP-V0-01）；隐私/法律/Provider/真机为外部依赖。

## Canonical Risk 覆盖

- CR-01：路线承接；当前本地隔离暴露。
- CR-02：路线承接；当前AuthZ fail-open，P0。
- CR-03：路线承接；credential暴露，需外部轮换/broker。
- CR-04：路线承接；连接、migration、restore尚未验证。
- CR-05：路线承接；Source→MemoryVersion单Authority仍缺实现。
- CR-06：路线承接；outbox/unknown effect当前暴露。
- CR-07：路线承接；iOS runtime部分可复用，但业务Authority仍耦合。
- CR-08：路线承接；当前Optional默认暴露，Publication仍应保持关闭。
- CR-09：路线承接；Voice/DH受Provider、Privacy、Legal、真机门阻断。
- CR-10：路线承接；删除/恢复/Provider/backup receipt不完整。
- CR-11：路线承接存在缺口；指标分母、成本熔断、SLA owner未定。
- CR-12：路线承接存在缺口；migration runner、真实restore/cutover/retirement演练未完成。

12/12 canonical risk均有路线Package；8条高信号发现中，P0 2条、P1 6条、P2 0条。按发现计：当前实现暴露8条，路线充分承接7条，路线退出/参数缺口3条，外部依赖5条，分类可重叠。

## 未检查内容

其他Round2/Round3报告、全部Round5报告、`.env`、LocalConfig、密钥/token值、部署服务器/容器/timer、真实Provider、真机、生产数据库、运行时网络和backup restore。未运行测试，未修改文件。

## 独立性声明

仅使用指定五份文档；Round3响应只取第2节12个canonical risk定义作为risk authority，不采纳其评审结论；源码证据均按指定baseline commit只读抽查。

## 计数

- P0：2
- P1：6
- P2：0
