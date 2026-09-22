# SPEC-0071: The control plane can verify the custody certificate

- **Status:** Approved (2026-09-22)
- **Owner:** unassigned
- **Context(s):** agent / custody (the composition and its installer — the signing behaviour itself is
  unchanged)
- **ADRs:** 0104 (**Accepted 2026-09-22** — decisions 1, 2, 3, 4, 6 are the inputs; decision 5 is a
  refusal this spec must not quietly reopen), 0066 (custody is OpenBao transit, control-plane-side),
  0035 (`FROM scratch` images — why the trust store is one file), 0099 decision 7 + SPEC-0069 (no
  installer authors a Secret), 0096 (Kustomize-only installers), 0044 (SPEC-0044 AC1: the CA holds
  references, never material)
- **Task(s):** T-0089 (backend, AC1–AC7), T-0090 (super-repo, AC8–AC12)

## Problem / context

ADR-0104 records that `apply -k deploy/k8s/controlplane/overlays/prod-cp` fails at TLS to custody,
because `openbao-tls` is necessarily privately signed and nothing can hand the control plane that CA.
This spec says what "can verify" means in testable terms.

**The failure mode this spec exists to prevent is not the missing feature — it is a silent fallback.**
A CA option that quietly degrades to the system pool when its file is missing, unreadable or malformed
reproduces exactly today's bug while appearing configured: the deployment looks correct, the gate
passes, and the first custody call fails with a TLS error that names a certificate rather than a
configuration. AC4 is therefore the criterion this spec is really built around, and AC2 is its twin —
an option that *replaces* the root set rather than appending to it breaks every other TLS destination
the control plane has, equally silently. Those two are why ADR-0104 decision 3 refused the zero-code
`SSL_CERT_FILE` route, and a test that only proves "custody dial succeeds" would pass over both.

The second trap is scope. ADR-0104 decision 5 rejects publicly-trusted issuance outright, and
ADR-0066 decision 6 forbids giving OpenBao a public hostname. Nothing here may relax
`validateAddress`, widen the loopback-HTTP relaxation, or introduce `InsecureSkipVerify` on any path.

## In scope

- An explicit CA-bundle option on the custody client, and the composition root that supplies it.
- The `openbao-ca` Secret's consumption by the control-plane installer.
- A gate asserting that an `https` custody address and a mounted CA always travel together.
- Naming `openbao-ca` in the operator's out-of-band credential list.

## Out of scope

- **Who generates or rotates the CA.** Operator-created, out of band; cert-manager is an open ADR
  follow-up, not this spec.
- **The data plane.** ADR-0066 keeps custody control-plane-side and `check-custody-service.sh` asserts
  no data-plane surface references it.
- **Any change to signing, enrolment, transit, or the dev composition's behaviour.**
- Creating the Secret in any installer, which ADR-0099 decision 7 forbids.

## Contracts touched

None. No gRPC service, no event, no proto. This is a composition and installer change.

## Data owned

None. A CA certificate is a public verification input; no schema, no row, no context boundary moves.

## Acceptance criteria (each becomes a test)

**Backend — T-0089**

- [ ] AC1 `custody.Config` carries a `CAFile` field. With it set to a PEM bundle, `NewOpenBao` returns
      a signer whose HTTP client verifies a server presenting a certificate chaining to that bundle.
      Proven against a real `httptest` TLS server with a throwaway private CA: the dial **succeeds**
      with `CAFile` set and **fails** with it unset. Both directions asserted, in one test.
- [ ] AC2 The bundle is **appended to** the system pool, never substituted for it. Proven by a
      resulting `RootCAs` subject count equal to the system pool's plus the test CA's, and by a
      second assertion that a certificate chaining to a *public* root still verifies while `CAFile`
      is set. A test proving only AC1 passes on an implementation that replaces the pool.
- [ ] AC3 `NewOpenBao` contacts nothing, with `CAFile` set exactly as without (SPEC-0044 AC1's
      construction-from-configuration property). Proven by constructing against an address with no
      listener and asserting a nil error.
