# T-0089: The custody client can be given a CA, and refuses to guess

- **Status:** Done (2026-09-22) — backend@7a8dccd; AC1–AC7 met
- **Phase / Epic:** first control-plane deployment (ADR-0104 carry)
- **Repo(s):** backend
- **Spec:** `../specs/SPEC-0071-custody-tls-trust.md` (AC1–AC7)
- **ADRs:** 0104 (Accepted 2026-09-22 — decisions 1, 2, 3), 0066, 0044/SPEC-0044 AC1, 0035
- **Owner:** unassigned

## Goal

Give `custody.Config` an explicit `CAFile`, wire it from `GITFROK_CUSTODY_CA_FILE`, and make every
way of getting it wrong a loud construction error instead of a quiet fallback to the system pool.

Nothing about signing, enrolment or transit changes. `validateAddress` is not touched: `https`
outside loopback stays mandatory, and the loopback-HTTP relaxation keeps its exact current scope.

## Acceptance criteria (test-first)

- [x] AC1 `Config.CAFile` set → the client verifies a server chaining to that bundle; unset → it does
      not. Both directions, against a real TLS `httptest` server with a throwaway CA.
- [x] AC2 The bundle is **appended** to the system pool, not substituted. A public-root certificate
      still verifies while `CAFile` is set.
- [x] AC3 `NewOpenBao` still contacts nothing when `CAFile` is set (SPEC-0044 AC1).
- [x] AC4 Absent, unreadable, and malformed `CAFile` are each a construction error naming the path —
      three cases, no fallback, no deferral to first call.
- [x] AC5 Empty `CAFile` is byte-identical to today; every existing custody test passes unmodified.
- [x] AC6 `CAFile` and `Client` both set is refused at construction.
- [x] AC7 `cmd/controlplane-app` reads `GITFROK_CUSTODY_CA_FILE` into `Config.CAFile`; unset → empty.

## Tests to write first

- **unit (`modules/agent/internal/adapters/custody`)** — AC1 as one test asserting both directions;
  a separate test per AC4 case, each asserting the error mentions the path; AC6 as a construction
  refusal. AC1/AC4 must be written and **seen to fail** before the field exists, or they will be
  written to fit whatever gets built.
- **unit, pool composition (AC2)** — assert the resulting `RootCAs` subject count is the system
  pool's plus one, and that a public-root certificate still verifies. This is the test that
  distinguishes "appended" from "replaced"; an AC1-only suite passes on the broken implementation.
- **unit (AC3)** — construct against an address with no listener; assert nil error and no dial.
- **unit (`cmd/controlplane-app/custodyconfig_test.go`, AC7)** — beside the six variables already
  covered, including the unset case.
- **regression (AC5)** — the existing custody suite, unmodified. If a test needs changing to pass,
  that is a finding, not a fixup.

## Definition of Done

See `../process/definition-of-done.md`. Plus: `make verify` in `backend` green with `-race`, and one
commit in `backend` only (invariant 23) — the installer half is T-0090.

## Notes / open questions

**Do not reach for `SSL_CERT_FILE` or `SSL_CERT_DIR` if the tests get awkward.** ADR-0104 decision 3
rejected both, the first because Go uses it *instead of* the default file list and would silently drop
every public root. That refusal is the decision, not a preference.

**AC2's arithmetic depends on `x509.SystemCertPool()` being non-empty in a `FROM scratch` image
carrying one `ca-certificates.crt`.** SPEC-0071 records this as an assumption to be asserted rather
than trusted. If the pool comes back empty there, AC2 still holds — append is still append — but say
so in the exit record instead of adjusting the assertion until it passes.

**`Config.Client` stays.** It is the composition-root injection point the in-process wire tests use;
AC6 refuses only the *combination*, because two ways to specify one transport is a configuration
nobody can read off the composition.

## Exit record (2026-09-22, backend@7a8dccd)

All seven criteria met. `go test ./... -race` green across `backend` with **zero skips**;
`go vet`, `gofmt`, `check-dep-direction.sh` and `check-custody-service.sh` clean.

**AC2's first test was unsound, and the spec's recorded assumption is why it was caught.**
SPEC-0071 said to report rather than design around the question of whether
`x509.SystemCertPool()` is non-empty. It fired immediately: on darwin — and any platform using
lazy platform verification — `Subjects()` returns nothing, so the subject-count assertion read
"system + 1" and "nothing + 1" as the same number, and a mutant that **substituted** the system
pool **passed**. The assertion is now `CertPool.Equal` against a system pool with the same CA
appended, which compares system-pool provenance as well as contents and holds on every platform,
asserted in both directions so a pool that never received the CA fails too.

**Both critical assertions are mutation-proven**, not merely green:

| Mutation | Models | Result |
|---|---|---|
| `caPool` returns a fresh pool | `SSL_CERT_FILE`'s substitution (ADR-0104 decision 3) | `FAIL TestCAPoolAppendsToTheSystemPool` |
| `caPool` falls back to the system pool on a read error | ADR-0104's original bug wearing a CA option | `FAIL TestCAPoolRefusesUnusableFiles`, `FAIL …FailuresAreConstructionErrors/absent` |

**One thing the ACs did not name.** `KubernetesAuth` performs its own login call to the same
https address with its own client, so a CA reaching only the transit signer would have failed one
call earlier — same outage, less obvious cause. `CAFile` is on `KubernetesAuth` too and
`CustodyCAConfig` feeds both. Covered by `TestKubernetesAuthCAFileVerifiesTheServer`. Worth noting
for SPEC-0071's own record: the ACs were written from the adapter's `Config` and missed a second
dial in the same package.

**Nothing was relaxed.** `validateAddress` still demands https outside loopback, the loopback
relaxation keeps its exact scope, no `InsecureSkipVerify` exists on any path, and no existing test
was modified to pass.
