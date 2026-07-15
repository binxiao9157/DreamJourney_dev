#!/usr/bin/env python3
"""Verify Product V4 target-architecture invariants without claiming implementation."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"
SPEC = PRODUCT / "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = PRODUCT / "DreamJourney_V4_当前实现证据矩阵_V1.0.md"
DECISIONS = PRODUCT / "DreamJourney_V4_产品决策登记册_V1.0.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing document: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def chapter(text: str, number: int) -> str:
    match = re.search(rf"^## {number}\. .+$", text, re.MULTILINE)
    require(match is not None, f"missing Product Spec section {number}")
    next_match = re.search(r"^## \d+\. .+$", text[match.end():], re.MULTILINE)
    end = match.end() + next_match.start() if next_match else len(text)
    return text[match.start():end]


def table_ids(text: str, prefix: str) -> list[str]:
    return re.findall(rf"^\| ({prefix}\d{{2}}) \|", text, re.MULTILINE)


def main() -> None:
    spec = read(SPEC)
    evidence = read(EVIDENCE)
    decisions = read(DECISIONS)

    require(
        "### 18.2A Projection / Retrieval 后端 DFX 合同" in spec,
        "Projection/Retrieval DFX contract is missing",
    )
    for term in (
        "T_retrieval",
        "retrieval_request_duration_seconds",
        "projection_lag_seconds",
        "cross_vault_violation_total",
        "Recall@20",
        "100 并发突发",
    ):
        require(term in spec, f"Projection/Retrieval DFX invariant missing: {term}")

    require(
        "### 24.4A 人物记忆本体与类型化内容合同" in spec,
        "Memory Ontology architecture contract is missing",
    )
    for term in (
        "MemoryKind",
        "PerspectiveType",
        "EpistemicStatus",
        "memory_relations",
        "experience",
        "knowledge",
        "emotion",
        "PersonaProjection",
        "EmbodimentProfile",
    ):
        require(term in spec, f"Memory Ontology invariant missing: {term}")
    require(
        re.search(r"^\| DR-029 \|.*\| `CONFIRMED` \|", decisions, re.MULTILINE)
        is not None,
        "DR-029 Memory Ontology decision must be CONFIRMED",
    )
    require(
        "### 24.4B 逝者纪念人格与权利控制合同" in spec,
        "Memorial Persona architecture contract is missing",
    )
    for term in (
        "MemorialVault",
        "MemorialControllerAppointment",
        "RepresentedPersona",
        "DeceasedIntentEvidence",
        "MemorialCapabilityDecision",
        "RightsClaim",
        "ConflictHold",
        "LegalPolicyRegistry",
        "无生前明确授权的逝者 Voice/DH 当前保持 `NO_GO`",
    ):
        require(term in spec, f"Memorial Persona invariant missing: {term}")
    require(
        re.search(r"^\| DR-004 \|.*\| `CONFIRMED` \|", decisions, re.MULTILINE)
        is not None,
        "DR-004 Memorial Persona decision must be CONFIRMED",
    )

    section_numbers = [
        int(number)
        for number in re.findall(r"^## (\d+)\. ", spec, re.MULTILINE)
        if 22 <= int(number) <= 34
    ]
    require(section_numbers == list(range(22, 35)), "target architecture sections must be 22..34")

    chapters = {number: chapter(spec, number) for number in range(22, 35)}
    ios_layers = re.findall(
        r"^\| (AppShell / Composition|Feature|Domain|Application / Repository|Infrastructure|Runtime Adapter) \|",
        chapters[22],
        re.MULTILINE,
    )
    require(
        ios_layers
        == [
            "AppShell / Composition",
            "Feature",
            "Domain",
            "Application / Repository",
            "Infrastructure",
            "Runtime Adapter",
        ],
        "iOS architecture must preserve the exact six ordered layers",
    )

    backend_modules = re.findall(
        r"^\| (Identity / AuthZ|Persona / Consent|Source / Ingestion|Memory Review / Authority|Projection / Retrieval|Conversation / Context|Data Rights / Audit|Jobs / Notification|Publication / Visitor（MVP）|Voice / Digital Human（Voice MVP / DH Beta）|Family / Care（Family MVP / Care Future）|Time Letter（Future）) \|",
        chapters[23],
        re.MULTILINE,
    )
    require(
        backend_modules
        == [
            "Identity / AuthZ",
            "Persona / Consent",
            "Source / Ingestion",
            "Memory Review / Authority",
            "Projection / Retrieval",
            "Conversation / Context",
            "Data Rights / Audit",
            "Jobs / Notification",
            "Publication / Visitor（MVP）",
            "Voice / Digital Human（Voice MVP / DH Beta）",
            "Family / Care（Family MVP / Care Future）",
            "Time Letter（Future）",
        ],
        "backend modular-monolith ownership table drifted",
    )

    core_object_terms = [
        "SourceObject",
        "MemoryCandidate",
        "DecisionReceipt",
        "MemoryVersion",
        "Projection",
        "Citation",
        "`access_grants`",
        "`work_authorizations`",
        "Conversation",
        "`messages`",
        "Publication",
    ]
    for term in core_object_terms:
        require(term in chapters[24], f"core authority/object contract missing: {term}")
    require("Public Index" in spec, "Publication must retain an independent Public Index")
    for term in ("provider_receipts", "Job", "Outbox"):
        require(term.lower() in chapters[26].lower(), f"async/provider object contract missing: {term}")

    principals = re.findall(
        r"^\| `(user|delegated_user|visitor|machine|operator|break_glass)` \|",
        chapters[25],
        re.MULTILINE,
    )
    require(
        principals == ["user", "delegated_user", "visitor", "machine", "operator", "break_glass"],
        "principal taxonomy drifted",
    )
    authz_terms = [
        "fail closed",
        "principal/resource scope 不完整时一律 deny",
        "purpose",
        "AccessGrant",
        "WorkAuthorization",
        "不再定义可以绕过所有 policy 的通用 `system` principal",
    ]
    for term in authz_terms:
        require(term in chapters[25], f"Identity/AuthZ invariant missing: {term}")

    expected_ids = {
        (31, "J"): [f"J{number:02d}" for number in range(1, 16)],
        (31, "Q"): [f"Q{number:02d}" for number in range(11)],
        (32, "U"): [f"U{number:02d}" for number in range(1, 14)],
        (32, "O"): [f"O{number:02d}" for number in range(12)],
        (32, "Z"): [f"Z{number:02d}" for number in range(1, 9)],
        (33, "F"): [f"F{number:02d}" for number in range(1, 11)],
        (33, "V"): [f"V{number:02d}" for number in range(12)],
        (34, "C"): [f"C{number:02d}" for number in range(12)],
    }
    for (section, prefix), expected in expected_ids.items():
        actual = table_ids(chapters[section], prefix)
        require(actual == expected, f"section {section} IDs must be {expected[0]}..{expected[-1]}")

    fr_ids = set(re.findall(r"FR-[A-Z]+-\d{3}", spec))
    evidence_fr_ids = set(re.findall(r"^\| (FR-[A-Z]+-\d{3}) \|", evidence, re.MULTILINE))
    require(len(fr_ids) == 36 and fr_ids == evidence_fr_ids, "Product Spec must preserve all 36 FRs")
    decision_ids = re.findall(r"^\| (DR-\d{3}) \|", decisions, re.MULTILINE)
    require(
        decision_ids == [f"DR-{number:03d}" for number in range(1, 44)],
        "Decision Register must preserve exact DR-001..DR-043",
    )

    critical_rules = [
        "不创建第二套 migration runner、状态表或 Authority",
        "客户端 ownerId/personaId 只能作为请求上下文，不能决定 authority",
        "不暴露私人 Projection",
        "仅凭 payload `userId`",
        "iOS 只接收产品 session、signed upload intent 或 provider 明确支持的短期、最小权限 token",
        "禁止dual-send真实用户数据",
        "不能修改原 receipt 为“未发生”",
        "UNKNOWN 不是成功",
        "默认 `pause/no-go`",
    ]
    for rule in critical_rules:
        require(rule in spec, f"critical architecture prohibition missing: {rule}")

    require(
        "CONFIRMED TARGET / NOT IMPLEMENTED" in chapters[34],
        "static architecture must retain its not-implemented boundary",
    )

    print(
        "Product V4 architecture invariant check passed: "
        f"sections={len(section_numbers)}, ios_layers={len(ios_layers)}, "
        f"backend_modules={len(backend_modules)}, FRs={len(fr_ids)}, DRs={len(decision_ids)}"
    )


if __name__ == "__main__":
    main()
