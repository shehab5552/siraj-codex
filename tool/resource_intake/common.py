"""Bounded byte/JSON checks for developer intake, not product readiness."""
from pathlib import Path
import hashlib
import json
import math
import os
import re
import stat


class IntakeError(ValueError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def strict_json(data: bytes, *, max_bytes: int = 65536):
    if len(data) > max_bytes:
        raise IntakeError('metadataTooLarge')
    try:
        text = data.decode('utf-8', errors='strict')
    except UnicodeError as error:
        raise IntakeError('invalidUtf8') from error

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise IntakeError('duplicateJsonKey')
            result[key] = value
        return result

    def nonfinite(_):
        raise IntakeError('invalidJson')

    def finite_float(value):
        result = float(value)
        if not math.isfinite(result):
            raise IntakeError('invalidJson')
        return result

    try:
        return json.loads(text, object_pairs_hook=pairs, parse_constant=nonfinite, parse_float=finite_float)
    except IntakeError:
        raise
    except (ValueError, RecursionError) as error:
        raise IntakeError('invalidJson') from error


def verify_file(path: Path, size: int, sha256: str) -> dict:
    if type(size) is not int or size < 0 or not re.fullmatch('[a-fA-F0-9]{64}', sha256):
        raise IntakeError('invalidExpectation')
    path = Path(path).absolute()
    if '..' in path.parts or any(p.is_symlink() for p in (path, *path.parents)):
        raise IntakeError('unsafePath')
    try:
        if not stat.S_ISREG(path.lstat().st_mode):
            raise IntakeError('unsafePath')
        fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            if before.st_size != size:
                raise IntakeError('sizeMismatch')
            digest = hashlib.sha256()
            total = 0
            while block := stream.read(65536):
                total += len(block)
                if total > size:
                    raise IntakeError('fileChanged')
                digest.update(block)
            after = os.fstat(stream.fileno())
        current = path.lstat()
        fields = ('st_dev', 'st_ino', 'st_size', 'st_mtime_ns', 'st_ctime_ns')
        if total != size or any(getattr(before, f) != getattr(after, f) or getattr(after, f) != getattr(current, f) for f in fields):
            raise IntakeError('fileChanged')
        actual = digest.hexdigest()
        if actual != sha256.lower():
            raise IntakeError('hashMismatch')
        return {'size_bytes': total, 'sha256': actual}
    except OSError as error:
        raise IntakeError('artifactIoFailure') from error
