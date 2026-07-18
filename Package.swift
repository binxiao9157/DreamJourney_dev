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
            path: "DreamJourney/Sources/App",
            exclude: [
                "AccountLifecycleCoordinator.swift",
                "AccountLifecycleRuntimeRegistry.swift",
                "AppCoordinator.swift",
                "AuthCoordinator.swift",
                "Coordinator.swift",
                "DigitalHumanContextStore.swift",
                "FeatureFlagService.swift",
                "TabCoordinator.swift",
            ],
            sources: [
                "AccountSessionActor.swift",
                "AccountLease.swift",
                "AudioOwnerLeaseModel.swift",
            ]
        ),
        .testTarget(
            name: "DreamJourneyCoreTests",
            dependencies: ["DreamJourneyCore"],
            path: "DreamJourneyTests"
        ),
    ]
)
