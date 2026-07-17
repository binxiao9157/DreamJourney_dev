import Foundation

@main
enum TokenFamilyClientModelSmoke {
    static func main() throws {
        try verifyLegacyKeychainDecode()
        try verifyStrictV2NetworkDecode()
        verifyMonotonicRotation()
        try verifyRefreshAfterLogoutIsDiscarded()
        try verifyRefreshAfterLoginBIsDiscarded()
        try verifyStaleFailureDoesNotClearNewSession()
        print("Token-family client model smoke passed")
    }

    private static func verifyLegacyKeychainDecode() throws {
        let legacyData = Data(
            """
            {
              "sessionId": "session_legacy",
              "userId": "user_a",
              "tokenType": "Bearer",
              "accessToken": "dja_legacy",
              "refreshToken": "djr_legacy",
              "accessExpiresInSeconds": 900,
              "refreshExpiresInSeconds": 3600,
              "accessExpiresAt": "2030-07-17T06:00:00Z",
              "refreshExpiresAt": "2030-07-18T06:00:00Z"
            }
            """.utf8
        )
        let decoded = try JSONDecoder().decode(BackendAuthSessionContract.self, from: legacyData)
        require(decoded.contractVersion == 1, "old Keychain data must decode as contract v1")
        require(decoded.isLegacy, "old Keychain data must be explicitly legacy")
        require(decoded.tokenFamilyId == nil, "legacy Keychain data must not fabricate a token family")
        require(decoded.sessionVersion == nil, "legacy Keychain data must not fabricate a session version")
        require(!decoded.isPrivateAccessEligible, "legacy Keychain data must never authorize private access")
        requireThrows("legacy Keychain data must remain read-only and cannot be saved again") {
            try BackendAuthSessionStore.shared.save(decoded)
        }

        let encoded = try JSONEncoder().encode(decoded)
        let object = try requireObject(encoded)
        require(object["tokenFamilyId"] == nil, "legacy encoding must omit tokenFamilyId")
        require(object["sessionVersion"] == nil, "legacy encoding must omit sessionVersion")

        var legacyNetwork = authJSON(
            sessionId: "session_v1",
            userId: "user_a",
            contractVersion: 1
        )
        legacyNetwork["tokenFamilyId"] = "family_must_be_ignored"
        legacyNetwork["sessionVersion"] = 42
        let networkDecoded = requireSession(BackendAuthSessionContract(json: legacyNetwork))
        require(networkDecoded.isLegacy, "network v1 must remain explicitly legacy")
        require(networkDecoded.tokenFamilyId == nil, "network v1 must not claim family lineage")
        require(networkDecoded.sessionVersion == nil, "network v1 must not claim a lineage version")
    }

