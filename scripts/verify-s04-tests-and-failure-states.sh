#!/usr/bin/env bash
set -euo pipefail

# S04 test infrastructure and safe local failure-states verifier.
#
# Scope rules:
# - delegates upstream S03 contract verification first;
# - runs the repository-local app build before tests;
# - selects an available iOS Simulator deterministically for xcodebuild test;
# - verifies the Quizice scheme discovers and executes the QuiziceTests suite;
# - verifies the R007/R008 XCTest coverage markers remain present;
# - verifies Point-Free SnapshotTesting is linked through the QuiziceTests target;
# - runs tests with code coverage and enforces a risk-based minimum app line coverage;
# - preserves Quizice/data.json and never uses it as a mutable fixture;
# - keeps failures loud and actionable for local developer/CI-style invocation.
#
# To intentionally refresh image snapshots locally, run the XCTest command below
# with SNAPSHOT_TESTING_RECORD=all, inspect the changed PNGs, then rerun this
# verifier without recording.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly S03_VERIFIER="./scripts/verify-s03-statistics-screen-contracts.sh"
readonly PROJECT="Quizice.xcodeproj"
readonly PROJECT_FILE="$PROJECT/project.pbxproj"
readonly SCHEME="Quizice"
readonly CONFIGURATION="Debug"
readonly DATA_JSON="Quizice/data.json"
readonly SMOKE_TESTS="QuiziceTests/Unit/QuiziceTests.swift"
readonly SUMMARY_TESTS="QuiziceTests/Unit/StatisticsSummaryTests.swift"
readonly STORE_TESTS="QuiziceTests/Unit/StatisticsStoreTests.swift"
readonly PRESENTER_FAILURE_TESTS="QuiziceTests/Unit/QuizQuestionPresenterFailureStateTests.swift"
readonly SNAPSHOT_SUPPORT_TESTS="QuiziceTests/Snapshots/SnapshotSupport.swift"
readonly COMPONENT_SNAPSHOT_TESTS="QuiziceTests/Snapshots/ComponentSnapshotTests.swift"
readonly HOME_CARD_SNAPSHOT_TESTS="QuiziceTests/Snapshots/HomeCardSnapshotTests.swift"
readonly SCREEN_SNAPSHOT_TESTS="QuiziceTests/Snapshots/ScreenSnapshotTests.swift"
readonly SWIFTUI_SNAPSHOT_TESTS="QuiziceTests/Snapshots/SwiftUISnapshotTests.swift"
readonly APP_APPEARANCE_TESTS="QuiziceTests/Unit/AppAppearanceTests.swift"
readonly QUIZ_PRESENTER_TESTS="QuiziceTests/Unit/QuizPresenterTests.swift"
readonly QUESTION_PRESENTER_TESTS="QuiziceTests/Unit/QuizQuestionPresenterTests.swift"
readonly QUIZ_FACTORY_TESTS="QuiziceTests/Unit/QuizFactoryTests.swift"
readonly QUIZ_COORDINATOR_TESTS="QuiziceTests/Unit/QuizFlowCoordinatorAdditionalTests.swift"
readonly MIN_LINE_COVERAGE_PERCENT=80

TEMP_FILES=()
TEMP_PATHS=()
DATA_JSON_INITIAL_HASH=""

log_section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  printf '❌ S04 verifier failed: %s\n' "$1" >&2
  exit 1
}

remember_temp_file() {
  TEMP_FILES+=("$1")
}

remember_temp_path() {
  TEMP_PATHS+=("$1")
}

cleanup() {
  local path
  for path in "${TEMP_FILES[@]+"${TEMP_FILES[@]}"}"; do
    [[ -n "$path" && -f "$path" ]] && rm -f "$path"
  done
  for path in "${TEMP_PATHS[@]+"${TEMP_PATHS[@]}"}"; do
    [[ -n "$path" && -e "$path" ]] && rm -rf "$path"
  done
}
trap cleanup EXIT

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing required file: $path"
}

require_executable() {
  local path="$1"
  [[ -x "$path" ]] || fail "required verifier is missing or not executable: $path"
}

require_fixed_string() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  require_file "$path"
  if ! grep -Fq "$pattern" "$path"; then
    fail "$message ($path must contain: $pattern)"
  fi
}

require_extended_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  require_file "$path"
  if ! grep -Eq "$pattern" "$path"; then
    fail "$message ($path must match: $pattern)"
  fi
}

