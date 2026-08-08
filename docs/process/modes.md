# Modes — session-scoped emphasis

SPEC-0012. A mode says what to look at first. **A mode never changes a requirement.**

That sentence is the whole design. Ceremony tiers (`full`, `quick`, `bugfix`) change what a change
must satisfy and are therefore checked by `scripts/check-ceremony-tier.sh`. Modes change nothing, so
no gate reads this file, no PR declares a mode, and nothing here can waive a spec, a test, or an
invariant. If a mode ever needs to change what is required, it has stopped being a mode and needs
SPEC-0012 amended.

Announce one at the start of a session — "working in security mode on T-0014" — or don't. The cost
of being wrong is zero, which is the point.

| Mode | Look at first |
|---|---|
| **development** | The default. The task's spec and its acceptance criteria; the invariants its diff could plausibly touch. |
| **security** | Invariants 1–10 before the code. Tenant scoping and RLS together, the PDP path, audit emission, what crosses the agent↔CP stream. Threat-model the change before improving it. |
| **performance** | Measure before changing. What the benchmark actually says, not what the code looks like it does — T-0007 exists because SeaweedFS-FUSE looked fine until `rename()` was tested under concurrent readers. |
| **refactoring** | Behaviour preservation. The tests that exist before you start, and whether they would fail if the refactor were wrong. A refactor no test constrains is a rewrite. |
| **debugging** | One hypothesis at a time, each with a way to be wrong. Reproduce before fixing; a defect you cannot reproduce is a defect you cannot verify fixed. |
| **documentation** | Read the thing before describing it, and run the commands the doc tells a reader to run. Instructions that do not work are the defect — the dev DNS setup forwarded to nothing for three tasks because nobody followed the written steps on a clean machine. |
| **migration** | Both sides at once: what reads the old shape while the new one is being written. Additive first, cut over second, remove last — the order `contracts/` already requires within v1. |

## Why this is prose and not configuration

Modes were the part of the original proposal most likely to become a settings file with a schema and
a loader. They earn nothing from that. What an agent emphasises is a prompt-level concern, and the
moment it is enforced it becomes a tier — with the entry conditions, the security floor, and the
gate that tiers require. Keeping the two apart is what lets modes stay free.
