#!/usr/bin/env python3
"""Fail if source or the tested compiled app disables recovery."""
import argparse,plistlib,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--app',type=Path,required=True)
a=p.parse_args();result={}
for name,path in [('source',a.repo/'DreamJourney/Resources/Info.plist'),('compiled',a.app/'Info.plist')]:
    data=path.read_bytes();v=plistlib.loads(data)
    assert v.get('LiveRecoveryEnabled') is True,(name,'LiveRecoveryEnabled must be true')
    result[name]={'LiveRecoveryEnabled':True,'sha256':hashlib.sha256(data).hexdigest()}
print(json.dumps(result,indent=2))
