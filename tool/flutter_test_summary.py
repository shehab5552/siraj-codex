#!/usr/bin/env python3
"""Summarize actual Flutter JSON events, excluding hidden suite-loader tests."""
import json
import sys
from collections import Counter
from pathlib import Path
counts = Counter(passed=0, failed=0, skipped=0)
done = None
for line in Path(sys.argv[1]).read_text().splitlines():
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if event.get('type') == 'testDone' and not event.get('hidden'):
        counts['skipped' if event.get('skipped') else
               'passed' if event.get('result') == 'success' else 'failed'] += 1
    if event.get('type') == 'done':
        done = event.get('success')
result = dict(counts, success=done is True)
Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + '\n')
print('SIRAJ_HOST_RESULTS ' + json.dumps(result))
if done is not True or counts['failed'] or counts['skipped'] or not counts['passed']:
    raise SystemExit('Host suite did not fully pass')
