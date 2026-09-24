#!/usr/bin/env bash
set -euo pipefail

export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBLEM_FILE="${PROBLEM_FILE:-data/example.md}"
MODEL="${MODEL:-gpt-5.6-sol}"
REASONING_EFFORT="${REASONING_EFFORT:-max}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"
DRY_RUN="${DRY_RUN:-0}"

if [[ "$PROBLEM_FILE" = /* ]]; then
  echo "PROBLEM_FILE must be relative to agents/generation: $PROBLEM_FILE" >&2
  exit 1
fi

if [[ "$PROBLEM_FILE" == ".." || "$PROBLEM_FILE" == ../* || "$PROBLEM_FILE" == */.. || "$PROBLEM_FILE" == */../* ]]; then
  echo "PROBLEM_FILE must not contain '..': $PROBLEM_FILE" >&2
  exit 1
fi

if [[ "$PROBLEM_FILE" != data/*.md ]]; then
  echo "PROBLEM_FILE must point to a markdown file under data/: $PROBLEM_FILE" >&2
  exit 1
fi

if [[ ! -f "$ROOT_DIR/$PROBLEM_FILE" ]]; then
  echo "Problem file not found: $ROOT_DIR/$PROBLEM_FILE" >&2
  exit 1
fi

if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$MAX_ITERATIONS" -le 0 ]]; then
  echo "MAX_ITERATIONS must be a positive integer: $MAX_ITERATIONS" >&2
  exit 1
fi

if [[ "$DRY_RUN" != 0 && "$DRY_RUN" != 1 ]]; then
  echo "DRY_RUN must be 0 or 1: $DRY_RUN" >&2
  exit 1
fi

# data/algebra/prob1.md -> algebra/prob1
problem_rel="${PROBLEM_FILE#data/}"
problem_rel="${problem_rel%.md}"
problem_name="$(basename "$PROBLEM_FILE" .md)"
ref_dir="data/${problem_rel}.refs"
ref_prompt="Use reference_dir=${ref_dir} if it exists."

prepare_references() {
  local abs_ref_dir="$ROOT_DIR/$ref_dir"
  if [[ ! -d "$abs_ref_dir" ]]; then
    return
  fi

  local pdf_count=0
  while IFS= read -r -d '' pdf; do
    pdf_count=$((pdf_count + 1))
    if ! command -v pdftotext >/dev/null 2>&1; then
      echo "WARNING: found PDF references, but pdftotext is not installed; PDFs will be ignored." >&2
      return
    fi

    local rel_pdf="${pdf#"$abs_ref_dir"/}"
    local txt="$abs_ref_dir/.extracted/${rel_pdf%.pdf}.txt"
    mkdir -p "$(dirname "$txt")"
    if [[ ! -f "$txt" || "$pdf" -nt "$txt" ]]; then
      pdftotext -layout "$pdf" "$txt"
    fi
  done < <(find "$abs_ref_dir" -type f -iname '*.pdf' -not -path "$abs_ref_dir/.extracted/*" -print0)

  if [[ $pdf_count -gt 0 ]]; then
    ref_prompt="Use reference_dir=${ref_dir} if it exists. PDF references have been extracted to ${ref_dir}/.extracted; read those extracted .txt files instead of the PDFs."
  fi
}

extract_session_id() {
  local log_file="$1"
  awk -F'session id: ' 'NF > 1 { sub(/[[:space:]]+$/, "", $2); print $2; exit }' "$log_file"
}

format_duration() {
  local total="$1"
  printf "%02d:%02d:%02d" \
    $((total / 3600)) $(((total % 3600) / 60)) $((total % 60))
}

LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs/$problem_rel/iter}"
verified_path="$ROOT_DIR/results/$problem_rel/blueprint_verified.md"
pause_path="${PAUSE_FILE:-$ROOT_DIR/results/$problem_rel/PAUSE_AFTER_ITERATION}"

if [[ -f "$verified_path" ]]; then
  echo "Already solved: $verified_path"
  exit 0
fi

session_id="${SESSION_ID:-}"
session_id_is_explicit=0
if [[ -n "$session_id" ]]; then
  session_id_is_explicit=1
fi

next_iter=0
found_log=0

if [[ -d "$LOG_DIR" ]]; then
  shopt -s nullglob
  for prior_log in "$LOG_DIR/${problem_name}_iter_"*.md; do
    filename="${prior_log##*/}"
    if [[ "$filename" =~ _iter_([0-9]+)\.md$ ]]; then
      found_log=1
      iter_number="${BASH_REMATCH[1]}"
      if ((iter_number >= next_iter)); then
        next_iter=$((iter_number + 1))
      fi
    fi

    if [[ "$session_id_is_explicit" -eq 0 ]]; then
      discovered_id="$(extract_session_id "$prior_log")"
      if [[ -n "$discovered_id" ]]; then
        if [[ -z "$session_id" ]]; then
          session_id="$discovered_id"
        elif [[ "$session_id" != "$discovered_id" ]]; then
          echo "Conflicting session IDs found in $LOG_DIR" >&2
          echo "Set SESSION_ID explicitly to select the session to resume." >&2
          exit 1
        fi
      fi
    fi
  done
  shopt -u nullglob
fi

if [[ "$found_log" -eq 1 && -z "$session_id" ]]; then
  echo "Could not recover a session ID from $LOG_DIR" >&2
  echo "Set SESSION_ID explicitly if you know it." >&2
  exit 1
fi

if [[ -e "$pause_path" ]]; then
  echo "Pause marker already exists: $pause_path" >&2
  echo "Remove it before running again." >&2
  exit 1
fi

CODEX_VERSION="$(codex --version 2>/dev/null || echo 'unknown')"

echo "========================================"
echo " Codex:      $CODEX_VERSION"
echo " Codex home: $CODEX_HOME"
echo " Model:      $MODEL"
echo " Effort:     $REASONING_EFFORT"
echo " Problem:    $PROBLEM_FILE"
echo " Problem ID: $problem_rel"
echo " References: $ref_dir"
echo " Max iters:  $MAX_ITERATIONS"
if [[ "$found_log" -eq 1 ]]; then
  echo " Mode:       resume"
  echo " Session:    $session_id"
  echo " Next iter:  $next_iter"
else
  echo " Mode:       new"
  echo " Next iter:  0"
fi
echo " Logs:       $LOG_DIR"
echo " Stop file:  $verified_path"
echo " Pause file: $pause_path"
echo "========================================"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run only; no verification request or Codex run was started."
  exit 0
fi

prepare_references
mkdir -p "$LOG_DIR"

VERIFY_URL="${VERIFY_URL:-http://127.0.0.1:8091/health}"
if ! curl -sf "$VERIFY_URL" >/dev/null 2>&1; then
  echo "WARNING: verification service not reachable at ${VERIFY_URL%%/health*}"
  echo "         The agent may be unable to produce blueprint_verified.md."
  echo "         Start it first if you need verified proofs."
  echo ""
fi

START_EPOCH=$(date +%s)

elapsed_timer() {
  while true; do
    sleep 30
    local now
    now=$(date +%s)
    local secs=$((now - START_EPOCH))
    printf "\r  [elapsed %s] still running..." "$(format_duration "$secs")"
  done
}

elapsed_timer &
TIMER_PID=$!

cleanup_timer() {
  kill "$TIMER_PID" 2>/dev/null || true
  wait "$TIMER_PID" 2>/dev/null || true
}
trap cleanup_timer EXIT

end_iter=$((next_iter + MAX_ITERATIONS))
started_fresh=0
if [[ "$found_log" -eq 0 ]]; then
  started_fresh=1
fi

for ((iter = next_iter; iter < end_iter; iter += 1)); do
  if [[ -f "$verified_path" ]]; then
    echo "Solved problem_id=$problem_rel before iter=$iter"
    break
  fi

  if [[ -e "$pause_path" ]]; then
    echo "Paused before iter=$iter because marker exists: $pause_path"
    break
  fi

  log_file="$LOG_DIR/${problem_name}_iter_${iter}.md"
  if [[ -e "$log_file" ]]; then
    echo "Refusing to overwrite existing log: $log_file" >&2
    exit 1
  fi

  echo "Starting iter=$iter -> $log_file"

  if [[ "$started_fresh" -eq 1 && "$iter" -eq 0 ]]; then
    prompt="Use AGENTS.md exactly to solve the math problem in ${PROBLEM_FILE}. Use problem_id=${problem_rel}. ${ref_prompt}"

    if (
      cd "$ROOT_DIR"
      codex exec \
        -C "$ROOT_DIR" \
        -m "$MODEL" \
        --config "model_reasoning_effort=\"$REASONING_EFFORT\"" \
        --dangerously-bypass-approvals-and-sandbox \
        "$prompt"
    ) >"$log_file" 2>&1; then
      codex_rc=0
    else
      codex_rc=$?
    fi

    if [[ "$codex_rc" -ne 0 ]]; then
      echo "codex exited with code $codex_rc at iter=$iter (see $log_file for details)" >&2
      exit "$codex_rc"
    fi

    session_id="$(extract_session_id "$log_file")"
    if [[ -z "$session_id" && ! -f "$verified_path" ]]; then
      echo "Could not extract session id from $log_file" >&2
      exit 1
    fi
  else
    if ((iter % 2 == 1)); then
      web_mode="disabled"
      if [[ "$started_fresh" -eq 1 ]]; then
        prompt="Please continue. Do not use search tools like arxiv theorem search or web search. Please think deeply by yourself.
"
      else
        prompt="Please continue from the persisted memory and working draft. Follow AGENTS.md exactly. Do not use search tools like arXiv theorem search or web search during this turn; think deeply by yourself."
      fi
    else
      web_mode="live"
      if [[ "$started_fresh" -eq 1 ]]; then
        prompt="Please continue. You may now use search tools, such as arXiv theorem search and web search, during your reasoning, but please also think deeply by yourself.
"
      else
        prompt="Please continue from the persisted memory and working draft. Follow AGENTS.md exactly. You may use search tools, such as arXiv theorem search and web search, during this turn, but also think deeply by yourself."
      fi
    fi

    if (
      cd "$ROOT_DIR"
      codex exec resume "$session_id" \
        -m "$MODEL" \
        --config "model_reasoning_effort=\"$REASONING_EFFORT\"" \
        --config "web_search=\"$web_mode\"" \
        --dangerously-bypass-approvals-and-sandbox \
        "$prompt"
    ) >"$log_file" 2>&1; then
      codex_rc=0
    else
      codex_rc=$?
    fi

    if [[ "$codex_rc" -ne 0 ]]; then
      echo "codex exited with code $codex_rc at iter=$iter (see $log_file for details)" >&2
      exit "$codex_rc"
    fi
  fi

  echo "Finished problem_id=$problem_rel iter=$iter -> $log_file"

  if [[ -e "$pause_path" ]]; then
    echo "Paused after iter=$iter because marker exists: $pause_path"
    break
  fi
done

cleanup_timer
trap - EXIT

END_EPOCH=$(date +%s)
TOTAL=$((END_EPOCH - START_EPOCH))
printf "\n"

if [[ -f "$verified_path" ]]; then
  echo "Solved problem_id=$problem_rel -> $verified_path"
  printf "Total time: %s\n" "$(format_duration "$TOTAL")"
  echo ""
  echo "To view results in the browser, run:"
  echo "  ./site/serve.sh"
  echo "Then open http://localhost:3264"
  exit 0
fi

if [[ -e "$pause_path" ]]; then
  echo "Run paused. Remove the marker to continue later: $pause_path"
  printf "Total time: %s\n" "$(format_duration "$TOTAL")"
  exit 0
fi

echo "Completed MAX_ITERATIONS=$MAX_ITERATIONS without verified blueprint for problem_id=$problem_rel" >&2
echo "Run this script again to continue from the next unused iteration." >&2
printf "Total time: %s\n" "$(format_duration "$TOTAL")"
exit 1
