# ADR-0041: Git HTTP and SSH front doors terminate in the data plane

- **Status:** Proposed
- **Date:** 2026-08-09
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege, G9 least-privilege footprint
- **Relates to:** ADR-0004 (Git-RPC storage tier), ADR-0006 (PDP), ADR-0022 (process boundaries),
  ADR-0025 (one binary per plane), SPEC-0004, SPEC-0006 · **Tasks:** T-0011, T-0013

## Context

SPEC-0004 requires Smart-HTTP and SSH clients to authenticate, resolve a tenant and repository, and
route the unmodified Git protocol to `GitStorage`. T-0010 supplied that internal RPC, but it
intentionally accepts no credential or caller path. The public protocol boundary still needs a
single answer to three coupled questions: where the listeners run, what code is allowed to turn a
credential into an operation context, and whether a front door may ever bypass `git-storaged` to
touch repository storage.

Creating a separate `git-http` or `git-ssh` service would contradict ADR-0025's one-binary-per-plane
rule before an ADR-0026 extraction trigger is met. Letting an HTTP handler or an SSH forced command
invoke Git plumbing against a path would defeat ADR-0004's storage boundary and duplicate T-0010's
PDP decision. Treating a PAT or SSH key as an assertion of an authorization result would violate
ADR-0006's deny-by-default rule.

## Decision

We will run both client-facing Git protocol front doors inside `cmd/dataplane-app`, with this fixed
boundary:

1. **Smart-HTTP and SSH are listeners in the data-plane binary, not separate storage-facing
   services.** TLS termination and listener addresses are environment configuration. Smart-HTTP
   serves only Git's discovery and RPC endpoints; SSH accepts only Git upload-pack and receive-pack
   commands. Neither exposes a shell, arbitrary command execution, a filesystem path, or a generic
   proxy.

2. **Identity is resolved before routing.** HTTP Basic credentials are passed only to the
   Identity&Access authentication port for PAT verification; SSH public-key proof is passed only to
   that port for key lookup. The result is a tenant-scoped principal, never a caller-supplied tenant
   or actor assertion. Missing, malformed, expired, revoked, cross-tenant, or otherwise invalid
   credentials are denied before the storage RPC is opened.

3. **Repository URLs are handles, not paths.** The front door parses a configured URL/SSH command
   form into a tenant ID and repository ID, validates that opaque pair through the repository routing
   port, and constructs `gitsaas.git.v1.OperationContext` from the authenticated principal. No
   client-supplied filesystem path, credential, or authorization result crosses to `GitStorage`.

4. **Every permitted operation still reaches the PDP in `git-storaged`.** The front door performs
   authentication and routing; it does not decide `repo.read` or `repo.write`. `git-storaged` remains
   the policy-enforcement point immediately before `git-upload-pack` or `git-receive-pack`, so a
   mistakenly permissive front door cannot bypass the storage boundary.

5. **Failures are non-enumerating.** Authentication, tenant mismatch, unknown repository and PDP
   denial return the same coarse protocol-level unavailable/forbidden result appropriate to the
   transport. Detailed causes belong only in bounded operational audit/telemetry, never in Git
   output, credentials, or repository metadata.

6. **Protocol bytes are bridged unchanged and streamed.** After the context is admitted, request
   bytes flow bidirectionally between the transport and `GitStorage.UploadPack` or `ReceivePack`.
   The front door never buffers an entire pack, interprets Git objects, or creates a second write
   path. The T-0010 receive-pack event remains the asynchronous boundary for CI, search and audit.

## Consequences

**Positive.** Public Git traffic has one identity-to-storage route, while storage ownership and the
last PDP decision remain where ADR-0004 and T-0010 put them. The data plane stays one deployable
binary, and the two protocol front doors share the same tenant/actor context construction rather
than drifting into independent authorization schemes. A future ADR-0026 extraction can promote a
front door without changing the `GitStorage` contract.

**Negative / costs.** `dataplane-app` now owns two externally exposed protocol adapters and their
stream/backpressure behavior. Identity&Access must ship its authentication port before T-0011 can
meet real PAT/key acceptance criteria. SSH has no interactive shell, so operator debugging stays
outside the production listener.

**Follow-ups.**

- T-0013 defines and implements the additive Identity&Access authentication contracts for PATs and
  SSH keys, including revocation and tenant-scoped principal results.
- T-0011 defines endpoint/command parsing and proves real `git clone` and `git push` over both
  transports against a single storage node.
- Certificate issuance and rotation remain ADR-0017 follow-up work; this ADR only requires listener
  configuration rather than embedding a certificate choice.

## Alternatives considered

- **Separate Smart-HTTP and SSH services now** — rejected. No ADR-0026 trigger supports an
  extraction, and another process would add deployment and authorization seams before the modular
  monolith has evidence it needs them.
- **Invoke Git plumbing directly in the front doors** — rejected. It bypasses sharding, the block
  volume boundary, tenant-derived storage resolution, and the PDP check in `git-storaged`.
- **Authorize in the front door and omit the storage PDP decision** — rejected. Authentication is
  not authorization, and a defense-in-depth storage PEP is required by ADR-0006 and SPEC-0015.
- **Accept arbitrary SSH commands or a shell** — rejected. Git transport needs two plumbing commands;
  anything broader adds remote code execution surface with no Phase-1 requirement.
