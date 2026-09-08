# project_starter

Starter template for any **complex project** meant to be explored with an AI, then frozen as a reusable Markdown graph.

Principle: **conversation explores, the vault freezes.**

The AI does not "spawn a project." Two distinct roles:

1. **Discussion** — force the blind spots (constraints, non-goals, dependencies, risks, what you refuse).
2. **Vault** — turn that into a durable graph, replayable by another agent — and by you in six months.

Without step 2, the discussion dies in the thread. Without step 1, the vault is a hollow template.

This repo is the **marble** of the method: minimal tree, agent contracts, decisions / open pages, end-of-discussion compilation.

## Tree

```
project_starter/
├── README.md                 # this file (human)
├── AGENTS.md                 # consumption contract for the agent
├── INDEX.md                  # thin project map
├── DECISIONS.md              # what was decided
├── OPEN.md                 # what is not decided
├── METHODOLOGY.md            # full method
├── COMPILE.md                # compilation prompt "conversation → vault"
├── LICENSE
├── .gitignore
└── nodes/
    ├── _template.md          # node template
    ├── purpose.md            # goal / out of scope (to fill)
    └── constraints.md        # hard constraints (to fill)
```

Domain nodes (`auth`, `billing`, `ui`…) are **not** in the template. They are born from the discussion. One file = one responsibility.

## Start in 4 moves

1. **Explore** — discuss the project (goal, out of scope, constraints, risks, refusals).
2. **Compile** — paste `COMPILE.md` at the end of the thread. Do not ask "make me a vault" with no contract.
3. **Cold review** — cut decoration, harden constraints, fill `OPEN.md` instead of faking consensus.
4. **Execute selectively** — the agent loads `AGENTS.md` + `INDEX.md` + the nodes for *this* task. Not the transcript. Not the whole vault.

HTML / Prezi / visual mind maps = *human presentation* layer, never the source of truth.

## Copy this template

```bash
git clone <this-repo> my-project
cd my-project
rm -rf .git
git init
```

Then replace the `TODO`s in `INDEX.md`, `nodes/purpose.md`, `nodes/constraints.md`.

## License

MIT. The method belongs to no one.
