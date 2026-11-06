#!/usr/bin/env python3
"""Inspect the actual app APK, DEX class definitions and native ELF binaries."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('apk',type=Path)
    parser.add_argument('--apkanalyzer',required=True)
    parser.add_argument('--mapping',type=Path)
    args=parser.parse_args()
    if args.mapping is not None:
        assert args.mapping.is_file() and args.mapping.stat().st_size>0, 'R8 mapping missing'
    classes=['com.google.ai.edge.litertlm.Engine','com.google.ai.edge.litertlm.EmbeddingEngine',
             'com.example.siraj.ai_runtime.RuntimeLibraryProbe']
    for name in classes:
        subprocess.run([args.apkanalyzer,'dex','code','--class',name,str(args.apk)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    native=[]
    with zipfile.ZipFile(args.apk) as archive, tempfile.TemporaryDirectory() as temp:
        for name in ('LICENSE','THIRD_PARTY_NOTICE'):
            assert len(archive.read('assets/licenses/litertlm-android-0.19.0/'+name+'.txt'))>0, 'Runtime license notice missing'
        for abi,machine in [('arm64-v8a',183),('x86_64',62)]:
            name='lib/'+abi+'/liblitertlm_jni.so'
            blob=archive.read(name)
            assert blob[:4]==b'\x7fELF' and blob[4]==2 and blob[5]==1, 'Expected ELF64 little endian'
            assert struct.unpack_from('<H',blob,18)[0]==machine, 'ELF ABI mismatch'
            path=Path(temp)/(abi+'.so');path.write_bytes(blob)
            result=subprocess.run(['readelf','-h','-d',str(path)],check=True,capture_output=True,text=True)
            assert 'liblitertlm_jni.so' in result.stdout, 'JNI SONAME missing'
            native.append(dict(abi=abi,machine=machine,size_bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),readelf_passed=True))
    digest=hashlib.sha256()
    with args.apk.open('rb') as stream:
        while block:=stream.read(65536):digest.update(block)
    report=dict(apk=args.apk.name,size_bytes=args.apk.stat().st_size,sha256=digest.hexdigest(),
                classes_verified=classes,native=native,r8_mapping_verified=args.mapping is not None,
                model_execution='NOT RUN',g2='NOT RUN',g3='NOT RUN')
    print(json.dumps(report,indent=2))
    print('::notice title=B08 APK inspection::'+json.dumps(report,separators=(',',':')))


if __name__=='__main__':main()
