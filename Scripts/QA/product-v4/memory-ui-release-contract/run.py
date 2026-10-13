"""Compile exact production narrative decoder declarations without UIKit/network dependencies."""
from pathlib import Path
import subprocess,sys,tempfile
r=Path(__file__).resolve().parent;b=r.parents[3];src=b/'DreamJourney/Sources/Domain/OwnerTruth'
f=(src/'OwnerTruthFormalMemory.swift').read_text();c=(src/'OwnerTruthContracts.swift').read_text()
def span(text,a,z):
 assert text.count(a)==1 and text.count(z)==1
 return text[text.index(a):text.index(z)]
code='import Foundation\nimport CoreFoundation\n'+span(c,'struct OwnerTruthVaultID:','enum OwnerTruthSourceKind:')+span(f,'enum OwnerTruthFormalMemoryContractError:','enum OwnerTruthFormalMemoryVersionStatus:')+span(f,'enum OwnerTruthPersonMemoryDimensionKind:','struct OwnerTruthFormalMemoryDetail:')+f[f.index('private enum OwnerTruthFormalMemoryContract {'):]+(r/'main.swift').read_text()
with tempfile.TemporaryDirectory(prefix='dj-memory-ui-contract-') as tmp:
 p=Path(tmp)/'main.swift';p.write_text(code)
 subprocess.run(['swiftc','-module-cache-path','/private/tmp/dj-profile-swift-cache',str(p),'-o',str(Path(tmp)/'contract-check')],check=True)
 result=subprocess.run([str(Path(tmp)/'contract-check'),str(Path(sys.argv[1]) if len(sys.argv)>1 else b/'DreamJourney/Resources/Info.plist'),*sys.argv[2:]]);sys.exit(result.returncode)
