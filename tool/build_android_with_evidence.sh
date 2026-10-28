#!/usr/bin/env bash
# Build normal main only; CI-native targets are built after this APK is copied.
set -euo pipefail
mkdir -p dist
# A subshell is essential: failures must stop this sequence even though the
# enclosing process is checked to publish a bounded diagnostic on failure.
set +e
(
  set -euo pipefail
  flutter build apk --debug --no-pub --target=lib/main.dart
  cp build/app/outputs/flutter-apk/app-debug.apk dist/SIRAJ_P0_UNIFIED_ANDROID_DEBUG.apk
  # Regenerate the plugin registrant when changing Flutter build mode.
  flutter build apk --release --target=lib/main.dart
  git diff --exit-code -- pubspec.lock
) > dist/android-build.log 2>&1
build_status=$?
set -e
if [ "$build_status" -ne 0 ]; then
  python3 - <<'PY'
from pathlib import Path
import re
text=Path('dist/android-build.log').read_text(errors='replace')[-16000:]
# Never publish signed query strings or loopback VM-service authentication paths.
text=re.sub(r'(https?://[^/\s]+)[^\s]*',r'\1/[redacted]',text)
for index in range(0,len(text),3000):
    part=text[index:index+3000]
    print('::error title=SIRAJ Android build failure '+str(index//3000+1)+'::'+part.replace('%','%25').replace('\r','%0D').replace('\n','%0A'))
PY
  exit "$build_status"
fi
printf '%s\n' '::notice title=SIRAJ Android build::Normal main Debug APK and unsigned evaluation Release build passed'
