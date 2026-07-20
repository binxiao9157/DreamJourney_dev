//
//  AppDelegate.swift
//  DreamJourney
//

import AVFoundation
import UIKit
import UserNotifications
#if !((UI_QA_SIMULATOR || RELEASE_SCOPE_SIMULATOR) && targetEnvironment(simulator))
import SpeechEngineToB
import AMapFoundationKit
import MAMapKit
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var releasePolicyRefreshGeneration: UInt64 = 0

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        TencentVirtualmanSDKBridge.registerFactory()
        configureLaunchArgumentFeatureFlagsIfNeeded()
        UserManager.shared.reconcilePrivateAccessSession()
        let currentKnowledgeUserId = UserManager.shared.canEnterPrivateUI
            ? UserManager.shared.currentUser?.id
            : nil
        KnowledgeSyncCoordinator.shared.userDidChange(to: currentKnowledgeUserId)
        KBLiteManager.shared.switchUser(to: currentKnowledgeUserId)

        // 火山引擎语音 SDK 环境准备
        #if !((UI_QA_SIMULATOR || RELEASE_SCOPE_SIMULATOR) && targetEnvironment(simulator))
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReleasePolicyAccountChange),
            name: .djUserDidLogin,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReleasePolicyAccountChange),
            name: .djUserDidLogout,
            object: nil
        )
        refreshReleasePolicy()
        configureNotificationRuntimeIngress(launchOptions: launchOptions)
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

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let result = enqueueNotificationRuntimeRoute(
            userInfo: userInfo,
            source: .remoteNotification
        )
        completionHandler(result.shouldNotifyRouter ? .newData : .noData)
    }

    private func configureNotificationRuntimeIngress(
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        UNUserNotificationCenter.current().delegate = self
        guard let userInfo = launchOptions?[.remoteNotification]
            as? [AnyHashable: Any] else {
            return
        }
        _ = enqueueNotificationRuntimeRoute(
            userInfo: userInfo,
            source: .remoteNotification
        )
    }

    @discardableResult
    private func enqueueNotificationRuntimeRoute(
        userInfo: [AnyHashable: Any],
        source: NotificationRuntimeRouteSource
    ) -> NotificationRuntimeRouteIngressResult {
        let result = NotificationRuntimeRouteInbox.shared.ingest(
            userInfo: userInfo,
            source: source
        )
        guard result.shouldNotifyRouter else { return result }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .djNotificationRuntimeRouteQueued,
                object: nil
            )
        }
        return result
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

    private func configureLaunchArgumentFeatureFlagsIfNeeded() {
        #if DEBUG || UI_QA_SIMULATOR
        let configuration = QALaunchConfiguration.shared
        if configuration.shouldEnableDigitalHumanLivePanel {
            FeatureFlagService.shared.enableForCurrentLaunch(.digitalHumanLivePanel)
            print("[QA] Digital human live panel enabled by launch argument")
        }
        #endif
    }

    @objc private func handleUserDidLoginForPushDeviceToken() {
        syncStoredPushDeviceTokenIfPossible()
    }

    @objc private func handleReleasePolicyAccountChange() {
        FeatureGateService.shared.invalidateCapturedRoutes()
        RuntimeCapabilitySnapshotStore.shared.invalidate()
        refreshReleasePolicy()
    }

    private func refreshReleasePolicy() {
        releasePolicyRefreshGeneration &+= 1
        let refreshGeneration = releasePolicyRefreshGeneration
        FeatureGateService.shared.refreshPolicy { [weak self] result in
            guard let self,
                  self.releasePolicyRefreshGeneration == refreshGeneration else {
                return
            }
            if case .failure(let error) = result {
                self.invalidateReleasePolicyAuthorityAfterRefreshFailure(error)
            }
        }
    }

    private func invalidateReleasePolicyAuthorityAfterRefreshFailure(_ error: Error) {
        DreamJourneyBackendClient.shared.invalidateCachedReleasePolicyAuthority(
            clientBuild: FeatureGateService.shared.clientBuild
        )
        FeatureGateService.shared.invalidateCapturedRoutes()
        RuntimeCapabilitySnapshotStore.shared.invalidate()
        print(
            "[ReleasePolicy] refresh failed; cached M1-M4 authority invalidated for fail-closed access: " +
            error.localizedDescription
        )
    }

    private func syncStoredPushDeviceTokenIfPossible() {
        guard DreamJourneyBackendClient.shared.isPushDeviceTokenRegistrationConfigured,
              let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId),
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed,
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
            guard AccountLeaseRuntime.shared.validate(accountLease, at: .commit).allowed else {
                return
            }
            switch result {
            case .success(let object):
                guard let item = object["item"] as? [String: Any],
                      let registration = PushDeviceTokenRegistration(json: item) else {
                    return
                }
                _ = PushDeviceTokenStore.shared.saveRegistration(
                    registration,
                    accountLease: accountLease
                )
            case .failure(let error):
                guard AccountLeaseRuntime.shared.validate(accountLease, at: .runtime).allowed else {
                    return
                }
                print("[PushDeviceToken] backend registration failed: \(error.localizedDescription)")
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard NotificationRuntimeRouteInbox.shared.canPresent(
            userInfo: notification.request.content.userInfo
        ) else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = enqueueNotificationRuntimeRoute(
            userInfo: response.notification.request.content.userInfo,
            source: .notificationResponse
        )
        completionHandler()
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
private extension AppDelegate {
    func configureUIQASmokeHarnessIfNeeded() {
        let launchPlan = QAScenarioRunner.makeLaunchPlan(
            from: QALaunchConfiguration.shared
        )
        if launchPlan.shouldEnableArchiveRemoteFetch {
            FeatureFlagService.shared.enableForCurrentLaunch(.archiveRemoteFetch)
            print("[UI_QA] Archive remote fetch enabled")
        }
        if launchPlan.shouldEnableDigitalHumanLivePanel {
            FeatureFlagService.shared.enableForCurrentLaunch(.digitalHumanLivePanel)
            print("[UI_QA] Digital human live panel enabled")
        }
        if launchPlan.shouldSeedProfileCareFamilyMember,
           launchPlan.scenario?.requiresAuthenticatedBackendFixture != true {
            seedUIQAStarCareFamilyMember()
        }
        guard let scenario = launchPlan.scenario else { return }
        if scenario.requiresAuthenticatedBackendFixture {
            FeatureFlagService.shared.resetToDefaults()
            prepareUIQAProfileCareBackendSession(for: scenario) { [weak self] failureReason in
                guard let self else { return }
                if let failureReason {
                    self.writeProfileCareBackendFixtureFailure(
                        scenario: scenario,
                        reason: failureReason
                    )
                    return
                }
                self.activateUIQAAuthenticatedBackendProfileSession(for: scenario)
            }
            return
        }
        QAScenarioRunner.prepareSession(
            for: launchPlan,
            login: { UserManager.shared.login(phone: "13800009999", nickname: "UI QA") },
            resetFeatureFlags: { FeatureFlagService.shared.resetToDefaults() }
        )

        switch scenario {
        case .digitalHumanLivePanelSmoke:
            scheduleUIQAScenario(scenario) { $0.runDigitalHumanLivePanelSmoke() }
        case .echoDigitalHumanLifecycleSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoDigitalHumanLifecycleSmoke() }
        case .echoContinuousTurnSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoContinuousTurnSmoke() }
        case .digitalHumanRuntimeStubSmoke:
            prepareUIQADigitalHumanRuntimeStubBackendSession { [weak self] authenticated in
                guard authenticated else { return }
                self?.scheduleUIQAScenario(scenario) { $0.runDigitalHumanRuntimeStubSmoke() }
            }
        case .voiceCloneProfileSelectionSmoke:
            scheduleUIQAScenario(scenario) { $0.runVoiceCloneProfileSelectionSmoke() }
        case .voiceCloneSynthesisRuntimeSmoke:
            scheduleUIQAScenario(scenario) { $0.runVoiceCloneSynthesisRuntimeSmoke() }
        case .tencentBackendPCMDriveMockSmoke:
            scheduleUIQAScenario(scenario) { $0.runTencentBackendPCMDriveMockSmoke() }
        case .echoTraceExportSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoTraceExportSmoke() }
        case .echoRuntimeDiagnosticsExportSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoRuntimeDiagnosticsExportSmoke() }
        case .echoTraceEvidencePackageExportSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoTraceEvidencePackageExportSmoke() }
        case .echoTraceEvidencePackagePanelExportSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoTraceEvidencePackagePanelExportSmoke() }
        case .echoQAEvidenceBundleExportSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoQAEvidenceBundleExportSmoke() }
        case .profileCareBackendFailureRetrySmoke:
            scheduleUIQAScenario(scenario) { $0.runProfileCareBackendFailureRetrySmoke() }
        case .profileCareBackendStateSmoke:
            scheduleUIQAScenario(scenario) { $0.runProfileCareBackendStateSmoke() }
        case .profileCareStateSmoke:
            scheduleUIQAScenario(scenario) { $0.runProfileCareStateSmoke() }
        case .profileCareEscalationBoundarySmoke:
            scheduleUIQAScenario(scenario) { $0.runProfileCareEscalationBoundarySmoke() }
        case .profileFamilyPersonaReleaseSmoke:
            scheduleUIQAScenario(scenario) { $0.runProfileFamilyPersonaReleaseSmoke() }
        case .globalPrivateStoreRetirementSmoke:
            scheduleUIQAScenario(scenario) { _ in
                ProductV4GlobalPrivateStoreRetirementUIQASmoke.runAndPresent()
            }
        case .archiveMediaEntriesSmoke:
            scheduleUIQAScenario(scenario) { $0.runArchiveMediaEntriesSmoke() }
        case .archiveAudioLifecycleSmoke:
            scheduleUIQAScenario(scenario) { $0.runArchiveAudioLifecycleSmoke() }
        case .archiveHiddenShellSmoke:
            scheduleUIQAScenario(scenario) { $0.runArchiveHiddenShellSmoke() }
        case .ownerTruthCandidateInboxSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthCandidateInboxSmoke() }
        case .ownerTruthInterviewCandidateReviewSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthInterviewCandidateReviewSmoke() }
        case .ownerTruthInterviewSessionStateSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthInterviewSessionStateSmoke() }
        case .ownerTruthInterviewNaturalInputSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthInterviewNaturalInputSmoke() }
        case .ownerTruthInterviewNaturalInputEchoSurfaceSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthInterviewNaturalInputEchoSurfaceSmoke() }
        case .ownerTruthInterviewNaturalInputProductSurfaceSmoke:
            scheduleUIQAScenario(scenario) { $0.runOwnerTruthInterviewNaturalInputProductSurfaceSmoke() }
        case .archiveFailedAnalysisRetrySmoke:
            seedFailedArchiveAnalysisRetryContext()
            scheduleUIQAScenario(scenario) { $0.runArchiveFailedAnalysisRetrySmoke() }
        case .echoDelayedReplyNotificationSmoke:
            scheduleUIQAScenario(scenario) { $0.runEchoDelayedReplyNotificationSmoke() }
        case .backendEnvironmentSmoke:
            seedEchoArchiveContext()
            scheduleUIQAScenario(scenario) { $0.runBackendEnvSmoke() }
        case .archiveToEchoSmoke:
            DialogPromptDebugRecorder.reset()
            scheduleUIQAScenario(scenario) { $0.runArchiveToEchoSmoke() }
        case .archiveMediaEchoContextSmoke:
            DialogPromptDebugRecorder.reset()
            prepareArchiveMediaEchoContextSmoke()
        case .timeLetterDispatchReminderSmoke:
            scheduleUIQAScenario(scenario) { $0.runTimeLetterDispatchReminderSmoke() }
        case .echoListeningStatePreview:
            scheduleUIQAScenario(scenario) {
                $0.showEchoVoiceStatePreview(targetState: .listening)
            }
        case .echoSpeakingStatePreview:
            scheduleUIQAScenario(scenario) {
                $0.showEchoVoiceStatePreview(targetState: .speaking)
            }
        case .voiceSDKReadinessPreview:
            scheduleUIQAScenario(scenario) { $0.showVoiceSDKReadinessPreview() }
        case .voiceCloneStatusFeedbackPreview:
            scheduleUIQAScenario(scenario) { $0.showVoiceCloneStatusFeedbackPreview() }
        case .echoVoiceStatePreview:
            scheduleUIQAScenario(scenario) { $0.showEchoVoiceStatePreview() }
        case .seedEchoArchiveContext:
            seedEchoArchiveContext()
        case .seedArchiveAnalysisInsights:
            seedArchiveAnalysisInsightsContext()
        case .seedPendingArchiveAnalysis:
            seedPendingArchiveAnalysisContext()
        }
    }

    func prepareUIQAProfileCareBackendSession(
        for scenario: QALaunchScenario,
        completion: @escaping (String?) -> Void
    ) {
        guard let userId = uiqaArgumentValue(prefix: "DJCareSessionUserId=") else {
            completion("missingCareSessionUserId")
            return
        }
        QAAuthenticatedBackendSessionFixture.prepare(
            expectedUserId: userId,
            completion: completion
        )
    }

    func activateUIQAAuthenticatedBackendProfileSession(
        for scenario: QALaunchScenario,
        retryCount: Int = 0
    ) {
        let maximumCoordinatorRetries = 20
        guard let coordinator = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .compactMap({ $0.delegate as? SceneDelegate })
            .compactMap(\.appCoordinator)
            .first else {
            guard retryCount < maximumCoordinatorRetries else {
                writeProfileCareBackendFixtureFailure(
                    scenario: scenario,
                    reason: "missingUIQAAppCoordinator"
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.activateUIQAAuthenticatedBackendProfileSession(
                    for: scenario,
                    retryCount: retryCount + 1
                )
            }
            return
        }

        coordinator.activateVerifiedLoginForUIQA { [weak self] accepted, reason in
            guard let self else { return }
            guard accepted else {
                self.writeProfileCareBackendFixtureFailure(
                    scenario: scenario,
                    reason: "uiqaCoordinatorActivationRejected.\(reason)"
                )
                return
            }
            self.prepareUIQAProfileCareDashboardFixture(
                for: scenario
            ) { prepared in
                guard prepared else {
                    self.writeProfileCareBackendFixtureFailure(
                        scenario: scenario,
                        reason: "profileCareQADashboardFixtureUnavailable"
                    )
                    return
                }
                switch scenario {
                case .profileCareBackendFailureRetrySmoke:
                    self.scheduleUIQAScenario(scenario) { $0.runProfileCareBackendFailureRetrySmoke() }
                case .profileCareBackendStateSmoke:
                    self.scheduleUIQAScenario(scenario) { $0.runProfileCareBackendStateSmoke() }
                default:
                    break
                }
            }
        }
    }

    func prepareUIQAProfileCareDashboardFixture(
        for scenario: QALaunchScenario,
        retryCount: Int = 0,
        completion: @escaping (Bool) -> Void
    ) {
        guard scenario.requiresAuthenticatedBackendFixture else {
            completion(true)
            return
        }

        // The authenticated fixture proves a real principal/owner path. The
        // family member here only unlocks the Profile care-card presentation
        // prerequisite in the simulator; it is never persisted or exposed in
        // a release artifact.
        FeatureFlagService.shared.enableForCurrentLaunch(.careDashboard)
        seedUIQAStarCareFamilyMember()
        guard FamilyRepository.shared.hasStarModeMember else {
            guard retryCount < 10 else {
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.prepareUIQAProfileCareDashboardFixture(
                    for: scenario,
                    retryCount: retryCount + 1,
                    completion: completion
                )
            }
            return
        }
        completion(true)
    }

    func writeProfileCareBackendFixtureFailure(
        scenario: QALaunchScenario,
        reason: String
    ) {
        switch scenario {
        case .profileCareBackendStateSmoke:
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: reason
            )
        case .profileCareBackendFailureRetrySmoke:
            writeProfileCareBackendFailureRetrySmokeResult(
                completed: false,
                retry: [:],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: reason
            )
        default:
            return
        }
        print("[UI_QA] Profile care backend smoke failed reason=\(reason)")
    }

    /// The runtime-stub smoke intentionally exercises the authenticated route
    /// boundary. Its local backend provides a synthetic V2 challenge only in
    /// the UI_QA_SIMULATOR process; no production credential is synthesized.
    func prepareUIQADigitalHumanRuntimeStubBackendSession(
        completion: @escaping (Bool) -> Void
    ) {
        let phone = "13800009999"
        let fallbackNickname = "UI QA"
        guard let verificationCode = uiqaArgumentValue(prefix: "DJUIQAIdentityChallengeCode="),
              !verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            writeDigitalHumanRuntimeStubSmokeResult([
                "completed": false,
                "failureReason": "missingUIQAIdentityChallengeCode",
            ])
            print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=missingUIQAIdentityChallengeCode")
            completion(false)
            return
        }

        DreamJourneyBackendClient.shared.createIdentityChallenge(phone: phone) { [weak self] challengeResult in
            guard let self else { return }
            switch challengeResult {
            case .failure:
                self.writeDigitalHumanRuntimeStubSmokeResult([
                    "completed": false,
                    "failureReason": "identityChallengeCreateFailed",
                ])
                print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=identityChallengeCreateFailed")
                completion(false)
            case .success(let challenge):
                DreamJourneyBackendClient.shared.verifyIdentityChallenge(
                    challengeId: challenge.challengeId,
                    verificationCode: verificationCode,
                    nickname: fallbackNickname
                ) { [weak self] verificationResult in
                    guard let self else { return }
                    switch verificationResult {
                    case .failure(let error):
                        self.writeDigitalHumanRuntimeStubSmokeResult([
                            "completed": false,
                            "failureReason": "identityChallengeVerificationFailed",
                            "error": error.localizedDescription,
                        ])
                        print(
                            "[UI_QA] DigitalHumanRuntimeStubSmoke failed " +
                            "reason=identityChallengeVerificationFailed error=\(error.localizedDescription)"
                        )
                        completion(false)
                    case .success(let response):
                        guard let user = response["user"] as? [String: Any],
                              let userId = user["id"] as? String,
                              !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            self.writeDigitalHumanRuntimeStubSmokeResult([
                                "completed": false,
                                "failureReason": "identityChallengeMissingUser",
                            ])
                            print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=identityChallengeMissingUser")
                            completion(false)
                            return
                        }
                        let nickname = (user["nickname"] as? String) ?? fallbackNickname
                        guard UserManager.shared.loginVerifiedAccount(
                            phone: phone,
                            nickname: nickname,
                            userId: userId
                        ) else {
                            self.writeDigitalHumanRuntimeStubSmokeResult([
                                "completed": false,
                                "failureReason": "identityChallengeSessionAdoptionFailed",
                            ])
                            print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=identityChallengeSessionAdoptionFailed")
                            completion(false)
                            return
                        }
                        self.activateUIQADigitalHumanRuntimeStubAccount(
                            expectedUserId: userId,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    /// Mirrors the post-login AccountSessionActor activation that the normal
    /// AppCoordinator performs after a verified identity challenge.
    func activateUIQADigitalHumanRuntimeStubAccount(
        expectedUserId: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let credential = UserManager.shared.accountSessionCredentialSnapshot(),
              credential.trust == .requiresOnlineValidation,
              credential.normalizedSubjectId == expectedUserId else {
            writeDigitalHumanRuntimeStubSmokeResult([
                "completed": false,
                "failureReason": "identityChallengeCredentialUnavailable",
            ])
            completion(false)
            return
        }

        Task { [weak self] in
            let receipt = await AccountSessionActor.shared.activateVerifiedLogin(credential)
            await MainActor.run {
                guard let self else { return }
                guard receipt.accepted,
                      receipt.state == .active,
                      receipt.session?.subjectId == expectedUserId else {
                    self.writeDigitalHumanRuntimeStubSmokeResult([
                        "completed": false,
                        "failureReason": "identityChallengeAccountActivationFailed",
                    ])
                    completion(false)
                    return
                }
                print("[UI_QA] DigitalHumanRuntimeStubSmoke authenticated via synthetic V2 challenge")
                completion(true)
            }
        }
    }

    func scheduleUIQAScenario(
        _ scenario: QALaunchScenario,
        action: @escaping (AppDelegate) -> Void
    ) {
        QAScenarioRunner.schedule(
            scenario,
            scheduleAfter: { delay, scheduledAction in
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + delay,
                    execute: scheduledAction
                )
            },
            action: { [weak self] in
                guard let self else { return }
                action(self)
            }
        )
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
        guard let profileViewController = QAProfileScenarioRunner.selectRootProfileViewController() else {
            writeProfileCareStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                failureReason: "missingProfileRoot"
            )
            print("[UI_QA] ProfileCareStateSmoke failed reason=missingProfileRoot")
            return
        }

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
            profileTabSelected: true,
            failureReason: completed ? nil : "stateContractMismatch"
        )
        print(
            "[UI_QA] ProfileCareStateSmoke completed " +
            "completed=\(completed) " +
            "profileStates=\(profileStates.sorted().joined(separator: "|")) " +
            "dashboardStates=\(dashboardStates.sorted().joined(separator: "|"))"
        )
    }

    func runProfileCareBackendStateSmoke(profileRootRetryCount: Int = 0) {
        let maximumProfileRootRetries = 20
        guard let profileViewController = QAProfileScenarioRunner.selectRootProfileViewController() else {
            guard profileRootRetryCount < maximumProfileRootRetries else {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runProfileCareBackendStateSmoke(
                    profileRootRetryCount: profileRootRetryCount + 1
                )
            }
            return
        }
        guard UserManager.shared.currentUser?.id != nil else {
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingCareSessionUser"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=missingCareSessionUser")
            return
        }

        guard let caseName = uiqaArgumentValue(prefix: "DJCareCaseName="),
              let userId = uiqaArgumentValue(prefix: "DJCareStateUserId=") else {
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingCareStateCase"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=missingCareStateCase")
            return
        }

        let expectedState: String
        switch caseName {
        case "active":
            expectedState = ProfileCareDataState.available.accessibilityIdentifier
        case "empty":
            expectedState = ProfileCareDataState.empty.accessibilityIdentifier
        case "stale":
            expectedState = ProfileCareDataState.stale.accessibilityIdentifier
        default:
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "unsupportedCareStateCase"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=unsupportedCareStateCase")
            return
        }

        guard UserManager.shared.currentUser?.id == userId else {
            writeProfileCareBackendStateSmokeResult(
                completed: false,
                states: [],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "careSessionUserMismatch"
            )
            print("[UI_QA] ProfileCareBackendStateSmoke failed reason=careSessionUserMismatch")
            return
        }

        profileViewController.loadViewIfNeeded()

        let cases = [
            ProfileCareBackendStateSmokeCase(
                name: caseName,
                userId: userId,
                expectedState: expectedState
            ),
        ]

        profileViewController.runUIQAProfileCareBackendStateSmoke(cases: cases) { [weak self] states in
            let profileTabSelected = true
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

            func finish(retry: [String: Any], retryCompleted: Bool) {
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
                    "case=\(caseName) " +
                    "retryActionFired=\(retry["retryActionFired"] as? Bool ?? false) " +
                    "retryFinalState=\(retry["retryFinalState"] as? String ?? "notApplicable") " +
                    "profileStates=\(actualStates.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: "|")) " +
                    "dashboardStates=\(dashboardStates.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: "|"))"
                )
            }

            guard caseName == "active" else {
                finish(retry: ["skipped": true], retryCompleted: true)
                return
            }

            profileViewController.runUIQAProfileCareBackendRetrySmoke(retryUserId: userId) { retry in
                let retryCompleted = (retry["retryActionFired"] as? Bool) == true
                    && (retry["retryButtonVisible"] as? Bool) == true
                    && (retry["retryRequestCountAdvanced"] as? Bool) == true
                    && (retry["retryInitialState"] as? String) == ProfileCareDataState.stale.accessibilityIdentifier
                    && (retry["retryIntermediateState"] as? String) == ProfileCareDataState.loading.accessibilityIdentifier
                    && ((retry["retryIntermediateSyncCaption"] as? String) ?? "").contains("正在重新同步关怀信号")
                    && (retry["retryFinalState"] as? String) == ProfileCareDataState.available.accessibilityIdentifier
                    && (retry["retryRequestedUserId"] as? String) == userId
                finish(retry: retry, retryCompleted: retryCompleted)
            }
        }
    }

    func runProfileCareBackendFailureRetrySmoke(profileRootRetryCount: Int = 0) {
        let maximumProfileRootRetries = 20
        guard let profileViewController = QAProfileScenarioRunner.selectRootProfileViewController() else {
            guard profileRootRetryCount < maximumProfileRootRetries else {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runProfileCareBackendFailureRetrySmoke(
                    profileRootRetryCount: profileRootRetryCount + 1
                )
            }
            return
        }
        guard UserManager.shared.currentUser?.id != nil else {
            writeProfileCareBackendFailureRetrySmokeResult(
                completed: false,
                retry: [:],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "missingCareSessionUser"
            )
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=missingCareSessionUser")
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

        guard UserManager.shared.currentUser?.id == retryUserId else {
            writeProfileCareBackendFailureRetrySmokeResult(
                completed: false,
                retry: [:],
                profileTabSelected: false,
                backendConfigured: DreamJourneyBackendClient.shared.isCareSnapshotConfigured,
                failureReason: "careSessionUserMismatch"
            )
            print("[UI_QA] ProfileCareBackendFailureRetrySmoke failed reason=careSessionUserMismatch")
            return
        }

        profileViewController.loadViewIfNeeded()

        profileViewController.runUIQAProfileCareBackendFailureRetrySmoke(retryUserId: retryUserId) { [weak self] retry in
            let profileTabSelected = true
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
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId),
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=accountLeaseUnavailable")
            return
        }
        let resourceOwnerId = accountLease.subjectId
        let roleContextKey = "uiqa-echo-delayed-reply-role"

        let viewModel = EchoViewModel()
        for turn in 1..<EchoReplyPacingPolicy.waitAfterUserTurnCount {
            viewModel.beginVoiceInteraction()
            viewModel.finishUserVoice(
                text: "第 \(turn) 次想起爸爸小时候的故事",
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                roleContextKey: roleContextKey
            )
            viewModel.receiveAIReply("我在听，慢慢说。")
            viewModel.markReplyDelivered(accountLease: accountLease)
        }
        viewModel.beginVoiceInteraction()
        viewModel.finishUserVoice(
            text: "第十次想起这件事",
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            roleContextKey: roleContextKey
        )

        let delayedReply = viewModel.pendingDelayedReply
        let delayMinutesInRange = delayedReply.map {
            EchoReplyPacingPolicy.replyDelayMinuteRange.contains($0.minutes)
        } ?? false
        guard let delayedReply else {
            writeEchoDelayedReplyNotificationSmokeResult(
                completed: false,
                delayMinutesInRange: delayMinutesInRange,
                storedDelayedReply: false,
                localNotificationContractPresent: false,
                restoredWaitingState: false,
                restoredWaitingMinutes: 0,
                restoredWaitingMinutesInRange: false,
                restoredDelayedReplyIdMatched: false,
                expiredDelayedReplyAwaitingServer: false,
                expiredDelayedReplyPreserved: false,
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
        guard let callsiteContext = viewModel.pendingDelayedReplyContext,
              callsiteContext.accountLease == accountLease,
              callsiteContext.resourceOwnerId == resourceOwnerId,
              callsiteContext.operationId == delayedReply.id,
              callsiteContext.roleContextKey == roleContextKey else {
            print("[UI_QA] EchoDelayedReplyNotificationSmoke failed reason=missingCallsiteContext")
            return
        }
        let notificationOperationId = callsiteContext.operationId
        let storedReply = EchoDelayedReplyStore.shared.load(
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId,
            accountLease: callsiteContext.accountLease
        )
        let storedDelayedReply = storedReply?.id == delayedReply.id
            && storedReply?.userTurnCount == delayedReply.userTurnCount
            && storedReply?.trigger == delayedReply.trigger
        let rawNotificationMetadataValues = [
            accountLease.subjectId,
            accountLease.vaultId,
            accountLease.sessionId,
            accountLease.authorityEpoch,
            accountLease.generationId.uuidString,
            resourceOwnerId,
            delayedReply.id,
            notificationOperationId,
        ].filter { !$0.isEmpty }
        let expectedNotificationIdentifier = EchoDelayedReplyNotificationScheduler.notificationIdentifier(
            resourceOwnerId: resourceOwnerId,
            operationId: notificationOperationId,
            accountLease: accountLease
        )
        let localNotificationContractPresent = expectedNotificationIdentifier.map { identifier in
            identifier.hasPrefix("dj.echo.delayedReply.")
                && !rawNotificationMetadataValues.contains { identifier.contains($0) }
        } ?? false

        let restoreViewModel = EchoViewModel()
        let restoredWaitingState = restoreViewModel.restoreStoredDelayedReplyIfAvailable(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            roleContextKey: roleContextKey,
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
            id: delayedReply.id,
            scheduledAt: delayedReply.scheduledAt.addingTimeInterval(-600),
            deliverAt: delayedReply.scheduledAt.addingTimeInterval(-60),
            minutes: delayedReply.minutes,
            userTurnCount: delayedReply.userTurnCount,
            trigger: delayedReply.trigger
        )
        _ = EchoDelayedReplyStore.shared.save(
            expiredDelayedReply,
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId,
            accountLease: callsiteContext.accountLease
        )
        let expiredViewModel = EchoViewModel()
        let expiredDelayedReplyHandled = expiredViewModel.restoreStoredDelayedReplyIfAvailable(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            roleContextKey: roleContextKey,
            now: delayedReply.scheduledAt
        )
        let expiredDelayedReplyAwaitingServer: Bool
        if case .awaitingReplyDelivery = expiredViewModel.state {
            expiredDelayedReplyAwaitingServer = expiredDelayedReplyHandled
        } else {
            expiredDelayedReplyAwaitingServer = false
        }
        let expiredDelayedReplyPreserved = EchoDelayedReplyStore.shared.load(
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId,
            accountLease: callsiteContext.accountLease
        )?.id == expiredDelayedReply.id
            && EchoDelayedReplyCallsiteScopeStore().load(
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                roleContextKey: roleContextKey
            ) == callsiteContext
        _ = EchoDelayedReplyStore.shared.save(
            delayedReply,
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId,
            accountLease: callsiteContext.accountLease
        )
        _ = EchoDelayedReplyCallsiteScopeStore().save(callsiteContext)

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
                    expiredDelayedReplyAwaitingServer: expiredDelayedReplyAwaitingServer,
                    expiredDelayedReplyPreserved: expiredDelayedReplyPreserved,
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

            EchoDelayedReplyNotificationScheduler.shared.schedule(
                delayedReply,
                resourceOwnerId: resourceOwnerId,
                operationId: notificationOperationId,
                accountLease: accountLease
            ) { scheduleError in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        let pendingRequest = expectedNotificationIdentifier.flatMap { identifier in
                            requests.first { $0.identifier == identifier }
                        }
                        let pendingNotificationIdentifierMatched = expectedNotificationIdentifier.map {
                            pendingRequest?.identifier == $0
                        } ?? false
                        let pendingNotificationTriggerMatched: Bool
                        if let trigger = pendingRequest?.trigger as? UNTimeIntervalNotificationTrigger {
                            pendingNotificationTriggerMatched = !trigger.repeats
                                && trigger.timeInterval > 0
                        } else {
                            pendingNotificationTriggerMatched = false
                        }
                        let userInfo = pendingRequest?.content.userInfo ?? [:]
                        let expectedSubjectIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["subject", accountLease.subjectId]
                        )
                        let expectedGenerationIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["generation-id", accountLease.generationId.uuidString]
                        )
                        let expectedVaultIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["vault", accountLease.vaultId]
                        )
                        let expectedAuthorityEpochIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["authority-epoch", accountLease.authorityEpoch]
                        )
                        let expectedResourceOwnerIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["resource-owner", resourceOwnerId]
                        )
                        let expectedOperationIdentity = EchoDelayedReplyOperationScope.identityDigest(
                            values: ["operation", notificationOperationId]
                        )
                        let expectedNotificationUserInfoKeys: Set<String> = [
                            NotificationRuntimeRoutePayload.Key.schemaVersion,
                            NotificationRuntimeRoutePayload.Key.action,
                            "type",
                            "trigger",
                            "accountSubjectIdentity",
                            "accountLeaseGeneration",
                            "accountLeaseGenerationIdentity",
                            "accountLeaseVaultIdentity",
                            "accountLeaseAuthorityEpochIdentity",
                            "resourceOwnerIdentity",
                            "operationIdentity",
                        ]
                        let notificationUserInfoKeys = Set(
                            userInfo.keys.compactMap { $0 as? String }
                        )
                        let rawNotificationMetadataKeys: Set<String> = [
                            "subjectId",
                            "vaultId",
                            "sessionId",
                            "authorityEpoch",
                            "generationId",
                            "accountLeaseGenerationId",
                            "resourceOwnerId",
                            "delayedReplyId",
                            "operationId",
                        ]
                        let rawNotificationFieldsAbsent = rawNotificationMetadataKeys.isDisjoint(
                            with: notificationUserInfoKeys
                        )
                        let containsRawNotificationMetadata = userInfo.contains { key, value in
                            rawNotificationMetadataValues.contains { rawValue in
                                String(describing: key).contains(rawValue)
                                    || String(describing: value).contains(rawValue)
                            }
                        }
                        let pendingNotificationUserInfoMatched = userInfo["type"] as? String
                            == "echoDelayedReply"
                            && (userInfo[NotificationRuntimeRoutePayload.Key.schemaVersion] as? NSNumber)?.intValue
                                == NotificationRuntimeRoutePayload.schemaVersion
                            && userInfo[NotificationRuntimeRoutePayload.Key.action] as? String
                                == NotificationRuntimeRouteAction.open.rawValue
                            && userInfo["trigger"] as? String == delayedReply.trigger.rawValue
                            && userInfo["accountSubjectIdentity"] as? String == expectedSubjectIdentity
                            && (userInfo["accountLeaseGeneration"] as? NSNumber)?.uint64Value
                                == accountLease.generation
                            && userInfo["accountLeaseGenerationIdentity"] as? String
                                == expectedGenerationIdentity
                            && userInfo["accountLeaseVaultIdentity"] as? String == expectedVaultIdentity
                            && userInfo["accountLeaseAuthorityEpochIdentity"] as? String
                                == expectedAuthorityEpochIdentity
                            && userInfo["resourceOwnerIdentity"] as? String
                                == expectedResourceOwnerIdentity
                            && userInfo["operationIdentity"] as? String == expectedOperationIdentity
                            && notificationUserInfoKeys == expectedNotificationUserInfoKeys
                            && notificationUserInfoKeys.count == userInfo.count
                            && rawNotificationFieldsAbsent
                            && !containsRawNotificationMetadata
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
                            && expiredDelayedReplyAwaitingServer
                            && expiredDelayedReplyPreserved
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
                            expiredDelayedReplyAwaitingServer: expiredDelayedReplyAwaitingServer,
                            expiredDelayedReplyPreserved: expiredDelayedReplyPreserved,
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
                            "expiredDelayedReplyAwaitingServer=\(expiredDelayedReplyAwaitingServer) " +
                            "pendingNotificationMatched=\(pendingNotificationMatched)"
                        )
                    }
                }
            }
        }
    }

    func selectProfileTabForCareEscalationSmoke() -> Bool {
        QAProfileScenarioRunner.selectRootProfileTab()
    }

    func uiqaArgumentValue(prefix: String) -> String? {
        QALaunchConfiguration.shared.value(forPrefix: prefix)
    }

    func seedUIQAStarCareFamilyMember() {
        FamilyRepository.shared.add(FamilyMember(
            id: "uiqa_star_care_family",
            name: "星辰关怀家人",
            relation: "家人",
            isOnline: true,
            lastUpdated: "UI QA 已准备",
            digitalHumanMode: .star,
            backendContractMode: "uiqaStarCare",
            relationshipOwnerUserId: UserManager.shared.currentUser?.id ?? "user_9999",
            relationshipAuthoritySource: .qaFixture,
            accessStatus: "active",
            invitationStatus: "accepted"
        ))
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
            isFamilyManagementEnabled: true,
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
            && familyManagementOnlyRowVisible == false
            && familyManagementOnlyCanOpenSwitcher == false
            && familySpaceCanOpenSwitcher == false
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
            "ownerUserId": UserManager.shared.currentUser?.id ?? "user_9999",
            "accessStatus": "active",
            "invitationStatus": "accepted",
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

    func runVoiceCloneProfileSelectionSmoke() {
        let readyProfile = makeUIQAVoiceCloneProfile(
            voiceProfileId: "S_ready_uiqa",
            sampleStatus: .ready,
            providerStatus: "2",
            providerMessage: "ready",
            realCloneProviderReady: true,
            isEnabled: true
        )
        let pendingProfile = makeUIQAVoiceCloneProfile(
            voiceProfileId: "S_pending_uiqa",
            sampleStatus: .pending,
            providerStatus: "pending",
            providerMessage: "training",
            realCloneProviderReady: false,
            isEnabled: false
        )
        let deletedProfile = makeUIQAVoiceCloneProfile(
            voiceProfileId: "S_deleted_uiqa",
            sampleStatus: .deleted,
            providerStatus: "deleted",
            providerMessage: "deleted",
            realCloneProviderReady: false,
            isEnabled: false
        )

        let profiles = [pendingProfile, deletedProfile, readyProfile]
        let selectedProfile = VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles)
        let selectedWithPendingPreferred = VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles, preferredProfileId: pendingProfile.voiceProfileId)

        VoiceCloneService.shared.deleteVoiceProfile(profileId: readyProfile.voiceProfileId)
        VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: readyProfile))
        let usableBeforePending = VoiceCloneService.shared.currentUsableSpeakerId
        VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: pendingProfile))
        let usableAfterPending = VoiceCloneService.shared.currentUsableSpeakerId

        let readyPreferredOverPending = selectedProfile?.voiceProfileId == readyProfile.voiceProfileId
        let pendingPreferredRespected = selectedWithPendingPreferred?.voiceProfileId == pendingProfile.voiceProfileId
        let pendingClearsUsableReady = usableBeforePending == readyProfile.voiceProfileId
            && usableAfterPending == nil
        let deletedIgnored = selectedProfile?.voiceProfileId != deletedProfile.voiceProfileId
        let completed = readyPreferredOverPending
            && pendingPreferredRespected
            && pendingClearsUsableReady
            && deletedIgnored

        writeVoiceCloneProfileSelectionSmokeResult([
            "completed": completed,
            "readyVoiceProfileId": readyProfile.voiceProfileId,
            "pendingVoiceProfileId": pendingProfile.voiceProfileId,
            "deletedVoiceProfileId": deletedProfile.voiceProfileId,
            "selectedVoiceProfileId": selectedProfile?.voiceProfileId ?? "missing",
            "selectedWithPendingPreferredVoiceProfileId": selectedWithPendingPreferred?.voiceProfileId ?? "missing",
            "usableBeforePending": usableBeforePending ?? "missing",
            "usableAfterPending": usableAfterPending ?? "missing",
            "readyPreferredOverPending": readyPreferredOverPending,
            "pendingPreferredRespected": pendingPreferredRespected,
            "pendingClearsUsableReady": pendingClearsUsableReady,
            "deletedIgnored": deletedIgnored,
        ])
        print(
            "[UI_QA] VoiceCloneProfileSelectionSmoke completed " +
            "selected=\(selectedProfile?.voiceProfileId ?? "missing") " +
            "selectedWithPendingPreferred=\(selectedWithPendingPreferred?.voiceProfileId ?? "missing") " +
            "usableAfterPending=\(usableAfterPending ?? "missing")"
        )
    }

    func makeUIQAVoiceCloneProfile(
        voiceProfileId: String,
        sampleStatus: VoiceCloneSampleStatus,
        providerStatus: String,
        providerMessage: String,
        realCloneProviderReady: Bool,
        isEnabled: Bool,
        qualityAcceptanceRequired: Bool = false
    ) -> VoiceCloneProfileContract {
        guard let profile = VoiceCloneProfileContract(json: [
            "voiceProfileId": voiceProfileId,
            "sampleStatus": sampleStatus.rawValue,
            "authorizationConfirmed": true,
            "authorizationVersion": "voice-clone-consent-v1",
            "authorizationCopy": "UIQA 声音复刻授权合同，仅用于验证音色选择策略。",
            "providerMode": "volcengineVoiceClone2",
            "providerStatus": providerStatus,
            "providerMessage": providerMessage,
            "realCloneProviderReady": realCloneProviderReady,
            "qualityAcceptanceRequired": qualityAcceptanceRequired,
            "isEnabled": isEnabled,
            "defaultReleaseVisible": true,
            "contractVersion": 2,
            "disableContract": "后端禁用 voiceProfileId 的合成权限。",
            "deleteContract": "后端删除样本、训练产物和授权记录。",
            "personaScope": "personal",
            "digitalHumanId": "digital_human_uiqa_self",
        ]) else {
            preconditionFailure("Unable to build UIQA voice clone profile \(voiceProfileId)")
        }
        return profile
    }

    func runVoiceCloneSynthesisRuntimeSmoke() {
        let voiceProfileId = uiqaArgumentValue(prefix: "DJVoiceCloneProbeProfileId=") ?? "S_uiqa_voice_clone_probe_required"
        let userId = uiqaArgumentValue(prefix: "DJVoiceCloneProbeUserId=")
            ?? UserManager.shared.currentUser?.id
            ?? "voice_clone_ios_uiqa"

        DreamJourneyBackendClient.shared.fetchVoiceCloneRuntimeCapability { [weak self] runtimeResult in
            DispatchQueue.main.async {
                guard let self else { return }
                switch runtimeResult {
                case .failure(let error):
                    self.writeVoiceCloneSynthesisRuntimeSmokeResult([
                        "completed": false,
                        "failureReason": "runtimeFetchFailed",
                        "error": error.localizedDescription,
                        "voiceProfileId": voiceProfileId,
                        "userId": userId,
                    ])
                    print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=runtimeFetchFailed error=\(error.localizedDescription)")
                case .success(let capability):
                    guard capability.canSynthesize else {
                        self.writeVoiceCloneSynthesisRuntimeSmokeResult([
                            "completed": false,
                            "failureReason": "runtimeSynthesisUnavailable",
                            "voiceProfileId": voiceProfileId,
                            "userId": userId,
                            "provider": capability.provider,
                            "synthesisProviderReady": capability.synthesisProviderReady,
                            "voiceClone2TrialReady": capability.voiceClone2TrialReady,
                            "tencentAudioDriveSupported": capability.tencentAudioDrive.supported,
                        ])
                        print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=runtimeSynthesisUnavailable")
                        return
                    }
                    guard capability.tencentAudioDrive.supported else {
                        self.writeVoiceCloneSynthesisRuntimeSmokeResult([
                            "completed": false,
                            "failureReason": "tencentAudioDriveUnavailable",
                            "voiceProfileId": voiceProfileId,
                            "userId": userId,
                            "provider": capability.provider,
                            "synthesisProviderReady": capability.synthesisProviderReady,
                            "voiceClone2TrialReady": capability.voiceClone2TrialReady,
                            "tencentAudioDriveSupported": capability.tencentAudioDrive.supported,
                        ])
                        print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=tencentAudioDriveUnavailable")
                        return
                    }

                    DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
                        userId: userId,
                        voiceProfileId: voiceProfileId,
                        text: "你好，我在这里。",
                        audioFormat: "wav",
                        sampleRate: capability.tencentAudioDrive.sampleRate,
                        speechRate: -10,
                        loudnessRate: 10,
                        outputMode: capability.tencentAudioDrive.requestOutputMode
                    ) { [weak self] synthesisResult in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch synthesisResult {
                            case .failure(let error):
                                self.writeVoiceCloneSynthesisRuntimeSmokeResult([
                                    "completed": false,
                                    "failureReason": "synthesisFailed",
                                    "error": error.localizedDescription,
                                    "voiceProfileId": voiceProfileId,
                                    "userId": userId,
                                    "provider": capability.provider,
                                    "synthesisProviderReady": capability.synthesisProviderReady,
                                    "voiceClone2TrialReady": capability.voiceClone2TrialReady,
                                    "tencentAudioDriveSupported": capability.tencentAudioDrive.supported,
                                ])
                                print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=synthesisFailed error=\(error.localizedDescription)")
                            case .success(let synthesis):
                                let pcmData = synthesis.tencentAudioDrivePCMData
                                let pcmByteCount = pcmData?.count ?? 0
                                let riffHeader = Data([0x52, 0x49, 0x46, 0x46])
                                let isRawPCM = pcmData.map { !$0.starts(with: riffHeader) } ?? false
                                let pcmCompatible = synthesis.isTencentAudioDrivePCMCompatible
                                    && pcmByteCount == synthesis.byteCount
                                    && pcmByteCount > 0
                                    && isRawPCM
                                self.writeVoiceCloneSynthesisRuntimeSmokeResult([
                                    "completed": pcmCompatible,
                                    "failureReason": pcmCompatible ? "" : "pcmContractMismatch",
                                    "voiceProfileId": synthesis.voiceProfileId,
                                    "userId": userId,
                                    "provider": capability.provider,
                                    "providerMode": synthesis.providerMode,
                                    "synthesisProviderReady": capability.synthesisProviderReady,
                                    "voiceClone2TrialReady": capability.voiceClone2TrialReady,
                                    "tencentAudioDriveSupported": capability.tencentAudioDrive.supported,
                                    "outputMode": synthesis.outputMode ?? "",
                                    "audioFormat": synthesis.audioFormat,
                                    "sampleRate": synthesis.sampleRate ?? 0,
                                    "bitsPerSample": synthesis.bitsPerSample ?? 0,
                                    "channelCount": synthesis.channelCount ?? 0,
                                    "byteCount": synthesis.byteCount,
                                    "decodedByteCount": pcmByteCount,
                                    "pcmCompatible": pcmCompatible,
                                    "audioDataOmitted": true,
                                ])
                                print(
                                    "[UI_QA] VoiceCloneSynthesisRuntimeSmoke completed " +
                                    "voiceProfileId=\(synthesis.voiceProfileId) " +
                                    "pcmCompatible=\(pcmCompatible) bytes=\(synthesis.byteCount)"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    func showVoiceCloneStatusFeedbackPreview() {
        let readyProfile = makeUIQAVoiceCloneProfile(
            voiceProfileId: "S_ready_preview",
            sampleStatus: .ready,
            providerStatus: "2",
            providerMessage: "ready",
            realCloneProviderReady: true,
            isEnabled: true
        )
        let snapshot = VoiceCloneService.shared.voiceCloneShellSnapshot(from: readyProfile)
        let viewController = ProfileVoiceCloneShellViewController(snapshot: snapshot)

        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController else {
            return
        }

        tabBarController.selectedIndex = 2
        profileNavigationController.popToRootViewController(animated: false)
        profileNavigationController.pushViewController(viewController, animated: false)
        print("[UI_QA] VoiceCloneStatusFeedbackPreview shown")
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

    func runOwnerTruthCandidateInboxSmoke(retryCount: Int = 0) {
        guard OwnerTruthCandidateReviewQAGate.isEnabled else {
            OwnerTruthCandidateInboxUIQASmoke.writeFailure("qaGateDisabled")
            return
        }
        guard let userID = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userID),
              accountLease.subjectId == userID,
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            guard retryCount < 20 else {
                OwnerTruthCandidateInboxUIQASmoke.writeFailure("accountLeaseUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthCandidateInboxSmoke(retryCount: retryCount + 1)
            }
            return
        }
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              keyWindow.rootViewController is WarmTabBarController else {
            guard retryCount < 20 else {
                OwnerTruthCandidateInboxUIQASmoke.writeFailure("mainRootUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthCandidateInboxSmoke(retryCount: retryCount + 1)
            }
            return
        }
        let controller = OwnerTruthCandidateInboxUIQASmoke.makeViewController(accountLease: accountLease)
        keyWindow.rootViewController = UINavigationController(rootViewController: controller)
        keyWindow.makeKeyAndVisible()
        print("[UI_QA] OwnerTruthCandidateInboxSmoke started")
    }

    func runOwnerTruthInterviewCandidateReviewSmoke(retryCount: Int = 0) {
        guard OwnerTruthCandidateReviewQAGate.isEnabled else {
            OwnerTruthInterviewCandidateReviewUIQASmoke.writeFailure("qaGateDisabled")
            return
        }
        guard let userID = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userID),
              accountLease.subjectId == userID,
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            guard retryCount < 20 else {
                OwnerTruthInterviewCandidateReviewUIQASmoke.writeFailure("accountLeaseUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewCandidateReviewSmoke(retryCount: retryCount + 1)
            }
            return
        }
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              keyWindow.rootViewController is WarmTabBarController else {
            guard retryCount < 20 else {
                OwnerTruthInterviewCandidateReviewUIQASmoke.writeFailure("mainRootUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewCandidateReviewSmoke(retryCount: retryCount + 1)
            }
            return
        }
        let controller = OwnerTruthInterviewCandidateReviewUIQASmoke.makeViewController(
            accountLease: accountLease
        )
        keyWindow.rootViewController = UINavigationController(rootViewController: controller)
        keyWindow.makeKeyAndVisible()
        print("[UI_QA] OwnerTruthInterviewCandidateReviewSmoke started")
    }

    func runOwnerTruthInterviewSessionStateSmoke(retryCount: Int = 0) {
        guard OwnerTruthCandidateReviewQAGate.isEnabled else {
            OwnerTruthInterviewSessionStateUIQASmoke.writeFailure("qaGateDisabled")
            return
        }
        guard let userID = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userID),
              accountLease.subjectId == userID,
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            guard retryCount < 20 else {
                OwnerTruthInterviewSessionStateUIQASmoke.writeFailure("accountLeaseUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewSessionStateSmoke(retryCount: retryCount + 1)
            }
            return
        }
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              keyWindow.rootViewController is WarmTabBarController else {
            guard retryCount < 20 else {
                OwnerTruthInterviewSessionStateUIQASmoke.writeFailure("mainRootUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewSessionStateSmoke(retryCount: retryCount + 1)
            }
            return
        }
        let controller = OwnerTruthInterviewSessionStateUIQASmoke.makeViewController(
            accountLease: accountLease
        )
        keyWindow.rootViewController = UINavigationController(rootViewController: controller)
        keyWindow.makeKeyAndVisible()
        print("[UI_QA] OwnerTruthInterviewSessionStateSmoke started")
    }

    func runOwnerTruthInterviewNaturalInputSmoke(retryCount: Int = 0) {
        guard OwnerTruthCandidateReviewQAGate.isEnabled else {
            OwnerTruthInterviewNaturalInputUIQASmoke.writeFailure("qaGateDisabled")
            return
        }
        guard let userID = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userID),
              accountLease.subjectId == userID,
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            guard retryCount < 20 else {
                OwnerTruthInterviewNaturalInputUIQASmoke.writeFailure("accountLeaseUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewNaturalInputSmoke(retryCount: retryCount + 1)
            }
            return
        }
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              keyWindow.rootViewController is WarmTabBarController else {
            guard retryCount < 20 else {
                OwnerTruthInterviewNaturalInputUIQASmoke.writeFailure("mainRootUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runOwnerTruthInterviewNaturalInputSmoke(retryCount: retryCount + 1)
            }
            return
        }
        let controller = OwnerTruthInterviewNaturalInputUIQASmoke.makeViewController(
            accountLease: accountLease
        )
        keyWindow.rootViewController = UINavigationController(rootViewController: controller)
        keyWindow.makeKeyAndVisible()
        print("[UI_QA] OwnerTruthInterviewNaturalInputSmoke started")
    }

    func runOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "OwnerTruthInterviewNaturalInputEchoSurfaceSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeOwnerTruthInterviewNaturalInputEchoSurfaceSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] OwnerTruthInterviewNaturalInputEchoSurfaceSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "entryVisible=\(result["entryVisible"] as? Bool == true) " +
                    "sheetPresented=\(result["sheetPresented"] as? Bool == true)"
                )
            }
        )
    }

    func runOwnerTruthInterviewNaturalInputProductSurfaceSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "OwnerTruthInterviewNaturalInputProductSurfaceSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runOwnerTruthInterviewNaturalInputProductSurfaceSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeOwnerTruthInterviewNaturalInputProductSurfaceSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAOwnerTruthInterviewNaturalInputProductSurfaceSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] OwnerTruthInterviewNaturalInputProductSurfaceSmoke completed " +
                    "completed=\\(result[\"completed\"] as? Bool == true) " +
                    "productEntryVisible=\\(result[\"productEntryVisible\"] as? Bool == true) " +
                    "sheetPresented=\\(result[\"sheetPresented\"] as? Bool == true)"
                )
            }
        )
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
                && releaseOptionTitles.contains("录入时间信件")
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

            for item in [audioItem, videoItem, videoPlaceholderItem, draftLetter, deletedDraftLetter, sealedDraftLetter, sealedLetter] {
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
                && restoredSealed?.metadata["deliveryPolicy"] == "scheduled_local_and_in_app"
            let timeLetterDraftDeliveryContractPersisted = restoredDraft?.metadata["deliveryPolicy"] == "draft"
                && restoredDraft?.metadata[MemoryArchiveItem.timeLetterDeliveryStatusMetadataKey] == "draft"
                && restoredDraft?.metadata[MemoryArchiveItem.timeLetterNotificationScheduledMetadataKey] == "false"
            let timeLetterSealedDeliveryContractPersisted =
                restoredSealedDraft?.metadata["deliveryPolicy"] == "scheduled_local_and_in_app"
                && restoredSealedDraft?.metadata[MemoryArchiveItem.timeLetterDeliveryProviderStateMetadataKey] == "local_notification_and_in_app"
                && restoredSealedDraft?.metadata[MemoryArchiveItem.timeLetterNotificationScheduledMetadataKey] == "true"
                && restoredSealed?.metadata["deliveryPolicy"] == "scheduled_local_and_in_app"
                && restoredSealed?.metadata[MemoryArchiveItem.timeLetterDeliveryProviderStateMetadataKey] == "local_notification_and_in_app"
            let timeLetterBackendPayload = sealedDraftLetter.archiveBackendPayload(
                userId: "user_9999",
                viewerUserId: "user_9999",
                ownerId: "user_9999",
                personaScope: "personal",
                digitalHumanId: "user_9999"
            )
            let timeLetterBackendPayloadScheduled =
                !(timeLetterBackendPayload["openAt"] as? String ?? "").isEmpty
                && ((timeLetterBackendPayload["recipients"] as? [[String: Any]])?.isEmpty == false)
                && ((timeLetterBackendPayload["sealedAt"] as? String)?.isEmpty == false)
                && (timeLetterBackendPayload["deliveryStatus"] as? String) == "scheduled"
                && (timeLetterBackendPayload["deliveryExecutionState"] as? String) == "scheduled"
                && (timeLetterBackendPayload["deliveryDecisionState"] as? String) == "confirmed"
                && (timeLetterBackendPayload["deliveryScheduleState"] as? String) == "scheduled"
                && (timeLetterBackendPayload["deliveryProviderState"] as? String) == "local_notification_and_in_app"
                && (timeLetterBackendPayload["deliveryNotificationScheduled"] as? Bool) == true
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
            let videoTimelineThumbnailVisible = archiveHomeViewContainsIdentifier("archive-video-timeline-thumbnail")
            let videoTimelinePlaceholderVisible = archiveHomeViewContainsIdentifier("archive-video-timeline-placeholder")
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
            ) && archiveDetailViewContainsText("已封存", item: sealedDraftLetter)
            let timeLetterSealedDetailVisible = timeLetterSealedStateVisible
            let timeLetterReminderPolicyVisible = archiveDetailViewContainsIdentifier(
                "archive-time-letter-delivery-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsIdentifier(
                "archive-time-letter-lock-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsIdentifier(
                "archive-time-letter-notification-state",
                item: sealedDraftLetter
            ) && archiveDetailViewContainsText("不可删除或修改", item: sealedDraftLetter)
                && archiveDetailViewContainsText("本地通知 + 应用内提醒", item: sealedDraftLetter)
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
                && timeLetterDraftDeliveryContractPersisted
                && timeLetterSealedDeliveryContractPersisted
                && timeLetterBackendPayloadScheduled
                && mediaDetailEmptyStateVisible
                && mediaDetailFailedStateVisible
                && mediaDetailRetryActionVisible
                && audioDetailEmptyStateVisible
                && audioDetailTranscriptionFailedStateVisible
                && audioDetailTranscriptionRetryVisible
                && videoDetailThumbnailPlaceholderVisible
                && videoDetailFailedStateVisible
                && videoDetailRetryActionVisible
                && videoTimelineThumbnailVisible
                && videoTimelinePlaceholderVisible
                && hiddenMediaRuntimeCardVisible
                && hiddenMediaRuntimeProviderVisible
                && hiddenMediaRuntimeLimitVisible
                && hiddenMediaRuntimeUploadModeVisible
                && hiddenMediaRuntimeMockCopyVisible
                && timeLetterDraftActionsVisible
                && timeLetterSealedStateVisible
                && timeLetterDraftDetailVisible
                && timeLetterSealedDetailVisible
                && timeLetterReminderPolicyVisible
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
                timeLetterDraftDeliveryContractPersisted: timeLetterDraftDeliveryContractPersisted,
                timeLetterSealedDeliveryContractPersisted: timeLetterSealedDeliveryContractPersisted,
                timeLetterBackendPayloadScheduled: timeLetterBackendPayloadScheduled,
                mediaDetailEmptyStateVisible: mediaDetailEmptyStateVisible,
                mediaDetailFailedStateVisible: mediaDetailFailedStateVisible,
                mediaDetailRetryActionVisible: mediaDetailRetryActionVisible,
                audioDetailEmptyStateVisible: audioDetailEmptyStateVisible,
                audioDetailTranscriptionFailedStateVisible: audioDetailTranscriptionFailedStateVisible,
                audioDetailTranscriptionRetryVisible: audioDetailTranscriptionRetryVisible,
                videoDetailThumbnailPlaceholderVisible: videoDetailThumbnailPlaceholderVisible,
                videoDetailFailedStateVisible: videoDetailFailedStateVisible,
                videoDetailRetryActionVisible: videoDetailRetryActionVisible,
                videoTimelineThumbnailVisible: videoTimelineThumbnailVisible,
                videoTimelinePlaceholderVisible: videoTimelinePlaceholderVisible,
                hiddenMediaRuntimeCardVisible: hiddenMediaRuntimeCardVisible,
                hiddenMediaRuntimeProviderVisible: hiddenMediaRuntimeProviderVisible,
                hiddenMediaRuntimeLimitVisible: hiddenMediaRuntimeLimitVisible,
                hiddenMediaRuntimeUploadModeVisible: hiddenMediaRuntimeUploadModeVisible,
                hiddenMediaRuntimeMockCopyVisible: hiddenMediaRuntimeMockCopyVisible,
                timeLetterDraftActionsVisible: timeLetterDraftActionsVisible,
                timeLetterSealedStateVisible: timeLetterSealedStateVisible,
                timeLetterDraftDetailVisible: timeLetterDraftDetailVisible,
                timeLetterSealedDetailVisible: timeLetterSealedDetailVisible,
                timeLetterReminderPolicyVisible: timeLetterReminderPolicyVisible,
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

    func archiveHomeViewContainsIdentifier(_ identifier: String) -> Bool {
        let archiveViewController = MemoryArchiveViewController(repository: .shared)
        archiveViewController.loadViewIfNeeded()
        guard let view = archiveViewController.viewIfLoaded else {
            return false
        }
        return viewTreeContainsIdentifier(identifier, in: view)
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

    @discardableResult
    func seedPendingArchiveAnalysisContext() -> Bool {
        UserManager.shared.login(phone: "13800009999", nickname: "UI QA")
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.user_9999")

        let item = MemoryArchiveItemFactory.makePhotoItem(localPath: "/tmp/uiqa-pending-photo.jpg")
        let didAdd = MemoryArchiveRepository.shared.add(item, syncToBackend: false)

        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        print(
            "[UI_QA] Seeded pending archive analysis " +
            "inserted=\(didAdd) available=\(snapshot.availableItemCount)"
        )
        return didAdd
    }

    func prepareArchiveMediaEchoContextSmoke(retryCount: Int = 0) {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId),
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            guard retryCount < 40 else {
                print("[UI_QA] ArchiveMediaEchoContextSmoke failed reason=accountLeaseUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.prepareArchiveMediaEchoContextSmoke(retryCount: retryCount + 1)
            }
            return
        }

        DigitalHumanContextStore.shared.current = .defaultContext(userId: userId)
        let scope = ArchiveStorageScope(accountLease: accountLease, archiveOwnerId: userId)
        ArchiveLocalStorage.shared.purge(scope: scope)
        seedArchiveMediaEchoContext(ownerUserId: userId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.runArchiveMediaEchoContextSmoke()
        }
    }

    func seedArchiveMediaEchoContext(ownerUserId: String) {

        let audioItem = MemoryArchiveItemFactory.makeAudioItem(
            localPath: "/tmp/uiqa-media-context-audio.m4a",
            duration: 9,
            note: "这段语音说明不应覆盖已转写文本",
            transcriptText: "妈妈在厨房讲起桂花糕的声音",
            ownerUserId: ownerUserId
        )

        var videoItem = MemoryArchiveItemFactory.makeVideoItem(
            localPath: "/tmp/uiqa-media-context-video.mov",
            note: "视频里记录了院子里的桂花树",
            analysisStatus: .pending,
            ownerUserId: ownerUserId
        )
        videoItem.detectedPeople = ["不应注入视频人物"]
        videoItem.tags = ["不应注入视频标签"]
        videoItem.metadata[MemoryArchiveItem.analysisLocationCluesMetadataKey] = "不应注入视频地点"
        videoItem.metadata[MemoryArchiveItem.analysisSceneCluesMetadataKey] = "不应注入视频场景"

        let draftLetter = MemoryArchiveItemFactory.makeTimeLetterDraft(
            note: "这封草稿不应进入回响上下文",
            ownerUserId: ownerUserId
        )
        var sealedLetter = MemoryArchiveItemFactory.makeTimeLetter(
            note: "这封封存信可以进入回响上下文",
            ownerUserId: ownerUserId
        )
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

    func runArchiveToEchoSmoke(retryCount: Int = 0, hasSeededItem: Bool = false) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                writeArchiveToEchoSmokeResult(
                    completed: false,
                    containsArchiveContext: false,
                    availableItemCount: 0,
                    entries: "",
                    failureReason: "missingRootTab"
                )
                print("[UI_QA] ArchiveToEchoSmoke failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveToEchoSmoke(
                    retryCount: retryCount + 1,
                    hasSeededItem: hasSeededItem
                )
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let archiveNavigationController = viewControllers.first as? UINavigationController,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            writeArchiveToEchoSmokeResult(
                completed: false,
                containsArchiveContext: false,
                availableItemCount: 0,
                entries: "",
                failureReason: "missingSmokeDependencies"
            )
            print("[UI_QA] ArchiveToEchoSmoke failed reason=missingSmokeDependencies")
            return
        }

        guard hasSeededItem else {
            let didSeedItem = self.seedPendingArchiveAnalysisContext()
            guard didSeedItem else {
                writeArchiveToEchoSmokeResult(
                    completed: false,
                    containsArchiveContext: false,
                    availableItemCount: 0,
                    entries: "",
                    failureReason: "archiveSeedUnavailable"
                )
                print("[UI_QA] ArchiveToEchoSmoke failed reason=archiveSeedUnavailable")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runArchiveToEchoSmoke(
                    retryCount: retryCount,
                    hasSeededItem: true
                )
            }
            return
        }

        guard let item = MemoryArchiveRepository.shared.allItems().first else {
            writeArchiveToEchoSmokeResult(
                completed: false,
                containsArchiveContext: false,
                availableItemCount: 0,
                entries: "",
                failureReason: "seededArchiveItemUnavailable"
            )
            print("[UI_QA] ArchiveToEchoSmoke failed reason=seededArchiveItemUnavailable")
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

    func runTimeLetterDispatchReminderSmoke() {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId),
              AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed else {
            writeTimeLetterDispatchReminderSmokeResult([
                "completed": false,
                "failureReason": "accountLeaseUnavailable",
            ])
            print("[UI_QA] TimeLetterDispatchReminderSmoke failed reason=accountLeaseUnavailable")
            return
        }
        let resourceOwnerId = accountLease.subjectId
        let messageOperationId = "time-letter-dispatch-reminder-uiqa"
        UserDefaults.standard.removeObject(forKey: "dj.memoryArchive.items.\(userId)")
        _ = EchoReplyMessageStore.shared.clear(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: messageOperationId
        )

        var deliveredLetter = MemoryArchiveItemFactory.makeTimeLetter(
            note: "这封信已由后端投递，不应再被本地 due 计数重复计算。",
            openAt: Date().addingTimeInterval(-3600),
            recipients: [
                TimeLetterRecipientSelection(id: "self", name: "我"),
                TimeLetterRecipientSelection(id: "family-uiqa", name: "林静文"),
            ]
        )
        deliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryStatusMetadataKey] = "delivered"
        deliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryExecutionStateMetadataKey] = "delivered"
        deliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryScheduleStateMetadataKey] = "dispatched"
        deliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryProviderStateMetadataKey] = "local_notification_and_in_app"
        deliveredLetter.metadata["deliveredAt"] = ISO8601DateFormatter().string(from: Date())

        var secondDeliveredLetter = MemoryArchiveItemFactory.makeTimeLetter(
            note: "第二封到达的时间信件，用于验证提醒中心支持多封提醒。",
            openAt: Date().addingTimeInterval(-1800),
            recipients: [
                TimeLetterRecipientSelection(id: "self", name: "我"),
            ]
        )
        secondDeliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryStatusMetadataKey] = "delivered"
        secondDeliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryExecutionStateMetadataKey] = "delivered"
        secondDeliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryScheduleStateMetadataKey] = "dispatched"
        secondDeliveredLetter.metadata[MemoryArchiveItem.timeLetterDeliveryProviderStateMetadataKey] = "local_notification_and_in_app"
        secondDeliveredLetter.metadata["deliveredAt"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))

        MemoryArchiveRepository.shared.add(deliveredLetter, syncToBackend: false)
        MemoryArchiveRepository.shared.add(secondDeliveredLetter, syncToBackend: false)

        let reminder = TimeLetterMailboxReminder([
            "id": "time-letter-\(deliveredLetter.id)-self",
            "kind": "timeLetterReminder",
            "sourceArchiveItemId": deliveredLetter.id,
            "title": "时间信件已到打开时间",
            "status": "unread",
            "deliveredAt": deliveredLetter.metadata["deliveredAt"] ?? "",
            "recipientRole": "owner",
            "metadataOnly": true,
            "contentRedacted": true,
        ])
        let secondReminder = TimeLetterMailboxReminder([
            "id": "time-letter-\(secondDeliveredLetter.id)-self",
            "kind": "timeLetterReminder",
            "sourceArchiveItemId": secondDeliveredLetter.id,
            "title": "给未来的自己",
            "status": "unread",
            "deliveredAt": secondDeliveredLetter.metadata["deliveredAt"] ?? "",
            "recipientRole": "owner",
            "metadataOnly": true,
            "contentRedacted": true,
        ])
        let mailboxFixtureInjectionSucceeded: Bool
        if let reminder, let secondReminder {
            mailboxFixtureInjectionSucceeded = MemoryArchiveRepository.shared
                .replaceCachedTimeLetterMailboxReminders(
                    [reminder, secondReminder],
                    accountLease: accountLease
                )
        } else {
            mailboxFixtureInjectionSucceeded = false
        }

        let pendingFamilyMember = FamilyMember(
            id: "family-invite-pending-uiqa",
            name: "陈岚",
            relation: "女儿",
            phone: "13900001111",
            isOnline: false,
            lastUpdated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120)),
            relationshipOwnerUserId: userId,
            relationshipAuthoritySource: .qaFixture,
            accessStatus: "pending",
            invitationStatus: "pending"
        )
        let failedFamilyMember = FamilyMember(
            id: "family-invite-failed-uiqa",
            name: "周启明",
            relation: "哥哥",
            phone: "13900002222",
            isOnline: false,
            lastUpdated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-180)),
            relationshipOwnerUserId: userId,
            relationshipAuthoritySource: .qaFixture,
            accessStatus: "failed",
            invitationStatus: "failed",
            invitationError: "手机号暂不可达"
        )
        let acceptedFamilyMember = FamilyMember(
            id: "family-invite-accepted-uiqa",
            name: "李安然",
            relation: "妹妹",
            phone: "13900003333",
            isOnline: true,
            lastUpdated: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60)),
            relationshipOwnerUserId: userId,
            relationshipAuthoritySource: .qaFixture,
            accessStatus: "active",
            invitationStatus: "accepted"
        )
        FamilyRepository.shared.add(pendingFamilyMember)
        FamilyRepository.shared.add(failedFamilyMember)
        FamilyRepository.shared.add(acceptedFamilyMember)
        let familyInvitationSources = FamilyRepository.shared.getAll().map { $0 as FamilyInvitationMessageSource }
        let now = ISO8601DateFormatter().string(from: Date())
        let careSignalSources: [CareSignalMessageSource] = [
            StaticCareSignalMessageSource(
                careSignalId: "care-signal-failed-uiqa",
                careSignalTitle: "关怀信号加载失败",
                careSignalSummary: "心境追踪暂时无法同步，请稍后重试。",
                careSignalStatus: "failed",
                careSignalSeverity: "failed",
                careSignalUpdatedAt: now,
                careSignalOwnerUserId: userId
            ),
            StaticCareSignalMessageSource(
                careSignalId: "care-signal-stale-uiqa",
                careSignalTitle: "关怀信号可能过期",
                careSignalSummary: "关怀数据不是最新，当前展示本地安全状态。",
                careSignalStatus: "stale",
                careSignalSeverity: "stale",
                careSignalUpdatedAt: now,
                careSignalOwnerUserId: userId
            ),
            StaticCareSignalMessageSource(
                careSignalId: "care-signal-attention-uiqa",
                careSignalTitle: "心境状态需要关注",
                careSignalSummary: "近期心境趋势需要家人留意。",
                careSignalStatus: "available",
                careSignalSeverity: "needsAttention",
                careSignalUpdatedAt: now,
                careSignalOwnerUserId: userId
            ),
            StaticCareSignalMessageSource(
                careSignalId: "care-signal-normal-uiqa",
                careSignalTitle: "关怀信号平稳",
                careSignalSummary: "当前没有需要提醒的关怀状态。",
                careSignalStatus: "available",
                careSignalSeverity: "normal",
                careSignalUpdatedAt: now,
                careSignalOwnerUserId: userId
            ),
        ]
        let systemNoticeSources: [SystemNoticeMessageSource] = [
            StaticSystemNoticeMessageSource(
                systemNoticeId: "system-notice-release-uiqa",
                systemNoticeTitle: "系统维护通知",
                systemNoticeSummary: "今晚会进行短时维护，期间可能影响云端同步。",
                systemNoticeStatus: "published",
                systemNoticeCategory: "maintenance",
                systemNoticeSeverity: "info",
                systemNoticeUpdatedAt: now,
                resourceOwnerId: resourceOwnerId
            ),
            StaticSystemNoticeMessageSource(
                systemNoticeId: "system-notice-draft-uiqa",
                systemNoticeTitle: "未发布系统通知",
                systemNoticeSummary: "这条草稿不应进入消息中心。",
                systemNoticeStatus: "draft",
                systemNoticeCategory: "debug",
                systemNoticeSeverity: "info",
                systemNoticeUpdatedAt: now,
                resourceOwnerId: resourceOwnerId
            ),
        ]
        let echoReplySaved = EchoReplyMessageStore.shared.save([
            StaticEchoReplyMessageSource(
                echoReplyId: "echo-delayed-reply-uiqa",
                echoReplyTitle: "回响回信已抵达",
                echoReplySummary: "之前等待的回响已经准备好，可以继续对话。",
                echoReplyStatus: "unread",
                echoReplyDeliveredAt: now,
                echoReplyTrigger: "contentSignal",
                resourceOwnerId: resourceOwnerId
            ),
        ], accountLease: accountLease,
           resourceOwnerId: resourceOwnerId,
           operationId: messageOperationId)
        let echoReplySources = EchoReplyMessageStore.shared.sources(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: messageOperationId
        )

        let dueLetters = MemoryArchiveRepository.shared.dueTimeLetters()
        let mailboxReminders = MemoryArchiveRepository.shared.timeLetterMailboxReminders()
        let inAppMessageSnapshot = MemoryArchiveRepository.shared.inAppMessageCenterSnapshot(
            accountLease: accountLease,
            familyInvitationSources: familyInvitationSources,
            careSignalSources: careSignalSources,
            echoReplySources: echoReplySources,
            systemNoticeSources: systemNoticeSources
        )
        let reminderCount = MemoryArchiveRepository.shared.timeLetterReminderCount()
        let restoredDelivered = MemoryArchiveRepository.shared.allItems().first { $0.id == deliveredLetter.id }
        var resolvedReminderDetail: MemoryArchiveItem?
        if let reminder {
            MemoryArchiveRepository.shared.resolveTimeLetterReminderDetail(reminder) { result in
                if case .success(let item) = result {
                    resolvedReminderDetail = item
                }
            }
        }
        let reminderDetailResolved = resolvedReminderDetail?.id == deliveredLetter.id
        let reminderDetailNoteVisible = resolvedReminderDetail?.note == deliveredLetter.note
        let reminderDetailSnapshotWritten = resolvedReminderDetail.map {
            renderArchiveDetailSnapshot(
                fileName: "time-letter-reminder-detail.png",
                item: $0
            )
        } ?? false
        if let reminder {
            MemoryArchiveRepository.shared.markTimeLetterMailboxReminderRead(reminder)
        }
        let remindersAfterRead = MemoryArchiveRepository.shared.timeLetterMailboxReminders()
        let openedReminderId = reminder?.id
        let reminderReadStatusPersisted = openedReminderId.map { reminderId in
            remindersAfterRead.first(where: { $0.id == reminderId })?.isUnread == false
        } ?? false
        let secondReminderStillUnread = secondReminder.map { reminder in
            remindersAfterRead.first(where: { $0.id == reminder.id })?.isUnread == true
        } ?? false
        let reminderCountAfterRead = MemoryArchiveRepository.shared.timeLetterReminderCount()
        if let openedReminderId,
           let readReminder = remindersAfterRead.first(where: { $0.id == openedReminderId }) {
            MemoryArchiveRepository.shared.markTimeLetterMailboxReminderArchived(readReminder)
        }
        let remindersAfterArchive = MemoryArchiveRepository.shared.timeLetterMailboxReminders()
        let inAppMessageSnapshotAfterArchive = MemoryArchiveRepository.shared.inAppMessageCenterSnapshot(
            accountLease: accountLease,
            familyInvitationSources: familyInvitationSources,
            careSignalSources: careSignalSources,
            echoReplySources: echoReplySources,
            systemNoticeSources: systemNoticeSources
        )
        let familyInvitationMessageCount = inAppMessageSnapshot.sourceCounts["familyInvitation"] ?? 0
        let careSignalMessageCount = inAppMessageSnapshot.sourceCounts["careSignal"] ?? 0
        let systemNoticeMessageCount = inAppMessageSnapshot.sourceCounts["systemNotice"] ?? 0
        let echoReplyMessageCount = inAppMessageSnapshot.sourceCounts["echoReply"] ?? 0
        let inAppMessageCenterEntryTitle = inAppMessageSnapshot.entryButtonTitle(timeLetterReminderCount: reminderCount) ?? ""
        let reminderArchiveStatusPersisted = openedReminderId.map { reminderId in
            remindersAfterArchive.first(where: { $0.id == reminderId })?.isArchived == true
        } ?? false
        let secondReminderStillUnreadAfterArchive = secondReminder.map { reminder in
            remindersAfterArchive.first(where: { $0.id == reminder.id })?.isUnread == true
        } ?? false
        let reminderCountAfterArchive = MemoryArchiveRepository.shared.timeLetterReminderCount()
        let completed = reminder != nil
            && secondReminder != nil
            && mailboxFixtureInjectionSucceeded
            && restoredDelivered?.timeLetterDeliveryStatus == "delivered"
            && restoredDelivered?.isTimeLetterDelivered == true
            && dueLetters.contains(where: { $0.id == deliveredLetter.id }) == false
            && dueLetters.contains(where: { $0.id == secondDeliveredLetter.id }) == false
            && mailboxReminders.map(\.sourceArchiveItemId).contains(deliveredLetter.id)
            && mailboxReminders.map(\.sourceArchiveItemId).contains(secondDeliveredLetter.id)
            && inAppMessageSnapshot.totalCount == 9
            && inAppMessageSnapshot.sourceCounts["timeLetter"] == 2
            && familyInvitationMessageCount == 2
            && careSignalMessageCount == 3
            && systemNoticeMessageCount == 1
            && echoReplySaved
            && echoReplyMessageCount == 1
            && inAppMessageCenterEntryTitle == "9 条消息待处理 · 查看"
            && reminderCount == 2
            && reminderDetailResolved
            && reminderDetailNoteVisible
            && reminderDetailSnapshotWritten
            && reminderReadStatusPersisted
            && secondReminderStillUnread
            && reminderCountAfterRead == 1
            && reminderArchiveStatusPersisted
            && secondReminderStillUnreadAfterArchive
            && inAppMessageSnapshotAfterArchive.archivedCount == 1
            && inAppMessageSnapshotAfterArchive.unreadCount == 8
            && reminderCountAfterArchive == 1

        writeTimeLetterDispatchReminderSmokeResult([
            "completed": completed,
            "userId": userId,
            "itemId": deliveredLetter.id,
            "secondItemId": secondDeliveredLetter.id,
            "deliveryStatus": restoredDelivered?.timeLetterDeliveryStatus ?? "missing",
            "dueLetterIds": dueLetters.map(\.id),
            "mailboxReminderIds": mailboxReminders.map(\.id),
            "mailboxSourceArchiveItemIds": mailboxReminders.map(\.sourceArchiveItemId),
            "mailboxFixtureInjectionSucceeded": mailboxFixtureInjectionSucceeded,
            "inAppMessageCenterKindCounts": inAppMessageSnapshot.sourceCounts,
            "inAppMessageCenterEntryTitle": inAppMessageCenterEntryTitle,
            "inAppMessageCenterUnreadCount": inAppMessageSnapshot.unreadCount,
            "inAppMessageCenterArchivedCountAfterArchive": inAppMessageSnapshotAfterArchive.archivedCount,
            "familyInvitationMessageCount": familyInvitationMessageCount,
            "familyAcceptedInvitationExcluded": inAppMessageSnapshot.messages.contains { $0.familyMemberId == acceptedFamilyMember.id } == false,
            "careSignalMessageCount": careSignalMessageCount,
            "careNormalSignalExcluded": inAppMessageSnapshot.messages.contains { $0.careSignalId == "care-signal-normal-uiqa" } == false,
            "systemNoticeMessageCount": systemNoticeMessageCount,
            "systemDraftNoticeExcluded": inAppMessageSnapshot.messages.contains { $0.systemNoticeId == "system-notice-draft-uiqa" } == false,
            "echoReplyOwnerScopedSaveSucceeded": echoReplySaved,
            "echoReplyMessageCount": echoReplyMessageCount,
            "reminderCount": reminderCount,
            "timeLetterReminderDetailResolved": reminderDetailResolved,
            "timeLetterReminderDetailNoteVisible": reminderDetailNoteVisible,
            "timeLetterReminderDetailSnapshotWritten": reminderDetailSnapshotWritten,
            "timeLetterReminderReadStatusPersisted": reminderReadStatusPersisted,
            "timeLetterSecondReminderStillUnread": secondReminderStillUnread,
            "timeLetterReminderCountAfterRead": reminderCountAfterRead,
            "timeLetterReminderArchiveStatusPersisted": reminderArchiveStatusPersisted,
            "timeLetterSecondReminderStillUnreadAfterArchive": secondReminderStillUnreadAfterArchive,
            "timeLetterReminderCountAfterArchive": reminderCountAfterArchive,
        ])
        print(
            "[UI_QA] TimeLetterDispatchReminderSmoke completed " +
            "completed=\(completed) reminderCount=\(reminderCount)"
        )
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

    func showVoiceSDKReadinessPreview(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] VoiceSDKReadinessPreview failed reason=missingRootTab")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showVoiceSDKReadinessPreview(retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            print("[UI_QA] VoiceSDKReadinessPreview failed reason=missingEcho")
            return
        }

        tabBarController.selectedIndex = 1
        echoViewController.runUIQAVoiceSDKReadinessPreview()
        print("[UI_QA] VoiceSDKReadinessPreview showing readiness boundary")
    }

    func runDigitalHumanLivePanelSmoke(retryCount: Int = 0) {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController else {
            guard retryCount < 20 else {
                print("[UI_QA] DigitalHumanLivePanelSmoke failed reason=missingRootTab")
                writeDigitalHumanLivePanelSmokeResult([
                    "completed": false,
                    "failureReason": "missingRootTab"
                ])
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.runDigitalHumanLivePanelSmoke(retryCount: retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            print("[UI_QA] DigitalHumanLivePanelSmoke failed reason=missingEcho")
            writeDigitalHumanLivePanelSmokeResult([
                "completed": false,
                "failureReason": "missingEcho"
            ])
            return
        }

        tabBarController.selectedIndex = 1
        echoViewController.runUIQADigitalHumanLivePanelSmoke { [weak self] payload in
            var result = payload
            result["selectedTabIndex"] = tabBarController.selectedIndex
            self?.writeDigitalHumanLivePanelSmokeResult(result)
            print(
                "[UI_QA] DigitalHumanLivePanelSmoke completed " +
                "completed=\(result["completed"] as? Bool == true) " +
                "state=\(result["stateName"] as? String ?? "missing") " +
                "panelReady=\(result["panelReady"] as? Bool == true)"
            )
        }
    }

    func runDigitalHumanRuntimeStubSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "DigitalHumanRuntimeStubSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runDigitalHumanRuntimeStubSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeDigitalHumanRuntimeStubSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQADigitalHumanRuntimeStubSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] DigitalHumanRuntimeStubSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "provider=\(result["provider"] as? String ?? "missing") " +
                    "fallback=\(result["fallbackMode"] as? String ?? "missing")"
                )
            }
        )
    }

    func runTencentBackendPCMDriveMockSmoke(retryCount: Int = 0) {
        let voiceProfileId = uiqaArgumentValue(prefix: "DJTencentBackendPCMDriveMockVoiceProfileId=") ?? "S_uiqa_tencent_pcm_mock"
        let userId = uiqaArgumentValue(prefix: "DJTencentBackendPCMDriveMockUserId=")
            ?? UserManager.shared.currentUser?.id
            ?? "uiqa_tencent_backend_pcm_mock"
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "TencentBackendPCMDriveMockSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runTencentBackendPCMDriveMockSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeTencentBackendPCMDriveMockSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQATencentBackendPCMDriveMockSmoke(
                    voiceProfileId: voiceProfileId,
                    userId: userId,
                    completion: completion
                )
            },
            completionLog: { result in
                print(
                    "[UI_QA] TencentBackendPCMDriveMockSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "chunks=\(result["pcmChunkCount"] as? Int ?? 0) " +
                    "final=\(result["finalChunkObserved"] as? Bool == true)"
                )
            }
        )
    }

    func runEchoTraceExportSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoTraceExportSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoTraceExportSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoTraceExportSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoTraceExportSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoTraceExportSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "recordCount=\(result["recordCount"] as? Int ?? 0) " +
                    "latestTurnID=\(result["latestTurnID"] as? String ?? "missing")"
                )
            }
        )
    }

    func runEchoRuntimeDiagnosticsExportSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoRuntimeDiagnosticsExportSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoRuntimeDiagnosticsExportSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoRuntimeDiagnosticsExportSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoRuntimeDiagnosticsExportSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoRuntimeDiagnosticsExportSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "snapshotCount=\(result["snapshotCount"] as? Int ?? 0) " +
                    "latestTurnID=\(result["latestTurnID"] as? String ?? "missing")"
                )
            }
        )
    }

    func runEchoDigitalHumanLifecycleSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoDigitalHumanLifecycleSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoDigitalHumanLifecycleSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoDigitalHumanLifecycleSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoDigitalHumanLifecycleSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoDigitalHumanLifecycleSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "suspended=\(result["lifecycleSuspended"] as? Bool == true) " +
                    "restored=\(result["lifecycleRestored"] as? Bool == true) " +
                    "microphoneAutoStart=\(result["microphoneAutoStart"] as? Bool == true)"
                )
            }
        )
    }

    func runEchoContinuousTurnSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoContinuousTurnSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoContinuousTurnSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoContinuousTurnSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoContinuousTurnSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoContinuousTurnSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "firstTurn=\(result["firstTurnCompleted"] as? Bool == true) " +
                    "secondTurn=\(result["secondTurnCompleted"] as? Bool == true) " +
                    "staleReplyRejected=\(result["staleReplyRejected"] as? Bool == true)"
                )
            }
        )
    }

    func runEchoTraceEvidencePackageExportSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoTraceEvidencePackageExportSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoTraceEvidencePackageExportSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoTraceEvidencePackageExportSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoTraceEvidencePackageExportSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoTraceEvidencePackageExportSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "packageCount=\(result["packageCount"] as? Int ?? 0) " +
                    "latestTurnID=\(result["latestTurnID"] as? String ?? "missing")"
                )
            }
        )
    }

    func runEchoTraceEvidencePackagePanelExportSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoTraceEvidencePackagePanelExportSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoTraceEvidencePackagePanelExportSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoTraceEvidencePackagePanelExportSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoTraceEvidencePackagePanelExportSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoTraceEvidencePackagePanelExportSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "buttonVisible=\(result["buttonVisible"] as? Bool == true) " +
                    "latestTurnID=\(result["latestTurnID"] as? String ?? "missing")"
                )
            }
        )
    }

    func runEchoQAEvidenceBundleExportSmoke(retryCount: Int = 0) {
        QAEchoScenarioRunner.run(
            retryCount: retryCount,
            smokeName: "EchoQAEvidenceBundleExportSmoke",
            retry: { [weak self] nextRetryCount in
                self?.runEchoQAEvidenceBundleExportSmoke(retryCount: nextRetryCount)
            },
            writeResult: { [weak self] result in
                self?.writeEchoQAEvidenceBundleExportSmokeResult(result)
            },
            execute: { echoViewController, completion in
                echoViewController.runUIQAEchoQAEvidenceBundleExportSmoke(completion: completion)
            },
            completionLog: { result in
                print(
                    "[UI_QA] EchoQAEvidenceBundleExportSmoke completed " +
                    "completed=\(result["completed"] as? Bool == true) " +
                    "schemaVersion=\(result["schemaVersion"] as? Int ?? 0) " +
                    "latestTurnID=\(result["latestTurnID"] as? String ?? "missing")"
                )
            }
        )
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
        completed: Bool = true,
        containsArchiveContext: Bool,
        availableItemCount: Int,
        entries: String,
        failureReason: String? = nil
    ) {
        var result: [String: Any] = [
            "completed": completed,
            "containsArchiveContext": containsArchiveContext,
            "availableItemCount": availableItemCount,
            "entries": entries
        ]
        if let failureReason {
            result["failureReason"] = failureReason
        }

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

    func writeTimeLetterDispatchReminderSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] TimeLetterDispatchReminderSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("time-letter-dispatch-reminder-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] TimeLetterDispatchReminderSmoke failed reason=resultWrite error=\(error.localizedDescription)")
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
        QAProfileScenarioRunner.writeResult(
            result,
            fileName: "profile-care-escalation-boundary-smoke-result.json",
            smokeName: "ProfileCareEscalationBoundarySmoke"
        )
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

        QAProfileScenarioRunner.writeResult(
            result,
            fileName: "profile-care-state-smoke-result.json",
            smokeName: "ProfileCareStateSmoke"
        )
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

        QAProfileScenarioRunner.writeResult(
            result,
            fileName: "profile-care-backend-state-smoke-result.json",
            smokeName: "ProfileCareBackendStateSmoke"
        )
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

        QAProfileScenarioRunner.writeResult(
            result,
            fileName: "profile-care-backend-failure-retry-smoke-result.json",
            smokeName: "ProfileCareBackendFailureRetrySmoke"
        )
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
        timeLetterDraftDeliveryContractPersisted: Bool = false,
        timeLetterSealedDeliveryContractPersisted: Bool = false,
        timeLetterBackendPayloadScheduled: Bool = false,
        mediaDetailEmptyStateVisible: Bool,
        mediaDetailFailedStateVisible: Bool,
        mediaDetailRetryActionVisible: Bool,
        audioDetailEmptyStateVisible: Bool = false,
        audioDetailTranscriptionFailedStateVisible: Bool = false,
        audioDetailTranscriptionRetryVisible: Bool = false,
        videoDetailThumbnailPlaceholderVisible: Bool = false,
        videoDetailFailedStateVisible: Bool = false,
        videoDetailRetryActionVisible: Bool = false,
        videoTimelineThumbnailVisible: Bool = false,
        videoTimelinePlaceholderVisible: Bool = false,
        hiddenMediaRuntimeCardVisible: Bool = false,
        hiddenMediaRuntimeProviderVisible: Bool = false,
        hiddenMediaRuntimeLimitVisible: Bool = false,
        hiddenMediaRuntimeUploadModeVisible: Bool = false,
        hiddenMediaRuntimeMockCopyVisible: Bool = false,
        timeLetterDraftActionsVisible: Bool,
        timeLetterSealedStateVisible: Bool,
        timeLetterDraftDetailVisible: Bool = false,
        timeLetterSealedDetailVisible: Bool = false,
        timeLetterReminderPolicyVisible: Bool = false,
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
            "timeLetterDraftDeliveryContractPersisted": timeLetterDraftDeliveryContractPersisted,
            "timeLetterSealedDeliveryContractPersisted": timeLetterSealedDeliveryContractPersisted,
            "timeLetterBackendPayloadScheduled": timeLetterBackendPayloadScheduled,
            "mediaDetailEmptyStateVisible": mediaDetailEmptyStateVisible,
            "mediaDetailFailedStateVisible": mediaDetailFailedStateVisible,
            "mediaDetailRetryActionVisible": mediaDetailRetryActionVisible,
            "audioDetailEmptyStateVisible": audioDetailEmptyStateVisible,
            "audioDetailTranscriptionFailedStateVisible": audioDetailTranscriptionFailedStateVisible,
            "audioDetailTranscriptionRetryVisible": audioDetailTranscriptionRetryVisible,
            "videoDetailThumbnailPlaceholderVisible": videoDetailThumbnailPlaceholderVisible,
            "videoDetailFailedStateVisible": videoDetailFailedStateVisible,
            "videoDetailRetryActionVisible": videoDetailRetryActionVisible,
            "videoTimelineThumbnailVisible": videoTimelineThumbnailVisible,
            "videoTimelinePlaceholderVisible": videoTimelinePlaceholderVisible,
            "hiddenMediaRuntimeCardVisible": hiddenMediaRuntimeCardVisible,
            "hiddenMediaRuntimeProviderVisible": hiddenMediaRuntimeProviderVisible,
            "hiddenMediaRuntimeLimitVisible": hiddenMediaRuntimeLimitVisible,
            "hiddenMediaRuntimeUploadModeVisible": hiddenMediaRuntimeUploadModeVisible,
            "hiddenMediaRuntimeMockCopyVisible": hiddenMediaRuntimeMockCopyVisible,
            "timeLetterDraftActionsVisible": timeLetterDraftActionsVisible,
            "timeLetterSealedStateVisible": timeLetterSealedStateVisible,
            "timeLetterDraftDetailVisible": timeLetterDraftDetailVisible,
            "timeLetterSealedDetailVisible": timeLetterSealedDetailVisible,
            "timeLetterReminderPolicyVisible": timeLetterReminderPolicyVisible,
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
        expiredDelayedReplyAwaitingServer: Bool,
        expiredDelayedReplyPreserved: Bool,
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
            "expiredDelayedReplyAwaitingServer": expiredDelayedReplyAwaitingServer,
            "expiredDelayedReplyPreserved": expiredDelayedReplyPreserved,
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

    func writeDigitalHumanLivePanelSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] DigitalHumanLivePanelSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("digital-human-live-panel-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] DigitalHumanLivePanelSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeEchoDigitalHumanLifecycleSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] EchoDigitalHumanLifecycleSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("echo-digital-human-lifecycle-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] EchoDigitalHumanLifecycleSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeEchoContinuousTurnSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-continuous-turn-smoke-result.json",
            smokeName: "EchoContinuousTurnSmoke"
        )
    }

    func writeDigitalHumanRuntimeStubSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("digital-human-runtime-stub-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] DigitalHumanRuntimeStubSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeTencentBackendPCMDriveMockSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] TencentBackendPCMDriveMockSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("tencent-backend-pcm-drive-mock-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] TencentBackendPCMDriveMockSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeEchoTraceExportSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-trace-export-smoke-result.json",
            smokeName: "EchoTraceExportSmoke"
        )
    }

    func writeEchoRuntimeDiagnosticsExportSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-runtime-diagnostics-export-smoke-result.json",
            smokeName: "EchoRuntimeDiagnosticsExportSmoke"
        )
    }

    func writeEchoTraceEvidencePackageExportSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-trace-evidence-package-export-smoke-result.json",
            smokeName: "EchoTraceEvidencePackageExportSmoke"
        )
    }

    func writeEchoTraceEvidencePackagePanelExportSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-trace-evidence-package-panel-export-smoke-result.json",
            smokeName: "EchoTraceEvidencePackagePanelExportSmoke"
        )
    }

    func writeEchoQAEvidenceBundleExportSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "echo-qa-evidence-bundle-export-smoke-result.json",
            smokeName: "EchoQAEvidenceBundleExportSmoke"
        )
    }

    func writeOwnerTruthInterviewNaturalInputEchoSurfaceSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "owner-truth-interview-natural-input-echo-surface-smoke-result.json",
            smokeName: "OwnerTruthInterviewNaturalInputEchoSurfaceSmoke"
        )
    }

    func writeOwnerTruthInterviewNaturalInputProductSurfaceSmokeResult(_ result: [String: Any]) {
        writeEchoQAExportSmokeResult(
            result,
            fileName: "owner-truth-interview-natural-input-product-surface-smoke-result.json",
            smokeName: "OwnerTruthInterviewNaturalInputProductSurfaceSmoke"
        )
    }

    func writeEchoQAExportSmokeResult(
        _ result: [String: Any],
        fileName: String,
        smokeName: String
    ) {
        do {
            _ = try QAScenarioResultWriter.write(result, fileName: fileName)
        } catch QAScenarioResultWriter.WriteError.resultEncoding {
            print("[UI_QA] \(smokeName) failed reason=resultEncoding")
        } catch QAScenarioResultWriter.WriteError.resultWrite(let error) {
            print("[UI_QA] \(smokeName) failed reason=resultWrite error=\(error.localizedDescription)")
        } catch {
            print("[UI_QA] \(smokeName) failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeVoiceCloneProfileSelectionSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] VoiceCloneProfileSelectionSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("voice-clone-profile-selection-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] VoiceCloneProfileSelectionSmoke failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }

    func writeVoiceCloneSynthesisRuntimeSmokeResult(_ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=resultEncoding")
            return
        }

        let resultURL = documentsURL.appendingPathComponent("voice-clone-synthesis-runtime-smoke-result.json")
        do {
            try data.write(to: resultURL, options: [.atomic])
        } catch {
            print("[UI_QA] VoiceCloneSynthesisRuntimeSmoke failed reason=resultWrite error=\(error.localizedDescription)")
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
