# ADR-0075: Releases is a bounded context whose promises are supply-chain promises

- **Status:** Accepted
- **Date:** 2026-08-19 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (required by ADR-0070's follow-up before any PR-29 spec)
- **Related:** ADR-0070, ADR-0022, ADR-0033 (repo storage), ADR-0050/0051 (object storage),
  ADR-0044 and ADR-0065 (release trust and signing — for OUR releases), ADR-0071 (registry as the
  truth for existence), ADR-0007, ADR-0009/0010 (residency)
- **Governs:** PR-29

## Context

The prototype shows Releases beside Issues. PR-29 asks that a team can cut and publish a release
from a tag, with its artifacts and notes.

A release looks like a tag with a description attached. It is not. **A release is a distribution
point**, and the moment a customer's users download an artifact from it, this platform is in their
software supply chain. Every promise the surface makes — that this artifact came from that tag, that
it has not changed, that it is the one the maintainer published — is a promise about provenance.

The product already has machinery for exactly this problem, and it is pointed the other way:
**ADR-0044 and ADR-0065 sign and verify *our* releases** to a customer's data plane, with a release
trust bundle and digest pinning. Nothing equivalent exists for a *tenant's* releases.

## What has to be decided, and is not decided here

**1. Are release artifacts signed, and by whom?** An unsigned artifact served from a URL a customer
trusts is a supply-chain liability with the platform's name on it. Signing them raises the harder
question of whose key — the tenant has none the platform holds, and holding one for them is a
custody decision under ADR-0066's shape.

**2. Is a published release immutable?** If yes, that is an audit-grade claim requiring the same
posture as the append-only audit log, including what happens when a maintainer must withdraw a
compromised artifact. If no, "release" means considerably less than a reader assumes, and the
surface must say so.

**3. Where do artifacts live, and who pays for them?** ADR-0050 puts LFS and CI artifacts on the
SeaweedFS mount with an S3 fallback. Release artifacts are the same class of object and a different
retention question: a CI artifact is transient and a release artifact is meant to outlive everything
around it. Size and retention are fair-use dimensions (PRD §6) and therefore metering questions.

**4. What is a release derived from?** A tag lives in git storage. ADR-0071 already decided that for
repositories the *registry* is the truth for existence, not the disk; the same question recurs, and
a release whose tag has been deleted or moved is a state this surface must have an answer for.

## Decision

**This ADR does not adopt releases. It fixes two boundaries.**

**1. A release artifact is never served as trusted unless the product can say what makes it
trustworthy.** Until signing is decided, any release surface states plainly that artifacts are
stored and served as uploaded, and are not verified by the platform. That is the same discipline
ADR-0053's blame rule follows: name the thing the platform does not vouch for.

**2. Tenant release signing does not reuse the release trust bundle.** ADR-0044/ADR-0065's bundle
attests *platform* releases to data planes. Reusing it to attest tenant artifacts would conflate two
trust roots with different authorities, and the two-bundles lesson is already recorded in EP-21's
carry: neither one's test may stand in for the other's.

## Accepted scope (2026-08-19)

**The owner accepted this ADR together with its recommended alternative: tags and notes, no
artifacts.** That is the first increment, specified as SPEC-0056, and it changes what the open
questions above mean rather than answering them:

- **Signing (open question 1) does not arise.** With no artifact there is nothing to sign and
  nothing served as trusted. Decision 1 stands unused rather than satisfied, and becomes live the
  day an artifact does.
- **Immutability (open question 2) is narrowed, not settled.** For a notes-only release, notes are
  **editable and carry the instant they were last edited**: a release note is documentation, and
  refusing to fix a typo in it helps nobody. The audit-grade immutability question is about
  artifacts and returns with them.
- **Storage and metering (open question 3) do not arise.** Notes are a bounded text field in the
  context's own table, not an object in a store.
- **Open question 4 is answered, and it is the interesting one.** A tag can move or be deleted after
  a release is published. The release therefore records **the commit the tag pointed at when it was
  published**, so the surface can say when the tag no longer points there — rather than silently
  rendering whatever the tag means today. See SPEC-0056 AC6.

**What this increment must not grow into without returning here:** an artifact field, an upload
route, or a download link. Each re-opens questions 1 to 3 at once.

## Consequences

**Good.** The supply-chain question is asked before a download URL exists rather than after one is
in a customer's CI.

**Bad.** PR-29 is not delivered. And the honest cost of doing it properly — signing, custody,
immutability, retention, metering — is larger than the feature looks.

**The risk this ADR is most likely to be wrong about.** That releases need signing to ship at all.
Most forges served unsigned release artifacts for a decade and the world absorbed it; insisting on a
custody decision first may be gold-plating a feature customers would accept unsigned, with a clear
statement of what is not verified. Decision 1 is written to allow exactly that path — but if it is
taken, the statement must be prominent rather than a footnote, because the failure mode is somebody
else's compromise.

## Alternatives considered

**Releases as a view over tags, with notes and no artifacts.** Small, safe, genuinely useful, and
avoids every question above. **Recommended as the first increment if PR-29 proceeds.**

**Reuse the CI artifact path for release artifacts.** Refused for now: same storage, different
retention and different promises, and sharing the path invites sharing the retention.

## Follow-ups

- Tenant artifact signing and key custody, if artifacts proceed.
- Release artifact retention as a fair-use dimension.
- What a release means when its tag has moved or gone.
