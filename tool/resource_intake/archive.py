"""Read-only recursive ZIP inspection; no extraction or promotion API."""
from dataclasses import dataclass, field
import hashlib
import io
from pathlib import PurePosixPath, PureWindowsPath
import re
import stat
import zipfile
import zlib

from .common import IntakeError


@dataclass
class ArchiveNode:
    chain: tuple[str, ...]
    files: dict[str, bytes] = field(default_factory=dict)


@dataclass
class ArchiveInspection:
    nodes: list[ArchiveNode] = field(default_factory=list)
    checksum_files: int = 0
    verified_checksums: int = 0
    expanded_bytes: int = 0


def inspect_zip(data: bytes, *, max_bytes=134217728, max_members=4096, max_depth=3):
    result = ArchiveInspection()
    member_count = 0

    def safe_path(name):
        text = name[:-1] if name.endswith('/') else name
        if not text or '\\' in text or '\0' in text or PurePosixPath(text).is_absolute() or PureWindowsPath(text).drive or any(p in ('', '.', '..') for p in text.split('/')):
            raise IntakeError('unsafeArchivePath')
        return text

    def visit(blob, chain, depth):
        nonlocal member_count
        if depth > max_depth or len(blob) > max_bytes:
            raise IntakeError('archiveLimit')
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            entries = archive.infolist()
            member_count += len(entries)
            if member_count > max_members:
                raise IntakeError('archiveLimit')
            names = {}
            for entry in entries:
                name = safe_path(entry.orig_filename)
                mode = entry.external_attr >> 16
                if stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                    raise IntakeError('archiveLinkOrSpecial')
                if entry.flag_bits & 1:
                    raise IntakeError('encryptedArchive')
                if name in names:
                    raise IntakeError('duplicateArchivePath')
                names[name] = entry
            for name in names:
                for parent in PurePosixPath(name).parents:
                    if str(parent) != '.' and str(parent) in names and not names[str(parent)].is_dir():
                        raise IntakeError('archivePathConflict')
            # Names/types are checked before reading any payload. No extraction.
            node = ArchiveNode(chain)
            result.nodes.append(node)
            for entry in entries:
                if entry.is_dir():
                    continue
                if entry.file_size < 0 or result.expanded_bytes + entry.file_size > max_bytes:
                    raise IntakeError('archiveLimit')
                content = bytearray()
                with archive.open(entry) as stream:
                    while block := stream.read(65536):
                        result.expanded_bytes += len(block)
                        if result.expanded_bytes > max_bytes:
                            raise IntakeError('archiveLimit')
                        content.extend(block)
                if len(content) != entry.file_size:
                    raise IntakeError('invalidZip')
                node.files[entry.filename] = bytes(content)
            for name, content in node.files.items():
                if PurePosixPath(name).name != 'checksums.sha256':
                    continue
                result.checksum_files += 1
                try:
                    lines = content.decode('utf-8', errors='strict').splitlines()
                except UnicodeError as error:
                    raise IntakeError('invalidUtf8') from error
                declared = set()
                for line in lines:
                    match = re.fullmatch(r'([a-fA-F0-9]{64}) [ *](.+)', line)
                    if not match:
                        raise IntakeError('invalidChecksumList')
                    digest, relative = match.groups()
                    safe_path(relative)
                    target = str(PurePosixPath(name).parent / relative)
                    if target in declared:
                        raise IntakeError('duplicateChecksumTarget')
                    declared.add(target)
                    if target not in node.files:
                        raise IntakeError('missingChecksumTarget')
                    if hashlib.sha256(node.files[target]).hexdigest() != digest.lower():
                        raise IntakeError('internalHashMismatch')
                    result.verified_checksums += 1
                if not declared:
                    raise IntakeError('invalidChecksumList')
            for name, content in node.files.items():
                if name.lower().endswith(('.zip', '.jar', '.aar')) or zipfile.is_zipfile(io.BytesIO(content)):
                    visit(content, (*chain, name), depth + 1)

    try:
        visit(data, (), 0)
    except IntakeError:
        raise
    except (zipfile.BadZipFile, zlib.error, ValueError, RuntimeError, NotImplementedError, UnicodeError, EOFError) as error:
        raise IntakeError('invalidZip') from error
    return result
