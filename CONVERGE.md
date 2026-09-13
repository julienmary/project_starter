---
title: Convergence prompt
status: stable
priority: 0
depends_on:
  - "[[README]]"
---

# CONVERGE

Paste this when you want to check the **code against the vault**. It is the reverse of
the two commit-time questions: the drift question asks "does the vault still tell the
truth about the code?", the sweep question ([[AMEND]]) asks "does the rest of the vault
still agree with the decision that just changed?", and this pass asks "does the code do
everything the vault promises?". Run it at the cadence of the cold review, not on every
commit.

---

Assess this repository's code against its vault, under the `project_starter` contract.

This is not "review my code." It is a **convergence pass with a contract**:

1. Build the intent inventory. Read `AGENTS.md`, then `INDEX.md`, then every node whose
   `status` is `decided` or `stable`, plus `DECISIONS.md`. A `draft` or `open` page is
   not a promise: skip it. From these pages, extract the assertions the code can be
   checked against — behaviors, contracts, constraints, refusals.
2. Inspect only the code those assertions concern. Do not widen the scope beyond what
   the vault defines. This is a completeness check, not a code review: style, bugs and
   performance are out of scope unless a node asserts them.
3. Classify every mismatch, traced to the page and the section or decision it comes from:
   - `missing` — promised, absent from the code.
   - `partial` — present, but not fully what the page asserts.
   - `contradicted` — the code does the opposite of a constraint or a decision.
   - `uncovered` — the code does something no node covers. Not a defect of the code:
     the vault lies by omission.
4. Start your reply with the findings table: page, type, gap, evidence (the file or
   area observed). Zero findings: report **Converged**, update the date in step 6,
   change nothing else.
5. Write the findings, **append-only**. Never rewrite, renumber or delete a gap from a
   previous pass.
   - `missing` and `partial`: a dated section at the bottom of the node concerned,
     one line per gap — type, what, where it traces to:

     ```markdown
     ## Gaps (convergence 2026-09-11)

     - [ ] partial — PDF export absent, promised in §Exports
     - [ ] missing — webhook retry, DECISIONS.md 2026-08-02
     ```

   - `contradicted`: a dated line in `OPEN.md`. There is a decision to make — fix the
     code or reopen the decision — and undecided things live in `OPEN.md`, not in a
     silent code fix.
   - `uncovered`: a dated line in `OPEN.md`, or a new node when the responsibility is
     clear. Do not decide in the vault's place.
6. Update the `Last convergence` date in the State section of `INDEX.md`.
7. Do not fix the code in this pass. The pass measures; fixing is a task like any
   other, executed on the graph, one gap at a time.

Afterwards, a gap travels with the commit that fixes it: check it `[x]` in the node's
Gaps section and commit them together under `Vault: updated`. A fully checked Gaps
section is deleted at the next cold review.
