# ADR-0108: `gitfrok.7.solutions` is the tenant-facing name of the Git door

- **Status:** Accepted
- **Date:** 2026-09-23
- **Deciders:** the deciding owner, by direct instruction on 2026-09-23 ("point gitfrok.7.solutions
  for a tenant", then "remove old value and update the current", then "yes delete it" for the dead
  record it pointed through). Written after the change landed, and says so.
- **Amends:** ADR-0107 decision 1, to exactly the extent below. ADR-0107 is Accepted and is not
  edited (ADR-0001).
- **Relates to:** ADR-0107 (the Git door), ADR-0095 (the zone and its proxy rules), ADR-0041 (the
  front door's URL shape)

## Context

ADR-0107 decision 1 publishes the Git door at **one** hostname, `git-gitfrok.7.solutions`. Hours after
it was accepted, the owner asked for the name they had asked for from the start —
`gitfrok.7.solutions` — to serve a tenant.

That name was not free. It was a Cloudflare-**proxied** CNAME to `proxy-external-gitfork.7.solutions`
(note the transposed letters), an A record for `34.124.142.69` — an address in neither of this
project's GCP projects — which answered **522** (origin unreachable). Nothing in this tree created
either record and nothing referenced them. They were replaced and deleted on the owner's word, not on
the inference that a typo made them ours to reuse.

## Decision

**1. `gitfrok.7.solutions` is a second hostname on the same Git door.** Same Gateway, same reserved
address (`prod-dp-git-gateway`, `136.81.46.141`), same `HTTPRoute`, same `/git/` prefix, same backend.
It is a name, not a surface: nothing becomes reachable through it that was not already reachable
through `git-gitfrok`. ADR-0107 decision 1's "one hostname" becomes "two hostnames, one door"; its
"one path prefix" and "nothing else on the plane becomes reachable" stand unchanged.

**2. It is the name tenants are given.** `https://gitfrok.7.solutions/git/<tenant>/<repo>.git`. The
tenant stays in the path because the front door requires it (ADR-0041 decision 3: the URL is a handle
the door parses into a tenant and a repository, and the router refuses a tenant segment that does not
match the authenticated principal). A per-tenant vanity host would need a front-door change and is
not decided here.

**3. Every ADR-0107 rule for the door applies to this name unchanged.** DNS-only in Cloudflare (the
proxy caps request bodies, and a push is one request carrying the whole pack); a Google-managed
certificate on its own certificate-map entry (`gitfrok-apex`); its own Gateway listener
(`tenant-https`), because a listener carries one hostname. Its `_acme-challenge.gitfrok` CNAME is
load-bearing exactly as `git-gitfrok`'s is.

**4. `git-gitfrok.7.solutions` is kept.** Retiring it would break every remote already configured
against it, for no gain. Both names are equivalent and permanent until a later decision says
otherwise.

## Consequences

- **Proven before it was recorded:** a PAT issued for tenant `7solutions` pushed to and cloned
  `https://gitfrok.7.solutions/git/7solutions/welcome.git` with a browser-trusted certificate
  (`CN=gitfrok.7.solutions`, Google Trust Services WR3), and **the same PAT was refused** by tenant
  `dev`'s repository — `remote: authentication required`. Adding a hostname did not weaken tenant
  isolation, which is the only thing a second name could plausibly have broken.
- One more managed certificate, one more DNS authorization record to keep. Negligible cost; the
  Gateway and its forwarding rule are shared.
- **The apex of the product's naming is now a Git endpoint, not a web page.** A browser opening
  `https://gitfrok.7.solutions/` gets a 404: only `/git/` is routed. If the web surface ever moves to
  this name, that is a routing decision on this Gateway, and the two must not be allowed to collide on
  path.
