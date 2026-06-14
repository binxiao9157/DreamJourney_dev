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

    let screenshot = try repo.addScreenshot(
        localPath: "/tmp/wechat_voice_screenshot.jpg",
        title: "",
        note: "",
        tags: ["聊天记录"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    assertCondition(screenshot.kind == .screenshot, "screenshot material should persist its own kind")
    assertCondition(screenshot.title == "聊天截图", "blank screenshot title should use screenshot default")
    assertCondition(screenshot.note == "从相册加入的聊天记录或语音截图素材", "blank screenshot note should explain material type")
    assertCondition(screenshot.analysisStatus == .pending, "generation screenshot should start pending analysis")
    assertCondition(screenshot.privacyMetadata.scope == .generationAllowed, "screenshot should persist explicit generation scope")
    assertCondition(repo.summary().screenshotCount == 1, "summary should count screenshot materials separately")

    let voiceSample = try repo.addVoiceSample(
        localPath: "/tmp/grandma_voice.m4a",
        title: "外婆语音",
        note: "饭要趁热吃。",
        tags: ["语音样本"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    assertCondition(voiceSample.kind == .voiceSample, "voice sample should persist its kind")
    assertCondition(voiceSample.analysisStatus == .manual, "voice sample should be manual")
    assertCondition(voiceSample.localPath == "/tmp/grandma_voice.m4a", "voice sample local path should persist")
    assertCondition(voiceSample.privacyMetadata.scope == .generationAllowed, "voice sample should persist explicit generation scope")
    assertCondition(repo.summary().voiceSampleCount == 1, "summary should count voice samples")
    let targetedVoiceSample = try repo.attachTargetPerson(
        id: voiceSample.id,
        targetPersonId: "person-linguifang",
        now: now.addingTimeInterval(1)
    )
    assertCondition(targetedVoiceSample.targetPersonId == "person-linguifang", "voice sample should persist target person id")

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

    let realRoadshowArchive = try repo.addText(
        kind: .textNote,
        title: "外滩老照片",
        note: "这是真实的产品路演经历，不是演示数据。",
        tags: ["路演"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    let reloadedRepo = MemoryArchiveRepository(defaults: defaults, storageKey: "archive")
    assertCondition(
        reloadedRepo.items().contains(where: { $0.id == realRoadshowArchive.id }),
        "real archive materials should not be deleted only because their title or tags look like old demo content"
    )

    let legacySeedSuiteName = "MemoryArchiveLegacySeedVerify"
    let legacySeedDefaults = UserDefaults(suiteName: legacySeedSuiteName)!
    legacySeedDefaults.removePersistentDomain(forName: legacySeedSuiteName)
    let legacySeedJSON = """
    [{
      "id":"random-uuid-from-old-seed",
      "kind":"textNote",
      "title":"外滩合影的背景",
      "note":"1975 年 7 月，陈树安和陈静文在外滩拍过一张全家合影。",
      "createdAt":"2026-01-01T00:00:00Z",
      "updatedAt":"2026-01-01T00:00:00Z",
      "analysisStatus":"manual",
      "detectedPeople":[],
      "tags":["路演","外滩","家庭合影"],
      "isPrivate":false
    }, {
      "id":"real-similar-roadshow-memory",
      "kind":"textNote",
      "title":"外滩合影的背景",
      "note":"这是我自己补录的真实项目路演经历，不是内置演示家庭。",
      "createdAt":"2026-01-01T00:00:00Z",
      "updatedAt":"2026-01-01T00:00:00Z",
      "analysisStatus":"manual",
      "detectedPeople":[],
      "tags":["路演"],
      "isPrivate":false
    }]
    """.data(using: .utf8)!
    legacySeedDefaults.set(legacySeedJSON, forKey: "archive")
    let legacySeedRepo = MemoryArchiveRepository(defaults: legacySeedDefaults, storageKey: "archive")
    let legacySeedItems = legacySeedRepo.items()
    assertCondition(
        !legacySeedItems.contains(where: { $0.id == "random-uuid-from-old-seed" }),
        "old roadshow text seed should be cleaned even when it has a random UUID"
    )
    assertCondition(
        legacySeedItems.contains(where: { $0.id == "real-similar-roadshow-memory" }),
        "real archive text with similar roadshow wording should be preserved"
    )

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
    assertCondition(repo.items().count == 6, "deleted item should be removed")

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

    do {
        _ = try repo.addVoiceSample(
            localPath: " ",
            title: "空路径语音",
            isPrivate: false,
            now: now
        )
        assertCondition(false, "blank voice sample path should throw")
    } catch MemoryArchiveRepositoryError.invalidVoicePath {
        assertCondition(true, "blank voice sample path throws expected error")
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
