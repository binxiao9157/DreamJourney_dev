import Foundation
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class ControllableClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

final class SequenceUUIDGenerator {
    private var values: [UUID]

    init(values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        precondition(!values.isEmpty, "test UUID sequence exhausted")
        return values.removeFirst()
    }
}

struct StubHTTPResponse: Equatable {
    let statusCode: Int
    let body: Data
}

final class StubHTTPTransport {
    var nextResult: Result<StubHTTPResponse, Error>
    private(set) var requests: [URLRequest] = []

    init(nextResult: Result<StubHTTPResponse, Error>) {
        self.nextResult = nextResult
    }

    func send(_ request: URLRequest) -> Result<StubHTTPResponse, Error> {
        requests.append(request)
        return nextResult
    }
}

final class NotificationSpy {
    private(set) var postedNames: [String] = []

    func post(name: String) {
        postedNames.append(name)
    }
}

final class AudioOwnerSpy {
    private(set) var transitions: [AudioOwnerLeaseOwner] = []

    func record(_ owner: AudioOwnerLeaseOwner) {
        transitions.append(owner)
    }
}
