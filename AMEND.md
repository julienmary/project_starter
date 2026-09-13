---
title: Amendment sweep prompt
status: stable
priority: 0
depends_on:
  - "[[README]]"
---

# AMEND

Paste this **right after a settled page changed** — a `decided` or `stable` node, or a new
line in `DECISIONS.md`. It is the third direction, and the shortest.

The drift question asks "does the vault still tell the truth about the code?", and it is
scoped to the files in the commit. `CONVERGE.md` asks "does the code do everything the
vault promises?", and it runs at cold-review cadence. Neither asks **"does the rest of
the vault still agree with the decision that just changed?"** — and the commit that
changes a decision is precisely the one the drift question leaves alone, because a vault
file moved with it.

A settled page that contradicts the code is not merely stale. It is an **authorisation to
revert**: the next agent reads it, finds the change forbidden in writing, and undoes it in
good faith.

---

Sweep this vault for pages that the decision just recorded has made false, under the
`project_starter` contract.

This is not a convergence pass. It reads no code and inspects nothing outside the vault.

1. Name the amendment in one sentence: what the decision now says, and **what it says
   instead of**. The second half is the one that matters — the superseded wording is what
   you are hunting.
2. Grep the vault for the **old** wording, never the new one. The new one is already
   right wherever it appears. Search, at minimum:
   - the phrases the decision replaces, and their synonyms;
   - the constants it moved, in every page that quotes a number;
   - `OPEN.md` entries the decision closes, or whose question it changes;
   - deferral markers — "after v1", "deferred", "not yet", "planned" — for anything now
     delivered;
   - `INDEX.md`'s goal and out-of-scope lines, which outlive everything and are read first;
   - the test matrix, for classes that now exist.
3. Classify what you find, one line each: the page, the sentence, and whether it is
   **contradicted** (says the opposite), **stale** (was true, no longer is), or
   **incomplete** (still true, no longer sufficient).
4. Fix all of them **in one commit**, separate from the code. Each amendment keeps the
   sentence it replaces, dated, in the form the vault already uses:
   *(Amended YYYY-MM-DD: this line said "…".)* A reader must be able to see what changed
   and why without the git history.
5. Contradictions in a `decided` page are fixed, not moved to `OPEN.md`: the decision was
   already taken, the page simply had not heard. Only a contradiction you are **not**
   authorised to resolve goes to `OPEN.md`.
6. Date the sweep in the State section of `INDEX.md`, next to the convergence date. The
   two are not the same measurement and must not share a line.

Report the findings table first: page, type, the sentence as it stood. Zero findings:
report **Coherent**, move the date, change nothing else.
