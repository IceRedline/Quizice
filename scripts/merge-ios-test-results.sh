#!/usr/bin/env bash
set -euo pipefail

# Merges category xcresults so the coverage threshold reflects the complete
# suite instead of penalizing Unit, UI, or Snapshot jobs in isolation.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly OUTPUT_PATH="${QUIZICE_COMBINED_RESULT_PATH:-DerivedData/CI/TestResults/combined.xcresult}"
readonly MIN_LINE_COVERAGE_PERCENT="${QUIZICE_MIN_LINE_COVERAGE_PERCENT:-80}"

fail() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

(( $# >= 2 )) || fail "pass at least two category xcresult paths"
[[ ! -e "$OUTPUT_PATH" ]] || fail "combined result already exists: $OUTPUT_PATH"

for result_bundle in "$@"; do
  [[ -d "$result_bundle" ]] || fail "category xcresult is missing: $result_bundle"
done

mkdir -p "$(dirname "$OUTPUT_PATH")"
xcrun xcresulttool merge --output-path "$OUTPUT_PATH" "$@"

coverage_json="$(mktemp -t quizice-combined-coverage.XXXXXX.json)"
trap 'rm -f "$coverage_json"' EXIT
xcrun xccov view --report --json "$OUTPUT_PATH" > "$coverage_json"

python3 - \
  "$coverage_json" \
  "$MIN_LINE_COVERAGE_PERCENT" \
  "${GITHUB_STEP_SUMMARY:-}" <<'PY'
import json
import sys

coverage_path, minimum, step_summary_path = sys.argv[1:4]
minimum_percent = float(minimum)
with open(coverage_path, "r", encoding="utf-8") as handle:
    report = json.load(handle)

targets = [
    target for target in report.get("targets", [])
    if target.get("name") in {"Quizice", "Quizice.app"}
    or (target.get("name", "").startswith("Quizice") and "Tests" not in target.get("name", ""))
]
if not targets:
    raise SystemExit("Quizice app target is missing from the combined coverage report")

target = max(targets, key=lambda item: item.get("executableLines", 0))
percent = float(target.get("lineCoverage", 0)) * 100
executable_lines = int(target.get("executableLines", 0))
covered_lines = round(executable_lines * percent / 100)

print(
    f"Combined Quizice app line coverage: {percent:.2f}% "
    f"({covered_lines}/{executable_lines} executable lines)"
)

if step_summary_path:
    with open(step_summary_path, "a", encoding="utf-8") as handle:
        handle.write("### Combined coverage\n\n")
        handle.write(
            f"Quizice app line coverage: **{percent:.2f}%** "
            f"({covered_lines}/{executable_lines}), required: **{minimum_percent:.0f}%**.\n\n"
        )

if percent + 1e-9 < minimum_percent:
    raise SystemExit(
        f"combined line coverage {percent:.2f}% is below required {minimum_percent:.0f}%"
    )
PY

printf '✅ Combined coverage is at least %s%%.\n' "$MIN_LINE_COVERAGE_PERCENT"
printf 'Combined xcresult: %s\n' "$OUTPUT_PATH"
