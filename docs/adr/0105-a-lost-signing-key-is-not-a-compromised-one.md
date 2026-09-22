# ADR-0105: A lost signing key is not a compromised one, and treating it as one strands the artifacts it signed

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (written after the `image-publish` cosign private key was found to be gone,
  with its public half committed since August)
- **Amends:** **ADR-0044's rotation and compromise handling.** ADR-0044 is Accepted and is not edited
  (ADR-0001); everything in it stands. This adds the third event class it does not name, and
  corrects one instruction that is actively wrong when applied to that class.
- **Related:** ADR-0047 (publish authority — the three gates that make a key usable at all),
  ADR-0098 (Artifact Registry as the publish target; decision 3 keeps signing untouched),
  ADR-0065 (release-key rotation — the `.release` chain, which is a *separate* trust chain and
  inherits this ADR's classification), ADR-0066 decision 6 (the availability-versus-integrity
  distinction this ADR reuses deliberately)
- **Governs:** G4 change governance, G6 compliance, operability

## Context

ADR-0044 names two things that can happen to a signing key:

> Rotation creates a second protected-environment key and publishes its public key beside the
> current one. Consumers accept both only during an explicit overlap. […] **On compromise, revoke the
> old public key immediately, block promotion, and re-sign every still-eligible digest.**

Both assume the private key is still **available to us**. Rotation is a planned act performed *with*
the old key in hand; compromise is an unplanned act where the old key is in someone *else's* hands.
Neither describes the case that actually occurred on 2026-09-22: the private half of
`image-publish-2026-08.pub` is simply **gone** — not in `~/.gitfrok`, and never loaded into the
`image-publish` environment, which was found not to exist at all. Nobody has it, including an
adversary.

**The blast radii are inverses of each other, which is why one procedure cannot serve both.**

| | Compromise | Loss |
|---|---|---|
| Who can sign with it | an adversary, and us | **nobody** |
| Threatens | **integrity** — a malicious digest can be signed | **availability** — publishing stops |
| Existing signatures | **suspect**, must be re-signed and the key revoked fast | **still valid and still trustworthy** |
| Revoke the old public key | immediately | **not until replacements exist** |

That last row is the dangerous one. ADR-0044's compromise instruction — *revoke the old public key
immediately* — is exactly wrong on loss. A lost key signed nothing an adversary controls, so its
signatures remain the **only** proof of provenance for every digest already published under it.
Revoking it on the reflex of "a key went bad" strands those artifacts: consumers stop trusting images
that were never in question, and the fleet cannot verify what it is already running. Loss is an
availability event and never an integrity event — the same bound ADR-0066 decision 6 draws around a
custody outage, for the same reason.

**This time it cost nothing, and that is luck rather than design.** The registry has never held an
image (`Repository Size: 0.000MB`, `Listed 0 items`), so zero artifacts were signed by the lost key.
ADR-0044's removal precondition — *"after every active release is re-signed or expired"* — is
therefore satisfied vacuously, and the key can be retired outright with no overlap. The next loss
will not be free, and the procedure should not be written for the easy case.

## Decision

**1. Loss is a third event class, classified explicitly and in writing.** A key is **lost** when
neither an operator nor the protected environment holds the private half and there is no evidence of
disclosure. A key is **compromised** when there is reason to believe anyone else holds it. Where the
evidence is ambiguous, it is a compromise: that error is recoverable and its inverse is not.

**2. On loss, the old public key is NOT revoked while anything it signed is still pullable.** It stays
in the trust bundle as the verification root for those digests. ADR-0044's *revoke immediately*
applies to compromise alone, and this ADR is the note that stops it being applied by reflex to an
event that looks superficially similar.

**3. Loss does not block promotion.** Existing signatures stay valid, so already-published digests
remain deployable. What stops is *publishing new ones*, until decision 4 or 5 completes. Blocking
promotion on loss would convert an availability event into an outage for no integrity gain.

**4. Lost with nothing still pullable → retire outright, no overlap.** When no digest signed by the
key is pullable from any registry the tree names, ADR-0044's removal precondition is already met.
Publish the new public key, remove the old one in the same commit, and do not open an overlap window:
an overlap that protects no consumer is ceremony that makes the trust bundle harder to read.

**5. Lost with artifacts in the field → overlap, re-sign, then remove.** Publish the new key beside
the old, re-sign every still-pullable digest **with the new key**, and remove the old public key only
once none remains. This is ADR-0044's rotation path, and it still works because re-signing needs the
*new* key rather than the lost one — the only thing loss takes away is signing with the old.

**6. Which case applies is decided by evidence, recorded in the retirement commit.** A registry
listing showing what is actually pullable, not a recollection that nothing was published. The
listing goes in the commit message. Decision 4 turns on a claim about the world, and an unevidenced
claim there silently retires a key that something still depends on.

**7. A private key held only in the Actions secret is one deletion away from loss.** The protected
environment is an access-control boundary, not a backup. Custody requires the holder to be able to
answer *"where is the other copy"* — and this ADR exists because on 2026-09-22 the answer was
"nowhere", for a key whose public half had been committed and gated for six weeks.

## Consequences

- `deploy/dev/trust/image-publish/README.md` gains the classification and the two paths; its current
  text describes only ADR-0044's overlap and would mislead on decision 4.
- The immediate retirement of `image-publish-2026-08.pub` is decision 4's first application, and its
  commit carries the `Listed 0 items` evidence decision 6 requires.
- The `.release` chain (`deploy/releases/trust/`, ADR-0065) inherits this classification unchanged.
  Its two committed manifests reference `docker.io/gitfrok/*`, which ADR-0098 decision 4 retired and
  records as 404 — so by decision 6 that chain would also fall under decision 4 today. Stated, not
  acted on: nobody has reported that key missing.
- Nothing is gated mechanically. Decisions 1 and 6 are judgements a human makes at an incident, and a
  fitness function that asserted "this key was lost, not compromised" would be asserting the thing
  under investigation.

## Alternatives considered

- **Treat loss as compromise and revoke.** One procedure, no classification, and safe-sounding.
  Rejected: it strands artifacts whose signatures were never in doubt, and trains operators to
  revoke on reflex — which makes the genuinely urgent case indistinguishable from the calm one.
- **Treat loss as an ordinary rotation with an overlap always.** Rejected by decision 4's case: an
  overlap requires re-signing with the old key's successor and a window during which both are
  trusted. With nothing to re-sign, the window protects nobody and leaves a dead key in the bundle
  implying a capability that no longer exists.
- **Keep the lost public key in the bundle permanently, for provenance.** Rejected. A verification
  key whose private half is unaccounted for is a standing question, not an archive; once nothing
  verifies against it, removing it is what makes the bundle mean something.
- **Fold this into ADR-0044 as an edit.** Refused by ADR-0001: Accepted ADRs are immutable.

## Open questions

- **Does an air-gapped mirror (ADR-0013) change decision 4's evidence?** "Pullable" is asked of the
  registries the tree names; a customer's mirror may hold a digest ours no longer serves. Probably
  makes decision 5 the default for anything that ever shipped to a customer, which is worth deciding
  before the first BYO release rather than during an incident.
- **Should the two `.release` manifests pinning the retired `docker.io/gitfrok/*` be regenerated or
  retired at the first real publish?** Raised by ADR-0098 decision 4 and unanswered; this ADR only
  observes that they are the reason the release chain's classification is not hypothetical.
