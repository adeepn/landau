#!/usr/bin/env bash
# Spell-check Markdown sources using hunspell with ru_RU + en_US dictionaries.
# Words listed in .spellcheck-allow.txt are accepted as correct.
#
# Usage: scripts/spellcheck.sh [paths...]
# Default scope when no args given: content/, docs/, README.md, AGENTS.md.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ALLOW="${ROOT}/.spellcheck-allow.txt"
[ -f "${ALLOW}" ] || { echo "missing allow list: ${ALLOW}" >&2; exit 1; }

cd "${ROOT}"

PATHS=("$@")
if [ "${#PATHS[@]}" -eq 0 ]; then
  PATHS=(content docs README.md AGENTS.md)
fi

mapfile -t files < <(
  for p in "${PATHS[@]}"; do
    [ -e "$p" ] || continue
    if [ -d "$p" ]; then
      find "$p" -type f -name '*.md'
    else
      printf '%s\n' "$p"
    fi
  done | sort -u
)

if [ "${#files[@]}" -eq 0 ]; then
  echo "no markdown files found"
  exit 0
fi

unknown=$(mktemp)
trap 'rm -f "${unknown}"' EXIT

for f in "${files[@]}"; do
  awk '
    BEGIN { fm = 0; code = 0 }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    fm && /^---[[:space:]]*$/      { fm = 0; next }
    fm                             { next }
    /^[[:space:]]*```/             { code = !code; next }
    code                           { next }
    {
      gsub(/<[^>]*>/, " ")                              # HTML tags
      gsub(/`[^`]*`/, " ")                              # inline code spans
      gsub(/https?:\/\/[^[:space:])]+/, " ")            # URLs
      gsub(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/, " ")     # emails
      gsub(/[][(){}|*_~#]/, " ")                        # markdown punctuation
      print
    }
  ' "$f" \
  | hunspell -d ru_RU,en_US -l \
  >> "${unknown}"
done

# Empty unknown list = nothing to filter; happy exit.
if [ ! -s "${unknown}" ]; then
  echo "Spell check OK across ${#files[@]} files."
  exit 0
fi

# Filter accumulated unknowns against the allow list (exact, fixed strings).
sort -u "${unknown}" -o "${unknown}"
filtered=$(grep -vxFf "${ALLOW}" "${unknown}" || true)

if [ -n "${filtered}" ]; then
  echo "::error::Unknown words found in markdown sources:"
  printf '%s\n' "${filtered}" | sed 's/^/  /'
  echo
  echo "If these are intentional (proper nouns, technical terms),"
  echo "add them to .spellcheck-allow.txt. Otherwise, fix the spelling."
  exit 1
fi

echo "Spell check OK across ${#files[@]} files."
