#!/usr/bin/env bash
# Official Flutter Android integration execution. No network/policy bypass.
set -euo pipefail
target=${1:?integration test target required}
log=${2:?output log required}
mkdir -p "$(dirname "$log")"
if flutter test "$target" -d emulator-5554 --reporter expanded > "$log" 2>&1; then
  python3 - "$log" <<'PY'
from pathlib import Path
import re,sys
text=Path(sys.argv[1]).read_text(errors='replace')
lines=[line for line in text.splitlines() if 'All tests passed' in line or 'SIRAJ_NATIVE_KDF_METRICS' in line or 'SIRAJ_UNIFIED_ANDROID' in line]
for line in lines:
    safe=re.sub(r'\x1b\[[0-9;]*m','',line)
    print('::notice title=SIRAJ Android evidence::'+safe.replace('%','%25').replace('\r','%0D').replace('\n','%0A'))
PY
else
  result=$?
  python3 - "$log" <<'PY'
from pathlib import Path
import re,sys
text=Path(sys.argv[1]).read_text(errors='replace')[-16000:]
text=re.sub(r'\x1b\[[0-9;]*m','',text)
for index in range(0,len(text),3000):
    part=text[index:index+3000]
    print('::error title=SIRAJ Android test failure '+str(index//3000+1)+'::'+part.replace('%','%25').replace('\r','%0D').replace('\n','%0A'))
PY
  exit "$result"
fi
