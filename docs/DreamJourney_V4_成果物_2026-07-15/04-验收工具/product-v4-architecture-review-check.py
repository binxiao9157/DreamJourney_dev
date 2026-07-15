#!/usr/bin/env python3
"""Verify Round 3 independent-review coverage and disposition closure."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"

SPEC = PRODUCT / "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = PRODUCT / "DreamJourney_V4_当前实现证据矩阵_V1.0.md"
DECISIONS = PRODUCT / "DreamJourney_V4_产品决策登记册_V1.0.md"
RESPONSE = PRODUCT / "DreamJourney_V4_Round3_独立架构评审响应_V1.0.md"

REPORTS = {
    "IAR": PRODUCT / "DreamJourney_V4_Round3_iOS独立评审_V1.0.md",
    "BAR": PRODUCT / "DreamJourney_V4_Round3_后端独立评审_V1.0.md",
    "SOR": PRODUCT / "DreamJourney_V4_Round3_安全隐私运维独立评审_V1.0.md",
}
EXPECTED_IDS = [
    *(f"IAR-{number:02d}" for number in range(1, 8)),
    *(f"BAR-{number:02d}" for number in range(1, 8)),
    *(f"SOR-{number:02d}" for number in range(1, 9)),
]
EXPECTED_RISKS = {f"CR-{number:02d}" for number in range(1, 13)}
EXPECTED_PACKAGES = {
    "WP-S0-01",
    "WP-S0-02",
    "WP-S0-03",
    "WP-S0-04",
    "WP-S0-05",
    "WP-S0-06",
    "WP-S0-07",
    "WP-S1-01",
    "WP-S1-02",
    "WP-S1-03",
    "WP-S3-01",
    "WP-V0-01",
    "WP-MIG-01",
}
ALLOWED_DISPOSITIONS = {
    "ACCEPTED_SPEC_FIX",
    "ACCEPTED_IMPLEMENTATION_GAP",
    "ACCEPTED_EXTERNAL_GATE",
    "PARTIALLY_ACCEPTED",
    "DUPLICATE",
    "REJECTED_WITH_EVIDENCE",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing document: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def main() -> None:
    spec = read(SPEC)
    evidence = read(EVIDENCE)
    decisions = read(DECISIONS)
    response = read(RESPONSE)

    report_severity: dict[str, str] = {}
    for prefix, path in REPORTS.items():
        text = read(path)
        findings = re.findall(
            rf"^### ({prefix}-\d{{2}}) — (BLOCKER|HIGH)：",
            text,
            re.MULTILINE,
        )
        expected = [item for item in EXPECTED_IDS if item.startswith(f"{prefix}-")]
        require(
            [finding_id for finding_id, _ in findings] == expected,
            f"{prefix} report IDs must be exact and ordered: {expected}",
        )
        report_severity.update(findings)

    response_lines = [
        line
        for line in response.splitlines()
        if re.match(r"^\| (?:IAR|BAR|SOR)-\d{2} \|", line)
    ]
    rows = [table_cells(line) for line in response_lines]
    require(len(rows) == 22, f"response must contain 22 findings, got {len(rows)}")
    require(
        [row[0] for row in rows] == EXPECTED_IDS,
        "response finding IDs must exactly match IAR-01..07, BAR-01..07, SOR-01..08",
    )

    mapped_risks: set[str] = set()
    mapped_packages: set[str] = set()
    for row in rows:
        finding_id = row[0]
        require(len(row) == 8, f"{finding_id} must have 8 business cells, got {len(row)}")
        require(all(row), f"{finding_id} contains an empty response field")
        require(row[1] == report_severity[finding_id], f"{finding_id} severity drifted")

        disposition_match = re.fullmatch(r"`([A-Z_]+)`", row[2])
        require(disposition_match is not None, f"{finding_id} disposition must be code-formatted")
        require(
            disposition_match.group(1) in ALLOWED_DISPOSITIONS,
            f"{finding_id} has invalid disposition: {row[2]}",
        )
        require(re.fullmatch(r"CR-\d{2}", row[3]) is not None, f"{finding_id} lacks canonical risk")
        mapped_risks.add(row[3])

        packages = set(re.findall(r"WP-[A-Z0-9-]+", row[6]))
        require(packages, f"{finding_id} lacks a stable Round 4 package")
        mapped_packages.update(packages)

    risk_rows = re.findall(r"^\| (CR-\d{2}) \|", response, re.MULTILINE)
    require(risk_rows == sorted(EXPECTED_RISKS), "canonical risk table must be CR-01..CR-12")
    require(mapped_risks == EXPECTED_RISKS, "every canonical risk must be used by a finding")

    risk_section_end = response.index("## 3. 22 项 Finding Disposition")
    risk_packages = set(re.findall(r"WP-[A-Z0-9-]+", response[:risk_section_end]))
    require(
        risk_packages == EXPECTED_PACKAGES,
        f"stable package set drifted: missing={sorted(EXPECTED_PACKAGES - risk_packages)}, "
        f"extra={sorted(risk_packages - EXPECTED_PACKAGES)}",
    )
    require(
        mapped_packages == EXPECTED_PACKAGES,
        "finding-to-package mappings must cover the same 13 stable packages",
    )

    require(
        re.search(r"\b(?:OPEN|TODO|UNRESOLVED)\b", response) is None,
        "review response still contains an open placeholder",
    )
    require("### 7.10 Round 3D 独立架构复审状态" in evidence, "Evidence 7.10 is missing")
    require("### 3.3 Round 3D 独立评审映射" in decisions, "Decision mapping 3.3 is missing")
    require(
        "状态：独立方案评审40项产品回复及三级验证策略确认已同步为产品范围基线" in spec
        and "工程实现、法律/供应商外部门、G2-G4与发布批准仍独立验收" in spec,
        "Product Spec header does not report the July 15 product-confirmed/implementation-gated state",
    )

    stage_zero_terms = [
        "AccountSessionActor/AccountLease",
        "禁止 `user_001`",
        "request/job-scoped Unit of Work",
        "credential inventory",
        "artifact/header/log/backup secret scan",
        "删除状态至少区分访问已撤、pending、partial、unsupported、completed",
        "operation/rights/incident/provider cost",
    ]
    for term in stage_zero_terms:
        require(term in spec[:15000], f"Stage 0 review correction missing: {term}")

    decision_ids = re.findall(r"^\| (DR-\d{3}) \|", decisions, re.MULTILINE)
    require(
        decision_ids == [f"DR-{number:03d}" for number in range(1, 44)],
        "Decision Register must preserve exact DR-001..DR-043",
    )

    print(
        "Product V4 architecture review check passed: "
        f"reports={len(report_severity)}, response={len(rows)}, "
        f"risks={len(mapped_risks)}, packages={len(mapped_packages)}"
    )


if __name__ == "__main__":
    main()
