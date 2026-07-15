#!/usr/bin/env python3
"""Verify Round 4C Stage 1 work items, integration order, and status honesty."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = (
    ROOT
    / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
)

PACKAGES = ("WP-S1-01", "WP-S1-02", "WP-S1-03")
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


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(ROADMAP.is_file(), f"missing roadmap: {ROADMAP.relative_to(ROOT)}")
    text = ROADMAP.read_text(encoding="utf-8")

    header = text[:900]
    require(
        "V1.2 Product Confirmed Baseline + Staged Validation + Startup Lean Profile" in header
        and "115 个 Work Item" in header,
        "roadmap header must report the July 15 product-confirmed state",
    )
    require(
        "产品范围已确认不代表工程实现" in header
        and "当前 Operating Profile" in header,
        "roadmap header must retain the product-confirmation and implementation boundary",
    )
    require(
        "已合入33项/528字段；工程仍为`STOP/PLANNED`" in text,
        "Round 4C delivery status must remain distinct from implementation status",
    )

    headings = re.findall(r"^### `(WI-S1-(?:01|02|03)-\d{2})`", text, re.MULTILINE)
    expected_counts = {1: 12, 2: 11, 3: 10}
    expected = [
        f"WI-S1-{package:02d}-{number:02d}"
        for package, count in expected_counts.items()
        for number in range(1, count + 1)
    ]
    require(headings == expected, "Stage 1 work item headings must be exact and ordered")
    require(len(headings) == len(set(headings)) == 33, "Stage 1 IDs must be unique")

    for index, work_item in enumerate(headings):
        start = text.index(f"### `{work_item}`")
        if index + 1 < len(headings):
            end = text.index(f"### `{headings[index + 1]}`", start)
        else:
            end = text.index("### 17.1", start)
        block = text[start:end]
        for field in FIELDS:
            require(
                f"**{field}**" in block,
                f"{work_item} is missing required field: {field}",
            )

    package_rows = [
        line
        for line in text.splitlines()
        if re.match(r"^\| `WP-S1-0[123]` \| `STOP` \|", line)
    ]
    require(len(package_rows) == 3, "all three Stage 1 packages must remain STOP")
    require(all("`PLANNED`" in row for row in package_rows), "Stage 1 cannot be marked implemented")

    for batch in ("S1-0 Testable Seams", "S1-1 Capture & Effect Kernel", "S1-2 Review & Version", "S1-3 Projection & Text QA", "S1-4 Business Effects & Runtime", "S1-5 Migration & Cutover"):
        require(batch in text, f"missing Stage 1 integration batch: {batch}")

    required_rules = (
        "Stage 1 确定性下一任务规则",
        "Stage 1 Stop-the-Line",
        "一次只切一个Authority或Runtime owner",
        "任一扩展能力故障导致 Owner 文字",
        "G0/G1/generic build被用来宣称G2 Postgres、G3 Provider或G4真机",
    )
    for rule in required_rules:
        require(rule in text, f"missing Stage 1 integration invariant: {rule}")

    require(
        "任一扩展能力故障导致 Owner 文字" in text,
        "MVP extension/Beta lanes must not block the Owner text degradation path",
    )
    for work_item in ("WI-S1-01-11", "WI-S1-01-12", "WI-S1-02-11"):
        require(work_item in text, f"missing post-core Persona/media work item: {work_item}")
    require(
        "全部关闭时Owner文字Capture→Review→QA→Correction→Rights仍必须通过" in text,
        "Persona/media work items must not block the Owner text core",
    )
    require("mock/local-only/临时URL被标为uploaded或verified" in text, "mock upload stop-line missing")
    require(
        "ExtractionResult/模型标签直接成为confirmed Memory/Persona" in text,
        "processor direct-confirm stop-line missing",
    )
    require(
        "Stage 1、Optional/Migration 与追踪验收待 Round 4C–4E 合入" not in text,
        "stale Round 4C pending status remains in the roadmap",
    )

    print(
        "Product V4 Stage 1 roadmap check passed: "
        f"packages={len(PACKAGES)}, work_items={len(headings)}, fields={len(headings) * len(FIELDS)}, batches=6"
    )


if __name__ == "__main__":
    main()
