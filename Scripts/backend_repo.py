#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path


def resolve_backend_repo(root: Path | None = None) -> Path:
    candidates: list[Path] = []
    configured = os.getenv("DREAMJOURNEY_BACKEND_REPO", "").strip()
    if configured:
        candidates.append(Path(configured).expanduser())

    if root is not None:
        candidates.append(root / "DreamJourneyBackend")

    candidates.append(Path.home() / "Documents/Codex/Video/DreamJourneyBackend")

    for candidate in candidates:
        if (candidate / "app/main.py").is_file() and (candidate / "tests").is_dir():
            return candidate.resolve()

    searched = "\n".join(f"- {candidate}" for candidate in candidates)
    raise FileNotFoundError(
        "DreamJourneyBackend repository not found. Set "
        "DREAMJOURNEY_BACKEND_REPO=/path/to/DreamJourneyBackend.\n"
        f"Searched:\n{searched}"
    )


def backend_file(root: Path, relative_path: str) -> Path:
    return resolve_backend_repo(root) / relative_path
