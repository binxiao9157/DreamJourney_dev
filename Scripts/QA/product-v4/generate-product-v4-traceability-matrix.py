#!/usr/bin/env python3
"""Generate the DreamJourney V4 route traceability matrix from authority documents."""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"
REGISTER = ROOT / "docs/product/DreamJourney_V4_产品决策登记册_V1.0.md"
REVIEW = ROOT / "docs/product/DreamJourney_V4_Round3_独立架构评审响应_V1.0.md"
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
OUTPUT = ROOT / "docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md"

FIELDS = (
    "Outcome",
    "Product value",
    "Priority / lane",
    "Risk / requirement",
    "Dependencies",
    "iOS scope",
    "Backend scope",
    "Data/API/Event",
    "Migration",
    "Release policy",
    "Verification",
    "Deployment",
    "Rollback",
    "Definition of Done",
    "External gates",
    "Non-goals",
)

GATE_PATTERN = re.compile(r"(?<![A-Z0-9])G[0-4](?![A-Z0-9])")
GATE_ATOM = r"`?G[0-4]`?"
NEGATED_GATE_SPANS = (
    re.compile(rf"(?:无|不依赖|无需)\s*{GATE_ATOM}(?:\s*/\s*{GATE_ATOM})*"),
    re.compile(rf"{GATE_ATOM}\s*(?:不适用|不发(?:送)?|不调用)"),
)

PRIMARY_FR_TARGETS = {
    "FR-ACC-001": "WI-S0-02-01",
    "FR-ACC-002": "WI-S1-01-11",
    "FR-SRC-001": "WI-S1-01-12",
    "FR-SRC-002": "WI-S1-02-11",
    "FR-SRC-003": "WI-S1-01-01",
    "FR-CHAT-001": "WI-S1-03-05",
    "FR-CHAT-002": "WI-S1-01-03",
    "FR-CHAT-003": "WI-S1-01-04",
    "FR-VOICE-001": "WI-V0-01-03",
    "FR-VOICE-002": "WI-V0-01-05",
    "FR-VOICE-003": "WI-V0-01-09",
    "FR-VOICE-004": "WI-V0-01-01",
    "FR-VOICE-005": "WI-V0-01-10",
    "FR-MEM-001": "WI-S1-01-04",
    "FR-MEM-002": "WI-S1-01-05",
    "FR-QA-001": "WI-S1-01-07",
    "FR-QA-002": "WI-S1-01-08",
    "FR-PUB-001": "WI-S3-01-03",
    "FR-PUB-002": "WI-S3-01-07",
    "FR-PUB-003": "WI-S3-01-06",
    "FR-VIS-001": "WI-S3-01-05",
    "FR-VIS-002": "WI-S3-01-06",
    "FR-VIS-003": "WI-S3-01-06",
    "FR-PRIV-001": "WI-S0-02-04",
    "FR-PRIV-002": "WI-S0-02-05",
    "FR-PRIV-003": "WI-S0-05-06",
    "FR-PRIV-004": "WI-S0-05-04",
    "FR-PRIV-005": "WI-S0-05-01",
    "FR-PRIV-006": "WI-S0-02-05",
    "FR-SAFE-001": "WI-S0-06-09",
    "FR-SAFE-002": "WI-S3-01-06",
    "FR-OPS-001": "WI-S1-02-03",
    "FR-OPS-002": "WI-S0-07-05",
    "FR-OPS-003": "WI-S0-07-01",
}

DEFERRED_FR_TARGETS = {
    "FR-MEM-003": "STAGE4-VALUE-REENTRY",
    "FR-MEM-004": "STAGE4-VALUE-REENTRY",
}

DR_FALLBACK_TARGETS = {
    "DR-003": "WP-S0-06",
    "DR-008": "WP-S1-03",
    "DR-009": "WI-S1-01-12,WI-S1-02-11",
    "DR-012": "SCOPE-AOS-COMPONENTS",
    "DR-016": "WP-S3-01",
    "DR-017": "GLOBAL-EXTERNAL-GATES",
    "DR-020": "EXTERNAL-HERMES-ASSET-OWNER",
    "DR-021": "SCOPE-PERMANENT-TIMERIVER",
    "DR-030": "PRODUCT-V4-DOCUMENT-AUTHORITY",
    "DR-033": "GOVERNANCE-REVERSIBLE-ONLY",
    "DR-042": "WP-MIG-01",
    "DR-043": "WP-S0-06",
}

