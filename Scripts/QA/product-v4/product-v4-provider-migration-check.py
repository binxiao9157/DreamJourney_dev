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


def numbered_ids(text: str, prefix: str) -> list[str]:
    return re.findall(rf"^\| ({prefix}\d{{2}}) \|", text, re.MULTILINE)


def numbered_chapter(text: str, heading: str) -> str:
    start = text.index(heading)
    body_start = start + len(heading)
    next_heading = re.search(r"^## \d+\. ", text[body_start:], re.MULTILINE)
    end = body_start + next_heading.start() if next_heading else len(text)
    return text[start:end]


def main() -> None:
    spec = SPEC.read_text(encoding="utf-8")
    evidence = EVIDENCE.read_text(encoding="utf-8")
    decisions = DECISIONS.read_text(encoding="utf-8")
    chapter = numbered_chapter(
        spec, "## 33. Provider Effect、Credential 与 Exit 迁移"
    )

    headings = [
        "### 33.0 CURRENT EVIDENCE：Provider “ready”语义混合",
        "### 33.1 Provider 状态与 Receipt",
        "### 33.2 10 类 Provider Migration Matrix",
        "### 33.3 Credential Inventory、Rotation 与 Client Boundary",
        "### 33.4 Stable Request、Unknown 与 Callback Security",
        "### 33.5 Provider Test、Canary 与 Fallback Policy",
        "### 33.6 Provider Migration Waves",
        "### 33.7 Provider Exit 与 Asset Portability",
        "### 33.8 Provider 验收与故障场景",
        "### 33.9 实现阶段 UNKNOWN",
    ]
    for heading in headings:
        require(heading in chapter, f"Provider migration heading missing: {heading}")

    provider_ids = numbered_ids(chapter, "F")
    wave_ids = numbered_ids(chapter, "V")
    require(
        provider_ids == [f"F{index:02d}" for index in range(1, 11)],
        "provider IDs must be F01..F10",
    )
    require(
        wave_ids == [f"V{index:02d}" for index in range(12)],
        "provider wave IDs must be V00..V11",
    )

    required_terms = [
        "credentialValid",
        "sandboxVerified",
        "businessUsable",
        "deletionState",
        "providerRequestId",
        "credentialVersion",
        "candidate/active_for_new/draining_old/revoked/compromised",
        "static token不失效，不算短期",
        "unknown/manual_review/dead_letter",
        "禁止dual-send真实用户数据",
        "Callback验证TLS",
        "nonce唯一",
        "single-provider canary",
        "DR-026/027/028/031/037/039",
        "不新增产品确认",
    ]
    for term in required_terms:
        require(term in chapter, f"Provider migration term missing: {term}")

    scenario_start = chapter.index(headings[8])
    scenario_end = chapter.index(headings[9])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 20, f"Provider scenarios too small: {scenario_count}")

    evidence_heading = "### 7.8 Round 3C3C Provider 设计状态"
    require(evidence_heading in evidence, "Provider evidence section missing")
    evidence_chapter = evidence[evidence.index(evidence_heading):]
    for term in (
        "Provider state/receipt",
        "F01–F10 Provider matrix",
        "V00–V11 migration waves",
        "Delete/exit/asset portability",
        "Provider quality/device outcome",
        "`DESIGNED`",
        "`CONTRACT_ONLY`",
        "`EXTERNAL_ACCEPTANCE`",
        "2026-07-15 已确认 DR-028/037/039",
        "DR-026/031 仍为外部门",
        "DR-027 的精确预算暂缓",
    ):
        require(term in evidence_chapter, f"Provider evidence boundary missing: {term}")

    decision_heading = "### 3.1 Round 3C3C Provider 决策映射"
    require(decision_heading in decisions, "Provider decision mapping missing")
    decision_section = decisions[decisions.index(decision_heading):]
    for decision_id in ("DR-026", "DR-027", "DR-028", "DR-031", "DR-037", "DR-039"):
        require(decision_id in decision_section, f"Provider decision mapping missing: {decision_id}")
    require(
        "不能由设计或静态检查替代" in decision_section,
        "Provider product confirmation must preserve external evidence gates",
    )

    print(
        "Product V4 Provider migration check passed: "
        f"providers={len(provider_ids)}, waves={len(wave_ids)}, "
        f"scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
