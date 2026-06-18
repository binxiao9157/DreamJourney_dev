import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let decisionPath = "docs/superpowers/status/2026-06-18-prd-full-feature-closure-decisions.md"
let coveragePath = "docs/superpowers/status/2026-06-18-prd-coverage-matrix.md"

let decisions = read(decisionPath)
let coverage = read(coveragePath)
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(decisions, "# PRD 全功能闭环决策清单", "decision doc should keep its title")
assertContains(decisions, "默认修改为10轮", "decision doc should sync updated Echo default wait policy")
assertContains(decisions, "等待时长5-10分钟随机", "decision doc should sync updated Echo wait duration")
assertContains(decisions, "推送通知和本地通知和app内状态都需要", "decision doc should sync Echo notification requirement")
assertContains(decisions, "属于公开MVP", "decision doc should mark Echo waiting reply as public MVP")
assertContains(decisions, "要求app内修改密码", "decision doc should sync account security requirement")
assertContains(decisions, "只面向于用户本人", "decision doc should scope profile to the account user")
assertContains(decisions, "头像、名称、性别、地区、手机号", "decision doc should sync account center fields")
assertContains(decisions, "所有客户端档案页面的内容都是一样的", "decision doc should sync family digital-human archive visibility")
assertContains(decisions, "谁上传谁就拥有该条记忆", "decision doc should sync archive item ownership")
assertContains(decisions, "后端辅助+AI辅助", "decision doc should sync archive analysis mode")
assertContains(decisions, "自己可见，原则上子女及父母可见", "decision doc should sync care visibility")
assertContains(decisions, "MVP阶段需要功能实现（或占位）", "decision doc should sync care intervention placeholder requirement")

assertContains(coverage, "PRD updated to ten-round/adaptive policy", "coverage matrix should no longer describe Echo waiting as the old third-turn policy")
assertNotContains(coverage, "| 2-3轮后等待回信 | implemented default policy | yes |", "coverage matrix must not overclaim the superseded Echo waiting policy")

assertContains(releasePackage, "prd-full-feature-closure-decisions-check.swift", "release QA package should include PRD decision sync guard")
assertContains(releaseRegression, "prd-full-feature-closure-decisions-check.swift", "release regression should run PRD decision sync guard")