PACKAGE_OWNER_ROLES = {
    "WP-S0-01": "iOS + Security + Privacy",
    "WP-S0-02": "Security + Backend",
    "WP-S0-03": "Security + Provider owner",
    "WP-S0-04": "Backend + Data + SRE",
    "WP-S0-05": "Privacy + Backend + Provider",
    "WP-S0-06": "Product + iOS + Backend",
    "WP-S0-07": "Operations + Data + Privacy",
    "WP-S1-01": "Product + Backend + Data",
    "WP-S1-02": "Backend + Worker + Operations",
    "WP-S1-03": "iOS + Architecture",
    "WP-S3-01": "Product + Privacy + Security",
    "WP-V0-01": "Product + Privacy + Voice + Provider",
    "WP-MIG-01": "Architecture + Operations + Security",
}


@dataclass(frozen=True)
class WorkItem:
    work_item_id: str
    package_id: str
    fields: dict[str, str]
    fr_ids: tuple[str, ...]
    dr_ids: tuple[str, ...]
    finding_ids: tuple[str, ...]
    cr_ids: tuple[str, ...]
    gates: tuple[str, ...]


def cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def strip_ticks(value: str) -> str:
    return value.replace("`", "").strip()


def markdown_cell(value: str) -> str:
    return " ".join(value.replace("|", "\\|").split())


def markdown_ids(values: list[str] | tuple[str, ...]) -> str:
    return "<br>".join(f"`{value}`" for value in values) if values else "-"


def table_rows(text: str, prefix: str) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        row = cells(line)
        row_id = strip_ticks(row[0])
        if row_id.startswith(prefix):
            result[row_id] = row
    return result


def expand_numeric_ids(text: str, prefix: str, width: int) -> tuple[str, ...]:
    result = set(re.findall(rf"\b{prefix}-\d{{{width}}}\b", text))
    for match in re.finditer(
        rf"\b{prefix}-(\d{{{width}}})((?:/\d{{{width}}})+)", text
    ):
        result.add(f"{prefix}-{match.group(1)}")
        result.update(f"{prefix}-{part}" for part in match.group(2).split("/") if part)
    for match in re.finditer(
        rf"\b{prefix}-(\d{{{width}}})\.\.(\d{{{width}}})", text
    ):
        start, end = int(match.group(1)), int(match.group(2))
        result.update(f"{prefix}-{number:0{width}d}" for number in range(start, end + 1))
    return tuple(sorted(result))


def applicable_gates(text: str) -> tuple[str, ...]:
    """Extract explicitly applicable gates while removing explicit negations."""
    normalized = text
    for pattern in NEGATED_GATE_SPANS:
        normalized = pattern.sub(" ", normalized)
    gates = set(GATE_PATTERN.findall(normalized))
    if not gates:
        gates.add("G0")
    return tuple(sorted(gates))


def gate_parser_self_test() -> None:
    cases = {
        "G4产品 / G2真实 / G1 UIQA": ("G1", "G2", "G4"),
        "无G2/G3/G4；Xcode owner review": ("G0",),
        "G0 shadow；G2部署；无G3真实调用；G4产品": ("G0", "G2", "G4"),
        "G0 fixture；G3不适用；不依赖G2；无需G4；G3不发真实effect": ("G0",),
        "G2 schema；G3/G4尚不由schema关闭": ("G2", "G3", "G4"),
    }
    for source, expected in cases.items():
        actual = applicable_gates(source)
        if actual != expected:
            raise AssertionError(f"gate parser: {source!r} -> {actual}, expected {expected}")


def parse_work_items(text: str) -> dict[str, WorkItem]:
    matches = list(re.finditer(r"^### `(WI-[A-Z0-9-]+)`", text, re.MULTILINE))
    result: dict[str, WorkItem] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[match.start() : end]
        field_pairs = re.findall(r"^- \*\*([^*]+)\*\*：(.*)$", block, re.MULTILINE)
        if tuple(name for name, _ in field_pairs) != FIELDS:
            raise ValueError(f"invalid Work Item fields: {match.group(1)}")
        field_map = dict(field_pairs)
        risk = field_map["Risk / requirement"]
        work_item_id = match.group(1)
        package_id = "WP-" + "-".join(work_item_id.split("-")[1:-1])
        finding_ids = set()
        for prefix in ("IAR", "BAR", "SOR"):
            finding_ids.update(expand_numeric_ids(risk, prefix, 2))
        gates = applicable_gates(field_map["Verification"] + " " + field_map["External gates"])
        result[work_item_id] = WorkItem(
            work_item_id=work_item_id,
            package_id=package_id,
            fields=field_map,
            fr_ids=tuple(sorted(set(re.findall(r"\bFR-[A-Z]+-\d{3}\b", risk)))),
            dr_ids=expand_numeric_ids(risk, "DR", 3),
            finding_ids=tuple(sorted(finding_ids)),
            cr_ids=expand_numeric_ids(risk, "CR", 2),
            gates=gates,
        )
    return result


