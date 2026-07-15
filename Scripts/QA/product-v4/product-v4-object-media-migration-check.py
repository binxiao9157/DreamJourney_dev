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
    start = spec.index("## 32. 对象存储与媒体迁移")
    end = spec.index("## 33. Provider Effect、Credential 与 Exit 迁移", start)
    chapter = spec[start:end]

    headings = [
        "### 32.0 CURRENT EVIDENCE：媒体状态不能证明云对象存在",
        "### 32.1 Legacy Media/Object Migration Catalog",
        "### 32.2 Object Identity、Namespace 与 Upload Contract",
        "### 32.3 Migration Metadata、Copy 与 Reference Cutover",
        "### 32.4 Object/Media Migration Waves",
        "### 32.5 Object Delete、Retention 与 Receipt Matrix",
        "### 32.6 Object/Media 验收场景",
        "### 32.7 实现阶段 UNKNOWN",
    ]
    for heading in headings:
        require(heading in chapter, f"Object/media migration heading missing: {heading}")

    media_ids = catalog_ids(chapter, "U")
    wave_ids = catalog_ids(chapter, "O")
    delete_ids = catalog_ids(chapter, "Z")
    require(media_ids == [f"U{index:02d}" for index in range(1, 14)], "media IDs must be U01..U13")
    require(wave_ids == [f"O{index:02d}" for index in range(12)], "wave IDs must be O00..O11")
    require(delete_ids == [f"Z{index:02d}" for index in range(1, 9)], "delete IDs must be Z01..Z08")

    required_terms = [
        "mockObjectStorage/mock://",
        "ETag` 不能普遍替代sha256",
        "signed GET每次按当前principal/grant/purpose/object state重新AuthZ",
        "object_migration_links",
        "awaiting_owner_upload",
        "设备local-only",
        "用户显式submit/restore",
        "reference shadow",
        "同一DB transaction切SourceObject active reference",
        "Publication使用独立copy",
        "orphan reconciler",
        "partially_completed",
        "DR-026/031",
    ]
    for term in required_terms:
        require(term in chapter, f"Object/media migration term missing: {term}")

    scenario_start = chapter.index(headings[6])
    scenario_end = chapter.index(headings[7])
    scenario_count = len(
        re.findall(r"^\d+\. ", chapter[scenario_start:scenario_end], re.MULTILINE)
    )
    require(scenario_count >= 18, f"Object/media scenarios too small: {scenario_count}")

    require("### 7.7 Round 3C3B Object/Media 设计状态" in evidence, "Object/media evidence section missing")
    for term in ("U01–U13", "O00–O11", "Z01–Z08", "`DESIGNED`", "`CONTRACT_ONLY`", "`EXTERNAL_ACCEPTANCE`"):
        require(term in evidence, f"Object/media maturity boundary missing: {term}")

    print(
        "Product V4 Object/Media migration check passed: "
        f"media={len(media_ids)}, waves={len(wave_ids)}, "
        f"delete_surfaces={len(delete_ids)}, scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
