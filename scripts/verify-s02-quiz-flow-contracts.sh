#!/usr/bin/env bash
set -euo pipefail

# S02 quiz-flow contract verifier.
#
# This verifier intentionally combines the S01 storyboard-free runtime/build
# contract with S02 static guards for the local quiz flow. It may fail before
# later S02 implementation tasks land; those failures are the closeout target.
#
# Scope rules:
# - read only repository source files needed for the quiz-flow contract;
# - do not inspect .gsd/, .planning/, .audits/, or other planning artifacts;
# - keep checks deterministic and explicit so failures point to the contract.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly THEMES_SERVICE="Quizice/Features/Home/Collection/ThemesCollectionService.swift"
readonly QUESTION_PRESENTER="Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift"
readonly RESULT_VIEW_CONTROLLER="Quizice/Features/QuizResult/UI/QuizResultViewController.swift"
readonly RESULT_PRESENTER="Quizice/Features/QuizResult/Presentation/QuizResultPresenter.swift"
readonly DATA_JSON="Quizice/data.json"
readonly S01_VERIFIER="./scripts/verify-s01-programmatic-shell.sh"

fail() {
  printf '❌ S02 quiz flow contract failed: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Required source file is missing: $path"
}

reject_fixed_string() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  require_file "$path"
  if grep -Fq "$pattern" "$path"; then
    fail "$message ($path contains: $pattern)"
  fi
}

reject_extended_regex() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  require_file "$path"
  if grep -Eq "$pattern" "$path"; then
    fail "$message ($path matches: $pattern)"
  fi
}

printf 'Verifying S02 quiz flow contracts...\n'
printf 'Checking S01 storyboard-free runtime/build contract first...\n'
require_file "$S01_VERIFIER"
"$S01_VERIFIER"

printf 'Checking S02 source safety contracts...\n'
reject_fixed_string \
  "$THEMES_SERVICE" \
  'fatalError' \
  'Themes collection must not crash when local themes are unavailable'

reject_fixed_string \
  "$THEMES_SERVICE" \
  'accessibilityIdentifier!' \
  'Theme selection must not force-unwrap accessibilityIdentifier'

reject_fixed_string \
  "$QUESTION_PRESENTER" \
  'chosenTheme!' \
  'Question loading must not force-unwrap chosenTheme'

reject_fixed_string \
  "$QUESTION_PRESENTER" \
  'questionsTotalCount!' \
  'Question loading must not force-unwrap questionsTotalCount'

reject_extended_regex \
  "$RESULT_PRESENTER" \
  'Float\([^)]*correctAnswers[^)]*\)[[:space:]]*/[[:space:]]*Float\([^)]*totalQuestions[^)]*\)' \
  'Current-attempt result percentage must guard totalQuestions <= 0 before division'

printf 'Checking S02 absence of global statistics or persistence additions...\n'
readonly PERSISTENCE_OR_GLOBAL_STATS_PATTERN='UserDefaults|FileManager|JSONEncoder|JSONDecoder|PropertyListEncoder|PropertyListDecoder|NSUbiquitousKeyValueStore|CoreData|SQLite|Realm|statistics|globalStats|totalAttempts|bestScore|averageScore|highScore'
reject_extended_regex \
  "$RESULT_VIEW_CONTROLLER" \
  "$PERSISTENCE_OR_GLOBAL_STATS_PATTERN" \
  'Result view must stay current-attempt only and must not add global statistics or persistence'

reject_extended_regex \
  "$RESULT_PRESENTER" \
  "$PERSISTENCE_OR_GLOBAL_STATS_PATTERN" \
  'Result presenter must stay current-attempt only and must not add global statistics or persistence'

printf 'Checking Quizice/data.json has no working-tree edits...\n'
require_file "$DATA_JSON"
if git diff --quiet -- "$DATA_JSON"; then
  :
else
  fail "$DATA_JSON has working-tree changes; S02 must preserve quiz fixture data"
fi

printf '✅ S02 quiz flow contracts verification passed.\n'