def work_item_ceiling(work_item: WorkItem) -> str:
    if "G4" in work_item.gates or "G3" in work_item.gates:
        return "EXTERNAL_BLOCKED"
    if "G2" in work_item.gates:
        return "DEPLOYED_UNVERIFIED"
    return "INTERNAL_READY"


def render() -> str:
    spec = SPEC.read_text(encoding="utf-8")
    evidence = EVIDENCE.read_text(encoding="utf-8")
    register = REGISTER.read_text(encoding="utf-8")
    review = REVIEW.read_text(encoding="utf-8")
    roadmap = ROADMAP.read_text(encoding="utf-8")

    canonical_fr = set(re.findall(r"\bFR-[A-Z]+-\d{3}\b", spec))
    fr_rows = table_rows(evidence, "FR-")
    dr_rows = table_rows(register, "DR-")
    finding_rows = {}
    for prefix in ("IAR-", "BAR-", "SOR-"):
        finding_rows.update(table_rows(review, prefix))
    cr_rows = table_rows(review, "CR-")

    inventory = roadmap.split("### 2.1 Package Inventory", 1)[1].split("### 2.2", 1)[0]
    package_rows = table_rows(inventory, "WP-")
    work_items = parse_work_items(roadmap)

    if set(fr_rows) != canonical_fr or len(fr_rows) != 36:
        raise ValueError("FR authority/evidence mismatch")
    if len(dr_rows) != 43 or len(finding_rows) != 22 or len(cr_rows) != 12:
        raise ValueError("DR/finding/CR authority count mismatch")
    if len(package_rows) != 13 or len(work_items) != 115:
        raise ValueError("package/Work Item count mismatch")
    if set(PRIMARY_FR_TARGETS) | set(DEFERRED_FR_TARGETS) != canonical_fr:
        raise ValueError("FR primary/deferred mapping is incomplete")

    fr_to_wis: dict[str, list[str]] = defaultdict(list)
    dr_to_wis: dict[str, list[str]] = defaultdict(list)
    finding_to_wis: dict[str, list[str]] = defaultdict(list)
    for work_item in work_items.values():
        for requirement_id in work_item.fr_ids:
            fr_to_wis[requirement_id].append(work_item.work_item_id)
        for decision_id in work_item.dr_ids:
            dr_to_wis[decision_id].append(work_item.work_item_id)
        for finding_id in work_item.finding_ids:
            finding_to_wis[finding_id].append(work_item.work_item_id)

    for requirement_id, target in PRIMARY_FR_TARGETS.items():
        if target not in work_items or requirement_id not in work_items[target].fr_ids:
            raise ValueError(f"invalid FR primary target: {requirement_id}->{target}")

    finding_edges: dict[str, list[str]] = {}
    for finding_id, row in finding_rows.items():
        packages = re.findall(r"WP-[A-Z0-9-]+", row[6])
        edges = []
        for package_id in packages:
            candidates = sorted(
                work_item_id
                for work_item_id in finding_to_wis[finding_id]
                if work_items[work_item_id].package_id == package_id
            )
            if not candidates:
                raise ValueError(f"finding/package has no Work Item edge: {finding_id}->{package_id}")
            edges.append(f"{package_id}->{candidates[0]}")
        finding_edges[finding_id] = edges

    lines = [
        "# DreamJourney V4 路线追踪矩阵",
        "",
        "版本：V1.0 Generated Snapshot",
        "日期：2026-07-15",
        "状态：Round 4E1B 生成视图；不是实现完成证据",
        "权威源：Product Spec、当前实现证据矩阵、产品决策登记册、Round 3独立架构评审响应、V4可执行路线图",
        "",
        "## 0. 使用边界",
        "",
        "本文件用于双向追踪，不重新定义产品范围。生成器重复运行会覆盖本文件；人工决定应修改对应权威源或生成器中的显式关系配置。当前没有任何FR标记为`PROD_VERIFIED`，`PLANNED`只表示路线已定义，`UNASSIGNED`表示尚未分配执行人。",
        "",
        "集合基线：**36 FR / 43 DR / 22 Finding / 12 CR / 13 Package / 115 Work Item**。",
        "",
        "## 1. 关系与状态语义",
        "",
        "| 关系/字段 | 含义 | 禁止推导 |",
        "| --- | --- | --- |",
        "| `PRIMARY_WI` | FR主要交付责任 | 不表示该WI已实现 |",
        "| `SUPPORTING_WI` | 反向支持边 | 不替代primary退出门 |",
        "| `DEFERRED_BY_GATE` | 明确后置，达到重入门前无implementation WI | 不得为覆盖率提前开发 |",
        "| `BLOCKS_OR_GUIDES` | 开放DR约束可逆设计/发布 | 不表示产品已确认 |",
        "| `EXTERNAL_GATE` | 需要外部证据 | G0/G1不得关闭 |",
        "| `ENFORCES_REJECTION` | 实施负向禁止 | 不得重新包装为待开发能力 |",
        "| `GOVERNS_IMPLEMENTATION` | 产品选择已确认，约束对应实现与验收 | 不表示实现、外部门或发布门已关闭 |",
        "| `DEFERRED_POLICY_WITH_GUARDRAILS` | 产品参数暂缓，但工程保护必须实现 | 不得把预算未定解释为无限调用 |",
        "| `Lifecycle` | 路线执行状态 | 不等于当前代码成熟度 |",
        "| `Decision` | GO/STOP/NO_GO | 不与Lifecycle混用 |",
        "| `Ceiling` | 缺适用外部证据时最高状态 | 不得由文档/静态检查升级 |",
        "",
        "## 2. FR Registry（36）",
        "",
        "| FR | Priority | Primary relation | Primary target | Supporting WIs | Current maturity | Exposure | Main stage | Decision / external gates |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]

    for requirement_id in sorted(canonical_fr):
        row = fr_rows[requirement_id]
        if requirement_id in DEFERRED_FR_TARGETS:
            relation = "DEFERRED_BY_GATE"
            target = DEFERRED_FR_TARGETS[requirement_id]
        else:
            relation = "PRIMARY_WI"
            target = PRIMARY_FR_TARGETS[requirement_id]
        support = sorted(fr_to_wis.get(requirement_id, []))
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    f"`{requirement_id}`",
                    strip_ticks(row[1]),
                    f"`{relation}`",
                    f"`{target}`",
                    markdown_ids(support),
                    strip_ticks(row[7]),
                    strip_ticks(row[6]),
                    strip_ticks(row[8]),
                    f"{strip_ticks(row[4])}; {strip_ticks(row[5])}",
                )
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## 3. DR Registry（43）",
            "",
            "| DR | Status | Relation | Targets | Decision owner | Gate | State ceiling |",
            "| --- | --- | --- | --- | --- | --- | --- |",
        ]
    )
    for decision_id in sorted(dr_rows):
        row = dr_rows[decision_id]
        status = strip_ticks(row[3])
        if status == "REJECTED":
            relation, ceiling = "ENFORCES_REJECTION", "NEGATIVE_CONTROL_ONLY"
        elif status == "EXTERNAL_REQUIRED":
            relation, ceiling = "EXTERNAL_GATE", "EXTERNAL_BLOCKED"
        elif status == "CONFIRMED":
            relation, ceiling = "GOVERNS_IMPLEMENTATION", "PRODUCT_CONFIRMED_IMPLEMENTATION_GATED"
        elif status == "DEFERRED":
            relation, ceiling = "DEFERRED_POLICY_WITH_GUARDRAILS", "BUDGET_DECISION_DEFERRED"
        else:
            relation, ceiling = "BLOCKS_OR_GUIDES", "INTERNAL_READY_MAX"
        targets = sorted(dr_to_wis.get(decision_id, []))
        if not targets:
            fallback = DR_FALLBACK_TARGETS.get(decision_id)
            if not fallback:
                raise ValueError(f"decision has no relation target: {decision_id}")
            targets = fallback.split(",")
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    f"`{decision_id}`",
                    f"`{status}`",
                    f"`{relation}`",
                    markdown_ids(targets),
                    row[7],
                    row[8],
                    f"`{ceiling}`",
                )
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## 4. Finding → CR → Package → Work Item（22）",
            "",
            "| Finding | Severity | Disposition | CR | Declared packages | Package/WI edges |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
    )
    for finding_id in sorted(finding_rows):
        row = finding_rows[finding_id]
        packages = re.findall(r"WP-[A-Z0-9-]+", row[6])
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    f"`{finding_id}`",
                    row[1],
                    row[2],
                    row[3],
                    markdown_ids(packages),
                    markdown_ids(finding_edges[finding_id]),
                )
            )
            + " |"
        )

    findings_by_cr: dict[str, list[str]] = defaultdict(list)
    for finding_id, row in finding_rows.items():
        findings_by_cr[strip_ticks(row[3])].append(finding_id)
    packages_by_cr: dict[str, list[str]] = defaultdict(list)
    for package_id, row in package_rows.items():
        packages_by_cr[strip_ticks(row[2])].append(package_id)
    lines.extend(
        [
            "",
            "## 5. CR Registry（12）",
            "",
            "| CR | Findings | Packages | Canonical outcome |",
            "| --- | --- | --- | --- |",
        ]
    )
    for risk_id in sorted(cr_rows):
        row = cr_rows[risk_id]
        lines.append(
            f"| `{risk_id}` | {markdown_ids(sorted(findings_by_cr[risk_id]))} | "
            f"{markdown_ids(sorted(packages_by_cr[risk_id]))} | {markdown_cell(row[1])} |"
        )

    work_items_by_package: dict[str, list[str]] = defaultdict(list)
    for work_item in work_items.values():
        work_items_by_package[work_item.package_id].append(work_item.work_item_id)
    lines.extend(
        [
            "",
            "## 6. Package Registry（13）",
            "",
            "| Package | Name | Primary CR | Lane / Priority | Work Items | Current package state | Authority owner role | Exit gate summary |",
            "| --- | --- | --- | --- | --- | --- | --- | --- |",
        ]
    )
    for package_id in sorted(package_rows):
        row = package_rows[package_id]
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    f"`{package_id}`",
                    row[1],
                    strip_ticks(row[2]),
                    f"{row[4]} / {row[3]}",
                    markdown_ids(sorted(work_items_by_package[package_id])),
                    strip_ticks(row[7]),
                    PACKAGE_OWNER_ROLES[package_id],
                    row[8],
                )
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## 7. Work Item Reverse Registry（115）",
            "",
            "| Work Item | Package | FR | DR | Findings | CR | Lifecycle | Decision | Ceiling | Authority owner role | Execution owner | Gates |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
        ]
    )
    for work_item_id in sorted(work_items):
        work_item = work_items[work_item_id]
        decision = "NO_GO" if work_item.package_id == "WP-MIG-01" else "STOP"
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    f"`{work_item_id}`",
                    f"`{work_item.package_id}`",
                    markdown_ids(work_item.fr_ids),
                    markdown_ids(work_item.dr_ids),
                    markdown_ids(work_item.finding_ids),
                    markdown_ids(work_item.cr_ids),
                    "`PLANNED`",
                    f"`{decision}`",
                    f"`{work_item_ceiling(work_item)}`",
                    PACKAGE_OWNER_ROLES[work_item.package_id],
                    "`UNASSIGNED`",
                    markdown_ids(work_item.gates),
                )
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## 8. Gate 与证据升级规则",
            "",
            "1. `G0/G1`只能证明内部合同和模拟器体验，不能关闭`G2–G4`。",
            "2. required gate为`OPEN/FAILED/EXPIRED/MISSING`时，Work Item不得超过本表`Ceiling`。",
            "3. `Lifecycle=PLANNED`和`Execution owner=UNASSIGNED`是当前路线事实；生成矩阵、checker通过或文档评审不能把它升级为`IN_PROGRESS/VERIFIED`。",
            "4. FR当前成熟度来自证据矩阵；没有任何FR是`PROD_VERIFIED`。Provider配置、一次smoke、generic build或模拟器均不能替代真实环境/真机/产品/法律证据。",
            "5. 权威源变化后必须重新运行生成器和独立checker；矩阵手工编辑会在下一次生成时被覆盖。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="validate gate parsing only")
    args = parser.parse_args()
    gate_parser_self_test()
    if args.self_test:
        print("PASS generate-product-v4-traceability-matrix gate parser self-test")
        return
    OUTPUT.write_text(render(), encoding="utf-8")
    print(f"generated {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
