#!/bin/bash
# Runs every logic check against the REAL sources.
#
# main has no test target, so these stand in for one. Each check compiles the
# actual files the app ships — not a copy — and asserts behaviour that would
# otherwise only be caught by someone noticing the app was wrong.
#
#   ./tools/run-checks.sh            # all
#   ./tools/run-checks.sh Decay      # just the one whose name matches
#
# Swift only allows top-level statements in a file called `main.swift`, so each
# check is copied to that name before compiling. That is the only reason this
# script exists rather than a comment with a swiftc line in it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

MODELS="Eco-Habbit/Core/Models"
SERVICES="Eco-Habbit/Core/Services"
COMMON="$MODELS/Day.swift $MODELS/EarthStage.swift $MODELS/ActivityCategory.swift \
        $MODELS/FrictionLevel.swift $MODELS/EvidenceStrength.swift \
        $MODELS/Habit.swift $MODELS/Badge.swift $MODELS/EarnedBadge.swift \
        $MODELS/Fight.swift $MODELS/FightSeed.swift $MODELS/MockData.swift \
        Eco-Habbit/Core/Configuration/PointsConfiguration.swift \
        Eco-Habbit/Core/Persistence/PersistenceStore.swift \
        $SERVICES/PointsCalculationService.swift $SERVICES/StreakService.swift \
        $SERVICES/DecayService.swift $SERVICES/BadgeEvaluationService.swift \
        Eco-Habbit/Core/Engine/PointsEngine.swift \
        Eco-Habbit/Core/Engine/EvaluationLoop.swift \
        Eco-Habbit/Core/Repositories/HabitRepository.swift \
        Eco-Habbit/Core/Repositories/FightRepository.swift \
        Eco-Habbit/Core/Repositories/UserRepository.swift \
        Eco-Habbit/Core/Repositories/UserDocument.swift \
        Eco-Habbit/DesignSystem/Tokens.swift"

FILTER="${1:-}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0

for check in tools/*Check.swift; do
  name=$(basename "$check" .swift)
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue

  extra=""
  # The classifier check needs Vision/CoreML; nothing else does.
  [ "$name" = "VerdictCheck" ] && extra="Eco-Habbit/Core/ML/HabitClassifier.swift"

  cp "$check" "$TMP/main.swift"
  echo "── $name ──────────────────────────────────"
  if ! swiftc -O -o "$TMP/run" $COMMON $extra "$TMP/main.swift" 2>"$TMP/err"; then
    echo "  COMPILE FAILED"; grep -m5 'error:' "$TMP/err" | sed 's/^/  /'
    FAILED=1; continue
  fi
  "$TMP/run" || FAILED=1
done

echo
[ $FAILED -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $FAILED
