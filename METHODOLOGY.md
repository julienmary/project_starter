---
title: Methodology
status: stable
priority: 0
depends_on: []
---

# Methodology

## Thesis

Conversation explores. The vault freezes.

What works is not "the AI spawning a project." It is the split of roles:

1. **Discussion** — blind spots: constraints, non-goals, dependencies, risks, what you refuse.
2. **Vault** — durable graph, replayable by another agent, and by you in six months.

Without 2, the thread dies. Without 1, the vault is hollow.

## The 4 moves

1. Explore in conversation.
2. Compile under contract (see [[COMPILE]]) — not "make me a vault" alone.
3. Cold review. The first vault is a photograph of the chat: blind spots and overly neat phrasing. Cut decoration. Harden constraints.
4. Execute on *this* graph, not on the transcript. Selective load: [[AGENTS]].

## Compilation contract

- Thin root: [[INDEX]] + [[AGENTS]] — goal, out of scope, hard constraints, how to navigate.
- One file per responsibility, not a monologue sliced into headings.
- Explicit `depends_on` / "read first" links.
- [[DECISIONS]]: what was settled.
- [[OPEN]]: what was not.
- Frontmatter everywhere (`status`, `priority`, `depends_on`).
- Consumption rule: the agent loads only the index and the nodes for the task.

## Two traps

**Novel-vault** — 40 files repeating the same intro. The agent costs more than a good README. Symptom: every node starts with "this project aims to…". Fix: the intro lives in [[nodes/purpose]] only.

**Oracle-vault** — everything looks decided while you only explored. Fix: [[OPEN]]. `status: decided` has to be earned.

## Markdown, not HTML

Links (`[]()`, `[[wikilinks]]`) are enough for the graph. Token savings come from **selective loading**, not from the dialect.

- Source: versioned Markdown.
- HTML: punctual artifact when a *human* must compare, annotate, or browse visually.
- Prezi / mind map: presentation layer.

## Full loop

Talk to discover → compile into a Markdown graph → review → run the execution agent on that graph.

That is the starting prompt. The rest (stack, UI, slides) comes after the graph is stable.
