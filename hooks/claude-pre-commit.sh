#!/usr/bin/env bash
#
# claude-pre-commit.sh: Claude Code hook that keeps the vault honest at commit time.
#
# THE PROBLEM IT SOLVES
#
#   A vault drifts. The code moves, nobody reopens nodes/constraints.md, and three
#   months later the vault is a second stale PROMPT.md next to the code. Written
#   rules ("keep the vault up to date") do not hold against that; a check wired to
#   the commit does. Two kinds of check are needed:
#
#   1. What a script can verify: frontmatter, statuses, links, every decided page
#      logged in DECISIONS.md, INDEX.md size. That is vault-check.sh. The git
#      pre-commit hook in hooks/ runs it for humans; this hook runs it for the agent.
#
#   2. What needs judgement: "does this change to the code make a node false?"
#      No script can answer. The agent can, if it is asked at the right moment.
#      This hook asks. When a commit touches project files but no vault content
#      (INDEX.md, DECISIONS.md, OPEN.md, nodes/), it refuses the commit until the
#      message carries a trailer on its own line:
#
#         Vault: updated     a node, DECISIONS.md or OPEN.md changed with the code
#         Vault: unchanged   the nodes this change concerns were reread and still hold
#
#      "unchanged" is a claim made after reading, not a default. The trailer ends
#      up in git log, so the claim is auditable later.
#
#   As a side benefit it also refuses a commit while a tracked file matches
#   .gitignore, which is how private files leak into public repos.
#
# HOW IT RUNS
#
#   Claude Code calls it as a PreToolUse hook on the Bash tool, with a JSON object
#   on stdin. Only commands containing "git commit" are inspected. Exit 2 blocks
#   the command and hands stderr back to the agent, which then fixes the vault or
#   writes the trailer. Repositories without a vault-check.sh at their root are
#   left alone, except for the .gitignore check.
#
#   Install with ./install.sh (project or global scope). Needs jq or python3 to
#   read the JSON input. Runs on Linux and macOS (bash 3.2, BSD tools).
#
# LIMITS
#
#   - Only commits issued through Claude Code pass here. A commit typed in a
#     terminal only gets the mechanical checks, through the git hook.
#   - "git commit -F path" is not inspected for the trailer; use "-F -" with a
#     heredoc, or -m.
#   - "git add ... && git commit" stages after this hook ran, so the whole working
#     tree is considered in that case. A false positive only asks for a trailer.

# ---------------------------------------------------------------------------
# Input: {"tool_input": {"command": "..."}} on stdin
# ---------------------------------------------------------------------------
INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
elif command -v python3 >/dev/null 2>&1; then
    COMMAND=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')
else
    case "$INPUT" in
        *"git commit"*)
            echo "BLOCKED: hooks/claude-pre-commit.sh needs jq or python3 to read its input. Install one of them." >&2
            exit 2 ;;
        *) exit 0 ;;
    esac
fi

# Only intercept git commit commands
case "$COMMAND" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$TOP" || exit 0

# ---------------------------------------------------------------------------
# 1. Tracked files that should be gitignored
# ---------------------------------------------------------------------------
LEAKED=""
while IFS= read -r tracked_file; do
    # --no-index: without it, check-ignore never reports a tracked file
    if git check-ignore -q --no-index "$tracked_file" 2>/dev/null; then
        LEAKED="$LEAKED  $tracked_file"$'\n'
    fi
done < <(git ls-files)

if [ -n "$LEAKED" ]; then
    {
        echo "BLOCKED: These tracked files match .gitignore patterns:"
        printf '%s' "$LEAKED"
        echo "Run 'git rm --cached <file>' to untrack them first."
    } >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# 2. Vault repos only
# ---------------------------------------------------------------------------
[ -x "$TOP/vault-check.sh" ] || exit 0

# 2a. Mechanical checks
if ! CHECK=$("$TOP/vault-check.sh" 2>&1); then
    {
        echo "BLOCKED: vault-check.sh failed. Fix the vault, do not bypass it."
        printf '%s\n' "$CHECK"
    } >&2
    exit 2
fi

# 2b. Drift question
# Files the template ships. Content pages count as "vault updated"; method
# files count as neither vault content nor project code.
is_vault_content() { [[ "$1" =~ ^(INDEX\.md|DECISIONS\.md|OPEN\.md|nodes/.+\.md)$ ]]; }
is_method_file()   { [[ "$1" =~ ^(README\.md|AGENTS\.md|COMPILE\.md|LICENSE|\.gitignore|vault-check\.sh|install\.sh|hooks/.*|\.claude/.*)$ ]]; }

# Which files will this commit take? Staged ones, unless the command stages
# more at execution time (git add in the same command, -a / --all / -am),
# in which case every change in the working tree is considered. Conservative:
# a false positive only asks for a trailer.
STAGES_ALL='git commit[^|;&]*( -a| --all| -am| -a[a-z])'
if [[ "$COMMAND" == *"git add"* ]] || [[ "$COMMAND" =~ $STAGES_ALL ]]; then
    FILES=$(git status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //')
else
    FILES=$(git diff --cached --name-only)
fi

PROJECT=""
VAULT_TOUCHED=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    if is_vault_content "$f"; then
        VAULT_TOUCHED=1
    elif ! is_method_file "$f"; then
        PROJECT="$PROJECT  $f"$'\n'
    fi
done <<< "$FILES"

[ -z "$PROJECT" ] && exit 0          # nothing outside the vault: no question
[ "$VAULT_TOUCHED" -eq 1 ] && exit 0 # vault content moves with the change

# Trailer present in the commit message given on the command line?
# Own line (heredoc, multi-line -m) or a whole -m argument.
TRAILER_LINE='^[[:space:]]*Vault: (updated|unchanged)[[:space:]]*["'"'"']?[[:space:]]*$'
TRAILER_ARG='-m[[:space:]]+["'"'"']Vault: (updated|unchanged)["'"'"']'
if printf '%s\n' "$COMMAND" | grep -qE "$TRAILER_LINE" || [[ "$COMMAND" =~ $TRAILER_ARG ]]; then
    exit 0
fi
# --amend without a new message: the existing message may already carry it.
if [[ "$COMMAND" == *"--amend"* ]] && [[ "$COMMAND" != *" -m"* ]] && [[ "$COMMAND" != *"-F"* ]] \
   && git log -1 --format=%B 2>/dev/null | grep -qE '^Vault: (updated|unchanged)$'; then
    exit 0
fi

cat >&2 <<MSG
BLOCKED: this commit changes project files but no vault content, and carries no Vault: trailer.

Files outside the vault:
$(printf '%s' "$PROJECT")
Before committing, decide whether the vault still tells the truth:
  1. Open INDEX.md, find the nodes that cover these files.
  2. Reread those nodes and constraints.md. If the change touches a contract,
     a constraint or a decision, edit the node and add a line to DECISIONS.md
     or OPEN.md, then commit with a "Vault: updated" trailer.
  3. If they still hold, say so explicitly with a "Vault: unchanged" trailer.
     It is a claim made after reading, not a default.

Put the trailer on its own line at the end of the message, in a heredoc or -m.
A message read from a file (-F path) is not inspected: use -F - with a heredoc instead.
MSG
exit 2
