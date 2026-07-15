#!/usr/bin/env python3
"""Validate canonical roadmap IDs, critical trace edges, and total WI structure."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
REGISTER = ROOT / "docs/product/DreamJourney_V4_产品决策登记册_V1.0.md"
REVIEW = ROOT / "docs/product/DreamJourney_V4_Round3_独立架构评审响应_V1.0.md"

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


def work_item_block(text: str, work_item_id: str) -> str:
    marker = f"### `{work_item_id}`"
    start = text.index(marker)
    match = re.search(r"^### |^## ", text[start + len(marker) :], re.MULTILINE)
    end = start + len(marker) + match.start() if match else len(text)
    return text[start:end]


def expanded_finding_ids(text: str) -> set[str]:
    result: set[str] = set()
    for match in re.finditer(r"\b(IAR|BAR|SOR)-(\d{2})((?:/\d{2})*)", text):
        prefix, first, suffix = match.groups()
        result.add(f"{prefix}-{first}")
        result.update(f"{prefix}-{part}" for part in suffix.split("/") if part)
    return result


def validate(text: str) -> list[str]:
    errors: list[str] = []
    spec = SPEC.read_text(encoding="utf-8")
    register = REGISTER.read_text(encoding="utf-8")
    review = REVIEW.read_text(encoding="utf-8")

    canonical_fr = set(re.findall(r"\bFR-[A-Z]+-\d{3}\b", spec))
    canonical_dr = set(re.findall(r"\bDR-\d{3}\b", register))
    canonical_findings = set(re.findall(r"\b(?:IAR|BAR|SOR)-\d{2}\b", review))
    if len(canonical_fr) != 36:
        errors.append(f"E_FR_AUTHORITY_COUNT:{len(canonical_fr)}")
    if len(canonical_dr) != 43:
        errors.append(f"E_DR_AUTHORITY_COUNT:{len(canonical_dr)}")
    if len(canonical_findings) != 22:
        errors.append(f"E_FINDING_AUTHORITY_COUNT:{len(canonical_findings)}")

    exact_fr = set(re.findall(r"\bFR-[A-Z]+-\d{3}\b", text))
    fr_like = set(re.findall(r"\bFR-[A-Z]+(?:-\d{3})?(?:\.\.\d{3})?", text))
    extra_fr = sorted(fr_like - canonical_fr)
    missing_fr = sorted(canonical_fr - exact_fr)
    if extra_fr:
        errors.append(f"E_FR_EXTRA:{','.join(extra_fr)}")
    if missing_fr:
        errors.append(f"E_FR_MISSING:{','.join(missing_fr)}")
    if re.search(r"\bFR-[A-Z]+-\d{3}(?:/|\.\.)", text):
        errors.append("E_FR_SHORTHAND")
    if re.search(r"\bFR-[A-Z]+\b(?!-\d{3})", text):
        errors.append("E_FR_GENERIC")

    exact_dr = set(re.findall(r"\bDR-\d{3}\b", text))
    extra_dr = sorted(exact_dr - canonical_dr)
    if extra_dr:
        errors.append(f"E_DR_EXTRA:{','.join(extra_dr)}")

    expanded_findings = expanded_finding_ids(text)
    extra_findings = sorted(expanded_findings - canonical_findings)
    if extra_findings:
        errors.append(f"E_FINDING_EXTRA:{','.join(extra_findings)}")

    headings = re.findall(r"^### `(WI-[A-Z0-9-]+)`", text, re.MULTILINE)
    if len(headings) != 115 or len(set(headings)) != 115:
        errors.append(f"E_WI_COUNT:{len(headings)}/{len(set(headings))}")
    field_count = 0
    for work_item_id in headings:
        block = work_item_block(text, work_item_id)
        fields = re.findall(r"^- \*\*([^*]+)\*\*：", block, re.MULTILINE)
        field_count += len(fields)
        if tuple(fields) != FIELDS:
            errors.append(f"E_WI_FIELDS:{work_item_id}:{len(fields)}")
    if field_count != 1840:
        errors.append(f"E_FIELD_COUNT:{field_count}")
    if "115 个 Work Item / 1840 个必填字段" not in text:
        errors.append("E_DECLARED_TOTAL")

    required_rows = (
        "| `FR-ACC-001` | `PRIMARY_WI` | `WI-S0-02-01` |",
        "| `FR-SAFE-001` | `PRIMARY_WI` | `WI-S0-06-09` |",
        "| `FR-SAFE-002` | `PRIMARY_WI` | `WI-S3-01-06` |",
        "| `FR-MEM-003` | `DEFERRED_BY_GATE` | `STAGE4-VALUE-REENTRY` |",
        "| `FR-MEM-004` | `DEFERRED_BY_GATE` | `STAGE4-VALUE-REENTRY` |",
        "| `IAR-06` | `IMPLEMENTED_BY` | `WI-S1-01-09` |",
        "| `IAR-06` | `MIGRATION_GATED_BY` | `WI-MIG-01-08` |",
        "| `IAR-07` | `IMPLEMENTED_BY` | `WI-S1-03-10` |",
        "| `SOR-04` | `EXTERNAL_GATE` | `WI-V0-01-11` |",
        "| `DR-012` | `ENFORCES_REJECTION` | `SCOPE-AOS-COMPONENTS` |",
    )
    for row in required_rows:
        if row not in text:
            errors.append(f"E_TRACE_ROW:{row.split('|')[1].strip()}")

    critical_edges = {
        "WI-S0-02-01": "FR-ACC-001",
        "WI-S0-06-09": "FR-SAFE-001",
        "WI-S3-01-06": "FR-SAFE-002",
        "WI-S1-01-09": "IAR-06",
        "WI-MIG-01-08": "IAR-06",
        "WI-S1-03-10": "IAR-07",
        "WI-V0-01-11": "SOR-04",
    }
    for work_item_id, required_id in critical_edges.items():
        if required_id not in work_item_block(text, work_item_id):
            errors.append(f"E_CRITICAL_EDGE:{required_id}->{work_item_id}")

    voice_start = text.index("## 19. `WP-V0-01`")
    voice_end = text.index("## 20. `WP-MIG-01`", voice_start)
    if "DR-012" in text[voice_start:voice_end]:
        errors.append("E_DR012_VOICE_MISUSE")
    if "`DR-012`不得出现在Voice/DH Work Item" not in text:
        errors.append("E_DR012_REJECTION_RULE")

    return errors


def run_self_test(text: str) -> None:
    mutations = {
        "noncanonical_fr": text.replace("SCOPE-DIGITAL-HUMAN", "FR-DH-001", 1),
        "dr012_voice": text.replace("## 19. `WP-V0-01`", "## 19. `WP-V0-01`\n\nDR-012", 1),
        "missing_edge": text.replace("IAR-06", "IAR-05"),
        "wrong_total": text.replace("115 个 Work Item / 1840 个必填字段", "114 个 Work Item / 1824 个必填字段", 1),
    }
    for name, mutated in mutations.items():
        if not validate(mutated):
            raise AssertionError(f"negative fixture unexpectedly passed: {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    text = ROADMAP.read_text(encoding="utf-8")
    errors = validate(text)
    if errors:
        raise AssertionError("\n".join(errors))
    if args.self_test:
        run_self_test(text)
    print(
        "Product V4 canonical roadmap check passed: "
        "FRs=36, DRs=43-authority, findings=22-authority, work_items=115, fields=1840"
    )


if __name__ == "__main__":
    main()
