#!/usr/bin/env python3
"""Build or execute one value-minimized V4 non-device evidence bundle.

The registry intentionally points at existing lane-local gates.  This runner
does not change their release policy, activate feature flags, or claim that a
passing non-device gate is a public-release approval.  A normal invocation is
dry-run only; ``--execute`` is explicit and writes one isolated log directory
per lane command.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable, Mapping


SCHEMA_VERSION = "dreamjourney-v4-non-device-lane-registry-v1"
EVIDENCE_SCHEMA_VERSION = "dreamjourney-v4-unified-non-device-evidence-v1"
LANE_ORDER = ("m0", "stage2", "m1", "m2")
ALLOWED_DEFAULT_STATES = {"publicCore", "closedPilotDefaultOff"}
ALLOWED_BLOCKER_KINDS = {
    "DEVICE_REQUIRED",
    "EXTERNAL_PROVIDER_REQUIRED",
    "PRODUCT_OR_LEGAL_REQUIRED",
}
ENVIRONMENT_NAME = re.compile(r"^[A-Z][A-Z0-9_]{1,127}$")
SENSITIVE_ENVIRONMENT_FRAGMENTS = ("TOKEN", "KEY", "SECRET", "PASSWORD", "CREDENTIAL")


class LaneRegistryError(ValueError):
    """The source-owned lane registry is incomplete or unsafe to execute."""


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise LaneRegistryError(f"cannot read lane registry: {path}") from error
    if not isinstance(value, dict):
        raise LaneRegistryError("lane registry must be a JSON object")
    return value


def _require_string(value: object, field: str) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise LaneRegistryError(f"{field} must be a nonblank string")
    return normalized


def _relative_script(root: Path, argv: tuple[str, ...], label: str) -> None:
    if len(argv) != 2 or argv[0] != "bash":
        raise LaneRegistryError(f"{label} must invoke one repository-relative bash script")
    script = Path(argv[1])
    if script.is_absolute() or ".." in script.parts:
        raise LaneRegistryError(f"{label} script must remain inside its repository")
    if not (root / script).is_file():
        raise LaneRegistryError(f"{label} script is missing: {script}")


def load_registry(
    *,
    path: Path,
    ios_root: Path,
    backend_root: Path,
) -> tuple[dict[str, Any], ...]:
    raw = _read_json(path)
    if raw.get("schemaVersion") != SCHEMA_VERSION:
        raise LaneRegistryError("lane registry schema version is unsupported")
    raw_lanes = raw.get("lanes")
    if not isinstance(raw_lanes, list) or not raw_lanes:
        raise LaneRegistryError("lane registry requires lanes")

    normalized: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    roots = {"ios": ios_root, "backend": backend_root}
    for index, raw_lane in enumerate(raw_lanes):
        if not isinstance(raw_lane, dict):
            raise LaneRegistryError(f"lanes[{index}] must be an object")
        lane_id = _require_string(raw_lane.get("id"), f"lanes[{index}].id")
        if lane_id not in LANE_ORDER or lane_id in seen_ids:
            raise LaneRegistryError(f"lane id is unsupported or duplicated: {lane_id}")
        seen_ids.add(lane_id)
        title = _require_string(raw_lane.get("title"), f"lanes[{index}].title")
        default_state = _require_string(raw_lane.get("defaultState"), f"lanes[{index}].defaultState")
        if default_state not in ALLOWED_DEFAULT_STATES:
            raise LaneRegistryError(f"lane {lane_id} has unsupported default state")
        default_off = raw_lane.get("defaultOff")
        if not isinstance(default_off, bool):
            raise LaneRegistryError(f"lane {lane_id} defaultOff must be boolean")
        if default_state == "closedPilotDefaultOff" and not default_off:
            raise LaneRegistryError(f"lane {lane_id} must remain default-off")

        raw_environment = raw_lane.get("requiredEnvironment")
        if not isinstance(raw_environment, list) or not all(
            isinstance(item, str) and ENVIRONMENT_NAME.fullmatch(item) for item in raw_environment
        ):
            raise LaneRegistryError(f"lane {lane_id} has invalid requiredEnvironment")
        if len(set(raw_environment)) != len(raw_environment):
            raise LaneRegistryError(f"lane {lane_id} duplicates requiredEnvironment")

        raw_commands = raw_lane.get("commands")
        if not isinstance(raw_commands, list) or not raw_commands:
            raise LaneRegistryError(f"lane {lane_id} requires commands")
        commands: list[dict[str, Any]] = []
        command_ids: set[str] = set()
        for command_index, raw_command in enumerate(raw_commands):
            if not isinstance(raw_command, dict):
                raise LaneRegistryError(f"lane {lane_id} command must be an object")
            command_id = _require_string(
                raw_command.get("id"), f"lane {lane_id} command {command_index}.id"
            )
            if command_id in command_ids:
                raise LaneRegistryError(f"lane {lane_id} has duplicate command id: {command_id}")
            command_ids.add(command_id)
            repo = _require_string(raw_command.get("repo"), f"lane {lane_id} command {command_id}.repo")
            if repo not in roots:
                raise LaneRegistryError(f"lane {lane_id} command {command_id} has unknown repository")
            raw_argv = raw_command.get("argv")
            if not isinstance(raw_argv, list) or not all(isinstance(item, str) for item in raw_argv):
                raise LaneRegistryError(f"lane {lane_id} command {command_id} argv is invalid")
            argv = tuple(item.strip() for item in raw_argv)
            _relative_script(roots[repo], argv, f"lane {lane_id} command {command_id}")
            timeout = raw_command.get("timeoutSeconds")
            if isinstance(timeout, bool) or not isinstance(timeout, int) or not 10 <= timeout <= 7200:
                raise LaneRegistryError(f"lane {lane_id} command {command_id} timeout is invalid")
            commands.append(
                {
                    "id": command_id,
                    "repo": repo,
                    "argv": argv,
                    "timeoutSeconds": timeout,
                }
            )

        raw_blockers = raw_lane.get("remainingGates")
        if not isinstance(raw_blockers, list) or not raw_blockers:
            raise LaneRegistryError(f"lane {lane_id} requires explicit remainingGates")
        blockers: list[dict[str, str]] = []
        blocker_ids: set[str] = set()
        for blocker in raw_blockers:
            if not isinstance(blocker, dict):
                raise LaneRegistryError(f"lane {lane_id} blocker must be an object")
            kind = _require_string(blocker.get("kind"), f"lane {lane_id} blocker kind")
            blocker_id = _require_string(blocker.get("id"), f"lane {lane_id} blocker id")
            if kind not in ALLOWED_BLOCKER_KINDS or blocker_id in blocker_ids:
                raise LaneRegistryError(f"lane {lane_id} blocker is invalid")
            blocker_ids.add(blocker_id)
            blockers.append({"kind": kind, "id": blocker_id})

        normalized.append(
            {
                "id": lane_id,
                "title": title,
                "defaultState": default_state,
                "defaultOff": default_off,
                "requiredEnvironment": tuple(raw_environment),
                "commands": tuple(commands),
                "remainingGates": tuple(blockers),
            }
        )

    if set(seen_ids) != set(LANE_ORDER):
        raise LaneRegistryError("lane registry must explicitly classify m0, stage2, m1 and m2")
    return tuple(sorted(normalized, key=lambda item: LANE_ORDER.index(item["id"])))


def _revision(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def _selected_lanes(lanes: tuple[dict[str, Any], ...], raw_selection: str) -> tuple[dict[str, Any], ...]:
    requested = tuple(value.strip() for value in raw_selection.split(",") if value.strip())
    if not requested or requested == ("all",):
        return lanes
    if len(set(requested)) != len(requested) or any(value not in LANE_ORDER for value in requested):
        raise LaneRegistryError("--lanes must be a unique comma-separated subset of m0,stage2,m1,m2")
    lane_by_id = {lane["id"]: lane for lane in lanes}
    return tuple(lane_by_id[lane_id] for lane_id in LANE_ORDER if lane_id in requested)


def _safe_path(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _redact_command_log(*, raw_path: Path, destination_path: Path, environment: Mapping[str, str]) -> None:
    """Persist command output without copying configured secret values into evidence."""

    try:
        content = raw_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        content = ""
    for name, value in environment.items():
        if not any(fragment in name.upper() for fragment in SENSITIVE_ENVIRONMENT_FRAGMENTS):
            continue
        normalized = str(value or "")
        if len(normalized) < 4 or "\n" in normalized or "\r" in normalized:
            continue
        content = content.replace(normalized, f"[REDACTED:{name}]")
    destination_path.write_text(content, encoding="utf-8")
    try:
        raw_path.unlink()
    except OSError:
        pass


def _run_lane(
    *,
    lane: Mapping[str, Any],
    execute: bool,
    run_id: str,
    output_dir: Path,
    ios_root: Path,
    backend_root: Path,
) -> dict[str, Any]:
    lane_dir = output_dir / str(lane["id"])
    lane_dir.mkdir(parents=True, exist_ok=True)
    missing_environment = tuple(
        name for name in lane["requiredEnvironment"] if not os.environ.get(name, "").strip()
    )
    command_results: list[dict[str, Any]] = []
    if not execute:
        command_results = [
            {
                "id": command["id"],
                "status": "notRun",
                "repo": command["repo"],
            }
            for command in lane["commands"]
        ]
        execution_status = "notRun"
    elif missing_environment:
        command_results = [
            {
                "id": command["id"],
                "status": "blocked",
                "repo": command["repo"],
                "reasonCode": "requiredEnvironmentMissing",
            }
            for command in lane["commands"]
        ]
        execution_status = "blocked"
    else:
        roots = {"ios": ios_root, "backend": backend_root}
        for command in lane["commands"]:
            command_dir = lane_dir / str(command["id"])
            command_dir.mkdir(parents=True, exist_ok=True)
            log_path = command_dir / "command.log"
            raw_log_path = command_dir / "command.raw.log"
            environment = dict(os.environ)
            environment.update(
                {
                    "RUN_ID": f"{run_id}-{lane['id']}-{command['id']}",
                    "OUTPUT_ROOT": str(command_dir / "evidence"),
                    "V4_UNIFIED_LANE_ID": str(lane["id"]),
                }
            )
            started_at = _utc_now()
            try:
                with raw_log_path.open("w", encoding="utf-8") as handle:
                    completed = subprocess.run(
                        command["argv"],
                        cwd=roots[command["repo"]],
                        env=environment,
                        stdout=handle,
                        stderr=subprocess.STDOUT,
                        timeout=command["timeoutSeconds"],
                        check=False,
                    )
                _redact_command_log(
                    raw_path=raw_log_path,
                    destination_path=log_path,
                    environment=environment,
                )
                status = "passed" if completed.returncode == 0 else "failed"
                command_results.append(
                    {
                        "id": command["id"],
                        "status": status,
                        "repo": command["repo"],
                        "exitCode": completed.returncode,
                        "log": _safe_path(log_path, output_dir),
                        "startedAt": started_at,
                        "finishedAt": _utc_now(),
                    }
                )
            except subprocess.TimeoutExpired:
                _redact_command_log(
                    raw_path=raw_log_path,
                    destination_path=log_path,
                    environment=environment,
                )
                command_results.append(
                    {
                        "id": command["id"],
                        "status": "failed",
                        "repo": command["repo"],
                        "reasonCode": "commandTimeout",
                        "log": _safe_path(log_path, output_dir),
                        "startedAt": started_at,
                        "finishedAt": _utc_now(),
                    }
                )
            except OSError:
                _redact_command_log(
                    raw_path=raw_log_path,
                    destination_path=log_path,
                    environment=environment,
                )
                command_results.append(
                    {
                        "id": command["id"],
                        "status": "failed",
                        "repo": command["repo"],
                        "reasonCode": "commandExecutionFailed",
                        "log": _safe_path(log_path, output_dir),
                        "startedAt": started_at,
                        "finishedAt": _utc_now(),
                    }
                )
        execution_status = "passed" if all(
            result["status"] == "passed" for result in command_results
        ) else "failed"

    return {
        "id": lane["id"],
        "title": lane["title"],
        "defaultState": lane["defaultState"],
        "defaultOff": lane["defaultOff"],
        "executionStatus": execution_status,
        "requiredEnvironmentConfigured": not missing_environment,
        "commands": command_results,
        "remainingGates": list(lane["remainingGates"]),
    }


def build_evidence(
    *,
    registry_path: Path,
    ios_root: Path,
    backend_root: Path,
    output_root: Path,
    run_id: str,
    selected: str,
    execute: bool,
) -> tuple[Path, dict[str, Any]]:
    lanes = _selected_lanes(
        load_registry(path=registry_path, ios_root=ios_root, backend_root=backend_root),
        selected,
    )
    output_dir = output_root / run_id
    output_dir.mkdir(parents=True, exist_ok=True)
    lane_results = [
        _run_lane(
            lane=lane,
            execute=execute,
            run_id=run_id,
            output_dir=output_dir,
            ios_root=ios_root,
            backend_root=backend_root,
        )
        for lane in lanes
    ]
    statuses = {str(item["executionStatus"]) for item in lane_results}
    execution_status = (
        "notRun"
        if not execute
        else "passed"
        if statuses == {"passed"}
        else "blocked"
        if "blocked" in statuses and "failed" not in statuses
        else "failed"
    )
    payload = {
        "schemaVersion": EVIDENCE_SCHEMA_VERSION,
        "runId": run_id,
        "generatedAt": _utc_now(),
        "mode": "execute" if execute else "dryRun",
        "iosRevision": _revision(ios_root),
        "backendRevision": _revision(backend_root),
        "executionStatus": execution_status,
        # A non-device evidence bundle is never a public-release approval.
        "releaseDecision": "NO_GO",
        "releaseDecisionReason": "nonDeviceEvidenceCannotCloseExternalOrDeviceGates",
        "lanes": lane_results,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(payload, ensure_ascii=True, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    report_lines = [
        "# V4 Unified Non-device Evidence",
        "",
        f"- Run ID: `{run_id}`",
        f"- Mode: `{payload['mode']}`",
        f"- Execution: `{execution_status}`",
        "- Release decision: `NO_GO` (non-device evidence cannot close external or device gates).",
        "",
        "## Lanes",
    ]
    for lane in lane_results:
        report_lines.append(
            f"- `{lane['id']}`: `{lane['executionStatus']}`, default state `{lane['defaultState']}`."
        )
    report_lines.extend(["", "- Manifest: `manifest.json`"])
    (output_dir / "report.md").write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    return manifest_path, payload


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="DreamJourney V4 non-device lane evidence runner")
    script_dir = Path(__file__).resolve().parent
    parser.add_argument(
        "--registry",
        type=Path,
        default=script_dir / "v4-non-device-release-lanes-v1.json",
    )
    parser.add_argument(
        "--ios-root",
        type=Path,
        default=script_dir.parents[2],
    )
    parser.add_argument(
        "--backend-root",
        type=Path,
        default=script_dir.parents[2].parent / "DreamJourneyBackend",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path(
            os.environ.get(
                "OUTPUT_ROOT",
                str(script_dir.parents[2] / "tmp/qa/v4-unified-non-device-evidence"),
            )
        ),
    )
    parser.add_argument(
        "--run-id",
        default=os.environ.get("RUN_ID", datetime.now().strftime("%Y%m%d-%H%M%S") + "-v4-unified"),
    )
    parser.add_argument("--lanes", default="all")
    parser.add_argument("--execute", action="store_true", help="run lane-local gates; default is dry-run")
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = _parser().parse_args(list(argv) if argv is not None else None)
    try:
        manifest_path, payload = build_evidence(
            registry_path=args.registry.resolve(),
            ios_root=args.ios_root.resolve(),
            backend_root=args.backend_root.resolve(),
            output_root=args.output_root.resolve(),
            run_id=_require_string(args.run_id, "run id"),
            selected=args.lanes,
            execute=args.execute,
        )
    except LaneRegistryError as error:
        print(f"v4 unified lane evidence rejected: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"manifest": str(manifest_path), "executionStatus": payload["executionStatus"]}))
    return 0 if payload["executionStatus"] in {"passed", "notRun"} else 1


if __name__ == "__main__":  # pragma: no cover - exercised by the QA runner check
    raise SystemExit(main())
