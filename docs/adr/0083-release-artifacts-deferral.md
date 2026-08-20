# ADR-0083: Release artifacts stay deferred until a user asks — and the shape is fixed now so the reopen is one decision smaller

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-20
- **Deciders:** platform (disposition of ADR-0075's artifacts follow-up, per ADR-0070's Tier-C gate;
  accepted by the deciding owner 2026-08-21)
- **Related:** ADR-0075 (this disposes its follow-up; it is Accepted and is not amended), ADR-0070
  (the Tier-C gate whose evidence standard this applies), ADR-0020/0033/0050 (blob storage),
  ADR-0044/0065 (the release trust bundle — platform releases only), ADR-0066 (custody service),
  ADR-0057 (tenant secret custody follow-up), ADR-0008/0061 (fair-use and metering), SPEC-0056
  (AC9, AC12), PRD PR-29 and §6, `scripts/check-contracts.sh` check 15
- **Governs:** the artifacts half of PR-29 — the half ADR-0075's accepted increment left out

## Context

Phase 4 delivered releases as a tag, notes, and an honest answer when the tag moves (SPEC-0056,
T-0064…T-0066). ADR-0075 accepted exactly that increment and left artifacts out, because the moment
a customer's users download an artifact from this platform, the platform is in their software supply
chain. The absence is held by construction, not by intention: check 15 in `scripts/check-contracts.sh`
fails on any artifact field in `gitsaas.release.v1`, and the surface states the absence rather than
implying it (SPEC-0056 AC12).

PR-29 still names artifacts, so the PRD row reads delivered-in-part. The question this ADR exists to
answer is whether to close that half now — or to keep the deferral, and if so, with an explicit
statement of what would reopen it.

Three facts frame it:

1. **The evidence is still the prototype.** PR-29 was adopted from the `./UI` mockup under ADR-0070's
   Tier C, and ADR-0070 recorded as the risk it is most likely to be wrong about that PR-24…PR-32's
   evidence is a mockup, not a user. EP-27's five ADRs then defended each surface on its merits at
   acceptance, and not one adopted its surface as the prototype drew it. Nothing has happened since:
   no customer has asked for release artifacts, and no workflow has surfaced that needs them. That
   the prototype showed artifacts is precisely the evidence the gate exists to discount.
2. **Storage is not the blocker.** Blobs already have a decided home: SeaweedFS-S3 for LFS,
   artifacts and registry blobs (ADR-0020, confirmed by ADR-0033 §4, carried as invariant 7; the
   access path narrowed to the FUSE mount by ADR-0050). The deferral is not waiting on
   infrastructure. It is waiting on exactly the decisions ADR-0075's open questions name — signing
   and key custody, immutability and withdrawal, retention and metering — which is the point of
   ADR-0075's warning that an artifact field re-opens questions 1 to 3 at once.
3. **The product already distributes the two dominant artifact classes.** Container images through
   the registry, and source or large files through git and LFS. Artifacts would add generic binary
   downloads — the residual class, and the one every competing forge has had for a decade. That last
   clause is the strongest argument against deferral, and the Consequences treat it as the risk it is
   rather than dismissing it.

## Decision

**1. Release artifacts remain deferred.** No artifact field, no upload route, no download link — the
list ADR-0075's accepted scope said must not grow without returning here. Check 15 continues to hold
the absence at the wire, and PR-29 stays delivered-in-part with its gate named in the PRD row.

**2. This ADR does not amend ADR-0075.** Accepted ADRs are immutable (ADR-0001, invariant 11); this
is the disposition of its follow-up. ADR-0075's two decisions stand and will govern any artifact that
ever ships.

**3. The trigger that reopens the decision is named, and any one of the three suffices.**

- **A user asks.** A customer or design partner names a workflow in which downloading release
  artifacts from this product replaces something they do elsewhere today. The evidence standard is
  the Tier-C gate's: a user, not a mockup, and not an internal assumption about what a forge should
  have. An evaluation walk-away caused by the missing download counts, even if the word "artifact"
  never appears in the feedback.
- **Custody stops being a releases-specific problem.** The tenant-secret-custody follow-up of
  ADR-0057 — for which ADR-0066's OpenBao service is the presumptive home — gains a signing
  consumer for any reason. The key-custody question that makes artifacts expensive is then being
  answered anyway, and answering it again for releases costs little.
- **Import parity names release assets.** PR-12 imports refs, tags, LFS objects and merge-request
  history. If that scope extends to GitHub/GitLab release assets, the product must hold what it
  imports, and the deferral is moot.

Whichever fires, the reopen is a new ADR answering ADR-0075's open questions 1 to 3 — not a field
added beside check 15's back. The check exists precisely to force that order.

