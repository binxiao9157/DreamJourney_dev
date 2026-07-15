#!/usr/bin/env python3

import os
import re
import subprocess
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = Path(
    os.environ.get(
        "DREAMJOURNEY_BACKEND_ROOT",
        str(Path(__file__).resolve().parents[4] / "DreamJourneyBackend"),
    )
)
SPEC = IOS_ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EVIDENCE = IOS_ROOT / "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md"
EXPECTED_BACKEND_COMMIT = "4c0538bf3d2c90cf0ce9d3ca0dfbcb2138c73e85"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def ids(text: str, prefix: str) -> list[str]:
    return re.findall(rf"^\| ({prefix}\d{{2}}) \|", text, re.MULTILINE)


def main() -> None:
    require(SPEC.is_file(), f"Product Spec missing: {SPEC}")
    require(EVIDENCE.is_file(), f"evidence matrix missing: {EVIDENCE}")
    require(BACKEND_ROOT.is_dir(), f"backend repo missing: {BACKEND_ROOT}")

    backend_head = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=BACKEND_ROOT, text=True
    ).strip()
    require(
        backend_head == EXPECTED_BACKEND_COMMIT,
        "backend HEAD changed; refresh the legacy migration catalog before accepting it",
    )

    spec = SPEC.read_text()
    evidence = EVIDENCE.read_text()
    start = spec.index("## 27. Legacy 数据目录与确定性 Backfill 合同")
    end = spec.index("## 28. 数据 Migration Waves、Authority Cutover 与 Rollback", start)
    chapter = spec[start:end]

    headings = [
        "### 27.0 CURRENT EVIDENCE：本节尚未实现",
        "### 27.1 Migration Class 与临时控制对象",
        "### 27.2 ID、Identity、Owner 与 Vault 推导",
        "### 27.3 Backend Legacy Migration Catalog（18 张表）",
        "### 27.4 iOS Local Migration Catalog",
        "### 27.5 V4 Target Object Backfill Coverage（38 组）",
        "### 27.6 Backfill Runner Protocol",
        "### 27.7 Data Rights、Retention 与本地清理",
        "### 27.8 Backfill 验收与故障场景",
        "### 27.9 实现阶段必须补齐的 UNKNOWN",
    ]
    for heading in headings:
        require(heading in chapter, f"backfill heading missing: {heading}")

    postgres_store = (BACKEND_ROOT / "app/services/postgres_store.py").read_text()
    current_tables = re.findall(
        r"CREATE TABLE IF NOT EXISTS\s+([a-z_]+)", postgres_store
    )
    require(len(current_tables) == 18, f"expected 18 backend tables, got {len(current_tables)}")
    for table in current_tables:
        require(f"`{table}" in chapter, f"legacy backend table missing from catalog: {table}")

    backend_ids = ids(chapter, "B")
    ios_ids = ids(chapter, "I")
    require(backend_ids == [f"B{index:02d}" for index in range(1, 19)], "backend catalog IDs must be B01..B18")
    require(ios_ids == [f"I{index:02d}" for index in range(1, 13)], "iOS catalog IDs must be I01..I12")

    target_section = chapter[
        chapter.index(headings[5]) : chapter.index(headings[6])
    ]
    target_ids = re.findall(r"^\| (\d{2}) \|", target_section, re.MULTILINE)
    require(target_ids == [f"{index:02d}" for index in range(1, 39)], "target coverage IDs must be 01..38")

    required_terms = [
        "migrate",
        "derive",
        "project",
        "quarantine",
        "do-not-migrate",
        "external-reconcile",
        "UUIDv5(DJ_MIGRATION_V1",
        "legacy_identity_aliases",
        "claim_pending",
        "authority_epoch",
        "checkpoint 只在目标事务提交后前进",
        "Snapshot boundary",
        "Tail catch-up",
        "canonical checksum",
        "source_changed",
        "offset",
        "owner_conflict",
        "legacy_unassigned",
    ]
    for term in required_terms:
        require(term in chapter, f"backfill contract term missing: {term}")

    scenario_section = chapter[
        chapter.index(headings[8]) : chapter.index(headings[9])
    ]
    scenario_count = len(re.findall(r"^\d+\. ", scenario_section, re.MULTILINE))
    require(scenario_count >= 12, f"backfill scenarios too small: {scenario_count}")

    require("### 7.3 Round 3C1A Backfill 设计状态" in evidence, "evidence matrix backfill section missing")
    for state in ("`DESIGNED`", "`CONTRACT_ONLY`", "尚未完成/不得宣称"):
        require(state in evidence, f"evidence maturity boundary missing: {state}")
    require("未执行线上 row count" in evidence, "online data uncertainty must remain explicit")

    print(
        "Product V4 data backfill check passed: "
        f"backend_tables={len(backend_ids)}, ios_stores={len(ios_ids)}, "
        f"target_groups={len(target_ids)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
