#!/usr/bin/env bash
set -euo pipefail

# S04 test infrastructure and safe local failure-states verifier.
#
# Scope rules:
# - delegates upstream S03 contract verification first;
# - runs the repository-local app build before tests;
# - selects an available iOS Simulator deterministically for xcodebuild test;
# - verifies the Quizice scheme discovers and executes the QuiziceTests smoke test;
# - keeps failures loud and actionable for local developer/CI-style invocation.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly S03_VERIFIER="./scripts/verify-s03-statistics-screen-contracts.sh"
readonly PROJECT="Quizice.xcodeproj"
readonly SCHEME="Quizice"
readonly CONFIGURATION="Debug"

log_section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  printf 'S04 verifier failed: %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing required file: $path"
}

select_ios_simulator_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

try:
    payload = json.load(sys.stdin)
except Exception as exc:
    raise SystemExit(f"could not parse simctl JSON: {exc}")

devices_by_runtime = payload.get("devices", {})
candidates = []
for runtime, devices in devices_by_runtime.items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name", "")
        # Prefer normal iPhone simulators over watches, TVs, iPads, or unavailable variants.
        if not name.startswith("iPhone"):
            continue
        state = device.get("state", "")
        udid = device.get("udid", "")
        if udid:
            candidates.append((0 if state == "Booted" else 1, runtime, name, udid))

if not candidates:
    raise SystemExit("no available iOS iPhone Simulator found")

for _, _, _, udid in sorted(candidates):
    print(udid)
    break
'
}

require_file "$S03_VERIFIER"
require_file "$PROJECT/project.pbxproj"
require_file "QuiziceTests/QuiziceTests.swift"

log_section "S03 delegated verifier"
"$S03_VERIFIER"
printf 'S03 delegated verifier: PASS\n'

log_section "Project and scheme discovery"
xcodebuild -list -project "$PROJECT" | tee /tmp/quizice-s04-xcodebuild-list.txt
grep -q "QuiziceTests" "$PROJECT/project.pbxproj" || fail "QuiziceTests target is missing from project.pbxproj"
grep -q "@testable import Quizice" "QuiziceTests/QuiziceTests.swift" || fail "smoke test does not import the Quizice app module"
printf 'Project contains QuiziceTests target and smoke import: PASS\n'

log_section "App build"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
printf 'App build: PASS\n'

log_section "Simulator selection"
readonly SIMULATOR_UDID="$(select_ios_simulator_udid)"
[[ -n "$SIMULATOR_UDID" ]] || fail "simulator selection returned an empty UDID"
printf 'Selected iOS Simulator: %s\n' "$SIMULATOR_UDID"

log_section "XCTest smoke target"
readonly TEST_LOG="$(mktemp -t quizice-s04-xctest.XXXXXX.log)"
if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  CODE_SIGNING_ALLOWED=NO \
  test | tee "$TEST_LOG"; then
  printf 'XCTest log retained at: %s\n' "$TEST_LOG" >&2
  fail "xcodebuild test failed"
fi

grep -Eq "Test Case '-\[QuiziceTests\.QuiziceTests testQuiziceModuleLoads\]' passed|Test Suite 'QuiziceTests' passed|Test case 'QuiziceTests\.testQuiziceModuleLoads\(\)' passed" "$TEST_LOG" \
  || fail "QuiziceTests smoke XCTest did not appear to execute; inspect $TEST_LOG"
printf 'XCTest smoke target: PASS\n'

log_section "S04 verifier result"
printf 'S04 tests and failure states verifier: PASS\n'
