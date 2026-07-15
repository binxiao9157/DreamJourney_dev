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


def catalog_ids(text: str, prefix: str) -> list[str]:
    return re.findall(rf"^\| ({prefix}\d{{2}}) \|", text, re.MULTILINE)


def main() -> None:
    spec = SPEC.read_text()
    evidence = EVIDENCE.read_text()
    decisions = DECISIONS.read_text()
    start = spec.index("## 29. iOS AccountSession、Generation 与本地 Store Rollout")
    end = spec.index("## 30. Typed API、Identity/AuthZ 与 Capability Rollout", start)
    chapter = spec[start:end]

    headings = [
        "### 29.0 CURRENT EVIDENCE：账号与私有状态尚未统一",
        "### 29.1 AccountSessionActor 与 AccountLease",
        "### 29.2 状态机与跨介质恢复",
        "### 29.3 异步 Lease Checkpoints",
        "### 29.4 Account-Scoped Store Envelope",
        "### 29.5 iOS Rollout Waves",
        "### 29.6 iOS Account/Store 验收场景",
        "### 29.7 未决本地保留策略",
    ]
    for heading in headings:
        require(heading in chapter, f"iOS account/store heading missing: {heading}")

    risk_ids = catalog_ids(chapter, "A")
    store_ids = catalog_ids(chapter, "S")
    wave_ids = catalog_ids(chapter, "I")
    require(risk_ids == [f"A{index:02d}" for index in range(1, 12)], "risk IDs must be A01..A11")
    require(store_ids == [f"S{index:02d}" for index in range(1, 18)], "store IDs must be S01..S17")
    require(wave_ids == [f"I{index:02d}" for index in range(9)], "wave IDs must be I00..I08")

    required_terms = [
        "AccountSessionActor",
        "AccountSessionSnapshot",
        "AccountLease",
        "generationId / generationSequence",
        "authorityEpoch",
        "AccountActivationJournal",
        "prepared → sessionSaved → storesMounted → profileCached → committed",
        "sessionId + tokenFamilyId + generation",
        "Before store commit",
        "Before UI publish",
        "legacy_unassigned",
        "“当前登录账号”“同昵称”“同文件夹”都不是证据",
        "显式 seal 才生成一次 commandId",
        "DR-041",
    ]
    for term in required_terms:
        require(term in chapter, f"iOS account/store term missing: {term}")

    scenario_start = chapter.index(headings[6])
    scenario_end = chapter.index(headings[7])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 18, f"iOS account/store scenarios too small: {scenario_count}")

    require("### 6.3 Round 3C2A iOS Account/Store 设计状态" in evidence, "iOS rollout evidence section missing")
    for term in ("S01–S17", "I00–I08", "`DESIGNED`", "`CONTRACT_ONLY`", "`DECISION_REQUIRED`"):
        require(term in evidence, f"iOS rollout maturity boundary missing: {term}")
    require("| DR-041 |" in decisions, "DR-041 local draft retention decision missing")

    print(
        "Product V4 iOS account/store rollout check passed: "
        f"risks={len(risk_ids)}, stores={len(store_ids)}, "
        f"waves={len(wave_ids)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
