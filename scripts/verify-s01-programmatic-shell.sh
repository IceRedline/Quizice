#!/usr/bin/env bash
set -euo pipefail

# S01 storyboard-free shell verifier.
# Verifies the app has no runtime dependency on Main.storyboard, that the
# legacy Main.storyboard resource has been removed from the project, and that
# LaunchScreen.storyboard remains available as the system launch screen.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly INFO_PLIST="Quizice/Info.plist"
readonly PROJECT_FILE="Quizice.xcodeproj/project.pbxproj"
readonly MAIN_STORYBOARD="Quizice/Base.lproj/Main.storyboard"
readonly LAUNCH_SCREEN_STORYBOARD="Quizice/Base.lproj/LaunchScreen.storyboard"
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
require_file "$PROJECT_FILE"
require_file "$LAUNCH_SCREEN_STORYBOARD"
if [[ -e "$MAIN_STORYBOARD" ]]; then
  fail "$MAIN_STORYBOARD still exists; remove the unused runtime legacy storyboard resource."
fi
if grep -Fq 'UISceneStoryboardFile' "$INFO_PLIST"; then
  fail "$INFO_PLIST still declares UISceneStoryboardFile; remove storyboard scene launch before closing S01."
fi
if grep -Fq 'UIMainStoryboardFile' "$INFO_PLIST"; then
  fail "$INFO_PLIST still declares UIMainStoryboardFile; remove storyboard app launch before closing S01."
fi
if grep -Fq 'Main.storyboard' "$PROJECT_FILE"; then
  fail "$PROJECT_FILE still references Main.storyboard; remove the legacy project resource membership."
fi
if grep -Fq 'INFOPLIST_KEY_UIMainStoryboardFile' "$PROJECT_FILE"; then
  fail "$PROJECT_FILE still generates UIMainStoryboardFile; remove the Main storyboard build setting."
fi
if ! grep -Fq 'LaunchScreen.storyboard' "$PROJECT_FILE"; then
  fail "$PROJECT_FILE no longer references LaunchScreen.storyboard; preserve the system launch screen resource."
fi
if ! grep -Fq 'INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;' "$PROJECT_FILE"; then
  fail "$PROJECT_FILE no longer configures LaunchScreen as the launch storyboard."
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
