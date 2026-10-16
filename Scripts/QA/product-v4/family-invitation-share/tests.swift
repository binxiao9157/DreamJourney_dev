import UIKit
import Vision
import UniformTypeIdentifiers

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("FAIL: \(message)") }
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sample = "0123456789ABCDEF01234567" // Deliberately synthetic; never issued by a server.
let item = FamilyInvitationImageItem(code: sample)!
let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
check(item.image.size == CGSize(width: 1080, height: 624), "bounded standard image size")
check(item.image.scale == 1, "pixel scale independent of device")
check(item.activityViewControllerPlaceholderItem(controller) is UIImage, "placeholder is image, not old text")
for target in [nil, UIActivity.ActivityType.copyToPasteboard, UIActivity.ActivityType(rawValue: "synthetic.thirdparty")] {
    check(item.activityViewController(controller, itemForActivityType: target) is UIImage, "single image for every target")
    check(item.activityViewController(controller, dataTypeIdentifierForActivityType: target) == UTType.png.identifier, "actual PNG type")
}
let png = item.image.pngData()!
check(Array(png.prefix(8)) == [137,80,78,71,13,10,26,10], "PNG signature")
check(UIImage(data: png)?.size == item.image.size, "PNG decode size intact")
check(png.count < 1_000_000, "bounded share size")
try png.write(to: output.appendingPathComponent("invitation-synthetic.png"))
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US"]
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: item.image.cgImage!, options: [:]).perform([request])
let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
check(recognized.contains(sample), "OCR preserves exact 24-character invitation")
for code in ["", "A B", "ABC\nDEF", "邀请码", "ABC-123", String(repeating: "A", count: 129)] {
    check(FamilyInvitationImageItem(code: code) == nil, "invalid code rejected instead of truncated")
}
let longCode = String(repeating: "0123456789ABCDEF", count: 8)
let long = FamilyInvitationImageItem(code: longCode)!
check(long.image.size.height == 944, "all 128 characters have room")
try long.image.pngData()!.write(to: output.appendingPathComponent("invitation-long-synthetic.png"))
let longRequest = VNRecognizeTextRequest()
longRequest.recognitionLevel = .accurate
longRequest.recognitionLanguages = ["en-US"]
longRequest.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: long.image.cgImage!, options: [:]).perform([longRequest])
let hexRows = (longRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }.filter { $0.count >= 8 && $0.allSatisfy { "0123456789ABCDEF".contains($0) } }
check(hexRows.joined() == longCode, "OCR all long-code rows without data loss")
check(FamilyInvitationImageItem(code: "aBcd1234") != nil, "mixed case preserved as valid input")
check(FamilyInvitationSharePolicy.isCurrent(owner: "A", currentOwner: "A"), "same owner")
check(!FamilyInvitationSharePolicy.isCurrent(owner: "A", currentOwner: "B"), "switched owner denied")
check(!FamilyInvitationSharePolicy.isCurrent(owner: "A", currentOwner: nil), "logout denied")
check(!FamilyInvitationSharePolicy.isCurrent(owner: "", currentOwner: ""), "empty owner denied")
check(FamilyInvitationSharePolicy.outcome(completed: false, hasError: false) == .cancelled, "cancel not success")
check(FamilyInvitationSharePolicy.outcome(completed: true, hasError: false) == .reportedComplete, "callback complete only")
check(FamilyInvitationSharePolicy.outcome(completed: true, hasError: true) == .failed, "error outranks completion")
check(FamilyInvitationSharePolicy.outcome(completed: false, hasError: true) == .failed, "error fallback")
let pasteboard = UIPasteboard.withUniqueName()
check(FamilyInvitationSharePolicy.copyCode(sample, owner: "A", currentOwner: "A", pasteboard: pasteboard), "explicit copy allowed")
check(pasteboard.string == sample, "clipboard is exact code without title or inserted spaces")
check(!FamilyInvitationSharePolicy.copyCode("OTHER", owner: "A", currentOwner: "B", pasteboard: pasteboard), "switched owner cannot overwrite clipboard")
check(pasteboard.string == sample, "clipboard unchanged after denied copy")
check(!FamilyInvitationSharePolicy.copyCode("OTHER", owner: "A", currentOwner: nil, pasteboard: pasteboard), "logged out copy denied")
UIPasteboard.remove(withName: pasteboard.name)
print("PASS: \(checks) actual UIKit/image and owner/completion checks; WeChat NOT_RUN")
