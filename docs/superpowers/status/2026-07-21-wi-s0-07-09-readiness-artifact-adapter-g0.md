# WI-S0-07-09 Stage 0 就绪证据适配器 G0

日期：2026-07-21
Work Item：`WI-S0-07-09`
状态：`G0_ADAPTER_VERIFIED / G2_G4_OPEN`

## 本轮范围

新增只读适配器，将两类已存在的运行证据转成严格就绪判定器可消费的
value-free `GateResult`：

- 后端 `GET /ready` 摘要：只接受 `database`、`schema`、`auth` 三项均为
  `ready` 的 schema v1 响应；使用内容摘要生成 evidence id，不输出 URL、响应
  原文或配置值。
- iOS `EchoQAEvidenceManifest`：只接受当前、`passed`、带受约束 source commit、
  artifact hash、owner scope hash 和时间窗的导出 manifest；同时接受受约束的
  `evidenceIdHash`，以兼容 iOS 导出时的证据 ID 脱敏；不输出这些原始标识。
- 适配输出固定为 `dreamjourney.stage0-readiness-input.v1`，再交给
  `stage0_strict_readiness.py` 聚合。

## Fail-closed 规则

- `RUN_STAGE0_READINESS_ARTIFACT_GATE=1` 时，release regression 强制要求后端
  readiness artifact 与 Echo manifest 两者存在，并以 strict 模式运行。
- 后端非 ready、网络/文件读取失败、manifest 过期、`legacyUnverified`、无效 schema
  或缺失 artifact 都不能通过，并以非零退出结束该可选 gate。
- 默认不开启该 gate；默认跳过只产生 skipped 记录，不能被解释为通过。
- 该适配器不发起业务请求、不保存或导出凭据、不关闭 G2/G4，也不改变公开 UI。

## 使用方式

本地 fixture/专项验证：

```bash
python3 Scripts/QA/product-v4/stage0_readiness_artifact_adapter_check.py
bash Scripts/QA/product-v4/run-stage0-readiness-artifact-gate.sh
```

使用真实只读证据时，必须显式提供 artifact：

```bash
RUN_STAGE0_READINESS_ARTIFACT_GATE=1 \
STAGE0_BACKEND_READY_FILE=/secure/path/ready.json \
STAGE0_ECHO_MANIFEST_PATH=/secure/path/echo-qa-evidence-manifest.json \
bash Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

也可将 `STAGE0_BACKEND_READY_FILE` 替换为 `STAGE0_BACKEND_READY_URL`；两者不能
同时使用。输出只保留摘要与 GateResult，真实 artifact 应保留在受控证据目录。

## 本轮实际只读聚合

本轮使用当前线上 `GET /ready` 摘要和模拟器导出的脱敏 Echo QA manifest 执行 strict
聚合。结果为 `2/2` required GateResult 当前通过：

- `stage0.backendReadiness`：database/schema/auth 均为 `ready`；
- `stage0.echoQaEvidence`：当前 manifest 为 `passed`，并使用导出的
  `evidenceIdHash`，未回退为原始 evidence id。

证据目录位于忽略的 `tmp/qa/stage0-readiness-real-artifacts/` 下，只保留脱敏摘要、
QA bundle、manifest、截图与日志，不进入 Git。

## 验证边界

本轮只验证适配和 fail-closed 行为。没有把真实 G2 线上 `/ready` 观察或真机 Echo
manifest 作为本轮完成证据，因此不能据此声明 Stage 0、公开 M0 或发布验收完成。

完整 release regression 仍受既有 `archive-context-snapshot-check` 静态 fixture 编译
缺失媒体依赖的问题影响；该问题不由本适配器引入，需单独处理。
