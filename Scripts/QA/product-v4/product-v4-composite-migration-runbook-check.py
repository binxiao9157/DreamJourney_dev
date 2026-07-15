#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"
DECISIONS = ROOT / "docs/product/DreamJourney_V4_产品决策登记册_V1.0.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def numbered_chapter(text: str, heading: str) -> str:
    start = text.index(heading)
    body_start = start + len(heading)
    next_heading = re.search(r"^## \d+\. ", text[body_start:], re.MULTILINE)
    end = body_start + next_heading.start() if next_heading else len(text)
    return text[start:end]


def table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def main() -> None:
    spec = SPEC.read_text(encoding="utf-8")
    evidence = EVIDENCE.read_text(encoding="utf-8")
    decisions = DECISIONS.read_text(encoding="utf-8")
    chapter = numbered_chapter(
        spec, "## 34. 组合 Cutover、Rollback 与 Legacy 退役 Runbook"
    )

    headings = [
        "### 34.0 CURRENT EVIDENCE：分域方案存在，组合执行 Authority 不存在",
        "### 34.1 组合 Authority、Lane 与不变量",
        "### 34.2 五类 Rollback Plane",
        "### 34.3 不可逆事实与 Compensation/Reconcile",
        "### 34.4 既有 Wave 依赖映射",
        "### 34.5 组合 Migration Waves",
        "### 34.6 Go/No-Go Record、Threshold 与自动暂停",
        "### 34.7 Emergency Stop、Restore 与恢复边界",
        "### 34.8 Legacy Retirement Manifest",
        "### 34.9 跨域验收与故障演练",
        "### 34.10 实现阶段 UNKNOWN",
    ]
    for heading in headings:
        require(heading in chapter, f"Composite runbook heading missing: {heading}")
    require(
        "### 34.0A Startup Lean Profile：百级用户默认迁移档位" in chapter,
        "Startup Lean Profile heading missing",
    )

    rollback_planes = re.findall(
        r"^\| (UI exposure|Client routing|API traffic|Worker/provider|Schema/data) \|",
        chapter,
        re.MULTILINE,
    )
    require(
        rollback_planes
        == ["UI exposure", "Client routing", "API traffic", "Worker/provider", "Schema/data"],
        "rollback planes must contain the exact five ordered planes",
    )

    wave_lines = re.findall(r"^\| C\d{2} \|.*$", chapter, re.MULTILINE)
    wave_rows = [table_cells(line) for line in wave_lines]
    wave_ids = [row[0] for row in wave_rows]
    require(wave_ids == [f"C{index:02d}" for index in range(12)], "wave IDs must be C00..C11")
    for row in wave_rows:
        wave_id = row[0]
        require(len(row) == 11, f"{wave_id} must have 11 business cells, got {len(row)}")
        require(all(row), f"{wave_id} contains an empty execution field")
        require(row[9] == f"MRT-{wave_id}", f"{wave_id} must bind its own max recovery time")

    go_no_go_terms = [
        "runId / compositeWave / lane / cohort",
        "migrationHeads(W,I,P,Q,O,V)",
        "authorityEpoch",
        "backupId / backupAge / restoreEvidenceId / rollbackDrillEvidenceId",
        "mismatchByClass",
        "providerUnknown / providerInFlight",
        "rightsPending / deletePartial / retentionHold / objectOrphanLag",
        "thresholdSetId / observationWindow / maxRecoveryTime / evidenceBundleId",
        "decision(go|pause|no-go)",
        "approverRoles",
    ]
    for term in go_no_go_terms:
        require(term in chapter, f"go/no-go record field missing: {term}")

    retirement_start = chapter.index(headings[8])
    retirement_end = chapter.index(headings[9])
    retirement_section = chapter[retirement_start:retirement_end]
    retirement_types = re.findall(
        r"^\| (legacy schema|legacy route|legacy timer/effect|legacy credential|legacy feature flag|legacy local store|transition code) \|",
        retirement_section,
        re.MULTILINE,
    )
    require(
        retirement_types
        == [
            "legacy schema",
            "legacy route",
            "legacy timer/effect",
            "legacy credential",
            "legacy feature flag",
            "legacy local store",
            "transition code",
        ],
        "retirement manifest must cover the seven ordered legacy surfaces",
    )

    scenario_start = chapter.index(headings[9])
    scenario_end = chapter.index(headings[10])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 18, f"composite failure drills too small: {scenario_count}")

    required_terms = [
        "不创建第二套 migration runner",
        "owner_text_core",
        "Data Rights 高优先级",
        "UNKNOWN 不是成功",
        "epoch不回退",
        "不能修改原 no-go 为 go",
        "forward migration",
        "Q09旧timer drain/ownership cutover",
        "不能修改原 receipt 为“未发生”",
        "DR-023/026/028/031/035/039/040/041/042",
        "不会关闭仍为 `EXTERNAL_REQUIRED/RECOMMENDED_PENDING` 的外部门",
        "L0 盘点与可恢复备份",
        "L1 离线演练",
        "L2 维护窗切换",
        "L3 观察与退役",
    ]
    for term in required_terms:
        require(term in chapter, f"Composite runbook term missing: {term}")

    evidence_heading = "### 7.9 Round 3C4 组合 Runbook 设计状态"
    require(evidence_heading in evidence, "Composite runbook evidence section missing")
    evidence_section = evidence[evidence.index(evidence_heading):]
    for term in (
        "Composite authority / C00–C11",
        "Five rollback planes",
        "Irreversible compensation",
        "Go/no-go and recovery",
        "Legacy retirement manifest",
        "Production migration drill",
        "`DESIGNED`",
        "`CONTRACT_ONLY`",
        "`PRODUCT_CONFIRMED / NOT_IMPLEMENTED`",
        "`PRODUCT_CONFIRMED / CONTRACT_ONLY`",
        "`EXTERNAL_ACCEPTANCE`",
        "DR-023/026/028/031/035/039/040/041/042",
    ):
        require(term in evidence_section, f"Composite evidence boundary missing: {term}")

    decision_heading = "### 3.2 Round 3C4 组合 Runbook 决策映射"
    require(decision_heading in decisions, "Composite runbook decision mapping missing")
    decision_section = decisions[decisions.index(decision_heading):]
    for decision_id in ("DR-023", "DR-026", "DR-028", "DR-031", "DR-035", "DR-039", "DR-040", "DR-041", "DR-042"):
        require(decision_id in decision_section, f"Composite decision mapping missing: {decision_id}")
    require(
        "产品确认不能替代真实 backup/restore" in decision_section,
        "Composite runbook must preserve implementation and production gates",
    )

    print(
        "Product V4 composite migration runbook check passed: "
        f"planes={len(rollback_planes)}, waves={len(wave_ids)}, "
        f"retirement_surfaces={len(retirement_types)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
