#!/usr/bin/env python3
"""Offline, read-only audit of owner-pinned STAGING files. No activation API.

Run from the repository root; files must be in a private directory with no
concurrent writers. Release JSON is obtained separately via the official API.
Only sanitized evidence is printed; binaries never enter the repository.
"""
import argparse
import json
from pathlib import Path
import sys

from resource_intake.archive import inspect_zip
from resource_intake.biology import inspect_biology
from resource_intake.common import IntakeError, strict_json, verify_file
from resource_intake.manifest import PINS, validate_manifest, validate_release


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--release-json',required=True,type=Path)
    args=parser.parse_args()
    try:
        # Verify every input before any archive/manifest inspection.
        artifacts={name:verify_file(args.directory/name,pin['size_bytes'],pin['sha256']) for name,pin in PINS.items()}
        with args.release_json.open('rb') as stream:
            release=strict_json(stream.read(1048577),max_bytes=1048576)
        validate_release(release)
        manifest=validate_manifest((args.directory/'SIRAJ_AI_RESOURCES_MANIFEST.json').read_bytes())
        biology=inspect_biology(inspect_zip((args.directory/'Biology.zip').read_bytes()),PINS['embeddinggemma-2-text-270m.litertlm']['sha256'])
        aar=inspect_zip((args.directory/'litertlm-android-0.19.0.aar').read_bytes())
        print(json.dumps(dict(status='PASS', scope='PINNED_STAGING_STATIC_INTAKE_ONLY',
                              release_tag=release['tag_name'], artifacts=artifacts,
                              manifest=dict(status='PASS',classification=manifest['Status'], resource_entries=4,
                                            resource_urls='NOT PROVIDED',model_revisions='NOT PROVIDED',
                                            runtime_version=manifest['RuntimeRequirement']['Version']),
                              biology=biology, aar_archive=dict(status='PASS',archives=len(aar.nodes),
                                                               files=sum(len(n.files) for n in aar.nodes),expanded_bytes=aar.expanded_bytes),
                              runtime_compatibility='PENDING_VERIFICATION',device_validation='PENDING DEVICE TEST',
                              activation_performed=False),indent=2,ensure_ascii=False))
        return 0
    except IntakeError as error:
        print(json.dumps(dict(status='FAIL',code=error.code,activation_performed=False)))
        return 1
    except (OSError,KeyError,TypeError,ValueError):
        print(json.dumps(dict(status='FAIL',code='invalidOrUnavailableInput',activation_performed=False)))
        return 1


if __name__=='__main__':
    sys.exit(main())
