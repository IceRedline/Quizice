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
readonly RETIRED_STATISTICS_VIEW_CONTROLLER="Quizice/Features/Statistics/UI/StatisticsViewController.swift"
readonly STATISTICS_STORE="Quizice/Core/Persistence/StatisticsStore.swift"
readonly STATISTICS_SUMMARY="Quizice/Domain/Statistics/StatisticsSummary.swift"
readonly THEMES_SERVICE="Quizice/Features/Home/Collection/ThemesCollectionService.swift"
readonly STATISTICS_CARD_CELL="Quizice/Features/Home/Cards/StatisticsCardCollectionViewCell.swift"
readonly EXPANDED_STATISTICS_CARD="Quizice/Features/Home/Cards/ExpandedStatisticsCardView.swift"
readonly STATISTICS_PRESENTATION="Quizice/Features/Home/Cards/StatisticsPresentation.swift"
readonly THEME_DELEGATE="Quizice/Features/Home/Contracts/ThemeCollectionDelegate.swift"
readonly QUIZ_VIEW_LAYOUT="Quizice/Features/Home/Presentation/QuizViewController+Layout.swift"
readonly QUIZ_VIEW_ACTIONS="Quizice/Features/Home/Presentation/QuizViewController+Actions.swift"
readonly QUIZ_VIEW_CARD_PRESENTATION="Quizice/Features/Home/Presentation/QuizViewController+CardPresentation.swift"
readonly QUIZ_VIEW_PRESENTATION_ROOT="Quizice/Features/Home/Presentation"
readonly RESULT_VIEW_CONTROLLER="Quizice/Features/QuizResult/UI/QuizResultViewController.swift"
readonly QUIZ_FLOW_COORDINATOR="Quizice/App/Navigation/QuizFlowCoordinator.swift"

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

