//
//  AppDelegate.swift
//  DreamJourney
//

import AVFoundation
import UIKit
import UserNotifications
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDidLoginForPushDeviceToken),
            name: .djUserDidLogin,
            object: nil
        )
        configurePushDeviceTokenRegistration(application)
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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PushDeviceTokenStore.shared.saveDeviceToken(token)
        syncStoredPushDeviceTokenIfPossible()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[PushDeviceToken] remote notification registration failed: \(error.localizedDescription)")
    }

    private func configurePushDeviceTokenRegistration(_ application: UIApplication) {
        guard DreamJourneyBackendClient.shared.isPushDeviceTokenRegistrationConfigured else {
            return
        }
        guard hasAPNsEntitlement else {
            print("[PushDeviceToken] APNs entitlement missing; skip remote notification registration")
            return
        }
        application.registerForRemoteNotifications()
        syncStoredPushDeviceTokenIfPossible()
    }

    private var hasAPNsEntitlement: Bool {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let profile = String(data: data, encoding: .isoLatin1) else {
            return false
        }
        return profile.contains("<key>aps-environment</key>")
    }

    @objc private func handleUserDidLoginForPushDeviceToken() {
        syncStoredPushDeviceTokenIfPossible()
    }

    private func syncStoredPushDeviceTokenIfPossible() {
        guard DreamJourneyBackendClient.shared.isPushDeviceTokenRegistrationConfigured,
              let userId = UserManager.shared.currentUser?.id,
              let deviceToken = PushDeviceTokenStore.shared.loadDeviceToken() else {
            return
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        DreamJourneyBackendClient.shared.registerPushDeviceToken(
            userId: userId,
            deviceToken: deviceToken,
            environment: PushDeviceTokenEnvironment.current,
            deviceId: deviceId
        ) { result in
            switch result {
            case .success(let object):
                guard let item = object["item"] as? [String: Any],
                      let registration = PushDeviceTokenRegistration(json: item) else {
                    return
                }
                _ = PushDeviceTokenStore.shared.saveRegistration(registration)
            case .failure(let error):
                print("[PushDeviceToken] backend registration failed: \(error.localizedDescription)")
            }
        }
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
        if arguments.contains("DJRunProfileCareBackendFailureRetrySmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runProfileCareBackendFailureRetrySmoke()
            }
        } else if arguments.contains("DJRunProfileCareBackendStateSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runProfileCareBackendStateSmoke()
            }
        } else if arguments.contains("DJRunProfileCareStateSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runProfileCareStateSmoke()
            }
        } else if arguments.contains("DJRunProfileCareEscalationBoundarySmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runProfileCareEscalationBoundarySmoke()
            }
        } else if arguments.contains("DJRunProfileFamilyPersonaReleaseSmoke") {
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
        } else if arguments.contains("DJRunArchiveAudioLifecycleSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runArchiveAudioLifecycleSmoke()
            }
        } else if arguments.contains("DJRunArchiveHiddenShellSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runArchiveHiddenShellSmoke()
            }
        } else if arguments.contains("DJRunArchiveFailedAnalysisRetrySmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            FeatureFlagService.shared.resetToDefaults()
            seedFailedArchiveAnalysisRetryContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runArchiveFailedAnalysisRetrySmoke()
            }
        } else if arguments.contains("DJRunEchoDelayedReplyNotificationSmoke") {
            UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.runEchoDelayedReplyNotificationSmoke()
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
        } else if arguments.contains("DJRunArchiveMediaEchoContextSmoke") {
            DialogPromptDebugRecorder.reset()
            seedArchiveMediaEchoContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.runArchiveMediaEchoContextSmoke()
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
        } else if arguments.contains("DJSeedArchiveAnalysisInsights") {
            seedArchiveAnalysisInsightsContext()
        } else if arguments.contains("DJSeedPendingArchiveAnalysis") {
            seedPendingArchiveAnalysisContext()
        }
    }

    func runProfileCareEscalationBoundarySmoke() {
        let userId = UserManager.shared.currentUser?.id ?? "user_9999"
        let context = DigitalHumanContext.defaultContext(userId: userId)
        let snapshot = ProfileCareSnapshot(
            moodTitle: "心境追踪",
            moodStatus: "需关注",
            emotionalIndex: 0.64,
            cognitiveIndex: 0.75,
            sleepStatus: "睡眠线索 2 条",
            lonelinessIndex: 0.2,
            riskReminder: "Call today."
        )
        let draft = ProfileCareEscalationDraft.make(
            snapshot: snapshot,
            personaDisplayName: context.displayName
        )
        let payload = draft.backendCandidatePayload(viewerUserId: userId, personaOwnerId: context.ownerId)
        let profileTabSelected = selectProfileTabForCareEscalationSmoke()
        let completed = (payload["schemaVersion"] as? String) == "profileCareEscalationDraft.v1"
            && (payload["deliveryState"] as? String) == "draftOnly"
            && (payload["requiresHumanReview"] as? Bool) == true
            && (payload["backendContractConnected"] as? Bool) == false
            && (payload["willContactThirdParty"] as? Bool) == false
            && (payload["allowsEmergencyUse"] as? Bool) == false
            && (payload["containsRawTranscript"] as? Bool) == false
            && profileTabSelected

        writeProfileCareEscalationBoundarySmokeResult(
            completed: completed,
            payload: payload,
            profileTabSelected: profileTabSelected
        )
        print(
            "[UI_QA] ProfileCareEscalationBoundarySmoke completed " +
            "deliveryState=\(payload["deliveryState"] as? String ?? "missing") " +
            "backendContractConnected=\(payload["backendContractConnected"] as? Bool ?? true) " +
            "willContactThirdParty=\(payload["willContactThirdParty"] as? Bool ?? true) " +
            "profileTabSelected=\(profileTabSelected)"
        )
    }

    func runProfileCareStateSmoke() {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController,
              let profileViewController = profileNavigationController.viewControllers.first as? ProfileViewController else {
            writeProfileCareStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                failureReason: "missingProfileRoot"
            )
            print("[UI_QA] ProfileCareStateSmoke failed reason=missingProfileRoot")
            return
        }

        profileNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2
        profileViewController.loadViewIfNeeded()

        let states = profileViewController.runUIQAProfileCareStateSmoke()
        let expectedStates = Set([
            ProfileCareSnapshot.emptyFallback().dataState.accessibilityIdentifier,
            ProfileCareSnapshot.staleFallback().dataState.accessibilityIdentifier,
            ProfileCareSnapshot.failedFallback().dataState.accessibilityIdentifier,
        ])
        let profileStates = Set(states.compactMap { $0["profileState"] as? String })
        let dashboardStates = Set(states.compactMap {
            ($0["dashboard"] as? [String: Any])?["dashboardState"] as? String
        })
        let allRetryActionsVisible = states.allSatisfy {
            ($0["profileRetryVisible"] as? Bool) == true
                && ($0["profileRetryActionTitle"] as? String) == "重新同步"
                && (($0["dashboard"] as? [String: Any])?["dashboardActionTitle"] as? String) == "重新同步"
        }
        let allDashboardCardsVisible = states.allSatisfy {
            (($0["dashboard"] as? [String: Any])?["dashboardHasStateCard"] as? Bool) == true
        }
        let completed = profileStates == expectedStates
            && dashboardStates == expectedStates
            && allRetryActionsVisible
            && allDashboardCardsVisible

        writeProfileCareStateSmokeResult(
            completed: completed,
            states: states,
            profileTabSelected: tabBarController.selectedIndex == 2,
            failureReason: completed ? nil : "stateContractMismatch"
        )
        print(
            "[UI_QA] ProfileCareStateSmoke completed " +
            "completed=\(completed) " +
            "profileStates=\(profileStates.sorted().joined(separator: "|")) " +
            "dashboardStates=\(dashboardStates.sorted().joined(separator: "|"))"
        )
    }

    func runProfileCareBackendStateSmoke() {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController,
              let profileViewController = profileNavigationController.viewControllers.first as? ProfileViewController else {
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingProfileRoot"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=missingProfileRoot")
            return
        }

        guard let activeUserId = uiqaArgumentValue(prefix: "DJCareActiveUserId="),
              let emptyUserId = uiqaArgumentValue(prefix: "DJCareEmptyUserId="),
              let staleUserId = uiqaArgumentValue(prefix: "DJCareStaleUserId=") else {
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingCareUserIds"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=missingCareUserIds")
            return
        }

        profileNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2
        profileViewController.loadViewIfNeeded()

        let cases = [
            ProfileCareBackendStateSmokeCase(
                name: "active",
                userId: activeUserId,
                expectedState: ProfileCareDataState.available.accessibilityIdentifier
            ),
            ProfileCareBackendStateSmokeCase(
                name: "empty",
                userId: emptyUserId,
                expectedState: ProfileCareDataState.empty.accessibilityIdentifier
            ),
            ProfileCareBackendStateSmokeCase(
                name: "stale",
                userId: staleUserId,
                expectedState: ProfileCareDataState.stale.accessibilityIdentifier
            ),
        ]

        profileViewController.runUIQAProfileCareBackendStateSmoke(cases: cases) { [weak self] states in
            let profileTabSelected = tabBarController.selectedIndex == 2
            let expectedStates = Dictionary(uniqueKeysWithValues: cases.map { ($0.name, $0.expectedState) })
            let actualStates = Dictionary(uniqueKeysWithValues: states.compactMap { state -> (String, String)? in
                guard let name = state["name"] as? String,
                      let profileState = state["profileState"] as? String else {
                    return nil
                }
                return (name, profileState)
            })
            let dashboardStates = Dictionary(uniqueKeysWithValues: states.compactMap { state -> (String, String)? in
                guard let name = state["name"] as? String,
                      let dashboard = state["dashboard"] as? [String: Any],
                      let dashboardState = dashboard["dashboardState"] as? String else {
                    return nil
                }
                return (name, dashboardState)
            })
            let retryContractsValid = states.allSatisfy { state in
                let name = state["name"] as? String
                let retryVisible = state["profileRetryVisible"] as? Bool
                let retryTitle = state["profileRetryActionTitle"] as? String
                if name == "active" {
                    return retryVisible == false && retryTitle == ""
                }
                return retryVisible == true && retryTitle == "重新同步"
            }
            let sourceContractsValid = states.allSatisfy { state in
                guard let name = state["name"] as? String,
                      let source = state["source"] as? String else {
                    return false
                }
                if name == "empty" {
                    return source == "backendErrorFallback"
                }
                return source == "backend"
            }
            let stateContractsCompleted = DreamJourneyBackendClient.shared.isCareSnapshotConfigured
                && profileTabSelected
                && states.count == cases.count
                && actualStates == expectedStates
                && dashboardStates == expectedStates
                && retryContractsValid
                && sourceContractsValid

            profileViewController.runUIQAProfileCareBackendRetrySmoke(retryUserId: activeUserId) { retry in
                let retryCompleted = (retry["retryActionFired"] as? Bool) == true
                    && (retry["retryButtonVisible"] as? Bool) == true
                    && (retry["retryRequestCountAdvanced"] as? Bool) == true
                    && (retry["retryInitialState"] as? String) == ProfileCareDataState.stale.accessibilityIdentifier
                    && (retry["retryIntermediateState"] as? String) == ProfileCareDataState.loading.accessibilityIdentifier
                    && ((retry["retryIntermediateSyncCaption"] as? String) ?? "").contains("正在重新同步关怀信号")
                    && (retry["retryFinalState"] as? String) == ProfileCareDataState.available.accessibilityIdentifier
                    && (retry["retryRequestedUserId"] as? String) == activeUserId
                let completed = stateContractsCompleted && retryCompleted

                self?.writeProfileCareBackendStateSmokeResult(
                    completed: completed,
                    states: states,
                    retry: retry,
                    profileTabSelected: profileTabSelected,
                    backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                    failureReason: completed ? nil : "backendStateOrRetryContractMismatch"
                )
                print(
                    "[UI_QA] ProfileCareBackendStateSmoke completed " +
                    "completed=\(completed) " +
                    "retryActionFired=\(retry["retryActionFired"] as? Bool ?? false) " +
                    "retryFinalState=\(retry["retryFinalState"] as? String ?? "missing") " +
                    "profileStates=\(actualStates.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: "|")) " +
                    "dashboardStates=\(dashboardStates.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: "|"))"
                )
            }
        }
    }

    func runProfileCareBackendFailureRetrySmoke() {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController,
              let profileViewController = profileNavigationController.viewControllers.first as? ProfileViewController else {
            writeProfileCareBackendFailureRetrySmokeResult(
                completed: false,
                retry: [:],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingProfileRoot"
            )
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=missingProfileRoot")
            return
        }

        guard let retryUserId = uiqaArgumentValue(prefix: "DJCareFailureRetryUserId=") else {
            writeProfileCareBackendFailureRetrySmokeResult(
                completed: false,
                retry: [:],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingCareFailureRetryUserId"
            )
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=missingCareFailureRetryUserId")
            return
        }

        profileNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2
        profileViewController.loadViewIfNeeded()

        profileViewController.runUIQAProfileCareBackendFailureRetrySmoke(retryUserId: retryUserId) { [weak self] retry in
            let profileTabSelected = tabBarController.selectedIndex == 2
            let completed = DreamJourneyBackendClient.shared.isCareSnapshotConfigured
                && profileTabSelected
                && (retry["retryActionFired"] as? Bool) == true
                && (retry["retryButtonVisible"] as? Bool) == true
                && (retry["retryRequestCountAdvanced"] as? Bool) == true
                && (retry["retryFailureInitialState"] as? String) == ProfileCareDataState.failed.accessibilityIdentifier
                && (retry["retryIntermediateState"] as? String) == ProfileCareDataState.loading.accessibilityIdentifier
                && ((retry["retryIntermediateSyncCaption"] as? String) ?? "").contains("正在重新同步关怀信号")
                && (retry["retryFailureFinalState"] as? String) == ProfileCareDataState.failed.accessibilityIdentifier
                && (retry["retryFailureFinalRetryVisible"] as? Bool) == true
                && (retry["retryRequestedUserId"] as? String) == retryUserId

            self?.writeProfileCareBackendFailureRetrySmokeResult(
                completed: completed,
                retry: retry,
                profileTabSelected: profileTabSelected,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: completed ? nil : "backendFailureRetryContractMismatch"
            )
            print(
                "[UI_QA] ProfileCareBackendFailureRetrySmoke completed " +
                "completed=\(completed) " +
                "retryFailureFinalState=\(retry["retryFailureFinalState"] as? String ?? "missing") " +
                "retryFailureFinalRetryVisible=\(retry["retryFailureFinalRetryVisible"] as? Bool ?? false)"
            )
        }
    }

    func runEchoDelayedReplyNotificationSmoke() {
        EchoDelayedReplyStore.shared.clear()

        let viewModel = EchoViewModel()
        for turn in 1..<EchoReplyPacingPolicy.waitAfterUserTurnCount {
            viewModel.beginVoiceInteraction()
            viewModel.finishUserVoice(text: "第 \(turn) 次想起爸爸小时候的故事")
            viewModel.receiveAIReply("我在听，慢慢说。")
        }
        viewModel.beginVoiceInteraction()
        viewModel.finishUserVoice(text: "第十次想起这件事")

        let delayedReply = viewModel.pendingDelayedReply
        let storedReply = EchoDelayedReplyStore.shared.load()
        let delayMinutesInRange = delayedReply.map {
            EchoReplyPacingPolicy.replyDelayMinuteRange.contains($0.minutes)
        } ?? false
        let storedDelayedReply = delayedReply != nil
            && storedReply?.id == delayedReply?.id
            && storedReply?.userTurnCount == delayedReply?.userTurnCount
            && storedReply?.trigger == delayedReply?.trigger
        let localNotificationContractPresent =
            EchoDelayedReplyNotificationScheduler.notificationIdentifier == "dj.echo.delayedReply"
        guard let delayedReply else {
            writeEchoDelayedReplyNotificationSmokeResult(
                completed: false,
                delayMinutesInRange: delayMinutesInRange,
                storedDelayedReply: storedDelayedReply,
                localNotificationContractPresent: localNotificationContractPresent,
                restoredWaitingState: false,
                restoredWaitingMinutes: 0,
                restoredWaitingMinutesInRange: false,
                restoredDelayedReplyIdMatched: false,
                expiredDelayedReplyArrived: false,
                expiredDelayedReplyCleared: false,
                pendingNotificationScheduleSucceeded: false,
                pendingNotificationMatched: false,
                pendingNotificationIdentifierMatched: false,
                pendingNotificationTriggerMatched: false,
                pendingNotificationUserInfoMatched: false,
                pendingNotificationCount: 0,
                delayedReplyId: "missing",
                trigger: "missing"
            )
            print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=missingDelayedReply")
            return
        }

        let restoreViewModel = EchoViewModel()
        let restoredWaitingState = restoreViewModel.restoreStoredDelayedReplyIfAvailable(
            now: delayedReply.scheduledAt.addingTimeInterval(60)
        ) && restoreViewModel.isWaitingForDelayedReply
        let restoredWaitingMinutes: Int
        if case .waitingReply(let minutes) = restoreViewModel.state {
            restoredWaitingMinutes = minutes
        } else {
            restoredWaitingMinutes = 0
        }
        let restoredWaitingMinutesInRange = restoredWaitingMinutes > 0
            && restoredWaitingMinutes <= delayedReply.minutes
        let restoredDelayedReplyIdMatched = restoreViewModel.pendingDelayedReply?.id == delayedReply.id

        let expiredDelayedReply = EchoDelayedReply(
            id: "expired-\(delayedReply.id)",
            scheduledAt: delayedReply.scheduledAt.addingTimeInterval(-600),
            deliverAt: delayedReply.scheduledAt.addingTimeInterval(-60),
            minutes: delayedReply.minutes,
            userTurnCount: delayedReply.userTurnCount,
            trigger: delayedReply.trigger
        )
        _ = EchoDelayedReplyStore.shared.save(expiredDelayedReply)
        let expiredViewModel = EchoViewModel()
        let expiredDelayedReplyHandled = expiredViewModel.restoreStoredDelayedReplyIfAvailable(
            now: delayedReply.scheduledAt
        )
        let expiredDelayedReplyArrived: Bool
        if case .replied = expiredViewModel.state {
            expiredDelayedReplyArrived = expiredDelayedReplyHandled
        } else {
            expiredDelayedReplyArrived = false
        }
        let expiredDelayedReplyCleared = EchoDelayedReplyStore.shared.load() == nil
        _ = EchoDelayedReplyStore.shared.save(delayedReply)

        let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
        UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions) { [weak self] granted, _ in
            guard granted else {
                self?.writeEchoDelayedReplyNotificationSmokeResult(
                    completed: false,
                    delayMinutesInRange: delayMinutesInRange,
                    storedDelayedReply: storedDelayedReply,
                    localNotificationContractPresent: localNotificationContractPresent,
                    restoredWaitingState: restoredWaitingState,
                    restoredWaitingMinutes: restoredWaitingMinutes,
                    restoredWaitingMinutesInRange: restoredWaitingMinutesInRange,
                    restoredDelayedReplyIdMatched: restoredDelayedReplyIdMatched,
                    expiredDelayedReplyArrived: expiredDelayedReplyArrived,
                    expiredDelayedReplyCleared: expiredDelayedReplyCleared,
                    pendingNotificationScheduleSucceeded: false,
                    pendingNotificationMatched: false,
                    pendingNotificationIdentifierMatched: false,
                    pendingNotificationTriggerMatched: false,
                    pendingNotificationUserInfoMatched: false,
                    pendingNotificationCount: 0,
                    delayedReplyId: delayedReply.id,
                    trigger: delayedReply.trigger.rawValue
                )
                print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=notificationAuthorizationDenied")
                return
            }

            EchoDelayedReplyNotificationScheduler.shared.schedule(delayedReply) { scheduleError in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        let pendingRequest = requests.first {
                            $0.identifier == EchoDelayedReplyNotificationScheduler.notificationIdentifier
                        }
                        let pendingNotificationIdentifierMatched = pendingRequest?.identifier
                            == EchoDelayedReplyNotificationScheduler.notificationIdentifier
                        let pendingNotificationTriggerMatched: Bool
                        if let trigger = pendingRequest?.trigger as? UNTimeIntervalNotificationTrigger {
                            pendingNotificationTriggerMatched = !trigger.repeats
                                && trigger.timeInterval > 0
                        } else {
                            pendingNotificationTriggerMatched = false
                        }
                        let pendingNotificationUserInfoMatched = pendingRequest?.content.userInfo["type"] as? String
                            == "echoDelayedReply"
                            && pendingRequest?.content.userInfo["delayedReplyId"] as? String == delayedReply.id
                            && pendingRequest?.content.userInfo["trigger"] as? String == delayedReply.trigger.rawValue
                        let pendingNotificationMatched = pendingNotificationIdentifierMatched
                            && pendingNotificationTriggerMatched
                            && pendingNotificationUserInfoMatched
                        let pendingNotificationScheduleSucceeded = scheduleError == nil
                        let completed = viewModel.isWaitingForDelayedReply
                            && delayMinutesInRange
                            && storedDelayedReply
                            && localNotificationContractPresent
                            && restoredWaitingState
                            && restoredWaitingMinutesInRange
                            && restoredDelayedReplyIdMatched
                            && expiredDelayedReplyArrived
                            && expiredDelayedReplyCleared
                            && pendingNotificationScheduleSucceeded
                            && pendingNotificationMatched

                        self?.writeEchoDelayedReplyNotificationSmokeResult(
                            completed: completed,
                            delayMinutesInRange: delayMinutesInRange,
                            storedDelayedReply: storedDelayedReply,
                            localNotificationContractPresent: localNotificationContractPresent,
                            restoredWaitingState: restoredWaitingState,
                            restoredWaitingMinutes: restoredWaitingMinutes,
                            restoredWaitingMinutesInRange: restoredWaitingMinutesInRange,
                            restoredDelayedReplyIdMatched: restoredDelayedReplyIdMatched,
                            expiredDelayedReplyArrived: expiredDelayedReplyArrived,
                            expiredDelayedReplyCleared: expiredDelayedReplyCleared,
                            pendingNotificationScheduleSucceeded: pendingNotificationScheduleSucceeded,
                            pendingNotificationMatched: pendingNotificationMatched,
                            pendingNotificationIdentifierMatched: pendingNotificationIdentifierMatched,
                            pendingNotificationTriggerMatched: pendingNotificationTriggerMatched,
                            pendingNotificationUserInfoMatched: pendingNotificationUserInfoMatched,
                            pendingNotificationCount: requests.count,
                            delayedReplyId: delayedReply.id,
                            trigger: delayedReply.trigger.rawValue
                        )
                        print(
                            "[UI_QA] EchoDelayedReplyNotificationSmoke completed " +
                            "delayMinutesInRange=\(delayMinutesInRange) " +
                            "storedDelayedReply=\(storedDelayedReply) " +
                            "localNotificationContractPresent=\(localNotificationContractPresent) " +
                            "restoredWaitingState=\(restoredWaitingState) " +
                            "expiredDelayedReplyArrived=\(expiredDelayedReplyArrived) " +
                            "pendingNotificationMatched=\(pendingNotificationMatched)"
                        )
                    }
                }
            }
        }
    }

    func selectProfileTabForCareEscalationSmoke() -> Bool {
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

    func uiqaArgumentValue(prefix: String) -> String? {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { $0.isEmpty ? nil : $0 }
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
        let backendFamilyMember = makeProfileFamilyVoiceBackendDerivedFamilyMember()
        if let backendFamilyMember {
            FamilyRepository.shared.add(backendFamilyMember)
        }
        let backendVoiceProfile = makeProfileFamilyVoiceBackendVoiceProfile()
        let backendVoiceSnapshot = backendVoiceProfile.map {
            VoiceCloneService.shared.voiceCloneShellSnapshot(from: $0)
        }
        let backendVoiceShellRendered: Bool
        if let backendVoiceSnapshot {
            let voiceShell = ProfileVoiceCloneShellViewController(snapshot: backendVoiceSnapshot)
            voiceShell.loadViewIfNeeded()
            backendVoiceShellRendered = voiceShell.view.accessibilityIdentifier == "profile-voice-clone-shell"
        } else {
            backendVoiceShellRendered = false
        }
        let familyMembers = FamilyRepository.shared.getAll()
        let selfContext = DigitalHumanContext.defaultContext(userId: UserManager.shared.currentUser?.id ?? "user_9999")
        let backendFamilyRenderedInRepository = backendFamilyMember.map { member in
            familyMembers.contains { $0.id == member.id }
        } ?? false
        let firstFamilyMember = backendFamilyMember ?? familyMembers.first
        let profileTabSelected = selectProfileTabForFamilyPersonaSmoke()
        let completed = releaseRowVisible == false
            && familyManagementOnlyRowVisible
            && familyManagementOnlyCanOpenSwitcher == false
            && familySpaceCanOpenSwitcher
            && hiddenBranchesCanOpenSwitcher
            && selfContext.isSelfAssistant
            && profileTabSelected
            && !familyMembers.isEmpty
            && backendFamilyRenderedInRepository
            && firstFamilyMember?.digitalHumanMode == .star
            && firstFamilyMember?.familyPersonaContractVersion == 1
            && backendVoiceSnapshot?.voiceProfileId == "voice_profile_uiqa_backend"
            && backendVoiceSnapshot?.sampleStatus == .pending
            && backendVoiceSnapshot?.providerMode == "mockContract"
            && backendVoiceShellRendered

        writeProfileFamilyPersonaReleaseSmokeResult(
            completed: completed,
            releaseRowVisible: releaseRowVisible,
            familyManagementOnlyRowVisible: familyManagementOnlyRowVisible,
            familyManagementOnlyCanOpenSwitcher: familyManagementOnlyCanOpenSwitcher,
            familySpaceCanOpenSwitcher: familySpaceCanOpenSwitcher,
            hiddenBranchesCanOpenSwitcher: hiddenBranchesCanOpenSwitcher,
            familyMemberCount: familyMembers.count,
            firstFamilyMemberMode: firstFamilyMember?.digitalHumanMode.rawValue ?? "missing",
            backendFamilyDigitalHumanMode: backendFamilyMember?.digitalHumanMode.rawValue ?? "missing",
            backendFamilyDigitalHumanModeLabel: backendFamilyMember?.digitalHumanModeLabel ?? "missing",
            backendFamilyPersonaContractVersion: backendFamilyMember?.familyPersonaContractVersion ?? -1,
            backendFamilyContractMode: backendFamilyMember?.backendContractMode ?? "missing",
            backendFamilyDefaultReleaseVisible: backendFamilyMember?.defaultReleaseVisible ?? true,
            backendFamilyRenderedInRepository: backendFamilyRenderedInRepository,
            backendVoiceProfileId: backendVoiceSnapshot?.voiceProfileId ?? "missing",
            backendVoiceSampleStatus: backendVoiceSnapshot?.sampleStatus.rawValue ?? "missing",
            backendVoiceProviderMode: backendVoiceSnapshot?.providerMode ?? "missing",
            backendVoiceDefaultReleaseVisible: backendVoiceSnapshot?.defaultReleaseVisible ?? true,
            backendVoiceShellRendered: backendVoiceShellRendered,
            profileTabSelected: profileTabSelected
        )
        print(
            "[UI_QA] ProfileFamilyPersonaReleaseSmoke completed " +
            "releaseRowVisible=\(releaseRowVisible) " +
            "familyManagementOnlyCanOpenSwitcher=\(familyManagementOnlyCanOpenSwitcher) " +
            "hiddenBranchesCanOpenSwitcher=\(hiddenBranchesCanOpenSwitcher) " +
            "profileTabSelected=\(profileTabSelected) " +
            "familyMemberCount=\(familyMembers.count) " +
            "backendFamilyDigitalHumanMode=\(backendFamilyMember?.digitalHumanMode.rawValue ?? "missing") " +
            "backendVoiceProfileId=\(backendVoiceSnapshot?.voiceProfileId ?? "missing")"
        )
    }

    func makeProfileFamilyVoiceBackendDerivedFamilyMember() -> FamilyMember? {
        FamilyMember.fromBackendJSON([
            "id": "family_uiqa_backend_star",
            "name": "星辰测试家人",
            "relation": "家人",
            "phone": "13900001111",
            "accessStatus": "active",
            "lastUpdated": "后端已同步",
            "personaScope": "family",
            "digitalHumanId": "digital_human_uiqa_star",
            "digitalHumanMode": "star",
            "digitalHumanModeLabel": "星辰",
            "backendContractMode": "mockFamilyPersona",
            "familyPersonaContractVersion": 1,
            "defaultReleaseVisible": false,
        ])
    }

    func makeProfileFamilyVoiceBackendVoiceProfile() -> VoiceCloneProfileContract? {
        VoiceCloneProfileContract(json: [
            "voiceProfileId": "voice_profile_uiqa_backend",
            "sampleStatus": "pending",
            "authorizationConfirmed": true,
            "authorizationVersion": "voice-clone-consent-v1",
            "authorizationCopy": "声音克隆必须由用户主动授权，仅使用用户确认提交的声音样本。",
            "providerMode": "mockContract",
            "realCloneProviderReady": false,
            "qualityAcceptanceRequired": true,
            "isEnabled": false,
            "defaultReleaseVisible": false,
            "contractVersion": 1,
            "disableContract": "后端禁用 voiceProfileId 的合成权限。",
            "deleteContract": "后端删除样本、训练产物和授权记录。",
            "personaScope": "family",
            "digitalHumanId": "digital_human_uiqa_star",
        ])
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
        let expectedHiddenOptionTitles = ["添加文字描述", "选择照片", "录入语音", "录入视频片段", "录入时间信件"]
        let releaseVideoVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .video,
            isAudioUploadEnabled: false,
            isVideoUploadEnabled: false,
            isTimeLettersEnabled: false,
            isHiddenBranchesEnabled: false
        )
        let hiddenVideoVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .video,
            isAudioUploadEnabled: true,
            isVideoUploadEnabled: true,
            isTimeLettersEnabled: true,
            isHiddenBranchesEnabled: true
        )
        let audioRequiresMicrophonePermission = MemoryArchiveMediaReleaseReadiness
            .capability(for: .audio)
            .requiresMicrophonePermission
        let completed = releaseOptionTitles == expectedReleaseOptionTitles
            && hiddenOptionTitles == expectedHiddenOptionTitles
            && releaseVideoVisible == false
            && hiddenVideoVisible
            && audioRequiresMicrophonePermission

        writeArchiveMediaEntriesSmokeResult(
            completed: completed,
            releaseOptionTitles: releaseOptionTitles,
            hiddenOptionTitles: hiddenOptionTitles,
            releaseVideoVisible: releaseVideoVisible,
            hiddenVideoVisible: hiddenVideoVisible,
            audioRequiresMicrophonePermission: audioRequiresMicrophonePermission
        )
        print(
            "[UI_QA] ArchiveMediaEntriesSmoke completed " +
            "release=\(releaseOptionTitles.joined(separator: "|")) " +
            "hidden=\(hiddenOptionTitles.joined(separator: "|")) " +
            "releaseVideoVisible=\(releaseVideoVisible) " +
            "hiddenVideoVisible=\(hiddenVideoVisible)"
        )
    }

    func archiveCreationOptionTitles(isHiddenBranchesEnabled: Bool) -> [String] {
        let audioVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .audio,
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
            isHiddenBranchesEnabled: isHiddenBranchesEnabled
        )
        let videoVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .video,
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
            isHiddenBranchesEnabled: isHiddenBranchesEnabled
        )
        let timeLetterVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
            for: .timeLetter,
            isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
            isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
            isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
            isHiddenBranchesEnabled: isHiddenBranchesEnabled
        )
        return MemoryArchiveCreationOption.availableOptions(
            isAudioUploadEnabled: audioVisible,
            isVideoUploadEnabled: videoVisible,
            isTimeLettersEnabled: timeLetterVisible
        ).map(\.title)
    }

    func runArchiveAudioLifecycleSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                writeArchiveAudioLifecycleSmokeResult(
                    completed: false,
                    permissionDeniedRecoveryReady: false,
                    releaseAudioCreationVisible: false,
                    hiddenAudioCreationVisible: false,
                    audioFileExists: false,
                    restoredAudioItem: false,
                    restoredAudioItemCount: 0,
                    summaryAudioCount: 0,
                    contextIncludesAudio: false,
                    detailViewLoaded: false,
                    detailPlaybackLoadable: false,
                    failureReason: "missingRootTab"
                )
                print("[UI_QA] ArchiveAudioLifecycleSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveAudioLifecycleSmoke(retryCount: retryCount + 1)
            }
            return
        }

        do {
            UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")
            let releaseAudioCreationVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
                for: .audio,
                isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
                isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
                isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
                isHiddenBranchesEnabled: false
            )
            let hiddenAudioCreationVisible = MemoryArchiveMediaReleaseReadiness.isCreationVisible(
                for: .audio,
                isAudioUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveAudioUpload),
                isVideoUploadEnabled: FeatureFlagService.shared.isEnabled(.archiveVideoUpload),
                isTimeLettersEnabled: FeatureFlagService.shared.isEnabled(.timeLetters),
                isHiddenBranchesEnabled: true
            )
            let audioURL = try makeUIQAArchiveAudioFile()
            let audioFileExists = FileManager.default.fileExists(atPath: audioURL.path)
            let audioItem = MemoryArchiveItemFactory.makeAudioItem(
                localPath: audioURL.path,
                duration: 1.2,
                note: "UIQA 隐藏分支录入的一段语音档案"
            )
            MemoryArchiveRepository.shared.add(audioItem, syncToBackend: false)

            let restoredItems = MemoryArchiveRepository.shared.allItems()
            let restoredAudioItem = restoredItems.first {
                $0.id == audioItem.id
                    && $0.kind == .audio
                    && $0.localPath == audioURL.path
            }
            let summary = MemoryArchiveRepository.shared.summary()
            let contextSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
            let contextIncludesAudio = contextSnapshot.entries.contains {
                $0.id == audioItem.id && $0.kindLabel == MemoryArchiveItemKind.audio.archiveDisplayName
            }

            let detailViewLoaded: Bool
            if let restoredAudioItem {
                let detailViewController = MemoryArchiveDetailViewController(item: restoredAudioItem)
                detailViewController.loadViewIfNeeded()
                detailViewLoaded = detailViewController.viewIfLoaded != nil
            } else {
                detailViewLoaded = false
            }

            let playbackPlayer = try? AVAudioPlayer(contentsOf: audioURL)
            let detailPlaybackLoadable = playbackPlayer?.prepareToPlay() == true
                && (playbackPlayer?.duration ?? 0) > 0

            let recorderViewController = MemoryArchiveAudioRecorderViewController()
            recorderViewController.loadViewIfNeeded()
            let permissionDeniedRecoveryReady = recorderViewController.runUIQAPermissionDeniedRecoverySmoke()

            let completed = permissionDeniedRecoveryReady
                && !releaseAudioCreationVisible
                && hiddenAudioCreationVisible
                && audioFileExists
                && restoredAudioItem != nil
                && summary.audio == 1
                && contextIncludesAudio
                && detailViewLoaded
                && detailPlaybackLoadable

            tabBarController.selectedIndex = 0
            writeArchiveAudioLifecycleSmokeResult(
                completed: completed,
                permissionDeniedRecoveryReady: permissionDeniedRecoveryReady,
                releaseAudioCreationVisible: releaseAudioCreationVisible,
                hiddenAudioCreationVisible: hiddenAudioCreationVisible,
                audioFileExists: audioFileExists,
                restoredAudioItem: restoredAudioItem != nil,
                restoredAudioItemCount: restoredItems.filter { $0.kind == .audio }.count,
                summaryAudioCount: summary.audio,
                contextIncludesAudio: contextIncludesAudio,
                detailViewLoaded: detailViewLoaded,
                detailPlaybackLoadable: detailPlaybackLoadable,
                failureReason: nil
            )
            print(
                "[UI_QA] ArchiveAudioLifecycleSmoke completed " +
                "permissionDeniedRecoveryReady=\(permissionDeniedRecoveryReady) " +
                "hiddenAudioCreationVisible=\(hiddenAudioCreationVisible) " +
                "audioFileExists=\(audioFileExists) " +
                "restoredAudioItem=\(restoredAudioItem != nil) " +
                "detailPlaybackLoadable=\(detailPlaybackLoadable)"
            )
        } catch {
            writeArchiveAudioLifecycleSmokeResult(
                completed: false,
                permissionDeniedRecoveryReady: false,
                releaseAudioCreationVisible: false,
                hiddenAudioCreationVisible: false,
                audioFileExists: false,
                restoredAudioItem: false,
                restoredAudioItemCount: 0,
                summaryAudioCount: 0,
                contextIncludesAudio: false,
                detailViewLoaded: false,
                detailPlaybackLoadable: false,
                failureReason: error.localizedDescription
            )
            print("[UI_QA] ArchiveAudioLifecycleSmoke failed reason=\(error.localizedDescription)")
        }
    }

    func runArchiveHiddenShellSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                writeArchiveHiddenShellSmokeResult(
                    completed: false,
                    releaseOptionsHidden: false,
                    hiddenOptionsVisible: false,
                    audioRestored: false,
                    videoRestored: false,
                    timeLetterDraftRestored: false,
                    timeLetterSealedRestored: false,
                    audioTranscriptPersisted: false,
                    audioUploadStatusPersisted: false,
                    videoThumbnailPersisted: false,
                    videoUploadStatusPersisted: false,
                    videoAnalysisPending: false,
                    mediaUploadUploaded: false,
                    mediaUploadFailed: false,
                    timeLetterDraftEdited: false,
                    timeLetterDraftDeleted: false,
                    timeLetterDraftSealed: false,
                    mediaDetailEmptyStateVisible: false,
                    mediaDetailFailedStateVisible: false,
                    mediaDetailRetryActionVisible: false,
                    timeLetterDraftActionsVisible: false,
                    timeLetterSealedStateVisible: false,
                    releaseHiddenEntryPointsBlocked: false,
                    failureReason: "missingRootTab"
                )
                print("[UI_QA] ArchiveHiddenShellSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveHiddenShellSmoke(retryCount: retryCount + 1)
            }
            return
        }

        do {
            UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")
            let releaseOptionTitles = archiveCreationOptionTitles(isHiddenBranchesEnabled: false)
            let hiddenOptionTitles = archiveCreationOptionTitles(isHiddenBranchesEnabled: true)
            let releaseOptionsHidden = !releaseOptionTitles.contains("录入语音")
                && !releaseOptionTitles.contains("录入视频片段")
                && !releaseOptionTitles.contains("录入时间信件")
            let releaseHiddenEntryPointsBlocked = releaseOptionsHidden
                && !releaseOptionTitles.contains("生成测试视频档案")
            let hiddenOptionsVisible = hiddenOptionTitles.contains("录入语音")
                && hiddenOptionTitles.contains("录入视频片段")
                && hiddenOptionTitles.contains("录入时间信件")

            let emptyAudioItem = MemoryArchiveItem(
                kind: .audio,
                title: "语音档案",
                note: "缺少本地音频文件的 UIQA 空态。",
                ownerUserId: "user_9999",
                analysisStatus: .manual,
                analysisSummary: "仅保留说明，等待补回本地音频文件。",
                tags: ["语音档案"],
                metadata: [
                    "source": "manual_audio",
                    "contentKind": "audio",
                    MemoryArchiveItem.mediaUploadStatusMetadataKey: ArchiveMediaUploadStatus.localOnly.rawValue,
                    MemoryArchiveItem.mediaTranscriptionStatusMetadataKey: ArchiveMediaTranscriptionStatus.notRequested.rawValue,
                ]
            )
            let audioURL = try makeUIQAArchiveAudioFile()
            var audioItem = MemoryArchiveItemFactory.makeAudioItem(
                localPath: audioURL.path,
                duration: 1.2,
                note: "UIQA 隐藏分支录入的一段语音档案",
                transcriptText: "这是一段用于验证转写字段的 mock 文本"
            )
            let audioTranscriptionFailedItem = MemoryArchiveItemFactory.makeAudioItem(
                localPath: audioURL.path,
                duration: 1.2,
                note: "这段语音用于验证转写失败后的回响说明兜底。",
                transcriptionStatus: .failed,
                analysisStatus: .retryable,
                uploadStatus: .uploaded
            )
            let videoURL = try makeUIQAArchiveMockVideoFile()
            let thumbnailURL = try makeUIQAArchiveMockThumbnailFile()
            let videoSize = (try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? NSNumber)?
                .int64Value ?? 0
            var videoItem = MemoryArchiveItemFactory.makeVideoItem(
                localPath: videoURL.path,
                thumbnailPath: thumbnailURL.path,
                fileSizeBytes: videoSize,
                note: "UIQA 隐藏分支生成的 mock 视频档案"
            )
            let videoPlaceholderItem = MemoryArchiveItemFactory.makeVideoItem(
                localPath: videoURL.path,
                fileSizeBytes: videoSize,
                note: "UIQA 隐藏分支生成的无缩略图 mock 视频档案",
                analysisStatus: .failed,
                uploadStatus: .failed
            ).markingMediaUploadFailed("mock upload rejected")
            var draftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(note: "写给未来的一封草稿")
            let emptyDraftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(note: "")
            let deletedDraftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(note: "这封草稿会被删除")
            var sealedDraftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(note: "这封草稿会被封存")
            let sealedLetter = MemoryArchiveItemFactory.makeTimeLetter(note: "写给未来的一封封存信")

            for item in [audioItem, videoItem, draftLetter, deletedDraftLetter, sealedDraftLetter, sealedLetter] {
                MemoryArchiveRepository.shared.add(item, syncToBackend: false)
            }

            let expiresAt = ISO8601DateFormatter().string(
                from: Date().addingTimeInterval(TimeInterval(MemoryArchiveMediaReleaseReadiness.uploadIntentTTLSeconds))
            )
            let audioIntent = ArchiveMediaUploadIntent(json: [
                "uploadIntentId": "uiqa_audio_upload_intent",
                "archiveItemId": audioItem.id,
                "kind": MemoryArchiveItemKind.audio.rawValue,
                "storageProvider": "mockObjectStorage",
                "providerDisplayName": "Mock Object Storage",
                "providerMode": "mock",
                "requiresClientUpload": false,
                "uploadURLScheme": "mock",
                "realProviderReady": false,
                "providerSwitchContractVersion": 1,
                "clientUploadAction": "metadataOnly",
                "objectKey": "archive/audio/\(audioItem.id)/uiqa.m4a",
                "uploadURL": "mock://archive-media/audio/\(audioItem.id)",
                "expiresAt": expiresAt,
                "expiresInSeconds": MemoryArchiveMediaReleaseReadiness.uploadIntentTTLSeconds,
                "maxFileSizeBytes": MemoryArchiveMediaReleaseReadiness.audioFileSizeLimitMB * 1024 * 1024,
                "requiredHeaders": ["Content-Type": "audio/mp4"],
                "personaScope": "personal",
                "digitalHumanId": "user_9999",
            ])!
            audioItem = audioItem
                .markingMediaUploadPending()
                .markingMediaUploadUploaded(intent: audioIntent)
            videoItem = videoItem
                .markingMediaUploadPending()
                .markingMediaUploadFailed("mock upload rejected")
            draftLetter = draftLetter.updatingTimeLetterDraft(note: "写给未来的一封已编辑草稿")
            sealedDraftLetter = sealedDraftLetter.sealingTimeLetterDraft()

            _ = MemoryArchiveRepository.shared.update(audioItem, syncToBackend: false)
            _ = MemoryArchiveRepository.shared.update(videoItem, syncToBackend: false)
            _ = MemoryArchiveRepository.shared.update(draftLetter, syncToBackend: false)
            _ = MemoryArchiveRepository.shared.update(sealedDraftLetter, syncToBackend: false)
            let didRemoveDeletedDraft = MemoryArchiveRepository.shared.remove(id: deletedDraftLetter.id)

            let restoredItems = MemoryArchiveRepository.shared.allItems()
            let restoredAudio = restoredItems.first { $0.id == audioItem.id }
            let restoredVideo = restoredItems.first { $0.id == videoItem.id }
            let restoredDraft = restoredItems.first { $0.id == draftLetter.id }
            let restoredDeletedDraft = restoredItems.first { $0.id == deletedDraftLetter.id }
            let restoredSealedDraft = restoredItems.first { $0.id == sealedDraftLetter.id }
            let restoredSealed = restoredItems.first { $0.id == sealedLetter.id }
            let audioTranscriptPersisted = restoredAudio?.metadata[MemoryArchiveItem.mediaTranscriptTextMetadataKey] == "这是一段用于验证转写字段的 mock 文本"
            let audioUploadStatusPersisted = restoredAudio?.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] == ArchiveMediaUploadStatus.uploaded.rawValue
            let videoThumbnailPersisted = restoredVideo?.metadata[MemoryArchiveItem.mediaThumbnailPathMetadataKey] == thumbnailURL.path
            let videoUploadStatusPersisted = restoredVideo?.metadata[MemoryArchiveItem.mediaUploadStatusMetadataKey] == ArchiveMediaUploadStatus.failed.rawValue
            let videoAnalysisPending = restoredVideo?.analysisStatus == .pending
            let mediaUploadUploaded = restoredAudio?.metadata[MemoryArchiveItem.mediaObjectKeyMetadataKey] == audioIntent.objectKey
                && restoredAudio?.metadata[MemoryArchiveItem.mediaUploadIntentIdMetadataKey] == audioIntent.uploadIntentId
            let mediaUploadFailed = restoredVideo?.metadata[MemoryArchiveItem.mediaUploadErrorMetadataKey] == "mock upload rejected"
            let timeLetterDraftRestored = restoredDraft?.metadata["deliveryState"] == "draft"
                && restoredDraft?.metadata["timeLetterStatus"] == "draft"
            let timeLetterDraftEdited = restoredDraft?.note == "写给未来的一封已编辑草稿"
                && restoredDraft?.metadata["characterCount"] == "\(restoredDraft?.note.count ?? 0)"
            let timeLetterDraftSealed = restoredSealedDraft?.metadata["deliveryState"] == "sealed"
                && restoredSealedDraft?.metadata["timeLetterStatus"] == "sealed"
            let timeLetterDraftDeleted = didRemoveDeletedDraft && restoredDeletedDraft == nil
            let timeLetterSealedRestored = restoredSealed?.metadata["deliveryState"] == "sealed"
                && restoredSealed?.metadata["deliveryPolicy"] == "pending_product_decision"
            let timeLetterDraftDeliveryPolicyPersisted = restoredDraft?.isTimeLetterDeliveryDisabledUntilProductDecision == true
            let timeLetterSealedDeliveryPolicyPersisted = restoredSealedDraft?.isTimeLetterDeliveryDisabledUntilProductDecision == true
                && restoredSealed?.isTimeLetterDeliveryDisabledUntilProductDecision == true
            let timeLetterBackendPayload = sealedDraftLetter.archiveBackendPayload(
                userId: "user_9999",
                viewerUserId: "user_9999",
                ownerId: "user_9999",
                personaScope: "personal",
                digitalHumanId: "user_9999"
            )
            let timeLetterBackendPayloadNonDelivering =
                (timeLetterBackendPayload["deliveryExecutionState"] as? String) == "not_delivering"
                && (timeLetterBackendPayload["deliveryDecisionState"] as? String) == "waiting_product_decision"
                && (timeLetterBackendPayload["deliveryScheduleState"] as? String) == "not_scheduled"
                && (timeLetterBackendPayload["deliveryProviderState"] as? String) == "disabled_until_product_decision"
                && (timeLetterBackendPayload["deliveryNotificationScheduled"] as? Bool) == false
            let mediaDetailEmptyStateVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-empty-state",
                item: emptyAudioItem
            )
            let mediaDetailFailedStateVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-failed-state",
                item: videoItem
            ) && archiveDetailViewContainsText("上传失败，可重新同步", item: videoItem)
            let mediaDetailRetryActionVisible = archiveDetailViewContainsIdentifier(
                "archive-media-upload-intent-button",
                item: videoItem
            ) && archiveDetailViewContainsText("重新上传", item: videoItem)
                && archiveDetailViewContainsIdentifier("archive-hidden-media-retry-copy", item: videoItem)
            let audioDetailEmptyStateVisible = mediaDetailEmptyStateVisible
                && archiveDetailViewContainsText("媒体文件待补充", item: emptyAudioItem)
            let audioDetailTranscriptionFailedStateVisible = archiveDetailViewContainsIdentifier(
                "archive-audio-transcription-state",
                item: audioTranscriptionFailedItem
            ) && archiveDetailViewContainsText("转写失败，可重试", item: audioTranscriptionFailedItem)
            let audioDetailTranscriptionRetryVisible = archiveDetailViewContainsIdentifier(
                "archive-audio-transcription-retry-copy",
                item: audioTranscriptionFailedItem
            )
            let videoDetailThumbnailPlaceholderVisible = archiveDetailViewContainsIdentifier(
                "archive-video-media-placeholder",
                item: videoPlaceholderItem
            )
            let videoDetailFailedStateVisible = mediaDetailFailedStateVisible
                && archiveDetailViewContainsIdentifier("archive-video-analysis-state", item: videoItem)
            let videoDetailRetryActionVisible = mediaDetailRetryActionVisible
            let hiddenMediaRuntimeCardVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-runtime-card",
                item: videoItem
            )
            let hiddenMediaRuntimeProviderVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-runtime-provider",
                item: videoItem
            ) && archiveDetailViewContainsText("mockObjectStorage", item: videoItem)
            let hiddenMediaRuntimeLimitVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-runtime-limit",
                item: videoItem
            ) && archiveDetailViewContainsText("视频上限 200MB", item: videoItem)
            let hiddenMediaRuntimeUploadModeVisible = archiveDetailViewContainsIdentifier(
                "archive-hidden-media-runtime-upload-mode",
                item: videoItem
            )
            let hiddenMediaRuntimeMockCopyVisible = archiveDetailViewContainsText(
                "Mock 模式，仅同步媒体元数据",
                item: videoItem
            ) && archiveDetailViewContainsText("暂不执行真实文件 PUT", item: videoItem)
            let timeLetterDraftActionsVisible = archiveDetailViewContainsIdentifier(
                "archive-time-letter-draft-state",
                item: draftLetter
            ) && archiveDetailViewContainsIdentifier("archive-time-letter-edit-draft", item: draftLetter)
                && archiveDetailViewContainsIdentifier("archive-time-letter-seal-draft", item: draftLetter)
                && archiveDetailViewContainsIdentifier("archive-time-letter-delete-draft", item: draftLetter)
            let timeLetterDraftDetailVisible = timeLetterDraftActionsVisible
                && archiveDetailViewContainsText("草稿未封存", item: draftLetter)
            let timeLetterSealedStateVisible = archiveDetailViewContainsIdentifier(
                "archive-time-letter-sealed-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsText("投递策略待产品决策", item: sealedDraftLetter)
            let timeLetterSealedDetailVisible = timeLetterSealedStateVisible
            let timeLetterDeliveryPolicyVisible = archiveDetailViewContainsIdentifier(
                "archive-time-letter-delivery-disabled-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsIdentifier(
                "archive-time-letter-product-decision-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsIdentifier(
                "archive-time-letter-notification-not-scheduled-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsText("暂不投递", item: sealedDraftLetter)
                && archiveDetailViewContainsText("等待产品决策", item: sealedDraftLetter)
                && archiveDetailViewContainsText("不会调度本地通知或 APNs", item: sealedDraftLetter)
            let timeLetterEmptyBodyVisible = archiveDetailViewContainsIdentifier(
                "archive-time-letter-empty-body",
                item: emptyDraftLetter
            )
            let detailSnapshots = writeArchiveHiddenShellDetailSnapshots(
                audioEmptyItem: emptyAudioItem,
                audioTranscriptionFailedItem: audioTranscriptionFailedItem,
                videoFailedItem: videoPlaceholderItem,
                timeLetterDraftItem: draftLetter,
                timeLetterSealedItem: sealedDraftLetter
            )
            let audioEmptyDetailSnapshotWritten = detailSnapshots["audioEmptyDetailSnapshotWritten"] == true
            let audioTranscriptionFailedDetailSnapshotWritten = detailSnapshots["audioTranscriptionFailedDetailSnapshotWritten"] == true
            let videoFailedDetailSnapshotWritten = detailSnapshots["videoFailedDetailSnapshotWritten"] == true
            let timeLetterDraftDetailSnapshotWritten = detailSnapshots["timeLetterDraftDetailSnapshotWritten"] == true
            let timeLetterSealedDetailSnapshotWritten = detailSnapshots["timeLetterSealedDetailSnapshotWritten"] == true

            let completed = releaseOptionsHidden
                && releaseHiddenEntryPointsBlocked
                && hiddenOptionsVisible
                && restoredAudio != nil
                && restoredVideo != nil
                && timeLetterDraftRestored
                && timeLetterSealedRestored
                && audioTranscriptPersisted
                && audioUploadStatusPersisted
                && videoThumbnailPersisted
                && videoUploadStatusPersisted
                && videoAnalysisPending
                && mediaUploadUploaded
                && mediaUploadFailed
                && timeLetterDraftEdited
                && timeLetterDraftDeleted
                && timeLetterDraftSealed
                && timeLetterDraftDeliveryPolicyPersisted
                && timeLetterSealedDeliveryPolicyPersisted
                && timeLetterBackendPayloadNonDelivering
                && mediaDetailEmptyStateVisible
                && mediaDetailFailedStateVisible
                && mediaDetailRetryActionVisible
                && audioDetailEmptyStateVisible
                && audioDetailTranscriptionFailedStateVisible
                && audioDetailTranscriptionRetryVisible
                && videoDetailThumbnailPlaceholderVisible
                && videoDetailFailedStateVisible
                && videoDetailRetryActionVisible
                && hiddenMediaRuntimeCardVisible
                && hiddenMediaRuntimeProviderVisible
                && hiddenMediaRuntimeLimitVisible
                && hiddenMediaRuntimeUploadModeVisible
                && hiddenMediaRuntimeMockCopyVisible
                && timeLetterDraftActionsVisible
                && timeLetterSealedStateVisible
                && timeLetterDraftDetailVisible
                && timeLetterSealedDetailVisible
                && timeLetterDeliveryPolicyVisible
                && timeLetterEmptyBodyVisible
                && audioEmptyDetailSnapshotWritten
                && audioTranscriptionFailedDetailSnapshotWritten
                && videoFailedDetailSnapshotWritten
                && timeLetterDraftDetailSnapshotWritten
                && timeLetterSealedDetailSnapshotWritten

            tabBarController.selectedIndex = 0
            writeArchiveHiddenShellSmokeResult(
                completed: completed,
                releaseOptionsHidden: releaseOptionsHidden,
                hiddenOptionsVisible: hiddenOptionsVisible,
                audioRestored: restoredAudio != nil,
                videoRestored: restoredVideo != nil,
                timeLetterDraftRestored: timeLetterDraftRestored,
                timeLetterSealedRestored: timeLetterSealedRestored,
                audioTranscriptPersisted: audioTranscriptPersisted,
                audioUploadStatusPersisted: audioUploadStatusPersisted,
                videoThumbnailPersisted: videoThumbnailPersisted,
                videoUploadStatusPersisted: videoUploadStatusPersisted,
                videoAnalysisPending: videoAnalysisPending,
                mediaUploadUploaded: mediaUploadUploaded,
                mediaUploadFailed: mediaUploadFailed,
                timeLetterDraftEdited: timeLetterDraftEdited,
                timeLetterDraftDeleted: timeLetterDraftDeleted,
                timeLetterDraftSealed: timeLetterDraftSealed,
                timeLetterDraftDeliveryPolicyPersisted: timeLetterDraftDeliveryPolicyPersisted,
                timeLetterSealedDeliveryPolicyPersisted: timeLetterSealedDeliveryPolicyPersisted,
                timeLetterBackendPayloadNonDelivering: timeLetterBackendPayloadNonDelivering,
                mediaDetailEmptyStateVisible: mediaDetailEmptyStateVisible,
                mediaDetailFailedStateVisible: mediaDetailFailedStateVisible,
                mediaDetailRetryActionVisible: mediaDetailRetryActionVisible,
                audioDetailEmptyStateVisible: audioDetailEmptyStateVisible,
                audioDetailTranscriptionFailedStateVisible: audioDetailTranscriptionFailedStateVisible,
                audioDetailTranscriptionRetryVisible: audioDetailTranscriptionRetryVisible,
                videoDetailThumbnailPlaceholderVisible: videoDetailThumbnailPlaceholderVisible,
                videoDetailFailedStateVisible: videoDetailFailedStateVisible,
                videoDetailRetryActionVisible: videoDetailRetryActionVisible,
                hiddenMediaRuntimeCardVisible: hiddenMediaRuntimeCardVisible,
                hiddenMediaRuntimeProviderVisible: hiddenMediaRuntimeProviderVisible,
                hiddenMediaRuntimeLimitVisible: hiddenMediaRuntimeLimitVisible,
                hiddenMediaRuntimeUploadModeVisible: hiddenMediaRuntimeUploadModeVisible,
                hiddenMediaRuntimeMockCopyVisible: hiddenMediaRuntimeMockCopyVisible,
                timeLetterDraftActionsVisible: timeLetterDraftActionsVisible,
                timeLetterSealedStateVisible: timeLetterSealedStateVisible,
                timeLetterDraftDetailVisible: timeLetterDraftDetailVisible,
                timeLetterSealedDetailVisible: timeLetterSealedDetailVisible,
                timeLetterDeliveryPolicyVisible: timeLetterDeliveryPolicyVisible,
                timeLetterEmptyBodyVisible: timeLetterEmptyBodyVisible,
                audioEmptyDetailSnapshotWritten: audioEmptyDetailSnapshotWritten,
                audioTranscriptionFailedDetailSnapshotWritten: audioTranscriptionFailedDetailSnapshotWritten,
                videoFailedDetailSnapshotWritten: videoFailedDetailSnapshotWritten,
                timeLetterDraftDetailSnapshotWritten: timeLetterDraftDetailSnapshotWritten,
                timeLetterSealedDetailSnapshotWritten: timeLetterSealedDetailSnapshotWritten,
                releaseHiddenEntryPointsBlocked: releaseHiddenEntryPointsBlocked,
                failureReason: nil
            )
            print(
                "[UI_QA] ArchiveHiddenShellSmoke completed " +
                "hiddenOptionsVisible=\(hiddenOptionsVisible) " +
                "audioRestored=\(restoredAudio != nil) " +
                "videoRestored=\(restoredVideo != nil) " +
                "timeLetterDraftRestored=\(timeLetterDraftRestored) " +
                "timeLetterSealedRestored=\(timeLetterSealedRestored) " +
                "mediaUploadUploaded=\(mediaUploadUploaded) " +
                "mediaUploadFailed=\(mediaUploadFailed) " +
                "mediaDetailFailedStateVisible=\(mediaDetailFailedStateVisible) " +
                "videoDetailThumbnailPlaceholderVisible=\(videoDetailThumbnailPlaceholderVisible)"
            )
        } catch {
            writeArchiveHiddenShellSmokeResult(
                completed: false,
                releaseOptionsHidden: false,
                hiddenOptionsVisible: false,
                audioRestored: false,
                videoRestored: false,
                timeLetterDraftRestored: false,
                timeLetterSealedRestored: false,
                audioTranscriptPersisted: false,
                audioUploadStatusPersisted: false,
                videoThumbnailPersisted: false,
                videoUploadStatusPersisted: false,
                videoAnalysisPending: false,
                mediaUploadUploaded: false,
                mediaUploadFailed: false,
                timeLetterDraftEdited: false,
                timeLetterDraftDeleted: false,
                timeLetterDraftSealed: false,
                mediaDetailEmptyStateVisible: false,
                mediaDetailFailedStateVisible: false,
                mediaDetailRetryActionVisible: false,
                timeLetterDraftActionsVisible: false,
                timeLetterSealedStateVisible: false,
                releaseHiddenEntryPointsBlocked: false,
                failureReason: error.localizedDescription
            )
            print("[UI_QA] ArchiveHiddenShellSmoke failed reason=\(error.localizedDescription)")
        }
    }

    func archiveDetailViewContainsIdentifier(_ identifier: String, item: MemoryArchiveItem) -> Bool {
        let detailViewController = MemoryArchiveDetailViewController(item: item)
        detailViewController.loadViewIfNeeded()
        guard let view = detailViewController.viewIfLoaded else {
            return false
        }
        return viewTreeContainsIdentifier(identifier, in: view)
    }

    func archiveDetailViewContainsText(_ text: String, item: MemoryArchiveItem) -> Bool {
        let detailViewController = MemoryArchiveDetailViewController(item: item)
        detailViewController.loadViewIfNeeded()
        guard let view = detailViewController.viewIfLoaded else {
            return false
        }
        return viewTreeContainsText(text, in: view)
    }

    func viewTreeContainsIdentifier(_ identifier: String, in view: UIView) -> Bool {
        if view.accessibilityIdentifier == identifier {
            return true
        }
        return view.subviews.contains { viewTreeContainsIdentifier(identifier, in: $0) }
    }

    func viewTreeContainsText(_ text: String, in view: UIView) -> Bool {
        if let label = view as? UILabel,
           label.text?.contains(text) == true {
            return true
        }
        if let button = view as? UIButton,
           button.title(for: .normal)?.contains(text) == true {
            return true
        }
        if view.accessibilityLabel?.contains(text) == true {
            return true
        }
        return view.subviews.contains { viewTreeContainsText(text, in: $0) }
    }

    func writeArchiveHiddenShellDetailSnapshots(
        audioEmptyItem: MemoryArchiveItem,
        audioTranscriptionFailedItem: MemoryArchiveItem,
        videoFailedItem: MemoryArchiveItem,
        timeLetterDraftItem: MemoryArchiveItem,
        timeLetterSealedItem: MemoryArchiveItem
    ) -> [String: Bool] {
        [
            "audioEmptyDetailSnapshotWritten": renderArchiveDetailSnapshot(
                fileName: "archive-hidden-audio-empty-detail.png",
                item: audioEmptyItem
            ),
            "audioTranscriptionFailedDetailSnapshotWritten": renderArchiveDetailSnapshot(
                fileName: "archive-hidden-audio-transcription-failed-detail.png",
                item: audioTranscriptionFailedItem
            ),
            "videoFailedDetailSnapshotWritten": renderArchiveDetailSnapshot(
                fileName: "archive-hidden-video-failed-detail.png",
                item: videoFailedItem
            ),
            "timeLetterDraftDetailSnapshotWritten": renderArchiveDetailSnapshot(
                fileName: "archive-hidden-time-letter-draft-detail.png",
                item: timeLetterDraftItem
            ),
            "timeLetterSealedDetailSnapshotWritten": renderArchiveDetailSnapshot(
                fileName: "archive-hidden-time-letter-sealed-detail.png",
                item: timeLetterSealedItem
            ),
        ]
    }

    func renderArchiveDetailSnapshot(fileName: String, item: MemoryArchiveItem) -> Bool {
        let detailViewController = MemoryArchiveDetailViewController(item: item)
        detailViewController.loadViewIfNeeded()
        guard let view = detailViewController.viewIfLoaded,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData() else {
            return false
        }

        let outputURL = documentsURL.appendingPathComponent(fileName)
        do {
            try data.write(to: outputURL, options: [.atomic])
            return true
        } catch {
            print("[UI_QA] ArchiveHiddenShellSmoke snapshotWrite failed file=\(fileName) error=\(error.localizedDescription)")
            return false
        }
    }

    func makeUIQAArchiveAudioFile() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("uiqa-audio-lifecycle.m4a")
        try? FileManager.default.removeItem(at: fileURL)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let file = try AVAudioFile(forWriting: fileURL, settings: settings)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100) else {
            throw NSError(
                domain: "DreamJourney.UIQA.AudioLifecycle",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create audio buffer"]
            )
        }
        buffer.frameLength = 44_100
        if let channel = buffer.floatChannelData?.pointee {
            for frame in 0..<Int(buffer.frameLength) {
                channel[frame] = frame % 200 < 100 ? 0.10 : -0.10
            }
        }
        try file.write(from: buffer)
        return fileURL
    }

    func makeUIQAArchiveMockVideoFile() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-video", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("uiqa-hidden-shell-video.mov")
        try? FileManager.default.removeItem(at: fileURL)
        let data = Data("DreamJourney hidden shell mock video placeholder".utf8)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func makeUIQAArchiveMockThumbnailFile() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-video-thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("uiqa-hidden-shell-video.jpg")
        try? FileManager.default.removeItem(at: fileURL)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 96)).image { context in
            DJDesignTokens.Color.surfaceContainer.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 96))
            DJDesignTokens.Color.accentDeep.setFill()
            context.fill(CGRect(x: 56, y: 28, width: 48, height: 40))
        }
        guard let data = image.jpegData(compressionQuality: 0.72) else {
            throw NSError(
                domain: "DreamJourney.UIQA.ArchiveHiddenShell",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode mock video thumbnail"]
            )
        }
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func makeUIQAArchiveFailedAnalysisImageFile() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-images", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("uiqa-failed-analysis-retry.jpg")

        let fallbackImage = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            DJDesignTokens.Color.surfaceContainer.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            DJDesignTokens.Color.accentDeep.setFill()
            context.fill(CGRect(x: 12, y: 12, width: 40, height: 40))
        }
        let image = UIImage(named: "default_memory_1") ?? fallbackImage
        guard let data = image.jpegData(compressionQuality: 0.72) else {
            throw NSError(
                domain: "DreamJourney.UIQA.ArchiveFailedAnalysisRetry",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode UIQA image"]
            )
        }
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
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

    func seedArchiveMediaEchoContext() {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        let audioItem = MemoryArchiveItemFactory.makeAudioItem(
            localPath: "/tmp/uiqa-media-context-audio.m4a",
            duration: 9,
            note: "这段语音说明不应覆盖已转写文本",
            transcriptText: "妈妈在厨房讲起桂花糕的声音"
        )

        var videoItem = MemoryArchiveItemFactory.makeVideoItem(
            localPath: "/tmp/uiqa-media-context-video.mov",
            note: "视频里记录了院子里的桂花树",
            analysisStatus: .pending
        )
        videoItem.detectedPeople = ["不应注入视频人物"]
        videoItem.tags = ["不应注入视频标签"]
        videoItem.metadata[MemoryArchiveItem.analysisLocationCluesMetadataKey] = "不应注入视频地点"
        videoItem.metadata[MemoryArchiveItem.analysisSceneCluesMetadataKey] = "不应注入视频场景"

        let draftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(note: "这封草稿不应进入回响上下文")
        var sealedLetter = MemoryArchiveItemFactory.makeTimeLetter(note: "这封封存信可以进入回响上下文")
        sealedLetter.analysisSummary = "封存信内容：这封封存信可以进入回响上下文"

        MemoryArchiveRepository.shared.add(audioItem, syncToBackend: false)
        MemoryArchiveRepository.shared.add(videoItem, syncToBackend: false)
        MemoryArchiveRepository.shared.add(draftLetter, syncToBackend: false)
        MemoryArchiveRepository.shared.add(sealedLetter, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 10)
        print("[UI_QA] Seeded archive media echo context available=\(snapshot.availableItemCount)")
    }

    func seedArchiveAnalysisInsightsContext() {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        var analyzedItem = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/uiqa-analysis-insights-photo.jpg")
        analyzedItem.title = "外滩家庭合影"
        analyzedItem.note = "奶奶和爸爸在上海外滩散步，翻看老照片时聊起春节聚会。"
        analyzedItem.applyLocalAnalysisResult(now: Date(timeIntervalSince1970: 1_800_000_010))
        print(
            "[UI_QA] Seeded archive insights locations=\(analyzedItem.detectedLocationClues.joined(separator: "|")) " +
            "scenes=\(analyzedItem.detectedSceneClues.joined(separator: "|"))"
        )

        var failedItem = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/uiqa-analysis-failed-photo.jpg")
        failedItem.title = "等待重试的照片"
        failedItem.note = "这张照片用于验证分析失败/重试状态。"
        failedItem.markAnalysisFailed(reason: "mock analysis timeout", now: Date(timeIntervalSince1970: 1_800_000_011))

        MemoryArchiveRepository.shared.add(analyzedItem, syncToBackend: false)
        MemoryArchiveRepository.shared.add(failedItem, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        print("[UI_QA] Seeded archive analysis insights available=\(snapshot.availableItemCount)")
    }

    func seedFailedArchiveAnalysisRetryContext() {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        do {
            let imageURL = try makeUIQAArchiveFailedAnalysisImageFile()
            var failedItem = MemoryArchiveItemFactory.makePhotoItem(localPath: imageURL.path)
            failedItem = failedItem.updatingBackendSyncState(
                .synced,
                attemptedAt: Date(timeIntervalSince1970: 1_800_000_012)
            )
            failedItem.markAnalysisFailed(
                reason: "provider_unavailable",
                now: Date(timeIntervalSince1970: 1_800_000_013)
            )
            MemoryArchiveRepository.shared.add(failedItem, syncToBackend: false)
            print("[UI_QA] Seeded failed archive analysis retry item id=\(failedItem.id)")
        } catch {
            print("[UI_QA] ArchiveFailedAnalysisRetrySmoke failed reason=seedImage error=\(error.localizedDescription)")
        }
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

    func runArchiveMediaEchoContextSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] ArchiveMediaEchoContextSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveMediaEchoContextSmoke(retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            print("[UI_QA] ArchiveMediaEchoContextSmoke failed reason=missingSmokeDependencies")
            return
        }

        tabBarController.selectedIndex = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            echoViewController.runUIQAMicrophoneSmoke()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot(limit: 10)
                let prompt = DialogPromptDebugRecorder.lastSnapshot?.prompt ?? ""
                let entries = archiveSnapshot.debugSummary()
                let result: [String: Any] = [
                    "completed": true,
                    "containsArchiveContext": prompt.contains("【记忆档案馆素材线索】"),
                    "availableItemCount": archiveSnapshot.availableItemCount,
                    "entries": entries,
                    "audioTranscriptInjected": prompt.contains("妈妈在厨房讲起桂花糕的声音"),
                    "audioNoteFallbackExcludedWhenTranscriptExists": !prompt.contains("这段语音说明不应覆盖已转写文本"),
                    "audioLocalPathExcluded": !prompt.contains("/tmp/uiqa-media-context-audio.m4a"),
                    "videoPendingNoteInjected": prompt.contains("视频里记录了院子里的桂花树"),
                    "videoPendingCluesExcluded": !prompt.contains("不应注入视频人物")
                        && !prompt.contains("不应注入视频标签")
                        && !prompt.contains("不应注入视频地点")
                        && !prompt.contains("不应注入视频场景"),
                    "videoLocalPathExcluded": !prompt.contains("/tmp/uiqa-media-context-video.mov"),
                    "timeLetterDraftExcluded": !prompt.contains("这封草稿不应进入回响上下文"),
                    "timeLetterSealedIncluded": prompt.contains("封存信内容：这封封存信可以进入回响上下文"),
                ]
                self.writeArchiveMediaEchoContextSmokeResult(result)
                print(
                    "[UI_QA] ArchiveMediaEchoContextSmoke completed " +
                    "available=\(archiveSnapshot.availableItemCount) entries=\(entries)"
                )
            }
        }
    }

    func runArchiveFailedAnalysisRetrySmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] ArchiveFailedAnalysisRetrySmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveFailedAnalysisRetrySmoke(retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              let archiveNavigationController = viewControllers.first as? UINavigationController,
              let item = MemoryArchiveRepository.shared.allItems().first(where: { $0.analysisStatus == .failed }) else {
            print("[UI_QA] ArchiveFailedAnalysisRetrySmoke failed reason=missingFailedArchiveItem")
            return
        }

        tabBarController.selectedIndex = 0
        let detailViewController = MemoryArchiveDetailViewController(item: item)
        archiveNavigationController.pushViewController(detailViewController, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            detailViewController.runUIQAArchiveFailedAnalysisRetrySmoke { payload in
                guard let self else { return }
                let storedItem = MemoryArchiveRepository.shared.allItems().first(where: { $0.id == item.id })
                var result = payload
                result["storedFinalAnalysisStatus"] = storedItem?.analysisStatus.rawValue ?? "missing"
                result["storedAnalysisRetryable"] = storedItem?.analysisRetryableForBackend ?? false
                result["storedCloudStateText"] = storedItem?.archiveBackendSyncDisplayName ?? "missing"

                let initialStatus = result["initialAnalysisStatus"] as? String
                let finalStatus = result["finalAnalysisStatus"] as? String
                let retryButtonVisible = result["retryButtonVisible"] as? Bool == true
                let retryActionFired = result["retryActionFired"] as? Bool == true
                let backendConfigured = result["backendConfigured"] as? Bool == true
                let storedFinalStatus = result["storedFinalAnalysisStatus"] as? String
                let storedCloudStateText = result["storedCloudStateText"] as? String
                let retryable = result["analysisRetryable"] as? Bool == true
                let finalStatusIsAccepted = finalStatus == "failed" || finalStatus == "analyzed"
                let finalContractIsAccepted = finalStatus == "analyzed" || retryable
                let completed = retryButtonVisible
                    && retryActionFired
                    && backendConfigured
                    && initialStatus == "failed"
                    && finalStatusIsAccepted
                    && finalContractIsAccepted
                    && storedFinalStatus == finalStatus
                    && storedCloudStateText == "云端已同步"

                result["completed"] = completed
                self.writeArchiveFailedAnalysisRetrySmokeResult(result)
                print(
                    "[UI_QA] ArchiveFailedAnalysisRetrySmoke completed " +
                    "completed=\(completed) " +
                    "initial=\(initialStatus ?? "missing") " +
                    "final=\(finalStatus ?? "missing") " +
                    "backendConfigured=\(backendConfigured)"
                )
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
                    familyRefreshSucceeded: false,
                    backendFamilyMembers: [],
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

                FamilyRepository.shared.refreshFromBackend(userId: userId) { familyResult in
                    let familyRefreshSucceeded: Bool
                    let backendFamilyMembers: [FamilyMember]
                    let resolvedFailureReason: String?
                    switch familyResult {
                    case .success(let members):
                        familyRefreshSucceeded = true
                        backendFamilyMembers = members
                        resolvedFailureReason = failureReason
                    case .failure(let error):
                        familyRefreshSucceeded = false
                        backendFamilyMembers = []
                        resolvedFailureReason = failureReason ?? error.localizedDescription
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
                            familyRefreshSucceeded: familyRefreshSucceeded,
                            backendFamilyMembers: backendFamilyMembers,
                            failureReason: resolvedFailureReason
                        )
                        print(
                            "[UI_QA] BackendEnvSmoke completed " +
                            "archiveRefreshSucceeded=\(archiveRefreshSucceeded) " +
                            "careMoodStatus=\(careSnapshot?.moodStatus ?? "missing") " +
                            "familyRefreshSucceeded=\(familyRefreshSucceeded) " +
                            "backendFamilyMemberCount=\(backendFamilyMembers.count)"
                        )
                    }
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

    func writeArchiveMediaEchoContextSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveMediaEchoContextSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-media-echo-context-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveMediaEchoContextSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeArchiveFailedAnalysisRetrySmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveFailedAnalysisRetrySmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-failed-analysis-retry-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveFailedAnalysisRetrySmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeProfileCareEscalationBoundarySmokeResult(
        completed: Bool,
        payload: [String: Any],
        profileTabSelected: Bool
    ) {
        var result = payload
        result["completed"] = completed
        result["profileTabSelected"] = profileTabSelected

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ProfileCareEscalationBoundarySmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("profile-care-escalation-boundary-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ProfileCareEscalationBoundarySmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeProfileCareStateSmokeResult(
        completed: Bool,
        states: [[String: Any]],
        profileTabSelected: Bool,
        failureReason: String? = nil
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "profileTabSelected": profileTabSelected,
            "states": states,
            "expectedStates": [
                ProfileCareSnapshot.emptyFallback().dataState.accessibilityIdentifier,
                ProfileCareSnapshot.staleFallback().dataState.accessibilityIdentifier,
                ProfileCareSnapshot.failedFallback().dataState.accessibilityIdentifier,
            ],
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ProfileCareStateSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("profile-care-state-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ProfileCareStateSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeProfileCareBackendStateSmokeResult(
        completed: Bool,
        states: [[String: Any]],
        retry: [String: Any]? = nil,
        profileTabSelected: Bool,
        backendConfigured: Bool,
        failureReason: String? = nil
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "backendConfigured": backendConfigured,
            "profileTabSelected": profileTabSelected,
            "states": states,
            "expectedStates": [
                "active": ProfileCareDataState.available.accessibilityIdentifier,
                "empty": ProfileCareDataState.empty.accessibilityIdentifier,
                "stale": ProfileCareDataState.stale.accessibilityIdentifier,
            ],
            "failedStateCoveredByLocalSmoke": true,
        ]
        if let retry {
            result["retry"] = retry
        }
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("profile-care-backend-state-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeProfileCareBackendFailureRetrySmokeResult(
        completed: Bool,
        retry: [String: Any],
        profileTabSelected: Bool,
        backendConfigured: Bool,
        failureReason: String? = nil
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "backendConfigured": backendConfigured,
            "profileTabSelected": profileTabSelected,
            "retry": retry,
            "expectedFailureState": ProfileCareDataState.failed.accessibilityIdentifier,
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("profile-care-backend-failure-retry-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=resultWrite error=\(error.localizedDescription)")
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
        backendFamilyDigitalHumanMode: String,
        backendFamilyDigitalHumanModeLabel: String,
        backendFamilyPersonaContractVersion: Int,
        backendFamilyContractMode: String,
        backendFamilyDefaultReleaseVisible: Bool,
        backendFamilyRenderedInRepository: Bool,
        backendVoiceProfileId: String,
        backendVoiceSampleStatus: String,
        backendVoiceProviderMode: String,
        backendVoiceDefaultReleaseVisible: Bool,
        backendVoiceShellRendered: Bool,
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
            "backendFamilyDigitalHumanMode": backendFamilyDigitalHumanMode,
            "backendFamilyDigitalHumanModeLabel": backendFamilyDigitalHumanModeLabel,
            "backendFamilyPersonaContractVersion": backendFamilyPersonaContractVersion,
            "backendFamilyContractMode": backendFamilyContractMode,
            "backendFamilyDefaultReleaseVisible": backendFamilyDefaultReleaseVisible,
            "backendFamilyRenderedInRepository": backendFamilyRenderedInRepository,
            "backendVoiceProfileId": backendVoiceProfileId,
            "backendVoiceSampleStatus": backendVoiceSampleStatus,
            "backendVoiceProviderMode": backendVoiceProviderMode,
            "backendVoiceDefaultReleaseVisible": backendVoiceDefaultReleaseVisible,
            "backendVoiceShellRendered": backendVoiceShellRendered,
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
        releaseVideoVisible: Bool,
        hiddenVideoVisible: Bool,
        audioRequiresMicrophonePermission: Bool
    ) {
        let result: [String: Any] = [
            "completed": completed,
            "releaseOptionTitles": releaseOptionTitles,
            "hiddenOptionTitles": hiddenOptionTitles,
            "releaseVideoVisible": releaseVideoVisible,
            "hiddenVideoVisible": hiddenVideoVisible,
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

    func writeArchiveAudioLifecycleSmokeResult(
        completed: Bool,
        permissionDeniedRecoveryReady: Bool,
        releaseAudioCreationVisible: Bool,
        hiddenAudioCreationVisible: Bool,
        audioFileExists: Bool,
        restoredAudioItem: Bool,
        restoredAudioItemCount: Int,
        summaryAudioCount: Int,
        contextIncludesAudio: Bool,
        detailViewLoaded: Bool,
        detailPlaybackLoadable: Bool,
        failureReason: String?
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "permissionDeniedRecoveryReady": permissionDeniedRecoveryReady,
            "releaseAudioCreationVisible": releaseAudioCreationVisible,
            "hiddenAudioCreationVisible": hiddenAudioCreationVisible,
            "audioFileExists": audioFileExists,
            "restoredAudioItem": restoredAudioItem,
            "restoredAudioItemCount": restoredAudioItemCount,
            "summaryAudioCount": summaryAudioCount,
            "contextIncludesAudio": contextIncludesAudio,
            "detailViewLoaded": detailViewLoaded,
            "detailPlaybackLoadable": detailPlaybackLoadable,
            "hiddenBranchesArgument": MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveAudioLifecycleSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-audio-lifecycle-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveAudioLifecycleSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeArchiveHiddenShellSmokeResult(
        completed: Bool,
        releaseOptionsHidden: Bool,
        hiddenOptionsVisible: Bool,
        audioRestored: Bool,
        videoRestored: Bool,
        timeLetterDraftRestored: Bool,
        timeLetterSealedRestored: Bool,
        audioTranscriptPersisted: Bool,
        audioUploadStatusPersisted: Bool,
        videoThumbnailPersisted: Bool,
        videoUploadStatusPersisted: Bool,
        videoAnalysisPending: Bool,
        mediaUploadUploaded: Bool,
        mediaUploadFailed: Bool,
        timeLetterDraftEdited: Bool,
        timeLetterDraftDeleted: Bool,
        timeLetterDraftSealed: Bool,
        timeLetterDraftDeliveryPolicyPersisted: Bool = false,
        timeLetterSealedDeliveryPolicyPersisted: Bool = false,
        timeLetterBackendPayloadNonDelivering: Bool = false,
        mediaDetailEmptyStateVisible: Bool,
        mediaDetailFailedStateVisible: Bool,
        mediaDetailRetryActionVisible: Bool,
        audioDetailEmptyStateVisible: Bool = false,
        audioDetailTranscriptionFailedStateVisible: Bool = false,
        audioDetailTranscriptionRetryVisible: Bool = false,
        videoDetailThumbnailPlaceholderVisible: Bool = false,
        videoDetailFailedStateVisible: Bool = false,
        videoDetailRetryActionVisible: Bool = false,
        hiddenMediaRuntimeCardVisible: Bool = false,
        hiddenMediaRuntimeProviderVisible: Bool = false,
        hiddenMediaRuntimeLimitVisible: Bool = false,
        hiddenMediaRuntimeUploadModeVisible: Bool = false,
        hiddenMediaRuntimeMockCopyVisible: Bool = false,
        timeLetterDraftActionsVisible: Bool,
        timeLetterSealedStateVisible: Bool,
        timeLetterDraftDetailVisible: Bool = false,
        timeLetterSealedDetailVisible: Bool = false,
        timeLetterDeliveryPolicyVisible: Bool = false,
        timeLetterEmptyBodyVisible: Bool = false,
        audioEmptyDetailSnapshotWritten: Bool = false,
        audioTranscriptionFailedDetailSnapshotWritten: Bool = false,
        videoFailedDetailSnapshotWritten: Bool = false,
        timeLetterDraftDetailSnapshotWritten: Bool = false,
        timeLetterSealedDetailSnapshotWritten: Bool = false,
        releaseHiddenEntryPointsBlocked: Bool,
        failureReason: String?
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "releaseOptionsHidden": releaseOptionsHidden,
            "hiddenOptionsVisible": hiddenOptionsVisible,
            "audioRestored": audioRestored,
            "videoRestored": videoRestored,
            "timeLetterDraftRestored": timeLetterDraftRestored,
            "timeLetterSealedRestored": timeLetterSealedRestored,
            "audioTranscriptPersisted": audioTranscriptPersisted,
            "audioUploadStatusPersisted": audioUploadStatusPersisted,
            "videoThumbnailPersisted": videoThumbnailPersisted,
            "videoUploadStatusPersisted": videoUploadStatusPersisted,
            "videoAnalysisPending": videoAnalysisPending,
            "mediaUploadUploaded": mediaUploadUploaded,
            "mediaUploadFailed": mediaUploadFailed,
            "timeLetterDraftEdited": timeLetterDraftEdited,
            "timeLetterDraftDeleted": timeLetterDraftDeleted,
            "timeLetterDraftSealed": timeLetterDraftSealed,
            "timeLetterDraftDeliveryPolicyPersisted": timeLetterDraftDeliveryPolicyPersisted,
            "timeLetterSealedDeliveryPolicyPersisted": timeLetterSealedDeliveryPolicyPersisted,
            "timeLetterBackendPayloadNonDelivering": timeLetterBackendPayloadNonDelivering,
            "mediaDetailEmptyStateVisible": mediaDetailEmptyStateVisible,
            "mediaDetailFailedStateVisible": mediaDetailFailedStateVisible,
            "mediaDetailRetryActionVisible": mediaDetailRetryActionVisible,
            "audioDetailEmptyStateVisible": audioDetailEmptyStateVisible,
            "audioDetailTranscriptionFailedStateVisible": audioDetailTranscriptionFailedStateVisible,
            "audioDetailTranscriptionRetryVisible": audioDetailTranscriptionRetryVisible,
            "videoDetailThumbnailPlaceholderVisible": videoDetailThumbnailPlaceholderVisible,
            "videoDetailFailedStateVisible": videoDetailFailedStateVisible,
            "videoDetailRetryActionVisible": videoDetailRetryActionVisible,
            "hiddenMediaRuntimeCardVisible": hiddenMediaRuntimeCardVisible,
            "hiddenMediaRuntimeProviderVisible": hiddenMediaRuntimeProviderVisible,
            "hiddenMediaRuntimeLimitVisible": hiddenMediaRuntimeLimitVisible,
            "hiddenMediaRuntimeUploadModeVisible": hiddenMediaRuntimeUploadModeVisible,
            "hiddenMediaRuntimeMockCopyVisible": hiddenMediaRuntimeMockCopyVisible,
            "timeLetterDraftActionsVisible": timeLetterDraftActionsVisible,
            "timeLetterSealedStateVisible": timeLetterSealedStateVisible,
            "timeLetterDraftDetailVisible": timeLetterDraftDetailVisible,
            "timeLetterSealedDetailVisible": timeLetterSealedDetailVisible,
            "timeLetterDeliveryPolicyVisible": timeLetterDeliveryPolicyVisible,
            "timeLetterEmptyBodyVisible": timeLetterEmptyBodyVisible,
            "audioEmptyDetailSnapshotWritten": audioEmptyDetailSnapshotWritten,
            "audioTranscriptionFailedDetailSnapshotWritten": audioTranscriptionFailedDetailSnapshotWritten,
            "videoFailedDetailSnapshotWritten": videoFailedDetailSnapshotWritten,
            "timeLetterDraftDetailSnapshotWritten": timeLetterDraftDetailSnapshotWritten,
            "timeLetterSealedDetailSnapshotWritten": timeLetterSealedDetailSnapshotWritten,
            "releaseHiddenEntryPointsBlocked": releaseHiddenEntryPointsBlocked,
            "hiddenBranchesArgument": MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] ArchiveHiddenShellSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("archive-hidden-shell-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] ArchiveHiddenShellSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeEchoDelayedReplyNotificationSmokeResult(
        completed: Bool,
        delayMinutesInRange: Bool,
        storedDelayedReply: Bool,
        localNotificationContractPresent: Bool,
        restoredWaitingState: Bool,
        restoredWaitingMinutes: Int,
        restoredWaitingMinutesInRange: Bool,
        restoredDelayedReplyIdMatched: Bool,
        expiredDelayedReplyArrived: Bool,
        expiredDelayedReplyCleared: Bool,
        pendingNotificationScheduleSucceeded: Bool,
        pendingNotificationMatched: Bool,
        pendingNotificationIdentifierMatched: Bool,
        pendingNotificationTriggerMatched: Bool,
        pendingNotificationUserInfoMatched: Bool,
        pendingNotificationCount: Int,
        delayedReplyId: String,
        trigger: String
    ) {
        let result: [String: Any] = [
            "completed": completed,
            "delayMinutesInRange": delayMinutesInRange,
            "storedDelayedReply": storedDelayedReply,
            "localNotificationContractPresent": localNotificationContractPresent,
            "restoredWaitingState": restoredWaitingState,
            "restoredWaitingMinutes": restoredWaitingMinutes,
            "restoredWaitingMinutesInRange": restoredWaitingMinutesInRange,
            "restoredDelayedReplyIdMatched": restoredDelayedReplyIdMatched,
            "expiredDelayedReplyArrived": expiredDelayedReplyArrived,
            "expiredDelayedReplyCleared": expiredDelayedReplyCleared,
            "pendingNotificationScheduleSucceeded": pendingNotificationScheduleSucceeded,
            "pendingNotificationMatched": pendingNotificationMatched,
            "pendingNotificationIdentifierMatched": pendingNotificationIdentifierMatched,
            "pendingNotificationTriggerMatched": pendingNotificationTriggerMatched,
            "pendingNotificationUserInfoMatched": pendingNotificationUserInfoMatched,
            "pendingNotificationCount": pendingNotificationCount,
            "delayedReplyId": delayedReplyId,
            "trigger": trigger,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("echo-delayed-reply-notification-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeBackendEnvSmokeResult(
        archiveRefreshSucceeded: Bool,
        careSnapshot: ProfileCareSnapshot?,
        familyRefreshSucceeded: Bool,
        backendFamilyMembers: [FamilyMember],
        failureReason: String?
    ) {
        let archiveItems = MemoryArchiveRepository.shared.allItems()
        let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
        let archiveTitles = archiveItems.map(\.title)
        let familyMembers = FamilyRepository.shared.getAll()
        let familyMemberNames = familyMembers.map(\.name)
        let containsBackendFamilyMember = familyMemberNames.contains("Daughter")
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
            && familyRefreshSucceeded
            && containsBackendFamilyMember

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
            "familyRefreshSucceeded": familyRefreshSucceeded,
            "backendFamilyMemberCount": backendFamilyMembers.count,
            "familyMemberCount": familyMembers.count,
            "containsBackendFamilyMember": containsBackendFamilyMember,
            "familyMemberNames": familyMemberNames,
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
