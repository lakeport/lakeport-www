#!/usr/bin/env python3
"""Negative edge-contract check: verify adding `Version.v3` without updating `clientHandler`
fails `lakeport check` with an unhandled union case error (proving no wildcard arms exist).
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def resolve_lakeport_bin() -> str:
    env_bin = os.environ.get("LAKEPORT_BIN")
    if env_bin and Path(env_bin).is_file():
        return env_bin
    which_bin = shutil.which("lakeport")
    if which_bin:
        return which_bin
    for candidate in [
        REPO.parent / "lakeport" / "packages" / "lakeport-cli" / "bin" / "lakeport",
        Path.home() / ".lakeport" / "bin" / "lakeport",
    ]:
        if candidate.is_file():
            return str(candidate)
    raise SystemExit("Could not locate `lakeport` binary. Set LAKEPORT_BIN or add `lakeport` to PATH.")


def resolve_scratch_dir() -> Path:
    base = Path(os.environ.get("TMPDIR") or tempfile.gettempdir())
    if str(base).startswith("/dev/shm"):
        base = Path.home() / ".cache" / "lakeport" / "tmp"
    base.mkdir(parents=True, exist_ok=True)
    return base


def main() -> None:
    lakeport = resolve_lakeport_bin()
    scratch_root = resolve_scratch_dir()
    with tempfile.TemporaryDirectory(dir=scratch_root, prefix="neg-v3-") as tmp:
        tmp_repo = Path(tmp) / "lakeport-www"
        shutil.copytree(
            REPO,
            tmp_repo,
            ignore=shutil.ignore_patterns(".git", ".lakeport", "dist", ".lake", "node_modules", ".wrangler"),
        )
        versions_file = tmp_repo / "shared" / "SiteContract" / "Versions.lean"
        src = versions_file.read_text(encoding="utf-8")
        mutated = src.replace("  | v2\n", "  | v2\n  | v3\n", 1)
        assert mutated != src, "Failed to inject | v3 into Versions.lean"
        versions_file.write_text(mutated, encoding="utf-8")

        env = os.environ.copy()
        env["TMPDIR"] = str(scratch_root)
        env["LAKEPORT_TASK_DIR"] = str(Path(tmp) / "cli")
        proc = subprocess.run(
            [lakeport, "check", str(tmp_repo)],
            capture_output=True,
            text=True,
            env=env,
        )
        combined = proc.stdout + "\n" + proc.stderr
        if proc.returncode == 0:
            raise SystemExit("FAIL: lakeport check unexpectedly succeeded with unhandled Version.v3!")
        if "v3" not in combined and "missing cases" not in combined:
            raise SystemExit(f"FAIL: check failed, but not with missing v3 cases:\n{combined}")
        print("PASS: injecting `| v3` failed compilation as expected (wildcard-free handlers verified).")


if __name__ == "__main__":
    main()
