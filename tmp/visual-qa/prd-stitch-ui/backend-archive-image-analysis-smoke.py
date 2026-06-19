#!/usr/bin/env python3
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


if len(sys.argv) < 4:
    raise SystemExit(
        "Usage: backend-archive-image-analysis-smoke.py <app-root> <user-id> <marker> [image-path]"
    )

APP_ROOT = Path(sys.argv[1])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ID = sys.argv[2]
MARKER = re.sub(r"[^A-Za-z0-9_-]", "_", sys.argv[3])
IMAGE_PATH = (
    Path(sys.argv[4])
    if len(sys.argv) > 4
    else APP_ROOT / "DreamJourney/Assets.xcassets/default_memory_1.imageset/memory.jpg"
)

if not BASE_URL:
    raise SystemExit("BACKEND_BASE_URL is required")
if not API_TOKEN:
    raise SystemExit("BACKEND_API_TOKEN is required")
if not IMAGE_PATH.exists():
    raise SystemExit(f"image fixture not found: {IMAGE_PATH}")

ARCHIVE_ID = f"archive_image_analysis_smoke_{MARKER}"


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    params: Optional[Dict[str, str]] = None,
    *,
    auth: bool = True,
    expected: int = 200,
    timeout: int = 90,
) -> Dict[str, Any]:
    url = f"{BASE_URL}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    data = None
    headers = {"Accept": "application/json"}
    if auth:
        headers["Authorization"] = f"Bearer {API_TOKEN}"
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            status = response.status
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        if error.code == expected:
            return json.loads(body) if body else {}
        raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return json.loads(body) if body else {}


def string_list(value: Any) -> List[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def read_image_base64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def assert_deployed_contract_preflight(image_base64: str) -> Dict[str, Any]:
    dry_run_payload = {
        "userId": USER_ID,
        "archiveItemId": ARCHIVE_ID,
        "imageBase64": image_base64[:96],
        "privacyMetadata": {
            "scope": "generationAllowed",
            "contentType": "photo",
            "aiAnalysisAllowed": True,
        },
    }
    dry_run = request_json(
        "POST",
        "/archive/image-analysis",
        dry_run_payload,
        params={"dryRun": "true"},
        timeout=20,
    )
    response_contract = dry_run.get("responseContract")
    if not isinstance(response_contract, dict):
        raise AssertionError("deployed backend contract is stale: dryRun responseContract is missing")
    for key in [
        "analysisStatus",
        "analysisSummary",
        "detectedPeople",
        "detectedLocations",
        "detectedScenes",
        "tags",
        "analysisFailureReason",
        "analysisRetryable",
    ]:
        if key not in response_contract:
            raise AssertionError(f"deployed backend contract is stale: responseContract missing {key}")
    return {
        "provider": dry_run.get("provider"),
        "capability": dry_run.get("capability"),
        "responseContractKeys": sorted(response_contract.keys()),
    }


def assert_runtime_archive_image_analysis_contract() -> Dict[str, Any]:
    config = request_json("GET", "/config/runtime", timeout=20)
    capability = config.get("archiveImageAnalysis")
    if not isinstance(capability, dict):
        raise AssertionError("deployed backend contract is stale: archiveImageAnalysis runtime capability is missing")
    if capability.get("endpoint") != "/archive/image-analysis":
        raise AssertionError("archiveImageAnalysis endpoint should be /archive/image-analysis")
    if capability.get("provider") != "deepseek/text-only":
        raise AssertionError("archiveImageAnalysis provider should be deepseek/text-only until a vision provider is configured")
    if capability.get("supportsVision") is not False:
        raise AssertionError("archiveImageAnalysis supportsVision should be false for deepseek/text-only")
    if capability.get("fallbackMode") != "retryableFailure":
        raise AssertionError("archiveImageAnalysis fallbackMode should be retryableFailure")
    expected_statuses = ["pending", "analyzing", "analyzed", "failed", "retryable"]
    if capability.get("statuses") != expected_statuses:
        raise AssertionError(f"archiveImageAnalysis statuses changed: {capability.get('statuses')!r}")
    capabilities = config.get("capabilities") or {}
    if capabilities.get("archiveImageAnalysis") != capability.get("enabled"):
        raise AssertionError("capabilities.archiveImageAnalysis should match archiveImageAnalysis.enabled")
    return {
        "enabled": capability.get("enabled"),
        "provider": capability.get("provider"),
        "supportsVision": capability.get("supportsVision"),
        "fallbackMode": capability.get("fallbackMode"),
        "statuses": capability.get("statuses"),
    }


def normalize_analysis_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "analysisStatus": str(payload.get("analysisStatus") or "").strip(),
        "analysisSummary": str(payload.get("analysisSummary") or payload.get("description") or "").strip(),
        "description": str(payload.get("description") or payload.get("analysisSummary") or "").strip(),
        "detectedPeople": string_list(payload.get("detectedPeople")),
        "detectedLocations": string_list(payload.get("detectedLocations")),
        "detectedScenes": string_list(payload.get("detectedScenes")),
        "tags": string_list(payload.get("tags")),
        "scene": str(payload.get("scene") or "").strip(),
        "occasion": str(payload.get("occasion") or "").strip(),
        "mood": str(payload.get("mood") or "").strip(),
        "estimatedDecade": payload.get("estimatedDecade"),
        "analysisFailureReason": str(payload.get("analysisFailureReason") or "").strip(),
        "analysisRetryable": bool(payload.get("analysisRetryable")),
    }


