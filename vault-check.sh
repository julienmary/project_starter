#!/usr/bin/env bash
# Mechanical checks on the Markdown vault. Exit 1 on the first category of failure,
# after listing every problem found. Runs from any directory.
#
# Checked:
#   - frontmatter present on every vault page, with title / status / priority / depends_on
#   - status in draft | open | decided | stable | deprecated, priority is an integer
#   - depends_on is [] or a block list of quoted wikilinks, each one resolving to a file
#   - every wikilink and Markdown link to a .md file resolves (code spans are ignored)
#   - every "status: decided" page has a line in DECISIONS.md linking to it
#   - INDEX.md stays under MAX_INDEX_LINES
#   - every node in nodes/ (except _template) has a row in the INDEX.md node map
#   - no TODO left in a page whose status is not draft

set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

MAX_INDEX_LINES=80
STATUSES='draft|open|decided|stable|deprecated'

errors=0
fail() { printf '%s\n' "$*" >&2; errors=$((errors + 1)); }

# --- helpers -----------------------------------------------------------------

frontmatter() {           # print the YAML block between the two leading --- lines
  awk 'NR==1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$1"
}

body() {                  # print everything after the frontmatter
  awk 'NR==1 && $0=="---" { infm=1; next } infm && /^---$/ { infm=0; next } !infm { print }' "$1"
}

field() {                 # field FILE KEY: scalar value of KEY, empty if absent
  frontmatter "$1" | awk -v k="$2" '$0 ~ "^"k":" { sub("^"k":[ ]*", ""); print; exit }'
}

has_field() { frontmatter "$1" | grep -qE "^$2:"; }

strip_code() {            # drop fenced blocks and inline code spans from stdin
  awk '/^```/ { f = !f; next } !f { print }' | sed -E 's/`[^`]*`//g'
}

resolve() {               # resolve TARGET (no brackets): exact path, else unique basename
  local t="${1%%|*}"; t="${t%%#*}"
  [ -z "$t" ] && return 0                       # [[#heading]] is a self link
  [ -f "$t.md" ] && return 0
  local n
  n=$(find . -path ./.git -prune -o -name "$(basename "$t").md" -print | wc -l)
  [ "$n" -eq 1 ]
}

# --- vault pages -------------------------------------------------------------

pages=()
for f in AGENTS.md COMPILE.md INDEX.md DECISIONS.md OPEN.md nodes/*.md; do
  [ -f "$f" ] && pages+=("$f")
done
[ ${#pages[@]} -eq 0 ] && { echo "no vault pages found" >&2; exit 1; }

for f in "${pages[@]}"; do
  # frontmatter presence and required keys
  if [ "$(head -n1 "$f")" != "---" ] || ! frontmatter "$f" | grep -q .; then
    fail "$f: missing frontmatter"
    continue
  fi
  for k in title status priority depends_on; do
    has_field "$f" "$k" || fail "$f: frontmatter lacks '$k'"
  done

  # status and priority values
  status=$(field "$f" status)
  [[ "$status" =~ ^($STATUSES)$ ]] || fail "$f: status '$status' not in $STATUSES"
  priority=$(field "$f" priority)
  [[ "$priority" =~ ^[0-9]+$ ]] || fail "$f: priority '$priority' is not an integer"

  # depends_on: [] inline, or a block list of quoted wikilinks
  dep_inline=$(field "$f" depends_on)
  if [ -n "$dep_inline" ] && [ "$dep_inline" != "[]" ]; then
    fail "$f: depends_on must be [] or a block list, got '$dep_inline'"
  fi
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    if [[ "$dep" =~ ^\"\[\[(.+)\]\]\"$ ]]; then
      resolve "${BASH_REMATCH[1]}" || fail "$f: depends_on target [[${BASH_REMATCH[1]}]] does not resolve"
    else
      fail "$f: depends_on entry must be a quoted wikilink like \"[[nodes/purpose]]\", got '$dep'"
    fi
  done < <(frontmatter "$f" | awk '
      /^depends_on:/ { d = 1; next }
      d && /^  - /   { sub(/^  - /, ""); print; next }
      d              { exit }')

  # links in the body
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    resolve "$link" || fail "$f: wikilink [[$link]] does not resolve"
  done < <(body "$f" | strip_code | grep -oE '\[\[[^]]+\]\]' | sed -E 's/^\[\[(.*)\]\]$/\1/')
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    [ -f "$link" ] || fail "$f: link ($link) does not resolve"
  done < <(body "$f" | strip_code | grep -oE '\]\([^)]+\.md\)' | sed -E 's/^\]\((.*)\)$/\1/')

  # decided pages must be logged
  if [ "$status" = "decided" ]; then
    name="${f%.md}"
    if ! grep -qF -e "[[$name]]" -e "[[$(basename "$name")]]" DECISIONS.md 2>/dev/null; then
      fail "$f: status is decided but DECISIONS.md has no line linking [[${name}]]"
    fi
  fi

  # no TODO outside drafts
  if [ "$status" != "draft" ] && body "$f" | strip_code | grep -q 'TODO'; then
    fail "$f: status is '$status' but the page still contains TODO"
  fi
done

# --- index -------------------------------------------------------------------

if [ -f INDEX.md ]; then
  lines=$(wc -l < INDEX.md)
  [ "$lines" -le "$MAX_INDEX_LINES" ] || fail "INDEX.md: $lines lines, max $MAX_INDEX_LINES; push detail down into nodes/"
  for f in nodes/*.md; do
    [ -f "$f" ] || continue
    b=$(basename "${f%.md}")
    [ "$b" = "_template" ] && continue
    grep -qF -e "[[nodes/$b]]" -e "[[$b]]" INDEX.md || fail "INDEX.md: node map has no row for [[nodes/$b]]"
  done
fi

# --- verdict -----------------------------------------------------------------

if [ "$errors" -gt 0 ]; then
  echo "vault-check: $errors problem(s)" >&2
  exit 1
fi
echo "vault-check: ok (${#pages[@]} pages)"
