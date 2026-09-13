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
#      That question checks one direction only. The reverse - does the code do
#      everything the vault promises - is CONVERGE.md, run by hand at cold-review
#      cadence. This hook merely reminds, without ever refusing: when the "Last
#      convergence" date in INDEX.md is more than VAULT_CONVERGE_EVERY commits
#      old (30 by default), a non-blocking note is shown, at most once per that
#      many commits. VAULT_CONVERGE=0 turns it off.
#
#   3. Whether this project should have a vault at all. Installed globally, this
#      hook also runs in repositories that have none. Staying silent there means
#      the method only ever reaches projects where someone already thought of it.
#      So when a repository without a vault has grown past a threshold
#      (VAULT_OFFER_MIN_COMMITS commits and VAULT_OFFER_MIN_FILES tracked files,
#      12 and 15 by default), the question is put once:
#
#         Vault: adopting            setting one up now
#         Vault: skip (one-shot)     not that kind of project
#         Vault: skip (never)        never ask again in this clone
#
#      Below the threshold it says nothing: a vault is friction on a one-shot
#      task, and a hook that nags on throwaway repositories gets uninstalled.
#      The answer is remembered in .git/vault-declined, with the size at which
#      it was declined - the question returns only if the repository triples,
#      which is the "it grew into a real project after all" case. VAULT_OFFER=0
#      turns it off entirely.
#
#   As a side benefit it also refuses a commit while a tracked file matches
#   .gitignore, which is how private files leak into public repos.
#
# HOW IT RUNS
#
#   Claude Code calls it as a PreToolUse hook on the Bash tool, with a JSON object
#   on stdin. Only commands containing "git commit" are inspected. Exit 2 blocks
#   the command and hands stderr back to the agent, which then fixes the vault or
#   writes the trailer. A repository without a vault-check.sh at its root gets the
#   .gitignore check and, past the size threshold, the question in point 3.
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
# 2. No vault here: offer one, once, and only when the project deserves it
#
#    A vault earns its cost on a project that accumulates decisions. On a
#    one-shot task it is pure friction, and a hook that nags on every throwaway
#    repository gets uninstalled. So the question is put only when the
#    repository has visible substance, it is asked once, and the answer is
#    remembered in .git/ (a local decision, not something to commit).
#
#    Tunable: VAULT_OFFER=0 disables it, VAULT_OFFER_MIN_COMMITS and
#    VAULT_OFFER_MIN_FILES move the threshold, VAULT_STARTER points at the
#    method directory.
# ---------------------------------------------------------------------------
if [ ! -x "$TOP/vault-check.sh" ]; then
    [ "${VAULT_OFFER:-1}" = "0" ] && exit 0

    MIN_COMMITS=${VAULT_OFFER_MIN_COMMITS:-12}
    MIN_FILES=${VAULT_OFFER_MIN_FILES:-15}
    COMMITS=$(git rev-list --count HEAD 2>/dev/null) || COMMITS=0
    FILES=$(( $(git ls-files 2>/dev/null | wc -l) ))   # $(( )) strips BSD wc padding

    # Below the threshold this is a one-shot task. Say nothing.
    [ "${COMMITS:-0}" -lt "$MIN_COMMITS" ] && exit 0
    [ "$FILES" -lt "$MIN_FILES" ] && exit 0

    # Already answered? "never" is final; a number is the size at which it was
    # declined, and the question comes back only if the project has since
    # tripled - that is the "it grew into a real project after all" case.
    DECLINED="$(git rev-parse --git-dir)/vault-declined"
    if [ -f "$DECLINED" ]; then
        WAS=$(cat "$DECLINED" 2>/dev/null)
        [ "$WAS" = "never" ] && exit 0
        case "$WAS" in
            ''|*[!0-9]*) WAS=$COMMITS ;;                       # unreadable: treat as now
        esac
        [ "$COMMITS" -lt $((WAS * 3)) ] && exit 0
    fi

    # The answer, same trailer namespace as the drift question.
    OQ='["'"'"']'
    OT='(adopting|skip \([^)]+\))'
    ANSWER=$(printf '%s\n' "$COMMAND" | sed -nE "s/^[[:space:]]*Vault: $OT[[:space:]]*$OQ?[[:space:]]*\$/\1/p" | head -n1)
    [ -z "$ANSWER" ] && ANSWER=$(printf '%s\n' "$COMMAND" | sed -nE "s/.*-m[[:space:]]+${OQ}Vault: $OT$OQ.*/\1/p" | head -n1)

    case "$ANSWER" in
        adopting)
            exit 0 ;;                    # let it through; asked again until the vault exists
        "skip (never)")
            printf 'never\n' > "$DECLINED"; exit 0 ;;
        "skip ("*)
            printf '%s\n' "$COMMITS" > "$DECLINED"; exit 0 ;;
    esac

    STARTER=${VAULT_STARTER:-$HOME/share/project_starter}
    if [ -d "$STARTER" ]; then
        HOW="  cp -r $STARTER/{AGENTS.md,COMPILE.md,CONVERGE.md,INDEX.md,DECISIONS.md,OPEN.md,nodes,hooks,vault-check.sh,install.sh} .
  then follow COMPILE.md to compile this project's design into the nodes,
  and run ./install.sh last (it wires this hook, which would otherwise refuse
  the vault's own first commits)."
    else
        HOW="  the project_starter method directory was not found; set VAULT_STARTER to it."
    fi

    cat >&2 <<MSG
BLOCKED once: this repository has $COMMITS commits and $FILES tracked files, and no
vault. At this size the design decisions exist somewhere - a thread, a README, your
head - and nothing keeps them true. Is this project worth one?

A vault is worth it when the project accumulates decisions that a later agent must
not reopen. It is not worth it for a one-shot task.

Answer on its own line at the end of the commit message:

  Vault: adopting                 you are setting one up now; this commit passes and
                                  the question returns until vault-check.sh exists
  Vault: skip (one-shot)          not that kind of project. Remembered; asked again
                                  only if the repository triples in size
  Vault: skip (never)             never ask again in this clone

Any reason works in the parentheses; it lands in git log, so the choice stays
auditable.

To set one up:
$HOW
MSG
    exit 2
fi

# 2a. Mechanical checks
if ! CHECK=$("$TOP/vault-check.sh" 2>&1); then
    {
        echo "BLOCKED: vault-check.sh failed. Fix the vault, do not bypass it."
        printf '%s\n' "$CHECK"
    } >&2
    exit 2
fi

# 2b. Convergence reminder, non-blocking
#
#     The drift question checks one direction: the vault still tells the truth
#     about the code. CONVERGE.md checks the other: the code does everything the
#     vault promises. Nothing forces that pass to run, so this reminds - it never
#     refuses. When a commit carrying project code goes through and the "Last
#     convergence" date in INDEX.md is more than VAULT_CONVERGE_EVERY commits old
#     (30 by default), a message is shown to the user, at most once per
#     VAULT_CONVERGE_EVERY commits (.git/vault-converge-reminded keeps the pace).
#     VAULT_CONVERGE=0 turns it off.
converge_reminder() {
    [ "${VAULT_CONVERGE:-1}" = "0" ] && return 0
    local every commits since last pace was
    every=${VAULT_CONVERGE_EVERY:-30}
    commits=$(git rev-list --count HEAD 2>/dev/null) || return 0
    last=$(sed -nE 's/^- *Last convergence: *([0-9]{4}-[0-9]{2}-[0-9]{2}).*$/\1/p' INDEX.md 2>/dev/null | head -n1)
    if [ -n "$last" ]; then
        since=$(git rev-list --count --since="$last 00:00" HEAD 2>/dev/null) || return 0
    else
        since=$commits            # no dated pass yet: the whole history is unconverged
    fi
    [ "$since" -lt "$every" ] && return 0
    pace="$(git rev-parse --git-dir)/vault-converge-reminded"
    if [ -f "$pace" ]; then
        was=$(cat "$pace" 2>/dev/null)
        case "$was" in ''|*[!0-9]*) was=0 ;; esac
        [ $((commits - was)) -lt "$every" ] && return 0
    fi
    printf '%s\n' "$commits" > "$pace"
    printf '{"systemMessage":"vault: %s commits since the last convergence pass. Paste CONVERGE.md to check the code against what the vault promises (VAULT_CONVERGE=0 silences this)."}\n' "$since"
    return 0
}

