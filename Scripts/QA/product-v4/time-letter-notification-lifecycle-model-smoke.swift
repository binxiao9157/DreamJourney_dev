import Foundation
import UserNotifications

private struct Lease: Equatable {
    let subject: String
    let vault: String
    let generation: UInt64
    let generationID: String
    let authorityEpoch: String
}

private final class RequestCenter: @unchecked Sendable {
    private(set) var requests: [String: UNNotificationRequest] = [:]
    private(set) var pendingReadCount = 0

    func add(_ request: UNNotificationRequest) {
        requests[request.identifier] = request
    }

    func getPendingNotificationRequests(
        completion: @escaping @Sendable ([UNNotificationRequest]) -> Void
    ) {
        pendingReadCount += 1
        completion(Array(requests.values))
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        identifiers.forEach { requests.removeValue(forKey: $0) }
    }
}

private final class ResultBox: @unchecked Sendable {
    var value: Bool?
}

private final class TimeLetterLifecycleScheduler {
    private let requestCenter: RequestCenter

    init(requestCenter: RequestCenter) {
        self.requestCenter = requestCenter
    }

    func schedule(itemID: String, ownerID: String, lease: Lease) -> String {
        let identifier = "dj.timeLetter.reminder.\(identity(["request", itemID, ownerID, accountLeaseIdentity(lease)]))"
        let content = UNMutableNotificationContent()
        content.userInfo = [
            "kind": "timeLetter",
            "accountLeaseIdentity": accountLeaseIdentity(lease),
            "resourceOwnerIdentity": identity(["owner", ownerID]),
            "operationIdentity": identity(["operation", itemID]),
        ]
        requestCenter.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
        return identifier
    }

    func teardown(oldLease: Lease?, completion: @escaping @Sendable (Bool) -> Void) {
        guard let oldLease else {
            completion(false)
            return
        }
        requestCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                completion(false)
                return
            }
            let identifiers = requests.compactMap { request in
                self.requestIsOwned(request, byLifecycleLease: oldLease) ? request.identifier : nil
            }
            self.requestCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            self.requestCenter.getPendingNotificationRequests { [weak self] remaining in
                guard let self else {
                    completion(false)
                    return
                }
                completion(!remaining.contains { self.requestIsOwned($0, byLifecycleLease: oldLease) })
            }
        }
    }

    private func requestIsOwned(_ request: UNNotificationRequest, byLifecycleLease lease: Lease) -> Bool {
        let userInfo = request.content.userInfo
        guard request.identifier.hasPrefix("dj.timeLetter.reminder."),
              userInfo["kind"] as? String == "timeLetter",
              userInfo["accountLeaseIdentity"] as? String == accountLeaseIdentity(lease),
              let owner = userInfo["resourceOwnerIdentity"] as? String,
              !owner.isEmpty,
              let operation = userInfo["operationIdentity"] as? String,
              !operation.isEmpty else {
            return false
        }
        return true
    }

    private func accountLeaseIdentity(_ lease: Lease) -> String {
        identity([
            "account-lease",
            lease.subject,
            lease.vault,
            String(lease.generation),
            lease.generationID,
            lease.authorityEpoch,
        ])
    }

    private func identity(_ values: [String]) -> String {
        values.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }
}

@main
private enum TimeLetterNotificationLifecycleModelSmoke {
    static func main() {
        let old = Lease(subject: "owner-a", vault: "vault-a", generation: 4, generationID: "generation-a", authorityEpoch: "epoch-a")
        let refreshed = Lease(subject: "owner-a", vault: "vault-a", generation: 5, generationID: "generation-b", authorityEpoch: "epoch-b")
        let other = Lease(subject: "owner-b", vault: "vault-b", generation: 1, generationID: "generation-c", authorityEpoch: "epoch-c")
        let requestCenter = RequestCenter()
        let scheduler = TimeLetterLifecycleScheduler(requestCenter: requestCenter)

        let oldID = scheduler.schedule(itemID: "letter-a", ownerID: "owner-a", lease: old)
        let refreshedID = scheduler.schedule(itemID: "letter-b", ownerID: "owner-a", lease: refreshed)
        let otherID = scheduler.schedule(itemID: "letter-c", ownerID: "owner-b", lease: other)

        let malformedContent = UNMutableNotificationContent()
        malformedContent.userInfo = ["kind": "timeLetter", "accountLeaseIdentity": "not-owned"]
        let malformedID = "dj.timeLetter.reminder.malformed"
        requestCenter.add(UNNotificationRequest(identifier: malformedID, content: malformedContent, trigger: nil))

        let missingLeaseResult = ResultBox()
        scheduler.teardown(oldLease: nil) { missingLeaseResult.value = $0 }
        require(missingLeaseResult.value == false, "missing old lease must report failure")
        require(requestCenter.requests.count == 4, "missing old lease must preserve all requests")

        let result = ResultBox()
        scheduler.teardown(oldLease: old) { result.value = $0 }
        require(result.value == true, "old lease teardown must complete")
        require(requestCenter.requests[oldID] == nil, "old generation request must be removed")
        require(requestCenter.requests[refreshedID] != nil, "same subject new generation request must survive")
        require(requestCenter.requests[otherID] != nil, "other account request must survive")
        require(requestCenter.requests[malformedID] != nil, "unproven request must not be deleted")
        require(requestCenter.pendingReadCount >= 2, "teardown must verify removal with a second read")

        print("TimeLetter notification lifecycle model smoke passed")
    }

    private static func require(_ condition: Bool, _ message: String) {
        if !condition {
            fatalError(message)
        }
    }
}
