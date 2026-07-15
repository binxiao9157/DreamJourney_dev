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


def code_rows(text: str) -> list[str]:
    return [line for line in text.splitlines() if line.startswith("| `")]


def main() -> None:
    spec = SPEC.read_text()
    headings = [
        "## 26. Job、Outbox、对象存储与 Provider 合同",
        "### 26.0 CURRENT EVIDENCE：异步与外部能力尚未生产化",
        "### 26.1 Outbox 与 Job 数据合同",
        "### 26.2 Job 状态机",
        "### 26.3 Transactional Outbox 与恢复顺序",
        "### 26.4 确定性 Job 目录",
        "### 26.5 私有对象存储生命周期",
        "### 26.6 通用 Provider Port",
        "### 26.7 Provider 适配矩阵",
        "### 26.8 业务完成与 Provider 完成语义",
        "### 26.9 安全、成本与可观察性",
        "### 26.10 Job/Object/Provider 验收场景",
    ]
    for heading in headings:
        require(heading in spec, f"job/provider heading missing: {heading}")

    contract = section(spec, headings[0], "## 27. Legacy 数据目录与确定性 Backfill 合同")
    for term in (
        "outbox_events",
        "dedupe_key",
        "lease_owner/until",
        "work_authorization_id",
        "FOR UPDATE SKIP LOCKED",
        "reconciling",
        "providerRequestId",
        "consumer_receipts",
        "provider_receipts",
        "unknownOutcome",
        "skippedAuthorizationRevoked",
        "partiallyDelivered",
    ):
        require(term in contract, f"job/provider term missing: {term}")

    jobs = section(spec, headings[5], headings[6])
    job_rows = code_rows(jobs)
    require(len(job_rows) >= 8, f"job catalog rows too small: {len(job_rows)}")

    object_contract = section(spec, headings[6], headings[7])
    for state in (
        "intent_issued",
        "uploaded_unverified",
        "quarantined",
        "verified",
        "deletion_pending",
        "deleted",
    ):
        require(state in object_contract, f"object lifecycle state missing: {state}")

    providers = section(spec, headings[8], headings[9])
    provider_rows = [
        line for line in providers.splitlines() if line.startswith("| ")
    ][2:]
    require(len(provider_rows) >= 8, f"provider rows too small: {len(provider_rows)}")

    acceptance = section(
        spec,
        headings[11],
        "## 27. Legacy 数据目录与确定性 Backfill 合同",
    )
    scenarios = sum(1 for line in acceptance.splitlines() if re.match(r"^\d+\. ", line))
    require(scenarios >= 10, f"job/provider acceptance scenarios too small: {scenarios}")

    print(
        "Product V4 job/provider check passed: "
        f"jobs={len(job_rows)}, providers={len(provider_rows)}, "
        f"acceptance_scenarios={scenarios}"
    )


if __name__ == "__main__":
    main()
