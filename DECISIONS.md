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

- 2026-09-09 — The Claude Code hook ships in `hooks/` with `install.sh`, project or global scope, Linux and macOS. A drift check that depends on one machine's config is not part of the method.
- 2026-09-09 — Vault integrity is enforced at commit time: `vault-check.sh` for what a script can check, a `Vault: updated|unchanged` commit trailer for what needs judgement. Rules are not enough against drift.
- 2026-09-08 — `depends_on` entries are quoted wikilinks, not paths. Obsidian then shows them in graph and backlinks; agents read both forms.
- 2026-09-08 — README.md absorbs METHODOLOGY.md. One source for the method, no duplicated thesis.
- 2026-09-08 — Source of truth is a Markdown graph (vault), not the transcript, not HTML. See [[README]].
- 2026-09-08 — Agent consumption: index + task nodes only.
