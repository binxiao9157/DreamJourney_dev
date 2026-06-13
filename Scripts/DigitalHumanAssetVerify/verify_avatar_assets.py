#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import json
import sys
from pathlib import Path


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def iter_resources(manifest):
    resources = manifest.get("resources", {})
    for key in ("video", "data", "wasm", "poster", "common_texture"):
        item = resources.get(key)
        if item:
            yield key, item
    for index, item in enumerate(resources.get("js", []), start=1):
        yield f"js[{index}]", item


def validate_resource(root, label, item):
    path_value = item.get("path")
    expected_sha = item.get("sha256")
    if not path_value or not expected_sha:
        return [f"{label}: missing path or sha256"]

    path = root / path_value
    if not path.is_file():
        return [f"{label}: missing file {path_value}"]

    actual_sha = sha256_file(path)
    if actual_sha != expected_sha:
        return [f"{label}: sha256 mismatch for {path_value}"]

    print(f"OK: {label} {path_value}")
    return []


def validate_combined_data(root, manifest):
    resources = manifest.get("resources", {})
    data_item = resources.get("data", {})
    data_path_value = data_item.get("path")
    if not data_path_value:
        return ["data: manifest missing resources.data.path"]

    data_path = root / data_path_value
    try:
        with gzip.open(data_path, "rt", encoding="utf-8") as handle:
            combined = json.load(handle)
    except Exception as error:
        return [f"data: gzip JSON decode failed for {data_path_value}: {error}"]

    requirements = manifest.get("combined_data_requirements", {})
    required_fields = requirements.get("required_fields", [])
    missing_fields = [field for field in required_fields if field not in combined]
    errors = [f"data: missing required field {field}" for field in missing_fields]

    expected_size = requirements.get("expected_size", manifest.get("model_size"))
    if expected_size is not None and combined.get("size") != expected_size:
        errors.append(f"data: size mismatch, expected {expected_size}, got {combined.get('size')}")

    if "json_data" in combined and "frame_count" in manifest:
        json_data = combined.get("json_data")
        if not isinstance(json_data, list):
            errors.append("data: json_data must be a list")
        elif len(json_data) != manifest["frame_count"]:
            errors.append(
                f"data: json_data length mismatch, expected {manifest['frame_count']}, got {len(json_data)}"
            )

    if "face3D_obj" in combined and not isinstance(combined.get("face3D_obj"), list):
        errors.append("data: face3D_obj must be a list")

    if "version" in combined and not isinstance(combined.get("version"), (int, str)):
        errors.append("data: version must be an integer or string")

    if not errors:
        print(
            "OK: combined_data fields "
            f"version={combined.get('version')} size={combined.get('size')} "
            f"json_data={len(combined.get('json_data', []))} face3D_obj={len(combined.get('face3D_obj', []))}"
        )
    return errors


def validate_manifest(manifest):
    errors = []
    expected = {
        "engine": "DHLiveMini",
        "engine_version": "mini2.0",
        "model_size": 184,
        "fps": 25,
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            errors.append(f"manifest: {key} must be {value}, got {manifest.get(key)}")

    labels = [label for label, _ in iter_resources(manifest)]
    for label in ("video", "data", "wasm", "poster", "common_texture"):
        if label not in labels:
            errors.append(f"manifest: missing {label} resource")
    if not manifest.get("resources", {}).get("js"):
        errors.append("manifest: missing js resources")
    return errors


def main():
    parser = argparse.ArgumentParser(description="Verify DreamJourney digital human avatar assets.")
    parser.add_argument(
        "--manifest",
        default="DreamJourney/Resources/web/avatar_manifest.json",
        help="Path to avatar_manifest.json from repository root.",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    manifest_path = (repo_root / args.manifest).resolve()
    if not manifest_path.is_file():
        return fail(f"manifest not found: {args.manifest}")

    try:
        manifest = load_json(manifest_path)
    except Exception as error:
        return fail(f"manifest JSON decode failed: {error}")

    asset_root = manifest_path.parent
    errors = validate_manifest(manifest)
    for label, item in iter_resources(manifest):
        errors.extend(validate_resource(asset_root, label, item))
    errors.extend(validate_combined_data(asset_root, manifest))

    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print("OK: avatar manifest verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
