import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FamilyCircleQuickActions verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let actions = FamilyCircleQuickAction.defaultActions

require(actions.map(\.kind) == [.careDashboard, .familyFootprint], "default actions should expose care dashboard then family footprint")

let footprint = actions[1]
require(footprint.title == "家族足迹地图", "footprint action title should be roadshow-facing")
require(footprint.subtitle.contains("代际"), "footprint subtitle should mention generational footprint")
require(footprint.iconName == "map", "footprint action should use map icon")
require(footprint.accessibilityLabel == "查看家族足迹地图", "footprint action should be accessible")

print("FamilyCircleQuickActions verification passed")
