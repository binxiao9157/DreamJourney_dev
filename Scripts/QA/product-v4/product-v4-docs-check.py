#!/usr/bin/env python3

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs" / "product"

SPEC = PRODUCT / "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
MATRIX = PRODUCT / "DreamJourney_V4_当前实现证据矩阵_V1.0.md"
REGISTER = PRODUCT / "DreamJourney_V4_产品决策登记册_V1.0.md"
REVIEW = PRODUCT / "DreamJourney_V4_Round2_独立评审响应_V1.0.md"

SOURCE_DOCS = {
    PRODUCT / "Hermes-Skills-All_AOS-Memory_Analysis.md": "STATIC_ANALYSIS_INPUT",
    PRODUCT / "寻梦环游_iOS工程_PRD_目标架构一致性分析_V1.0.md": "HISTORICAL_ANALYSIS_INPUT",
    PRODUCT / "寻梦环游_个人记忆库与数字分身平台_PRD_V1.0.md": "PRD_WORKING_INPUT",
    PRODUCT / "DreamJourney_V3_产品蓝图_Product_Blueprint_V3.0.md": "BLUEPRINT_WORKING_INPUT",
}

ALLOWED_DECISION_STATUSES = {
    "CONFIRMED",
    "RECOMMENDED_PENDING",
    "EXTERNAL_REQUIRED",
    "DEFERRED",
    "REJECTED",
}

ALLOWED_REVIEW_STATUSES = {
    "ACCEPTED",
    "PARTIALLY_ACCEPTED",
    "DECISION_REGISTERED",
    "REJECTED_WITH_REASON",
}


