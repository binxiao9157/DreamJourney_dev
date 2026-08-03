# 用十一项治理门把声音复刻、TTS 与数字人从原型变成可控 Beta

## Problem Definition

当前工程已有VoiceCloneService、后端火山训练/TTS、Tencent DH session/SDK/PCM drive、角色音色和大量QA evidence，但同意、用途、主体证明、样本/生成音频、Provider accepted/unknown、质量、删除/exit和成本仍分散。一个`ready`、provider配置或一次真机有声不能证明整条能力可公开。

## Proposed Solution

为`WP-V0-01`建立十一项：

1. `WI-V0-01-01`：Voice/DH产品范围、purpose、consent与公开/私用分轨。
2. `WI-V0-01-02`：VoiceProfile/Sample/Grant/GeneratedAudio/ProviderReceipt/DHSession schema。
3. `WI-V0-01-03`：主体证明、录音授权、样本质量/保留和training command。
4. `WI-V0-01-04`：后端credential broker、Provider adapter、stable request/unknown reconcile。
5. `WI-V0-01-05`：训练状态、试听与Owner质量确认，形成quality-usable profile。
6. `WI-V0-01-06`：TTS/GeneratedAudio、purpose/text binding、PCM/timeline和cache receipt。
7. `WI-V0-01-07`：本人/家人角色voiceProfile选择、授权与fallback合同。
8. `WI-V0-01-08`：Tencent DH asset/session/lease/cleanup/provider receipt。
9. `WI-V0-01-09`：iOS Runtime、single audio owner、PCM drive、打断和麦克风恢复。
10. `WI-V0-01-10`：pause/disable/delete/consent revoke/provider exit与传播DAG。
11. `WI-V0-01-11`：质量、真机、隐私、成本、incident、cohort与Beta exit gate。

每项16字段。Owner私用、训练、TTS、DH audio-drive和Visitor public voice使用独立purpose；后者必须等Stage3文字Visitor稳定后另行promotion。默认音色不能冒充复刻，真实数据禁止dual-send，iOS不保存长期Provider key。

## Acceptance Criteria

- 11项/176字段完整，覆盖从consent到delete/exit。
- training accepted、profile ready、Owner quality accepted、GeneratedAudio ready、DH session ready和真机experience分别有receipt/gate。
- role/profile/asset/account/runtime generation绑定，失败不继续旧角色或静默默认音色。
- Provider timeout为unknown/query/reconcile，配置存在不等于ready；真实高敏请求只发一个已批准Provider。
- Voice/DH可独立关闭，Owner文字核心不依赖它们。
- G3/G4、Privacy/Legal/Finance未关闭时保持`EXTERNAL_BLOCKED`。

## Verification Plan

- 对照Product Spec Voice/DH、Consent/Purpose、Provider、iOS Runtime、Object/Media和Rights章节。
- 结合独立审计校准当前火山/Tencent/iOS路径及已有mock/真机证据边界。
- 检查11项/176字段、purpose、receipt、single owner、default-off、delete/exit和G0–G4。
- 运行Provider/Object/Job、Voice/DH相关QA、Product V4与diff gates。

## Risks

- 火山训练/TTS与Tencent渲染跨Provider，外部effect不可用DB回滚；必须稳定request和reconcile。
- 家人音色需要被录音人的独立授权，不能由Owner/家庭关系代替。
- 真机AudioSession/口型/打断质量不能由模拟器或PCM格式合同关闭。

## Assumptions

- 本轮只写路线图，不调用Provider、不改配置或真机验证。
- 当前Voice/DH代码可作为adapter输入，不因历史投入自动公开。
