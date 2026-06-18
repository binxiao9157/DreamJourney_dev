//
//  AppDelegate.swift
//  DreamJourney
//

import UIKit
#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))
import SpeechEngineToB
import AMapFoundationKit
import MAMapKit
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 火山引擎语音 SDK 环境准备
        #if !(UI_QA_SIMULATOR && targetEnvironment(simulator))
        SpeechEngine.prepareEnvironment()

        // ⚠️ AMap3DMap 8.1.0+ 强制要求：必须在创建 MAMapView 之前调用隐私合规接口，
        //    否则 MAMapView(frame:) 会返回 nil，地图黑屏。
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)

        // 初始化高德地图 SDK
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String, apiKey != "YOUR_AMAP_KEY" {
            AMapServices.shared().apiKey = apiKey
        }
        #endif
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        configureUIQASmokeHarnessIfNeeded()
        #endif
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
private extension AppDelegate {
    func configureUIQASmokeHarnessIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("DJEnableArchiveRemoteFetch") {
            FeatureFlagService.shared.set(.archiveRemoteFetch, enabled: true)
            print("[UI_QA] Archive remote fetch enabled")
        }
        if arguments.contains("DJRunProfileFamilyPersonaReleaseSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runProfileFamilyPersonaReleaseSmoke()
            }
        } else if arguments.contains("DJRunArchiveMediaEntriesSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runArchiveMediaEntriesSmoke()
            }
        } else if arguments.contains("DJRunBackendEnvSmoke") {
            seedEchoArchiveContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.runBackendEnvSmoke()
            }
        } else if arguments.contains("DJRunArchiveToEchoSmoke") {
            DialogPromptDebugRecorder.reset()
            seedPendingArchiveAnalysisContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.runArchiveToEchoSmoke()
            }
        } else if arguments.contains("DJShowEchoListeningStatePreview") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showEchoVoiceStatePreview(targetState: .listening)
            }
        } else if arguments.contains("DJShowEchoSpeakingStatePreview") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showEchoVoiceStatePreview(targetState: .speaking)
            }
        } else if arguments.contains("DJShowEchoVoiceStatePreview") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showEchoVoiceStatePreview()
            }
        } else if arguments.contains("DJSeedEchoArchiveContext") {
            seedEchoArchiveContext()
        } else if arguments.contains("DJSeedPendingArchiveAnalysis") {
            seedPendingArchiveAnalysisContext()
        }
    }

    func runProfileFamilyPersonaReleaseSmoke() {
        let releaseRowVisible = ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible(
            isFamilyManagementEnabled: false,
            isHiddenBranchesEnabled: false
        )
        let familyManagementOnlyRowVisible = ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible(
            isFamilyManagementEnabled: true,
            isHiddenBranchesEnabled: false
        )
        let familyManagementOnlyCanOpenSwitcher = ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher(
            isFamilySpaceEnabled: false,
            isHiddenBranchesEnabled: false
        )
        let familySpaceCanOpenSwitcher = ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher(
            isFamilySpaceEnabled: true,
            isHiddenBranchesEnabled: false
        )
        let hiddenBranchesCanOpenSwitcher = ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher(
            isFamilySpaceEnabled: false,
            isHiddenBranchesEnabled: true
        )
        let familyMembers = FamilyRepository.shared.getAll()
        let selfContext = DigitalHumanContext.defaultContext(userId: UserManager.shared.currentUser?.id ?? "user_9999")
        let firstFamilyMember = familyMembers.first
        let profileTabSelected = selectProfileTabForFamilyPersonaSmoke()
        let completed = releaseRowVisible == false
            && familyManagementOnlyRowVisible
            && familyManagementOnlyCanOpenSwitcher == false
            && familySpaceCanOpenSwitcher
            && hiddenBranchesCanOpenSwitcher
            && selfContext.isSelfAssistant
            && profileTabSelected
            && !familyMembers.isEmpty

        writeProfileFamilyPersonaReleaseSmokeResult(
            completed: completed,
            releaseRowVisible: releaseRowVisible,
            familyManagementOnlyRowVisible: familyManagementOnlyRowVisible,
            familyManagementOnlyCanOpenSwitcher: familyManagementOnlyCanOpenSwitcher,
            familySpaceCanOpenSwitcher: familySpaceCanOpenSwitcher,
            hiddenBranchesCanOpenSwitcher: hiddenBranchesCanOpenSwitcher,
            familyMemberCount: familyMembers.count,
            firstFamilyMemberMode: firstFamilyMember?.digitalHumanMode.rawValue ?? "missing",
            profileTabSelected: profileTabSelected
        )
        print(
            "[UI_QA] ProfileFamilyPersonaReleaseSmoke completed " +
            "releaseRowVisible=\(releaseRowVisible) " +
            "familyManagementOnlyCanOpenSwitcher=\(familyManagementOnlyCanOpenSwitcher) " +
            "hiddenBranchesCanOpenSwitcher=\(hiddenBranchesCanOpenSwitcher) " +
            "profileTabSelected=\(profileTabSelected) " +
            "familyMemberCount=\(familyMembers.count)"
        )
    }

    func selectProfileTabForFamilyPersonaSmoke() -> Bool {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2) else {
            return false
        }

        if let profileNavigationController = viewControllers[2] as? UINavigationController {
            profileNavigationController.popToRootViewController(animated: false)
        }
        tabBarController.selectedIndex = 2
        return true
    }

    func runArchiveMediaEntriesSmoke() {
        let releaseOptionTitles = archiveCreationOptionTitles(isHiddenBranchesEnabled: false)
        let hiddenOptionTitles = archiveCreationOptionTitles(isHiddenBranchesEnabled: true)
        let expectedReleaseOptionTitles = ["添加文字描述", "选择照片"]
        let expectedHiddenOptionTitles = ["添加文字描述", "选择照片", "录入语音", "录入时间信件"]
        let videoVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .video,
            isAudioUploadEnabled: true,
            isTimeLettersEnabled: true,
            isHiddenBranchesEnabled: true
        )
        let audioRequiresMicrophonePermission = MemoryArchiveMediaReleaseReadiness
            .capability(for: .audio)
            .requiresMicrophonePermission
        let completed = releaseOptionTitles == expectedReleaseOptionTitles
            && hiddenOptionTitles == expectedHiddenOptionTitles
            && videoVisible == false
            && audioRequiresMicrophonePermission

        writeArchiveMediaEntriesSmokeResult(
            completed: completed,
            releaseOptionTitles: releaseOptionTitles,
            hiddenOptionTitles: hiddenOptionTitles,
            videoVisible: videoVisible,
            audioRequiresMicrophonePermission: audioRequiresMicrophonePermission
        )
        print(
            "[UI_QA] ArchiveMediaEntriesSmoke completed " +
            "release=\(releaseOptionTitles.joined(separator: "|")) " +
            "hidden=\(hiddenOptionTitles.joined(separator: "|")) " +
            "videoVisible=\(videoVisible)"
        )
    }

    func archiveCreationOptionTitles(isHiddenBranchesEnabled: Bool) -> [String] {
        let audioVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .audio,
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
            isHiddenBranchesEnabled: isHiddenBranchesEnabled
        )
        let timeLetterVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .timeLetter,
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
            isHiddenBranchesEnabled: isHiddenBranchesEnabled
        )
        return MemoryArchiveCreationOption.availableOptions(
            isAudioUploadEnabled: audioVisible,
            isTimeLettersEnabled: timeLetterVisible
        ).map(\.title)
    }

    enum EchoVoiceStatePreviewTarget {
        case listening
        case waitingReply
        case speaking
    }

    func seedEchoArchiveContext() {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        let item = MemoryArchiveItemFactory.makeTextItem(
            note: "爸爸在老家院子里讲起小时候听收音机的声音"
        )
        MemoryArchiveRepository.shared.add(item, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        print("[UI_QA] Seeded echo archive context available=\(snapshot.availableItemCount)")
    }

    func seedPendingArchiveAnalysisContext() {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        let item = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/uiqa-pending-photo.jpg")
        MemoryArchiveRepository.shared.add(item, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        print("[UI_QA] Seeded pending archive analysis available=\(snapshot.availableItemCount)")
    }

    func runArchiveToEchoSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] ArchiveToEchoSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveToEchoSmoke(retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let archiveNavigationController = viewControllers.first as? UINavigationController,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController,
              let item = MemoryArchiveRepository.shared.allItems().first else {
            print("[UI_QA] ArchiveToEchoSmoke failed reason=missingSmokeDependencies")
            return
        }

        tabBarController.selectedIndex = 0
        let detailViewController = MemoryArchiveDetailViewController(item: item)
        archiveNavigationController.pushViewController(detailViewController, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            detailViewController.runUIQALocalAnalysisSmoke()
            archiveNavigationController.popToRootViewController(animated: false)
            tabBarController.selectedIndex = 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                echoViewController.runUIQAMicrophoneSmoke()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
                    let promptSnapshot = DialogPromptDebugRecorder.lastSnapshot
                    let containsArchiveContext = promptSnapshot?.containsArchiveContext == true
                    let entries = archiveSnapshot.debugSummary()
                    self.writeArchiveToEchoSmokeResult(
                        containsArchiveContext: containsArchiveContext,
                        availableItemCount: archiveSnapshot.availableItemCount,
                        entries: entries
                    )
                    print(
                        "[UI_QA] ArchiveToEchoSmoke completed " +
                        "containsArchiveContext=\(containsArchiveContext) " +
                        "available=\(archiveSnapshot.availableItemCount) " +
                        "entries=\(entries)"
                    )
                }
            }
        }
    }

    func showEchoVoiceStatePreview(
        targetState: EchoVoiceStatePreviewTarget = .waitingReply,
        retryCount: Int = 0
    ) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] EchoVoiceStatePreview failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showEchoVoiceStatePreview(targetState: targetState, retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            print("[UI_QA] EchoVoiceStatePreview failed reason=missingEcho")
            return
        }

        tabBarController.selectedIndex = 1
        switch targetState {
        case .listening:
            echoViewController.runUIQAEchoListeningStatePreview()
            print("[UI_QA] EchoVoiceStatePreview showing listening state")
        case .waitingReply:
            echoViewController.runUIQAEchoVoiceStatePreview()
            print("[UI_QA] EchoVoiceStatePreview showing waiting state")
        case .speaking:
            echoViewController.runUIQAEchoSpeakingStatePreview()
            print("[UI_QA] EchoVoiceStatePreview showing speaking state")
        }
    }

    func runBackendEnvSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                writeBackendEnvSmokeResult(
                    archiveRefreshSucceeded: false,
                    careSnapshot: nil,
                    failureReason: "missingRootTab"
                )
                print("[UI_QA] BackendEnvSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runBackendEnvSmoke(retryCount: retryCount + 1)
            }
            return
        }

        tabBarController.selectedIndex = 0
        MemoryArchiveRepository.shared.refreshFromBackend { [weak self, weak tabBarController] archiveResult in
            let archiveRefreshSucceeded: Bool
            let failureReason: String?
            switch archiveResult {
            case .success:
                archiveRefreshSucceeded = true
                failureReason = nil
            case .failure(let error):
                archiveRefreshSucceeded = false
                failureReason = error.localizedDescription
            }

            let userId = UserManager.shared.currentUser?.id ?? "user_9999"
            DreamJourneyBackendClient.shared.latestCareSnapshot(userId: userId) { careResult in
                let careSnapshot: ProfileCareSnapshot?
                switch careResult {
                case .success(let object):
                    careSnapshot = ProfileCareSnapshot(json: object)
                case .failure:
                    careSnapshot = nil
                }

                DispatchQueue.main.async {
                    if let tabBarController,
                       let viewControllers = tabBarController.viewControllers,
                       viewControllers.count > 2 {
                        tabBarController.selectedIndex = 2
                    }
                    self?.writeBackendEnvSmokeResult(
                        archiveRefreshSucceeded: archiveRefreshSucceeded,
                        careSnapshot: careSnapshot,
                        failureReason: failureReason
                    )
                    print(
                        "[UI_QA] BackendEnvSmoke completed " +
                        "archiveRefreshSucceeded=\(archiveRefreshSucceeded) " +
                        "careMoodStatus=\(careSnapshot?.moodStatus ?? "missing")"
                    )
                }
            }
        }
    }

    func writeArchiveToEchoSmokeResult(
        containsArchiveContext: Bool,
        availableItemCount: Int,
        entries: String
    ) {
        let result: [String: Any] = [
            "completed": true,
            "containsArchiveContext": containsArchiveContext,
            "availableItemCount": availableItemCount,
            "entries": entries
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveToEchoSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-to-echo-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveToEchoSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeProfileFamilyPersonaReleaseSmokeResult(
        completed: Bool,
        releaseRowVisible: Bool,
        familyManagementOnlyRowVisible: Bool,
        familyManagementOnlyCanOpenSwitcher: Bool,
        familySpaceCanOpenSwitcher: Bool,
        hiddenBranchesCanOpenSwitcher: Bool,
        familyMemberCount: Int,
        firstFamilyMemberMode: String,
        profileTabSelected: Bool
    ) {
        let result: [String: Any] = [
            "completed": completed,
            "releaseRowVisible": releaseRowVisible,
            "familyManagementOnlyRowVisible": familyManagementOnlyRowVisible,
            "familyManagementOnlyCanOpenSwitcher": familyManagementOnlyCanOpenSwitcher,
            "familySpaceCanOpenSwitcher": familySpaceCanOpenSwitcher,
            "hiddenBranchesCanOpenSwitcher": hiddenBranchesCanOpenSwitcher,
            "familyMemberCount": familyMemberCount,
            "firstFamilyMemberMode": firstFamilyMemberMode,
            "profileTabSelected": profileTabSelected,
            "hiddenBranchesArgument": ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument,
            "unavailableTitle": ProfileFamilyPersonaReleaseReadiness.unavailableTitle
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ProfileFamilyPersonaReleaseSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("profile-family-persona-release-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ProfileFamilyPersonaReleaseSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeArchiveMediaEntriesSmokeResult(
        completed: Bool,
        releaseOptionTitles: [String],
        hiddenOptionTitles: [String],
        videoVisible: Bool,
        audioRequiresMicrophonePermission: Bool
    ) {
        let result: [String: Any] = [
            "completed": completed,
            "releaseOptionTitles": releaseOptionTitles,
            "hiddenOptionTitles": hiddenOptionTitles,
            "videoVisible": videoVisible,
            "audioRequiresMicrophonePermission": audioRequiresMicrophonePermission,
            "hiddenBranchesArgument": MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveMediaEntriesSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-media-entries-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveMediaEntriesSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeBackendEnvSmokeResult(
        archiveRefreshSucceeded: Bool,
        careSnapshot: ProfileCareSnapshot?,
        failureReason: String?
    ) {
        let archiveItems = MemoryArchiveRepository.shared.allItems()
        let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
        let archiveTitles = archiveItems.map(\.title)
        let containsBackendContractPhoto = archiveItems.contains { item in
            item.title == "Backend Contract Photo"
                || item.tags.contains("backend-contract")
                || item.metadata["source"] == "backend-contract"
        }
        let containsCareSuggestion = careSnapshot?.syncCaption.contains("Call today.") == true
        let completed = archiveRefreshSucceeded
            && containsBackendContractPhoto
            && careSnapshot != nil
            && careSnapshot?.moodStatus == "需关注"

        var result: [String: Any] = [
            "completed": completed,
            "archiveRefreshSucceeded": archiveRefreshSucceeded,
            "archiveItemCount": archiveItems.count,
            "availableArchiveItemCount": archiveSnapshot.availableItemCount,
            "archiveTitles": archiveTitles,
            "containsBackendContractPhoto": containsBackendContractPhoto,
            "careMoodStatus": careSnapshot?.moodStatus ?? "missing",
            "careSyncCaption": careSnapshot?.syncCaption ?? "missing",
            "containsCareSuggestion": containsCareSuggestion,
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] BackendEnvSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("backend-env-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] BackendEnvSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }

        let storeSummary: [String: Any] = [
            "count": archiveItems.count,
            "ids": archiveItems.map(\.id),
            "kinds": archiveItems.map { $0.kind.rawValue },
            "titles": archiveTitles,
            "analysisStatuses": archiveItems.map { $0.analysisStatus.rawValue },
            "containsBackendContractPhoto": containsBackendContractPhoto,
        ]
        guard let summaryData = try? JSONSerialization.data(withJSONObject: storeSummary, options: [.sortedKeys]) else {
            print("[UI_QA] BackendEnvSmoke failed reason=storeSummaryEncoding")
            return
        }

        let summaryURL = documentsURL.appendingPathComponent("app-archive-store-summary.json")
        do {
            try summaryData.write(to: summaryURL, options: [.atomic])
        } catch {
            print("[UI_QA] BackendEnvSmoke failed reason=storeSummaryWrite error=\(error.localizedDescription)")
        }
    }
}
#endif
