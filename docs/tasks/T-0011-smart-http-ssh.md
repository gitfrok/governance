# T-0011: Smart-HTTP + SSH front doors

- **Status:** Done (2026-08-10) — backend #27/#28
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0004-git-storage-transport.md; docs/specs/SPEC-0022-ssh-verifier-key-routing.md
- **ADRs:** 0004, 0003, 0041, 0043
- **Owner:** unassigned

## Goal
Expose git over smart-HTTP and SSH, authenticating and routing to the Git-RPC service.

## Acceptance criteria (test-first)
- [x] AC1: `git clone/push` works over HTTPS with a PAT and over SSH with a key.
- [x] AC2: auth resolves the tenant + identity before any storage call (deny on failure).
- [x] AC3: unauthorized/anonymous access to a private repo is denied.

## Tests to write first
- integration: real git client over both transports; unit: auth/route logic.
- policy/isolation: private-repo access control.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `47d6aca` (#27) | Complete Smart-HTTP and SSH front doors: `internal/gitfrontdoor/{router,http,ssh_server,grpc_storage}` with auth-first routing, tenant enforcement, path-traversal rejection, and one verified forced git command per SSH session. |
| backend | `a4c7db8` (#28) | Wire front doors into the dataplane and complete the HTTP push path. |

- **AC1** — real git clone+push over HTTPS-with-PAT and SSH-with-key pass (`TestSmartHTTPGitCloneStreamsThroughGitStorage`, `TestSmartHTTPGitPushStreamsThroughGitStorage`, `TestSSHGitCloneAndPushStreamThroughGitStorage`).
- **AC2** — auth+tenant resolved before storage; anonymous/denied credentials never open a Git subprocess (`TestSmartHTTPAuthenticatesBeforeOpeningStorageAndStreamsAdvertisement`, `TestSmartHTTPAnonymousRequestIsDeniedWithoutStorage`, `TestSmartHTTPDeniedCredentialNeverOpensStorage`, `TestSSHUnknownKeyIsDeniedBeforeStorage`); `TestRepositoryReaderWrongTenantSendsNoContent` proves wrong-tenant yields no content.
- **AC3** — unauthorized/anonymous access denied and surfaced to the git client (`TestSmartHTTPPDPDenialFailsTheGitClient`, `TestDataPlaneSSHDeniesUnknownKey`).

## Notes / open questions
Governance work (ADR-0041, ADR-0043, SPEC-0022) approved before RED. The SSH verifier key ID routes through the credential verifier lookup. Cross-repo changes followed ADR-0027 order (governance first).
