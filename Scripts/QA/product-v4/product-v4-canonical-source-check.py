#!/usr/bin/env python3
"""Guard the 2026-08-17 product-confirmed documentation authority chain."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"
PLAN = (
    ROOT
    / "docs/superpowers/plans/2026-08-18-dreamjourney-product-confirmed-gap-01-13-execution-plan.md"
)
RAW_INPUT_SHA256 = "2bd97b7cf1e08e37affdc169cbc68c9ba03b5323557dec8c33bfbc0e81450d6f"
SUPPLEMENTAL_DECISION_SHA256 = "1ea2fac89c753b3e347502f329a3a9e8b5e614c13f4dc6ffba535cabd152b5ab"
IOS_HEAD = "09394f9869e0b0e20150a43ffe8149a7e607356c"
BACKEND_HEAD = "b472b6de9fc43e797936741b63a9de877db48750"

README = PRODUCT / "README.md"
HIGH_LEVEL_DESIGN = PRODUCT / "寻梦环游_产品确认版整体概要设计_2026-08-17.md"
RAW_PRODUCT_INPUT = PRODUCT / "寻梦环游_当前代码产品PRD_2026-08-17-产品已确认点.md"
NORMALIZED_PRD = PRODUCT / "寻梦环游_产品确认版PRD_2026-08-18.md"
EVIDENCE_MATRIX = PRODUCT / "寻梦环游_产品确认版当前实现证据矩阵_2026-08-18.md"
DECISION_QUEUE = PRODUCT / "寻梦环游_产品确认版待明确与完善清单_2026-08-18.md"

CANONICAL_FILES = (
    README,
    HIGH_LEVEL_DESIGN,
    RAW_PRODUCT_INPUT,
    NORMALIZED_PRD,
    EVIDENCE_MATRIX,
    DECISION_QUEUE,
    PLAN,
)

REQUIREMENT_PATTERN = re.compile(
    r"\b(?:APP|AUTH|ARCH|MEM|INTV|ECHO|FAM|PROF|DATA|VOICE|DH|PUB|KB|NOTI|OPS|SEC)-\d{3}\b"
)
GAP_PATTERN = re.compile(r"\bGAP-(?:0[1-9]|1[0-3])\b")


def require_marker(errors: list[str], path: Path, marker: str) -> None:
    if marker not in path.read_text(encoding="utf-8"):
        errors.append(f"MARKER_MISSING: {path.relative_to(ROOT)} -> {marker}")


def main() -> int:
    errors: list[str] = []

    for path in CANONICAL_FILES:
        if not path.is_file():
            errors.append(f"CANONICAL_FILE_MISSING: {path.relative_to(ROOT)}")

    if errors:
        for error in errors:
            print(error)
        print(f"Product-confirmed canonical source check failed: errors={len(errors)}")
        return 1

    for marker in (
        "PRODUCT_CONFIRMED_2026-08-18_ALIGNED",
        HIGH_LEVEL_DESIGN.name,
        RAW_PRODUCT_INPUT.name,
        NORMALIZED_PRD.name,
        EVIDENCE_MATRIX.name,
        DECISION_QUEUE.name,
        PLAN.name,
        "其他 V4 Product Spec",
    ):
        require_marker(errors, README, marker)

    for marker in (
        RAW_INPUT_SHA256,
        SUPPLEMENTAL_DECISION_SHA256,
        IOS_HEAD,
        BACKEND_HEAD,
        "GAP-13",
    ):
        require_marker(errors, HIGH_LEVEL_DESIGN, marker)

    for marker in (RAW_INPUT_SHA256, "产品确认原始内容", NORMALIZED_PRD.name):
        require_marker(errors, RAW_PRODUCT_INPUT, marker)

    normalized_text = NORMALIZED_PRD.read_text(encoding="utf-8")
    requirement_ids = set(REQUIREMENT_PATTERN.findall(normalized_text))
    if len(requirement_ids) != 35:
        errors.append(f"NORMALIZED_PRD_REQUIREMENT_COUNT_INVALID: {len(requirement_ids)}")
    for marker in (
        "数字人",
        "暂时关闭",
        "时光信与延迟回复",
        "正式记忆 Markdown",
        "密码与手机号验证码登录注册",
        "当前版本 + 3 个历史快照",
        "单个声音主体最多创建 5 次",
        "应用内消息中心",
    ):
        if marker not in normalized_text:
            errors.append(f"NORMALIZED_PRD_MARKER_MISSING: {marker}")

    evidence_text = EVIDENCE_MATRIX.read_text(encoding="utf-8")
    evidence_requirements = set(REQUIREMENT_PATTERN.findall(evidence_text))
    evidence_gaps = set(GAP_PATTERN.findall(evidence_text))
    if len(evidence_requirements) != 35:
        errors.append(f"EVIDENCE_REQUIREMENT_COUNT_INVALID: {len(evidence_requirements)}")
    if len(evidence_gaps) != 13:
        errors.append(f"EVIDENCE_GAP_COUNT_INVALID: {len(evidence_gaps)}")
    for marker in (IOS_HEAD, BACKEND_HEAD, "只评估当前仓库代码"):
        if marker not in evidence_text:
            errors.append(f"EVIDENCE_MARKER_MISSING: {marker}")

    decision_text = DECISION_QUEUE.read_text(encoding="utf-8")
    decision_ids = set(re.findall(r"\bPCQ-(?:0[1-9]|1[0-3])\b", decision_text))
    if len(decision_ids) != 13:
        errors.append(f"DECISION_QUEUE_COUNT_INVALID: {len(decision_ids)}")
    for marker in (
        "DERIVED_PRODUCT_DECISION_RECORD",
        "CONFIRMED_2026-08-18",
        SUPPLEMENTAL_DECISION_SHA256,
        "决策 Owner",
        "最迟确认 Gate",
        "确认凭证",
        "最多创建 5 次",
        "当前版本 + 最多 3 个历史快照",
        "一键删除已读",
    ):
        if marker not in decision_text:
            errors.append(f"DECISION_QUEUE_MARKER_MISSING: {marker}")
    if decision_text.count("产品最终确认：`CONFIRMED") != 13:
        errors.append(
            "DECISION_CONFIRMATION_COUNT_INVALID: "
            f"{decision_text.count('产品最终确认：`CONFIRMED')}"
        )

    plan_text = PLAN.read_text(encoding="utf-8")
    plan_gaps = set(GAP_PATTERN.findall(plan_text))
    if len(plan_gaps) != 13:
        errors.append(f"PLAN_GAP_COUNT_INVALID: {len(plan_gaps)}")
    for marker in (
        "Work Item 执行卡",
        "UI 设计依据矩阵",
        "部署运行态快照",
        "API 与迁移合同清单",
        "验收证据与回滚规范",
        "PC-00-03 首版可见范围收敛",
        "PC-A0 密码与手机号验证码双登录",
        "PC-A4 音色独立授权与累计创建上限",
        "PC-A5 家庭关系解除与数据处置",
        "PC-B4 统一消息中心与未读入口",
        "产品确认后的连续开发队列",
        "本轮明确延期，不进入开发队列",
    ):
        if marker not in plan_text:
            errors.append(f"PLAN_EXECUTION_CONTROL_MARKER_MISSING: {marker}")

    if errors:
        for error in errors:
            print(error)
        print(f"Product-confirmed canonical source check failed: errors={len(errors)}")
        return 1

    print(
        "Product-confirmed canonical source check passed: "
        f"canonical_files={len(CANONICAL_FILES)} requirements={len(requirement_ids)} "
        f"gaps={len(evidence_gaps)} decisions={len(decision_ids)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
