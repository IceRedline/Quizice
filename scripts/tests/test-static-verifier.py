#!/usr/bin/env python3
"""Ensure --checks-only never starts Xcode or resolves packages."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class StaticVerifierTests(unittest.TestCase):
    def test_checks_only_never_launches_xcodebuild(self):
        with tempfile.TemporaryDirectory(prefix="quizice-static-verifier-") as directory:
            stub = Path(directory) / "xcodebuild"
            marker = Path(directory) / "called"
            stub.write_text('#!/bin/sh\ntouch "$QUIZICE_XCODEBUILD_CALL_LOG"\nexit 91\n')
            stub.chmod(0o755)
            environment = dict(
                os.environ, PATH=f"{directory}:{os.environ['PATH']}",
                QUIZICE_XCODEBUILD_CALL_LOG=str(marker),
            )
            environment.pop("QUIZICE_SKIP_XCODEBUILD", None)
            result = subprocess.run(
                ["/bin/bash", "scripts/verify-s04-tests-and-failure-states.sh", "--checks-only"],
                cwd=ROOT, env=environment, capture_output=True, text=True, check=False,
            )
            self.assertFalse(marker.exists(), "Static verification invoked xcodebuild")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
