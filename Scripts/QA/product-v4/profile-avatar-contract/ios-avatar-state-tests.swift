let raw = Data([0xff, 0xd8, 0xff, 0xd9])
let fixture = ProfileAvatar(mimeType:"image/jpeg",imageBase64:raw.base64EncodedString(),sha256:SHA256.hash(data:raw).map{String(format:"%02x",$0)}.joined(),width:256,height:256)
let profile:[String:Any] = ["userId":"a","avatar":try! JSONSerialization.jsonObject(with:JSONEncoder().encode(fixture))]
func reset() {
 UserManager.shared.storedCurrentUser = UserModel(id:"a", nickname:"keep", phone:"123")
 BackendAuthSessionStore.shared.currentSession = BackendAuthSessionContract(userId:"a",sessionId:"s1")
 UserManager.shared.avatarUploadSessionID = nil
 UserManager.shared.privateAccessState = .authenticated
 DreamJourneyBackendClient.shared.callbacks = []
 UserManager.shared.persisted = nil
}
var passes=0
func check(_ name:String,_ test:()->Bool) {reset();guard test() else {fatalError("FAIL \(name)")};passes+=1;print("PASS \(name)")}
check("successful upload applies only avatar and persists") {
 var saved=false
 UserManager.shared.saveAvatar(jpeg:raw,expectedUserID:"a",expectedSessionID:"s1") {if case .saved = $0 {saved=true}}
 let before=UserManager.shared.currentUser!.avatar == nil
 DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":profile]))
 return before && saved && UserManager.shared.persisted?.avatar==fixture && UserManager.shared.currentUser?.nickname=="keep"
}
check("upload failure preserves old avatar") {
 UserManager.shared.storedCurrentUser?.avatar=fixture
 var failed=false
 UserManager.shared.saveAvatar(jpeg:raw,expectedUserID:"a",expectedSessionID:"s1") {if case .failed = $0 {failed=true}}
 DreamJourneyBackendClient.shared.callbacks[0](.failure(NSError(domain:"offline",code:1)))
 return failed && UserManager.shared.currentUser?.avatar==fixture
}
check("account switch rejects prior upload") {
 UserManager.shared.saveAvatar(jpeg:raw,expectedUserID:"a",expectedSessionID:"s1") {_ in}
 UserManager.shared.storedCurrentUser=UserModel(id:"b",nickname:"other",phone:"")
 BackendAuthSessionStore.shared.currentSession=BackendAuthSessionContract(userId:"b",sessionId:"s2")
 DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":profile]))
 return UserManager.shared.currentUser?.avatar==nil && UserManager.shared.currentUser?.id=="b"
}
check("new login of same account rejects prior callback") {
 UserManager.shared.refreshAvatar()
 BackendAuthSessionStore.shared.currentSession=BackendAuthSessionContract(userId:"a",sessionId:"s2")
 DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":profile]))
 return UserManager.shared.currentUser?.avatar==nil
}
check("old read cannot overwrite confirmed avatar") {
 UserManager.shared.refreshAvatar()
 UserManager.shared.saveAvatar(jpeg:raw,expectedUserID:"a",expectedSessionID:"s1") {_ in}
 DreamJourneyBackendClient.shared.callbacks[1](.success(["profile":profile]))
 DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":["userId":"a"]]))
 return UserManager.shared.currentUser?.avatar==fixture
}
check("refresh suppressed during upload") {
 UserManager.shared.saveAvatar(jpeg:raw,expectedUserID:"a",expectedSessionID:"s1") {_ in}
 UserManager.shared.refreshAvatar()
 return DreamJourneyBackendClient.shared.callbacks.count==1
}
check("invalid hash does not overwrite avatar") {
 var invalid=profile;var a=invalid["avatar"] as! [String:Any];a["sha256"]="wrong";invalid["avatar"]=a
 UserManager.shared.refreshAvatar();DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":invalid]))
 return UserManager.shared.currentUser?.avatar==nil
}
check("server no avatar clears stale local cache") {
 UserManager.shared.storedCurrentUser?.avatar=fixture
 UserManager.shared.refreshAvatar();DreamJourneyBackendClient.shared.callbacks[0](.success(["profile":["userId":"a"]]))
 return UserManager.shared.currentUser?.avatar==nil
}
check("offline read preserves cached avatar") {
 UserManager.shared.storedCurrentUser?.avatar=fixture
 UserManager.shared.refreshAvatar();DreamJourneyBackendClient.shared.callbacks[0](.failure(NSError(domain:"offline",code:1)))
 return UserManager.shared.currentUser?.avatar==fixture
}
check("old cached UserModel decodes without avatar") {
 let old=Data("{\"id\":\"old\",\"nickname\":\"name\",\"phone\":\"123\"}".utf8)
 return (try? JSONDecoder().decode(UserModel.self,from:old))?.avatar==nil
}
print("\(passes) avatar behavior checks passed; network and disk boundaries are test doubles")
