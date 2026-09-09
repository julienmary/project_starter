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
#      This hook asks, and it asks first. When a commit touches project files but
#      no vault content (INDEX.md, DECISIONS.md, OPEN.md, nodes/), the first
#      attempt is refused whatever the message says, and the question is put to
#      the agent. A second attempt on the same change is accepted only if the
#      message answers on its own line:
#
#         Vault: unchanged (reread: nodes/billing, nodes/constraints)
#
#      naming the vault pages that were reread and still hold. A bare
#      "Vault: unchanged" is refused: the answer has to say what was read.
#      "Vault: updated" is for commits where a node, DECISIONS.md or OPEN.md
#      moves with the code; those pass without being asked, the diff is the proof.
#
#      The question is remembered in .git/vault-question as a fingerprint of the
#      project files about to be committed. Change the code again and the
#      question is asked again. The trailer ends up in git log, so the claim
#      and what it says was reread stay auditable.
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
# a false positive only asks the question.
STAGES_ALL='git commit[^|;&]*( -a| --all| -am| -a[a-z])'
STAGE_MODE="index"
if [[ "$COMMAND" == *"git add"* ]] || [[ "$COMMAND" =~ $STAGES_ALL ]]; then
    STAGE_MODE="worktree"
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
        PROJECT="$PROJECT$f"$'\n'
    fi
done <<< "$FILES"

[ -z "$PROJECT" ] && exit 0          # nothing outside the vault: no question
[ "$VAULT_TOUCHED" -eq 1 ] && exit 0 # vault content moves with the change

# Fingerprint of the project change about to be committed: path + blob id of
# what will be committed. Same fingerprint on the retry = same question.
fingerprint() {
    local f blob
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if [ "$STAGE_MODE" = "index" ]; then
            blob=$(git ls-files -s -- "$f" | cut -d' ' -f2)
        elif [ -f "$f" ]; then
            blob=$(git hash-object -- "$f")
        else
            blob="deleted"
        fi
        printf '%s %s\n' "$f" "${blob:-deleted}"
    done <<< "$PROJECT" | git hash-object --stdin
}
FP=$(fingerprint)
STATE="$(git rev-parse --git-dir)/vault-question"
ASKED=0
[ -f "$STATE" ] && [ "$(cat "$STATE")" = "$FP" ] && ASKED=1

# The answer: a "Vault: ..." trailer in the message. Own line (heredoc,
# multi-line -m), a whole -m argument, or the previous message on --amend
# without a new one.
Q='["'"'"']'
T='(updated|unchanged( \(reread: [^)]+\))?)'
TRAILER=$(printf '%s\n' "$COMMAND" | sed -nE "s/^[[:space:]]*Vault: $T[[:space:]]*$Q?[[:space:]]*\$/\1/p" | head -n1)
[ -z "$TRAILER" ] && TRAILER=$(printf '%s\n' "$COMMAND" | sed -nE "s/.*-m[[:space:]]+${Q}Vault: $T$Q.*/\1/p" | head -n1)
if [ -z "$TRAILER" ] && [[ "$COMMAND" == *"--amend"* ]] && [[ "$COMMAND" != *" -m"* ]] && [[ "$COMMAND" != *"-F"* ]]; then
    TRAILER=$(git log -1 --format=%B 2>/dev/null | sed -nE "s/^Vault: $T\$/\1/p" | head -n1)
fi

# Validate the answer. Only "unchanged (reread: ...)" with existing pages is a
# valid answer here: "updated" without vault content in the commit is a lie.
REASON=""
if [ "$ASKED" -eq 1 ]; then
    case "$TRAILER" in
        "unchanged (reread: "*)
            LIST=${TRAILER#unchanged (reread: }; LIST=${LIST%)}
            IFS=',' read -r -a PAGES <<< "$LIST"
            for pg in "${PAGES[@]}"; do
                pg=$(printf '%s' "$pg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
                case "$pg" in *.md) ;; *) pg="$pg.md" ;; esac
                [ -f "$pg" ] || REASON="$REASON  '$pg' is not a page of this vault"$'\n'
            done
            [ -z "$REASON" ] && exit 0 ;;
        unchanged)
            REASON="  'Vault: unchanged' must say what was reread: Vault: unchanged (reread: nodes/x, nodes/y)"$'\n' ;;
        updated)
            REASON="  'Vault: updated' but this commit carries no change to INDEX.md, DECISIONS.md, OPEN.md or nodes/"$'\n' ;;
    esac
fi

printf '%s' "$FP" > "$STATE"
NODES=$(grep -oE '\[\[nodes/[^]|#]+' INDEX.md 2>/dev/null | sed 's/^\[\[//' | sort -u | sed 's/^/  /')
[ -z "$NODES" ] && NODES="  (INDEX.md maps no domain node yet)"

# An answer that is present but wrong gets the reason. No answer at all gets the
# full question again, even if it was already asked: the agent may not have seen
# it (two registrations of this hook, a lost message).
if [ "$ASKED" -eq 1 ] && [ -n "$TRAILER" ]; then
    cat >&2 <<MSG
BLOCKED: the vault question was asked for this change and the answer is not valid.
$(printf '%s' "$REASON")
Answer on its own line at the end of the commit message:
  Vault: unchanged (reread: nodes/x, nodes/y)   pages you reread, paths relative to the repo root
or edit the vault (a node, DECISIONS.md or OPEN.md) and commit it with the code under "Vault: updated".
MSG
else
    cat >&2 <<MSG
BLOCKED: this commit changes project files but no vault content. Does the vault still tell the truth?

Files outside the vault:
$(printf '%s' "$PROJECT" | sed 's/^/  /')
Nodes mapped in INDEX.md:
$NODES
Before committing:
  1. Find in INDEX.md the nodes that cover these files. Reread them and nodes/constraints.md.
  2. If the change touches a contract, a constraint or a decision: edit the node, add a
     line to DECISIONS.md or OPEN.md, commit them with the code under "Vault: updated".
  3. If they still hold, commit again with the same change and answer on its own line:
       Vault: unchanged (reread: nodes/x, nodes/y)
     naming the pages you reread. A bare "Vault: unchanged" is refused.
  4. No node covers these files? That is a hole: add it to OPEN.md or create the node.

A message read from a file (-F path) is not inspected: use -F - with a heredoc, or -m.
MSG
fi
exit 2