**4. The shape is fixed now, for the day a trigger fires.** Accepted-but-unbuilt, the same posture
ADR-0078's decisions 1 and 2 take toward a marketing surface that does not exist yet: these bind the
day artifacts exist, and not before.

- **Blobs live in the tenant-scoped SeaweedFS blob store** — the same class as LFS and CI artifacts
  (ADR-0020's S3 role, confirmed by ADR-0033, accessed per ADR-0050) — never in git storage
  (invariant 7) and never on the CI artifact path. ADR-0075 refused that reuse, and the refusal
  stands: same store, different retention, different promises.
- **Artifacts get their own retention class, and metering is decided at reopen.** A release artifact
  is meant to outlive everything around it, which makes it unlike any object the fair-use envelope
  meters today. PRD §6 names storage and egress as envelope dimensions; whether artifacts meter under
  those or add a dimension is one of the reopen questions, not something that accrues silently.
- **Nothing is served as trusted unless the product can say what makes it trustworthy** (ADR-0075
  decision 1). The unsigned path that decision allows remains available at reopen — with the
  statement prominent rather than a footnote — and tenant signing never reuses the release trust
  bundle (ADR-0075 decision 2).

## What this does not decide

- **Whether tenant artifacts are signed at all, and by whose key** (ADR-0075 open question 1). That
  is decided at reopen. The ICP is regulated teams for whom the supply chain is a buying criterion —
  a higher bar than the forges that served unsigned for a decade — but the bar is the reopen ADR's to
  set, not this one's.
- **Whether a published release becomes audit-grade immutable, and what withdrawing a compromised
  artifact means** (open question 2, ADR-0007's posture as the reference point).
- **The wire shape** — fields, upload and download RPCs, BFF routes, the view. That is a spec after
  the reopen, and check 15 moves only in the governance PR that implements it (invariants 21, 24).
- **Anything about the shipped increment.** Tags, notes, and the moved-tag answer are untouched.

## Consequences

**Good.** No supply-chain promise made for a user who does not exist, and no custody, retention or
metering decision taken under the pressure of a feature that looks small. Because the gate is
structural, the deferral cannot quietly grow into a "just a download URL" commit — check 15 fails
first, and this ADR is what the failure resolves to. And because the shape is fixed now, the future
reopen is one decision smaller: storage, retention class and the survival of the trust rules will not
be re-litigated.

**Bad.** PR-29 remains delivered-in-part, and the honest cost ADR-0075 named stays on the books:
when artifacts arrive, the work is signing, custody, immutability, retention and metering, and it is
larger than the feature looks. The product also stays absent from a surface every competing forge
has had for a decade, and evaluators notice absences even when nobody voices them.

**The risk this ADR is most likely to be wrong about.** That the trigger underweights table stakes.
A customer may never ask for artifacts precisely because they assume their forge has them — the gap
surfaces at onboarding as churn rather than as a request, and trigger (a) waits for words nobody may
say. The mitigations are written into the trigger: an evaluation walk-away counts as an ask even
unworded, and trigger (c) forces the question the day a migration would drop a customer's release
assets. If neither fires and the product loses a deal to a forge with downloads, the decision to
revisit is this one.

## Alternatives considered

**Build unsigned artifacts now, with the prominent statement.** ADR-0075's decision 1 already allows
this, and its own risk section names the argument: most forges served unsigned artifacts for a
decade and the world absorbed it. Refused on evidence, not on architecture — there is no user to
defend the four questions that remain after the statement (custody, immutability, retention,
metering), and building a Tier-C increment against a mockup is exactly the class of work ADR-0070's
gate exists to refuse. The trigger exists so this alternative returns the day the evidence changes.

**Reuse the CI artifact path.** Refused already by ADR-0075: same storage, different retention and
different promises, and sharing the path invites sharing the retention. The refusal is carried into
decision 4's shape.

**Withdraw the artifacts half the way PR-32 was withdrawn.** PR-32 was withdrawn because nobody
could own its surface — no repository, no owner, no way to start. Artifacts are the opposite: the
Release context exists, is delivered, and has an owner; what is missing is a decision, not an owner.
A decision with a named trigger is a deferral, not a withdrawal, and the PR-29 row stays.

**Decide signing, custody and immutability now so a build would be mechanical.** Deciding key
custody for tenants who have not asked, and audit-grade immutability for objects that do not exist,
is the gold-plating the gate exists to prevent. Those questions are left to the reopen deliberately,
where they will have a user to argue from.

## Follow-ups

- On any trigger firing: an ADR answering ADR-0075's open questions 1 to 3, then a spec, then the
  governance contract PR that moves check 15 — in that order (invariant 24).
- On acceptance: the PRD's PR-29 row and §12.1's deferral record should cite this ADR; the PRD is
  amended by its own change, not by this one.