def assert_analysis_contract(analysis: Dict[str, Any]) -> str:
    status = analysis["analysisStatus"]
    if status == "analyzed":
        assert_true(
            analysis["analysisSummary"]
            or analysis["detectedPeople"]
            or analysis["detectedLocations"]
            or analysis["detectedScenes"]
            or analysis["tags"],
            "image analysis should return a summary or displayable clues",
        )
        assert_equal(analysis["analysisFailureReason"], "", "successful image analysis failure reason")
        assert_equal(analysis["analysisRetryable"], False, "successful image analysis retry flag")
        return "analyzed"

    if status == "failed":
        assert_true(analysis["analysisFailureReason"], "failed image analysis should include analysisFailureReason")
        assert_equal(analysis["analysisRetryable"], True, "failed image analysis should be retryable")
        if analysis["analysisFailureReason"] != "provider_unavailable":
            raise AssertionError(
                "failed image analysis should use provider_unavailable until a real visual provider is configured"
            )
        return "failed_retryable_provider_unavailable"

    raise AssertionError(f"image analysis status should be analyzed or failed, got {status!r}")


def make_archive_payload(analysis: Dict[str, Any]) -> Dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "userId": USER_ID,
        "id": ARCHIVE_ID,
        "kind": "photo",
        "source": "photoLibrary",
        "title": "相册影像",
        "note": "部署后端图像分析 smoke 相册导入样本",
        "description": analysis["description"] or analysis["analysisSummary"],
        "analysisStatus": analysis["analysisStatus"],
        "analysisSummary": analysis["analysisSummary"],
        "detectedPeople": analysis["detectedPeople"],
        "detectedLocations": analysis["detectedLocations"],
        "detectedScenes": analysis["detectedScenes"],
        "tags": analysis["tags"],
        "analysisFailureReason": analysis["analysisFailureReason"],
        "analysisRetryable": analysis["analysisRetryable"],
        "createdAt": now,
        "ownerId": USER_ID,
        "ownerDisplayName": "Backend Smoke",
        "ownerRole": "self",
        "managedByUserId": USER_ID,
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {
            "scope": "generationAllowed",
            "contentType": "photo",
            "aiAnalysisAllowed": True,
            "syncReason": "backend-archive-image-analysis-smoke",
        },
        "metadata": {
            "source": "album_import",
            "smokeMarker": MARKER,
            "scene": analysis["scene"],
            "occasion": analysis["occasion"],
            "mood": analysis["mood"],
            "estimatedDecade": analysis["estimatedDecade"],
        },
    }


def find_item(items: List[Dict[str, Any]], item_id: str) -> Dict[str, Any]:
    for item in items:
        if item.get("id") == item_id:
            return item
    raise AssertionError(f"archive item {item_id} missing from GET /archive/items/{USER_ID}")


