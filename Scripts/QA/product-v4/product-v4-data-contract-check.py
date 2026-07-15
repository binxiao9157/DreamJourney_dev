#!/usr/bin/env python3

import re
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(text: str, start: str, end: Optional[str] = None) -> str:
    start_index = text.index(start)
    if end is None:
        return text[start_index:]
    return text[start_index:text.index(end, start_index)]


def table_rows(text: str) -> list[str]:
    return [line for line in text.splitlines() if line.startswith("| `")]


def main() -> None:
    spec = SPEC.read_text()
    headings = [
        "## 24. 核心数据与 Authority 合同",
        "### 24.1 通用关系约束",
        "### 24.2 Identity、Vault 与授权数据",
        "### 24.3 Source 与处理结果",
        "### 24.4 Candidate、Decision 与 Memory Version",
        "### 24.4A 人物记忆本体与类型化内容合同",
        "### 24.4B 逝者纪念人格与权利控制合同",
        "### 24.5 Conversation、Answer 与 Citation",
        "### 24.6 Projection 与检索数据",
        "### 24.7 Data Rights、删除与审计数据",
        "### 24.8 Extension Domain 的独立数据边界",
        "### 24.9 Legacy 数据映射规则",
        "### 24.10 数据合同验收场景",
    ]
    for heading in headings:
        require(heading in spec, f"data contract heading missing: {heading}")

    data_contract = section(spec, headings[0], "## 25. Identity、AuthZ 与 `/v2` API 合同")
    rows = table_rows(data_contract)
    require(len(rows) >= 30, f"logical data object rows too small: {len(rows)}")

    required_terms = [
        "vault_id",
        "owner_subject_id",
        "UNIQUE (vault_id, id)",
        "FOREIGN KEY (vault_id, source_id)",
        "memory_candidates",
        "candidate_evidence",
        "decision_receipts",
        "memory_versions",
        "memory_relations",
        "correction_links",
        "MemoryKind",
        "PerspectiveType",
        "EpistemicStatus",
        "experience",
        "knowledge",
        "emotion",
        "PersonaProjection",
        "EmbodimentProfile",
        "memorial_controller_appointments",
        "kinship_death_verifications",
        "deceased_intent_evidence",
        "memorial_capability_decisions",
        "memorial_rights_claims",
        "memorial_conflict_holds",
        "citations",
        "data_rights_authorizations",
        "resource_deletion_receipts",
        "legacy_needs_review",
        "authority_epoch",
    ]
    for term in required_terms:
        require(term in data_contract, f"data contract term missing: {term}")

    optional = section(
        spec,
        "### 24.8 Extension Domain 的独立数据边界",
        "### 24.9 Legacy 数据映射规则",
    )
    for domain in ("Publication/Visitor", "Voice/DH", "Family/Care", "TimeLetter"):
        require(domain in optional, f"optional data boundary missing: {domain}")

    acceptance = section(
        spec,
        "### 24.10 数据合同验收场景",
        "## 25. Identity、AuthZ 与 `/v2` API 合同",
    )
    scenario_count = sum(1 for line in acceptance.splitlines() if re.match(r"^\d+\. ", line))
    require(scenario_count >= 8, f"data contract acceptance scenarios too small: {scenario_count}")

    print(
        "Product V4 data contract check passed: "
        f"logical_rows={len(rows)}, acceptance_scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
