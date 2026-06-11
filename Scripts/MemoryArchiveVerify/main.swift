import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private let suiteName = "MemoryArchiveVerify"
let defaults = UserDefaults(suiteName: suiteName)!
defaults.removePersistentDomain(forName: suiteName)

let repo = MemoryArchiveRepository(defaults: defaults, storageKey: "archive")
let now = Date(timeIntervalSince1970: 1_800_000_100)

do {
    let note = try repo.addText(
        kind: .personalityNote,
        title: "妈妈的口头禅",
        note: "慢慢吃，别着急。",
        tags: ["口头禅"],
        isPrivate: true,
        now: now
    )
    assertCondition(note.analysisStatus == .manual, "text material should be manual")
    assertCondition(note.isPrivate, "text privacy should persist")
    assertCondition(note.privacyMetadata.scope == .privateOnly, "private text should map to privateOnly")
    assertCondition(repo.summary().textCount == 1, "summary should count text materials")

    let photo = try repo.addPhoto(
        localPath: "/tmp/old_photo.jpg",
        title: "老房子照片",
        note: "相册里翻出来的旧照片",
        tags: ["旧照片"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    assertCondition(photo.analysisStatus == .pending, "photo should start pending")
    assertCondition(photo.privacyMetadata.scope == .generationAllowed, "photo should persist explicit generation scope")
    assertCondition(repo.summary().photoCount == 1, "summary should count photos")

    let familyPhoto = try repo.addPhoto(
        localPath: "/tmp/family_photo.jpg",
        title: "家庭共享照片",
        note: "只给家人看，不做远端分析",
        tags: ["家庭"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle),
        now: now
    )
    assertCondition(familyPhoto.analysisStatus == .manual, "family photo should not start remote analysis")
    assertCondition(familyPhoto.privacyMetadata.scope == .familyCircle, "family photo should persist explicit family scope")

    let familyNote = try repo.addText(
        kind: .textNote,
        title: "家庭可见回忆",
        note: "这段可以给家人看。",
        tags: ["家庭"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .familyCircle),
        now: now
    )
    assertCondition(familyNote.privacyMetadata.scope == .familyCircle, "text should persist explicit family scope")

    let analysis = MemoryArchiveImageAnalysis(
        summary: "一家人在老房子门口合影。",
        detectedPeople: ["妈妈", "外婆"],
        scene: "老房子",
        occasion: "家庭合影",
        mood: "温馨",
        estimatedDecade: 1990
    )

    let analyzed = try repo.applyImageAnalysis(
        id: photo.id,
        analysis: analysis,
        now: now.addingTimeInterval(5)
    )
    assertCondition(analyzed.analysisStatus == .analyzed, "photo should become analyzed")
    assertCondition(analyzed.detectedPeople == ["妈妈", "外婆"], "detected people should persist")
    assertCondition(analyzed.scene == "老房子", "scene should persist")
    assertCondition(repo.summary().analyzedPhotoCount == 1, "summary should count analyzed photos")

    let failed = try repo.markAnalysisFailed(id: analyzed.id, now: now.addingTimeInterval(10))
    assertCondition(failed.analysisStatus == .failed, "photo can be marked failed")

    try repo.delete(id: note.id)
    assertCondition(repo.items().count == 3, "deleted item should be removed")

    do {
        _ = try repo.addText(
            kind: .textNote,
            title: "",
            note: " ",
            tags: [],
            isPrivate: false,
            now: now
        )
        assertCondition(false, "blank text material should throw")
    } catch MemoryArchiveRepositoryError.invalidText {
        assertCondition(true, "blank text material throws expected error")
    }

    let legacyJSON = """
    [{
      "id":"legacy-private",
      "kind":"textNote",
      "title":"旧私密",
      "note":"旧内容",
      "createdAt":"2026-01-01T00:00:00Z",
      "updatedAt":"2026-01-01T00:00:00Z",
      "analysisStatus":"manual",
      "detectedPeople":[],
      "tags":[],
      "isPrivate":true
    }]
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let legacyItems = try decoder.decode([MemoryArchiveItem].self, from: legacyJSON)
    assertCondition(legacyItems.first?.privacyMetadata.scope == .privateOnly, "legacy private archive item should migrate to privateOnly")
} catch {
    fputs("FAIL: unexpected error \(error)\n", stderr)
    exit(1)
}

print("MemoryArchive verification passed")
