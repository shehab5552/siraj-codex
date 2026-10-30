#!/usr/bin/env python3
"""Verify tracked resources, SIRAJ label, and optionally the actual compiled APK.
Requires Pillow only for APK decoded-pixel comparison (aapt is in Android SDK).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile
import io

ANDROID='{http://schemas.android.com/apk/res/android}'

def verify(repo,apk=None,aapt=None):
    repo=Path(repo)
    provenance=json.loads((repo/'assets/branding/provenance.json').read_text())
    for relative,expected in provenance['generated'].items():
        path=repo/relative
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
            raise ValueError(f'Branding resource mismatch: {relative}')
    template=json.loads((repo/'assets/branding/flutter_template_hashes.json').read_text())
    for relative,old in template.items():
        if hashlib.sha256((repo/relative).read_bytes()).hexdigest()==old:
            raise ValueError(f'Flutter template launcher remains: {relative}')
    app=ET.parse(repo/'android/app/src/main/AndroidManifest.xml').getroot().find('application')
    if app.get(ANDROID+'label')!='SIRAJ' or app.get(ANDROID+'icon')!='@mipmap/ic_launcher':
        raise ValueError('Launcher label/icon manifest mismatch')
    if apk:
        from PIL import Image
        if not aapt: raise ValueError('--aapt is required for a compiled APK')
        result=subprocess.run([str(aapt),'dump','badging',str(apk)],check=True,capture_output=True,text=True).stdout
        if "application-label:'SIRAJ'" not in result:
            raise ValueError('Compiled APK does not declare SIRAJ label')
        icons=re.findall(r"application-icon-(\d+):'([^']+)'",result)
        checked=[]
        densities={'160':'mdpi','240':'hdpi','320':'xhdpi','480':'xxhdpi','640':'xxxhdpi'}
        with zipfile.ZipFile(apk) as archive:
            # aapt may report the API26 adaptive XML instead of a bitmap. Check
            # each actual legacy bitmap too; AAPT PNG crunching may change bytes.
            for density in densities.values():
                paths=[n for n in archive.namelist() if re.fullmatch(r'res/mipmap-'+density+r'(?:-v\d+)?/ic_launcher.png',n)]
                if len(paths)!=1: raise ValueError(f'Compiled launcher missing for {density}')
                actual=Image.open(io.BytesIO(archive.read(paths[0]))).convert('RGBA')
                source=Image.open(repo/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png').convert('RGBA')
                if actual.size!=source.size or actual.tobytes()!=source.tobytes():
                    raise ValueError(f'Compiled launcher pixels differ for {density}')
                checked.append(paths[0])
            adaptive=[n for n in archive.namelist() if re.fullmatch(r'res/mipmap-anydpi-v26/ic_launcher.xml',n)]
            if len(adaptive)!=1: raise ValueError('Compiled Adaptive Icon missing')
            splash=[n for n in archive.namelist() if 'siraj_splash_mark' in n]
            if len(splash)!=5: raise ValueError('Compiled density splash marks missing')
            bitmap_paths=[n for n in archive.namelist() if re.fullmatch(r'res/drawable-nodpi(?:-v\d+)?/siraj_launcher_foreground.png',n)]+splash
            if len(bitmap_paths)!=6: raise ValueError('Compiled adaptive foreground missing')
            for name in bitmap_paths:
                source_path=re.sub(r'(drawable-[a-z]+)-v\d+',r'\1',name)
                actual=Image.open(io.BytesIO(archive.read(name))).convert('RGBA')
                source_image=Image.open(repo/'android/app/src/main'/source_path).convert('RGBA')
                if actual.size!=source_image.size or actual.tobytes()!=source_image.tobytes():
                    raise ValueError(f'Compiled branding pixels differ: {name}')
            resources=subprocess.run([str(aapt),'dump','resources',str(apk)],check=True,capture_output=True,text=True).stdout
            foreground_ids=re.findall(r'resource (0x[0-9a-fA-F]+) \S+:drawable/siraj_launcher_foreground\b',resources)
            tree=subprocess.run([str(aapt),'dump','xmltree',str(apk),adaptive[0]],check=True,capture_output=True,text=True).stdout.lower()
            if not foreground_ids or not any(identifier.lower() in tree for identifier in foreground_ids):
                raise ValueError('Adaptive Icon does not reference the verified foreground')
        provenance={**provenance,'apk_sha256':hashlib.sha256(Path(apk).read_bytes()).hexdigest(),'compiled_label':'SIRAJ','compiled_launchers_checked':checked,'compiled_adaptive_icon':adaptive,'compiled_splash_files':splash}
    return {k:v for k,v in provenance.items() if k!='generated'}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--apk',type=Path);p.add_argument('--aapt',type=Path);p.add_argument('--output',type=Path)
    a=p.parse_args();r=verify(a.repo,a.apk,a.aapt);out=json.dumps(r,indent=2)+'\n'
    if a.output:a.output.write_text(out)
    print(out,end='')
