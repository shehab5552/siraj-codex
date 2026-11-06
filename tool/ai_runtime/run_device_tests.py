#!/usr/bin/env python3
"""Report genuine Android target results without publishing private device logs.

Non-object JSON may occur among build diagnostics. Only test protocol objects
and the fixed aggregate probe record count as evidence; exit0 alone is not PASS.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import traceback


def parse_output(output):
    metrics=[];passed=failed=skipped=0;done=False
    for line in output.splitlines():
        try:event=json.loads(line)
        except ValueError:continue
        if not isinstance(event,dict):continue
        if event.get('type')=='testDone' and not event.get('hidden'):
            if event.get('skipped'):skipped+=1
            elif event.get('result')=='success':passed+=1
            else:failed+=1
        if event.get('type')=='done':done=event.get('success') is True
        message=event.get('message','') if event.get('type')=='print' else ''
        if not isinstance(message,str) or 'SIRAJ_B08_MODEL_METRICS ' not in message:continue
        try:value=json.loads(message.split('SIRAJ_B08_MODEL_METRICS ',1)[1])
        except ValueError:continue
        if isinstance(value,dict) and value not in metrics:metrics.append(value)
    return metrics,dict(passed=passed,failed=failed,skipped=skipped),done


def main():
    directory=Path(sys.argv[1]);directory.mkdir(parents=True,exist_ok=True)
    reports=[]
    # Flutter3.38.5 uninstalls after each invocation. Keep the private fixtures
    # alive across all six cases by using one real integration target.
    for target in ['b08_android_acceptance_test']:
        print('::notice title=B08 Android target start::'+target,flush=True)
        process=subprocess.run(['flutter','test','integration_test/'+target+'.dart','--no-pub','-d','emulator-5554','--machine'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace')
        metrics,counts,done=parse_output(process.stdout)
        failures=re.findall(r'SIRAJ_B08_MODEL_FAILURE ([A-Za-z]+)',process.stdout)
        model=metrics[0] if len(metrics)==1 else {}
        model_scope_valid=(model.get('status')=='PASS'
            and model.get('scope')=='X86_64_EMULATOR_ENGINEERING_ONLY'
            and model.get('modelInferenceExecuted') is True
            and model.get('productionResourcesApproved') is False
            and model.get('g2')=='BLOCKED' and model.get('g3')=='BLOCKED'
            and model.get('embeddingQueryCount')==3
            and model.get('assertedNonemptyCompletionCount')==4
            and model.get('nativeCancellationTerminal')=='generationCancelled')
        # All six visible cases are mandatory: DB, secure session, two storage,
        # JNI, and the genuine-model case. A print + done with zero/partial cases
        # is never a successful acceptance run.
        evidence_passed=(done and len(metrics)==1 and model_scope_valid
            and counts==dict(passed=6,failed=0,skipped=0))
        success=process.returncode==0 and evidence_passed
        result=dict(target=target,status='PASS' if success else 'FAIL',exit_code=process.returncode,
                    evidence_complete=evidence_passed,errors=failures,metrics=metrics,flutter_reported_cases=counts)
        reports.append(result)
        print('::notice title=B08 Android target::'+json.dumps(result,separators=(',',':')),flush=True)
        (directory/'android-results.json').write_text(json.dumps(reports,indent=2)+'\n')
        if not success:
            print('::error title=B08 Android target failed::'+target+' exit='+str(process.returncode)+' complete_evidence='+str(evidence_passed)+' typed_errors='+','.join(failures),flush=True)
            return process.returncode or 1
    return 0


if __name__=='__main__':
    try:sys.exit(main())
    except Exception as error:
        # Own tool frame names aid diagnosis without reflecting child output,
        # exception messages, model text, prompts, vectors or signed URLs.
        safe=dict(error_type=type(error).__name__,frames=[dict(file=Path(frame.filename).name,line=frame.lineno,function=frame.name) for frame in traceback.extract_tb(error.__traceback__)],raw_output_published=False)
        print('::error title=B08 device reporter failed::'+json.dumps(safe,separators=(',',':')),flush=True)
        sys.exit(1)
