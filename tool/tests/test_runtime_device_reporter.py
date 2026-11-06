"""CI reporter contract fixtures only; these are NOT Android/model evidence."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

path=Path(__file__).resolve().parents[1]/'ai_runtime'/'run_device_tests.py'
spec=importlib.util.spec_from_file_location('b08_device_reporter',path)
reporter=importlib.util.module_from_spec(spec);spec.loader.exec_module(reporter)

class RuntimeDeviceReporterTest(unittest.TestCase):
    def invoke(self,events,returncode=0):
        with tempfile.TemporaryDirectory() as directory:
            output='\n'.join(json.dumps(event) for event in events)
            child=subprocess.CompletedProcess(['test-only-fake'],returncode,stdout=output)
            with patch.object(sys,'argv',['reporter',directory]),patch.object(reporter.subprocess,'run',return_value=child),contextlib.redirect_stdout(io.StringIO()):
                result=reporter.main()
            file=Path(directory)/'android-results.json'
            return result,json.loads(file.read_text()) if file.exists() else None
    def events(self):
        return [dict(type='testDone',result='success',hidden=False,skipped=False) for _ in range(6)]+[dict(type='print',message='SIRAJ_B08_MODEL_METRICS '+json.dumps(dict(status='PASS',scope='X86_64_EMULATOR_ENGINEERING_ONLY',modelInferenceExecuted=True,productionResourcesApproved=False,g2='BLOCKED',g3='BLOCKED',embeddingQueryCount=3,assertedNonemptyCompletionCount=4,nativeCancellationTerminal='generationCancelled'))),dict(type='done',success=True)]
    def test_non_object_json_diagnostics_do_not_crash_machine_parser(self):
        code,report=self.invoke([[],0,None,'diagnostic']+self.events())
        self.assertEqual(code,0);self.assertEqual(report[0]['flutter_reported_cases'],dict(passed=6,failed=0,skipped=0))
    def test_missing_real_model_metric_is_not_a_pass(self):
        code,report=self.invoke([dict(type='done',success=True)])
        self.assertNotEqual(code,0);self.assertEqual(report[0]['status'],'FAIL')
    def test_zero_cases_with_metric_is_not_complete_evidence(self):
        code,report=self.invoke(self.events()[6:])
        self.assertNotEqual(code,0);self.assertEqual(report[0]['status'],'FAIL')
    def test_partial_cases_with_metric_are_not_complete_evidence(self):
        code,report=self.invoke(self.events()[1:])
        self.assertNotEqual(code,0);self.assertEqual(report[0]['status'],'FAIL')
    def test_wrong_scope_is_not_engineering_proof(self):
        events=self.events();events[-2]['message']=events[-2]['message'].replace('X86_64_EMULATOR_ENGINEERING_ONLY','TEST_ONLY_UNRELATED_SCOPE')
        code,report=self.invoke(events)
        self.assertNotEqual(code,0);self.assertEqual(report[0]['status'],'FAIL')
    def test_child_failure_is_preserved(self):
        code,report=self.invoke([dict(type='testDone',result='error',hidden=False,skipped=False)],1)
        self.assertNotEqual(code,0);self.assertEqual(report[0]['flutter_reported_cases']['failed'],1)

if __name__=='__main__':unittest.main()
