#!/usr/bin/env python3
"""Run real Flutter Android targets; report only counts and aggregate metrics.

Never emit raw test logs, prompts, answers, native traces or vectors as Actions
annotations. Full device logs stay private to the runner and are not uploaded.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

def main():
    directory=Path(sys.argv[1]);directory.mkdir(parents=True,exist_ok=True)
    reports=[]
    targets=['b03_android_database_test','b04_android_secure_session_test','b07_download_storage_test','b08_runtime_library_test','b08_real_models_test']
    for target in targets:
        # Run each target independently: Flutter native app is restarted, while
        # private fixtures persist through same-signature debug installation.
        process=subprocess.run(['flutter','test','integration_test/'+target+'.dart','--no-pub','-d','emulator-5554','--machine'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        output=process.stdout
        metrics=[];passed=failed=skipped=0
        for line in output.splitlines():
            try:event=json.loads(line)
            except ValueError:continue
            if event.get('type')=='testDone' and not event.get('hidden'):
                if event.get('skipped'):skipped+=1
                elif event.get('result')=='success':passed+=1
                else:failed+=1
            message=event.get('message','') if event.get('type')=='print' else ''
            if 'SIRAJ_B08_MODEL_METRICS ' in message:
                metrics.append(json.loads(message.split('SIRAJ_B08_MODEL_METRICS ',1)[1]))
        failures=re.findall(r'SIRAJ_B08_MODEL_FAILURE ([A-Za-z]+)',output)
        result=dict(target=target,status='PASS' if process.returncode==0 else 'FAIL',exit_code=process.returncode,
                    errors=failures,metrics=metrics,flutter_reported_cases=dict(passed=passed,failed=failed,skipped=skipped))
        reports.append(result)
        # Fixed-name test targets contain no user data; arbitrary exception
        # messages are intentionally never reflected in this report.
        print('::notice title=B08 Android target::'+json.dumps(result,separators=(',',':')))
        (directory/'android-results.json').write_text(json.dumps(reports,indent=2)+'\n')
        if process.returncode:
            print('::error title=B08 Android target failed::'+target+' exit='+str(process.returncode)+' typed_errors='+','.join(failures))
            return process.returncode
    return 0
if __name__=='__main__':sys.exit(main())