- [ ] AC4 A `CAFile` that does not exist, cannot be read, or contains no parseable certificate is a
      **construction error naming the path**. It must not fall back to the system pool, and must not
      defer the failure to first call. Three separate negative cases: absent, unreadable, malformed.
- [ ] AC5 An empty `CAFile` leaves behaviour byte-identical to today: system pool only, dev's
      loopback-HTTP composition unchanged, and every existing custody test green unmodified.
- [ ] AC6 Setting both `CAFile` and `Client` is refused at construction. They are two ways to specify
      one transport, and silently preferring either is a configuration whose effect cannot be read
      off the composition.
- [ ] AC7 The composition root reads `GITFROK_CUSTODY_CA_FILE` and passes it to `Config.CAFile`;
      unset means empty means AC5. Asserted in `cmd/controlplane-app`'s custody-config test beside the
      six variables already covered.

**Super-repo — T-0090**

- [ ] AC8 `deploy/k8s/controlplane/overlays/prod-cp` mounts the `openbao-ca` Secret's `ca.crt`
      read-only into the control-plane pod and sets `GITFROK_CUSTODY_CA_FILE` to that path. Asserted
      over the **rendered** output, not the source text.
- [ ] AC9 No installer authors `openbao-ca`: it is referenced, never generated. No `secretGenerator`,
      no literal, no `stringData` — the assertion SPEC-0069 already makes for the other eight,
      extended to the ninth.
- [ ] AC10 The installer mounts `openbao-ca` and **not** `openbao-tls`. Mounting the Secret that holds
      the custody server's private key into the control plane is the obvious shortcut and is refused
      by name, because it would work.
- [ ] AC11 `check-controlplane-kustomize.sh` fails a rendered overlay whose custody address scheme is
      `https` while no CA is mounted or `GITFROK_CUSTODY_CA_FILE` is unset — the pairing whose absence
      allowed ADR-0104's gap. Proven failable by negative fixtures for each half separately, and a
      positive case asserting a loopback-`http` composition does **not** trip it.
- [ ] AC12 `deploy/k8s/README.md` lists `openbao-ca` among the credentials an operator creates out of
      band, stating that it is the only public one — so it is neither handled as a secret nor used to
      infer the other eight are not.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | The custody channel signs agent certificates; an unverified peer there is ADR-0066 undone. AC1/AC4 make verification real rather than nominal, and nothing here widens the loopback relaxation |
| G4 change governance | Implements an Accepted ADR rather than deciding anything; AC11 turns decision 6 into a gate so the pairing cannot regress silently |
| G6 compliance | The custody CA becomes a declared, inspectable input instead of an undocumented assumption; AC10 keeps the server's private key out of the control plane |
| Operability | AC4 converts a first-call TLS error into a start-up error naming a path; AC12 puts the ninth credential where the operator already reads the other eight |

## Non-functional

- No measurable latency change: the pool is built once at construction, not per call.
- No new dependency. `crypto/x509` and `crypto/tls` are already in the module graph.
- The image stays `FROM scratch` (ADR-0035); the CA arrives as a mount, never a layer.

## Open questions / assumptions

- **Assumed:** `x509.SystemCertPool()` on the `scratch` image returns the copied
  `ca-certificates.crt`, so AC2's "appended" is meaningful there and not only on a developer laptop.
  This is an assumption about the image and must be asserted by AC2's test rather than taken on trust;
  if it turns out `SystemCertPool()` is empty in that image, AC2 still holds but its subject-count
  arithmetic changes, and that is a finding worth recording rather than adjusting around.
- **Deliberately unanswered:** rotation. ADR-0104's consequences name it and the ADR register carries
  it as a follow-up. A CA swap today is "update the Secret, restart the control plane", with no
  overlap window — acceptable while the CA is generated once per cluster, and the wrong answer the
  moment it is automated.
- **Ordering:** T-0090 sets an environment variable that T-0089 teaches the binary to read. Applying
  the installer first is harmless but proves nothing, so T-0089 lands first.