    private static func verifyStrictV2NetworkDecode() throws {
        let valid = requireSession(makeV2(sessionId: "session_v2", userId: "user_a", familyId: "family_a", version: 1))
        require(valid.contractVersion == 2, "v2 response must preserve contractVersion")
        require(valid.tokenFamilyId == "family_a", "v2 response must preserve tokenFamilyId")
        require(valid.sessionVersion == 1, "v2 response must preserve sessionVersion")
        require(!valid.isLegacy, "v2 response must not be marked legacy")

        let validRoundTrip = try JSONDecoder().decode(
            BackendAuthSessionContract.self,
            from: JSONEncoder().encode(valid)
        )
        require(validRoundTrip == valid, "valid v2 Keychain data must round-trip with lineage")

        var missingFamily = v2JSON(sessionId: "missing_family", userId: "user_a", familyId: "family_a", version: 1)
        missingFamily.removeValue(forKey: "tokenFamilyId")
        require(BackendAuthSessionContract(json: missingFamily) == nil, "v2 without tokenFamilyId must fail closed")

        var blankFamily = v2JSON(sessionId: "blank_family", userId: "user_a", familyId: "family_a", version: 1)
        blankFamily["tokenFamilyId"] = "   "
        require(BackendAuthSessionContract(json: blankFamily) == nil, "v2 with blank tokenFamilyId must fail closed")

        var missingVersion = v2JSON(sessionId: "missing_version", userId: "user_a", familyId: "family_a", version: 1)
        missingVersion.removeValue(forKey: "sessionVersion")
        require(BackendAuthSessionContract(json: missingVersion) == nil, "v2 without sessionVersion must fail closed")

        let zeroVersion = v2JSON(sessionId: "zero_version", userId: "user_a", familyId: "family_a", version: 0)
        require(BackendAuthSessionContract(json: zeroVersion) == nil, "v2 with non-positive sessionVersion must fail closed")

        var stringVersion = v2JSON(sessionId: "string_version", userId: "user_a", familyId: "family_a", version: 1)
        stringVersion["sessionVersion"] = "1"
        require(BackendAuthSessionContract(json: stringVersion) == nil, "v2 sessionVersion must be an integer field")

        var booleanVersion = v2JSON(sessionId: "boolean_version", userId: "user_a", familyId: "family_a", version: 1)
        booleanVersion["sessionVersion"] = true
        require(BackendAuthSessionContract(json: booleanVersion) == nil, "v2 sessionVersion must reject booleans")

        var stringContract = v2JSON(sessionId: "string_contract", userId: "user_a", familyId: "family_a", version: 1)
        stringContract["contractVersion"] = "2"
        require(BackendAuthSessionContract(json: stringContract) == nil, "auth contractVersion must be an integer field")

        var unknownVersion = v2JSON(sessionId: "unknown_contract", userId: "user_a", familyId: "family_a", version: 1)
        unknownVersion["contractVersion"] = 3
        require(BackendAuthSessionContract(json: unknownVersion) == nil, "unknown auth contract versions must fail closed")

        let missingFamilyData = try JSONSerialization.data(withJSONObject: missingFamily, options: [.sortedKeys])
        requireThrows("persisted v2 without tokenFamilyId must not decode") {
            _ = try JSONDecoder().decode(BackendAuthSessionContract.self, from: missingFamilyData)
        }
    }

    private static func verifyMonotonicRotation() {
        let captured = requireSession(makeV2(sessionId: "session_a1", userId: "user_a", familyId: "family_a", version: 1))
        let successor = requireSession(makeV2(sessionId: "session_a2", userId: "user_a", familyId: "family_a", version: 2))
        require(successor.isValidRefreshSuccessor(of: captured), "same-family increasing v2 rotation must be accepted")

        let sameSession = requireSession(makeV2(sessionId: "session_a1", userId: "user_a", familyId: "family_a", version: 2))
        require(!sameSession.isValidRefreshSuccessor(of: captured), "refresh must rotate sessionId")

        let sameVersion = requireSession(makeV2(sessionId: "session_a2", userId: "user_a", familyId: "family_a", version: 1))
        require(!sameVersion.isValidRefreshSuccessor(of: captured), "v2 sessionVersion must strictly increase")

        let lowerVersion = requireSession(makeV2(sessionId: "session_a2", userId: "user_a", familyId: "family_a", version: 0 + 1))
        require(!lowerVersion.isValidRefreshSuccessor(of: successor), "older v2 callbacks must be rejected")

        let otherFamily = requireSession(makeV2(sessionId: "session_a2", userId: "user_a", familyId: "family_b", version: 2))
        require(!otherFamily.isValidRefreshSuccessor(of: captured), "refresh must not switch token families")

        let otherUser = requireSession(makeV2(sessionId: "session_b2", userId: "user_b", familyId: "family_a", version: 2))
        require(!otherUser.isValidRefreshSuccessor(of: captured), "refresh must not switch users")

        let legacyA = requireSession(BackendAuthSessionContract(json: authJSON(sessionId: "legacy_a", userId: "user_a", contractVersion: 1)))
        let legacyB = requireSession(BackendAuthSessionContract(json: authJSON(sessionId: "legacy_b", userId: "user_a", contractVersion: 1)))
        require(!legacyB.isValidRefreshSuccessor(of: legacyA), "legacy v1 rotation must require reauthentication")
        require(!successor.isValidRefreshSuccessor(of: legacyA), "legacy-to-v2 refresh must not infer lineage")
        require(!legacyB.isValidRefreshSuccessor(of: captured), "v2 refresh must not downgrade to legacy")
    }

