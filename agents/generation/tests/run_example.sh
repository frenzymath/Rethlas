#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBLEM_FILE="${PROBLEM_FILE:-data/example.md}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs/example}"
MODEL="${MODEL:-gpt-5.4}"
REASONING_EFFORT="${REASONING_EFFORT:-xhigh}"

if [[ ! -f "$ROOT_DIR/$PROBLEM_FILE" ]]; then
  echo "Problem file not found: $ROOT_DIR/$PROBLEM_FILE" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

problem_id="$(basename "$PROBLEM_FILE" .md)"
log_file="$LOG_DIR/${problem_id}.md"
prompt="Use AGENTS.md exactly to solve the math problem in ${PROBLEM_FILE}."

CODEX_VERSION="$(codex --version 2>/dev/null || echo 'unknown')"

echo "========================================"
echo " Codex:    $CODEX_VERSION"
echo " Model:    $MODEL"
echo " Effort:   $REASONING_EFFORT"
echo " Problem:  $PROBLEM_FILE"
echo " Log:      $log_file"
echo "========================================"
echo ""
echo "Running ${PROBLEM_FILE} -> $log_file"

START_EPOCH=$(date +%s)

elapsed_timer() {
  while true; do
    sleep 30
    local now=$(date +%s)
    local secs=$((now - START_EPOCH))
    printf "\r  [elapsed %02d:%02d:%02d] still running..." \
      $((secs/3600)) $(((secs%3600)/60)) $((secs%60))
  done
}
elapsed_timer &
TIMER_PID=$!
trap 'kill $TIMER_PID 2>/dev/null; wait $TIMER_PID 2>/dev/null' EXIT

(
  cd "$ROOT_DIR"
  codex exec \
    -C "$ROOT_DIR" \
    -m "$MODEL" \
    --config "model_reasoning_effort=\"$REASONING_EFFORT\"" \
    --dangerously-bypass-approvals-and-sandbox \
    "$prompt"
) >"$log_file" 2>&1

kill $TIMER_PID 2>/dev/null; wait $TIMER_PID 2>/dev/null
trap - EXIT

END_EPOCH=$(date +%s)
TOTAL=$((END_EPOCH - START_EPOCH))
printf "\n"
echo "Finished ${PROBLEM_FILE} -> $log_file"
printf "Total time: %02d:%02d:%02d\n" \
  $((TOTAL/3600)) $(((TOTAL%3600)/60)) $((TOTAL%60))
