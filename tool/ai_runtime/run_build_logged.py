#!/usr/bin/env python3
"""Expose bounded build diagnostics through official CI annotations, no secrets.

For build/dependency commands only. Do not wrap inference or student-data tasks.
"""
from pathlib import Path
import re
import subprocess
import sys

log=Path(sys.argv[1]); log.parent.mkdir(parents=True,exist_ok=True)
with log.open('w') as output:
    result=subprocess.run(sys.argv[2:],stdout=output,stderr=subprocess.STDOUT)
if result.returncode:
    lines=log.read_text(errors='replace').splitlines()
    indices=set()
    for index,line in enumerate(lines):
        if re.search(r'(?i)(error|exception|failed|failure|could not|incompatible|what went wrong|missing|^e:)',line):
            indices.update(range(max(0,index-1),min(len(lines),index+5)))
    selected=[lines[index] for index in sorted(indices)]
    message='\n'.join(selected[-30:] or lines[-20:])[-10000:]
    # Fixed public build repositories use no signed URLs, but strip every URL
    # query anyway; never reveal redirected credential strings in annotations.
    message=re.sub(r'(https?://[^\s?]+)\?[^\s]*',r'\1?[query-redacted]',message)
    message=message.replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error title=B08 build diagnostics::'+message)
else:
    print('Build command succeeded: '+sys.argv[2])
sys.exit(result.returncode)
