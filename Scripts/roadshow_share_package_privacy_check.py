#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path


EXPECTED_PACKAGE_PATHS = [
    "share_packages/all_family.json",
    "share_packages/selected_member.json",
]
REQUIRED_PACKAGE_FIELDS = [
    "sourceUserId",
    "sourceNickname",
    "exportDate",
    "graphJSON",
]
REQUIRED_GRAPH_FIELDS = ["people", "places", "events", "facts"]
FORBIDDEN_MARKERS = [
    "PRIVATE_",
    "LOCAL_",
    "GENERATION_",
    "RAW_TRANSCRIPT",
    "FULL_TRANSCRIPT",
    "FULL_LETTER",
    "UNAUTHORIZED_",
]


def resolve_package_paths(paths: list[str]) -> list[Path]:
    if len(paths) == 1:
        root = Path(paths[0])
        if root.is_dir():
            return [root / relative_path for relative_path in EXPECTED_PACKAGE_PATHS]
    return [Path(path) for path in paths]


def display_path(path: Path) -> str:
    parts = path.parts
    if "share_packages" in parts:
        index = parts.index("share_packages")
        return "/".join(parts[index:])
    return str(path)


def finding(path: Path, check: str, message: str) -> dict:
    return {
        "path": display_path(path),
        "check": check,
        "message": message,
    }


def inspect_package(path: Path):
    findings = []
    if not path.exists():
        return None, [finding(path, "missing", "Share package JSON file is missing.")]

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None, [finding(path, "unreadable", "Share package must be UTF-8 JSON.")]

    for marker in FORBIDDEN_MARKERS:
        if marker in text:
            findings.append(
                finding(path, "forbidden-marker", f"Forbidden marker detected: {marker}")
            )

    try:
        package = json.loads(text)
    except json.JSONDecodeError:
        return None, findings + [finding(path, "invalid-json", "Share package is not parseable JSON.")]

    if not isinstance(package, dict):
        return None, findings + [finding(path, "invalid-shape", "Share package root must be an object.")]

    for field in REQUIRED_PACKAGE_FIELDS:
        if field not in package:
            findings.append(finding(path, "missing-package-field", f"Missing package field: {field}"))

    graph_raw = package.get("graphJSON")
    if not isinstance(graph_raw, str):
        findings.append(finding(path, "invalid-graph-json", "graphJSON must be a JSON string."))
        return package, findings

    try:
        graph = json.loads(graph_raw)
    except json.JSONDecodeError:
        findings.append(finding(path, "invalid-graph-json", "graphJSON is not parseable JSON."))
        return package, findings

    if not isinstance(graph, dict):
        findings.append(finding(path, "invalid-graph-shape", "graphJSON root must be an object."))
        return package, findings

    for field in REQUIRED_GRAPH_FIELDS:
        if not isinstance(graph.get(field), list):
            findings.append(finding(path, "missing-graph-field", f"Missing graph array: {field}"))

    return package, findings


def privacy_log_text(paths: list[Path]) -> str:
    normalized_paths = [display_path(path) for path in paths]
    return "\n".join(
        [
            "PASS share package privacy check",
            f"checked {normalized_paths[0]}",
            f"checked {normalized_paths[1]}",
            "no private_ or local_ markers found",
            "no raw_transcript, full_transcript, or full_letter content found",
            "no unauthorized_ member content found",
            "graphJSON parsed with people, places, events, and facts arrays",
            "",
        ]
    )


def build_payload(paths: list[Path], findings: list[dict]) -> dict:
    return {
        "status": "pass" if not findings else "fail",
        "packages": [display_path(path) for path in paths],
        "findings": findings,
        "privacyCheckLog": privacy_log_text(paths) if not findings and len(paths) == 2 else None,
    }


def print_text(payload: dict) -> None:
    if payload["status"] == "pass":
        print(payload["privacyCheckLog"], end="")
        return

    print("FAIL share package privacy check")
    for item in payload["findings"]:
        print(f"- {item['path']}: {item['check']} - {item['message']}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check roadshow share package JSON samples and produce privacy_check.log text."
    )
    parser.add_argument(
        "paths",
        nargs="+",
        help=(
            "Either an evidence directory containing share_packages/all_family.json and "
            "share_packages/selected_member.json, or the two JSON files directly."
        ),
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    parser.add_argument("--write-log", help="Write PASS privacy_check.log text to this path.")
    args = parser.parse_args()

    paths = resolve_package_paths(args.paths)
    findings: list[dict] = []
    if len(paths) != 2:
        findings.append(
            {
                "path": ",".join(str(path) for path in paths),
                "check": "invalid-arguments",
                "message": "Provide an evidence directory or exactly two share package JSON files.",
            }
        )
    else:
        for path in paths:
            _package, package_findings = inspect_package(path)
            findings.extend(package_findings)

    payload = build_payload(paths, findings)

    if args.write_log and not findings and len(paths) == 2:
        output_path = Path(args.write_log)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(payload["privacyCheckLog"], encoding="utf-8")

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_text(payload)

    return 0 if not findings else 2


if __name__ == "__main__":
    sys.exit(main())
