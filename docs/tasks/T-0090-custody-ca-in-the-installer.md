# T-0090: The installer mounts the custody CA, and a gate keeps the pair together

- **Status:** Done (2026-09-22) — super-repo@a3d59c3; AC8–AC12 met
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

- [x] AC8 `controlplane/overlays/prod-cp` mounts `openbao-ca`'s `ca.crt` read-only and sets
      `GITFROK_CUSTODY_CA_FILE` to that path. Asserted over the **rendered** output.
- [x] AC9 No installer authors `openbao-ca` — referenced only. No `secretGenerator`, no literal, no
      `stringData`.
- [x] AC10 The installer mounts `openbao-ca` and **not** `openbao-tls`. Refused by name.
- [x] AC11 `check-controlplane-kustomize.sh` fails a rendered overlay with an `https` custody address
      and either no CA mount or no `GITFROK_CUSTODY_CA_FILE`. Negative fixture per half; a positive
      case proves a loopback-`http` composition does not trip it.
- [x] AC12 `deploy/k8s/README.md` lists `openbao-ca` in the out-of-band credential list, stating it is
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

## Exit record (2026-09-22, super-repo@a3d59c3)

All five criteria met. `make verify` 0; `cp-kustomize-test` went from 10 assertions to **14**, all
proven failable, the real tree accepted, and — new — a positive fixture accepted.

**The fixtures were decorative on their first writing, and reading exit codes would have hidden it.**
All three new negative fixtures were refused by the gate *before the rule existed*. Not because it
caught them: `check-controlplane-kustomize.sh` derives the environment name from the overlay's
basename, so a fixture directory named `https-no-ca-mount` trips three AC8 "this environment has no
addresses unit" violations on its own name. `expect_refusal` reads only the exit status, so they
looked like proof. Each fixture is now nested under a `prod-cp/` directory and produces exactly one
violation — its own — verified by reading the violation text:

| Fixture | Sole violation |
|---|---|
| `https-no-ca-mount/prod-cp` | AC11 — `GITFROK_CUSTODY_CA_FILE` set, no volumeMount covers the path |
| `https-no-ca-env/prod-cp` | AC11 — https address, `GITFROK_CUSTODY_CA_FILE` unset |
| `custody-ca-from-tls-secret/prod-cp` | AC10 — CA mounted from `openbao-tls` |
| `loopback-http-no-ca/prod-cp` | *accepted* — the gate does not over-fire on dev's posture |

**The same weakness is pre-existing in T-0084's nine fixtures, and was NOT fixed here.** Checked
individually rather than assumed: **eight of the nine do still produce their own intended violation**,
so the suite is sound in substance today. But because `expect_refusal` reads only the exit status,
any of those eight would keep passing if the assertion it names silently broke, as long as AC8 keeps
firing on the directory name.

**The ninth, `wrong-address-name`, proves nothing at all.** Its defect is a typo'd Gateway address
(`gitfrok-gateway-typo`), and the name the gate expects is derived from the fixture's own directory
name — so it is refused identically with or without the typo, exactly as the un-nested new fixtures
were. It is a passing assertion about nothing.

That is SPEC-0067 AC10's territory rather than this task's, so it is recorded as a follow-up instead
of being widened into. The fix is mechanical and this task demonstrates it: nest each fixture under
`prod-cp/` so the environment name resolves, leaving one violation per fixture.

**AC11 is conditional, and the positive fixture is what keeps that honest.** A rule demanding a CA
unconditionally would refuse dev's loopback-http composition and make it ungateable. The harness had
no way to assert non-over-firing at all, so it gained `expect_acceptance`.

**AC10 is matched by `mountPath`, not by volume name** — the path is the contract the binary reads;
the name is a convention, and a gate that trusted the name would pass a volume renamed by anyone.

**Not yet applied to the live cluster**, correctly: `openbao-ca` does not exist on `prod-cp` until an
operator creates it from the CA that signed the running `openbao-tls`. The overlay renders and gates
clean; the Deployment will not start until the Secret exists, which is the same shape as the other
eight credentials.
