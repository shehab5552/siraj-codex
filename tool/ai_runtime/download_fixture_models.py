#!/usr/bin/env python3
"""Fetch licensed CI-only fixtures with official gh; reuse B07 byte validation."""
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from resource_intake.common import verify_file
from resource_intake.manifest import PINS

def main():
    directory=Path(sys.argv[1]);directory.mkdir(parents=True,exist_ok=True)
    reviewed=json.loads(Path('docs/qa/b08-runtime/model-license-review.json').read_text())
    assert len(reviewed)==2 and all(r['engineering_review']=='PASS' for r in reviewed),'License review missing'
    report=[]
    for name in ('Qwen3-0.6B.litertlm','embeddinggemma-2-text-270m.litertlm'):
        assert any(r['expected_sha256']==PINS[name]['sha256'] and r['artifact_matched'] for r in reviewed),'License/artifact mismatch'
        process=subprocess.run(['gh','release','download','siraj-ai-resources-staging-v1','--repo','shehab5552/siraj-codex','--pattern',name,'--dir',str(directory)],capture_output=True,text=True)
        if process.returncode:
            # Do not log gh stderr: release redirects may contain signed URLs.
            urls=re.findall(r'https?://[^\s<>]+',process.stderr)
            hosts=sorted({urlsplit(u).hostname for u in urls})
            statuses=re.findall(r'HTTP\s+(\d{3})',process.stderr)
            error=dict(artifact=name,status='FAIL',entry_hostname='github.com',error_hostnames=hosts,http_statuses=statuses,cause='official gh release download failed',exit_code=process.returncode)
            print('::error title=B08 model download::'+json.dumps(error));(directory/'download-result.json').write_text(json.dumps(error,indent=2)+'\n');return 1
        pin=PINS[name];evidence=verify_file(directory/name,pin['size_bytes'],pin['sha256']);report.append(evidence)
    result=dict(status='PASS',scope='CI_TEST_FIXTURE_ONLY',artifacts=report,activation_performed=False)
    (directory/'download-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('::notice title=B08 model fixture bytes::'+json.dumps(result,separators=(',',':')));return 0
if __name__=='__main__':sys.exit(main())
