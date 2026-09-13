---
title: Agent contract
status: stable
priority: 0
depends_on: []
---

# AGENTS.md

Read **this file first**, then [[INDEX]]. Load nothing else until the task is identified.

## Navigation

1. Read `AGENTS.md` + `INDEX.md`.
2. Identify relevant nodes via links and frontmatter `depends_on`.
3. Load **only** those nodes (+ their direct dependencies listed under "read first").
4. Do not dump the vault. Do not reread the design transcript.
5. If a decision is missing: check [[DECISIONS]] then [[OPEN]]. Do not invent consensus.

## Source of truth

- The `.md` files in this repo.
- `DECISIONS.md` beats an "obvious" reading of the chat.
- `OPEN.md` beats any urge to close too early.

HTML, slides, mockups = derived artifacts. You may *generate* them. You do not *treat* them as spec.

## Writing

- One file = one responsibility. Not a monologue sliced into headings.
- Frontmatter required: `title`, `status`, `priority`, `depends_on` (list, may be empty).
- `depends_on` entries are quoted wikilinks: `- "[[nodes/purpose]]"`. Plain paths are not links for Obsidian and stay out of the graph.
- `status` ∈ `draft | open | decided | stable | deprecated`.
- Markdown links or wikilinks to neighboring nodes. No copy-paste of the same paragraph.
- If you create a node: start from `nodes/_template.md`.
- If you settle something: one line in [[DECISIONS]], date + short rationale.
- If you find a hole: one line in [[OPEN]], not a phantom decision.

## Committing

- Run `./vault-check.sh` before committing. A failing check is a problem to fix in the vault, not to bypass.
- A commit that changes code without vault content is refused once and the question is put to you: does the vault still tell the truth? Do not pre-empt it with a trailer; read first.
- Answer on the retry, on its own line: `Vault: unchanged (reread: nodes/x, nodes/y)`, naming the pages you actually reread. Or edit the node, [[DECISIONS]] or [[OPEN]], commit them with the code, and mark it `Vault: updated`.
- A commit that stages [[DECISIONS]] or a node whose `status` is `decided` or `stable` is refused once too, on a different question: does the **rest of the vault** still agree with the decision you just changed? Answer on the retry with `Vault: updated (swept: INDEX, nodes/purpose, OPEN)`, naming the pages you checked against it. [[AMEND]] is the method — grep the wording the decision **replaces**, never the new one. A settled page that contradicts the code is not stale, it is an authorisation to revert.
- If your change closes a gap listed in a node's `## Gaps` section (written by [[CONVERGE]]): check it `[x]` in that node and commit them together under `Vault: updated`. Do not add gaps outside a convergence pass; a hole found while working goes to [[OPEN]].
- What you name after `reread:` is a claim in the history. Name only what you read.

## Forbidden

- Novel-vault: repeating the project intro in every node.
- Oracle-vault: marking everything `decided` while it is still exploratory.
- Loading the whole graph "just in case."
- Replacing Markdown source with HTML.
