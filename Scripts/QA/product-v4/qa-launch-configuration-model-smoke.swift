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
        }

        print("PASS: QA launch configuration model expectsQAConfiguration=\(expectsQAConfiguration)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
