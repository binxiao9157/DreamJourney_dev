from pathlib import Path
import subprocess,tempfile
o=Path(__file__).resolve().parent;r=o.parents[3]
model=(r/'DreamJourney/Sources/Services/MemoryModel.swift').read_text();manager=(r/'DreamJourney/Sources/Services/UserManager.swift').read_text()
# Compile unchanged production value declarations and avatar methods; fake only transport/session/disk boundaries.
a=model.index('struct ProfileAvatar:');z=model.index('// MARK: - 用户模型',a);avatar=model[a:z]
a=model.index('struct UserModel:');z=model.index('\n    var recordYears',a);user=model[a:z]+'\n}\n'
a=manager.index('    // Avatar is server-confirmed');z=manager.index('    private func normalizedProfileField',a);methods=manager[a:z]
stubs='''
struct BackendAuthSessionContract {let userId:String;let sessionId:String;func isPrivateAccessEligible(for id:String)->Bool {id==userId}}
final class BackendAuthSessionStore {static let shared=BackendAuthSessionStore();var currentSession:BackendAuthSessionContract?}
final class DreamJourneyBackendClient {enum ClientError:Error {case featurePolicyDenied(String,String);case accountScopeChanged};static let shared=DreamJourneyBackendClient();var callbacks:[(Result<[String:Any],Error>)->Void]=[]
func readAvatarProfile(userId:String,session:BackendAuthSessionContract,completion:@escaping(Result<[String:Any],Error>)->Void){callbacks.append(completion)}
func uploadProfileAvatar(userId:String,jpeg:Data,session:BackendAuthSessionContract,completion:@escaping(Result<[String:Any],Error>)->Void){callbacks.append(completion)}}
enum UserProfileSaveResult {case saved;case failed(String);case savedWithRemoteWarning(String)}
extension Notification.Name {static let djUserDidUpdate=Notification.Name("updated")}
final class UserManager {static let shared=UserManager();enum State {case authenticated,suspended};var privateAccessState:State = .authenticated
let accountStateLock=NSRecursiveLock();var avatarOperationID=UUID();var avatarUploadSessionID:String?;var storedCurrentUser:UserModel?;var currentUser:UserModel?{storedCurrentUser};var canEnterPrivateUI:Bool{privateAccessState == .authenticated};var persisted:UserModel?
func saveToDefaultsLocked(user:UserModel)->Bool{persisted=user;return true}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'main.swift';p.write_text('import Foundation\nimport CryptoKit\n'+avatar+user+stubs+methods+'\n}\n'+(o/'ios-avatar-state-tests.swift').read_text())
 subprocess.run(['swiftc','-module-cache-path','/private/tmp/dj-profile-swift-cache',str(p),'-o',d+'/check'],check=True)
 subprocess.run([d+'/check'],check=True)
