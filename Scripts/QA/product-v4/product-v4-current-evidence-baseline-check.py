#!/usr/bin/env python3
"""Guard the current V4 evidence snapshot against stale audit baselines."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MATRIX = ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"
PLAN = (
    ROOT
    / "docs/superpowers/plans/2026-08-09-dreamjourney-v4-complete-functional-development-plan.md"
)
SCAN = (
    ROOT
    / "docs/superpowers/status/2026-08-09-v4-full-engineering-gap-scan.md"
)

CURRENT_MARKERS = (
    "版本：V1.5 Current Engineering Refresh",
    "更新日期：2026-08-09",
    "feature/prd-stitch-ui-adaptation@dfd55c82",
    "Backend `main@8a61720`",
    "migration head `0085`",
    "workspace 296 项通过",
    "1973 项通过",
    "26/26 通过",
    "`RELEASE_NO_GO`",
    "configured but broker blocked",
    "2026-07-16 历史 iOS 审计",
    "2026-07-16 历史后端审计",
)

EXPECTED_REQUIREMENTS = {
    "FR-ACC-001": ("PARTIAL", "M0 Identity", "真实新用户当前不能登录"),
    "FR-SRC-001": ("IMPLEMENTED", "M0 Stage 2 Media", "等待真实腾讯 COS"),
    "FR-CHAT-001": ("IMPLEMENTED", "M0 Owner Truth", "尚未公开"),
    "FR-MEM-001": ("IMPLEMENTED", "M0 Owner Truth", "人工确认后"),
    "FR-QA-001": ("PARTIAL", "M0 Owner Truth", "旧 /context/build"),
    "FR-PRIV-004": ("IMPLEMENTED", "M0 Data Rights", "真实媒体字节等待 COS"),
    "FR-VOICE-001": ("PARTIAL", "M1 Living Self Voice", "identityLivenessProviderUnavailable"),
    "FR-PUB-001": ("IMPLEMENTED", "M2 Publication/Visitor", "发布政策仍 externalBlocked"),
    "FR-OPS-001": ("IMPLEMENTED", "Cross-cutting Operations", "生产 Worker/scheduler disabled"),
}


def fail(message: str) -> None:
    raise SystemExit(f"product-v4-current-evidence-baseline-check failed: {message}")


def requirement_rows(text: str) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for line in text.splitlines():
        if not re.match(r"^\| FR-[A-Z]+-[0-9]{3} \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 10:
            fail(f"invalid requirement row width for {cells[0]}")
        result[cells[0]] = cells
    return result


def main() -> None:
    for path in (MATRIX, PLAN, SCAN):
        if not path.is_file():
            fail(f"required evidence file is missing: {path.relative_to(ROOT)}")

    text = MATRIX.read_text(encoding="utf-8")
    current_section = text.split("## 1. 使用规则", maxsplit=1)[0]
    for marker in CURRENT_MARKERS:
        if marker not in text:
            fail(f"current marker is missing: {marker}")

    for stale_marker in (
        "版本：V1.4 Guided Interview Target / Implementation Evidence Unchanged",
        "更新日期：2026-07-16\n状态：",
        "工程基线：iOS `feature/prd-stitch-ui-adaptation@8a1922b`",
    ):
        if stale_marker in current_section:
            fail(f"stale marker leaked into current header: {stale_marker}")

    rows = requirement_rows(text)
    if len(rows) != 36:
        fail(f"expected 36 current requirement rows, got {len(rows)}")

    for requirement, (maturity, stage, evidence) in EXPECTED_REQUIREMENTS.items():
        row = rows.get(requirement)
        if row is None:
            fail(f"current requirement row is missing: {requirement}")
        if row[7].strip("`") != maturity:
            fail(f"unexpected maturity for {requirement}: {row[7]}")
        if row[8] != stage:
            fail(f"unexpected stage for {requirement}: {row[8]}")
        if evidence not in row[9]:
            fail(f"current evidence is missing for {requirement}: {evidence}")

    if text.index("## 0. 2026-08-09 当前证据快照") > text.index("## 1. 使用规则"):
        fail("current snapshot must precede usage and historical sections")

    print(
        "Product V4 current evidence baseline check passed: "
        f"{len(rows)} requirements at iOS dfd55c82 / backend 8a61720"
    )


if __name__ == "__main__":
    main()
