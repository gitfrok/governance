# SPEC-0017: Repository read RPC contract

- **Status:** Draft
- **Owner:** platform
- **Context(s):** Repository/Git + BFF
- **ADRs:** 0022, 0015, 0006, 0003
- **Task(s):** T-0014 (consumer); T-0015 (consumer)
- **PRD:** PR-8

## Problem / context

SPEC-0007 requires tenant-scoped tree, file, and diff reads from Repository/Git and
an aggregation-only BFF view. Its pagination and streaming thresholds remain open, so
a proto would otherwise hard-code behavior before it is specified. This specification
defines the additive v1 read surface used by the BFF and the browser it serves.

## In scope

- A `gitsaas.repository.v1.RepositoryReader` internal gRPC service with `GetTree`,
  `GetFile`, and `GetDiff` operations.
- A tenant-scoped request context carrying tenant, verified actor and request IDs;
  opaque repository and revision handles; and repo-relative Git paths only.
- Paginated tree entries with an opaque, server-issued page token.
- Chunked server streams for file and diff bytes, so neither the BFF nor the backend
  needs to buffer an arbitrary blob or patch in memory.
- Coarse, non-enumerating denial before any content or continuation token is emitted.
- BFF mapping of the contract result to its browser-facing view without storage access,
  authorization decisions, Git parsing, or domain-derived fields.

## Out of scope

- Blame, commit history, search, archive download, LFS object bytes, writes, review
  flows, and browser endpoint routing or visual design.
- Browser credentials or direct browser-to-backend calls; the BFF remains the only
  browser-facing consumer.
- A new authorization mechanism: Repository/Git asks the existing PDP for `repo.read`.

## Contracts touched

Additive `contracts/proto/repository/v1/repository.proto`:

- `RepositoryReader.GetTree`, unary, returns at most 100 entries by default and at
  most 500 when the caller supplies `page_size`; the server returns an opaque
  `next_page_token` only when more entries exist.
- `RepositoryReader.GetFile` and `GetDiff`, server-streaming; every response has at
  most 64 KiB of bytes and a final `eof` marker. File metadata occurs only in the
  first response; a stream emits no bytes when authorization, revision, or path
  validation fails.
- Request messages include `tenant_id`, `repository_id`, `actor_id`, and `request_id`.
  They include an opaque Git revision and a repository-relative path where applicable;
  they never include a storage location, filesystem path, credential, policy result,
  or a caller-provided tenant/actor assertion.
- Tree entries name the repository-relative path, entry kind, Git object ID, mode and
  byte size. Diff requests name a base and head revision plus an optional
  repository-relative path filter. These are Git-facing data, not host filesystem
  locations.

Exact field numbers and generated package paths are part of the additive contract PR
after this spec is Approved. Existing v1 contracts remain unchanged.

## Data owned

Repository/Git owns repository objects and resolves revisions and paths against the
tenant-scoped repository. The BFF owns no repository data: it forwards authenticated
identity context to the reader and shapes returned contract data for its HTTP/SSR view.
Policy owns the allow/deny decision and neither read response carries it.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A permitted principal receives a paginated tree for one tenant-scoped
  repository and revision; a continuation token is opaque and cannot be reused against
  another tenant, repository, or revision.
- [ ] AC2: A permitted principal reads a file or diff as ordered chunks no larger than
  64 KiB; a payload larger than one chunk is complete and byte-identical when joined.
- [ ] AC3: Missing, malformed, cross-tenant, unknown, or unauthorized read requests
  emit no content or continuation token and return the same coarse denial class.
- [ ] AC4: Absolute paths, traversal segments, storage paths, credentials, and policy
  outcomes cannot be represented by the contract request or response.
- [ ] AC5: The BFF uses only `RepositoryReader` result data to form its view response;
  its aggregation tests prove it does not call storage, invoke the PDP, or derive an
  authorization result.
- [ ] AC6: A browser route reaches the read surface only through the BFF; a direct
  backend endpoint is absent and the dependency-direction gate remains green.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | every request is tenant-scoped; tokens bind to their repository and revision |
| G2 least privilege | Repository/Git asks the PDP before yielding any content; the BFF does not decide access |
| G9 least-privilege footprint | no storage paths, credentials, or policy outcomes cross the read contract |

## Non-functional

- Tree pages default to 100 entries, cap at 500, and use opaque server-issued tokens.
- File and diff streams cap each message at 64 KiB and respect gRPC cancellation/backpressure.
- The BFF does not buffer a whole file or diff before forwarding it to its SSR/HTTP response.
- Errors supplied to browser-facing consumers are non-enumerating; detailed reasons remain bounded
  operational telemetry only.

## Open questions / assumptions

- The browser endpoint paths and cache headers are BFF implementation details; they must preserve
  the contract's tenant/principal context and no-store behavior for private content.
- Blame and history are in PR-8 but not T-0014's stated scope; a later task/spec extends this v1
  surface additively rather than overloading tree/file/diff responses.