# 2c. Drift question
# Files the template ships. Content pages count as "vault updated"; method
# files count as neither vault content nor project code.
is_vault_content() { [[ "$1" =~ ^(INDEX\.md|DECISIONS\.md|OPEN\.md|nodes/.+\.md)$ ]]; }
is_method_file()   { [[ "$1" =~ ^(README\.md|AGENTS\.md|COMPILE\.md|CONVERGE\.md|AMEND\.md|LICENSE|\.gitignore|vault-check\.sh|install\.sh|hooks/.*|\.claude/.*)$ ]]; }

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

# Which of the staged vault files are **contracts**: DECISIONS.md, or a node whose staged
# content declares `status: decided` or `status: stable`. A draft promises nothing, and
# OPEN.md is where undecided things are supposed to live — neither can be contradicted.
CONTRACTS=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_vault_content "$f" || continue
    case "$f" in
        DECISIONS.md) CONTRACTS="$CONTRACTS$f"$'\n'; continue ;;
        nodes/*) ;;
        *) continue ;;
    esac
    if [ "$STAGE_MODE" = "index" ]; then
        HEAD_OF=$(git show ":$f" 2>/dev/null | head -n 12)
    else
        HEAD_OF=$(head -n 12 -- "$f" 2>/dev/null)
    fi
    printf '%s\n' "$HEAD_OF" | grep -qE '^status: (decided|stable)[[:space:]]*$' \
        && CONTRACTS="$CONTRACTS$f"$'\n'
done <<< "$FILES"
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
    done <<< "$1" | git hash-object --stdin
}
# The answer: a "Vault: ..." trailer in the message. Own line (heredoc,
# multi-line -m), a whole -m argument, or the previous message on --amend
# without a new one.
Q='["'"'"']'
T='(updated( \(swept: [^)]+\))?|unchanged( \(reread: [^)]+\))?)'
TRAILER=$(printf '%s\n' "$COMMAND" | sed -nE "s/^[[:space:]]*Vault: $T[[:space:]]*$Q?[[:space:]]*\$/\1/p" | head -n1)
[ -z "$TRAILER" ] && TRAILER=$(printf '%s\n' "$COMMAND" | sed -nE "s/.*-m[[:space:]]+${Q}Vault: $T$Q.*/\1/p" | head -n1)
if [ -z "$TRAILER" ] && [[ "$COMMAND" == *"--amend"* ]] && [[ "$COMMAND" != *" -m"* ]] && [[ "$COMMAND" != *"-F"* ]]; then
    TRAILER=$(git log -1 --format=%B 2>/dev/null | sed -nE "s/^Vault: $T\$/\1/p" | head -n1)
