#!/usr/bin/env python3
"""Build-time inspection of the fixed Maven coordinate; never an app downloader."""
import hashlib
import json
from pathlib import Path
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

COORDINATE = 'com.google.ai.edge.litertlm:litertlm-android:0.19.0'
BASE = 'https://dl.google.com/dl/android/maven2/com/google/ai/edge/litertlm/litertlm-android/0.19.0/litertlm-android-0.19.0'
SIZE = 21197249
SHA256 = 'e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b'


def main():
    root=Path(sys.argv[1]); root.mkdir(parents=True,exist_ok=True)
    report={'coordinate':COORDINATE,'accepted':False}
    try:
        for extension,limit in [('pom',1048576),('aar',256*1024*1024)]:
            url=BASE+'.'+extension
            with urllib.request.urlopen(url,timeout=90) as response:
                digest=hashlib.sha256(); size=0
                with (root/('litertlm-android-0.19.0.'+extension)).open('wb') as out:
                    while block:=response.read(65536):
                        size+=len(block)
                        if size>limit:raise ValueError('artifact exceeds inspection bound')
                        digest.update(block);out.write(block)
                report[extension]={'url':url,'http_status':response.status,'size':size,'sha256':digest.hexdigest()}
        ns={'m':'http://maven.apache.org/POM/4.0.0'}
        pom=ET.parse(root/'litertlm-android-0.19.0.pom').getroot()
        text=lambda node,path:node.findtext(path,default='',namespaces=ns)
        report['pom_identity']={k:text(pom,'m:'+k) for k in ('groupId','artifactId','version','packaging')}
        report['direct_dependencies']=[{k:text(d,'m:'+k) for k in ('groupId','artifactId','version','scope')} for d in pom.findall('m:dependencies/m:dependency',ns)]
        report['licenses']=[{k:text(d,'m:'+k) for k in ('name','url')} for d in pom.findall('m:licenses/m:license',ns)]
        report['owner_pin_matched']=report['aar']['size']==SIZE and report['aar']['sha256']==SHA256
        identity=report['pom_identity']
        report['version_matched']=identity['groupId']=='com.google.ai.edge.litertlm' and identity['artifactId']=='litertlm-android' and identity['version']=='0.19.0'
        report['accepted']=report['owner_pin_matched'] and report['version_matched']
        if report['accepted']:
            with zipfile.ZipFile(root/'litertlm-android-0.19.0.aar') as aar:
                (root/'classes.jar').write_bytes(aar.read('classes.jar'))
    except urllib.error.HTTPError as error:
        report['failure']={'http_status':error.code,'hostname':'dl.google.com','cause':'HTTP error'}
    except urllib.error.URLError as error:
        report['failure']={'cause_type':type(error.reason).__name__,'hostname':'dl.google.com'}
    except (OSError,ValueError,ET.ParseError,zipfile.BadZipFile,KeyError) as error:
        report['failure']={'cause_type':type(error).__name__}
    (root/'maven-audit.json').write_text(json.dumps(report,indent=2)+'\n')
    # Small public build evidence is accessible via GitHub's annotations API.
    # Never include credentials, redirects, questions, answers or model bytes.
    print('::notice title=B08 Maven audit::'+json.dumps(report,separators=(',',':')))
    return 0 if report['accepted'] else 1


if __name__=='__main__':sys.exit(main())
