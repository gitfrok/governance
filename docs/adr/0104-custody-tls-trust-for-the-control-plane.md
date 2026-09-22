# ADR-0104: The control plane cannot verify the custody service's certificate, and nothing in the tree can give it the CA

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (written after the first production apply of `deploy/k8s/platform` put a
  TLS-serving OpenBao on a real cluster, which is where this became measurable)
- **Related:** ADR-0066 (custody is OpenBao transit, control-plane-side — this ADR supplies the one
  thing its transport posture never named), ADR-0035 (first-party images are `FROM scratch`, which is
  why the trust store is exactly one file), ADR-0099 decision 7 + SPEC-0069 (no installer authors a
  Secret), ADR-0096 (Kustomize-only installers), ADR-0092 decision 4 (OpenTofu never provisions a
  Kubernetes object), SPEC-0044 AC1/AC3 (the CA holds references, never material), SPEC-0067
  (the control-plane installer), T-0040, T-0084, T-0086
- **Governs:** G1 isolation, G6 compliance, operability

## Context

`deploy/k8s/README.md` step 4 — apply `controlplane/overlays/prod-cp` — cannot succeed today, for a
reason that is independent of the two blockers already recorded there (unpublished images, and an
uninitialised OpenBao). **The control plane has no way to verify the certificate the custody service
presents.** Everything below is measured against the tree and the live `prod-cp` cluster on
2026-09-22, not inferred.

**1. The custody certificate must be privately signed.** `openbao-tls` covers
`openbao-{0,1,2}.openbao-internal` and `openbao.gitfrok.svc.cluster.local`. No public CA issues for
those names and none ever will, so a private CA is not a shortcut here — it is the only shape
available. The certificate now serving on `prod-cp` was generated out of band for exactly this
reason.

**2. The client verifies against the system pool and offers no alternative.**
`backend/modules/agent/internal/adapters/custody/openbao.go`: `Config` carries `Address`, `Mount`,
`Token`, `Client` and `AllowHTTPForLocalTests` — **no CA file, no CA bundle, no TLS config**.
`defaultHTTPClient()` returns `&http.Client{Timeout: 10 * time.Second}`, i.e. Go's default transport
against the system root pool. The one hook that exists, `Config.Client`, is a composition-root
injection point that the production composition does not use for this.

**3. The system pool is one file, and the private CA is not in it.** ADR-0035 makes the image `FROM
scratch`; `backend/Dockerfile.controlplane` copies exactly
`/etc/ssl/certs/ca-certificates.crt` from the build stage. That is the whole trust store.

**4. The installer supplies nothing.** `controlplane/overlays/prod-cp` mounts one volume into the
control-plane pod — the custody-snapshot PVC — and sets `GITFROK_CUSTODY_OPENBAO_ADDR`,
`_TRANSIT_MOUNT`, `_KUBERNETES_ROLE`, `_KEY_NAME`, `_SNAPSHOT_FILE`. There is no CA mount and no
CA-bearing environment variable, because no such variable is defined.

**5. This was never exercised, anywhere, which is why it survived every gate.** `deploy/dev` serves
custody with `tls_disable = true` and the control plane dials `http://127.0.0.1:8200` with
`GITFROK_CUSTODY_ALLOW_LOOPBACK_HTTP=true`. So the *only* composition that has ever talked to custody
did so over plain HTTP. `validateAddress` has always required `https` outside loopback; nothing had
ever taken that branch against a real server.

**6. And the escape hatch is deliberately, correctly sealed.**
`scripts/test-platform-kustomize.sh` fixture `loopback-http` asserts *"AC8 — dev's plain-http custody
relaxation travelling to production"* is refused. That gate is right and this ADR does not ask to
weaken it. But it means both doors are shut at once: production may not use the dev relaxation, and
production cannot supply a CA. **There is no working production configuration**, and the two halves
were authored by different tasks, each correct on its own.

The failure this produces is a TLS verification error from the agent door at first custody call —
which reads as a network or certificate-provisioning fault, not as the missing-feature it is.

## Decision

**1. The custody client gains an explicit CA option.** `custody.Config` gains a `CAFile` (path to a
PEM bundle), read at construction and used to build a `tls.Config` with that bundle appended to the
system pool. `NewOpenBao` keeps contacting nothing, so SPEC-0044 AC1's construction-from-
configuration property is untouched: a CA certificate is a public verification input, not key
material, and this remains a composition that holds references.

