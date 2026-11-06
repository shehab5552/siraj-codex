#!/usr/bin/env python3
"""Collect public license provenance for the exact owner-pinned weights.

No weight download, authentication, inference or automatic license approval.
Build checks remain independent if licensing cannot be established.
"""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
from urllib.parse import quote, urlsplit
import urllib.error
import urllib.request


def fetch(url,limit=1048576):
    with urllib.request.urlopen(url,timeout=30) as response:
        data=response.read(limit+1)
        if len(data)>limit:raise ValueError('inspection size bound')
        return data,dict(hostname=urlsplit(response.url).hostname,http_status=response.status)


def metadata(model):
    if not re.fullmatch(r'(litert-community|google|Qwen)/[A-Za-z0-9_.-]+',model):
        raise ValueError('non-authoritative model namespace')
    data,status=fetch('https://huggingface.co/api/models/'+quote(model,safe='/')+'?blobs=true')
    return json.loads(data),status


class MainText(HTMLParser):
    def __init__(self):
        super().__init__();self.main=0;self.skip=0;self.parts=[]
    def handle_starttag(self,tag,attrs):
        if tag=='main':self.main+=1
        if tag in ('script','style'):self.skip+=1
    def handle_endtag(self,tag):
        if tag=='main':self.main=max(0,self.main-1)
        if tag in ('script','style'):self.skip=max(0,self.skip-1)
    def handle_data(self,data):
        if self.main and not self.skip and data.strip():self.parts.append(data.strip())


def audit(label,pin,candidates):
    report=dict(label=label,expected_sha256=pin,artifact_matched=False,permission_status='BLOCKED',attempts=[])
    for model in candidates[:12]:
        try:
            value,status=metadata(model)
            report['attempts'].append(dict(model=model,**status))
            matches=[f['rfilename'] for f in value.get('siblings',[]) if f.get('lfs',{}).get('sha256')==pin]
            if not matches:continue
            revision=value['sha'];license_id=value.get('cardData',{}).get('license')
            report.update(model=model,revision=revision,artifact_matched=True,weight_files=matches,declared_license=license_id)
            report['card_data']=value.get('cardData',{})
            card_url='https://huggingface.co/'+quote(model,safe='/')+'/raw/'+quote(revision,safe='')+'/README.md'
            card,card_http=fetch(card_url,65536)
            report.update(model_card_source=card_url,model_card_http=card_http,model_card_text=card.decode('utf8','strict'))
            filenames={f['rfilename'] for f in value.get('siblings',[])}
            chosen=next((name for name in ['LICENSE','LICENSE.txt','LICENSE.md'] if name in filenames),None)
            if chosen:
                url='https://huggingface.co/'+quote(model,safe='/')+'/resolve/'+quote(revision,safe='')+'/'+chosen
                raw,source=fetch(url,65536);text=raw.decode('utf8','strict')
                report.update(license_source=url,license_http=source,license_sha256=hashlib.sha256(raw).hexdigest(),license_text=text)
            elif license_id=='apache-2.0':
                url='https://www.apache.org/licenses/LICENSE-2.0.txt'
                raw,source=fetch(url,65536)
                report.update(license_source=url,license_http=source,license_sha256=hashlib.sha256(raw).hexdigest(),license_text=raw.decode('utf8','strict'))
            elif license_id=='gemma':
                url='https://ai.google.dev/gemma/terms'
                raw,source=fetch(url,2*1024*1024);parser=MainText();parser.feed(raw.decode('utf8','strict'))
                text='\n'.join(parser.parts)
                report.update(license_source=url,license_http=source,license_sha256=hashlib.sha256(raw).hexdigest(),license_text=text)
            if report.get('license_text'):
                report['permission_status']='PENDING ENGINEERING LICENSE REVIEW'
                if len(report['license_text'])>45000:
                    report['license_text']=report['license_text'][:45000];report['license_text_truncated']=True
            break
        except urllib.error.HTTPError as error:
            report['attempts'].append(dict(model=model,http_status=error.code,cause='HTTP error'))
        except (urllib.error.URLError,ValueError,KeyError,UnicodeError,OSError) as error:
            report['attempts'].append(dict(model=model,cause_type=type(error).__name__))
    return report


def main():
    directory=Path(sys.argv[1]);directory.mkdir(parents=True,exist_ok=True)
    candidates=['litert-community/Qwen3-0.6B','litert-community/Qwen3-0.6B-litert-lm']
    try:
        data,_=fetch('https://huggingface.co/api/models?search=Qwen3-0.6B&limit=100')
        candidates+=sorted({m['id'] for m in json.loads(data) if m.get('id','').startswith('litert-community/')})
    except (urllib.error.URLError,ValueError,KeyError):pass
    reports=[
        audit('Qwen3','c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108',list(dict.fromkeys(candidates))),
        audit('EmbeddingGemma','2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',['litert-community/embeddinggemma-2-text-270m-litert-lm']),
    ]
    (directory/'model-license-audit.json').write_text(json.dumps(reports,indent=2)+'\n')
    for report in reports:
        message=json.dumps(report,separators=(',',':')).replace('%','%25')
        print('::notice title=B08 model license '+report['label']+'::'+message)


if __name__=='__main__':main()
