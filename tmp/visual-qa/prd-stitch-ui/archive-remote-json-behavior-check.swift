import Foundation

@main
enum ArchiveRemoteJSONBehaviorCheck {
    static func main() {
        let remoteJSON: [String: Any] = [
            "id": "remote-time-letter-1",
            "kind": "time_letter",
            "title": "给未来的一封信",
            "note": "等桂花开的时候，再一起回看这段话。",
            "localPath": "/remote/archive/time-letter.txt",
            "createdAt": "2026-06-16T10:20:30Z",
            "updatedAt": "2026-06-17T11:22:33Z",
            "analysisStatus": "analyzed",
            "analysisSummary": "远端已整理出一段可用于回响的时间信件线索。",
            "detectedPeople": ["妈妈", "家人"],
            "tags": ["时间信件", "情感线索"],
            "metadata": [
                "source": "backend",
                "revision": 2,
                "contentKind": "time_letter",
            ],
        ]

        guard let item = MemoryArchiveItem(remoteJSON: remoteJSON) else {
            fail("remote JSON should parse into MemoryArchiveItem")
        }

        assertEqual(item.id, "remote-time-letter-1", "id")
        assertEqual(item.kind, .timeLetter, "kind")
        assertEqual(item.analysisStatus, .analyzed, "analysisStatus")
        assertEqual(item.title, "给未来的一封信", "title")
        assertEqual(item.note, "等桂花开的时候，再一起回看这段话。", "note")
        assertEqual(item.localPath, "/remote/archive/time-letter.txt", "localPath")
        assertEqual(item.analysisSummary, "远端已整理出一段可用于回响的时间信件线索。", "analysisSummary")
        assertEqual(item.detectedPeople, ["妈妈", "家人"], "detectedPeople")
        assertEqual(item.tags, ["时间信件", "情感线索"], "tags")
        assertEqual(item.metadata["source"], "backend", "metadata.source")
        assertEqual(item.metadata["revision"], "2", "metadata.revision")

        let invalidJSON: [String: Any] = [
            "id": "bad",
            "kind": "unsupported",
        ]
        if MemoryArchiveItem(remoteJSON: invalidJSON) != nil {
            fail("unsupported remote kind should not parse")
        }

        print("Archive remote JSON behavior checks passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        guard actual == expected else {
            fail("\(label): expected \(expected), got \(actual)")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Archive remote JSON behavior check failed: \(message)\n", stderr)
        exit(1)
    }
}
