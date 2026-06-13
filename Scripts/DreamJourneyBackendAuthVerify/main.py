#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
CONFIG = ROOT / "DreamJourney/Sources/Services/AppConfiguration.swift"
BACKEND_CONFIG = ROOT / "DreamJourneyBackend/app/core/config.py"
BACKEND_MAIN = ROOT / "DreamJourneyBackend/app/main.py"
BACKEND_IDENTITY = ROOT / "DreamJourneyBackend/app/services/user_identity.py"
BACKEND_MEMORY_STORE = ROOT / "DreamJourneyBackend/app/services/in_memory_store.py"
BACKEND_POSTGRES_STORE = ROOT / "DreamJourneyBackend/app/services/postgres_store.py"
BACKEND_TESTS = ROOT / "DreamJourneyBackend/tests/test_core_services.py"
BACKEND_POSTGRES_TESTS = ROOT / "DreamJourneyBackend/tests/test_postgres_store.py"
VERIFY = ROOT / "Scripts/verify_phase1.sh"

client = CLIENT.read_text(encoding="utf-8")
config = CONFIG.read_text(encoding="utf-8")
backend_config = BACKEND_CONFIG.read_text(encoding="utf-8")
backend_main = BACKEND_MAIN.read_text(encoding="utf-8")
backend_identity = BACKEND_IDENTITY.read_text(encoding="utf-8")
backend_memory_store = BACKEND_MEMORY_STORE.read_text(encoding="utf-8")
backend_postgres_store = BACKEND_POSTGRES_STORE.read_text(encoding="utf-8")
backend_tests = BACKEND_TESTS.read_text(encoding="utf-8")
backend_postgres_tests = BACKEND_POSTGRES_TESTS.read_text(encoding="utf-8")
phase1 = VERIFY.read_text(encoding="utf-8")

checks = [
    (
        "iOS client should define a backend API token config key",
        'private static let apiTokenKey = "DreamJourneyBackendAPIToken"' in client,
    ),
    (
        "iOS config should read DreamJourneyBackendAPIToken from plist/env",
        '"DreamJourneyBackendAPIToken"' in config,
    ),
    (
        "iOS client should attach bearer authorization when configured",
        'request.setValue("Bearer \\(apiToken)", forHTTPHeaderField: "Authorization")' in client,
    ),
    (
        "iOS client should attach an explicit DreamJourney token header",
        'request.setValue(apiToken, forHTTPHeaderField: "X-DreamJourney-API-Token")' in client,
    ),
    (
        "manual GET requests should go through the same backend auth helper",
        client.count("authorizeBackendRequest(&request)") >= 4,
    ),
    (
        "backend settings should expose BACKEND_API_TOKEN",
        "backend_api_token" in backend_config and '"BACKEND_API_TOKEN"' in backend_config,
    ),
    (
        "backend should compare tokens in constant time",
        "secrets.compare_digest" in backend_main,
    ),
    (
        "backend should reject missing or invalid tokens when configured",
        "test_backend_api_token_required_when_configured" in backend_tests
        and "Authorization" in backend_tests
        and "401" in backend_tests,
    ),
    (
        "backend should expose the same stable full-phone user id helper as iOS",
        "def stable_user_id(phone: str) -> str" in backend_identity
        and "FNV_PRIME" in backend_identity
        and "normalized_phone_digits" in backend_identity,
    ),
    (
        "backend stores should not derive user id from the last four phone digits",
        "stable_user_id(phone)" in backend_memory_store
        and "stable_user_id(phone)" in backend_postgres_store
        and "phone[-4:]" not in backend_memory_store
        and "phone[-4:]" not in backend_postgres_store,
    ),
    (
        "backend tests should cover last-four phone collisions for auth login and postgres users",
        "test_auth_login_uses_stable_full_phone_hash_not_last_four_digits" in backend_tests
        and "test_upsert_user_uses_stable_full_phone_hash" in backend_postgres_tests
        and "user_aef88d2439c15d38" in backend_tests
        and "user_aef88d2439c15d38" in backend_postgres_tests,
    ),
    (
        "phase1 verification should cover backend auth",
        "DreamJourneyBackendAuthVerify/main.py" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"DreamJourneyBackendAuth verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DreamJourneyBackendAuth verification passed")