def fail(message: str) -> None:
    print(f"Product V4 docs check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: Path) -> str:
    if not path.is_file():
        fail(f"missing file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def ids(pattern: str, text: str) -> set[str]:
    return set(re.findall(pattern, text))


def main() -> None:
    spec = read(SPEC)
    matrix = read(MATRIX)
    register = read(REGISTER)
    review = read(REVIEW)

    expected_fr = ids(r"FR-[A-Z]+-\d{3}", matrix)
    spec_fr = ids(r"FR-[A-Z]+-\d{3}", spec)
    if len(expected_fr) != 36 or spec_fr != expected_fr:
        fail(
            f"FR coverage mismatch: matrix={len(expected_fr)} spec={len(spec_fr)} "
            f"missing={sorted(expected_fr - spec_fr)} extra={sorted(spec_fr - expected_fr)}"
        )

    expected_conflicts = {f"C-{number:02d}" for number in range(1, 22)}
    matrix_conflicts = ids(r"(?<![A-Z])C-\d{2}\b", matrix)
    register_conflicts = ids(r"(?<![A-Z])C-\d{2}\b", register)
    if matrix_conflicts != expected_conflicts or register_conflicts != expected_conflicts:
        fail(
            "conflict coverage mismatch: "
            f"matrix_missing={sorted(expected_conflicts - matrix_conflicts)} "
            f"register_missing={sorted(expected_conflicts - register_conflicts)}"
        )

    rows = [
        line
        for line in register.splitlines()
        if re.match(r"\| DR-\d{3} \|", line)
    ]
    decision_ids = [re.match(r"\| (DR-\d{3}) \|", row).group(1) for row in rows]
    required_decisions = {f"DR-{number:03d}" for number in range(1, 44)}
    if len(decision_ids) != len(set(decision_ids)):
        fail("duplicate decision ID")
    if set(decision_ids) != required_decisions:
        fail(
            "decision ID set mismatch: "
            f"missing={sorted(required_decisions - set(decision_ids))} "
            f"extra={sorted(set(decision_ids) - required_decisions)}"
        )

    confirmed = set()
    for row in rows:
        columns = [column.strip() for column in row.strip("|").split("|")]
        if len(columns) != 9:
            fail(f"decision row must have 9 columns: {row}")
        decision_id = columns[0]
        match = re.search(r"`([A-Z_]+)`", columns[3])
        if not match or match.group(1) not in ALLOWED_DECISION_STATUSES:
            fail(f"invalid status for {decision_id}: {columns[3]}")
        if match.group(1) == "CONFIRMED":
            confirmed.add(decision_id)
        for index, value in enumerate(columns):
            if not value:
                fail(f"empty column {index + 1} for {decision_id}")

    expected_confirmed = {
        "DR-001", "DR-002", "DR-003", "DR-004", "DR-005", "DR-006",
        "DR-007", "DR-008", "DR-010", "DR-011", "DR-013", "DR-014",
        "DR-015", "DR-016", "DR-019", "DR-023", "DR-024", "DR-025",
        "DR-028", "DR-029", "DR-030", "DR-032", "DR-033", "DR-037",
        "DR-038", "DR-039", "DR-040", "DR-041", "DR-042", "DR-043",
    }
    if confirmed != expected_confirmed:
        fail(
            "CONFIRMED decisions changed without updating the E2 guard: "
            f"{sorted(confirmed)}"
        )

    required_review_ids = {
        *(f"PV-{number:02d}" for number in range(1, 8)),
        *(f"DM-{number:02d}" for number in range(1, 8)),
        *(f"CR-{number:02d}" for number in range(1, 11)),
        *(f"RV-{number:02d}" for number in range(1, 20)),
    }
    review_rows = [
        line
        for line in review.splitlines()
        if re.match(r"\| (?:PV|DM|CR|RV)-\d{2} \|", line)
    ]
    review_ids = [
        re.match(r"\| ((?:PV|DM|CR|RV)-\d{2}) \|", row).group(1)
        for row in review_rows
    ]
    if len(review_ids) != len(set(review_ids)):
        fail("duplicate review response ID")
    if not required_review_ids.issubset(set(review_ids)):
        fail(f"missing review responses: {sorted(required_review_ids - set(review_ids))}")
    for row in review_rows:
        columns = [column.strip() for column in row.strip("|").split("|")]
        if len(columns) != 6:
            fail(f"review row must have 6 columns: {row}")
        match = re.search(r"`([A-Z_]+)`", columns[3])
        if not match or match.group(1) not in ALLOWED_REVIEW_STATUSES:
            fail(f"invalid review status for {columns[0]}: {columns[3]}")

    required_spec_sections = [
        "章节默认规则",
        "## 14. 产品能力合同与完成定义",
        "## 15. AI、检索与安全行为合同",
        "## 16. 隐私、安全与数据权利",
        "## 17. Voice 与 Digital Human 产品边界",
        "## 18. 质量属性与发布门",
        "## 19. Release policy、运营与成本",
        "## 20. 当前实现采用、冻结与替换",
        "## 21. 规格治理与开放决策",
        "DreamJourney_V4_Round2_独立评审响应_V1.0.md",
    ]
    missing_sections = [section for section in required_spec_sections if section not in spec]
    if missing_sections:
        fail(f"Product Spec incomplete: {missing_sections}")
    for stale_marker in ["后续 Round 2 待集成内容", "WTMVU", "TODO"]:
        if stale_marker in spec:
            fail(f"stale Product Spec marker: {stale_marker}")

    absolute_claims = [
        "完全可信",
        "完全可控",
        "立即彻底删除",
        "随时完全撤回",
        "不会被冒用",
        "不是机器人",
    ]
    negation_markers = [
        "禁止",
        "不得",
        "不能",
        "不承诺",
        "不使用",
        "不采用",
        "不可",
        "拒绝",
        "替换/退役",
        "当前 prompt",
    ]
    for line_number, line in enumerate(spec.splitlines(), start=1):
        for claim in absolute_claims:
            if claim in line and not any(marker in line for marker in negation_markers):
                fail(f"unqualified absolute claim at Product Spec line {line_number}: {claim}")

    for document in [SPEC, MATRIX, REGISTER, REVIEW]:
        document_text = read(document)
        for relative_target in re.findall(r"\[[^\]]+\]\(([^)#]+\.md)(?:#[^)]+)?\)", document_text):
            if "://" in relative_target or relative_target.startswith("/"):
                continue
            resolved = (document.parent / relative_target).resolve()
            if not resolved.is_file():
                fail(
                    f"broken Markdown link in {document.name}: "
                    f"{relative_target}"
                )

    for source_path, lifecycle in SOURCE_DOCS.items():
        source = read(source_path)
        required_markers = [
            "文档生命周期（Task 27，2026-07-12）",
            lifecycle,
            "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md",
            "DreamJourney_V4_当前实现证据矩阵_V1.0.md",
            "DreamJourney_V4_产品决策登记册_V1.0.md",
            "历史正文保留",
        ]
        missing = [marker for marker in required_markers if marker not in source]
        if missing:
            fail(f"source lifecycle incomplete for {source_path.name}: {missing}")

    for label in [
        "`FACT`",
        "`CONFIRMED`",
        "`RECOMMENDED`",
        "`DECISION_REQUIRED`",
        "`EXTERNAL_DEPENDENCY`",
    ]:
        if label not in spec:
            fail(f"missing Product Spec conclusion label: {label}")

    print(
        "Product V4 docs check passed: "
        f"{len(expected_fr)} requirements, {len(expected_conflicts)} conflicts, "
        f"{len(decision_ids)} decisions, {len(review_ids)} review responses, "
        f"{len(SOURCE_DOCS)} lifecycle banners"
    )


if __name__ == "__main__":
    main()
