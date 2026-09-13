---
title: Decisions
status: draft
priority: 1
depends_on: []
---

# DECISIONS

What was **settled** — in chat or after. Without this page, trade-offs vanish and the agent reopens them.

Format, one line per decision, newest first:

```
- YYYY-MM-DD — Decision. One-sentence rationale. Link to the node if needed.
```

## Log

- 2026-09-13 — **The drift question is not enough: a third mechanism, the sweep question, fires on every commit that moves a settled page.** The hook skipped any commit carrying vault content, on the premise that "the diff is the proof". It proves the page you touched was reconsidered and nothing about the other nineteen — and a decision that changes lands its consequences precisely there. The commit that amends a decision was therefore the one commit that asked nothing. Found the hard way on a real project: a `decided` node still forbade, in writing, the behaviour the code had just adopted, hours after the decision; eleven such gaps in one sweep, including the goal line of `INDEX.md`. A settled page that contradicts the code is not stale, it is an **authorisation to revert**. `claude-pre-commit.sh` now refuses the first attempt when `DECISIONS.md` or a `decided`/`stable` node is staged, and takes `Vault: updated (swept: ...)` naming the pages checked. Trigger kept narrow — `OPEN.md`, drafts and code alone never ask — because a hook that nags gets uninstalled. [[AMEND]] carries the method: grep the **superseded** wording, never the new one. Rejected: extending `CONVERGE` to cover it, which runs at cold-review cadence and reads code — wrong weight, wrong moment, wrong direction.
- 2026-09-11 — The convergence pass ([[CONVERGE]]) is the reverse of the drift question: the drift question asks whether the vault still tells the truth about the code, the pass asks whether the code does everything the vault promises. Adapted from spec-kit's converge, stripped of its CLI and per-feature machinery.
- 2026-09-11 — `missing`/`partial` gaps live in a dated `## Gaps` section of the node concerned — one file = one responsibility, selective loading keeps working. `contradicted` and `uncovered` go to [[OPEN]]: there a decision is owed, not code. All writes append-only.
- 2026-09-11 — Convergence is triggered by hand at cold-review cadence; the hook only **reminds**, non-blocking, past `VAULT_CONVERGE_EVERY` commits (30). Blocking was rejected: a full code↔vault pass is too heavy per commit, and a hook that nags gets uninstalled. `CONVERGE.md` is a pasteable method file like [[COMPILE]] — no slash command, no CLI.
- 2026-09-10 — The hook **offers the vault** in repositories that have none, once, and only past a size threshold (12 commits and 15 tracked files by default). Installed globally it runs everywhere, and staying silent in vaultless repositories meant the method only ever reached projects where someone had already thought of it. The threshold is the point: a vault is friction on a one-shot task, and a hook that nags on throwaway repositories gets uninstalled.
- 2026-09-10 — The decline is remembered in `.git/vault-declined` **with the size at which it was declined**, and the question returns only if the repository triples. A permanent decline taken at 12 commits would be a decision about a different project than the one that exists at 100. `skip (never)` is the explicit escape hatch, so nothing is assumed on the user's behalf; the reason lands in `git log`.
- 2026-09-10 — Registering the hook in both scopes is **not** a defect in itself: its state is a fingerprint it overwrites rather than a token it consumes, so two runs on one command reach the same verdict (verified, all paths). The real hazard is the two registrations pointing at *different versions* — the global scope copies the file and goes stale, the project scope symlinks it and stays current. `install.sh` now checks that instead of claiming "the second run answers a question the agent never saw", which this design no longer does.
- 2026-09-09 — The drift question is asked first, never pre-empted: first commit attempt on code without vault content is refused, the retry must name the pages reread (`Vault: unchanged (reread: ...)`). A trailer written by reflex is worth nothing.
- 2026-09-09 — The Claude Code hook ships in `hooks/` with `install.sh`, project or global scope, Linux and macOS. A drift check that depends on one machine's config is not part of the method.
- 2026-09-09 — Vault integrity is enforced at commit time: `vault-check.sh` for what a script can check, a `Vault: updated|unchanged` commit trailer for what needs judgement. Rules are not enough against drift.
- 2026-09-08 — `depends_on` entries are quoted wikilinks, not paths. Obsidian then shows them in graph and backlinks; agents read both forms.
- 2026-09-08 — README.md absorbs METHODOLOGY.md. One source for the method, no duplicated thesis.
- 2026-09-08 — Source of truth is a Markdown graph (vault), not the transcript, not HTML. See [[README]].
- 2026-09-08 — Agent consumption: index + task nodes only.
