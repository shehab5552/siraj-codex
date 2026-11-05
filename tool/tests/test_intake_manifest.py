import copy
import json
import unittest
from tool.resource_intake.common import IntakeError
from tool.resource_intake.manifest import validate_manifest, validate_release, PINS


def manifest():
    return {
        'SchemaVersion': '1.0.0', 'Package': 'SIRAJ_AI_RESOURCES',
        'Status': 'STAGING_NOT_PRODUCTION_APPROVED',
        'CreatedUTC': '2026-11-05T22:51:41.2963897Z',
        'Resources': [dict(Role=p['role'], File=n, SizeBytes=p['size_bytes'], SHA256=p['sha256'].upper())
                      for n, p in PINS.items() if p['role'] != 'MANIFEST'],
        'RuntimeRequirement': dict(Artifact='litertlm-android-0.19.0.aar', Version='0.19.0', Platform='Android', RequiredFor=['LLM', 'EMBEDDING'], AlternativeRuntimeAllowed=False, CompatibilityStatus='NOT_YET_VERIFIED'),
        'BiologyDataset': dict(Container='Biology.zip', Units=['Unit_01', 'Unit_02'], IntegrationStatus='REQUIRES_COMPATIBILITY_VALIDATION'),
    }


class ManifestTest(unittest.TestCase):
    def test_valid_staging_only(self):
        self.assertEqual(validate_manifest(json.dumps(manifest()).encode())['Status'], 'STAGING_NOT_PRODUCTION_APPROVED')

    def test_invalid_manifest_fields(self):
        for key, value in [('Status', 'READY'), ('Resources', []), ('SchemaVersion', '2'), ('Resources', None), ('RuntimeRequirement', {})]:
            with self.subTest(key=key, value=value), self.assertRaises(IntakeError):
                data = manifest(); data[key] = value
                validate_manifest(json.dumps(data).encode())

    def test_resource_mutations_and_duplicates(self):
        for key, value in [('File', '../a'), ('SizeBytes', True), ('SizeBytes', 1), ('SHA256', '0'*64), ('Role', 'READY')]:
            with self.subTest(key=key), self.assertRaises(IntakeError):
                data = manifest(); data['Resources'][0][key] = value
                validate_manifest(json.dumps(data).encode())
        data = manifest(); data['Resources'].append(copy.deepcopy(data['Resources'][0]))
        with self.assertRaises(IntakeError): validate_manifest(json.dumps(data).encode())

    def test_no_production_or_alternate_runtime(self):
        for key, value in [('AlternativeRuntimeAllowed', True), ('AlternativeRuntimeAllowed', 0), ('Version', '0.20.0'), ('CompatibilityStatus', 'READY')]:
            data = manifest(); data['RuntimeRequirement'][key] = value
            with self.assertRaises(IntakeError): validate_manifest(json.dumps(data).encode())

    def test_release_pins(self):
        data = dict(tag_name='siraj-ai-resources-staging-v1', prerelease=True, draft=False,
                    assets=[dict(name=n, size=p['size_bytes'], digest='sha256:'+p['sha256'], state='uploaded') for n,p in PINS.items()])
        validate_release(data)
        for mutation in ('size', 'digest', 'duplicate', 'not_staging'):
            broken=copy.deepcopy(data)
            if mutation=='size': broken['assets'][0]['size'] = True
            if mutation=='digest': broken['assets'][0]['digest'] = 'sha256:'+'0'*64
            if mutation=='duplicate': broken['assets'].append(copy.deepcopy(broken['assets'][0]))
            if mutation=='not_staging': broken['prerelease'] = False
            with self.subTest(mutation=mutation), self.assertRaises(IntakeError): validate_release(broken)
