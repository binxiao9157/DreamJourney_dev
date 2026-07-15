#!/usr/bin/env python3
"""Guard the canonical Product V4 working sources from snapshot drift."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
QA_DIR = ROOT / "Scripts/QA/product-v4"
SNAPSHOT = ROOT / "docs/DreamJourney_V4_成果物_2026-07-15"
SNAPSHOT_TOKEN = "docs/DreamJourney_V4_成果物_"

CANONICAL_FILES = (
    PRODUCT / "README.md",
    PRODUCT / "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md",
    PRODUCT / "DreamJourney_V4_产品决策登记册_V1.0.md",
    PRODUCT / "DreamJourney_V4_当前实现证据矩阵_V1.0.md",
    PRODUCT / "DreamJourney_V4_评审与验收清单_V1.0.md",
    PRODUCT / "DreamJourney_V4_路线追踪矩阵_V1.0.md",
    PRODUCT / "DreamJourney_V4_路线执行注册表_V1.0.json",
    ROADMAP,
)

WORKING_SOURCE_MARKERS = (
    "CANONICAL_WORKING_SOURCE",
    "DELIVERY_SNAPSHOT_NON_CANONICAL",
    "Scripts/QA/product-v4",
)


def main() -> int:
    errors: list[str] = []

    for path in CANONICAL_FILES:
        if not path.is_file():
            errors.append(f"CANONICAL_FILE_MISSING: {path.relative_to(ROOT)}")

    readme = PRODUCT / "README.md"
    if readme.is_file():
        text = readme.read_text(encoding="utf-8")
        for marker in WORKING_SOURCE_MARKERS:
            if marker not in text:
                errors.append(f"CANONICAL_README_MARKER_MISSING: {marker}")

    snapshot_readme = SNAPSHOT / "README.md"
    if not snapshot_readme.is_file():
        errors.append("DELIVERY_SNAPSHOT_MISSING: README.md")
    elif "DELIVERY_SNAPSHOT_NON_CANONICAL" not in snapshot_readme.read_text(encoding="utf-8"):
        errors.append("DELIVERY_SNAPSHOT_CLASSIFICATION_MISSING")

    for path in sorted(QA_DIR.glob("*.py")):
        if path.resolve() == Path(__file__).resolve():
            continue
        text = path.read_text(encoding="utf-8")
        if SNAPSHOT_TOKEN in text:
            errors.append(f"QA_DEPENDS_ON_SNAPSHOT: {path.relative_to(ROOT)}")

    for path in (*CANONICAL_FILES[:6], ROADMAP):
        if path.is_file() and SNAPSHOT_TOKEN in path.read_text(encoding="utf-8"):
            errors.append(f"CANONICAL_DOC_DEPENDS_ON_SNAPSHOT: {path.relative_to(ROOT)}")

    registry_path = PRODUCT / "DreamJourney_V4_路线执行注册表_V1.0.json"
    if registry_path.is_file():
        try:
            registry = json.loads(registry_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            errors.append(f"CANONICAL_REGISTRY_INVALID: {error}")
        else:
            expected = "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
            if registry.get("source", {}).get("path") != expected:
                errors.append("CANONICAL_REGISTRY_SOURCE_PATH_DRIFT")

    if errors:
        for error in errors:
            print(error)
        print(f"Product V4 canonical source check failed: errors={len(errors)}")
        return 1

    print(
        "Product V4 canonical source check passed: "
        f"canonical_files={len(CANONICAL_FILES)} qa_scripts={len(list(QA_DIR.glob('*.py')))} "
        "snapshot=non-canonical"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
