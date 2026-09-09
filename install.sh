#!/usr/bin/env bash
#
# install.sh: wire the vault checks to git and to Claude Code.
#
#   1. git pre-commit hook   -> git config core.hooksPath hooks   (mechanical checks, humans and agents)
#   2. Claude Code hook      -> hooks/claude-pre-commit.sh        (mechanical checks + the drift question, agents)
#
# The Claude Code hook can be installed for this project (.claude/ in the repo,
# versioned with it) or globally (~/.claude/, every repo on this machine).
# Read hooks/claude-pre-commit.sh before choosing: its header explains what
# problem it solves and what it will refuse.
#
# Usage:
#   ./install.sh                       interactive
#   ./install.sh --project [--no-git]  non-interactive, project scope
#   ./install.sh --global  [--no-git]  non-interactive, global scope
#   ./install.sh --git-only            only the git hook
#
# Runs on Linux and macOS (bash 3.2). Needs jq or python3 to edit settings.json;
# without them the JSON to add is printed for you to paste.

set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

HOOK_SRC="hooks/claude-pre-commit.sh"
HOOK_NAME="claude-pre-commit.sh"
STATUS_MSG="vault: checking commit"

SCOPE=""
GIT_HOOK="ask"
for arg in "$@"; do
    case "$arg" in
        --project)  SCOPE="project" ;;
        --global)   SCOPE="global" ;;
        --git-only) SCOPE="none"; GIT_HOOK="yes" ;;
        --no-git)   GIT_HOOK="no" ;;
        -h|--help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done
[ -n "$SCOPE" ] && [ "$GIT_HOOK" = "ask" ] && GIT_HOOK="yes"

[ -f "$HOOK_SRC" ] || { echo "missing $HOOK_SRC" >&2; exit 1; }
[ -f "vault-check.sh" ] || { echo "missing vault-check.sh" >&2; exit 1; }

say() { printf '%s\n' "$*"; }
ask() {                       # ask PROMPT DEFAULT -> answer in $REPLY
    local prompt="$1" default="$2"
    printf '%s [%s] ' "$prompt" "$default"
    read -r REPLY </dev/tty || REPLY=""
    [ -z "$REPLY" ] && REPLY="$default"
}

# ---------------------------------------------------------------------------
# Interactive choices
# ---------------------------------------------------------------------------
if [ -z "$SCOPE" ]; then
    say ""
    say "Read this before choosing. Header of $HOOK_SRC:"
    say "------------------------------------------------------------------"
    sed -n '3,/^# HOW IT RUNS/p' "$HOOK_SRC" | sed '$d' | sed 's/^# \{0,1\}//'
    say "------------------------------------------------------------------"
    say "Full file: $HOOK_SRC"
    say ""
    say "Where should the Claude Code hook go?"
    say "  1) project   .claude/hooks/ + .claude/settings.json in this repo, versioned with it"
    say "  2) global    ~/.claude/hooks/ + ~/.claude/settings.json, every repo on this machine"
    say "  3) skip      git hook only"
    ask "Choice" "1"
    case "$REPLY" in
        1) SCOPE="project" ;;
        2) SCOPE="global" ;;
        3) SCOPE="none" ;;
        *) echo "aborted" >&2; exit 1 ;;
    esac
fi

if [ "$GIT_HOOK" = "ask" ]; then
    ask "Enable the git pre-commit hook (git config core.hooksPath hooks)? y/n" "y"
    case "$REPLY" in y|Y|yes) GIT_HOOK="yes" ;; *) GIT_HOOK="no" ;; esac
fi

# ---------------------------------------------------------------------------
# 1. git hook
# ---------------------------------------------------------------------------
if [ "$GIT_HOOK" = "yes" ]; then
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git config core.hooksPath hooks
        say "git: core.hooksPath = hooks (hooks/pre-commit runs vault-check.sh)"
    else
        say "git: not a repository yet, run 'git config core.hooksPath hooks' after git init"
    fi
fi

[ "$SCOPE" = "none" ] && exit 0

# ---------------------------------------------------------------------------
# 2. Claude Code hook: file
# ---------------------------------------------------------------------------
if [ "$SCOPE" = "project" ]; then
    DEST_DIR=".claude/hooks"
    SETTINGS=".claude/settings.json"
    # Symlink: one source, hooks/claude-pre-commit.sh, nothing to keep in sync.
    mkdir -p "$DEST_DIR"
    ln -sfn "../../$HOOK_SRC" "$DEST_DIR/$HOOK_NAME"
    CMD="\"\$CLAUDE_PROJECT_DIR\"/$DEST_DIR/$HOOK_NAME"
    say "hook: $DEST_DIR/$HOOK_NAME -> $HOOK_SRC (symlink)"
