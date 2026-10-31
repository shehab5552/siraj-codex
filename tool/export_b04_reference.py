"""Export verified Codex reference diffs, never apply them to another project.

Run from the Codex repository. Only docs/qa/b04_reference is written.
"""
import hashlib
import json
from pathlib import Path
import subprocess

BASE = "651af0d62d05761c80d9a8cbc9d1f51b836929eb"
CODE = "80b4f0fe1a228731ff6ae57ccdeb5598d201f681"


def git(*args):
    return subprocess.check_output(["git", *args])


def main():
    root = Path(git("rev-parse", "--show-toplevel").decode().strip())
    if Path.cwd().resolve() != root.resolve():
        raise SystemExit("Run at the root of the Codex repository")
    out = root / "docs/qa/b04_reference"
    entries = []
    paths = git("diff", "--name-only", BASE, CODE).decode().splitlines()
    for name in paths:
        if name.startswith("docs/"):
            continue
        relative = Path(name)
        assert not relative.is_absolute() and ".." not in relative.parts
        patch = git("diff", "--no-ext-diff", "--binary", BASE, CODE, "--", name)
        target = out / "patches" / (name + ".patch")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(patch)
        after = git("show", f"{CODE}:{name}")
        exists = subprocess.run(["git", "cat-file", "-e", f"{BASE}:{name}"], capture_output=True).returncode == 0
        before = git("show", f"{BASE}:{name}") if exists else None
        entry = {
            "path": name,
            "kind": "modified" if exists else "new",
            "patch": target.relative_to(out).as_posix(),
            "patch_sha256": hashlib.sha256(patch).hexdigest(),
            "codex_base_sha256": hashlib.sha256(before).hexdigest() if exists else None,
            "codex_result_sha256": hashlib.sha256(after).hexdigest(),
        }
        if not exists:
            full = out / "new_files" / (name + ".txt")
            full.parent.mkdir(parents=True, exist_ok=True)
            full.write_bytes(after)
            entry["full_new_file"] = full.relative_to(out).as_posix()
        elif name.endswith("/SirajSecureSessionChannel.kt"):
            full = out / "complete_platform" / (name + ".txt")
            full.parent.mkdir(parents=True, exist_ok=True)
            full.write_bytes(after)
            entry["full_reference_source"] = full.relative_to(out).as_posix()
        entries.append(entry)
    manifest = {
        "repository": "shehab5552/siraj-codex",
        "base": BASE,
        "code_commit": CODE,
        "warning": "REFERENCE ONLY. Original project has not been accessed. Adapt manually; never blindly overwrite Auth/SQLite or migrate/delete data.",
        "entries": entries,
    }
    out.mkdir(parents=True, exist_ok=True)
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(entries)} reference diffs from pinned Codex commits.")


if __name__ == "__main__":
    main()
