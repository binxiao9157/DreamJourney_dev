#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[3]
SOURCE_ROOT = ROOT / "DreamJourney/Sources"

CONVERSATION_MANAGER = SOURCE_ROOT / "Services/ConversationMemoryManager.swift"
CONVERSATION_STORAGE = SOURCE_ROOT / "Services/ConversationLocalStorage.swift"
MEMOIR_MODEL = SOURCE_ROOT / "Memoir/MemoirModel.swift"
MEMOIR_REPOSITORY = SOURCE_ROOT / "Memoir/MemoirRepository.swift"
MEMORY_MODEL = SOURCE_ROOT / "Services/MemoryModel.swift"
MEMORY_REPOSITORY = SOURCE_ROOT / "Services/MemoryRepository.swift"
MAP_FOOTPRINT = SOURCE_ROOT / "Modules/Map/MapFootprintViewController.swift"

TARGET_FILES = (
    CONVERSATION_MANAGER,
    CONVERSATION_STORAGE,
    MEMOIR_MODEL,
    MEMOIR_REPOSITORY,
    MEMORY_MODEL,
    MEMORY_REPOSITORY,
    MAP_FOOTPRINT,
)


@dataclass(frozen=True)
class Violation:
    code: str
    path: str
    message: str
    lines: tuple[int, ...] = ()
    excerpts: tuple[str, ...] = ()


@dataclass(frozen=True)
class ForbiddenRule:
    code: str
    path: Path
    pattern: str
    message: str


@dataclass(frozen=True)
class LiteralAllowance:
    path: str
    function_signature: str
    exact_line: str
    kind: str
    rationale: str
    anchor_line: str | None = None
    required_file_snippets: tuple[str, ...] = ()


# A fallback-owner literal in release sources is denied by default. These entries
# are deliberately exact: path, function, source line, compiler lane, and fixture
# anchor must all match. Adding a directory or filename-wide exception is not
# permitted.
USER_001_LITERAL_ALLOWLIST = (
    LiteralAllowance(
        path="DreamJourney/Sources/Services/ConversationLocalStorage.swift",
        function_signature="private static func isReservedFallbackOwner(",
        exact_line='["user_001", "unknown", "default"].contains(value.lowercased())',
        kind="deny_guard",
        rationale="the scoped store rejects reserved fallback owners",
        required_file_snippets=(
            "!Self.isReservedFallbackOwner(subjectId)",
            "!Self.isReservedFallbackOwner(ownerId)",
        ),
    ),
    LiteralAllowance(
        path="DreamJourney/Sources/Memoir/MemoirRepository.swift",
        function_signature="static func isLegacySeed(",
        exact_line='normalized(memoir.authorId) == "user_001"',
        kind="deny_guard",
        rationale="legacy memoir fixtures are classified for quarantine, never assigned",
        required_file_snippets=(
            "reason: .seedFixture",
            "quarantineLegacyPayload(",
        ),
    ),
    LiteralAllowance(
        path="DreamJourney/Sources/Services/AccountPrivateMediaStore.swift",
        function_signature="private static func validScopeIdentifier(",
        exact_line='"user_001",',
        kind="deny_guard",
        rationale="the account-private media store rejects reserved fallback scopes",
        required_file_snippets=(
            "try validateLease(accountLease, at: .request)",
            "account-private-media-scope-v1|",
        ),
    ),
    LiteralAllowance(
        path="DreamJourney/Sources/AppDelegate.swift",
        function_signature="func runTimeLetterDispatchReminderSmoke()",
        exact_line='let userId = UserManager.shared.currentUser?.id ?? "user_001"',
        kind="qa_fixture",
        rationale="time-letter simulator smoke fixture",
    ),
    LiteralAllowance(
        path="DreamJourney/Sources/Modules/Echo/EchoViewController.swift",
        function_signature="func runUIQAEchoTraceEvidencePackagePanelExportSmoke(",
        exact_line='relationshipOwnerUserId: UserManager.shared.currentUser?.id ?? "user_001",',
        kind="qa_fixture",
        rationale="Echo evidence-panel simulator fixture",
        required_file_snippets=("relationshipAuthoritySource: .qaFixture",),
    ),
    LiteralAllowance(
        path="DreamJourney/Sources/Modules/Echo/EchoViewController.swift",
        function_signature="func runUIQAEchoTraceEvidencePackagePanelExportSmoke(",
        exact_line='viewerUserId: UserManager.shared.currentUser?.id ?? "user_001",',
        kind="qa_fixture",
        rationale="Echo evidence-panel simulator fixture",
        required_file_snippets=("relationshipAuthoritySource: .qaFixture",),
    ),
    *(
        LiteralAllowance(
            path="DreamJourney/Sources/Services/MemoryRepository.swift",
            function_signature="private func seedMockData()",
            exact_line='authorId: "user_001"',
            kind="qa_fixture",
            rationale=f"legacy map fixture {fixture_id}; fixture data is do-not-migrate",
            anchor_line=f'id: "{fixture_id}"',
        )
        for fixture_id in (
            "mem_001",
            "mem_002",
            "mem_003",
            "mem_004",
            "mem_005",
            "mem_006",
        )
    ),
)


