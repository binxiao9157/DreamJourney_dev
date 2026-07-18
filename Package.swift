// swift-tools-version: 6.0
import PackageDescription

// CI runs this unhosted target on macOS because the current app target links
// provider SDK binaries that only expose an iPhoneOS slice. The same source
// files are also compiled by DreamJourneyTests inside the Xcode project.
let package = Package(
    name: "DreamJourneyCore",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "DreamJourneyCore", targets: ["DreamJourneyCore"]),
    ],
    targets: [
        .target(
            name: "DreamJourneyCore",
            path: "DreamJourney/Sources",
            exclude: [
                "App/AccountLifecycleCoordinator.swift",
                "App/AccountLifecycleRuntimeRegistry.swift",
                "App/AppCoordinator.swift",
                "App/AuthCoordinator.swift",
                "App/Coordinator.swift",
                "App/DigitalHumanContextStore.swift",
                "App/FeatureFlagService.swift",
                "App/TabCoordinator.swift",
                "AppDelegate.swift",
                "Common",
                "DesignSystem",
                "Memoir",
                "Modules",
                "SceneDelegate.swift",
                "Services",
                "TabBar",
                "Theme",
                "ViewController.swift",
            ],
            sources: [
                "App/AccountSessionActor.swift",
                "App/AccountLease.swift",
                "App/AudioOwnerLeaseModel.swift",
                "Domain/OwnerTruth/OwnerTruthContracts.swift",
                "Domain/OwnerTruth/OwnerTruthRepository.swift",
            ]
        ),
        .testTarget(
            name: "DreamJourneyCoreTests",
            dependencies: ["DreamJourneyCore"],
            path: "DreamJourneyTests"
        ),
    ]
)
