# T-0090: The installer mounts the custody CA, and a gate keeps the pair together

- **Status:** Todo
- **Phase / Epic:** first control-plane deployment (ADR-0104 carry)
- **Repo(s):** super-repo
- **Spec:** `../specs/SPEC-0071-custody-tls-trust.md` (AC8–AC12)
- **ADRs:** 0104 (Accepted 2026-09-22 — decisions 4, 6), 0099 decision 7 + SPEC-0069 (no installer
  authors a Secret), 0096, 0066
- **Owner:** unassigned
- **Blocked by:** T-0089 — this task sets an environment variable that task teaches the binary to
  read. Landing it first is harmless and proves nothing.

## Goal

Mount the operator-created `openbao-ca` Secret into the control-plane pod, point
`GITFROK_CUSTODY_CA_FILE` at it, and add the gate whose absence let ADR-0104's gap exist: an `https`
custody address and a mounted CA must travel together.

## Acceptance criteria (test-first)

- [ ] AC8 `controlplane/overlays/prod-cp` mounts `openbao-ca`'s `ca.crt` read-only and sets
      `GITFROK_CUSTODY_CA_FILE` to that path. Asserted over the **rendered** output.
- [ ] AC9 No installer authors `openbao-ca` — referenced only. No `secretGenerator`, no literal, no
      `stringData`.
- [ ] AC10 The installer mounts `openbao-ca` and **not** `openbao-tls`. Refused by name.
- [ ] AC11 `check-controlplane-kustomize.sh` fails a rendered overlay with an `https` custody address
      and either no CA mount or no `GITFROK_CUSTODY_CA_FILE`. Negative fixture per half; a positive
      case proves a loopback-`http` composition does not trip it.
- [ ] AC12 `deploy/k8s/README.md` lists `openbao-ca` in the out-of-band credential list, stating it is
      the only public one.

## Tests to write first

- **fixtures (`scripts/test-controlplane-kustomize.sh`), before the gate logic** — three new cases:
  `https-no-ca-mount` refused, `https-no-ca-env` refused, and `loopback-http-no-ca` **accepted**. The
  third is the one that matters: a gate written from the two refusals alone will happily fail dev.
- **fixture (AC10)** — an overlay mounting `openbao-tls` in place of `openbao-ca` is refused. It would
  otherwise work at runtime, which is exactly why it needs a named refusal rather than a convention.
- **gate assertion over rendered output (AC8/AC9)** — render, then assert; never grep the source
  text. Both existing kustomize gates were tripped by their own explanatory comments when they
  grepped source, and that history is why this rule is written down.
- **`make verify` at the end** — `check-controlplane-kustomize.sh` and its failability proof run
  beside each other there, deliberately.

## Definition of Done

See `../process/definition-of-done.md`. Plus: `make verify` green in the super-repo, one commit in
the super-repo only (invariant 23), and the pin bump for T-0089's backend commit as its own commit.

## Notes / open questions

**This task does not create the Secret and must not.** ADR-0099 decision 7 and SPEC-0069 hold: the
operator creates it out of band, like the eight already in that class. A `secretGenerator` here would
put a certificate in git — harmless in itself, since a CA certificate is public — and would break the
property the gate exists to protect, which is that *no installer authors a Secret at all*. The
exception that looks safe is the one that ends the rule.

**Applying this to the live `prod-cp` cluster requires the operator to create `openbao-ca` first**,
from the CA that signed the running `openbao-tls`. Until then the overlay renders and gates cleanly
but will not start — which is correct, and is the same shape as the other eight credentials.

**AC11 is the whole point of the task.** ADR-0104's gap was two independently correct halves that
nothing checked agreed. A gate that only asserts AC8 restates what the overlay already says; the
assertion that earns its place is the conditional one.
