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
# with QUIZICE_RECORD_SNAPSHOTS=1, inspect the changed PNGs, then rerun this
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
readonly HOME_VISUAL_TESTS="QuiziceTests/UI/HomeScreenVisualStateTests.swift"
readonly CROSS_SCREEN_VISUAL_TESTS="QuiziceTests/UI/CrossScreenVisualStateTests.swift"
readonly APP_APPEARANCE_TESTS="QuiziceTests/Unit/AppAppearanceTests.swift"
readonly QUIZ_PRESENTER_TESTS="QuiziceTests/Unit/QuizPresenterTests.swift"
readonly QUESTION_PRESENTER_TESTS="QuiziceTests/Unit/QuizQuestionPresenterTests.swift"
readonly QUIZ_FACTORY_TESTS="QuiziceTests/Unit/QuizFactoryTests.swift"
readonly QUIZ_COORDINATOR_TESTS="QuiziceTests/Unit/QuizFlowCoordinatorAdditionalTests.swift"
readonly SNAPSHOT_RUNTIME_IDENTIFIER="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
readonly SNAPSHOT_HOST_DEVICE_TYPE_SUFFIX=".iPhone-16e"
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

print_xctest_failure_summary() {
  local result_bundle="$1"
  local test_log="$2"
  local summary_json
  summary_json="$(mktemp -t quizice-s04-xcresult-summary.XXXXXX.json)"
  remember_temp_file "$summary_json"

  log_section "XCTest failure summary" >&2

  if xcrun xcresulttool get test-results summary --path "$result_bundle" --compact > "$summary_json" 2>/dev/null; then
    if python3 - "$summary_json" "${GITHUB_ACTIONS:-}" "${GITHUB_STEP_SUMMARY:-}" "$PROJECT_ROOT" <<'PY'
import json
import re
import sys

summary_path, github_actions, step_summary_path, project_root = sys.argv[1:5]

with open(summary_path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

failures = []

def walk(value):
    if isinstance(value, dict):
        if value.get("testName") or value.get("failureText"):
            failures.append(value)
        for child in value.values():
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)

walk(payload.get("testFailures", payload))

deduplicated = []
seen = set()
for failure in failures:
    key = (
        failure.get("targetName", ""),
        failure.get("testName", ""),
        failure.get("failureText", ""),
    )
    if key not in seen:
        seen.add(key)
        deduplicated.append(failure)

def escape_github(value):
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")

def swift_location(text):
    match = re.search(r"((?:/[^:\n]+)?[^:\n]+\.swift):(\d+)", text)
    if match:
        return match.group(1), match.group(2)
    return "", ""

if not deduplicated:
    print("No structured XCTest failures were found in the xcresult summary.", file=sys.stderr)
    raise SystemExit(2)

summary_lines = [
    "### XCTest failure summary",
    "",
    "| Target | Test | Message |",
    "| --- | --- | --- |",
]

for index, failure in enumerate(deduplicated, start=1):
    target = failure.get("targetName") or "unknown target"
    test_name = failure.get("testName") or failure.get("testIdentifierString") or "unknown test"
    message = (failure.get("failureText") or "").strip() or "No failure message in xcresult."
    one_line_message = " ".join(message.split())
    print(f"{index}. {target} / {test_name}", file=sys.stderr)
    print(f"   {one_line_message}", file=sys.stderr)

    file_path, line = swift_location(message)
    if file_path.startswith(project_root + "/"):
        file_path = file_path[len(project_root) + 1:]
    if github_actions.lower() == "true":
        annotation = f"::error title={escape_github(test_name)}"
        if file_path:
            annotation += f",file={escape_github(file_path)}"
        if line:
            annotation += f",line={line}"
        annotation += f"::{escape_github(one_line_message)}"
        print(annotation)

    markdown_message = one_line_message.replace("|", "\\|")
    summary_lines.append(f"| `{target}` | `{test_name}` | {markdown_message} |")

if step_summary_path:
    with open(step_summary_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(summary_lines))
        handle.write("\n")
PY
    then
      return
    fi
  fi

  printf 'Could not read structured failures from xcresult; showing likely failure lines from xcodebuild log.\n' >&2
  grep -E "Test case '.*' failed|/[^:]+\.swift:[0-9]+: error:|XCTAssert|failed:" "$test_log" >&2 || true
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
  if [[ -n "${QUIZICE_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "$QUIZICE_SIMULATOR_UDID"
    return
  fi

  xcrun simctl list devices available -j | python3 -c '
import json
import sys

preferred_runtime = sys.argv[1]
preferred_device_type_suffix = sys.argv[2]
try:
    payload = json.load(sys.stdin)
except Exception as exc:
    raise SystemExit(f"could not parse simctl JSON: {exc}")

devices_by_runtime = payload.get("devices", {})
candidates = []
for runtime, devices in devices_by_runtime.items():
    if runtime != preferred_runtime:
        continue
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name", "")
        device_type = device.get("deviceTypeIdentifier", "")
        if not device_type.endswith(preferred_device_type_suffix):
            continue
        state = device.get("state", "")
        udid = device.get("udid", "")
        if udid:
            boot_rank = 0 if state == "Booted" else 1
            candidates.append((boot_rank, name, udid))

if not candidates:
    raise SystemExit(
        "snapshot host unavailable: create an iPhone 16e on iOS 26.2 "
        "or set QUIZICE_SIMULATOR_UDID to an explicitly compatible simulator"
    )

for _, _, udid in sorted(candidates):
    print(udid)
    break
' "$SNAPSHOT_RUNTIME_IDENTIFIER" "$SNAPSHOT_HOST_DEVICE_TYPE_SUFFIX"
}

assert_snapshot_recording_disabled() {
  local simulator_udid="$1"
  local key
  local value

  for key in QUIZICE_RECORD_SNAPSHOTS SNAPSHOT_TESTING_RECORD; do
    value="${!key:-}"
    [[ -z "$value" ]] || fail "$key must be unset while running the verifier"

    value="$(xcrun simctl spawn "$simulator_udid" launchctl getenv "$key" 2>/dev/null || true)"
    [[ -z "$value" ]] || fail "$key is set in the selected simulator; unset it before verification"
  done
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
  require_file "$HOME_VISUAL_TESTS"
  require_file "$CROSS_SCREEN_VISUAL_TESTS"
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
  require_fixed_string "$HOME_CARD_SNAPSHOT_TESTS" 'testRadarLongThemeCompactCardSnapshot' 'Home card snapshots must cover long Radar titles on compact phones'
  require_fixed_string "$HOME_CARD_SNAPSHOT_TESTS" 'testCompactStatisticsCardSnapshot' 'Home card snapshots must cover compact statistics layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testHomeScreenSnapshot' 'Screen snapshots must cover home'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testHomeCompactPortraitSnapshot' 'Screen snapshots must cover the home screen on iPhone SE geometry'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testHomeCompactPortraitBottomSnapshot' 'Screen snapshots must cover the final home item and its internal bottom spacing'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testClassicLongAnswerModernPortraitSnapshot' 'Screen snapshots must reproduce long answers on iPhone 17 Pro Classic layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testClassicLongAnswerCompactPortraitSnapshot' 'Screen snapshots must reproduce long answers on compact Classic layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testRadarLongAnswerModernPortraitSnapshot' 'Screen snapshots must cover long answers on iPhone 17 Pro Radar layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testRadarLongAnswerCompactPortraitSnapshot' 'Screen snapshots must cover long answers on compact Radar layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" 'testCleanLongAnswerCompactPortraitSnapshot' 'Screen snapshots must cover long answers on compact Clean layout'
  require_fixed_string "$SCREEN_SNAPSHOT_TESTS" '«Поступай так, чтобы максима твоей воли могла бы быть всеобщим законом»' 'Screen snapshots must reproduce the reported long-answer fixture'
  require_fixed_string "$SWIFTUI_SNAPSHOT_TESTS" 'testSettingsViewSnapshot' 'SwiftUI snapshots must cover settings'
  require_fixed_string "$SWIFTUI_SNAPSHOT_TESTS" 'testClassicSettingsCompactPortraitSnapshot' 'SwiftUI snapshots must cover Classic settings on iPhone SE geometry'
  require_fixed_string "$HOME_VISUAL_TESTS" 'testCleanSettingsSurfaceIsCircular' 'Home visual tests must keep the Clean settings surface circular'
  require_fixed_string "$HOME_VISUAL_TESTS" 'XCTAssertEqual(themeCell.layer.shadowOpacity, 0)' 'Home visual tests must keep Clean light theme cards shadowless'
  require_fixed_string "$HOME_VISUAL_TESTS" 'testCompactStatisticsTitleShrinksAndLastItemOwnsBottomSpacing' 'Home visual tests must cover compact statistics text and last-item-owned spacing'
  require_fixed_string "$CROSS_SCREEN_VISUAL_TESTS" 'testLongAnswersShrinkWithoutClippingAcrossSelectableStylesAndPhoneSizes' 'Cross-screen visual tests must cover long-answer fitting across selectable styles and phone sizes'
  require_fixed_string "$CROSS_SCREEN_VISUAL_TESTS" 'testLongAnswersRespectAccessibilityContentSizeWhileFitting' 'Cross-screen visual tests must preserve Dynamic Type while fitting long answers'
  require_fixed_string "$CROSS_SCREEN_VISUAL_TESTS" 'testQuestionNextButtonStaysPinnedWhenExtremeAnswerGrowsCard' 'Cross-screen visual tests must cover the readable-font fallback for extreme answers'
  require_fixed_string "$CROSS_SCREEN_VISUAL_TESTS" 'testQuestionAdvanceResetsScrolledLongAnswerCardToTop' 'Cross-screen visual tests must reset long-answer scroll position when advancing'
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
  assert_snapshot_recording_disabled "$simulator_udid"

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
    -parallel-testing-enabled NO \
    -enableCodeCoverage YES \
    -resultBundlePath "$result_bundle" \
    test | tee "$test_log"; then
    print_xctest_failure_summary "$result_bundle" "$test_log"
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
  require_extended_regex "$test_log" "Test Suite 'HomeCardSnapshotTests' passed|Test case 'HomeCardSnapshotTests\\." \
    'HomeCardSnapshotTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'SwiftUISnapshotTests' passed|Test case 'SwiftUISnapshotTests\\." \
    'SwiftUISnapshotTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'HomeScreenVisualStateTests' passed|Test case 'HomeScreenVisualStateTests\\." \
    'HomeScreenVisualStateTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'CrossScreenVisualStateTests' passed|Test case 'CrossScreenVisualStateTests\\." \
    'CrossScreenVisualStateTests did not appear to execute'
  require_extended_regex "$test_log" "Test Suite 'AppAppearanceTests' passed|Test case 'AppAppearanceTests\\." \
    'AppAppearanceTests did not appear to execute'

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