health = request_json("GET", "/health", auth=False, timeout=10)
assert_equal(health.get("status"), "ok", "health status")
assert_equal(health.get("store"), "postgres", "deployed backend must use Postgres")
runtime_archive_image_analysis = assert_runtime_archive_image_analysis_contract()

image_base64 = read_image_base64(IMAGE_PATH)
contract_preflight = assert_deployed_contract_preflight(image_base64)
analysis_request = {
    "userId": USER_ID,
    "archiveItemId": ARCHIVE_ID,
    "imageBase64": image_base64,
    "privacyMetadata": {
        "scope": "generationAllowed",
        "contentType": "photo",
        "aiAnalysisAllowed": True,
    },
}
analysis_result = normalize_analysis_payload(
    request_json("POST", "/archive/image-analysis", analysis_request, timeout=120)
)
analysis_contract_mode = assert_analysis_contract(analysis_result)

archive_payload = make_archive_payload(analysis_result)
saved_response = request_json("POST", "/archive/items", archive_payload, timeout=20)
assert_equal(saved_response.get("status"), "saved", "archive item save status")
persisted_item = saved_response.get("item") or {}
assert_equal(persisted_item.get("id"), ARCHIVE_ID, "persisted archive id")
assert_equal(persisted_item.get("metadataOnly"), True, "persisted archive item should be metadataOnly")

listed_response = request_json("GET", f"/archive/items/{urllib.parse.quote(USER_ID)}", timeout=20)
items = listed_response.get("items") or []
assert_true(isinstance(items, list), "archive list response should include items")
listed_item = find_item(items, ARCHIVE_ID)

for key in [
    "analysisStatus",
    "analysisSummary",
    "detectedPeople",
    "detectedLocations",
    "detectedScenes",
    "tags",
    "analysisFailureReason",
    "analysisRetryable",
    "personaScope",
    "digitalHumanId",
]:
    assert_equal(listed_item.get(key), archive_payload.get(key), f"read-after-write field {key}")

metadata = listed_item.get("metadata") or {}
assert_equal(metadata.get("source"), "album_import", "listed item metadata source")
assert_equal(metadata.get("smokeMarker"), MARKER, "listed item smoke marker")

result = {
    "completed": True,
    "baseUrl": BASE_URL,
    "health": health,
    "runtime_archive_image_analysis": runtime_archive_image_analysis,
    "userId": USER_ID,
    "archiveItemId": ARCHIVE_ID,
    "imageFixture": str(IMAGE_PATH.relative_to(APP_ROOT)) if IMAGE_PATH.is_relative_to(APP_ROOT) else str(IMAGE_PATH),
    "contract_preflight": contract_preflight,
    "analysis_contract_mode": analysis_contract_mode,
    "analysis_result": analysis_result,
    "persisted_item": {
        "id": persisted_item.get("id"),
        "analysisStatus": persisted_item.get("analysisStatus"),
        "detectedPeople": string_list(persisted_item.get("detectedPeople")),
        "detectedLocations": string_list(persisted_item.get("detectedLocations")),
        "detectedScenes": string_list(persisted_item.get("detectedScenes")),
        "tags": string_list(persisted_item.get("tags")),
        "analysisFailureReason": persisted_item.get("analysisFailureReason"),
        "analysisRetryable": persisted_item.get("analysisRetryable"),
        "metadataOnly": persisted_item.get("metadataOnly"),
    },
    "listed_item": {
        "id": listed_item.get("id"),
        "analysisStatus": listed_item.get("analysisStatus"),
        "detectedPeople": string_list(listed_item.get("detectedPeople")),
        "detectedLocations": string_list(listed_item.get("detectedLocations")),
        "detectedScenes": string_list(listed_item.get("detectedScenes")),
        "tags": string_list(listed_item.get("tags")),
        "analysisFailureReason": listed_item.get("analysisFailureReason"),
        "analysisRetryable": listed_item.get("analysisRetryable"),
        "metadata": metadata,
    },
}

print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
