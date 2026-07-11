import Foundation

struct KBLiteSemanticCacheScope: Hashable {
    let ownerDigest: String
    let generation: UUID

    init?(ownerUserId: String, generation: UUID) {
        let owner = ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, owner != "signed-out" else { return nil }
        ownerDigest = Self.digest(owner)
        self.generation = generation
    }

    private static func digest(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

enum KBLiteSemanticEntityKind: String, Hashable {
    case person
    case place
    case event
    case fact
}

struct KBLiteSemanticCacheKey: Hashable {
    let scope: KBLiteSemanticCacheScope
    let entityKind: KBLiteSemanticEntityKind
    let entityIdFingerprint: String
    let textFingerprint: String

    init(
        scope: KBLiteSemanticCacheScope,
        entityKind: KBLiteSemanticEntityKind,
        entityId: String,
        searchableText: String
    ) {
        self.scope = scope
        self.entityKind = entityKind
        entityIdFingerprint = Self.fingerprint(entityId)
        textFingerprint = Self.fingerprint(searchableText)
    }

    private static func fingerprint(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx:%d", hash, value.utf8.count)
    }
}

enum KBLiteSemanticCachePolicy {
    static func accepts(
        taskScope: KBLiteSemanticCacheScope,
        activeScope: KBLiteSemanticCacheScope?
    ) -> Bool {
        taskScope == activeScope
    }
}
