#!/usr/bin/env python3
"""Verify that Product V4 evidence covers every PRD requirement exactly once."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRD = ROOT / "docs/product/寻梦环游_个人记忆库与数字分身平台_PRD_V1.0.md"
MATRIX = ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"
REQUIREMENT_PATTERN = re.compile(r"FR-[A-Z]+-[0-9]{3}")
ALLOWED_MATURITY = {
    "PROD_VERIFIED",
    "IMPLEMENTED",
    "CONTRACT_ONLY",
    "MOCK_ONLY",
    "PARTIAL",
    "MISSING",
}
ALLOWED_EXPOSURE = {
    "PUBLIC_PARTIAL",
    "BETA_UNVERIFIED",
    "HIDDEN_QA",
    "DISABLED",
    "CROSS_CUTTING",
}
ALLOWED_PRIMARY_STAGES = {
    "M0 Identity",
    "M0 Family Contribution",
    "M0 Stage 2 Media",
    "M0 Data Rights",
    "M0 Owner Truth",
    "M1 Living Self Voice",
    "M2 Publication/Visitor",
    "M3/M4 Deferred",
    "Cross-cutting Operations",
}


def fail(message: str) -> None:
    raise SystemExit(f"product-v4-evidence-matrix-check failed: {message}")


def matrix_rows(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        if not re.match(r"^\| FR-[A-Z]+-[0-9]{3} \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 10:
            fail(f"expected 10 cells for {cells[0]}, got {len(cells)}")
        rows.append(cells)
    return rows


def main() -> None:
    if not PRD.is_file() or not MATRIX.is_file():
        fail("PRD or evidence matrix is missing")

    prd_ids = sorted(set(REQUIREMENT_PATTERN.findall(PRD.read_text(encoding="utf-8"))))
    matrix_text = MATRIX.read_text(encoding="utf-8")
    rows = matrix_rows(matrix_text)
    matrix_ids = [row[0] for row in rows]
    duplicates = sorted(key for key, count in Counter(matrix_ids).items() if count > 1)

    if duplicates:
        fail(f"duplicate requirement rows: {duplicates}")
    if sorted(matrix_ids) != prd_ids:
        missing = sorted(set(prd_ids) - set(matrix_ids))
        extra = sorted(set(matrix_ids) - set(prd_ids))
        fail(f"requirement mismatch; missing={missing}, extra={extra}")
    for row in rows:
        (
            requirement,
            _,
            _,
            _,
            decision_gate,
            external_gate,
            exposure,
            maturity,
            stage,
            gap,
        ) = row
        if any("\u5f85\u5ba1\u8ba1" in cell for cell in row):
            fail(f"matrix row still contains audit placeholders: {requirement}")
        normalized_maturity = maturity.strip("`")
        if normalized_maturity not in ALLOWED_MATURITY:
            fail(f"invalid maturity for {requirement}: {maturity}")
        if exposure not in ALLOWED_EXPOSURE:
            fail(f"invalid exposure for {requirement}: {exposure}")
        if stage not in ALLOWED_PRIMARY_STAGES:
            fail(f"invalid primary stage for {requirement}: {stage}")
        if not decision_gate or not external_gate or not gap:
            fail(f"missing decision/external gate or gap for {requirement}")

    print(f"Product V4 evidence matrix check passed: {len(rows)} requirements")


if __name__ == "__main__":
    main()
