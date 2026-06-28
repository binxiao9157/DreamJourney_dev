import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)
let fileManager = FileManager.default

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("docs-qa-script-path-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let docsURL = rootURL.appendingPathComponent("docs")
let stalePattern = #"tmp/visual-qa/prd-stitch-ui/[A-Za-z0-9_./*-]+\.(swift|sh|py)"#
let staleRegex = try! NSRegularExpression(pattern: stalePattern)
var staleReferences: [String] = []

if let enumerator = fileManager.enumerator(
    at: docsURL,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
) {
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "md" {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            continue
        }
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard staleRegex.firstMatch(in: content, range: nsRange) != nil else {
            continue
        }
        staleReferences.append(fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""))
    }
}

require(staleReferences.isEmpty, "docs should not point executable QA scripts at tmp:\n\(staleReferences.prefix(50).joined(separator: "\n"))")

let currentStatus = read("docs/superpowers/status/2026-06-28-ios-stability-hardening.md")
require(currentStatus.contains("Scripts/QA/prd-stitch-ui/"), "current stability doc should document the stable QA script directory")
require(currentStatus.contains("tmp/visual-qa/prd-stitch-ui/"), "current stability doc should keep tmp as generated output directory")

print("docs-qa-script-path-check passed")
