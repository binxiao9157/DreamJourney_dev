import Foundation

@main
enum KnowledgeSemanticCacheIsolationModelSmoke {
    static func main() {
        let generationA = UUID()
        let generationB = UUID()
        let ownerA = requireScope(owner: "account-a", generation: generationA)
        let ownerB = requireScope(owner: "account-b", generation: generationA)
        let nextGeneration = requireScope(owner: "account-a", generation: generationB)

        require(ownerA != ownerB, "different owners must not share a semantic cache scope")
        require(ownerA != nextGeneration, "a user generation change must invalidate the semantic cache scope")
        require(ownerA.ownerDigest != "account-a", "semantic cache scope must not retain raw user IDs")

        let person = KBLiteSemanticCacheKey(
            scope: ownerA,
            entityKind: .person,
            entityId: "shared-id",
            searchableText: "旧内容"
        )
        let place = KBLiteSemanticCacheKey(
            scope: ownerA,
            entityKind: .place,
            entityId: "shared-id",
            searchableText: "旧内容"
        )
        let updatedPerson = KBLiteSemanticCacheKey(
            scope: ownerA,
            entityKind: .person,
            entityId: "shared-id",
            searchableText: "新内容"
        )
        let otherOwnerPerson = KBLiteSemanticCacheKey(
            scope: ownerB,
            entityKind: .person,
            entityId: "shared-id",
            searchableText: "旧内容"
        )

        require(person != place, "entity kind must isolate same-ID embeddings")
        require(person != updatedPerson, "content updates must invalidate same-ID embeddings")
        require(person != otherOwnerPerson, "owner scope must isolate same-ID embeddings")
        require(!person.textFingerprint.contains("旧内容"), "cache keys must not retain searchable text")
        require(
            KBLiteSemanticCachePolicy.accepts(taskScope: ownerA, activeScope: ownerA),
            "the active scope must accept its own work"
        )
        require(
            !KBLiteSemanticCachePolicy.accepts(taskScope: ownerA, activeScope: ownerB),
            "a stale owner warm task must be rejected"
        )
        require(
            !KBLiteSemanticCachePolicy.accepts(taskScope: ownerA, activeScope: nextGeneration),
            "a stale generation warm task must be rejected"
        )

        print("Knowledge semantic cache isolation model smoke passed")
    }

    private static func requireScope(owner: String, generation: UUID) -> KBLiteSemanticCacheScope {
        guard let scope = KBLiteSemanticCacheScope(ownerUserId: owner, generation: generation) else {
            fatalError("expected a valid semantic cache scope")
        }
        return scope
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
