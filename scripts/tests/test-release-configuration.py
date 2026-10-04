#!/usr/bin/env python3
"""Offline regression tests for the build-time Release configuration gate."""
import os
from pathlib import Path
import subprocess
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "validate-release-configuration.sh"


class ReleaseConfigurationTests(unittest.TestCase):
    def run_gate(self, value, configuration="Release"):
        environment = dict(os.environ, CONFIGURATION=configuration)
        environment.pop("APPMETRICA_API_KEY", None)
        environment.pop("BACKEND_BASE_URL", None)
        if value is not None:
            environment["BACKEND_BASE_URL"] = value
        return subprocess.run(
            ["/bin/bash", str(SCRIPT)], env=environment,
            text=True, capture_output=True, check=False,
        )

    def test_release_accepts_https_backend_without_analytics(self):
        for value in ("https://backend.example.com/api", "https://staging.example.com:8443/service/api/"):
            with self.subTest(value=value):
                result = self.run_gate(value)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_release_rejects_missing_unsafe_and_malformed_endpoints(self):
        invalid = (
            None, "", "$(BACKEND_BASE_URL)", "${BACKEND_BASE_URL}",
            "https:", "backend.example.com/api", "http://backend.example.com/api",
            "https://backend.example.com", "https://backend.example.com/notapi",
            "https://localhost/api", "https://127.0.0.1/api", "https://[::1]/api",
            "https://10.1.2.3/api", "https://backend.local/api",
            "https://backend.example.com:70000/api", "https://bad_host.example.com/api",
            "https://backend.example.com/api?token=secret", "https://backend.example.com/api#part",
            "https://backend.example.com/api?", "https://backend.example.com/api#",
            " https://backend.example.com/api", "https://backend.example.com/api\n",
            "https://backend.example.com\\@other.example.com/api",
        )
        for value in invalid:
            with self.subTest(value=value):
                result = self.run_gate(value)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Release requires BACKEND_BASE_URL", result.stderr)

    def test_error_does_not_disclose_credentials(self):
        result = self.run_gate("https://private-user:private-password@backend.example.com/api")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("private-user", result.stdout + result.stderr)
        self.assertNotIn("private-password", result.stdout + result.stderr)

    def test_debug_can_build_without_backend_configuration(self):
        self.assertEqual(self.run_gate(None, configuration="Debug").returncode, 0)


if __name__ == "__main__":
    unittest.main()
