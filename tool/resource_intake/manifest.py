"""Owner-pinned STAGING inspection, never an application resource catalog."""
from .common import IntakeError, strict_json

PINS = {
    'Biology.zip': dict(role='RAG_DATASET', size_bytes=873028, sha256='8111e6cedd0a045e3368b02905ac2a15776e850ec50ea54794c32e3bdf6c015c'),
    'embeddinggemma-2-text-270m.litertlm': dict(role='EMBEDDING', size_bytes=164626432, sha256='2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb'),
    'litertlm-android-0.19.0.aar': dict(role='ANDROID_RUNTIME', size_bytes=21197249, sha256='e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b'),
    'Qwen3-0.6B.litertlm': dict(role='LLM', size_bytes=613722264, sha256='c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108'),
    'SIRAJ_AI_RESOURCES_MANIFEST.json': dict(role='MANIFEST', size_bytes=2494, sha256='1a1fdf3e4cde89feb3f089583ba54efcf8dbc9f188967d63cbecb20d582eb4f4'),
}


def validate_manifest(data):
    value = strict_json(data)
    if not isinstance(value, dict) or value.get('SchemaVersion') != '1.0.0' or value.get('Package') != 'SIRAJ_AI_RESOURCES' or value.get('Status') != 'STAGING_NOT_PRODUCTION_APPROVED':
        raise IntakeError('invalidStagingManifest')
    resources = value.get('Resources')
    expected = {n: p for n,p in PINS.items() if p['role'] != 'MANIFEST'}
    if not isinstance(resources, list) or len(resources) != len(expected):
        raise IntakeError('invalidResourceList')
    seen = set()
    for item in resources:
        if not isinstance(item, dict) or not isinstance(item.get('File'), str):
            raise IntakeError('invalidResource')
        name = item['File']
        if name not in expected or name in seen:
            raise IntakeError('unexpectedOrDuplicateResource')
        pin = expected[name]
        if item.get('Role') != pin['role'] or type(item.get('SizeBytes')) is not int or item['SizeBytes'] != pin['size_bytes'] or not isinstance(item.get('SHA256'), str) or item['SHA256'].lower() != pin['sha256']:
            raise IntakeError('manifestPinMismatch')
        seen.add(name)
    if value.get('RuntimeRequirement') != dict(Artifact='litertlm-android-0.19.0.aar', Version='0.19.0', Platform='Android', RequiredFor=['LLM', 'EMBEDDING'], AlternativeRuntimeAllowed=False, CompatibilityStatus='NOT_YET_VERIFIED'):
        raise IntakeError('unexpectedRuntimeRequirement')
    if value['RuntimeRequirement'].get('AlternativeRuntimeAllowed') is not False:
        raise IntakeError('unexpectedRuntimeRequirement')
    if value.get('BiologyDataset') != dict(Container='Biology.zip', Units=['Unit_01', 'Unit_02'], IntegrationStatus='REQUIRES_COMPATIBILITY_VALIDATION'):
        raise IntakeError('unexpectedDatasetDeclaration')
    return value


def validate_release(data):
    if not isinstance(data, dict) or data.get('tag_name') != 'siraj-ai-resources-staging-v1' or data.get('prerelease') is not True or data.get('draft') is not False:
        raise IntakeError('unexpectedRelease')
    assets = data.get('assets')
    if not isinstance(assets, list):
        raise IntakeError('invalidReleaseAssets')
    seen = set()
    for asset in assets:
        if not isinstance(asset, dict) or not isinstance(asset.get('name'), str):
            raise IntakeError('invalidReleaseAssets')
        name = asset['name']
        if name not in PINS or name in seen:
            raise IntakeError('unexpectedOrDuplicateReleaseAsset')
        pin = PINS[name]
        if type(asset.get('size')) is not int or asset['size'] != pin['size_bytes'] or asset.get('digest') != 'sha256:'+pin['sha256'] or asset.get('state') != 'uploaded':
            raise IntakeError('releasePinMismatch')
        seen.add(name)
    if seen != set(PINS):
        raise IntakeError('missingReleaseAsset')