FORBIDDEN_RULES = (
    ForbiddenRule(
        code="CONVERSATION_GLOBAL_IO",
        path=CONVERSATION_MANAGER,
        pattern=r"\bFileManager\.default\b|\bdata\.write\(",
        message="ConversationMemoryManager must delegate persistence to the owner-scoped store",
    ),
    ForbiddenRule(
        code="CONVERSATION_LEGACY_WRITER",
        path=CONVERSATION_MANAGER,
        pattern=r"conversation_memory(?:_|\.json)|\blegacyFilePath\b|\bfallbackPath\b|\bpathToLoad\b",
        message="legacy Conversation paths must not be mounted or written by the production manager",
    ),
    ForbiddenRule(
        code="CONVERSATION_AUTO_OWNER",
        path=CONVERSATION_MANAGER,
        pattern=r"ownerId\.isEmpty\s*\?\s*userId|\?\?\s*\"personal_user_001\"",
        message="Conversation writes must not infer an owner for an empty or reserved legacy scope",
    ),
    ForbiddenRule(
        code="MEMOIR_GLOBAL_IO",
        path=MEMOIR_REPOSITORY,
        pattern=(
            r"\bstorageDirectory\b|\bsaveToDisk\b|\bloadAllFromDisk\b|"
            r"private\s+func\s+fileURL\s*\(for"
        ),
        message="MemoirRepository must not retain the legacy unscoped disk writer API",
    ),
    ForbiddenRule(
        code="MEMOIR_GLOBAL_LOCATOR",
        path=MEMOIR_REPOSITORY,
        pattern=r"storageDirectory\.appendingPathComponent",
        message="legacy memoir/recordings locators must not feed an unscoped storageDirectory writer",
    ),
    ForbiddenRule(
        code="MEMORY_GLOBAL_DEFAULTS",
        path=MEMORY_REPOSITORY,
        pattern=(
            r"\bpersistKey\b|\bsavePersistedMemories\b|\bloadPersistedMemories\b"
        ),
        message="MemoryRepository must not mount or write the global UserDefaults store",
    ),
    ForbiddenRule(
        code="MAP_GLOBAL_DEFAULTS",
        path=MAP_FOOTPRINT,
        pattern=(
            r"UserDefaults\.standard|\breadMemoriesKey\b|\bbouncedMemoriesKey\b|"
            r"dj\.readMemoryIds|dj\.bouncedMemoryIds"
        ),
        message="Map read/bounce state must be delegated to an owner-scoped store",
    ),
    ForbiddenRule(
        code="MAP_LEGACY_AUTO_CLAIM",
        path=MAP_FOOTPRINT,
        pattern=r"getAllByOwner\(\s*\"user_001\"\s*\)",
        message="Map must never fall back to the legacy fixture owner when the active owner is empty",
    ),
    ForbiddenRule(
        code="MEMOIR_DEFAULT_OWNER",
        path=MEMOIR_MODEL,
        pattern=r"authorId\s*:\s*String\s*=",
        message="MemoirModel owner must be explicit; model initializers cannot supply a fallback owner",
    ),
    ForbiddenRule(
        code="MEMORY_DEFAULT_OWNER",
        path=MEMORY_MODEL,
        pattern=r"authorId\s*:\s*String\s*=",
        message="MemoryModel owner must be explicit; model initializers cannot supply a fallback owner",
    ),
)


