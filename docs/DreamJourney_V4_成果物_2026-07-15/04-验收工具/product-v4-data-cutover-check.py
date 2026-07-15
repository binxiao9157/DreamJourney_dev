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
    start = spec.index("## 28. 数据 Migration Waves、Authority Cutover 与 Rollback")
    end = spec.index("## 29. iOS AccountSession、Generation 与本地 Store Rollout", start)
    chapter = spec[start:end]

    headings = [
        "### 28.0 CURRENT EVIDENCE：没有可执行 Migration/Cutover 系统",
        "### 28.1 Migration Run 与 Cohort 状态机",
        "### 28.2 Authority Epoch 与 Single-Authority 规则",
        "### 28.3 Migration Wave Catalog",
        "### 28.4 Canonical Shadow Compare 与 Promotion Gate",
        "### 28.5 Cutover、Pause 与 Rollback Matrix",
        "### 28.6 Legacy Contract 与 Retirement Gate",
        "### 28.7 Go/No-Go Evidence Record",
        "### 28.8 Migration Wave 验收与故障场景",
        "### 28.9 实现阶段未决参数",
    ]
    for heading in headings:
        require(heading in chapter, f"data cutover heading missing: {heading}")

    wave_ids = catalog_ids(chapter, "W")
    mismatch_ids = catalog_ids(chapter, "M")
    rollback_ids = catalog_ids(chapter, "R")
    retirement_ids = catalog_ids(chapter, "D")
    require(wave_ids == [f"W{index:02d}" for index in range(12)], "wave IDs must be W00..W11")
    require(mismatch_ids == [f"M{index:02d}" for index in range(1, 9)], "mismatch IDs must be M01..M08")
    require(rollback_ids == [f"R{index:02d}" for index in range(1, 6)], "rollback IDs must be R01..R05")
    require(retirement_ids == [f"D{index:02d}" for index in range(1, 8)], "retirement IDs must be D01..D07")

    required_terms = [
        "authority_epoch",
        "stale_authority_epoch",
        "Single-Authority",
        "compatibility projection/outbox",
        "upgrade_required",
        "不恢复 legacy direct write",
        "连续两次全量",
        "max(old writer retry window, longest compatibility cache TTL, tail catch-up SLA)",
        "MigrationGoNoGoRecord",
        "decision=go|pause|no-go",
        "forward migration",
        "不运行旧二进制",
        "关闭旧写 → 停旧 background effect → 移除旧读依赖",
        "DR-040",
    ]
    for term in required_terms:
        require(term in chapter, f"data cutover term missing: {term}")

    scenario_section = chapter[
        chapter.index(headings[8]) : chapter.index(headings[9])
    ]
    scenario_count = len(re.findall(r"^\d+\. ", scenario_section, re.MULTILINE))
    require(scenario_count >= 16, f"cutover scenarios too small: {scenario_count}")

    require("### 7.4 Round 3C1B Cutover/Rollback 设计状态" in evidence, "cutover evidence section missing")
    for term in (
        "W00–W11",
        "M01–M08",
        "R01–R05",
        "D01–D07",
        "`DESIGNED`",
        "`CONTRACT_ONLY`",
        "没有真实产品/数据/安全批准",
    ):
        require(term in evidence, f"cutover maturity boundary missing: {term}")

    print(
        "Product V4 data cutover check passed: "
        f"waves={len(wave_ids)}, mismatches={len(mismatch_ids)}, "
        f"rollbacks={len(rollback_ids)}, retirements={len(retirement_ids)}, "
        f"scenarios={scenario_count}"
    )


if __name__ == "__main__":
    main()
