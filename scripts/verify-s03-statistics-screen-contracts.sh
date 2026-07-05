#!/usr/bin/env bash
set -euo pipefail

# S03 statistics screen contract verifier.
#
# Scope rules:
# - delegates upstream S02 contract verification first;
# - runs the repository-local iOS build used by the slice closeout;
# - reads only repository source/project files needed for the S03 contract;
# - does not inspect .gsd/, .planning/, .audits/, ignored paths, secrets, or local statistics data;
# - keeps checks deterministic and explicit so failures point to the missing contract.

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

readonly S02_VERIFIER="./scripts/verify-s02-quiz-flow-contracts.sh"
readonly PROJECT_FILE="Quizice.xcodeproj/project.pbxproj"
readonly STATISTICS_VIEW_CONTROLLER="Quizice/StatisticsViewController.swift"
readonly STATISTICS_STORE="Quizice/Services/StatisticsStore.swift"
readonly STATISTICS_SUMMARY="Quizice/Models/StatisticsSummary.swift"
readonly THEMES_SERVICE="Quizice/Services/ThemesCollectionService.swift"
readonly THEME_DELEGATE="Quizice/Services/ThemeCollectionDelegate.swift"
readonly QUIZ_VIEW_CONTROLLER="Quizice/QuizViewController.swift"
readonly RESULT_VIEW_CONTROLLER="Quizice/QuizResultViewController.swift"
readonly SCENE_DELEGATE="Quizice/SceneDelegate.swift"

fail() {
  printf '❌ S03 statistics screen contract failed: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Required source file is missing: $path"
}