USER_001_STRING = re.compile(r'"(?:\\.|[^"\\])*user_001(?:\\.|[^"\\])*"')


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def code_before_line_comment(line: str) -> str:
    in_string = False
    escaped = False
    cursor = 0
    while cursor < len(line):
        character = line[cursor]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
        else:
            if character == '"':
                in_string = True
            elif character == "/" and cursor + 1 < len(line) and line[cursor + 1] == "/":
                return line[:cursor]
        cursor += 1
    return line


def is_explicit_qa_condition(condition: str) -> bool:
    normalized = "".join(condition.split())
    return normalized in {
        "UI_QA_SIMULATOR&&targetEnvironment(simulator)",
        "(UI_QA_SIMULATOR||RELEASE_SCOPE_SIMULATOR)&&targetEnvironment(simulator)",
    }


def qa_only_line_map(lines: list[str]) -> list[bool]:
    stack: list[bool] = []
    result: list[bool] = []
    for line in lines:
        directive = line.strip()
        if directive.startswith("#if "):
            stack.append(is_explicit_qa_condition(directive[4:]))
        elif directive.startswith("#elseif ") and stack:
            stack[-1] = is_explicit_qa_condition(directive[8:])
        elif directive == "#else" and stack:
            stack[-1] = False
        elif directive.startswith("#endif") and stack:
            stack.pop()
        result.append(any(stack))
    return result


def function_line_span(source: str, signature: str) -> tuple[int, int] | None:
    start = source.find(signature)
    if start < 0:
        return None
    opening = source.find("{", start)
    if opening < 0:
        return None
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return (
                    source.count("\n", 0, start) + 1,
                    source.count("\n", 0, cursor) + 1,
                )
    return None


def is_allowlisted_literal(
    path: Path,
    line_number: int,
    line: str,
    lines: list[str],
    source: str,
    qa_lines: list[bool],
    consumed: set[int],
) -> tuple[bool, str | None]:
    relative_path = relative(path)
    for index, allowance in enumerate(USER_001_LITERAL_ALLOWLIST):
        if index in consumed or allowance.path != relative_path:
            continue
        if line.strip() != allowance.exact_line:
            continue
        span = function_line_span(source, allowance.function_signature)
        if span is None or not (span[0] <= line_number <= span[1]):
            continue
        if any(snippet not in source for snippet in allowance.required_file_snippets):
            continue
        if allowance.anchor_line is not None:
            context_start = max(0, line_number - 14)
            context = {candidate.strip() for candidate in lines[context_start:line_number]}
            if allowance.anchor_line not in context:
                continue
        if allowance.kind == "qa_fixture" and not qa_lines[line_number - 1]:
            continue
        consumed.add(index)
        return True, allowance.rationale
    return False, None


def scan_user_001_literals() -> tuple[list[Violation], list[str]]:
    violations: list[Violation] = []
    accepted: list[str] = []
    consumed_allowances: set[int] = set()
    for path in sorted(SOURCE_ROOT.rglob("*.swift")):
        source = path.read_text()
        lines = source.splitlines()
        qa_lines = qa_only_line_map(lines)
        for line_number, line in enumerate(lines, start=1):
            code = code_before_line_comment(line)
            if USER_001_STRING.search(code) is None:
                continue
            allowed, rationale = is_allowlisted_literal(
                path,
                line_number,
                line,
                lines,
                source,
                qa_lines,
                consumed_allowances,
            )
            if allowed:
                accepted.append(f"{relative(path)}:{line_number} ({rationale})")
                continue
            violations.append(
                Violation(
                    code="FIXED_FALLBACK_OWNER",
                    path=relative(path),
                    lines=(line_number,),
                    excerpts=(line.strip(),),
                    message=(
                        "user_001 is forbidden in release sources unless this exact occurrence is an "
                        "allowlisted simulator QA fixture or reserved-owner deny guard"
                    ),
                )
            )
    return violations, accepted


