# P3-S1：统一非真机发布证据 Lane Registry

日期：2026-08-06  
范围：V4 的 M0、Stage 2、M1、M2 非真机 gate 聚合；不改变任何产品功能、公开入口或 feature flag。

## 目的

既有 gate 分布在 iOS 和 Backend 两个仓库。P3-S1 不重写这些 gate，也不把不同阶段的证据混成一个“全部发布完成”的结论。

新增的 registry 将四个 lane 显式绑定到各自已有的后端/iOS gate，并要求每个 lane 声明：

- 默认状态（公开 M0 或 closed-pilot default-off）；
- 运行命令与独立超时；
- 缺失环境条件；
- 尚未关闭的 `DEVICE_REQUIRED`、`EXTERNAL_PROVIDER_REQUIRED`、`PRODUCT_OR_LEGAL_REQUIRED` Gate。

## 使用方式

默认只生成计划，不执行任何 gate：

```bash
bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh
```

显式执行全部 lane：

```bash
bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh --execute
```

只执行一个或多个 lane：

```bash
bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh \
  --execute --lanes stage2,m1
```

M0 的 iOS 联合 gate 仍需要已有后端证据包：

```bash
BACKEND_EVIDENCE_PATH=/absolute/path/to/backend/manifest.json \
  bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh \
    --execute --lanes m0
```

每次执行会在 `tmp/qa/v4-unified-non-device-evidence/<run-id>/` 生成：

- `manifest.json`：脱敏的 lane、revision、命令状态、证据日志相对路径和未关闭 Gate；
- `report.md`：人工可读摘要；
- `<lane>/<command>/command.log`：该 command 的脱敏本地 gate 日志；原始临时日志会在脱敏后删除。

## 结论边界

即使所有 selected lane 的 `executionStatus=passed`，聚合证据也固定输出：

```text
releaseDecision=NO_GO
releaseDecisionReason=nonDeviceEvidenceCannotCloseExternalOrDeviceGates
```

这避免把模拟器、mock、shadow、default-off 或合同层的通过，误写成真实 Provider、真机、成年人核验、法规/法务审核都已完成。

## 验证

```bash
python3 Scripts/QA/product-v4/v4-non-device-release-lanes-check.py
bash -n Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh
```

已执行 M1 实际 lane：

```bash
RUN_ID=p3-s1-m1-fixed-2 \
OUTPUT_ROOT=/tmp/dreamjourney-p3-s1-m1-fixed-2 \
bash Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh \
  --execute --lanes m1
```

结果：后端 Voice/DH readiness、iOS Voice/DH readiness、iOS account lifecycle 三条既有 gate 均通过。生成的 manifest 仍固定为：

```text
releaseDecision=NO_GO
releaseDecisionReason=nonDeviceEvidenceCannotCloseExternalOrDeviceGates
```

关联修正：Voice Profile 删除只有本地撤权和 outbox 接受状态时，后端现在返回 `providerCleanupState=unsupported`，而不是暗示 Provider 正在清理。只有持久化上游 Provider 回执后才允许展示外部清理完成。

下一子项 P3-S2：运行 Stage 2、M2 和带已有后端证据的 M0 lane，形成同一 revision 的完整非真机 evidence snapshot；仍不将其误写成设备或 Provider 验收完成。