else
    DEST_DIR="$HOME/.claude/hooks"
    SETTINGS="$HOME/.claude/settings.json"
    mkdir -p "$DEST_DIR"
    cp "$HOOK_SRC" "$DEST_DIR/$HOOK_NAME"
    chmod +x "$DEST_DIR/$HOOK_NAME"
    CMD="$DEST_DIR/$HOOK_NAME"
    say "hook: copied to $DEST_DIR/$HOOK_NAME (re-run ./install.sh --global after updating $HOOK_SRC)"
fi

# ---------------------------------------------------------------------------
# 3. Claude Code hook: settings.json
#    Adds {matcher: Bash, hooks: [{type: command, command: CMD}]} under
#    hooks.PreToolUse unless an entry with the same command already exists.
#    Everything else in the file is preserved.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

if command -v python3 >/dev/null 2>&1; then
    RESULT=$(python3 - "$SETTINGS" "$CMD" "$STATUS_MSG" <<'PY'
import json, sys
path, cmd, status = sys.argv[1:4]
with open(path) as fh:
    data = json.load(fh)
pre = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
others = []
for entry in pre:
    for h in entry.get("hooks", []):
        c = h.get("command", "")
        if c == cmd:
            print("exists"); sys.exit(0)
        if entry.get("matcher") == "Bash":
            others.append(c)
pre.append({"matcher": "Bash", "hooks": [{"type": "command", "command": cmd, "statusMessage": status}]})
with open(path, "w") as fh:
    json.dump(data, fh, indent=2); fh.write("\n")
print("added")
for c in others:
    print("other:" + c)
PY
    )
elif command -v jq >/dev/null 2>&1; then
    TMP="$SETTINGS.tmp.$$"
    if jq -e --arg cmd "$CMD" '[.hooks.PreToolUse[]?.hooks[]?.command] | index($cmd)' "$SETTINGS" >/dev/null 2>&1; then
        RESULT="exists"
    else
        RESULT=$(jq --arg cmd "$CMD" -r '[.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]?.command] | .[] | "other:" + .' "$SETTINGS")
        jq --arg cmd "$CMD" --arg st "$STATUS_MSG" \
           '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher:"Bash", hooks:[{type:"command", command:$cmd, statusMessage:$st}]}])' \
           "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        RESULT="added"$'\n'"$RESULT"
    fi
else
    say "settings: neither python3 nor jq found. Add this to $SETTINGS under hooks.PreToolUse:"
    say "  {\"matcher\": \"Bash\", \"hooks\": [{\"type\": \"command\", \"command\": \"$CMD\", \"statusMessage\": \"$STATUS_MSG\"}]}"
    exit 0
fi

# The same hook registered in the other scope (project vs global) runs twice
# per commit, and the second run answers a question the agent never saw.
MARKER='claude-pre-commit.sh: Claude Code hook'
list_bash_hooks() {           # list_bash_hooks SETTINGS_FILE -> one command per line
    [ -f "$1" ] || return 0
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$1" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for entry in data.get("hooks", {}).get("PreToolUse", []):
    if entry.get("matcher") == "Bash":
        for h in entry.get("hooks", []):
            print(h.get("command", ""))
PY
    else
        jq -r '.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]?.command' "$1" 2>/dev/null
    fi
}
if [ "$SCOPE" = "project" ]; then OTHER="$HOME/.claude/settings.json"; else OTHER=".claude/settings.json"; fi
while IFS= read -r other_cmd; do
    [ -z "$other_cmd" ] && continue
    f=${other_cmd//\"/}; f=${f/#\~/$HOME}; f=${f//\$HOME/$HOME}; f=${f//\$CLAUDE_PROJECT_DIR/$PWD}
    if [ -f "$f" ] && grep -q "$MARKER" "$f" 2>/dev/null; then
        say "warning: the same hook is also registered in $OTHER as $other_cmd"
        say "         it will run twice on every commit here; remove one of the two registrations"
    fi
done <<EOF_HOOKS
$(list_bash_hooks "$OTHER")
EOF_HOOKS

case "$RESULT" in
    exists*) say "settings: $SETTINGS already registers this hook" ;;
    added*)  say "settings: hook registered in $SETTINGS" ;;
    *)       say "settings: unexpected result: $RESULT" >&2; exit 1 ;;
esac
printf '%s\n' "$RESULT" | grep '^other:' | sed 's/^other:/warning: another Bash PreToolUse hook is registered: /'
say "done. Claude Code reads settings at startup: restart the session for the hook to take effect."
