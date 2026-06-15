#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN_DIR="$(cd "$SITE_DIR/.." && pwd)"
CONTENT_DIR="$SITE_DIR/content"
RESULTS_DIR="$GEN_DIR/results"
TRANSFORM="$SITE_DIR/transform_math.py"
PORT="${PORT:-3264}"

if [[ ! -d "$SITE_DIR/themes/MATbook" ]]; then
  bash "$SITE_DIR/setup_theme.sh"
fi

sync_content() {
  echo "Syncing results into site/content/ ..."

  # Clean generated content while preserving the root landing section.
  find "$CONTENT_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
  find "$CONTENT_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.md' ! -name '_index.md' -exec rm -f {} +

  if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "No results directory found at $RESULTS_DIR"
    return
  fi

  local page_count=0
  local section_seen=$'\n'
  local section_weight=1

  toml_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
  }

  ensure_section_indexes() {
    local rel_dir="$1"
    local partial=""
    local component
    IFS='/' read -r -a components <<< "$rel_dir"

    for component in "${components[@]}"; do
      if [[ -z "$component" ]]; then
        continue
      fi

      if [[ -z "$partial" ]]; then
        partial="$component"
      else
        partial="$partial/$component"
      fi

      local section_dir="$CONTENT_DIR/$partial"
      if [[ "$section_seen" != *$'\n'"$partial"$'\n'* ]]; then
        mkdir -p "$section_dir"
        local weight="$section_weight"
        if [[ "$partial" == "unclassified" ]]; then
          weight=0
        fi
        printf '+++\ntitle = "%s"\nsort_by = "slug"\nweight = %d\n+++\n' \
          "$(toml_escape "$component")" "$weight" > "$section_dir/_index.md"
        section_seen+="${partial}"$'\n'
        if [[ "$partial" != "unclassified" ]]; then
          section_weight=$((section_weight + 1))
        fi
      fi
    done
  }

  while IFS= read -r -d '' problem_dir; do
    local source_md=""
    if [[ -f "$problem_dir/blueprint_verified.md" ]]; then
      source_md="$problem_dir/blueprint_verified.md"
    elif [[ -f "$problem_dir/blueprint.md" ]]; then
      source_md="$problem_dir/blueprint.md"
    else
      continue
    fi

    local problem_rel="${problem_dir#"$RESULTS_DIR"/}"
    # problem_rel is e.g. "my_problem" or "example/example1".
    # The leaf problem becomes the page; parent directories become sections.
    # Root-level problems are grouped under the generated unclassified section.

    local page_name="${problem_rel##*/}"
    local category_dir="unclassified"
    if [[ "$problem_rel" == */* ]]; then
      category_dir="${problem_rel%/*}"
    fi
    ensure_section_indexes "$category_dir"

    local dest
    dest="$CONTENT_DIR/$category_dir/$page_name.md"

    local ts
    ts="$(date -r "$source_md" +%Y-%m-%d 2>/dev/null || echo "2026-01-01")"

    local tmp="$dest.tmp"
    mkdir -p "$(dirname "$dest")"
    python3 "$TRANSFORM" "$source_md" "$tmp"

    {
      printf '+++\ntitle = "%s"\ndate = %s\nweight = %d\n' \
        "$(toml_escape "$page_name")" "$ts" "$page_count"
      printf '[extra]\nmath = true\n+++\n\n'
      cat "$tmp"
    } > "$dest"
    rm -f "$tmp"
    page_count=$((page_count + 1))
  done < <(find "$RESULTS_DIR" -mindepth 1 -type d -print0 | sort -z)

  echo "Done. Synced ${page_count} page(s)."
}

sync_content

if [[ "${SYNC_ONLY:-0}" == "1" ]]; then
  exit 0
fi

echo ""
echo "Starting zola serve on http://localhost:${PORT} ..."
echo ""
cd "$SITE_DIR"
exec zola serve --port "$PORT" --interface 127.0.0.1
