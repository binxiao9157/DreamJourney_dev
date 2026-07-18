#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/memoir-tts-cache-owner-scope-check.py
swiftc -frontend -parse DreamJourney/Sources/Memoir/MemoirTTSService.swift

echo "Memoir TTS cache owner-scope gate passed"