    private static func verifyRefreshAfterLogoutIsDiscarded() throws {
        let store = BackendAuthSessionStore.shared
        store.clear()
        let capturedA = requireSession(makeV2(sessionId: "logout_a1", userId: "user_a", familyId: "family_a", version: 1))
        let responseA = requireSession(makeV2(sessionId: "logout_a2", userId: "user_a", familyId: "family_a", version: 2))
        try store.save(capturedA)

        require(store.clear(ifCurrentMatches: capturedA), "logout must clear its captured session")
        let replacedAfterLogout = try store.replace(responseA, ifCurrentMatches: capturedA)
        require(!replacedAfterLogout, "refresh-A callback after logout must be discarded")
        require(store.currentSession == nil, "stale refresh must not recreate a logged-out session")
    }

    private static func verifyRefreshAfterLoginBIsDiscarded() throws {
        let store = BackendAuthSessionStore.shared
        store.clear()
        let capturedA = requireSession(makeV2(sessionId: "login_a1", userId: "user_a", familyId: "family_a", version: 1))
        let responseA = requireSession(makeV2(sessionId: "login_a2", userId: "user_a", familyId: "family_a", version: 2))
        let loginB = requireSession(makeV2(sessionId: "login_b1", userId: "user_b", familyId: "family_b", version: 1))
        try store.save(capturedA)
        try store.save(loginB)

        let replacedAfterLoginB = try store.replace(responseA, ifCurrentMatches: capturedA)
        require(!replacedAfterLoginB, "refresh-A callback after login-B must be discarded")
        require(store.currentSession == loginB, "stale refresh-A must not overwrite login-B")
    }

    private static func verifyStaleFailureDoesNotClearNewSession() throws {
        let store = BackendAuthSessionStore.shared
        store.clear()
        let capturedA = requireSession(makeV2(sessionId: "failure_a1", userId: "user_a", familyId: "family_a", version: 1))
        let currentA = requireSession(makeV2(sessionId: "failure_a2", userId: "user_a", familyId: "family_a", version: 2))
        try store.save(capturedA)
        try store.save(currentA)

        require(!store.clear(ifCurrentMatches: capturedA), "stale refresh failure must not clear a newer session")
        require(store.currentSession == currentA, "new session must survive stale refresh failure")
        store.clear()
    }

    private static func makeV2(
        sessionId: String,
        userId: String,
        familyId: String,
        version: Int
    ) -> BackendAuthSessionContract? {
        BackendAuthSessionContract(json: v2JSON(
            sessionId: sessionId,
            userId: userId,
            familyId: familyId,
            version: version
        ))
    }

    private static func v2JSON(
        sessionId: String,
        userId: String,
        familyId: String,
        version: Int
    ) -> [String: Any] {
        var json = authJSON(sessionId: sessionId, userId: userId, contractVersion: 2)
        json["tokenFamilyId"] = familyId
        json["sessionVersion"] = version
        return json
    }

    private static func authJSON(
        sessionId: String,
        userId: String,
        contractVersion: Int
    ) -> [String: Any] {
        [
            "sessionId": sessionId,
            "userId": userId,
            "tokenType": "Bearer",
            "accessToken": "dja_\(sessionId)",
            "refreshToken": "djr_\(sessionId)",
            "accessExpiresInSeconds": 900,
            "refreshExpiresInSeconds": 3600,
            "accessExpiresAt": "2030-07-17T06:00:00Z",
            "refreshExpiresAt": "2030-07-18T06:00:00Z",
            "contractVersion": contractVersion,
        ]
    }

    private static func requireSession(_ session: BackendAuthSessionContract?) -> BackendAuthSessionContract {
        guard let session else {
            fail("expected a valid auth session")
        }
        return session
    }

    private static func requireObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fail("expected an encoded JSON object")
        }
        return object
    }

    private static func requireThrows(_ message: String, operation: () throws -> Void) {
        do {
            try operation()
            fail(message)
        } catch {
            return
        }
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        guard try condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Token-family client model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}
