---
title: Compilation prompt
status: stable
priority: 0
depends_on:
  - "[[README]]"
---

# COMPILE

Paste this **at the end of a discussion**, once the project has been explored enough. Adapt the first paragraph to the actual thread.

---

Compile this conversation into a Markdown vault, under the `project_starter` contract.

This is not "make me a vault." It is a **compilation with a contract**:

1. Fill `INDEX.md` (goal in one sentence, out of scope, 3 hard constraints, node table). Do not exceed ~80 lines.
2. Fill `nodes/purpose.md` and `nodes/constraints.md`.
3. Create **one file per responsibility** in `nodes/`, from `nodes/_template.md`. No monologue sliced into headings. Do not repeat the project intro in every node.
4. Frontmatter everywhere: `title`, `status`, `priority`, `depends_on`. Entries of `depends_on` are quoted wikilinks (`- "[[nodes/purpose]]"`).
5. Explicit links between nodes (`[]()` or `[[wikilinks]]`) + a "read first" column in the index.
6. `DECISIONS.md`: only what was **settled** in this thread, date + one-sentence rationale.
7. `OPEN.md`: everything that was explored but not settled. Do not close items to look tidy.
8. Do not invent a stack, a schedule, or features absent from the thread. If you must assume, put it in `OPEN.md`, not in `DECISIONS.md`.
9. Start your reply with the tree you produced.
10. After generation: list 5 possible cuts for the cold review (decoration, duplicates, soft constraints).

Future consumption rule (already in `AGENTS.md`, also apply it during compilation): a later agent will load only the index + the nodes for its task.

---

## Cold review (human, next day)

Checklist:

- [ ] The index fits on one page.
- [ ] No node repeats the project goal.
- [ ] Every `status: decided` has a line in `DECISIONS.md`.
- [ ] Every blur visible in the chat is in `OPEN.md`.
- [ ] A task can be executed by loading ≤ 4 files.
