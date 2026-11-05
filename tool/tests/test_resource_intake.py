"""Hostile input tests use generated, isolated files; no shipped model fixtures."""
import hashlib
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from resource_intake.archive import inspect_zip
from resource_intake.common import IntakeError, strict_json, verify_file


def make_zip(entries, *, stored=False):
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED) as z:
        for name, content in entries:
            z.writestr(name, content)
    return output.getvalue()


class CommonTest(unittest.TestCase):
    def test_valid_utf8_json(self):
        self.assertEqual(strict_json('{"لغة":"عربي"}'.encode()), {'لغة': 'عربي'})

    def test_invalid_utf8(self):
        with self.assertRaisesRegex(IntakeError, 'invalidUtf8'):
            strict_json(b'{"x":"\xff"}')

    def test_invalid_json(self):
        with self.assertRaisesRegex(IntakeError, 'invalidJson'):
            strict_json(b'{')

    def test_duplicate_key(self):
        with self.assertRaisesRegex(IntakeError, 'duplicateJsonKey'):
            strict_json(b'{"Status":"STAGING","Status":"READY"}')

    def test_nonfinite_json(self):
        for token in ['NaN', 'Infinity', '-Infinity', '1e999', '-1e999']:
            with self.subTest(token=token), self.assertRaisesRegex(IntakeError, 'invalidJson'):
                strict_json(('{"x":'+token+'}').encode())

    def test_json_limit(self):
        with self.assertRaisesRegex(IntakeError, 'metadataTooLarge'):
            strict_json(b' ' * 100, max_bytes=16)

    def test_actual_size_and_streamed_sha(self):
        with tempfile.TemporaryDirectory() as d:
            file = Path(d)/'artifact';file.write_bytes(b'abc')
            self.assertEqual(verify_file(file, 3, hashlib.sha256(b'abc').hexdigest()),
                             {'size_bytes': 3, 'sha256': hashlib.sha256(b'abc').hexdigest()})

    def test_size_and_hash_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            file = Path(d)/'artifact';file.write_bytes(b'abc')
            for size, digest, reason in [(4, hashlib.sha256(b'abc').hexdigest(), 'sizeMismatch'), (3, '0'*64, 'hashMismatch')]:
                with self.subTest(reason=reason), self.assertRaisesRegex(IntakeError, reason):
                    verify_file(file, size, digest)

    def test_symlink_does_not_count_as_artifact(self):
        with tempfile.TemporaryDirectory() as d:
            file = Path(d)/'outside';file.write_bytes(b'abc');link = Path(d)/'link';link.symlink_to(file)
            with self.assertRaisesRegex(IntakeError, 'unsafePath'):
                verify_file(link, 3, hashlib.sha256(b'abc').hexdigest())


class ZipTest(unittest.TestCase):
    def test_nested_zip_and_crc(self):
        inner = make_zip([('content.json', b'{}')])
        report = inspect_zip(make_zip([('Biology/Unit_01/pilot.zip', inner)]))
        self.assertEqual(len(report.nodes), 2)
        self.assertEqual(report.nodes[1].files['content.json'], b'{}')

    def test_truncated_zip(self):
        with self.assertRaisesRegex(IntakeError, 'invalidZip'):
            inspect_zip(make_zip([('a', b'abc')])[:-8])

    def test_crc_corruption(self):
        data = make_zip([('a', b'UNIQUE_PAYLOAD')], stored=True).replace(b'UNIQUE_PAYLOAD', b'BROKEN_PAYLOAD')
        with self.assertRaisesRegex(IntakeError, 'invalidZip'):
            inspect_zip(data)

    def test_traversal_absolute_windows_and_empty_segments(self):
        for name in ['../active', '/active', 'C:/active', 'C:active', 'a\\..\\active', 'a/../active', 'a/./b', 'a//b']:
            with self.subTest(name=name), self.assertRaisesRegex(IntakeError, 'unsafeArchivePath'):
                inspect_zip(make_zip([(name, b'x')]))

    def test_symlink_member(self):
        member = zipfile.ZipInfo('link');member.create_system = 3;member.external_attr = (stat.S_IFLNK|0o777)<<16
        with self.assertRaisesRegex(IntakeError, 'archiveLinkOrSpecial'):
            inspect_zip(make_zip([(member, b'../active')]))

    def test_duplicate_and_file_directory_alias(self):
        for entries in [[('same', b'a'), ('same', b'b')], [('a', b'file'), ('a/b', b'child')]]:
            with self.subTest(entries=entries), self.assertRaisesRegex(IntakeError, 'duplicateArchivePath|archivePathConflict'):
                # zipfile's duplicate warning concerns the intentionally hostile fixture.
                import warnings
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', UserWarning)
                    inspect_zip(make_zip(entries))

    def test_expansion_member_and_depth_limits(self):
        cases = [(make_zip([('a', b'x'*100)]), {'max_bytes':10}), (make_zip([('a', b'a'), ('b', b'b')]), {'max_members':1}), (make_zip([('inner.zip', make_zip([('a', b'a')]))]), {'max_depth':0})]
        for data, limits in cases:
            with self.subTest(limits=limits), self.assertRaisesRegex(IntakeError, 'archiveLimit'):
                inspect_zip(data, **limits)

    def test_all_declared_internal_hashes(self):
        checksum = (hashlib.sha256(b'abc').hexdigest()+'  data.bin\n').encode()
        result = inspect_zip(make_zip([('data.bin', b'abc'), ('checksums.sha256', checksum)]))
        self.assertEqual((result.checksum_files, result.verified_checksums), (1, 1))

    def test_bad_or_missing_internal_hash_target(self):
        for name, digest in [('data.bin', '0'*64), ('missing.bin', hashlib.sha256(b'abc').hexdigest())]:
            with self.subTest(name=name), self.assertRaisesRegex(IntakeError, 'internalHashMismatch|missingChecksumTarget'):
                inspect_zip(make_zip([('data.bin', b'abc'), ('checksums.sha256', (digest+'  '+name+'\n').encode())]))

    def test_rejection_preserves_existing_resource(self):
        with tempfile.TemporaryDirectory() as d:
            active = Path(d)/'active';active.write_bytes(b'previous-approved-resource')
            with self.assertRaises(IntakeError):
                inspect_zip(make_zip([('../active', b'replacement')]))
            self.assertEqual(active.read_bytes(), b'previous-approved-resource')
            self.assertEqual(list(Path(d).iterdir()), [active])


if __name__ == '__main__':
    unittest.main()
