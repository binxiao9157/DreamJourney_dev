#!/usr/bin/env python3
"""Verify links in the current product-confirmed documentation set."""

from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"
DOCUMENTS = (
    PRODUCT / "README.md",
    PRODUCT / "寻梦环游_产品确认版整体概要设计_2026-08-17.md",
    PRODUCT / "寻梦环游_当前代码产品PRD_2026-08-17-产品已确认点.md",
    PRODUCT / "寻梦环游_产品确认版PRD_2026-08-18.md",
    PRODUCT / "寻梦环游_产品确认版当前实现证据矩阵_2026-08-18.md",
    PRODUCT / "寻梦环游_产品确认版待明确与完善清单_2026-08-18.md",
    ROOT / "docs/superpowers/plans/2026-08-18-dreamjourney-product-confirmed-gap-01-13-execution-plan.md",
)
LINE_SUFFIX = re.compile(r":\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$")


def link_target(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith("<") and ">" in raw:
        raw = raw[1 : raw.index(">")]
    else:
        raw = raw.split(maxsplit=1)[0]
    return unquote(raw.split("#", maxsplit=1)[0])


def referenced_path(document: Path, raw: str) -> Path | None:
    target = link_target(raw)
    if not target or target.startswith("#"):
        return None
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
        return None
    target = LINE_SUFFIX.sub("", target)
    path = Path(target)
    return path if path.is_absolute() else (document.parent / path).resolve()


def main() -> int:
    errors: list[str] = []
    checked_links = 0

    for document in DOCUMENTS:
        if not document.is_file():
            errors.append(f"DOCUMENT_MISSING: {document.relative_to(ROOT)}")
            continue
        text = document.read_text(encoding="utf-8")
        for raw in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            path = referenced_path(document, raw)
            if path is None:
                continue
            checked_links += 1
            if not path.exists():
                errors.append(f"BROKEN_LINK: {document.name} -> {path}")

    if errors:
        for error in errors:
            print(error)
        print(f"Product-confirmed links check failed: errors={len(errors)}")
        return 1

    print(
        "Product-confirmed links check passed: "
        f"documents={len(DOCUMENTS)} links={checked_links}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
