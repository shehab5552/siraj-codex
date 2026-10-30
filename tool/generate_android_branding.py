#!/usr/bin/env python3
"""Generate deterministic Android resources from a supplied, hash-pinned PNG.
Development tool only; requires Pillow. No network, AI generation or APK signing.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tempfile
import warnings
from PIL import Image

DENSITIES = {'mdpi':1, 'hdpi':1.5, 'xhdpi':2, 'xxhdpi':3, 'xxxhdpi':4}

def generate(source: Path, root: Path, expected_sha: str, identity: str):
    if source.is_symlink() or not source.is_file():
        raise ValueError('Source must be an existing regular PNG, not a symlink')
    raw = source.read_bytes()
    if len(raw)>16*1024*1024 or hashlib.sha256(raw).hexdigest()!=expected_sha:
        raise ValueError('Source size or SHA-256 mismatch')
    with warnings.catch_warnings():
        warnings.simplefilter('error', Image.DecompressionBombWarning)
        with Image.open(io.BytesIO(raw)) as image:
            if image.format!='PNG' or min(image.size)<1024 or max(image.size)>4096:
                raise ValueError('A 1024..4096 px PNG source is required')
            image.load()
            logo=image.convert('RGBA')
    if identity not in ('reference-monogram','approved-logo'):
        raise ValueError('Unknown identity classification')
    root=root.absolute()
    if not (root/'pubspec.yaml').is_file():
        raise ValueError('Output root must be the SIRAJ repository')
    def safe(relative):
        p=root/relative
        if any(a.is_symlink() for a in [p,*p.parents] if a!=Path('/')):
            raise ValueError('Symlink output path rejected')
        return p
    outputs={}
    def add(relative,data):
        safe(relative)
        outputs[relative]=data.encode() if isinstance(data,str) else data
    def png(image):
        b=io.BytesIO();image.save(b,format='PNG',optimize=False);return b.getvalue()
    def fitted(size,art_size,background=(0,0,0,0)):
        out=Image.new('RGBA',(size,size),background)
        mark=logo.copy();mark.thumbnail((art_size,art_size),Image.Resampling.LANCZOS)
        out.alpha_composite(mark,((size-mark.width)//2,(size-mark.height)//2));return out
    res='android/app/src/main/res/'
    for density,scale in DENSITIES.items():
        # Legacy launcher is composed on navy; adaptive art stays inside 66/108 safe zone.
        n=round(48*scale)
        add(f'{res}mipmap-{density}/ic_launcher.png',png(fitted(n,round(n*.82),(16,43,70,255))))
        add(f'{res}drawable-{density}/siraj_splash_mark.png',png(fitted(round(96*scale),round(96*scale))))
    add(res+'drawable-nodpi/siraj_launcher_foreground.png',png(fitted(432,264)))
    adaptive='''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/siraj_splash_background"/><foreground android:drawable="@drawable/siraj_launcher_foreground"/></adaptive-icon>\n'''
    add(res+'mipmap-anydpi-v26/ic_launcher.xml',adaptive)
    for mode,color in [('values','#102B46'),('values-night','#101D2B')]:
        add(res+mode+'/siraj_brand_colors.xml',f'<resources><color name="siraj_splash_background">{color}</color></resources>\n')
    launch='''<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@color/siraj_splash_background"/><item android:gravity="center"><bitmap android:gravity="center" android:src="@drawable/siraj_splash_mark"/></item></layer-list>\n'''
    add(res+'drawable/launch_background.xml',launch)
    add(res+'drawable-v21/launch_background.xml',launch)
    for mode,parent in [('values-v31','Theme.Light.NoTitleBar'),('values-night-v31','Theme.Black.NoTitleBar')]:
        add(res+mode+'/styles.xml',f'''<resources><style name="LaunchTheme" parent="@android:style/{parent}"><item name="android:windowSplashScreenBackground">@color/siraj_splash_background</item><item name="android:windowSplashScreenAnimatedIcon">@drawable/siraj_launcher_foreground</item><item name="android:windowBackground">@drawable/launch_background</item></style><style name="NormalTheme" parent="@android:style/{parent}"><item name="android:windowBackground">?android:colorBackground</item></style></resources>\n''')
    add('assets/branding/app_mark.png',png(logo))
    report={'identity':identity,'official_logo_verified':identity=='approved-logo','source_sha256':expected_sha,'source_dimensions':list(logo.size),'adaptive_safe_zone':'66dp within 108dp','generated':{p:hashlib.sha256(v).hexdigest() for p,v in outputs.items()}}
    add('assets/branding/provenance.json',json.dumps(report,indent=2)+'\n')
    # Every input and destination is validated before the first resource is changed.
    with tempfile.TemporaryDirectory(prefix='siraj-branding-') as temp:
        for i,(relative,data) in enumerate(outputs.items()):
            tmp=Path(temp)/str(i);tmp.write_bytes(data)
        for i,relative in enumerate(outputs):
            dest=safe(relative);dest.parent.mkdir(parents=True,exist_ok=True)
            # Temporary file in destination directory keeps each replacement atomic.
            with tempfile.NamedTemporaryFile(dir=dest.parent,delete=False) as f:
                f.write((Path(temp)/str(i)).read_bytes());name=f.name
            Path(name).replace(dest)
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',required=True,type=Path);p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--expected-sha256',required=True);p.add_argument('--identity',required=True,choices=['reference-monogram','approved-logo'])
    a=p.parse_args();r=generate(a.source,a.repo,a.expected_sha256,a.identity)
    print(json.dumps({k:r[k] for k in ['identity','official_logo_verified','source_sha256','source_dimensions']},indent=2))
