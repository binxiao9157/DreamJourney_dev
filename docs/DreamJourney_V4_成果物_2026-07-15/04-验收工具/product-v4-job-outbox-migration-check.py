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
    start = spec.index("## 31. Job、Outbox 与 Legacy Timer 迁移")
    end = spec.index("## 32. 对象存储与媒体迁移", start)
    chapter = spec[start:end]

    headings = [
        "### 31.0 CURRENT EVIDENCE：没有统一异步执行 Authority",
        "### 31.1 Scheduler Lease 与 Job Family Ownership",
        "### 31.2 15 类 Job 的 Legacy Migration Catalog",
        "### 31.3 Transactional Outbox Migration",
        "### 31.4 Job/Timer Migration Waves",
        "### 31.5 Pause、Rollback 与 Retirement",
        "### 31.6 可观察性与 Go/No-Go",
        "### 31.7 Job/Outbox/Timer 验收场景",
        "### 31.8 实现阶段 UNKNOWN",
    ]
    for heading in headings:
        require(heading in chapter, f"Job/Outbox migration heading missing: {heading}")

    job_ids = catalog_ids(chapter, "J")
    wave_ids = catalog_ids(chapter, "Q")
    require(job_ids == [f"J{index:02d}" for index in range(1, 16)], "job IDs must be J01..J15")
    require(wave_ids == [f"Q{index:02d}" for index in range(11)], "wave IDs must be Q00..Q10")

    target_jobs = [
        "sourceObjectVerify",
        "sourceObjectScan",
        "sourceExtraction",
        "candidateProposal",
        "projectionRebuild",
        "timeLetterDispatch",
        "echoDelayedReply",
        "rightsExport",
        "rightsDelete",
        "voiceCloneTrain",
        "voiceCloneDelete",
        "ttsSynthesis",
        "digitalHumanCleanup",
        "notificationDelivery",
        "providerReconcile",
    ]
    for job in target_jobs:
        require(f"`{job}`" in chapter, f"job migration missing: {job}")

    required_terms = [
        "scheduler_leases",
        "job_family_cutovers",
        "shadow_consumer_receipts",
        "每 family 一个 active generation",
        "Scheduler 只发现 due resource 并创建 deduped Job",
        "Shadow 只能验证",
        "禁止写业务表、Inbox、Job active state、Provider request",
        "business receipt completeness",
        "legacy timer drain/no-op/release generation",
        "不得重新启会直接执行同effect的旧timer",
        "authorityEpoch",
        "UNKNOWN",
    ]
    for term in required_terms:
        require(term in chapter, f"Job/Outbox migration term missing: {term}")

    scenario_start = chapter.index(headings[7])
    scenario_end = chapter.index(headings[8])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 16, f"Job/Outbox scenarios too small: {scenario_count}")

    require("### 7.6 Round 3C3A Job/Outbox/Timer 设计状态" in evidence, "Job/Outbox evidence section missing")
    for term in ("J01–J15", "Q00–Q10", "`DESIGNED`", "`CONTRACT_ONLY`", "`DECISION_REQUIRED`"):
        require(term in evidence, f"Job/Outbox maturity boundary missing: {term}")

    print(
        "Product V4 Job/Outbox migration check passed: "
        f"jobs={len(job_ids)}, waves={len(wave_ids)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