def scan_forbidden_rule(rule: ForbiddenRule) -> Violation | None:
    if not rule.path.is_file():
        return Violation(
            code="MISSING_SURFACE",
            path=relative(rule.path),
            message="required production writer surface is missing",
        )
    pattern = re.compile(rule.pattern)
    matched_lines: list[int] = []
    excerpts: list[str] = []
    for line_number, line in enumerate(rule.path.read_text().splitlines(), start=1):
        code = code_before_line_comment(line)
        if pattern.search(code) is None:
            continue
        matched_lines.append(line_number)
        if len(excerpts) < 4:
            excerpts.append(line.strip())
    if not matched_lines:
        return None
    return Violation(
        code=rule.code,
        path=relative(rule.path),
        lines=tuple(matched_lines),
        excerpts=tuple(excerpts),
        message=rule.message,
    )


def scan_unguarded_fixture_seed(path: Path) -> Violation | None:
    source = path.read_text()
    lines = source.splitlines()
    qa_lines = qa_only_line_map(lines)
    matches = [
        line_number
        for line_number, line in enumerate(lines, start=1)
        if re.fullmatch(r"\s*seedMockData\(\)\s*", code_before_line_comment(line))
        and not qa_lines[line_number - 1]
    ]
    if not matches:
        return None
    return Violation(
        code="PRODUCTION_FIXTURE_AUTO_SEED",
        path=relative(path),
        lines=tuple(matches),
        excerpts=tuple(lines[line_number - 1].strip() for line_number in matches),
        message="fixture seeding must be compile-gated to the exact simulator QA lane",
    )


def require_snippets(
    path: Path,
    source: str,
    code: str,
    requirements: tuple[tuple[str, tuple[str, ...]], ...],
) -> list[Violation]:
    violations: list[Violation] = []
    for label, snippets in requirements:
        missing = tuple(snippet for snippet in snippets if snippet not in source)
        if not missing:
            continue
        violations.append(
            Violation(
                code=code,
                path=relative(path),
                message=f"{label} is incomplete; missing: {', '.join(missing)}",
            )
        )
    return violations


def storage_corpus(prefixes: tuple[str, ...], base_paths: tuple[Path, ...]) -> str:
    candidates = set(base_paths)
    for path in SOURCE_ROOT.rglob("*.swift"):
        if "Archive" in path.parts:
            continue
        if any(path.name.startswith(prefix) and "Storage" in path.name for prefix in prefixes):
            candidates.add(path)
        if "PrivateStore" in path.name:
            candidates.add(path)
    return "\n".join(path.read_text() for path in sorted(candidates) if path.is_file())


