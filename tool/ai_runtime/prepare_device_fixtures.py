#!/usr/bin/env python3
"""Isolated CI fixture transfer, never a production downloader or catalog.

Files are obtained by the official gh release command outside Git, then checked
by the EXISTING B07 verifier. No model path is exposed on the Flutter channel.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from resource_intake.common import verify_file
from resource_intake.manifest import PINS

MODELS=('Qwen3-0.6B.litertlm','embeddinggemma-2-text-270m.litertlm')
PACKAGE='com.example.siraj'

def adb(*args,**kwargs):
    return subprocess.run(['adb',*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kwargs)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path);parser.add_argument('--apk',required=True,type=Path);args=parser.parse_args()
    for name in MODELS:
        pin=PINS[name];verify_file(args.directory/name,pin['size_bytes'],pin['sha256'])
    adb('install','-r',str(args.apk))
    adb('shell','run-as',PACKAGE,'mkdir','-p','files/ai-runtime-fixtures')
    for name in MODELS:
        # Host bytes -> stdin -> app UID private file. No public shared storage,
        # arbitrary destination, active resource mutation or runtime URL.
        with (args.directory/name).open('rb') as stream:
            adb('shell','-T','run-as',PACKAGE,'sh','-c',"'cat > files/ai-runtime-fixtures/"+name+"'",stdin=stream)
        adb('shell','run-as',PACKAGE,'chmod','400','files/ai-runtime-fixtures/'+name)
    # Disable emulator data and WiFi before inference; host ADB remains available.
    adb('shell','svc','wifi','disable');adb('shell','svc','data','disable')
    wifi=adb('shell','settings','get','global','wifi_on').stdout.decode().strip()
    data=adb('shell','settings','get','global','mobile_data').stdout.decode().strip()
    assert wifi=='0' and data=='0','Offline preparation not confirmed'
    report=dict(status='PASS',scope='DEBUG_ENGINEERING_FIXTURE_ONLY',model_bytes_verified=True,
                wifi_setting=wifi,mobile_data_setting=data,activation_performed=False)
    (args.directory/'device-preparation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('::notice title=B08 offline device preparation::'+json.dumps(report,separators=(',',':')))

if __name__=='__main__':main()
