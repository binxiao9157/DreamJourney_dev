# Echo QA Evidence Bundle v2

## 目标

把 Echo 真机/模拟器调试需要的信息收敛成一份 QA-only 证据包，减少声音、数字人、上下文、fallback 问题分散在多个日志里反复猜。

## 包含内容

- `schemaVersion=2`
- Echo trace record
- iOS runtime diagnostics
- 原有 Echo trace evidence package
- Context V2 clue summary
  - selected archive refs
  - KBLite facts
  - persona signals
  - care signals
  - filtered reasons
  - ranking trace count
  - source counts
  - latency
- digital human session summary
- voice synthesis summary
- fallback summary

## 导出方式

QA 面板里的「导出证据包」按钮现在导出：

```text
echo-qa-evidence-bundle.json
```

UIQA 脚本：

```bash
Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh
```

Release regression 可选开关：

```bash
RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 隐私与安全边界

- 不导出 raw audio
- 不导出 PCM/audio base64
- 不导出 appkey/accesstoken
- 不导出供应商访问密钥
- 只保留 providerLogId/providerRequestId 用于服务商排查
- 只导出档案 ID、数量、线索来源和权限摘要，不导出档案正文

## 验证

- `Scripts/QA/prd-stitch-ui/echo-qa-evidence-bundle-check.swift`
- `Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- `Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 预期用途

当 Echo 出现数字人无声、口型不同步、声音复刻未进入 Echo、Context 缺失或 fallback 异常时，先导出这份 Evidence Bundle v2，再对照后端日志和 provider log。
