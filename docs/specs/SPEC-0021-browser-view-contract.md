# SPEC-0021: Browser repository-view HTTP contract

- **Status:** Implemented (2026-08-14) — every acceptance criterion is proven by its task(s)
- **Owner:** platform
- **Context(s):** BFF, webfrontend, Repository/Git
- **ADRs:** 0015, 0020, 0022, 0023
- **Task(s):** T-0015
- **PRD:** PR-8

## Problem / context

RepositoryReader supplies tenant-scoped tree, file, and diff data to the BFF, but neither
SPEC-0007 nor SPEC-0017 defines the browser-facing BFF shape. Without this boundary the Astro app
could call Repository/Git directly, the BFF could expose storage semantics, or separate web and BFF
changes could silently drift. This specification defines the small SSR view surface and its
authentication, streaming, cache, and navigation guarantees before T-0015 implementation.

## In scope

- A versioned BFF HTTP view API, represented by additive
  `contracts/proto/bff/v1/browser.proto` messages and proto-JSON responses.
- Authenticated SSR tree, file, and diff views that call only the BFF; BFF maps only from
  RepositoryReader results and does not invoke the PDP, parse Git objects, touch storage, or derive
  permission outcomes.
- Tenant/principal context derived by the BFF from an authenticated session and forwarded to
  RepositoryReader. Browser input never carries tenant ID, actor ID, actor role, or an allow flag.
- Opaque revision/repository handles, repository-relative path encoding, pagination, bounded
  streaming, private no-store responses, and coarse non-enumerating failures.
- A keyboard-first command palette for navigation among the current repository tree, file, and
  diff views. It navigates; it never creates, modifies, reviews, or authorizes repository state.

## Out of scope

- A browser-to-Repository/Git route, direct storage/gRPC access, editing, blame/history, archive
  download, LFS bytes, MR/review UI, search, caching private source in a shared CDN, and command
  palette write actions.
- A second BFF authorization decision. Repository/Git remains the `repo.read` PEP defined by
  SPEC-0017.

## Contracts touched

`contracts/proto/bff/v1/browser.proto` defines view messages used as the JSON schema for these BFF
endpoints (tenant and actor are deliberately absent):

| Endpoint | Response | Semantics |
| --- | --- | --- |
| `GET /v1/repositories/{repository_id}/tree?revision=&page_token=&page_size=` | `TreeView` | entries and opaque continuation token |
| `GET /v1/repositories/{repository_id}/file?revision=&path=` | streamed bytes plus first-response `FileViewMetadata` | metadata once; BFF preserves RepositoryReader's 64 KiB bounded chunks |
| `GET /v1/repositories/{repository_id}/diff?base_revision=&head_revision=&path=` | streamed bytes | optional repo-relative path filter; BFF preserves chunk order/bounds |

`repository_id`, revisions, page token, and path are request handles, not paths on the host. A path
is percent-decoded exactly once, must remain repository-relative, and must not contain an absolute
prefix, `..` segment, NUL, a storage location, credential, policy outcome, or backend address.
The BFF passes it unchanged after validation to RepositoryReader; it does not resolve it against a
filesystem. `page_size` uses the SPEC-0017 server default/cap and is not a BFF-specific limit.

All successful private responses send `Cache-Control: private, no-store`. File and diff responses
stream rather than buffer whole content; browser-facing error bodies contain no revision, path,
repository-existence, PDP, or cross-tenant distinction. A failed Reader call emits no partial body,
metadata, or continuation token.

The BFF obtains its `ReadContext` only from authenticated request/session middleware and allocates
a request ID. It forwards verified roles once RepositoryReader's actor-role context is available.
The webfrontend's sole per-environment upstream is the configured BFF origin; it has no backend
origin, backend gRPC client, storage client, or RepositoryReader dependency.

## SSR and palette behavior

- The Astro server renders routes for tree, file, and diff from BFF responses only. It preserves
  route/query handles in links but never renders a credential, tenant/actor attribute, policy
  reason, or raw backend error.
- `Ctrl+K`/`Cmd+K` opens a focus-trapped, keyboard-operable palette. The v0 commands are **Browse
  tree**, **Open file**, and **Compare revisions** for the current repository. Selecting one changes
  only the browser route; Enter executes and Escape closes.
- Tree entries link to their repository-relative child route. File and diff views identify the
  requested revision(s) and path without converting object IDs or applying authorization logic.

## Data owned

Repository/Git owns Git reads and the authorization decision. The BFF owns only request adaptation
and shaped response streaming. webfrontend owns presentation/navigation state and no repository
data. Identity&Access owns the authenticated session/principal. No web or BFF component reads
Repository/Git storage or another context's database.

## Acceptance criteria (each becomes a test)

- [ ] AC1: An authenticated user can SSR-render a tenant-scoped tree, file, and diff through the
  BFF; each BFF handler maps only RepositoryReader data and preserves ordered bounded streams.
- [ ] AC2: Missing, malformed, cross-tenant, unknown, or denied view requests return one coarse
  browser error with no content, metadata, token, repository existence signal, or backend detail.
- [ ] AC3: A browser request cannot choose tenant, actor, role, policy outcome, filesystem path,
  backend address, or gRPC target. Session middleware supplies the only identity context.
- [ ] AC4: Browser and BFF integration tests prove the webfrontend reaches only the configured BFF
  origin and has no direct backend dependency; a request succeeds when BFF is stubbed and fails
  safely when BFF is unavailable, without contacting backend.
- [ ] AC5: Private tree/file/diff responses carry `Cache-Control: private, no-store`; a large file
  or diff is not buffered in full by BFF or SSR before response streaming.
- [ ] AC6: Keyboard tests prove `Ctrl+K`/`Cmd+K`, arrow navigation, Enter, and Escape operate the
  three v0 palette commands; Playwright covers tree → file → diff navigation.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | tenant/principal derive from session, and cross-tenant failures do not enumerate data |
| G2 least privilege | only Repository/Git asks PDP; browser and BFF cannot supply a decision |
| G9 least-privilege footprint | no backend/storage/credential client exists in the web process |
| UX | SSR and a small keyboard palette implement ADR-0015 without a second domain surface |

## Non-functional

- View responses respect Reader cancellation/backpressure; BFF and SSR must not join arbitrary
  file or diff streams into memory.
- Private source is never cached in a shared response cache; route-level user state is not embedded
  in static build output.
- The palette is keyboard operable with visible focus and an accessible label.

## Open questions / assumptions

- The external hostnames and BFF origin are environment configuration under invariant 13. The
  endpoint paths above are the versioned API route, not an environment hostname.
- Browser endpoint messages remain additive. Future blame/history/search extensions get new fields
  or endpoints rather than changing tree/file/diff semantics.
- T-0013 session/OIDC adapter work supplies authenticated BFF middleware; this spec does not pick
  cookie or bearer-token encoding.
