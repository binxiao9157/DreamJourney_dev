import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let store = read("DreamJourney/Sources/Services/BackendAuthSessionStore.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

for field in [
    "accessToken",
    "refreshToken",
    "accessExpiresAt",
    "refreshExpiresAt",
    "sessionId",
    "userId",
] {
    require(store.contains("let \(field):"), "Auth session contract must retain \(field)")
}
require(store.contains("import KeychainAccess"), "Auth tokens must use KeychainAccess")
require(store.contains("afterFirstUnlockThisDeviceOnly"), "Auth tokens must not migrate to another device")
require(store.contains("func save(_ session:"), "Auth store must save the rotated session atomically")
require(store.contains("func clear(ifCurrentMatches captured:"), "Logout must not clear a newer login session")

require(client.contains("case publicRequest"), "Public routes must use an explicit auth policy")
require(client.contains("case userRequired"), "Business routes must require an explicit user session")
require(client.contains("case refreshExchange"), "Refresh rotation must use an isolated auth policy")
require(!client.contains("case automatic"), "Implicit automatic auth policy must not remain")
require(!client.contains("case anonymous"), "Anonymous policy must be replaced by explicit public requests")
require(!client.contains("case backendOnly"), "The retired shared backend token policy must not remain")
require(!client.contains("X-DreamJourney-Api-Token"), "The app must not send a shared system credential")
require(!client.contains("DreamJourneyBackendAPIToken"), "The app must not read a packaged backend token")
require(client.contains("case userAuthenticationRequired"), "Missing user sessions must return a typed local error")
require(client.contains("guard let authenticatedSession = currentSession else"), "User requests must fail before networking without a session")
require(client.contains("X-DreamJourney-User-Id"), "Ownership shadow must receive the authenticated actor hint")
require(client.contains("\"Authorization\": \"Bearer \\(session.accessToken)\""), "User requests must send the opaque access token")
require(client.contains("statusCode == 401"), "Client must only refresh after an unauthorized response")
require(client.contains("allowsRefresh: false"), "Refresh retry must be bounded to one attempt")
require(client.contains("path: \"/auth/refresh\""), "Client must implement refresh rotation")
require(client.contains("path: \"/auth/logout\""), "Client must revoke the server session on logout")
require(client.contains("activeAuthRefreshGroup"), "Concurrent 401 responses must share one active refresh request")
require(client.contains("pendingAuthRefreshGroups"), "Refresh coalescing must retain session-scoped pending groups")
require(client.contains("adoptAuthSession(from: object)"), "Login must persist the backend-issued auth session")
require(client.contains("session.userId != responseUserId"), "Login must reject a session bound to another user")

require(userManager.contains("DreamJourneyBackendClient.shared.logoutAuthSession()"), "User logout must revoke and clear auth state")
require(project.contains("BackendAuthSessionStore.swift"), "Auth session store must belong to the app target")

print("Auth session and ownership shadow checks passed")
