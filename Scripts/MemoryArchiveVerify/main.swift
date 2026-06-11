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
    assertCondition(repo.summary().textCount == 1, "summary should count text materials")

    let photo = try repo.addPhoto(
        localPath: "/tmp/old_photo.jpg",
        title: "老房子照片",
        note: "相册里翻出来的旧照片",
        tags: ["旧照片"],
        isPrivate: false,
        now: now
    )
    assertCondition(photo.analysisStatus == .pending, "photo should start pending")
    assertCondition(repo.summary().photoCount == 1, "summary should count photos")

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
    assertCondition(repo.items().count == 1, "deleted item should be removed")

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
} catch {
    fputs("FAIL: unexpected error \(error)\n", stderr)
    exit(1)
}

print("MemoryArchive verification passed")
