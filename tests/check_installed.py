"""Exercise the installed executable without calling a GPU operation."""

import subprocess
import sys
from pathlib import Path


def main():
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    version = sys.argv[2]
    cases = [
        (["--version"], 0, f"cuda-vector-add {version}\n", ""),
        (["--help"], 0, None, ""),
        ([], 2, "", None),
        (["--unknown"], 2, "", None),
        (["--version", "extra"], 2, "", None),
    ]
    for arguments, expected_status, expected_stdout, expected_stderr in cases:
        result = subprocess.run(
            [executable, *arguments], capture_output=True, text=True, timeout=30
        )
        if result.returncode != expected_status:
            raise RuntimeError(f"{arguments}: status {result.returncode}, "
                               f"expected {expected_status}: {result.stderr}")
        for stream, expected in [(result.stdout, expected_stdout),
                                 (result.stderr, expected_stderr)]:
            if expected is not None and stream != expected:
                raise RuntimeError(f"{arguments}: unexpected output {stream!r}")
        if arguments == ["--help"] and "--gpu-test" not in result.stdout:
            raise RuntimeError("GPU test is missing from installed help")
        if expected_status == 2 and "Usage:" not in result.stderr:
            raise RuntimeError(f"{arguments}: missing usage diagnostic")
    print("PASS: installed version, help, and argument validation (no GPU required)")


if __name__ == "__main__":
    main()
