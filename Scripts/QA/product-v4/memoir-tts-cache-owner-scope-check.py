#!/usr/bin/env python3

from dataclasses import dataclass
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "DreamJourney/Sources/Memoir/MemoirTTSService.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {marker}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated declaration: {marker}")


def function_body(source: str, pattern: str, label: str) -> str:
    match = re.search(pattern, source, re.MULTILINE)
    require(match is not None, f"missing function: {label}")
    opening = source.find("{", match.end())
    require(opening >= 0, f"missing body: {label}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function: {label}")


def compact(value: str) -> str:
    return "".join(value.split())


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(source)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


@dataclass(frozen=True)
class Lease:
    subject_id: str
    vault_id: str
    generation: int
    generation_id: str
    session_id: str


def cache_scope(lease: Lease) -> tuple[str, str, int, str]:
    return (
        lease.subject_id.strip(),
        lease.vault_id.strip(),
        lease.generation,
        lease.generation_id.lower(),
    )


def cache_identity(
    memoir_id: str,
    persona_owner_id: str,
    role_key: str,
    voice_profile_id: str,
    text_hash: str,
    audio_format: str,
    provider_mode: str,
) -> tuple[str, str, str, str, str, str, str]:
    return (
        memoir_id.strip(),
        persona_owner_id.strip(),
        role_key.strip(),
        voice_profile_id.strip(),
        text_hash.strip(),
        audio_format.strip().lower(),
        provider_mode.strip().lower(),
    )


def run_scope_model() -> None:
    alice = Lease("alice", "vault-a", 7, "generation-a", "session-old")
    alice_refresh = Lease("alice", "vault-a", 7, "generation-a", "session-new")
    alice_new_generation = Lease("alice", "vault-a", 8, "generation-b", "session-new")
    bob = Lease("bob", "vault-b", 7, "generation-c", "session-b")

    require(
        cache_scope(alice) == cache_scope(alice_refresh),
        "same-generation session refresh must retain the cache scope",
    )
    require(
        cache_scope(alice) != cache_scope(alice_new_generation),
        "new account generation for the same subject must not reuse cache",
    )
    require(
        cache_scope(alice) != cache_scope(bob),
        "different account subjects must not share cache",
    )

    alice_profile_a = cache_identity(
        "memoir-1", "alice", "memoir", "S_alice_a", "text-a", "mp3", "volcengine"
    )
    alice_profile_b = cache_identity(
        "memoir-1", "alice", "memoir", "S_alice_b", "text-a", "mp3", "volcengine"
    )
    alice_changed_text = cache_identity(
        "memoir-1", "alice", "memoir", "S_alice_a", "text-b", "mp3", "volcengine"
    )
    alice_changed_provider = cache_identity(
        "memoir-1", "alice", "memoir", "S_alice_a", "text-a", "mp3", "mockcontract"
    )
    scoped_cache = {(cache_scope(alice), alice_profile_a): "alice-profile-a-audio"}
    require(
        scoped_cache.get((cache_scope(alice_refresh), alice_profile_a)) == "alice-profile-a-audio",
        "same-generation refreshed session must read existing cache",
    )
    require(
        scoped_cache.get((cache_scope(alice_new_generation), alice_profile_a)) is None,
        "new generation must fail closed for the same memoir id",
    )
    require(
        scoped_cache.get((cache_scope(bob), alice_profile_a)) is None,
        "another subject must fail closed for the same memoir id",
    )
    require(
        alice_profile_a != alice_profile_b,
        "different voice profiles must not share a cache identity",
    )
    require(
        alice_profile_a != alice_changed_text,
        "changed memoir text must not reuse an earlier audio identity",
    )
    require(
        alice_profile_a != alice_changed_provider,
        "different synthesis providers must not reuse an earlier audio identity",
    )
    require(
        scoped_cache.get((cache_scope(alice), alice_profile_b)) is None,
        "a requested profile must never resolve another profile's audio",
    )