def contract_violations() -> list[Violation]:
    violations: list[Violation] = []
    if CONVERSATION_STORAGE.is_file():
        conversation_storage = CONVERSATION_STORAGE.read_text()
        violations.extend(
            require_snippets(
                CONVERSATION_STORAGE,
                conversation_storage,
                "CONVERSATION_STORAGE_CONTRACT",
                (
                    (
                        "owner-scoped Conversation envelope",
                        (
                            "struct ConversationStorageScope",
                            "let subjectId: String",
                            "let vaultId: String",
                            "let ownerId: String",
                            "let generation: UInt64",
                            "let generationId: UUID",
                            "struct ConversationStoreEnvelope",
                            "let contentHash: String",
                        ),
                    ),
                    (
                        "Conversation legacy disposition and receipt",
                        (
                            "struct ConversationLegacyMigrationReceipt",
                            "case migrated",
                            "case quarantined",
                            "case discarded",
                            "sourceContentHash",
                        ),
                    ),
                    (
                        "Conversation ambiguous legacy quarantine",
                        (
                            "observeGlobalLegacyIfNeeded",
                            "reason: .ambiguousOwner",
                            "migrateScopedLegacyIfPermitted",
                            "scope.ownerId == scope.subjectId",
                        ),
                    ),
                ),
            )
        )
    else:
        violations.append(
            Violation(
                code="MISSING_CONVERSATION_STORAGE",
                path=relative(CONVERSATION_STORAGE),
                message="owner-scoped Conversation storage and legacy quarantine contract is missing",
            )
        )

    if CONVERSATION_MANAGER.is_file():
        manager = CONVERSATION_MANAGER.read_text()
        violations.extend(
            require_snippets(
                CONVERSATION_MANAGER,
                manager,
                "CONVERSATION_WRITER_CONTRACT",
                (
                    (
                        "Conversation writer AccountLease integration",
                        (
                            "AccountLease",
                            "ConversationStorageScope",
                            "ConversationLocalStorage",
                            "at: .commit",
                        ),
                    ),
                ),
            )
        )

    for repository, surface, prefixes in (
        (MEMOIR_REPOSITORY, "Memoir", ("Memoir",)),
        (MEMORY_REPOSITORY, "Memory/Map", ("Memory", "Map")),
    ):
        if not repository.is_file():
            continue
        repository_source = repository.read_text()
        violations.extend(
            require_snippets(
                repository,
                repository_source,
                f"{surface.upper().replace('/', '_')}_WRITER_CONTRACT",
                (
                    (
                        f"{surface} writer AccountLease commit fence",
                        ("AccountLease", "at: .commit"),
                    ),
                ),
            )
        )
        corpus = storage_corpus(prefixes, (repository,))
        migration_requirements = [
            ("migration receipt", ("MigrationReceipt",)),
            ("quarantine path", ("quarantin",)),
            ("content hash", ("contentHash",)),
            ("owner scope", ("subjectId", "vaultId", "generation")),
            ("surface identifier", ("surfaceId",)),
        ]
        migration_requirements.append(
            (
                "receipt dispositions",
                ("migrated", "quarantined") if surface == "Memoir" else ("quarantined",),
            )
        )
        missing_groups = [
            label
            for label, required_tokens in migration_requirements
            if not all(token in corpus for token in required_tokens)
        ]
        if missing_groups:
            violations.append(
                Violation(
                    code=f"{surface.upper().replace('/', '_')}_MIGRATION_CONTRACT",
                    path=relative(repository),
                    message=(
                        f"{surface} storage corpus is missing required retirement semantics: "
                        + ", ".join(missing_groups)
                    ),
                )
            )
    return violations


def format_lines(lines: tuple[int, ...]) -> str:
    if not lines:
        return ""
    if len(lines) <= 8:
        return ":" + ",".join(str(line) for line in lines)
    shown = ",".join(str(line) for line in lines[:8])
    return f":{shown},...(+{len(lines) - 8})"


def main() -> int:
    missing = [path for path in TARGET_FILES if not path.is_file()]
    if missing:
        print("Global private store retirement static check FAILED", file=sys.stderr)
        for path in missing:
            print(f"- [MISSING_SURFACE] {relative(path)}: required source file is missing", file=sys.stderr)
        return 1

    violations, accepted_literals = scan_user_001_literals()
    for rule in FORBIDDEN_RULES:
        violation = scan_forbidden_rule(rule)
        if violation is not None:
            violations.append(violation)
    for path in (MEMOIR_REPOSITORY, MEMORY_REPOSITORY):
        violation = scan_unguarded_fixture_seed(path)
        if violation is not None:
            violations.append(violation)
    violations.extend(contract_violations())

    if violations:
        print(
            f"Global private store retirement static check FAILED ({len(violations)} violation groups)",
            file=sys.stderr,
        )
        print(
            f"Exact literal allowlist accepted {len(accepted_literals)} occurrence(s); "
            "all other release-source occurrences are denied.",
            file=sys.stderr,
        )
        for violation in violations:
            location = f"{violation.path}{format_lines(violation.lines)}"
            print(f"- [{violation.code}] {location}: {violation.message}", file=sys.stderr)
            for excerpt in violation.excerpts:
                print(f"    {excerpt}", file=sys.stderr)
        return 1

    print(
        "Global private store retirement static check passed "
        f"({len(accepted_literals)} exact user_001 literal allowance(s))"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
