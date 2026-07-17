#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
REPOSITORY = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compact(value: str) -> str:
    return "".join(value.split())


def body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {signature}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function body: {signature}")


def main() -> None:
    require(REPOSITORY.is_file(), "FamilyRepository production file is missing")
    source = REPOSITORY.read_text()

    for snippet in (
        "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
        "private func captureAccountLease(for ownerUserId: String) -> AccountLease?",
        "private func isCurrentAccountLease(",
        "accountLeaseRuntime.capture(forSubjectId: ownerUserId)",
        "accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed",
    ):
        require(snippet in source, f"Family lease adapter missing: {snippet}")

    initializer = body(source, "private init()")
    for snippet in (
        "let startupOwnerUserId = activeOwnerUserId",
        "let startupAccountLease = captureAccountLease(for: startupOwnerUserId)",
        "at: .timer",
        "syncFromKnowledgeBase(accountLease: startupAccountLease)",
        "bootstrapCurrentUserFromBackend(accountLease: startupAccountLease)",
    ):
        require(snippet in initializer, f"startup timer lease checkpoint missing: {snippet}")
    timer = initializer[initializer.find("DispatchQueue.main.asyncAfter") :]
    require(
        "UserManager.shared.currentUser" not in timer,
        "startup timer must not re-read the current user after capturing its lease",
    )

    refresh = body(
        source,
        "private func refreshFromBackend(\n        userId: String,\n        accountLease: AccountLease,",
    )
    for snippet in (
        "isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .request)",
        "FamilyAuthorizationRefreshResponsePolicy.accepts(",
        "capturedRefreshGeneration: capturedRefreshGeneration",
        "currentRefreshGeneration: self.authorizationFreshness.generation",
        "self.isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .commit)",
        "accountLease: accountLease",
    ):
        require(
            compact(snippet) in compact(refresh),
            f"refresh lease/authorization guard missing: {snippet}",
        )
    require(
        "UserManager.shared.currentUser" not in refresh,
        "refresh callback must not re-read the current user",
    )
    require(
        "captureAccountLease" not in refresh,
        "refresh operation must keep the lease captured by its caller",
    )

    invite = body(source, "func inviteByPhone(")
    for snippet in (
        "let accountLease = captureAccountLease(for: requestedOwner)",
        "isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .request)",
        "self.isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .commit)",
        "self.userGeneration == capturedGeneration",
        "self.activeOwnerUserId == requestedOwner",
        "accountLease: accountLease",
    ):
        require(
            compact(snippet) in compact(invite),
            f"invite lease/owner guard missing: {snippet}",
        )
    require(
        "UserManager.shared.currentUser" not in invite,
        "invite callback must not re-read the current user",
    )
    require(
        invite.count("captureAccountLease(for: requestedOwner)") == 1,
        "invite operation must capture exactly one lease",
    )

    replace = body(
        source,
        "private func replaceRemoteMembers(\n        _ remoteMembers: [FamilyMember],\n        ownerUserId: String,\n        accountLease: AccountLease",
    )
    require(
        compact("isCurrentAccountLease(accountLease, ownerUserId: ownerUserId, at: .commit)")
        in compact(replace),
        "remote member commit must validate the captured lease",
    )

    sync = body(source, "private func syncFromKnowledgeBase(accountLease: AccountLease)")
    require(
        compact("isCurrentAccountLease(accountLease, ownerUserId: ownerUserId, at: .commit)")
        in compact(sync),
        "knowledge candidate commit must validate the captured lease",
    )

    upsert = body(
        source,
        "private func upsert(\n        _ member: FamilyMember,\n        expectedGeneration: UUID,\n        accountLease: AccountLease",
    )
    for snippet in (
        "isCurrentAccountLease(accountLease, ownerUserId: member.relationshipOwnerUserId, at: .commit)",
        "userGeneration == expectedGeneration",
    ):
        require(compact(snippet) in compact(upsert), f"local upsert guard missing: {snippet}")

    for signature in (
        "private func notifyMembersChanged(accountLease: AccountLease)",
        "private func notifyCandidatesChanged(accountLease: AccountLease)",
    ):
        notification = body(source, signature)
        for snippet in (
            "isCurrentAccountLease(",
            "accountLease,",
            "at: .ui",
            "NotificationCenter.default.post",
        ):
            require(snippet in notification, f"notification lease guard missing: {signature}: {snippet}")
        require(
            notification.find("at: .ui") < notification.find("NotificationCenter.default.post"),
            f"notification must validate the lease before posting: {signature}",
        )
        require(
            "captureAccountLease" not in notification,
            f"notification must not replace the captured lease: {signature}",
        )

    for signature in (
        "private func persistModeOverrides(accountLease: AccountLease)",
        "private func persistVoiceProfileOverrides(accountLease: AccountLease)",
    ):
        persistence = body(source, signature)
        require(
            compact(
                "isCurrentAccountLease(accountLease, ownerUserId: accountLease.subjectId, at: .commit)"
            )
            in compact(persistence),
            f"local override commit must validate the captured lease: {signature}",
        )

    delivery = body(source, "private func deliver<T>(")
    require("at: .ui" in delivery, "completion apply must validate the captured lease")

    print("Family AccountLease static check passed")


if __name__ == "__main__":
    main()
