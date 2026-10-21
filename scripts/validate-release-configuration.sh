#!/usr/bin/env bash
set -euo pipefail

# Called by the app target before compilation. This checks configuration only;
# it never contacts the backend and never prints potentially sensitive values.
if [[ "${CONFIGURATION:-}" != "Release" ]]; then
  exit 0
fi

/usr/bin/python3 - <<'PY'
import ipaddress
import os
import re
import sys
from urllib.parse import urlsplit


def fail():
    print(
        "error: Release requires BACKEND_BASE_URL to be an HTTPS backend URL "
        "ending in /api, without credentials, query or fragment. Set it in "
        "Configurations/Secrets.xcconfig or pass it as an Xcode build setting. "
        "APPMETRICA_API_KEY remains optional.",
        file=sys.stderr,
    )
    sys.exit(1)


value = os.environ.get("BACKEND_BASE_URL", "")
if not value or re.search(r"\s|\$|[\\<>]", value):
    fail()
try:
    url = urlsplit(value)
    host = url.hostname
    port = url.port
    if (url.scheme != "https" or not host or url.username is not None
            or url.password is not None or url.query or url.fragment
            or "?" in value or "#" in value
            or not url.path.rstrip("/").endswith("/api")
            or (port is not None and not 1 <= port <= 65535)):
        fail()
    if host == "localhost" or host.endswith((".localhost", ".local")):
        fail()
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        labels = host.encode("idna").decode("ascii").split(".")
        if len(labels) < 2 or any(
            not re.fullmatch(r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?", label)
            for label in labels
        ):
            fail()
    else:
        if not address.is_global:
            fail()
except (ValueError, UnicodeError):
    fail()
PY