**2. The composition root reads it from `GITFROK_CUSTODY_CA_FILE`**, beside the six
`GITFROK_CUSTODY_*` variables that already exist. Empty means "system pool only", which keeps every
current composition — including dev's loopback HTTP — behaving exactly as it does now.

**3. Process-global environment variables are rejected as the mechanism.** `SSL_CERT_FILE` would be
the zero-code fix and is a trap: Go uses it *instead of* the default file list, so setting it drops
the public roots the control plane needs for every other TLS destination, and it does so silently.
`SSL_CERT_DIR` does compose additively and would work, but it retunes TLS for the whole process to
fix one client, and nothing would record why. An explicit option is assertable; an env var that
happens to work is not.

**4. The CA reaches the pod as its own Secret, `openbao-ca`, carrying `ca.crt` only.** Not the
existing `openbao-tls`: that Secret holds the server's private key, and the control plane has no
business mounting it. Per ADR-0099 decision 7 and SPEC-0069, **no installer authors it** — it is
operator-created out of band like the eight credentials already in that class, and it is the only
one of them that is not secret.

**5. Issuing the custody certificate from a publicly-trusted CA is rejected**, not deferred. The
names are cluster-internal; no public CA can sign them. Any proposal of this shape is really a
proposal to give OpenBao a public hostname, which ADR-0066 decision 6 forbids.

**6. A gate asserts the pair.** Whenever a rendered control-plane overlay sets a custody address
whose scheme is `https`, it must also mount a CA and set `GITFROK_CUSTODY_CA_FILE`. This is the
assertion whose absence let the gap exist: each half was independently correct and nothing checked
that they agreed.

## Consequences

- Step 4 becomes possible once images exist and OpenBao is unsealed. Until decisions 1–2 are built it
  is blocked regardless of those two, which is the fact `deploy/k8s/README.md` now records.
- **A `backend` change and a super-repo change, in that order, and never in one commit** (invariant
  23). Decisions 1–2 are `backend`; decisions 4 and 6 are the super-repo installer and its gate.
- The operator's out-of-band credential list grows from eight to nine. Its newest member is the only
  public one, which is worth saying in the runbook so nobody handles it as a secret and nobody treats
  the other eight as public by association.
- Rotating the custody CA becomes a two-sided operation — new `ca.crt` into the Secret, control plane
  restarted — with the same overlap discipline ADR-0044 already applies to release keys. Not solved
  here; named so the second rotation is not the first time anyone considers it.
- The dev composition does not change. It keeps its loopback-HTTP relaxation and keeps being refused
  in production by the existing fixture.

## Alternatives considered

- **`SSL_CERT_FILE` on the container.** Zero code. Rejected under decision 3: it replaces rather than
  augments the root set, breaking unrelated TLS silently.
- **`SSL_CERT_DIR` on the container.** Zero code and additive, so it does work. Rejected as a
  *decision* rather than as a mechanism: it is invisible at the call site, and the next reader of the
  custody adapter sees a plain `http.Client` and correctly concludes it verifies against system
  roots.
- **Bake the CA into the control-plane image.** Makes the trust store a build-time input, so rotating
  the CA requires a new signed release of every first-party image. Rejected: it couples a cluster's
  private trust material to an artifact ADR-0098 publishes publicly.
- **`InsecureSkipVerify` for the in-cluster hop.** Rejected outright. The custody channel is the one
  that signs agent certificates; an unauthenticated peer there is the whole of ADR-0066 undone.
- **cert-manager issuing `openbao-tls` from a cluster issuer.** Changes who *generates* the
  certificate and not who can *verify* it — the issuer's CA is still private and still has to reach
  the control plane. Compatible with this ADR rather than an alternative to it, and left open below.

## Open questions

- **Who generates the custody CA in steady state?** Today it is the operator, out of band. cert-manager
  with a cluster-internal issuer would automate issuance and renewal and would still need decisions
  1–2 to be usable. Worth its own ADR if the answer is yes.
- **Does the data plane have the same gap?** ADR-0066 puts custody control-plane-side and
  `check-custody-service.sh` asserts no data-plane surface references it, so the answer should be
  "not applicable" — but that is an argument, not an assertion, and the gate checks references rather
  than transport.