fi

# The sweep question, on every commit that moves a contract page.
#
# The drift question below is scoped to the files in the commit, and it is skipped
# entirely when vault content moves with them — "the diff is the proof". That is true of
# the page you touched and false of every other one: a decision that changes lands its
# consequences elsewhere, in the pages nobody opened. The commit that changes a decision
# is therefore precisely the one the drift question leaves alone. A settled page that
# contradicts the code is not merely stale, it is an authorisation to revert: the next
# agent reads it, finds the change forbidden in writing, and undoes it in good faith.
#
# Narrow on purpose. Only `decided`/`stable` nodes and DECISIONS.md trigger it; a commit
# that only moves OPEN.md, a draft or code is never asked. A hook that nags gets
# uninstalled, and this one has one question to spend.
if [ -n "$CONTRACTS" ]; then
    SFP=$(fingerprint "$CONTRACTS")
    SSTATE="$(git rev-parse --git-dir)/vault-sweep"
    SASKED=0
    [ -f "$SSTATE" ] && [ "$(cat "$SSTATE")" = "$SFP" ] && SASKED=1
    SREASON=""
    if [ "$SASKED" -eq 1 ]; then
        case "$TRAILER" in
            "updated (swept: "*)
                SLIST=${TRAILER#updated (swept: }; SLIST=${SLIST%)}
                IFS=',' read -r -a SPAGES <<< "$SLIST"
                for pg in "${SPAGES[@]}"; do
                    pg=$(printf '%s' "$pg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
                    case "$pg" in *.md) ;; *) pg="$pg.md" ;; esac
                    [ -f "$pg" ] || SREASON="$SREASON  '$pg' is not a page of this vault"$'\n'
                done
                if [ -z "$SREASON" ]; then
                    printf '%s' "$SFP" > "$SSTATE"
                    converge_reminder
                    exit 0
                fi ;;
            updated)
                SREASON="  'Vault: updated' does not say what else was checked against this change"$'\n' ;;
        esac
    fi
    printf '%s' "$SFP" > "$SSTATE"
    cat >&2 <<MSG
BLOCKED: this commit changes a settled page. Does the rest of the vault still agree with it?

Contract pages in this commit:
$(printf '%s' "$CONTRACTS" | sed 's/^/  /')
Sweep before committing (AMEND.md has the full method):
  1. Say in one sentence what the decision now asserts, and what it asserts **instead of**.
  2. Grep the vault for the **superseded** wording, never the new one: the phrases it
     replaces, the constants it moves, the OPEN.md entries it closes, deferral markers
     ("after v1", "deferred") for anything now delivered, INDEX.md's goal and out-of-scope
     lines, and the test matrix.
  3. Fix every page it made false, in this commit, keeping the replaced sentence dated:
     *(Amended YYYY-MM-DD: this line said "...".)*
  4. Commit again and answer on its own line:
       Vault: updated (swept: INDEX, nodes/purpose, OPEN)
     naming the pages you checked. A bare "Vault: updated" is refused here.
$(printf '%s' "$SREASON")
MSG
    exit 2
fi

[ -z "$PROJECT" ] && exit 0          # nothing outside the vault: no question
if [ "$VAULT_TOUCHED" -eq 1 ]; then  # vault content moves with the change
    converge_reminder
    exit 0
fi
FP=$(fingerprint "$PROJECT")
STATE="$(git rev-parse --git-dir)/vault-question"
ASKED=0
[ -f "$STATE" ] && [ "$(cat "$STATE")" = "$FP" ] && ASKED=1


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
            if [ -z "$REASON" ]; then
                converge_reminder
                exit 0
            fi ;;
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
