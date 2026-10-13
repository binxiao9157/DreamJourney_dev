import Foundation
var failures = 0
func check(_ name: String, _ block: () throws -> Bool) {
    do { if try block() { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") } }
    catch { failures += 1; print("FAIL \(name): \(error)") }
}
func rejected(_ value: [String: Any]) -> Bool {
    do { _ = try OwnerTruthPersonLifeStory(backendJSONObject: value); return false } catch { return true }
}
let id = "00000000-0000-0000-0000-000000000101"
let version = "00000000-0000-0000-0000-000000000201"
let chapter: [String: Any] = ["chapterId":"daily","title":"日常生活","format":"plainText","paragraphCount":1,"paragraphs":["我在周末整理照片。"],"text":"我在周末整理照片。","supportingMemoryCount":1,"supportingMemoryIds":[id],"supportingMemoryVersionIds":[version],"facets":["habit"]]
var story: [String: Any] = ["schemaVersion":OwnerTruthPersonLifeStory.schemaVersion,"algorithmVersion":OwnerTruthPersonLifeStory.algorithmVersion,"format":"plainText","state":"ready","title":"我的人生记录","overview":NSNull(),"documentVersion":String(repeating:"a",count:64),"sourceFingerprint":String(repeating:"b",count:64),"chapterCount":1,"supportingMemoryCount":1,"chapters":[chapter]]
check("ready chapters without overview remain readable") { let s = try OwnerTruthPersonLifeStory(backendJSONObject:story); return s.overview == nil && s.chapters.count == 1 && s.chapters[0].text == "我在周末整理照片。" }
check("missing optional overview") { var s=story;s.removeValue(forKey:"overview");return try OwnerTruthPersonLifeStory(backendJSONObject:s).chapters.count==1 }
check("legacy nonempty overview") { var s=story;s["overview"]="我的生活记录";return try OwnerTruthPersonLifeStory(backendJSONObject:s).overview=="我的生活记录" }
check("ready missing chapters rejected") { var s=story;s["chapters"]=[];s["chapterCount"]=0;s["supportingMemoryCount"]=0;return rejected(s) }
check("malformed version rejected") {var s=story;s["documentVersion"]="bad";return rejected(s)}
check("missing evidence rejected") {var s=story;var c=chapter;c["supportingMemoryIds"]=[];s["chapters"]=[c];return rejected(s)}
check("duplicate chapters rejected") {var s=story;s["chapters"]=[chapter,chapter];s["chapterCount"]=2;s["supportingMemoryCount"]=2;return rejected(s)}
check("nonstring overview rejected") {var s=story;s["overview"]=123;return rejected(s)}
check("blank overview rejected") {var s=story;s["overview"]="  ";return rejected(s)}
check("empty record valid") {var s=story;s["state"]="empty";s["chapters"]=[];s["chapterCount"]=0;s["supportingMemoryCount"]=0;return try OwnerTruthPersonLifeStory(backendJSONObject:s).state == .empty}
check("empty with chapters rejected") {var s=story;s["state"]="empty";return rejected(s)}
if let path=CommandLine.arguments.dropFirst().first {
 check("final package recovery and theme entry enabled") {
  let p=try PropertyListSerialization.propertyList(from:Data(contentsOf:URL(fileURLWithPath:path)),format:nil) as! [String:Any]
  return p["LiveRecoveryEnabled"] as? Bool == true
 }
}
if CommandLine.arguments.count > 2 {
 check("actual online complete profile decodes") {
  let object = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [String: Any]
  let vault = OwnerTruthVaultID(object["vaultId"] as! String)!
  let profile = try OwnerTruthPersonMemoryProfile(backendJSONObject: object, expectedVaultID: vault)
  print("profile memories=\(profile.memoryCount) chapters=\(profile.lifeStory.chapters.count)")
  return profile.state == .ready && !profile.lifeStory.chapters.isEmpty
 }
}
print("failures=\(failures)")
exit(failures == 0 ? 0 : 1)
