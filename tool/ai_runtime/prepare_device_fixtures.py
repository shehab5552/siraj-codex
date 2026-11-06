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
import re
import time
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
        remote='files/ai-runtime-fixtures/'+name
        actual_hash=adb('shell','run-as',PACKAGE,'sha256sum',remote).stdout.decode().split()[0]
        actual_size=int(adb('shell','run-as',PACKAGE,'wc','-c',remote).stdout.decode().split()[0])
        assert actual_hash==PINS[name]['sha256'] and actual_size==PINS[name]['size_bytes'],'Device fixture bytes do not match host pin'
    # Disable emulator data and WiFi before inference; host ADB remains available.
    adb('shell','svc','wifi','disable');adb('shell','svc','data','disable')
    # Official Android shell controls only on this disposable CI emulator.
    # Ethernet is independent from the WiFi/mobile settings on some images.
    controls=[]
    for command in [['cmd','connectivity','airplane-mode','enable']]:
        result=subprocess.run(['adb','shell',*command],capture_output=True)
        controls.append(dict(command=' '.join(command),exit_code=result.returncode))
    help_result=subprocess.run(['adb','shell','cmd','ethernet','help'],capture_output=True)
    if b'set-ethernet-enabled' in help_result.stdout:
        result=subprocess.run(['adb','shell','cmd','ethernet','set-ethernet-enabled','false'],capture_output=True)
        controls.append(dict(command='cmd ethernet set-ethernet-enabled false',exit_code=result.returncode))
    deadline=time.monotonic()+15
    while True:
        wifi=adb('shell','settings','get','global','wifi_on').stdout.decode().strip()
        data=adb('shell','settings','get','global','mobile_data').stdout.decode().strip()
        connectivity=adb('shell','dumpsys','connectivity').stdout.decode()
        match=re.search(r'Active default network:\s*(\S+)',connectivity)
        active_default=match.group(1) if match else 'unknown'
        routes=adb('shell','ip','route','show','table','all').stdout.decode()+adb('shell','ip','-6','route','show','table','all').stdout.decode()
        default_count=sum(1 for line in routes.splitlines() if line.strip().startswith('default '))
        if wifi=='0' and data=='0' and active_default in ('none','null'):break
        if time.monotonic()>=deadline:
            failure=dict(wifi=wifi,mobile_data=data,active_default_network=active_default,default_route_count=default_count,controls=controls)
            print('::error title=B08 offline preparation failed::'+json.dumps(failure,separators=(',',':')))
            raise AssertionError('Device offline condition not established')
        time.sleep(0.25)
    report=dict(status='PASS',scope='DEBUG_ENGINEERING_FIXTURE_ONLY',model_bytes_verified=True,device_model_sha256_verified=True,controls=controls,
                wifi_setting=wifi,mobile_data_setting=data,active_default_network=active_default,default_route_count=default_count,activation_performed=False)
    (args.directory/'device-preparation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('::notice title=B08 offline device preparation::'+json.dumps(report,separators=(',',':')))

if __name__=='__main__':main()
