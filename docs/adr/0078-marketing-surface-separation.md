# ADR-0078: The marketing page is served by a surface that never holds a session

- **Status:** Proposed
- **Date:** 2026-08-19
- **Deciders:** platform (ADR-0070's open follow-up, and the smallest Tier C decision)
- **Related:** ADR-0070, ADR-0049 (the BFF browser session), ADR-0019/0020 (Astro SSR),
  ADR-0003 (tenancy), SPEC-0001 (coarse refusal)
- **Governs:** PR-32

## Context

PR-32 asks that an unauthenticated visitor is served a marketing landing page that never leaks
tenant existence or content. ADR-0070 left one question open: whether that page belongs in
`webfrontend` at all.

It does not, and the reason is narrow and concrete rather than architectural taste.

`webfrontend` is an SSR app whose every page reads the session cookie and forwards it to the BFF.
The shell itself branches on cookie presence to render the auth affordance (ADR-0049). Serving an
unauthenticated marketing page from that same origin puts a page with no authorization story inside
an app whose entire structure assumes one — and the failure mode is not hypothetical. It is a
future contributor adding "a few logged-in touches" to the landing page: a repository count, a
recent-activity strip, a customer logo wall. Each is a tenant-existence leak, and each looks like a
small improvement to a marketing page.

## Decision

**1. The marketing page is a separate surface that never receives a session cookie**, and it makes
no call to the BFF. Static, or server-rendered from content that is not tenant data.

**2. It is not served from the authenticated app's origin.** The cookie is `__Host-` prefixed, which
binds it to an origin; a different host is what makes "never receives a session" a property rather
than a promise.

**3. `webfrontend`'s root stays the repository list.** Since T-0055 that route lists the caller's
repositories, and it is the right thing for a signed-in reader to land on. An unauthenticated
visitor reaching it gets the coarse refusal the whole product gives — which reveals nothing, and is
already the behaviour.

## Consequences

**Good.** The property is structural: a surface with no session cannot leak tenant state, whatever
someone later adds to it. It also keeps the marketing page free of the SSR app's build, gates and
design-token discipline, none of which a landing page needs.

**Bad.** Two surfaces to deploy and two places where the brand lives, and the visual drift between
them is now somebody's job. ADR-0069's tokens are in `webfrontend`; a separate marketing surface
either duplicates them or imports them, and duplication is how brands diverge.

**The risk this ADR is most likely to be wrong about.** That the separation survives contact with
marketing's actual wants. The first request will be "can the pricing page show live usage" or "can
we personalise it for a logged-in visitor", and the answer under this ADR is no. If that turns out
to be a real business need, the decision to revisit is this one — not the leak-prevention rule,
which stays.

## Alternatives considered

**Serve it from `webfrontend` at `/marketing` with no BFF calls.** Simplest, one deployment, and
refused: "makes no BFF calls" is a discipline rather than a property, and it lives one commit away
from being false in an app where every other page does.

**No marketing page in this product at all.** Entirely reasonable — it may belong to a website that
has nothing to do with this repository. If so, PR-32 should be withdrawn from the PRD rather than
left open, and this ADR becomes the record of why.

## Follow-ups

- Where the marketing surface actually lives, if it proceeds — a separate repository is the likely
  answer and is not decided here.
- How ADR-0069's brand tokens reach it without being duplicated.
