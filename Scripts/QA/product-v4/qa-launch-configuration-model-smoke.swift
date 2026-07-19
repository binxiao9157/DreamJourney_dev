import Foundation

@main
struct QALaunchConfigurationModelSmoke {
    static func main() {
        let configuration = QALaunchConfiguration.shared
        let expectsQAConfiguration = ProcessInfo.processInfo.environment[
            "DJ_EXPECT_QA_CONFIGURATION"
        ] == "1"

        if expectsQAConfiguration {
            require(
                configuration.contains("DJQAExact"),
                "Debug/UIQA configuration must preserve exact arguments"
            )
            require(
                configuration.contains(prefix: "DJQAPrefix="),
                "Debug/UIQA configuration must preserve prefix arguments"
            )
            require(
                configuration.value(forPrefix: "DJQAPrefix=") == "value",
                "Debug/UIQA configuration must trim and return keyed values"
            )
            require(
                configuration.value(forPrefix: "DJQAEmpty=") == nil,
                "Debug/UIQA configuration must reject empty keyed values"
            )
            require(
                configuration.startupScenario == .digitalHumanLivePanelSmoke,
                "registry must preserve legacy priority when multiple smoke arguments are present"
            )
            require(
                configuration.shouldEnableDigitalHumanLivePanel,
                "digital-human scenario must enable its launch-scoped panel capability"
            )
            require(
                configuration.shouldSeedProfileCareFamilyMember,
                "profile-care scenarios must keep their family seed policy"
            )
            require(
                QALaunchScenario.startupOrder.first == .digitalHumanLivePanelSmoke,
                "registry order must begin with the legacy first smoke scenario"
            )
            require(
                Set(QALaunchScenario.startupOrder).count == QALaunchScenario.startupOrder.count,
                "registry order must not include duplicate scenarios"
            )
        } else {
            require(
                !configuration.contains("DJQAExact"),
                "production configuration must fail closed for exact arguments"
            )
            require(
                !configuration.contains(prefix: "DJQAPrefix="),
                "production configuration must fail closed for prefix arguments"
            )
            require(
                configuration.value(forPrefix: "DJQAPrefix=") == nil,
                "production configuration must fail closed for keyed values"
            )
            require(
                configuration.startupScenario == nil,
                "production configuration must not resolve a UIQA startup scenario"
            )
            require(
                !configuration.shouldEnableDigitalHumanLivePanel,
                "production configuration must not enable the digital-human QA capability"
            )
            require(
                !configuration.shouldSeedProfileCareFamilyMember,
                "production configuration must not enable profile-care QA seeding"
            )
        }

        print("PASS: QA launch configuration model expectsQAConfiguration=\(expectsQAConfiguration)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
