from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[4]
s=(r/'DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift').read_text()
methods=s[s.index('    @objc private func saveTapped()'):s.index('    private func validateProfile')].replace('@objc private ', '').replace('private func ', 'func ')
pre='''import Foundation
struct User {let id:String}
struct Session {let sessionId:String;func isPrivateAccessEligible(for id:String)->Bool {true}}
class BackendAuthSessionStore {static let shared=BackendAuthSessionStore();var currentSession:Session?=Session(sessionId:"s")}
enum ResultState {case saved;case failed(String);case savedWithRemoteWarning(String)}
class UserManager {static let shared=UserManager();var currentUser:User?=User(id:"a");var uploads=0;var saves=0;var avatarCompletion:((ResultState)->Void)?;var profileCompletion:((ResultState)->Void)?
func saveAvatar(jpeg:Data,expectedUserID:String,expectedSessionID:String,completion:@escaping(ResultState)->Void){uploads+=1;avatarCompletion=completion}
func saveProfile(nickname:String,gender:String?,region:String?,completion:@escaping(ResultState)->Void){saves+=1;profileCompletion=completion}}
class Field {var text:String?="name";func resignFirstResponder(){}}
class Page {
enum ProfileSaveState {case idle,saving,saved,failed(String),networkUnavailable,invalid(String)}
enum Validation {case valid(String,String?,String?),invalid(String)}
var profileSaving=false;var avatarBusy=false;let nameField=Field();let genderField=Field();let regionField=Field();let avatarStatusLabel=Field()
var selectedAvatarJPEG:Data?=Data([1]);var avatarSelectionOwner:(userID:String,sessionID:String)?=("a","s")
var state:ProfileSaveState = .idle;var valid=true
func validateProfile(name:String?,gender:String?,region:String?)->Validation{valid ? .valid(name!,gender,region) : .invalid("invalid")}
func cancelAvatarSelection(){selectedAvatarJPEG=nil;avatarSelectionOwner=nil}
func loadUser(){}
func renderAvatar(){}
func renderSaveState(_ s:ProfileSaveState){state=s}
'''
tests='''
func reset()->Page {let u=UserManager.shared;u.currentUser=User(id:"a");u.uploads=0;u.saves=0;u.avatarCompletion=nil;u.profileCompletion=nil;BackendAuthSessionStore.shared.currentSession=Session(sessionId:"s");return Page()}
func check(_ name:String,_ run:(Page)->Bool){let p=reset();precondition(run(p),name);print("PASS "+name)}
check("one save uploads first and waits for both results") {p in let u=UserManager.shared;p.saveTapped();guard u.uploads==1 && u.saves==0 && p.profileSaving else{return false};u.avatarCompletion?(.saved);guard u.saves==1 && p.selectedAvatarJPEG==nil && p.profileSaving else{return false};u.profileCompletion?(.saved);if case .saved=p.state{return !p.profileSaving};return false}
check("no new image only saves fields") {p in let u=UserManager.shared;p.selectedAvatarJPEG=nil;p.saveTapped();return u.uploads==0 && u.saves==1}
check("upload failure retains image and edited fields") {p in let u=UserManager.shared;p.nameField.text="changed";p.saveTapped();u.avatarCompletion?(.failed("offline"));if case .failed=p.state{return u.saves==0 && p.selectedAvatarJPEG != nil && p.nameField.text=="changed" && !p.profileSaving};return false}
check("partial save retry does not upload twice") {p in let u=UserManager.shared;p.saveTapped();u.avatarCompletion?(.saved);u.profileCompletion?(.savedWithRemoteWarning("offline"));guard !p.profileSaving else{return false};if case .failed=p.state{p.saveTapped();return u.uploads==1 && u.saves==2};return false}
check("account change stops second write") {p in let u=UserManager.shared;p.saveTapped();u.currentUser=User(id:"b");u.avatarCompletion?(.saved);return u.saves==0 && !p.profileSaving}
check("session change stops second write") {p in let u=UserManager.shared;p.saveTapped();BackendAuthSessionStore.shared.currentSession=Session(sessionId:"new");u.avatarCompletion?(.saved);return u.saves==0 && !p.profileSaving}
check("duplicate clicks do not duplicate save") {p in let u=UserManager.shared;p.saveTapped();p.saveTapped();return u.uploads==1}
check("photo reading prevents save") {p in let u=UserManager.shared;p.avatarBusy=true;p.saveTapped();return u.uploads==0 && u.saves==0}
check("invalid fields prevent avatar upload") {p in let u=UserManager.shared;p.valid=false;p.saveTapped();return u.uploads==0 && u.saves==0}
check("failed fields after avatar success remain editable") {p in let u=UserManager.shared;p.nameField.text="changed";p.saveTapped();u.avatarCompletion?(.saved);u.profileCompletion?(.failed("disk"));if case .failed=p.state{return !p.profileSaving && p.selectedAvatarJPEG==nil && p.nameField.text=="changed"};return false}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'main.swift';p.write_text(pre+methods+'\n}\n'+tests)
 subprocess.run(['swiftc','-module-cache-path','/private/tmp/dj-profile-swift-cache',str(p),'-o',d+'/test'],check=True)
 subprocess.run([d+'/test'],check=True)
print('Production save orchestration exercised with transport/UI doubles; no device coverage claimed.')
