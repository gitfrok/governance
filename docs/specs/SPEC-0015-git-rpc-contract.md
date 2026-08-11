# SPEC-0015: Git-RPC v1 contract

- **Status:** Approved
- **Owner:** platform
- **Context(s):** Repository/Git
- **ADRs:** 0004, 0006, 0016, 0022, 0025, 0033
- **Task(s):** T-0010

## Problem / context

SPEC-0004 requires an internal Git-RPC service, but it does not define the v1
gRPC surface that `git-storaged` and the future smart-HTTP/SSH front doors use.
Without that surface, implementation would choose tenant, authorization, and
Git-protocol semantics ad hoc at the process boundary.

## In scope

- A new additive `contracts/proto/git/v1/git.proto` package with a
  `GitStorage` service.
- Bidirectional `UploadPack` and `ReceivePack` RPCs. They carry Git protocol
  bytes unchanged: the client stream is stdin for the corresponding Git
  plumbing command; the server stream is its stdout. This is the internal
  transport for clone/fetch and push respectively, not a new Git protocol.
- The first client message carries an `OperationContext`; every operation has
  an opaque `tenant_id`, `repository_id`, `actor_id`, and `request_id`.
  Repository paths, authorization tokens, and Git object contents never
  appear in metadata.
- `git-storaged` derives the repository location only from the tenant-scoped
  handle beneath its configured block-volume root. It never accepts a caller
  path and never mounts or writes live repositories on FUSE.
- Before spawning `git-upload-pack` or `git-receive-pack`, `git-storaged`
  checks its tenant-scoped handle and obtains a PDP decision for `repo.read`
  or `repo.write`. A denial is indistinguishable from an unavailable
  repository to the caller.
- A successful receive-pack publishes the existing
  `gitsaas.events.repository.v1.RefUpdated` event for every changed ref. The
  event remains the asynchronous integration boundary for CI, search, and
  audit.
 - `GitStorage.SetProtection` carries one exact-ref branch-protection rule from
   Code Review to the storage node (SPEC-0019 AC7). It is the boundaried
   counterpart of `BranchProtectionChanged`: the event is sufficient when Code
   Review and git-storaged share a process; the RPC is the route by which the
   rule reaches the node that enforces direct pushes when they do not. Storage
   asks the PDP for the rule change exactly as it does for any ref-affecting
   operation.
- `GitStorage.SubscribeRefUpdates` is the boundaried counterpart of the
  repository `RefUpdated` event: when git-storaged and the dataplane share a
  process, the dataplane's in-process bus announces every ref update; when they
  do not, the dataplane subscribes to this server-streaming RPC and publishes
  the notification as `RefUpdated` on its own bus. Storage keeps applying
  updates whether or not a subscriber is connected — the subscription is a wire
  event channel, not a command or an acknowledgement protocol.

## Out of scope

- Smart-HTTP and SSH authentication/translation (T-0011).
- Primary-plus-sync-replica acknowledgement, promotion, and fencing (T-0012).
- Repository creation APIs, placement control plane, LFS transfer, and
  replication topology.
- Exposing `git-storaged` to browsers or untrusted clients.

## Contracts touched

`contracts/proto/git/v1/git.proto` is additive and contains:

- `GitStorage.UploadPack(stream UploadPackRequest) returns (stream UploadPackResponse)`;
- `GitStorage.ReceivePack(stream ReceivePackRequest) returns (stream ReceivePackResponse)`;
- `GitStorage.SetProtection(SetProtectionRequest) returns (SetProtectionResponse)` — one
  exact-ref rule (`target_ref`, `required_approvals`) under a `RefUpdateContext`;
- `GitStorage.SubscribeRefUpdates(SubscribeRefUpdatesRequest) returns (stream RefUpdateNotification)` —
  server-streaming ref announcements (per-notification `ref`, `old_sha`, `new_sha`,
  `actor_id`, `actor_roles`, `occurred_at`), tenant/repository wildcard filtering;
- `OperationContext` with `tenant_id`, `repository_id`, `actor_id`, and
  `request_id`;
- packet payloads as `bytes`, plus an explicit client-stream close marker.

The request context is required in the first client message and absent from
later messages. Empty tenant, repository, actor, or request IDs are denied.
The contract carries neither credentials nor an `allowed` flag: authorization
is a server-side PDP decision, never a caller assertion.

## Data owned

Repository/Git owns bare-repository bytes and the tenant-scoped handle that
locates them beneath the configured block-volume root. The service owns no
other context's data and publishes ref changes rather than synchronously
calling CI, search, or audit.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A client can stream a small clone/fetch through `UploadPack` and a
  push through `ReceivePack` against one block-volume-backed node.
- [ ] AC2: `git-storaged` rejects an empty or wrong-tenant handle before a Git
  subprocess starts; the response does not disclose whether another tenant's
  repository exists.
- [ ] AC3: A caller cannot supply a filesystem path, authorization result, or
  credential in the Git-RPC request metadata.
- [ ] AC4: A successful ref move emits contract-compatible `RefUpdated` with
  tenant, repository, actor, old SHA, new SHA, and ref.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | opaque tenant-scoped handles; no caller paths; wrong-tenant denial |
| G2 least privilege | PDP decision occurs inside the storage service before Git runs |
| G5 auditability | ref changes leave the service as `RefUpdated` for independent consumers |
| G9 least-privilege footprint | the internal service accepts no credential or source-code metadata |

## Non-functional

- Stream Git bytes without buffering an entire pack in memory.
- Preserve Git's process exit status as a coarse, non-enumerating RPC failure.
- Repositories use the block-volume semantics mandated by ADR-0033; LFS,
  artifacts, and registry blobs remain object-store concerns.

## Open questions / assumptions

- T-0011 supplies the authenticated actor and protocol translation; until
  then, T-0010 integration tests use a trusted in-process test caller only.
- T-0012 extends the write acknowledgement path; this v1 service must not
  claim a receive-pack is durable beyond the single-node behavior T-0010
  proves.
- The exact proto field numbers and generated-language package paths are part
  of the implementation PR after this draft is approved; they must follow the
  additive v1 rules in `contracts/README.md`.
