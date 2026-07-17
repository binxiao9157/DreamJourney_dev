#!/usr/bin/env python3
"""Verify local links and absolute evidence references in Product V4 Markdown."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "docs/product"
LINE_SUFFIX = re.compile(r":\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def link_target(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith("<") and ">" in raw:
        raw = raw[1:raw.index(">")]
    else:
        raw = raw.split(maxsplit=1)[0]
    return unquote(raw.split("#", maxsplit=1)[0])


def referenced_path(document: Path, raw: str) -> Path | None:
    target = link_target(raw)
    if not target or target.startswith("#"):
        return None
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) and not target.startswith("/Users/"):
        return None
    target = LINE_SUFFIX.sub("", target)
    path = Path(target)
    return path if path.is_absolute() else (document.parent / path).resolve()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-absolute-evidence",
        action="store_true",
        help="also fail when source-workspace /Users/... evidence paths are unavailable",
    )
    args = parser.parse_args()

    documents = sorted(PRODUCT.glob("DreamJourney_V4_*.md"))
    risk_authority = PRODUCT / "寻梦环游_产品问题风险分级与整体规避方案_V1.0.md"
    if risk_authority.is_file():
        documents.append(risk_authority)
    require(documents, "no Product V4 Markdown documents found")

    checked_links = 0
    checked_evidence_paths = 0
    unavailable_external_evidence: list[str] = []
    broken: list[str] = []

    for document in documents:
        text = document.read_text(encoding="utf-8")
        for raw in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            path = referenced_path(document, raw)
            if path is None:
                continue
            checked_links += 1
            if not path.exists():
                broken.append(f"{document.name}: Markdown link -> {path}")

        for raw in re.findall(r"`(/Users/[^`\n]+)`", text):
            path_text = LINE_SUFFIX.sub("", raw.strip())
            path = Path(path_text)
            checked_evidence_paths += 1
            if not path.exists():
                unavailable_external_evidence.append(
                    f"{document.name}: evidence path -> {path}"
                )

    if args.require_absolute_evidence:
        broken.extend(unavailable_external_evidence)

    require(not broken, "broken local references:\n" + "\n".join(broken))
    print(
        "Product V4 links check passed: "
        f"documents={len(documents)}, links={checked_links}, "
        f"absolute_evidence_paths={checked_evidence_paths}, "
        f"unavailable_external_evidence={len(unavailable_external_evidence)}, "
        f"strict_absolute_evidence={args.require_absolute_evidence}"
    )


if __name__ == "__main__":
    main()
