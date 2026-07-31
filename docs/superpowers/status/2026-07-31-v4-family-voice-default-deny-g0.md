# V4 家人角色复刻音色默认拒绝 G0

日期：2026-07-31

## 范围与权威依据

- 路线：`2026-07-17-dreamjourney-v4-final-requirements-execution-plan.md` 第 0.3、5C、12 节。
- 规则：M0 只允许经授权的家庭静态贡献；M1 只允许完成成年人核验的在世主体以
  `subject=actor` 训练和私用自己的复刻音色。家庭关系本身不是声音授权。
- 本轮仅收敛旧 Echo 路径中“家人资料携带 ready voiceProfileId 时，客户端仍可能选中它”的
  兼容风险；不改变三 Tab、公开 Echo 视觉或家人普通文字回响。

## 已实现

### iOS 选择边界

`EchoRoleVoiceProfileSelection` 现在只有三类可执行来源：

1. AI 助手默认音色；
2. 当前已登录本人的 ready 复刻音色；
3. 非本人家人角色的 `familyVoiceNotPermitted`。

家人角色保留人物/档案上下文，但不再读取 `FamilyRepository` 的 accepted member 音色字段，
也不会把 `normalizedVoiceProfileId` 传给 `sendEchoReplyViaTencentVoiceClonePCMDrive`。
该状态不会显示为公开的“缺少音色”提示；QA evidence 会记录 fallback 原因，普通 Echo 继续走
中性文本/默认运行路径。

### 后端纵深防御

既有 `/voice/synthesis` 在 provider 创建前检查 profile：当 `personaScope != personal` 或
`digitalHumanId != userId` 时返回 HTTP 403，代码为 `subject_eligibility_hard_denied`，原因是
`familySubjectHardDeny`。本轮补充接口级回归，证明一个表面上 ready、enabled、provider-ready 的
家人 profile 也不能触发 provider 调用。

## QA 证据

### 静态门

```bash
swift Scripts/QA/prd-stitch-ui/echo-role-voice-profile-selection-check.swift .
bash Scripts/QA/product-v4/run-ios-family-voice-deny-gate.sh
```

结果：`PASS`。

### 后端合同

```bash
PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_voice_synthesis_family_scope \
  tests.test_voice_role_selection_shadow
```

结果：`10 passed`。测试使用 observe-mode 的发布策略隔离 hidden route gate，随后验证授权
hard deny；没有调用真实 Provider。

### 模拟器 UIQA / 证据包

```bash
SIMULATOR_NAME='iPhone 17 Pro' LOG_WAIT_TIMEOUT=60 \
  Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh
```

结果：`PASS`。构建与安装使用本机 bundle id `com.yxj.dreamjourney.app`。导出的最新运行时证据包含：

- `roleVoiceSource=familyVoiceNotPermitted`；
- 没有 `voiceProfileIdHash`；
- `voiceSynthesis.status=unavailable`，`failureReason=familyVoiceNotPermitted`；
- `voiceOutputMode=tencentText`；
- 家人上下文保留，且没有跨 scope 档案混入。

本次产物：

```text
tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260731-132643/
```

该 harness 在写完 result 后会恢复原来的 Echo 上下文，因此截图证明的是恢复后的公开 UI 没有出现
家人复刻音色提示；家人 fixture 的授权结论以同目录 JSON 证据包为准。

## 未声明完成的范围

- 这不是 M1 本人私有 Voice 的 release、Provider、删除或真机质量验收；
- 这不是 M2 在世主体授权发布或 Digital Human 的开放；
- 没有部署后端、没有调用腾讯或火山真实 Provider、没有声纹训练或数字人 session；
- 没有将 Family 声音能力重新设计为产品功能。若未来成年人以自己的身份完成 M1 权利链，必须走独立
  VoiceProfile version、专项授权、provider receipt 和 G3/G4 gate，不能通过家庭关系复用。