file_sha256() {
  local path="$1"
  require_file "$path"
  shasum -a 256 "$path" | awk '{print $1}'
}

record_data_json_hash() {
  DATA_JSON_INITIAL_HASH="$(file_sha256 "$DATA_JSON")"
  printf 'Recorded %s SHA-256 before verifier workflow: %s\n' "$DATA_JSON" "$DATA_JSON_INITIAL_HASH"
}

assert_data_json_unchanged() {
  local current_hash
  current_hash="$(file_sha256 "$DATA_JSON")"
  if [[ "$current_hash" != "$DATA_JSON_INITIAL_HASH" ]]; then
    fail "$DATA_JSON was modified by the S04 verifier workflow (before: $DATA_JSON_INITIAL_HASH, after: $current_hash)"
  fi
  printf '%s preserved: PASS\n' "$DATA_JSON"
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

check_project_and_test_wiring() {
  log_section "Project and XCTest target wiring checks"

  require_file "$PROJECT_FILE"
  require_file "$SMOKE_TESTS"
  require_file "$SUMMARY_TESTS"
  require_file "$STORE_TESTS"
  require_file "$PRESENTER_FAILURE_TESTS"
  require_file "$SNAPSHOT_SUPPORT_TESTS"
  require_file "$COMPONENT_SNAPSHOT_TESTS"
  require_file "$HOME_CARD_SNAPSHOT_TESTS"
  require_file "$SCREEN_SNAPSHOT_TESTS"
  require_file "$SWIFTUI_SNAPSHOT_TESTS"
  require_file "$APP_APPEARANCE_TESTS"
  require_file "$QUIZ_PRESENTER_TESTS"
  require_file "$QUESTION_PRESENTER_TESTS"
  require_file "$QUIZ_FACTORY_TESTS"
  require_file "$QUIZ_COORDINATOR_TESTS"

  local xcodebuild_list_log
  xcodebuild_list_log="$(mktemp -t quizice-s04-xcodebuild-list.XXXXXX.log)"
  remember_temp_file "$xcodebuild_list_log"
  xcodebuild -list -project "$PROJECT" | tee "$xcodebuild_list_log"

  require_fixed_string "$PROJECT_FILE" 'QuiziceTests' 'QuiziceTests target must be present in the Xcode project'
  require_fixed_string "$PROJECT_FILE" 'productType = "com.apple.product-type.bundle.unit-test";' 'QuiziceTests must remain an XCTest unit-test bundle'
  require_fixed_string "$PROJECT_FILE" 'TestTargetID = 993C1BA82D8D5E8900AD9BE4;' 'QuiziceTests must remain app-hosted by the Quizice app target'
  require_fixed_string "$PROJECT_FILE" 'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Quizice.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Quizice";' 'QuiziceTests must keep a concrete app TEST_HOST'
  require_fixed_string "$PROJECT_FILE" 'BUNDLE_LOADER = "$(TEST_HOST)";' 'QuiziceTests must load through TEST_HOST'
  require_extended_regex "$PROJECT_FILE" 'QuiziceTests\.swift in Sources' 'QuiziceTests smoke test must remain in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'StatisticsSummaryTests\.swift in Sources' 'StatisticsSummaryTests must remain in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'StatisticsStoreTests\.swift in Sources' 'StatisticsStoreTests must remain in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'QuizQuestionPresenterFailureStateTests\.swift in Sources' 'QuizQuestionPresenterFailureStateTests must remain in the test Sources build phase'
  require_fixed_string "$PROJECT_FILE" 'https://github.com/pointfreeco/swift-snapshot-testing' 'Point-Free SnapshotTesting package must be referenced by the Xcode project'
  require_fixed_string "$PROJECT_FILE" 'SnapshotTesting in Frameworks' 'SnapshotTesting product must be linked into the test target'
  require_extended_regex "$PROJECT_FILE" 'SnapshotSupport\.swift in Sources' 'Snapshot support helpers must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'ComponentSnapshotTests\.swift in Sources' 'Component snapshot tests must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'HomeCardSnapshotTests\.swift in Sources' 'Home-card snapshot tests must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'ScreenSnapshotTests\.swift in Sources' 'Screen snapshot tests must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'SwiftUISnapshotTests\.swift in Sources' 'SwiftUI snapshot tests must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'AppAppearanceTests\.swift in Sources' 'App appearance tests must be in the test Sources build phase'
  require_extended_regex "$PROJECT_FILE" 'QuizQuestionPresenterTests\.swift in Sources' 'Expanded question presenter tests must be in the test Sources build phase'
  require_fixed_string "$SMOKE_TESTS" '@testable import Quizice' 'Smoke tests must import the Quizice app module'
  require_fixed_string "$xcodebuild_list_log" 'Quizice' 'Quizice scheme must be visible to xcodebuild'

  printf 'Project contains app-hosted QuiziceTests target and required XCTest files: PASS\n'
}

check_statistics_coverage_markers() {
  log_section "R007 statistics coverage-marker checks"

  require_fixed_string "$SUMMARY_TESTS" 'testEmptySummaryHasZeroTotalsAndDisplayValues' 'Statistics tests must cover the empty summary baseline'
  require_fixed_string "$SUMMARY_TESTS" 'testSummaryAggregatesPlayedQuizzesCorrectAnswersAndTotalQuestions' 'Statistics tests must cover played quiz, correct-answer, and total-question aggregation'
  require_fixed_string "$SUMMARY_TESTS" 'XCTAssertEqual(summary.correctAnswers, 12)' 'Statistics tests must assert aggregate correct answers'
  require_fixed_string "$SUMMARY_TESTS" 'XCTAssertEqual(summary.totalQuestions, 17)' 'Statistics tests must assert aggregate total questions'
  require_fixed_string "$SUMMARY_TESTS" 'testPercentageIsRoundedToNearestWholeNumber' 'Statistics tests must cover percentage rounding'
  require_fixed_string "$SUMMARY_TESTS" 'XCTAssertEqual(summary.percentage, 67)' 'Statistics tests must assert rounded percentage'
  require_fixed_string "$SUMMARY_TESTS" 'testBestResultDisplayUsesBestAttempt' 'Statistics tests must cover best-result display'
  require_fixed_string "$SUMMARY_TESTS" 'testBestResultSelectsHigherPercentageOverMoreCorrectAnswers' 'Statistics tests must cover best-result percentage precedence'
  require_fixed_string "$SUMMARY_TESTS" 'testBestResultTieUsesMoreCorrectAnswers' 'Statistics tests must cover best-result tie handling'
  require_fixed_string "$SUMMARY_TESTS" 'testExactTieKeepsSmallerTotalQuestionAttempt' 'Statistics tests must cover exact tie behavior'
  require_fixed_string "$STORE_TESTS" 'testRecordAttemptPersistsValidAttempts' 'Statistics store tests must cover valid attempt persistence'
  require_fixed_string "$STORE_TESTS" 'XCTAssertNotNil(harness.defaults.data(forKey: harness.key))' 'Statistics store tests must assert persistence for valid attempts'

  printf 'R007 statistics marker checks: PASS\n'
}

check_failure_state_coverage_markers() {
  log_section "R008 local failure-state coverage-marker checks"

  require_fixed_string "$STORE_TESTS" 'testFirstRunLoadSummaryReturnsEmpty' 'Statistics store tests must cover first-run empty state'
  require_fixed_string "$STORE_TESTS" 'XCTAssertEqual(harness.store.loadSummary(), .empty)' 'Statistics store tests must assert empty fallback behavior'
  require_fixed_string "$STORE_TESTS" 'testLoadSummaryReturnsEmptyForCorruptPersistedBytesAndRemovesKey' 'Statistics store tests must cover corrupt persisted bytes'
  require_fixed_string "$STORE_TESTS" 'Data("not-json".utf8)' 'Statistics store tests must inject corrupt persisted bytes without app fixtures'
  require_fixed_string "$STORE_TESTS" 'testLoadSummaryReturnsEmptyAndRemovesKeyForMalformedAttemptPayload' 'Statistics store tests must cover malformed persisted attempt payloads'
  require_fixed_string "$STORE_TESTS" 'XCTAssertNil(harness.defaults.data(forKey: harness.key))' 'Statistics store tests must assert corrupt/malformed persistence is removed'
  require_fixed_string "$STORE_TESTS" 'testRecordAttemptIgnoresNonPositiveTotals' 'Statistics store tests must cover invalid non-positive totals'
  require_fixed_string "$STORE_TESTS" 'testRecordAttemptSanitizesCorrectAnswersOutsideValidRange' 'Statistics store tests must cover out-of-range correct-answer sanitization'

  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testNilChosenThemeShowsUnavailableQuestionState' 'Presenter failure-state tests must cover nil chosen theme'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testChosenThemeWithNoQuestionsShowsUnavailableQuestionState' 'Presenter failure-state tests must cover empty local question arrays'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testQuestionWithEmptyTextShowsUnavailableQuestionState' 'Presenter failure-state tests must cover malformed blank question text'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testQuestionWithFewerThanFourAnswersShowsUnavailableQuestionState' 'Presenter failure-state tests must cover malformed answer counts'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testQuestionWithEmptyCorrectAnswerShowsUnavailableQuestionState' 'Presenter failure-state tests must cover malformed blank correct answer'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'assertMalformedQuestionShowsUnavailable' 'Presenter failure-state tests must share malformed-question unavailable-state assertions'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'assertUnavailableState' 'Presenter failure-state tests must assert the unavailable-question contract'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'XCTAssertEqual(view.unavailableCalls.count, 1' 'Unavailable-question assertions must verify exactly one unavailable state'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'XCTAssertTrue(view.loadedQuestions.isEmpty' 'Unavailable-question assertions must verify malformed questions are not loaded'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'XCTAssertEqual(view.resultsCallCount, 0' 'Unavailable-question assertions must verify no result navigation fires'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'QuizQuestionPresenter(session: session)' 'Presenter tests must use injected session state instead of QuizFactory.shared'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testQuestionWithDuplicatedCorrectAnswerShowsUnavailableQuestionState' 'Presenter failure-state tests must cover ambiguous duplicate correct-answer titles'
  require_fixed_string "$PRESENTER_FAILURE_TESTS" 'testAnswerSelectionUsesOptionID' 'Presenter tests must cover answer selection by option id'

  if grep -Fq "$DATA_JSON" "$SUMMARY_TESTS" "$STORE_TESTS" "$PRESENTER_FAILURE_TESTS"; then
    fail "S04 tests must use synthetic fixtures and isolated UserDefaults, not mutable $DATA_JSON"
  fi

  printf 'R008 failure-state marker checks: PASS\n'
}

check_snapshot_coverage_markers() {
  log_section "Snapshot and expanded unit coverage-marker checks"

  require_fixed_string "$SNAPSHOT_SUPPORT_TESTS" 'import SnapshotTesting' 'Snapshot support must import Point-Free SnapshotTesting'
  require_fixed_string "$SNAPSHOT_SUPPORT_TESTS" 'AppLocalizationStore.shared.languagePreference = language' 'Snapshot support must pin language'
  require_fixed_string "$SNAPSHOT_SUPPORT_TESTS" 'UIView.setAnimationsEnabled(false)' 'Snapshot support must disable animations'
  require_fixed_string "$COMPONENT_SNAPSHOT_TESTS" 'testPrimaryButtonsAcrossDesignStyles' 'Component snapshots must cover primary buttons across styles'
  require_fixed_string "$COMPONENT_SNAPSHOT_TESTS" 'testSecondaryButtonsAcrossDesignStyles' 'Component snapshots must cover secondary buttons across styles'
  require_fixed_string "$HOME_CARD_SNAPSHOT_TESTS" 'testThemeCardSnapshot' 'Home card snapshots must cover theme cards'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testHomeScreenSnapshot' 'Screen snapshots must cover home'
  require_fixed_string "$SWIFTUI_SNAPSHOT_TESTS" 'testSettingsViewSnapshot' 'SwiftUI snapshots must cover settings'
  require_fixed_string "$APP_APPEARANCE_TESTS" 'testAllDesignStylesResolveExpectedSurfaceFamilies' 'Appearance tests must cover all design styles'
  require_fixed_string "$QUESTION_PRESENTER_TESTS" 'testCorrectAnswerRecordsSingleCompletedAttemptAndEmitsResult' 'Question presenter tests must cover result emission and statistics recording'
  require_fixed_string "$QUIZ_FACTORY_TESTS" 'testSwiftDataThemeStoreReplacesFetchesAndClearsThemes' 'Factory tests must cover in-memory SwiftData theme store behavior'

  printf 'Snapshot and expanded unit coverage-marker checks: PASS\n'
}

run_app_build() {
  log_section "App build"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphonesimulator \
    CODE_SIGNING_ALLOWED=NO \
    build
  printf 'App build: PASS\n'
}

check_coverage() {
  local result_bundle="$1"
  local coverage_json
  coverage_json="$(mktemp -t quizice-s04-xccov.XXXXXX.json)"
  remember_temp_file "$coverage_json"

  xcrun xccov view --report --json "$result_bundle" > "$coverage_json"
  python3 - "$coverage_json" "$MIN_LINE_COVERAGE_PERCENT" <<'PY'
import json
import sys

path = sys.argv[1]
minimum = float(sys.argv[2])
with open(path, "r", encoding="utf-8") as handle:
    report = json.load(handle)

targets = report.get("targets", [])
app_targets = [
    target for target in targets
    if target.get("name") in {"Quizice.app", "Quizice"}
    or (target.get("name", "").startswith("Quizice") and "Tests" not in target.get("name", ""))
]

if not app_targets:
    raise SystemExit("could not find Quizice app target in xccov report")

target = sorted(app_targets, key=lambda item: item.get("executableLines", 0), reverse=True)[0]
line_coverage = target.get("lineCoverage")
if line_coverage is None:
    raise SystemExit("Quizice app target did not include lineCoverage")

percent = line_coverage * 100
print(f"Quizice app line coverage: {percent:.2f}%")
if percent + 1e-9 < minimum:
    raise SystemExit(f"line coverage {percent:.2f}% is below required {minimum:.0f}%")
PY
  printf 'Coverage threshold (%s%%): PASS\n' "$MIN_LINE_COVERAGE_PERCENT"
}

run_unit_tests() {
  log_section "Simulator selection"
  local simulator_udid
  simulator_udid="$(select_ios_simulator_udid)"
  [[ -n "$simulator_udid" ]] || fail "simulator selection returned an empty UDID"
  printf 'Selected iOS Simulator: %s\n' "$simulator_udid"

  log_section "XCTest suite"
  local test_log
  test_log="$(mktemp -t quizice-s04-xctest.XXXXXX.log)"
  remember_temp_file "$test_log"
  local result_bundle
  result_bundle="$(mktemp -d "${TMPDIR:-/tmp}/quizice-s04-result.XXXXXX.xcresult")"
  rm -rf "$result_bundle"
  remember_temp_path "$result_bundle"

  if ! xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    CODE_SIGNING_ALLOWED=NO \
    -enableCodeCoverage YES \
    -resultBundlePath "$result_bundle" \
    test | tee "$test_log"; then
    printf 'XCTest log retained at: %s\n' "$test_log" >&2
    fail "xcodebuild test failed"
  fi

  require_extended_regex "$test_log" "Test Case '-\\[QuiziceTests\\.QuiziceTests testQuiziceModuleLoads\\]' passed|Test Suite 'QuiziceTests' passed|Test case 'QuiziceTests\\.testQuiziceModuleLoads\\(\\)' passed" \
    'QuiziceTests smoke XCTest did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'StatisticsSummaryTests' passed|Test case 'StatisticsSummaryTests\\." \
    'StatisticsSummaryTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'StatisticsStoreTests' passed|Test case 'StatisticsStoreTests\\." \
    'StatisticsStoreTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'QuizQuestionPresenterFailureStateTests' passed|Test case 'QuizQuestionPresenterFailureStateTests\\." \
    'QuizQuestionPresenterFailureStateTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'ComponentSnapshotTests' passed|Test case 'ComponentSnapshotTests\\." \
    'ComponentSnapshotTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'ScreenSnapshotTests' passed|Test case 'ScreenSnapshotTests\\." \
    'ScreenSnapshotTests did not appear to execute'

  printf 'XCTest suite: PASS\n'
  check_coverage "$result_bundle"
}

log_section "Required files and data preservation baseline"
require_executable "$S03_VERIFIER"
require_file "$PROJECT_FILE"
require_file "$DATA_JSON"
record_data_json_hash

log_section "S03 delegated verifier"
"$S03_VERIFIER"
printf 'S03 delegated verifier: PASS\n'
assert_data_json_unchanged

check_project_and_test_wiring
check_statistics_coverage_markers
check_failure_state_coverage_markers
check_snapshot_coverage_markers
assert_data_json_unchanged
run_app_build
assert_data_json_unchanged
run_unit_tests
assert_data_json_unchanged

log_section "S04 verifier result"
printf 'S03 delegation, app build, unit tests, coverage-marker checks, and %s preservation: PASS\n' "$DATA_JSON"
printf '✅ S04 tests and failure states verifier: PASS\n'
