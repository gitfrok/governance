# ADR-0058: Adopt Woodpecker's pipeline format — the syntax, not the engine

- **Status:** Accepted
- **Date:** 2026-08-14
- **Governs:** G1 isolation, G3 supply chain, G4 change governance, G8 footprint
- **Relates to:** ADR-0005 (ephemeral sandbox per job) · ADR-0012 (gVisor via `RuntimeClass`) ·
  ADR-0022 (bounded contexts) · ADR-0025/0026 (modular monolith, extraction triggers) ·
  ADR-0034/0035/0036 (image pinning and supply chain) · ADR-0039 (no vendored third-party code) ·
  ADR-0040 (Apache-2.0 across the tree) · SPEC-0010 (CI ephemeral isolation) ·
  SPEC-0020 (CI job contract) · T-0017 (CI v0, Done)

## Context

The request was to use **Woodpecker CI** as the main CI/CD engine. Woodpecker is an Apache-2.0
CI/CD system with a server/agent architecture, Docker, Kubernetes, local and dummy execution
backends, and forge integrations for GitHub, GitLab, Gitea, Forgejo and Bitbucket, plus an
experimental **addon** seam for custom forges.

Four integration shapes were considered — a forge addon, a headless executor behind our contract, a
Go library inside `modules/ci`, and the pipeline format alone. **The format was chosen.** This ADR
therefore records a narrower decision than the request's wording, and says so plainly: under this
decision Woodpecker is **not** the engine, is not deployed, and is not a dependency. What is adopted
is its **pipeline language**.

The engine remains the one T-0017 shipped: a tenant-scoped queue, a KEDA-scaled dispatcher, and an
ephemeral Kubernetes Job per attempt under a gVisor `RuntimeClass`, gated by the PDP and evidenced in
the audit chain. ADR-0005 and ADR-0012 are **not superseded** — they fix isolation requirements that
any engine must meet, and ours already does.

What the format buys is **portability for tenants**: a team arriving from a Woodpecker or Drone-shaped
pipeline brings its file rather than rewriting it. What it does not buy is execution capability —
matrix expansion, plugins, services and caches remain features this platform must implement itself
before it can honour the syntax that describes them.

The relevant verified facts: Woodpecker's code is **Apache-2.0** (ADR-0040 clear); its documentation
is **CC-BY-SA 4.0**, which is why this decision implements the format and does not copy its docs; and
its Kubernetes backend exposes `runtimeClassName`, which matters only if a later ADR revisits the
engine choice.

## Decision

### 1. Tenant pipelines are declared in Woodpecker's pipeline format

The tenant-facing pipeline file adopts Woodpecker's YAML syntax and file conventions. This replaces
SPEC-0020's `.gitfrok/ci.yaml`, whose v0 shape is one image reference and one argv command.

Because SPEC-0010 and SPEC-0020 are **Approved**, this is an **amendment to both**, not an
implementation detail. The amendment — and the task that implements it — are follow-ups this ADR
requires and does not perform.

### 2. A declared supported subset, and explicit rejection outside it

The platform supports a **named subset** of the format, published per construct. Anything outside it
is a **hard error at parse time**, reported to the tenant with the construct and its position.

**No unsupported construct is ever silently ignored.** A skipped `when` clause runs a step that
should not have run; an ignored `secrets` block runs a build that believes it is authenticated; a
dropped `depends_on` runs steps out of order. Silence turns an unimplemented feature into a
security defect, so the parser fails closed.

The subset is versioned against a **pinned upstream syntax version**. Upstream evolution does not
silently widen or narrow what this platform accepts.

### 3. The execution model is unchanged, and the format does not extend it

Adopting the syntax grants no execution capability the platform has not separately built and
specified. In particular, and regardless of what a file may express:

- **One ephemeral sandbox per attempt, destroyed after it** (ADR-0005); no two tenants ever share a
  sandbox; a job or attempt is never reused.
- **gVisor `RuntimeClass`** is the isolation default (ADR-0012), and the dev cluster's inability to
  provide one under rootless podman remains T-0017's recorded host limit, not a waiver.
- **Every step image is a pinned, resolvable reference** under ADR-0034/0035/0036. A "plugin" in this
  format is an image, so plugin use is image supply chain, with no implied ecosystem, registry or
  marketplace.
- **Still out of scope**, exactly as SPEC-0020 has it: privileged builds, host networking, Docker
  socket access, external runner registration, secrets injection, and cache/artifact products. Each
  needs its own spec before its syntax is accepted.
- **The file is read at the immutable commit** recorded at enqueue, never at a mutable ref.

### 4. What is not adopted

No Woodpecker server, agent, database, web UI, forge integration or addon is deployed, and no
Woodpecker package enters `go.mod`. The platform's CI surface stays on the unified surface ADR-0015
fixes, and its footprint gains no pod — which matters under BYO (G8, ADR-0026).

The claim the platform may make is **"Woodpecker-compatible pipeline format, subset published"**. It
may not claim to run Woodpecker, or to be compatible with any construct outside the declared subset.

## Consequences

**Positive:** tenants migrating from Woodpecker, and to a lesser extent from Drone-shaped CI, bring
their pipelines rather than rewriting them — a real adoption lever for the price of a parser. Nothing
about isolation, tenancy, the PDP gate or the audit chain changes, because the engine does not
change. No new pod, no new dependency, no new operational surface, and no experimental upstream API
in the critical path.

**Negative:** the platform inherits a syntax whose surface is far wider than its capability, and the
gap is now visible to every tenant who writes a file. Each unsupported construct is a rejection a
user experiences as a limitation rather than a design choice, and each one is a standing invitation
to implement a feature this platform has not specified. Compatibility is also a claim customers will
test at the edges; a published per-construct subset is the only honest way to make it, and keeping
that document true as upstream moves is ongoing work rather than a one-off.

**Also:** SPEC-0010 and SPEC-0020 are Approved and now need amendment, which is the first real cost of
this decision. And the request that prompted this ADR asked for an engine; a later decision to adopt
Woodpecker's engine — as a headless executor or as a Go library inside `modules/ci` — remains open and
is **not** foreclosed by this one. The format is the compatible half of that path.

## Alternatives considered

- **Headless executor behind our contract.** Woodpecker deployed internally, jobs pushed to it,
  its UI and forge sync never exposed, tenancy enforced at our boundary. Buys the real engine —
  matrix, plugins, services — at the cost of a second queue, a second scaling story (there is no
  native KEDA scaler for its queue, so ADR-0005's scale-to-zero would need re-proving), and more
  pods per BYO install. Rejected now, viable later.
- **Go library inside `modules/ci`.** Import its pipeline compiler and Kubernetes backend as a
  `go.mod` dependency — permitted by ADR-0039, since a dependency is not vendored code — keeping our
  dispatcher, contract, PDP path and KEDA scaling. Smallest blast radius of the engine options, but
  it makes us the integrator of an upstream internal API. Rejected now.
- **Forge addon — gitfrok as a Woodpecker forge.** The fullest integration and the worst fit: the
  addon seam is documented as experimental and able to "change and break at any time", Woodpecker's
  data model keys repositories and users to a single forge with no tenant concept (G1, ADR-0003), and
  its web UI collides with ADR-0015's unified surface. Rejected.
- **Keep `.gitfrok/ci.yaml`.** Costs nothing and stays exactly as capable as the platform is, but
  every arriving team rewrites its pipelines. Rejected in favour of portability.
