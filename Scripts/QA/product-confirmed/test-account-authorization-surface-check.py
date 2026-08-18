#!/usr/bin/env python3
"""Fail if test-account authorization management leaks into the normal iOS app."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys


ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
SOURCE_ROOTS = (ROOT / "DreamJourney", ROOT / "DreamJourneyApp")
FORBIDDEN = (
    (r"\btestRole\b", "testRole"),
    (r"\bfeatureEntitlements\b", "featureEntitlements"),
    (r"\bscenarioBindings\b", "scenarioBindings"),
    (r"\bentitlementRevision\b", "entitlementRevision"),
    (r"/ops/test-accounts", "/ops/test-accounts"),
    (r"测试角色", "测试角色"),
    (r"产品功能权限", "产品功能权限"),
)


def main() -> None:
    violations: list[dict[str, object]] = []
    scanned = 0
    for source_root in SOURCE_ROOTS:
        if not source_root.exists():
            continue
        for path in source_root.rglob("*.swift"):
            scanned += 1
            text = path.read_text(encoding="utf-8")
            for pattern, token in FORBIDDEN:
                if re.search(pattern, text):
                    violations.append(
                        {
                            "path": str(path.relative_to(ROOT)),
                            "token": token,
                        }
                    )
    if violations:
        raise SystemExit(
            json.dumps(
                {"status": "failed", "violations": violations},
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    print(
        json.dumps(
            {
                "status": "passed",
                "swiftFilesScanned": scanned,
                "managementSurface": "backendInternalOnly",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