require_executable() {
  local path="$1"
  [[ -x "$path" ]] || fail "Required verifier is missing or not executable: $path"
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

printf 'Verifying S03 statistics screen contracts...\n'
printf 'Checking upstream S02 quiz flow contracts first...\n'
require_executable "$S02_VERIFIER"
"$S02_VERIFIER"

printf 'Checking S03 iOS build contract...\n'
xcodebuild -project Quizice.xcodeproj -scheme Quizice -destination 'generic/platform=iOS Simulator' build

printf 'Checking statistics source files and project membership...\n'
require_file "$STATISTICS_VIEW_CONTROLLER"
require_file "$STATISTICS_STORE"
require_file "$STATISTICS_SUMMARY"
require_file "$PROJECT_FILE"
require_fixed_string "$PROJECT_FILE" 'StatisticsViewController.swift' 'Statistics screen must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'StatisticsStore.swift' 'Statistics store must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'StatisticsSummary.swift' 'Statistics summary model must be referenced by the Xcode project'
require_extended_regex "$PROJECT_FILE" 'StatisticsViewController\.swift in Sources' 'Statistics screen must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'StatisticsStore\.swift in Sources' 'Statistics store must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'StatisticsSummary\.swift in Sources' 'Statistics summary model must be in the app Sources build phase'

printf 'Checking statistics store safety markers...\n'
require_fixed_string "$STATISTICS_STORE" 'guard totalQuestions > 0 else { return nil }' 'Statistics store must reject zero-question attempts before persistence'
require_fixed_string "$STATISTICS_STORE" 'min(max(correctAnswers, 0), sanitizedTotal)' 'Statistics store must clamp malformed correct-answer counts'
require_fixed_string "$STATISTICS_STORE" 'userDefaults.removeObject(forKey: key)' 'Statistics store must recover from malformed stored attempt data'
require_fixed_string "$STATISTICS_SUMMARY" 'guard totalQuestions > 0 else { return 0 }' 'Statistics summary percentage must guard empty totals'
require_fixed_string "$STATISTICS_SUMMARY" 'static let empty' 'Statistics summary must expose an empty-state value'

printf 'Checking home statistics card and navigation contract...\n'
require_fixed_string "$THEMES_SERVICE" 'private var statisticsIndex: Int' 'Home collection must derive the final statistics card index from theme count'
require_fixed_string "$THEMES_SERVICE" 'if indexPath.item == statisticsIndex' 'Statistics card must be the final home collection item'
require_fixed_string "$THEMES_SERVICE" 'static let statisticsCardHeight: CGFloat = 112' 'Statistics card height must remain fixed at the polished rectangular-card height'
require_fixed_string "$THEMES_SERVICE" 'return CGSize(width: availableWidth, height: Layout.statisticsCardHeight)' 'Statistics card must span the full collection row as a rectangular card'
require_fixed_string "$THEMES_SERVICE" 'let twoColumnWidth = floor((availableWidth - Layout.itemSpacing) / 2)' 'Theme cards must use a two-column vertical grid width calculation'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'layout.scrollDirection = .vertical' 'Home collection must scroll vertically'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'private func updateCollectionScrollAvailability()' 'Home collection must update scroll behavior from rendered content size'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'themesCollectionView.alwaysBounceVertical = shouldScroll' 'Home collection must bounce vertically only when content does not fit'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'screenStackView = UIStackView(arrangedSubviews: [headerStackView, themesCollectionView])' 'Home collection must remain in the main vertical screen stack below the title'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'screenStackView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor)' 'Home collection stack must have a non-collapsing vertical height below the title'
require_fixed_string "$THEMES_SERVICE" 'configureStatisticsCard(in: cell, appearance: appearance)' 'Home collection must configure a dedicated statistics card'
require_fixed_string "$THEMES_SERVICE" 'button.accessibilityIdentifier = Content.statisticsAccessibilityID' 'Statistics card must expose a stable accessibility identifier'
require_fixed_string "$THEMES_SERVICE" 'button.accessibilityLabel = L10n.Home.statisticsAccessibilityLabel' 'Statistics card must expose a localized accessibility label'
require_fixed_string "$THEMES_SERVICE" 'button.accessibilityHint = L10n.Home.statisticsAccessibilityHint' 'Statistics card must explain its navigation action'
require_fixed_string "$THEMES_SERVICE" 'delegate?.statisticsButtonTouchedUpInside(sender)' 'Statistics card tap must call the delegate callback'
require_fixed_string "$THEME_DELEGATE" 'func statisticsButtonTouchedUpInside(_ sender: UIButton)' 'Theme collection delegate must expose the statistics callback'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'func statisticsButtonTouchedUpInside(_ sender: UIButton)' 'Home view controller must implement the statistics callback'
require_fixed_string "$QUIZ_VIEW_CONTROLLER" 'router?.showStatistics()' 'Home statistics callback must route statistics navigation through the coordinator'
require_fixed_string "$SCENE_DELEGATE" 'func showStatistics()' 'Coordinator routing protocol must expose statistics navigation'
require_fixed_string "$SCENE_DELEGATE" 'let viewController = StatisticsViewController()' 'Coordinator must instantiate the statistics screen'
require_fixed_string "$SCENE_DELEGATE" 'viewController.router = self' 'Coordinator must inject routing into the statistics screen'
require_fixed_string "$SCENE_DELEGATE" 'navigationController.pushViewController(viewController, animated: true)' 'Coordinator must push the statistics screen'

printf 'Checking statistics screen rendering and accessibility contract...\n'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'static let rootView = "statisticsScreen"' 'Statistics screen root view must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rootView.accessibilityIdentifier = AccessibilityID.rootView' 'Statistics screen root view must apply its stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rootView.accessibilityLabel = L10n.Statistics.accessibilityLabel' 'Statistics screen root view must expose an accessibility label'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'static let backButton = "statisticsBackButton"' 'Statistics screen must define a stable back-button accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'backButton.accessibilityIdentifier = AccessibilityID.backButton' 'Statistics screen must expose an explicit back button when the navigation bar is hidden'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'router?.closeStatistics()' 'Statistics back button must return through coordinator routing'
require_fixed_string "$SCENE_DELEGATE" 'func closeStatistics()' 'Coordinator routing protocol must expose statistics close navigation'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'titleLabel.accessibilityIdentifier = AccessibilityID.titleLabel' 'Statistics screen title must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'emptyStateLabel.accessibilityIdentifier = AccessibilityID.emptyStateLabel' 'Statistics empty state must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rowAccessibilityIdentifier: AccessibilityID.playedQuizzesRow' 'Played-quizzes statistic row must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rowAccessibilityIdentifier: AccessibilityID.correctAnswersRow' 'Correct-answers statistic row must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rowAccessibilityIdentifier: AccessibilityID.percentageRow' 'Percentage statistic row must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'rowAccessibilityIdentifier: AccessibilityID.bestResultRow' 'Best-result statistic row must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'render(summary: statisticsStore.loadSummary())' 'Statistics screen must refresh local aggregate data when shown'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'emptyStateLabel.isHidden = summary.playedQuizzes > .zero' 'Statistics screen must render an empty state for no attempts'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'accessibilityValue = "\(playedQuizzes)"' 'Played-quizzes row must expose its value to accessibility'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'accessibilityValue = correctAnswersDisplay' 'Correct-answers row must expose its value to accessibility'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'accessibilityValue = percentageDisplay' 'Percentage row must expose its value to accessibility'
require_fixed_string "$STATISTICS_VIEW_CONTROLLER" 'accessibilityValue = bestResultDisplay' 'Best-result row must expose its value to accessibility'

printf 'Checking result screen remains current-attempt only...\n'
readonly RESULT_GLOBAL_STATS_PATTERN='StatisticsViewController|StatisticsStore|StatisticsSummary|UserDefaults|statistics|globalStats|playedQuizzes|totalQuestions|bestResult|bestScore|averageScore|highScore|Процент правильных|Лучший результат|Пройдено викторин|Правильных ответов'
reject_extended_regex \
  "$RESULT_VIEW_CONTROLLER" \
  "$RESULT_GLOBAL_STATS_PATTERN" \
  'Result view must not render or depend on global statistics fields'

printf '✅ S03 statistics screen contracts verification passed.\n'
