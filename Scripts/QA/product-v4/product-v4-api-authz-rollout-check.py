#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def catalog_ids(text: str, prefix: str) -> list[str]:
    return re.findall(rf"^\| ({prefix}\d{{2}}) \|", text, re.MULTILINE)


def main() -> None:
    spec = SPEC.read_text()
    evidence = EVIDENCE.read_text()
    start = spec.index("## 30. Typed API、Identity/AuthZ 与 Capability Rollout")
    end = spec.index("## 31. Job、Outbox 与 Legacy Timer 迁移", start)
    chapter = spec[start:end]

    headings = [
        "### 30.0 CURRENT EVIDENCE：当前双轨会 fail-open",
        "### 30.1 EndpointDescriptor 与 Auth Mode",
        "### 30.2 Typed Client 与 Route Policy",
        "### 30.3 Strong Identity 与 Session Rollout",
        "### 30.4 AuthZ Rollout 与 Route Groups",
        "### 30.5 Capability 与 ReleasePolicy Snapshot",
        "### 30.6 Client Credential Eradication",
        "### 30.7 API/AuthZ/Capability Rollout Waves",
        "### 30.8 Client/Server Compatibility Matrix",
        "### 30.9 Error 与 Retry 合同",
        "### 30.10 API/AuthZ/Capability 验收场景",
        "### 30.11 未决与外部验收",
    ]
    for heading in headings:
        require(heading in chapter, f"API/AuthZ rollout heading missing: {heading}")

    risk_ids = catalog_ids(chapter, "X")
    auth_ids = catalog_ids(chapter, "H")
    route_ids = catalog_ids(chapter, "L")
    group_ids = catalog_ids(chapter, "G")
    wave_ids = catalog_ids(chapter, "P")
    require(risk_ids == [f"X{index:02d}" for index in range(1, 11)], "risk IDs must be X01..X10")
    require(auth_ids == [f"H{index:02d}" for index in range(1, 6)], "auth IDs must be H01..H05")
    require(route_ids == [f"L{index:02d}" for index in range(1, 6)], "route IDs must be L01..L05")
    require(group_ids == [f"G{index:02d}" for index in range(1, 10)], "group IDs must be G01..G09")
    require(wave_ids == [f"P{index:02d}" for index in range(11)], "wave IDs must be P00..P10")

    required_terms = [
        "EndpointDescriptor<Request, Response>",
        "publicChallenge",
        "userRequired",
        "delegatedGrant",
        "machineOnly",
        "operatorBreakGlass",
        "不存在 `automatic`",
        "请求发送前",
        "404 表示 resource hidden/not found",
        "Command shadow",
        "不写 aggregate、receipt/outbox/job，不调用 Provider",
        "sessionId + tokenFamilyId + generationId",
        "production deny",
        "dataAuthorityVersion",
        "providerReady / releaseVisible / externalVerified",
        "Release gate 必须扫描最终 `.app/.appex",
        "upgrade_required",
        "DR-023",
        "DR-040",
    ]
    for term in required_terms:
        require(term in chapter, f"API/AuthZ rollout term missing: {term}")

    scenario_start = chapter.index(headings[10])
    scenario_end = chapter.index(headings[11])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 18, f"API/AuthZ rollout scenarios too small: {scenario_count}")

    require("### 7.5 Round 3C2B API/AuthZ/Capability 设计状态" in evidence, "API/AuthZ evidence section missing")
    for term in (
        "H01–H05",
        "L01–L05",
        "G01–G09",
        "P00–P10",
        "`DESIGNED`",
        "`CONTRACT_ONLY`",
        "`EXTERNAL_ACCEPTANCE`",
    ):
        require(term in evidence or term in chapter, f"API/AuthZ maturity boundary missing: {term}")

    print(
        "Product V4 API/AuthZ rollout check passed: "
        f"risks={len(risk_ids)}, auth_modes={len(auth_ids)}, "
        f"route_modes={len(route_ids)}, groups={len(group_ids)}, "
        f"waves={len(wave_ids)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
