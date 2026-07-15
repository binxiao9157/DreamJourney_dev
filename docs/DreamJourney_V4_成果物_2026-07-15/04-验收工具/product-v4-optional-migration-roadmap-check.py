#!/usr/bin/env python3
"""Verify MVP extension lanes and composite migration roadmap invariants."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
FIELDS = (
    "Outcome", "Product value", "Priority / lane", "Risk / requirement",
    "Dependencies", "iOS scope", "Backend scope", "Data/API/Event",
    "Migration", "Release policy", "Verification", "Deployment", "Rollback",
    "Definition of Done", "External gates", "Non-goals",
)
GROUPS = (("S3-01", 9), ("V0-01", 11), ("MIG-01", 12))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(ROADMAP.is_file(), f"missing roadmap: {ROADMAP.relative_to(ROOT)}")
    text = ROADMAP.read_text(encoding="utf-8")

    header = text[:900]
    require(
        "V1.2 Product Confirmed Baseline + Staged Validation + Startup Lean Profile" in header
        and "115 个 Work Item" in header,
        "July 15 roadmap header is stale",
    )
    require(
        "产品范围已确认不代表工程实现" in header
        and "当前 Operating Profile" in header,
        "product-confirmation/implementation boundary is missing",
    )
    require("已合入32项/512字段" in text, "Round 4D delivery count is missing")
    require("Family/Publication/Voice 的产品范围已确认但实现/外部门仍`EXTERNAL_BLOCKED`" in text, "MVP extensions must preserve implementation/external gates")
    require("`PLANNED / NO-GO`" in text, "Composite migration must remain NO-GO")

    expected = [f"WI-{group}-{number:02d}" for group, count in GROUPS for number in range(1, count + 1)]
    headings = re.findall(r"^### `(WI-(?:S3-01|V0-01|MIG-01)-\d{2})`", text, re.MULTILINE)
    require(headings == expected, "Round 4D work item headings must be exact and ordered")
    require(len(headings) == len(set(headings)) == 32, "Round 4D work item IDs must be unique")

    for index, work_item in enumerate(headings):
        start = text.index(f"### `{work_item}`")
        if index + 1 < len(headings):
            end = text.index(f"### `{headings[index + 1]}`", start)
        else:
            end = text.index("### 20.1", start)
        block = text[start:end]
        for field in FIELDS:
            require(f"**{field}**" in block, f"{work_item} is missing field: {field}")

    invariants = (
        "用`isPrivate=false`、Family关系、KBLite graph、同一private store/index或query filter实现Publication/Visitor",
        "Voice/DH server policy missing/expired却客户端默认开放",
        "长期Provider/system credential进入App Bundle、API response、日志、QA/backup",
        "默认音色冒充复刻",
        "真实高敏请求dual-send",
        "Provider delete/exit无receipt却显示“已清理/已关闭”",
        "Public Gateway fallback private Projection",
        "立即按顺序执行 `WI-MIG-01-01/C00` 盘点和 `WI-MIG-01-02/C01` 真实 backup/isolated restore",
        "C10 永不删除，只有 C11 可在独立批准后 contract/revoke",
        "Authority 切换后所有回滚禁止 checkout 旧 writer 或降低 epoch",
        "任一扩展 lane 失败阻断 Owner 文字核心降级运行",
    )
    for invariant in invariants:
        require(invariant in text, f"missing Round 4D invariant: {invariant}")

    require(
        "Round 4D 状态、跨 Lane 优先级" not in header,
        "roadmap header must describe delivery, not ledger ticket wording",
    )
    require(
        "Optional/Migration 与追踪验收待 Round 4D–4E 合入" not in text,
        "stale Round 4D pending status remains",
    )

    print(
        "Product V4 Optional/Migration roadmap check passed: "
        f"packages={len(GROUPS)}, work_items={len(headings)}, fields={len(headings) * len(FIELDS)}"
    )


if __name__ == "__main__":
    main()