def run_static_check() -> None:
    require(SOURCE_PATH.is_file(), "MemoirTTSService.swift is missing")
    source = SOURCE_PATH.read_text()

    scope = declaration_body(source, "private struct MemoirTTSCacheScope")
    require_all(
        scope,
        (
            "let subjectId: String",
            "let vaultId: String",
            "let generation: UInt64",
            "let generationId: UUID",
            "accountLease.subjectId",
            "accountLease.vaultId",
            "accountLease.generation",
            "accountLease.generationId",
            "scopeDigest",
        ),
        "generation cache scope",
    )
    require("sessionId" not in scope, "session credential must not affect cache scope")
    require("authorityEpoch" not in scope, "authority refresh must not affect cache scope")

    envelope = declaration_body(source, "private struct MemoirTTSCacheEnvelope")
    require_all(
        envelope,
        ("let schemaVersion: Int", "let scope: MemoirTTSCacheScope", "let entry: MemoirTTSCacheEntry"),
        "cache envelope",
    )

    identity = declaration_body(source, "struct MemoirTTSCacheIdentity")
    require_all(
        identity,
        (
            "let memoirId: String",
            "let personaOwnerId: String",
            "let roleKey: String",
            "let voiceProfileId: String",
            "let textHash: String",
            "let audioFormat: String",
            "let providerMode: String",
            "var cacheDigest: String",
            "memoir-tts-cache-identity-v1",
        ),
        "owner keyed cache identity",
    )
    entry = declaration_body(source, "struct MemoirTTSCacheEntry")
    require_all(
        entry,
        ("let cacheIdentity: MemoirTTSCacheIdentity",),
        "cache entry identity",
    )

    service = declaration_body(source, "final class MemoirTTSService")
    require_all(
        service,
        (
            'appendingPathComponent("memoir_audio_scoped_v2"',
            'appendingPathComponent("memoir_tts_cache_scoped_v2"',
            'appendingPathComponent("memoir_tts_quarantine"',
            "captureScopedAccess(forSubjectId: nil, at: .request)",
            "captureScopedAccess(forSubjectId: memoir.authorId, at: .request)",
            "retireLegacyGlobalCacheIfNeeded()",
            "legacyGlobalCacheHasNoAccountGenerationEvidence",
        ),
        "scoped cache service",
    )
    require('?? "default"' not in service, "cache must not fall back to a default principal")
    require('?? "anonymous"' not in service, "cache must not fall back to an anonymous principal")

    public_lookup = function_body(
        service,
        r"func\s+getCachedSynthesis\s*\(for\s+memoir:\s+MemoirModel\)",
        "memoir cache lookup",
    )
    require_all(
        public_lookup,
        (
            "captureScopedAccess(forSubjectId: memoir.authorId, at: .request)",
            "resolvedVoiceProfileId(for: memoir, accountLease: access.accountLease)",
            "MemoirTTSCacheLookup(",
            "personaOwnerId: memoir.authorId",
            'roleKey: "memoir"',
            "textHash: Self.textHash(for: memoir.prose)",
            "getCachedSynthesis(matching: lookup, access: access)",
        ),
        "owner/profile/text cache lookup",
    )
    require(
        "func getAudioURL(for memoirId:" not in service,
        "raw memoir-id audio lookup must not bypass identity checks",
    )
    require(
        "func getCachedSynthesis(for memoirId:" not in service,
        "raw memoir-id cache lookup must not bypass identity checks",
    )

    load = function_body(
        service,
        r"private\s+func\s+loadCacheEntry\s*\(\s*from\s+fileURL",
        "scoped cache load",
    )
    require_all(
        load,
        (
            "decode(MemoirTTSCacheEnvelope.self",
            "envelope.scope == scope",
            "isIdentityConsistent(envelope.entry)",
            "isExpectedMetadataURL(fileURL, for: envelope.entry, scope: scope)",
            "isExpectedAudioURL",
        ),
        "fail-closed scoped cache load",
    )
    require(
        "decode(MemoirTTSCacheEntry.self" not in load,
        "legacy unscoped metadata must not be auto-claimed",
    )

    quarantine = function_body(
        service,
        r"private\s+func\s+quarantineLegacyFiles\s*\(",
        "legacy cache quarantine",
    )
    require_all(
        quarantine,
        (
            "legacyQuarantineDirectory",
            "FileManager.default.moveItem(at: sourceURL, to: quarantineURL)",
            "MemoirTTSLegacyQuarantineReceipt",
        ),
        "legacy cache quarantine",
    )

    commit = function_body(
        service,
        r"private\s+func\s+commitSynthesisArtifacts\s*\(",
        "synthesis artifact commit",
    )
    require_all(
        commit,
        (
            "operation.accountLease",
            "at: .commit",
            "MemoirTTSCacheScope(accountLease: accountLease)",
            "cacheFileURL(for: cacheEntry.cacheIdentity, scope: cacheScope)",
            "stagingFileURL",
            "saveCacheEnvelope",
            "storageLock.lock()",
            "restore(previousAudio, at: audioURL)",
            "restore(previousMetadata, at: metadataURL)",
            "throw TTSError.accountSessionChanged",
        ),
        "stale synthesis rollback",
    )
    require(
        commit.count("accountLeaseRuntime.validate(accountLease, at: .commit)") >= 3,
        "synthesis commit must validate before staging, before commit, and after writes",
    )

    audio_url = function_body(
        service,
        r"private\s+func\s+isExpectedAudioURL\s*\(",
        "cache audio path validation",
    )
    require_all(
        audio_url,
        (
            "isIdentityConsistent(entry)",
            "return audioURL.standardizedFileURL == audioFileURL(",
            "for: entry.cacheIdentity",
        ),
        "cache audio path validation",
    )

    synthesis = function_body(
        service,
        r"private\s+func\s+performSynthesis\s*\(",
        "synthesis response identity binding",
    )
    require_all(
        synthesis,
        (
            "returnedVoiceProfileId == request.voiceProfileId",
            "MemoirTTSCacheIdentity(",
            "personaOwnerId: scope.personaOwnerId",
            "roleKey: scope.roleKey",
            "providerMode: synthesis.providerMode",
            "audioFileURL(for: cacheIdentity, scope: cacheScope)",
            "cacheIdentity: cacheIdentity",
        ),
        "synthesis response identity binding",
    )

    timeline_lookup = function_body(
        service,
        r"func\s+getCachedLipSyncTimeline\s*\(forText",
        "timeline profile ambiguity rejection",
    )
    require_all(
        timeline_lookup,
        (
            "Set(matchingEntries.map(\\.cacheIdentity.voiceProfileId))",
            "voiceProfileIds.count == 1",
        ),
        "timeline profile ambiguity rejection",
    )


def main() -> None:
    run_static_check()
    run_scope_model()
    print("Memoir TTS cache owner-scope static/model smoke passed")


if __name__ == "__main__":
    main()
