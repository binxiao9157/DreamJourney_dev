#!/usr/bin/env python3
"""Static guard for the iOS provider diagnostics redaction boundary.

The check intentionally inspects source only. It never reads runtime logs, local
configuration, user data, or credentials. Provider diagnostics may contain only
allowlisted state/count metadata and hashed correlations.
"""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]

TARGETS = {
    "DreamJourney/Sources/Services/ConversationMemoryManager.swift": (
        "enum PrivacySafeDiagnostics",
        'redactionPolicyVersion = "iosDiagnostics-v1"',
    ),
    "DreamJourney/Sources/Services/KBLiteManager.swift": (
        "PrivacySafeDiagnostics.log",
    ),
    "DreamJourney/Sources/Memoir/DeepSeekService.swift": (
        "网络请求失败，请稍后再试",
    ),
    "DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift": (
        "PrivacySafeDiagnostics.log",
    ),
    "DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift": (
        "PrivacySafeDiagnostics.log",
    ),
    "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift": (
        "private enum EchoDiagnosticExportRedactor",
        "EchoDiagnosticExportRedactor.encode",
        'redactionPolicyVersion"] = PrivacySafeDiagnostics.redactionPolicyVersion',
    ),
    "DreamJourney/Sources/Modules/Echo/EchoViewController.swift": (
        "PrivacySafeDiagnostics.log",
        "print(record.logLine)",
    ),
}

FORBIDDEN_PRINT_TOKENS = (
    "error.localizedDescription",
    "archiveItemIDs=",
    "generationContextText",
    "providerResponseBody",
    "rawProviderResponse",
    "requestID=\\(",
    "turnID=\\(",
    "traceID=\\(",
    "traceId=\\(",
    "contextKey=\\(",
    "userId=\\(",
    "voiceProfileId=\\(",
    "providerLogId=\\(",
    "providerRequestId=\\(",
    "payload=\\(",
    "message=\\(",
    "SEI=\\(",
)


def print_blocks(source: str) -> list[tuple[int, str]]:
    """Returns balanced Swift print(...) blocks with their starting line."""
    blocks: list[tuple[int, str]] = []
    cursor = 0
    while True:
        start = source.find("print(", cursor)
        if start < 0:
            return blocks
        depth = 0
        in_string = False
        escaped = False
        index = start
        while index < len(source):
            char = source[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    blocks.append((source.count("\n", 0, start) + 1, source[start : index + 1]))
                    cursor = index + 1
                    break
            index += 1
        else:
            blocks.append((source.count("\n", 0, start) + 1, source[start:]))
            return blocks


def main() -> int:
    failures: list[str] = []
    checked_print_blocks = 0
    for relative_path, required_fragments in TARGETS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"{relative_path}: missing target")
            continue
        source = path.read_text(encoding="utf-8")
        for fragment in required_fragments:
            if fragment not in source:
                failures.append(f"{relative_path}: missing required boundary marker: {fragment}")
        for line_number, block in print_blocks(source):
            checked_print_blocks += 1
            for token in FORBIDDEN_PRINT_TOKENS:
                if token in block:
                    failures.append(
                        f"{relative_path}:{line_number}: raw diagnostics token in print block: {token}"
                    )
        if relative_path.endswith("EchoViewController.swift") and "archiveItemIDs=\\(" in source:
            failures.append(
                f"{relative_path}: forbidden legacy archive item trace suffix remains"
            )

    if failures:
        print("FAIL provider-redaction-boundary")
        print("\n".join(failures))
        return 1

    print(
        "PASS provider-redaction-boundary "
        f"targets={len(TARGETS)} printBlocks={checked_print_blocks} "
        "policy=iosDiagnostics-v1"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
