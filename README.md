# project_starter

A file tree to replace the monolithic `PROMPT.md` you get at the end of a brainstorming session with an AI.

## The problem

The usual loop when starting a project with an AI:

1. You explain what you want to achieve.
2. You ask the AI to question you, to explore the details.
3. At the end, the AI writes a synthesis: one `PROMPT.md` describing the project and all its aspects.

That file works as a memory of the discussion. It fails as a working document:

- It is **linear**. Constraints, decisions, open questions and domain details are interleaved in the order they came up, not by responsibility.
- It is **huge**. Every later session loads the whole thing, whatever the task.
- It is **irrelevant to a sub-task**. An agent asked to work on billing has to read the auth section, the UI section and the schedule to find the three lines that concern it.
- It **hides what is still open**. A synthesis reads like a spec. Explored-but-undecided points look settled.

## The answer

Same content, different shape: a small **graph of Markdown files** instead of one long document.

- A thin root (`INDEX.md`) with the goal, the out-of-scope list, the three hardest constraints and a map of the nodes.
- **One file per responsibility** in `nodes/`, with explicit links and a `depends_on` list.
- What was **settled** in `DECISIONS.md`. What was **not** in `OPEN.md`. Never mixed.
- A consumption contract (`AGENTS.md`): an agent loads the index and the nodes for *its* task. Nothing else.

Principle: **conversation explores, the vault freezes.** The discussion is where you force the blind spots (constraints, non-goals, dependencies, risks, refusals). The vault is the durable, replayable result. Without the discussion the vault is a hollow template. Without the vault the discussion dies in the thread.

Token savings come from **selective loading**, not from a clever format. Markdown with links is enough.

## Modus operandi

### 0. Copy the template

```bash
git clone <this-repo> my-project
cd my-project
rm -rf .git
git init
```

### 1. Explore, as usual

Open a session with your AI. Claude Code in the freshly cloned directory works best, because the agent can write the files itself. A web chat works too, with one extra copy step at the end.

Explain the goal. Ask the AI to question you. Push on the things a synthesis tends to smooth over:

- what is **out of scope**
- the **hard constraints** and what you **refuse** to do
- **dependencies** and **risks**
- what was **considered and rejected**, and why

Nothing changes here compared to your habit. The difference is what you ask for at the end.

### 2. Compile instead of asking for a PROMPT.md

At the point where you would ask "write me a PROMPT.md", paste the content of [`COMPILE.md`](COMPILE.md) instead.

It is a compilation **with a contract**. The AI must:

- fill `INDEX.md` (goal in one sentence, out of scope, three hard constraints, node table), under ~80 lines
- fill `nodes/purpose.md` and `nodes/constraints.md`
- create one node per responsibility in `nodes/`, from `nodes/_template.md`, without repeating the project intro in each
- put frontmatter everywhere (`title`, `status`, `priority`, `depends_on`)
- log only what was **settled** in `DECISIONS.md`, with date and rationale
- log everything explored but **not settled** in `OPEN.md`
- invent no stack, schedule or feature absent from the thread
- end with five candidate cuts for the cold review

In Claude Code, the agent writes the files directly. In a web chat, it returns them and you paste each one into place.

### 3. Cold review, the next day

The first vault is a photograph of the chat: neat phrasing, blind spots, points marked decided that were only explored. Review it cold, with the checklist at the bottom of [`COMPILE.md`](COMPILE.md):

- the index fits on one page
- no node repeats the project goal
- every `status: decided` has a line in `DECISIONS.md`
- every blur visible in the chat is in `OPEN.md`
- a task can be executed by loading at most four files

Cut decoration. Harden constraints. Move fake consensus to `OPEN.md`.

### 4. Execute on the graph, not on the transcript

For each later task, the agent reads `AGENTS.md`, then `INDEX.md`, then only the nodes the index lists for that task and their "read first" dependencies. It does not reread the discussion. It does not load the whole vault.

Example. Task: "implement the invoice export". The agent loads:

1. `AGENTS.md`, the contract
2. `INDEX.md`, finds the `billing` node and its "read first" column
3. `nodes/billing.md`
4. `nodes/constraints.md`, listed as read first

Four files. Auth, UI and the rest stay on disk. If a decision is missing, the agent checks `DECISIONS.md`, then `OPEN.md`. It does not invent consensus.

## Tree

```
project_starter/
├── README.md                 # this file, for humans: problem, method, tree
├── AGENTS.md                 # consumption contract for the agent
├── COMPILE.md                # compilation prompt to paste at the end of the discussion
├── INDEX.md                  # thin project map, to fill
├── DECISIONS.md              # what was settled, to fill
├── OPEN.md                   # what is not settled, to fill
├── LICENSE
├── .gitignore
└── nodes/
    ├── _template.md          # node template
    ├── purpose.md            # goal, audience, success, to fill
    └── constraints.md        # hard constraints, refusals, risks, to fill
```

Two kinds of files:

- **Method files**, stable, not meant to change per project: `README.md`, `AGENTS.md`, `COMPILE.md`, `nodes/_template.md`.
- **Project files**, produced by the compilation and refined by the cold review: `INDEX.md`, `DECISIONS.md`, `OPEN.md`, `nodes/purpose.md`, `nodes/constraints.md`, plus every domain node.

Domain nodes (`auth`, `billing`, `ui`...) are **not** in the template. They are born from the discussion. One file = one responsibility.

## Two traps

**Novel-vault.** Forty files that each restart with "this project aims to...". The agent pays more tokens than for a good README. Fix: the intro lives in `nodes/purpose.md` only. Every other node points to it.

**Oracle-vault.** Everything looks decided while you only explored. The agent builds on phantom decisions. Fix: `OPEN.md`. `status: decided` has to be earned by a dated line in `DECISIONS.md`.

## Markdown, not HTML

The source of truth is the versioned Markdown. HTML pages, slides, Prezi, mind maps are a presentation layer for humans who need to browse, compare or annotate. The agent may generate them. It never treats them as spec.

## License

MIT. The method belongs to no one.