reject_fixed_string_in_directory() {
  local directory="$1"
  local pattern="$2"
  local message="$3"

  [[ -d "$directory" ]] || fail "Required source directory is missing: $directory"
  if grep -RFq --include='*.swift' "$pattern" "$directory"; then
    fail "$message ($directory contains: $pattern)"
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

reject_path() {
  local path="$1"
  local message="$2"

  if [[ -e "$path" ]]; then
    fail "$message ($path must not exist)"
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
xcodebuild \
  -quiet \
  -project Quizice.xcodeproj \
  -scheme Quizice \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

printf 'Checking inline statistics source files and project membership...\n'
require_file "$STATISTICS_STORE"
require_file "$STATISTICS_SUMMARY"
require_file "$STATISTICS_CARD_CELL"
require_file "$EXPANDED_STATISTICS_CARD"
require_file "$STATISTICS_PRESENTATION"
require_file "$PROJECT_FILE"
require_fixed_string "$PROJECT_FILE" 'StatisticsStore.swift' 'Statistics store must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'StatisticsSummary.swift' 'Statistics summary model must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'StatisticsCardCollectionViewCell.swift' 'Reusable statistics card must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'ExpandedStatisticsCardView.swift' 'Expanded statistics card must be referenced by the Xcode project'
require_fixed_string "$PROJECT_FILE" 'StatisticsPresentation.swift' 'Inline statistics presentation model must be referenced by the Xcode project'
require_extended_regex "$PROJECT_FILE" 'StatisticsStore\.swift in Sources' 'Statistics store must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'StatisticsSummary\.swift in Sources' 'Statistics summary model must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'StatisticsCardCollectionViewCell\.swift in Sources' 'Reusable statistics card must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'ExpandedStatisticsCardView\.swift in Sources' 'Expanded statistics card must be in the app Sources build phase'
require_extended_regex "$PROJECT_FILE" 'StatisticsPresentation\.swift in Sources' 'Inline statistics presentation model must be in the app Sources build phase'
reject_path "$RETIRED_STATISTICS_VIEW_CONTROLLER" 'Standalone statistics controller must remain removed'
reject_fixed_string "$PROJECT_FILE" 'StatisticsViewController.swift' 'Xcode project must not reference the retired standalone statistics controller'

printf 'Checking statistics store safety markers...\n'
require_fixed_string "$STATISTICS_STORE" 'guard totalQuestions > 0 else { return nil }' 'Statistics store must reject zero-question attempts before persistence'
require_fixed_string "$STATISTICS_STORE" 'min(max(correctAnswers, 0), sanitizedTotal)' 'Statistics store must clamp malformed correct-answer counts'
require_fixed_string "$STATISTICS_STORE" 'userDefaults.removeObject(forKey: storageKey)' 'Statistics store must recover from malformed stored attempt data'
require_fixed_string "$STATISTICS_SUMMARY" 'guard totalQuestions > 0 else { return 0 }' 'Statistics summary percentage must guard empty totals'
require_fixed_string "$STATISTICS_SUMMARY" 'static let empty' 'Statistics summary must expose an empty-state value'

printf 'Checking home statistics card and inline presentation contract...\n'
require_fixed_string "$THEMES_SERVICE" 'private var statisticsIndex: Int' 'Home collection must derive the final statistics card index from theme count'
require_fixed_string "$THEMES_SERVICE" 'if indexPath.item == statisticsIndex' 'Statistics card must be the final home collection item'
require_fixed_string "$THEMES_SERVICE" 'static let statisticsCardHeight: CGFloat = 112' 'Statistics card height must remain fixed at the polished rectangular-card height'
require_fixed_string "$THEMES_SERVICE" 'static let lastItemBottomInset: CGFloat = 24' 'Final statistics item must own the release-safe bottom spacing'
require_fixed_string "$THEMES_SERVICE" 'height: Layout.statisticsCardHeight + Layout.lastItemBottomInset' 'Final collection item must include its own bottom spacing in its height'
require_fixed_string "$STATISTICS_CARD_CELL" 'actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.bottomInset)' 'Statistics card must leave bottom spacing inside the final item'
require_fixed_string "$THEMES_SERVICE" 'let twoColumnWidth = floor((availableWidth - Layout.itemSpacing) / 2)' 'Theme cards must use a two-column vertical grid width calculation'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'layout.scrollDirection = .vertical' 'Home collection must scroll vertically'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'func updateCollectionScrollAvailability()' 'Home collection must update scroll behavior from rendered content size'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'themesCollectionView.alwaysBounceVertical = shouldScroll' 'Home collection must bounce vertically only when content does not fit'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'screenStackView = UIStackView(arrangedSubviews: [themesCollectionView])' 'Home collection must own the main vertical screen stack'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'rootView.addSubview(headerStackView)' 'Home motivation header must be present as an overlay above the root background'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'rootView.addSubview(screenStackView)' 'Home collection stack must be installed as a root-level scroll surface'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'screenStackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)' 'Home collection stack must extend to the screen edge below the overlay header'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'screenStackView.layer.zPosition = Appearance.collectionLayerZPosition' 'Home collection must render above the motivation header while scrolling'
require_fixed_string "$QUIZ_VIEW_LAYOUT" 'headerStackView.layer.zPosition = Appearance.headerLayerZPosition' 'Home motivation header must keep an explicit lower layer order'
require_fixed_string "$THEMES_SERVICE" 'StatisticsCardCollectionViewCell.reuseIdentifier' 'Home collection must dequeue a dedicated reusable statistics card'
require_fixed_string "$THEMES_SERVICE" 'isSourceHidden: isStatisticsPresented' 'Home collection must hide only the source statistics card while expanded'
require_fixed_string "$STATISTICS_CARD_CELL" 'actionButton.accessibilityIdentifier = ThemesCollectionService.Content.statisticsAccessibilityID' 'Statistics card must expose a stable accessibility identifier'
require_fixed_string "$STATISTICS_CARD_CELL" 'actionButton.accessibilityLabel = L10n.Home.statisticsAccessibilityLabel' 'Statistics card must expose a localized accessibility label'
require_fixed_string "$STATISTICS_CARD_CELL" 'actionButton.accessibilityHint = L10n.Home.statisticsAccessibilityHint' 'Statistics card must explain its inline expansion action'
require_fixed_string "$THEMES_SERVICE" 'delegate?.statisticsButtonTouchedUpInside(sender)' 'Statistics card tap must call the delegate callback'
require_fixed_string "$THEME_DELEGATE" 'func statisticsButtonTouchedUpInside(_ sender: UIButton)' 'Theme collection delegate must expose the statistics callback'
require_fixed_string "$QUIZ_VIEW_ACTIONS" 'func statisticsButtonTouchedUpInside(_ sender: UIButton)' 'Home view controller must implement the statistics callback'
require_fixed_string "$QUIZ_VIEW_ACTIONS" 'homeStore.send(.presentStatistics)' 'Home statistics callback must present the statistics card inline'
require_fixed_string "$QUIZ_VIEW_ACTIONS" 'summary: statisticsStore.loadSummary()' 'Home must load the current aggregate summary for inline statistics'
require_fixed_string "$QUIZ_VIEW_CARD_PRESENTATION" 'func expandStatisticsCard(' 'Home must own the inline statistics expansion entry point'
require_fixed_string "$QUIZ_VIEW_CARD_PRESENTATION" 'let cardView = ExpandedStatisticsCardView(frame: targetFrame)' 'Home must render the expanded inline statistics surface'
require_fixed_string "$QUIZ_VIEW_CARD_PRESENTATION" 'cardView.configure(summary: summary, appearance: appearance)' 'Inline statistics must render the supplied aggregate summary'
require_fixed_string "$QUIZ_VIEW_CARD_PRESENTATION" 'func wireExpandedStatisticsCardActions(_ cardView: ExpandedStatisticsCardView)' 'Home must wire inline statistics dismissal actions'
require_fixed_string "$QUIZ_VIEW_CARD_PRESENTATION" 'self?.sendHomeCardAction(.closeRequested)' 'Inline statistics close must return through the Home state machine'
reject_fixed_string_in_directory "$QUIZ_VIEW_PRESENTATION_ROOT" 'router?.showStatistics()' 'Home statistics callback must not push the standalone statistics screen'
reject_fixed_string "$QUIZ_FLOW_COORDINATOR" 'func showStatistics()' 'Coordinator must not expose the retired statistics route'
reject_fixed_string "$QUIZ_FLOW_COORDINATOR" 'func closeStatistics()' 'Coordinator must not expose the retired statistics close route'
reject_fixed_string "$QUIZ_FLOW_COORDINATOR" 'StatisticsRouting' 'Coordinator must not retain the retired statistics routing protocol'
reject_fixed_string "$QUIZ_FLOW_COORDINATOR" 'StatisticsViewController' 'Coordinator must not instantiate the retired statistics controller'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'accessibilityViewIsModal = true' 'Expanded statistics card must be accessibility-modal'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'StatisticsPresentation.MetricID.playedQuizzes' 'Expanded statistics card must render all shared aggregate metrics'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'override func accessibilityPerformEscape() -> Bool' 'Expanded statistics card must support accessibility escape'

printf 'Checking inline statistics rendering and accessibility contract...\n'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'static let root = "expandedStatisticsCardView"' 'Inline statistics root must expose a stable accessibility identifier'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'static let closeButton = "expandedStatisticsCardCloseButton"' 'Inline statistics must expose an explicit close control'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'static let emptyState = "expandedStatisticsCardEmptyState"' 'Inline statistics empty state must expose a stable accessibility identifier'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'static let closeButtonSize: CGFloat = 44' 'Inline statistics close control must keep a 44-point hit target'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'let presentation = StatisticsPresentation(summary: summary)' 'Inline statistics must derive presentation values from the shared summary model'
require_fixed_string "$STATISTICS_PRESENTATION" 'init(summary: StatisticsSummary)' 'Inline statistics presentation model must derive from the shared aggregate summary'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'emptyStateLabel.isHidden = presentation.emptyStateText == nil' 'Inline statistics must render the empty state only when needed'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'accessibilityIdentifier = "expandedStatisticsMetric-\(metric.id.rawValue)"' 'Inline statistic rows must expose stable metric identifiers'
require_fixed_string "$EXPANDED_STATISTICS_CARD" 'accessibilityValue = metric.value' 'Inline statistic rows must expose their values to accessibility'

printf 'Checking result screen remains current-attempt only...\n'
readonly RESULT_GLOBAL_STATS_PATTERN='StatisticsViewController|StatisticsStore|StatisticsSummary|UserDefaults|statistics|globalStats|playedQuizzes|totalQuestions|bestResult|bestScore|averageScore|highScore|Процент правильных|Лучший результат|Пройдено викторин|Правильных ответов'
reject_extended_regex \
  "$RESULT_VIEW_CONTROLLER" \
  "$RESULT_GLOBAL_STATS_PATTERN" \
  'Result view must not render or depend on global statistics fields'

printf '✅ S03 statistics screen contracts verification passed.\n'
