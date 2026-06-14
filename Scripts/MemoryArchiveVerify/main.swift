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
    let emptyReadiness = MemoryArchiveBuildReadiness.build(items: [], archiveKnowledgeSourceCount: 0)
    assertCondition(emptyReadiness.state == .empty, "empty archive should be empty readiness")
    assertCondition(emptyReadiness.completedStepCount == 0, "empty readiness should have no completed steps")
    assertCondition(emptyReadiness.missingRequirements.contains("1 张已分析的可生成旧照片"), "readiness should ask for analyzed photo evidence")

    let readinessSuiteName = "MemoryArchiveReadinessVerify-\(UUID().uuidString)"
    let readinessDefaults = UserDefaults(suiteName: readinessSuiteName)!
    readinessDefaults.removePersistentDomain(forName: readinessSuiteName)
    let readinessRepo = MemoryArchiveRepository(defaults: readinessDefaults, storageKey: "archive")
    _ = try readinessRepo.addPhoto(
        localPath: "/tmp/private_photo.jpg",
        title: "私密照片",
        privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly),
        now: now
    )
    _ = try readinessRepo.addVoiceSample(
        localPath: "/tmp/local_voice.m4a",
        title: "本机语音",
        privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly),
        now: now
    )
    let privateOnlyReadiness = MemoryArchiveBuildReadiness.build(items: readinessRepo.items(), archiveKnowledgeSourceCount: 0)
    assertCondition(privateOnlyReadiness.completedStepCount == 0, "private/local materials should not count toward generation readiness")

    let pendingGenerationPhoto = try readinessRepo.addPhoto(
        localPath: "/tmp/generation_photo.jpg",
        title: "可生成旧照片",
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    let pendingScreenshot = try readinessRepo.addScreenshot(
        localPath: "/tmp/wechat_voice_1.jpg",
        title: "微信语音截图",
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    let untranscribedVoice1 = try readinessRepo.addVoiceSample(
        localPath: "/tmp/generation_voice_1.m4a",
        title: "语音样本 1",
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    let untranscribedVoice2 = try readinessRepo.addVoiceSample(
        localPath: "/tmp/generation_voice_2.m4a",
        title: "语音样本 2",
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    _ = try readinessRepo.addText(
        kind: .catchphrase,
        title: "口头禅",
        note: "慢慢来，饭要趁热吃。",
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed),
        now: now
    )
    let pendingMaterialReadiness = MemoryArchiveBuildReadiness.build(items: readinessRepo.items(), archiveKnowledgeSourceCount: 0)
    assertCondition(
        pendingMaterialReadiness.state == .collecting,
        "pending photo and untranscribed voice samples should not claim material readiness"
    )
    assertCondition(
        pendingMaterialReadiness.missingRequirements.contains("1 张已分析的可生成旧照片"),
        "readiness should require analyzed photo evidence, not just a photo file"
    )
    assertCondition(
        pendingMaterialReadiness.missingRequirements.contains("3 份有真实转写或分析的可生成语音/截图材料"),
        "readiness should require voice transcript or screenshot analysis evidence"
    )

    _ = try readinessRepo.applyImageAnalysis(
        id: pendingGenerationPhoto.id,
        analysis: MemoryArchiveImageAnalysis(
            summary: "一家人在西湖边合影。",
            detectedPeople: ["林桂芳"],
            scene: "西湖",
            occasion: "家庭合影",
            mood: "温暖",
            estimatedDecade: 1970
        ),
        now: now.addingTimeInterval(1)
    )
    _ = try readinessRepo.applyImageAnalysis(
        id: pendingScreenshot.id,
        analysis: MemoryArchiveImageAnalysis(
            summary: "微信语音截图记录了长辈的一段问候。",
            detectedPeople: ["林桂芳"],
            scene: "聊天截图",
            occasion: "语音记录",
            mood: "平和",
            estimatedDecade: nil
        ),
        now: now.addingTimeInterval(2)
    )
    _ = try readinessRepo.updateVoiceTranscript(
        id: untranscribedVoice1.id,
        transcript: "慢慢来，饭要趁热吃。",
        now: now.addingTimeInterval(3)
    )
    _ = try readinessRepo.updateVoiceTranscript(
        id: untranscribedVoice2.id,
        transcript: "今天别太累，早点休息。",
        now: now.addingTimeInterval(4)
    )

    let materialReady = MemoryArchiveBuildReadiness.build(items: readinessRepo.items(), archiveKnowledgeSourceCount: 0)
    assertCondition(materialReady.state == .materialReady, "complete materials without structured knowledge should be materialReady")
    assertCondition(materialReady.completedStepCount == 3, "materials should complete photo, voice evidence, and persona steps")
    assertCondition(materialReady.missingRequirements == ["至少 1 条档案来源的结构化知识"], "material readiness should only miss structured knowledge")

    let grounded = MemoryArchiveBuildReadiness.build(items: readinessRepo.items(), archiveKnowledgeSourceCount: 1)
    assertCondition(grounded.state == .grounded, "archive source knowledge should complete grounding readiness")
    assertCondition(grounded.completedStepCount == 4, "grounded readiness should complete all steps")
    assertCondition(grounded.detailText.contains("最小建库已成型"), "grounded readiness should expose user-facing completion text")

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

    let backendUpdatedPhoto = MemoryArchiveItem(
        id: photo.id,
        kind: .photo,
        title: "老房子照片",
        note: "服务器补齐的分析摘要",
        localPath: nil,
        createdAt: photo.createdAt,
        updatedAt: now.addingTimeInterval(20),
        analysisStatus: .analyzed,
        analysisSummary: "服务器恢复：一家人在老房子门口合影。",
        detectedPeople: ["林桂芳"],
        scene: "老房子",
        occasion: "家庭合影",
        mood: "温暖",
        estimatedDecade: 1980,
        tags: ["旧照片", "服务器恢复"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
    )
    let backendOnlyNote = MemoryArchiveItem(
        id: "backend-note-1",
        kind: .textNote,
        title: "服务器恢复文字",
        note: "从后端恢复的档案元数据。",
        localPath: nil,
        createdAt: now.addingTimeInterval(21),
        updatedAt: now.addingTimeInterval(21),
        analysisStatus: .manual,
        analysisSummary: nil,
        detectedPeople: [],
        scene: nil,
        occasion: nil,
        mood: nil,
        estimatedDecade: nil,
        tags: ["服务器恢复"],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
    )
    let mergedRemoteCount = repo.mergeRemoteItems([backendUpdatedPhoto, backendOnlyNote])
    let mergedItems = repo.items()
    let mergedPhoto = mergedItems.first { $0.id == photo.id }
    assertCondition(mergedRemoteCount == 2, "remote merge should count one update and one insert")
    assertCondition(mergedPhoto?.localPath == "/tmp/old_photo.jpg", "remote metadata merge must preserve existing local photo path")
    assertCondition(mergedPhoto?.analysisStatus == .analyzed, "remote metadata merge should apply newer analysis state")
    assertCondition(mergedPhoto?.analysisSummary?.contains("服务器恢复") == true, "remote metadata merge should apply newer analysis summary")
    assertCondition(
        mergedItems.contains(where: { $0.id == "backend-note-1" && $0.localPath == nil }),
        "remote-only archive metadata should become visible in the local archive list"
    )

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
    assertCondition(repo.items().count == 7, "deleted item should be removed while preserving backend-restored metadata")

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
