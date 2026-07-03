#!/usr/bin/env bash
set -euo pipefail

# S01 storyboard-free shell verifier.
# This verifier is expected to fail until T02 and T03 remove the remaining
# Storyboard launch and runtime navigation dependencies from the four-screen
# UIKit shell. LaunchScreen.storyboard and non-runtime Main.storyboard project
# resource references are intentionally out of scope for this check.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly INFO_PLIST="Quizice/Info.plist"
readonly RUNTIME_SWIFT_FILES=(
  "Quizice/SceneDelegate.swift"
  "Quizice/QuizViewController.swift"
  "Quizice/QuizDescriptionViewController.swift"
  "Quizice/QuizQuestionViewController.swift"
  "Quizice/QuizResultViewController.swift"
)
readonly STORYBOARD_PATTERNS=(
  'UIStoryboard('
  'instantiateViewController'
  'performSegue'
)

fail() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Required source file is missing: $path"
}

printf 'Verifying S01 programmatic UIKit shell...\n'

require_file "$INFO_PLIST"
if grep -Fq 'UISceneStoryboardFile' "$INFO_PLIST"; then
  fail "$INFO_PLIST still declares UISceneStoryboardFile; remove storyboard scene launch before closing S01."
fi

for source_file in "${RUNTIME_SWIFT_FILES[@]}"; do
  require_file "$source_file"
  for pattern in "${STORYBOARD_PATTERNS[@]}"; do
    if grep -Fq "$pattern" "$source_file"; then
      fail "$source_file still contains storyboard runtime dependency: $pattern"
    fi
  done
done

printf 'Static storyboard dependency checks passed. Running integration build...\n'
xcodebuild \
  -project Quizice.xcodeproj \
  -scheme Quizice \
  -destination 'generic/platform=iOS Simulator' \
  build

printf '✅ S01 programmatic UIKit shell verification passed.\n'
