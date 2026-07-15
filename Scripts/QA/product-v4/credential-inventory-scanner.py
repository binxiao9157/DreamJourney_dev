#!/usr/bin/env python3
"""Create a deterministic credential inventory without emitting credential values."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


REPORT_SCHEMA = "dreamjourney.credential-inventory.v1"
SURFACE_CATEGORIES = {
    "SOURCE",
    "HISTORY",
    "APP",
    "IPA",
    "DSYM",
    "RESPONSE",
    "HEADER",
    "RUNTIME",
    "OSLOG",
    "QA",
    "BACKUP",
    "CONTAINER",
}
ASSIGNMENT_TEMPLATE = (
    r"(?is)(?:[\"']?(?:{key})[\"']?\s*(?:=|:)\s*[\"']?)"
    r"(?P<value>[^\s\"'`,;<>]{{4,2048}})"
)
PLIST_TEMPLATE = (
    r"(?is)<key>\s*(?:{key})\s*</key>\s*<string>\s*"
    r"(?P<value>[^<]{{1,2048}})\s*</string>"
)
PRIVATE_KEY_PATTERN = re.compile(
    r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----\s*"
    r"(?P<value>[A-Za-z0-9+/=\r\n]{32,})\s*"
    r"-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY-----",
    re.MULTILINE,
)
BEARER_PATTERN = re.compile(r"(?i)\bBearer\s+(?P<value>[A-Za-z0-9._~+/=-]{12,2048})")
JWT_PATTERN = re.compile(
    r"(?P<value>eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})"
)
PRINTABLE_PATTERN = re.compile(rb"[\x20-\x7e\r\n\t]{8,}")


@dataclass(frozen=True)
class Surface:
    category: str
    root: Path
    label: str


def canonical_json_bytes(payload: Any) -> bytes:
    return (json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def short_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_surface(value: str) -> Surface:
    if "=" not in value:
        raise argparse.ArgumentTypeError("surface must use CATEGORY=PATH")
    category, raw_path = value.split("=", 1)
    category = category.upper().strip()
    if category not in SURFACE_CATEGORIES:
        raise argparse.ArgumentTypeError(f"unsupported surface category: {category}")
    root = Path(raw_path).expanduser()
    label = root.resolve().name if root.exists() else (root.name or "missing")
    return Surface(category=category, root=root, label=label)


def parse_category(value: str) -> str:
    category = value.upper().strip()
    if category not in SURFACE_CATEGORIES:
        raise argparse.ArgumentTypeError(f"unsupported surface category: {category}")
    return category


def load_policy(path: Path) -> dict[str, Any]:
    policy = json.loads(path.read_text(encoding="utf-8"))
    if policy.get("schemaVersion") != "dreamjourney.credential-inventory-policy.v1":
        raise ValueError("unsupported credential inventory policy")
    for entry in policy.get("allowlist", []):
        reviewers = entry.get("reviewedBy", [])
        if len(set(reviewers)) < 2 or not entry.get("expiresAt") or "value" in entry:
            raise ValueError("allowlist entries require two reviewers, expiry, and no value")
    return policy


def is_placeholder(value: str, tokens: Iterable[str]) -> bool:
    normalized = value.strip().strip("\"'")
    upper = normalized.upper()
    if not normalized:
        return True
    if any(token.upper() in upper for token in tokens):
        return True
    if any(marker in normalized for marker in ("${", "$(", "{{", "\\(", "***")):
        return True
    return upper in {"NIL", "NONE", "NULL", "FALSE", "UNSET"}


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def path_matches_allowlist(path: str, pattern: str | None) -> bool:
    return pattern is None or re.search(pattern, path) is not None


class InventoryBuilder:
    def __init__(self, policy: dict[str, Any], observed_at: str) -> None:
        self.policy = policy
        self.observed_at = observed_at
        self.findings: dict[tuple[str, str, str, str, int], dict[str, Any]] = {}
        self.surfaces: list[dict[str, Any]] = []
        self.placeholder_tokens = policy.get("placeholderTokens", [])
        self.placeholder_patterns = [
            re.compile(pattern) for pattern in policy.get("placeholderValuePatterns", [])
        ]
        self.reference_patterns = [
            re.compile(pattern) for pattern in policy.get("referenceValuePatterns", [])
        ]
        self.types: list[tuple[dict[str, Any], re.Pattern[str], re.Pattern[str]]] = []
        for entry in policy.get("credentialTypes", []):
            key = entry["keyPattern"]
            self.types.append(
                (
                    entry,
                    re.compile(ASSIGNMENT_TEMPLATE.format(key=key)),
                    re.compile(PLIST_TEMPLATE.format(key=key)),
                )
            )

    def add_finding(
        self,
        entry: dict[str, Any],
        raw_value: str,
        category: str,
        path: str,
        line: int,
    ) -> None:
        value = raw_value.strip().strip("\"'")
        if len(value) < 4:
            return
        fingerprint = short_hash(value)
        status = entry["classification"]
        if is_placeholder(value, self.placeholder_tokens) or any(
            pattern.search(value) for pattern in self.placeholder_patterns
        ):
            status = "PLACEHOLDER"
        elif any(pattern.search(value) for pattern in self.reference_patterns):
            status = "REFERENCE"
        allowlisted = False
        for allowed in self.policy.get("allowlist", []):
            if (
                allowed.get("type") == entry["type"]
                and allowed.get("fingerprint") == fingerprint
                and path_matches_allowlist(path, allowed.get("pathPattern"))
            ):
                allowlisted = True
                break
        if allowlisted:
            status = "ALLOWLISTED"

        if status == "SECRET":
            rotation_status = "PENDING_OWNER_CONFIRMATION"
            rotation_action = "CONTAIN_AND_ROTATE_IF_EXPOSURE_IS_CONFIRMED"
        elif status == "UNKNOWN":
            rotation_status = "CLASSIFICATION_REQUIRED"
            rotation_action = "CLASSIFY_THEN_CONTAIN_OR_APPROVE"
        elif status == "ALLOWLISTED":
            rotation_status = "EXCEPTION_ACTIVE"
            rotation_action = "REVIEW_BEFORE_EXCEPTION_EXPIRY"
        else:
            rotation_status = "NOT_APPLICABLE"
            rotation_action = "NONE"

        key = (entry["type"], fingerprint, category, path, line)
        evidence_seed = f"{category}:{path}:{line}:{entry['type']}:{fingerprint}"
        self.findings[key] = {
            "containment": entry["containment"],
            "credentialId": f"cred-{entry['type'].lower().replace('_', '-')}-{fingerprint}",
            "evidenceId": f"evidence-{short_hash(evidence_seed)}",
            "fingerprint": fingerprint,
            "lastObserved": self.observed_at,
            "line": line,
            "locationCategory": category,
            "owner": entry["owner"],
            "path": path,
            "replacementPath": entry["replacementPath"],
            "rotationAction": rotation_action,
            "rotationStatus": rotation_status,
            "scope": entry["scope"],
            "status": status,
            "type": entry["type"],
            "version": entry["version"],
        }

    def scan_text(self, text: str, category: str, path: str, base_line: int = 0) -> None:
        occupied: set[tuple[int, int]] = set()
        for entry, assignment, plist in self.types:
            for pattern in (plist, assignment):
                for match in pattern.finditer(text):
                    span = match.span("value")
                    if any(span[0] < end and span[1] > start for start, end in occupied):
                        continue
                    occupied.add(span)
                    self.add_finding(
                        entry,
                        match.group("value"),
                        category,
                        path,
                        base_line + line_number(text, span[0]),
                    )

        private_entry = {
            "classification": "SECRET",
            "containment": "Remove from exposed surfaces, rotate the key, and retain only a value-free rotation receipt.",
            "owner": "SECURITY_TRIAGE_OWNER",
            "replacementPath": "Managed secret storage with a public-key or short-lived session boundary.",
            "scope": "SERVER_ONLY",
            "type": "PRIVATE_KEY",
            "version": "v1",
        }
        for match in PRIVATE_KEY_PATTERN.finditer(text):
            self.add_finding(private_entry, match.group("value"), category, path, base_line + line_number(text, match.start("value")))

        bearer_entry = {
            "classification": "SECRET",
            "containment": "Revoke exposed bearer material and prevent response, log, artifact, and QA persistence.",
            "owner": "IDENTITY_SECURITY_OWNER",
            "replacementPath": "Subject-bound opaque sessions with expiry, revoke, audience, and scope.",
            "scope": "SESSION",
            "type": "BEARER_TOKEN",
            "version": "v1",
        }
        for match in BEARER_PATTERN.finditer(text):
            self.add_finding(bearer_entry, match.group("value"), category, path, base_line + line_number(text, match.start("value")))

        jwt_entry = {
            "classification": "SECRET",
            "containment": "Revoke exposed JWT material and prevent persistence outside the authorized session store.",
            "owner": "IDENTITY_SECURITY_OWNER",
            "replacementPath": "Opaque or sender-constrained short-lived user/service session.",
            "scope": "SESSION",
            "type": "JWT",
            "version": "v1",
        }
        for match in JWT_PATTERN.finditer(text):
            self.add_finding(jwt_entry, match.group("value"), category, path, base_line + line_number(text, match.start("value")))

    def scan_bytes(self, data: bytes, category: str, path: str) -> None:
        text = data.decode("utf-8", errors="ignore")
        if "\x00" in text:
            text = "\n".join(chunk.decode("ascii", errors="ignore") for chunk in PRINTABLE_PATTERN.findall(data))
        self.scan_text(text, category, path)


def git_files(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "-z"],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return []
    return [root / raw.decode("utf-8", errors="surrogateescape") for raw in result.stdout.split(b"\0") if raw]


def filesystem_files(root: Path, excluded: set[str]) -> Iterable[Path]:
    if root.is_file():
        yield root
        return
    for directory, names, files in os.walk(root):
        names[:] = sorted(name for name in names if name not in excluded)
        for name in sorted(files):
            yield Path(directory) / name


def path_is_excluded(root: Path, path: Path, excluded: set[str]) -> bool:
    try:
        relative = path.relative_to(root)
    except ValueError:
        relative = path
    return any(part in excluded for part in relative.parts)


def is_probably_binary(data: bytes) -> bool:
    if not data:
        return False
    sample = data[:8192]
    if b"\x00" in sample:
        return True
    control_bytes = sum(byte < 9 or 13 < byte < 32 for byte in sample)
    return control_bytes / len(sample) > 0.05


def display_path(surface: Surface, path: Path) -> str:
    try:
        relative = path.resolve().relative_to(surface.root.resolve())
        return f"{surface.label}/{relative.as_posix()}"
    except (OSError, ValueError):
        return f"{surface.label}/{path.name}"


def scan_zip(builder: InventoryBuilder, surface: Surface, path: Path, max_bytes: int) -> tuple[int, int]:
    scanned = 0
    skipped = 0
    try:
        with zipfile.ZipFile(path) as archive:
            for member in sorted(archive.infolist(), key=lambda item: item.filename):
                if member.is_dir():
                    continue
                if member.file_size > max_bytes:
                    skipped += 1
                    continue
                data = archive.read(member)
                builder.scan_bytes(data, surface.category, f"{display_path(surface, path)}!/{member.filename}")
                scanned += 1
    except (OSError, zipfile.BadZipFile, RuntimeError):
        skipped += 1
    return scanned, skipped


def scan_file(builder: InventoryBuilder, surface: Surface, path: Path, max_bytes: int) -> tuple[int, int]:
    if path.suffix.lower() in {".ipa", ".zip"}:
        return scan_zip(builder, surface, path, max_bytes)
    try:
        size = path.stat().st_size
        if size <= max_bytes:
            data = path.read_bytes()
            if surface.category in {"SOURCE", "CONTAINER"} and is_probably_binary(data):
                return 0, 1
            builder.scan_bytes(data, surface.category, display_path(surface, path))
            return 1, 0
        scanned_chunks = 0
        with path.open("rb") as handle:
            while True:
                chunk = handle.read(max_bytes)
                if not chunk:
                    break
                if surface.category in {"SOURCE", "CONTAINER"} and is_probably_binary(chunk):
                    return 0, 1
                builder.scan_bytes(chunk, surface.category, display_path(surface, path))
                scanned_chunks += 1
        return max(scanned_chunks, 1), 0
    except OSError:
        return 0, 1


def scan_history(builder: InventoryBuilder, surface: Surface) -> dict[str, Any]:
    if not (surface.root / ".git").exists():
        return {"filesScanned": 0, "itemsSkipped": 0, "status": "MISSING"}
    process = subprocess.Popen(
        ["git", "-C", str(surface.root), "log", "--all", "--format=commit %H", "--no-ext-diff", "--unified=0", "--", "."],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    commit = "unknown"
    path = "unknown"
    additions = 0
    assert process.stdout is not None
    for line in process.stdout:
        if line.startswith("commit "):
            commit = line.split(" ", 1)[1].strip()[:12]
        elif line.startswith("+++ b/"):
            path = line[6:].strip()
        elif line.startswith("+") and not line.startswith("+++"):
            additions += 1
            builder.scan_text(line[1:], surface.category, f"{surface.label}@{commit}/{path}")
    return_code = process.wait()
    return {
        "filesScanned": additions,
        "itemsSkipped": 0 if return_code == 0 else 1,
        "status": "SCANNED" if return_code == 0 else "ERROR",
    }


def scan_surface(builder: InventoryBuilder, surface: Surface, max_bytes: int, excluded: set[str]) -> dict[str, Any]:
    metadata = {
        "category": surface.category,
        "filesScanned": 0,
        "itemsSkipped": 0,
        "rootFingerprint": short_hash(str(surface.root.resolve())),
        "rootLabel": surface.label,
        "status": "SCANNED",
    }
    if not surface.root.exists():
        metadata["status"] = "MISSING"
        return metadata
    if surface.category == "HISTORY":
        metadata.update(scan_history(builder, surface))
        return metadata

    candidates = git_files(surface.root) if surface.category == "SOURCE" and (surface.root / ".git").exists() else list(filesystem_files(surface.root, excluded))
    for path in candidates:
        if path_is_excluded(surface.root, path, excluded):
            metadata["itemsSkipped"] += 1
            continue
        scanned, skipped = scan_file(builder, surface, path, max_bytes)
        metadata["filesScanned"] += scanned
        metadata["itemsSkipped"] += skipped
    if metadata["itemsSkipped"]:
        metadata["status"] = "PARTIAL"
    return metadata


def report_payload(
    builder: InventoryBuilder,
    policy: dict[str, Any],
    unavailable: list[str],
    required: list[str],
) -> dict[str, Any]:
    for category in unavailable:
        builder.surfaces.append(
            {
                "category": category,
                "filesScanned": 0,
                "itemsSkipped": 0,
                "rootFingerprint": None,
                "rootLabel": "not-provided",
                "status": "UNAVAILABLE",
            }
        )
    findings = sorted(
        builder.findings.values(),
        key=lambda item: (item["locationCategory"], item["path"], item["line"], item["type"], item["fingerprint"]),
    )
    blocking_statuses = {"SECRET", "UNKNOWN"}
    blocking = sum(1 for item in findings if item["status"] in blocking_statuses)
    unique_credentials = {item["credentialId"] for item in findings}
    unique_blocking_credentials = {
        item["credentialId"] for item in findings if item["status"] in blocking_statuses
    }
    scanned_categories = {item["category"] for item in builder.surfaces if item["status"] in {"SCANNED", "PARTIAL"}}
    coverage_blockers = sorted(set(required) - scanned_categories)
    status_counts: dict[str, int] = {}
    for item in findings:
        status_counts[item["status"]] = status_counts.get(item["status"], 0) + 1
    return {
        "containsCredentialValues": False,
        "coverage": {
            "coverageBlockers": coverage_blockers,
            "observedCategories": sorted(scanned_categories),
            "requiredCategories": sorted(set(required)),
        },
        "findings": findings,
        "generatedAt": builder.observed_at,
        "policyFingerprint": short_hash(canonical_json_bytes(policy).decode("utf-8")),
        "schemaVersion": REPORT_SCHEMA,
        "summary": {
            "blockingFindings": blocking,
            "coverageBlockers": len(coverage_blockers),
            "findings": len(findings),
            "statusCounts": dict(sorted(status_counts.items())),
            "surfaces": len(builder.surfaces),
            "uniqueBlockingCredentials": len(unique_blocking_credentials),
            "uniqueCredentials": len(unique_credentials),
        },
        "surfaces": sorted(builder.surfaces, key=lambda item: (item["category"], item["rootLabel"])),
    }


def write_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(canonical_json_bytes(payload))
    temporary.replace(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--surface", action="append", type=parse_surface, default=[])
    parser.add_argument("--unavailable-surface", action="append", type=parse_category, default=[])
    parser.add_argument("--require-surface", action="append", type=parse_category, default=[])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--observed-at", default=None)
    parser.add_argument("--enforce", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    policy = load_policy(args.policy)
    observed_at = args.observed_at or utc_now()
    builder = InventoryBuilder(policy, observed_at)
    max_bytes = int(policy.get("maxArchiveMemberBytes", 67108864))
    excluded = set(policy.get("excludedDirectoryNames", []))
    for surface in args.surface:
        builder.surfaces.append(scan_surface(builder, surface, max_bytes, excluded))
    payload = report_payload(builder, policy, args.unavailable_surface, args.require_surface)
    write_atomic(args.output, payload)
    summary = payload["summary"]
    print(
        "Credential inventory complete: "
        f"findings={summary['findings']} blocking={summary['blockingFindings']} "
        f"coverage_blockers={summary['coverageBlockers']} surfaces={summary['surfaces']}"
    )
    if args.enforce and (summary["blockingFindings"] or summary["coverageBlockers"]):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
