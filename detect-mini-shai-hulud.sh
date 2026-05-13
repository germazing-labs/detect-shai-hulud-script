#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

if [[ -d "$TARGET_DIR" ]]; then
  TARGET_DIR_ABS="$(cd -- "$TARGET_DIR" && pwd -P)"
elif [[ -f "$TARGET_DIR" ]]; then
  TARGET_DIR_ABS="$(cd -- "$(dirname -- "$TARGET_DIR")" && pwd -P)"
else
  echo "[ERROR] Target not found: $TARGET_DIR" >&2
  exit 2
fi

SELF_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'

FOUND=0

bad()  { printf '%b[ALERT]%b %s\n' "$RED" "$NC" "$1"; }
warn() { printf '%b[WARN]%b  %s\n' "$YELLOW" "$NC" "$1"; }
good() { printf '%b[OK]%b    %s\n' "$GREEN" "$NC" "$1"; }

walk_files() {
  find "$TARGET_DIR_ABS" \
    \( -path '*/node_modules/*' -o \
       -path '*/.git/*' -o \
       -path '*/dist/*' -o \
       -path '*/build/*' -o \
       -path '*/coverage/*' -o \
       -path '*/.next/*' -o \
       -path '*/.turbo/*' \
    \) -prune -o -type f -print0
}

grep_file_lines() {
  local regex="$1"
  local file="$2"

  grep -nH -I -E -- "$regex" "$file" 2>/dev/null \
    | awk -F: 'BEGIN { OFS=":" } { print $1, $2 }' || true
}

scan_regex_in_globs() {
  local title="$1"
  local regex="$2"
  shift 2

  local printed=0
  local file hit matched_glob pat

  while IFS= read -r -d '' file; do
    [[ "$file" != "$SELF_PATH" ]] || continue

    matched_glob=0
    for pat in "$@"; do
      case "$file" in
        $pat)
          matched_glob=1
          break
          ;;
      esac
    done
    [[ "$matched_glob" -eq 1 ]] || continue

    hit="$(grep_file_lines "$regex" "$file")"
    if [[ -n "$hit" ]]; then
      [[ "$printed" -ne 0 ]] || { bad "$title"; printed=1; }
      printf '%s\n' "$hit"
      FOUND=1
    fi
  done < <(walk_files)

  [[ "$printed" -ne 1 ]] || echo
}

scan_paths() {
  local title="$1"
  shift

  local printed=0
  local file pat

  while IFS= read -r -d '' file; do
    [[ "$file" != "$SELF_PATH" ]] || continue

    for pat in "$@"; do
      case "$file" in
        $pat)
          [[ "$printed" -ne 0 ]] || { warn "$title"; printed=1; }
          printf '%s\n' "$file"
          FOUND=1
          break
          ;;
      esac
    done
  done < <(walk_files)

  [[ "$printed" -ne 1 ]] || echo
}

echo "======================================================"
echo " Mini Shai-Hulud / TanStack IOC Scanner"
echo " Target: $TARGET_DIR_ABS"
echo " Self : $SELF_PATH"
echo "======================================================"
echo

echo "Checking package manifests and lockfiles..."
scan_regex_in_globs \
  "Package / lockfile indicators found" \
  '(^|[^@[:alnum:]_-])tanstack([^[:alnum:]_-]|$)|npm/tanstack@2\.0\.[4-7]|mbt@1\.2\.48|@cap-js/db-service@2\.10\.1|@cap-js/postgres@2\.2\.2|@cap-js/sqlite@2\.2\.2|intercom-client@7\.0\.4' \
  '*/package.json' \
  '*/package-lock.json' \
  '*/bun.lock' \
  '*/yarn.lock' \
  '*/pnpm-lock.yaml' \
  '*/npm-shrinkwrap.json'

echo "Checking lifecycle hooks..."
scan_regex_in_globs \
  "Lifecycle hooks found in manifests" \
  '"(preinstall|install|postinstall|prepare|prepack)"' \
  '*/package.json'

echo "Checking payload / persistence strings..."
scan_regex_in_globs \
  "Payload or persistence strings found" \
  'execution\.js|router_runtime\.js|bundle\.js|setup_bun\.js|bun_environment\.js|truffleSecrets\.json|cloud\.json|contents\.json|shai-hulud-workflow\.yml|SessionStart|folderOpen|A Mini Shai-Hulud has Appeared|api\.svix\.com|src_3387PLMB2uhXOBe3Q8sHu|github\.com/oven-sh/bun|GitHub Releases|self-hosted runner|runner registration|shai-hulud' \
  '*/package.json' \
  '*/package-lock.json' \
  '*/bun.lock' \
  '*/yarn.lock' \
  '*/pnpm-lock.yaml' \
  '*/npm-shrinkwrap.json' \
  '*/.github/workflows/*' \
  '*/.claude/settings.json' \
  '*/.vscode/tasks.json' \
  '*/**/*.js' \
  '*/**/*.mjs' \
  '*/**/*.cjs' \
  '*/**/*.ts' \
  '*/**/*.yml' \
  '*/**/*.yaml' \
  '*/**/*.json' \
  '*/**/*.sh'

echo "Checking for suspicious file names..."
scan_paths \
  "Suspicious files present" \
  '*/.claude/settings.json' \
  '*/.vscode/tasks.json' \
  '*/shai-hulud-workflow.yml' \
  '*/bundle.js' \
  '*/execution.js' \
  '*/router_runtime.js' \
  '*/setup_bun.js' \
  '*/bun_environment.js' \
  '*/data.json'

echo "Checking for exposed env files..."
scan_paths \
  "Sensitive env files present" \
  '*/.env' \
  '*/.env.local' \
  '*/.env.production' \
  '*/.env.development' \
  '*/.env.test'

echo "Checking git refs, if this is a repository..."
if command -v git >/dev/null 2>&1 && git -C "$TARGET_DIR_ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  refs="$(git -C "$TARGET_DIR_ABS" for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null | grep -i 'shai-hulud' || true)"
  if [[ -n "$refs" ]]; then
    warn "Git refs containing shai-hulud"
    printf '%s\n' "$refs"
    echo
    FOUND=1
  fi

  branch_name_hits="$(git -C "$TARGET_DIR_ABS" branch --list '*shai-hulud*' 2>/dev/null || true)"
  if [[ -n "$branch_name_hits" ]]; then
    warn "Local branches containing shai-hulud"
    printf '%s\n' "$branch_name_hits"
    echo
    FOUND=1
  fi
fi

echo "======================================================"

if [[ "$FOUND" -eq 0 ]]; then
  good "No obvious Mini Shai-Hulud / TanStack indicators found."
else
  bad "Potential indicators detected."
  echo
  echo "Next steps:"
  echo "  - rotate npm, GitHub, cloud, and AI-tool credentials"
  echo "  - delete and reinstall dependencies from trusted sources"
  echo "  - review .github/workflows, .claude/settings.json, and .vscode/tasks.json"
  echo "  - inspect lockfiles for unscoped tanstack and the known malicious versions"
fi

echo "======================================================"
exit "$FOUND"
