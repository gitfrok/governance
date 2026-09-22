# SPEC-0073: A data-plane BFF logs people in, through its own plane

- **Status:** Implemented (2026-09-23) — AC1–AC6 met at bff@14adef6 and super-repo; AC6 shown on the dev cluster
- **Owner:** unassigned
- **Context(s):** BFF (`bff/cmd/bff`, `bff/internal/plane`); dev deployment (`deploy/dev`)
- **ADRs:** 0102 (**Accepted 2026-09-23** — decisions 1, 2 and 5 are this spec), 0094 (decisions 3 and
  4 — the route partition this amends for login only), 0100 (decision 1, unamended), 0052 (decision 4
  — a configured store that cannot be reached is fatal), 0011 (no cross-plane call), 0001
- **Amends:** SPEC-0070's route partition in one respect: the login routes become served on the
  data plane too. SPEC-0070 AC5's *coarse 404 for an unmatched repository path* is preserved.
- **Task(s):** T-0093 (bff, then super-repo)

## Problem / context

Measured on the dev cluster on 2026-09-23: a data-plane BFF answers `404` on `/login`, and no plane
value produces a working login. The route partition mounts the login surface only in the
control-plane branch, and the control plane's backend door does not register `OIDCLogin`.

ADR-0102 decides the data plane authenticates for itself against the shared issuer. **The wiring is
already half there**: in `cmd/bff/main.go` the OIDC client is built on `metaConn`, which *is* the
data-plane door on a data-plane deployment, and `cmd/dataplane-app` registers `OIDCLogin` on that
door. What is missing is the route, and ADR-0102 decision 5's refusal to run without a durable store.

## In scope

- Serving the three login routes on a data-plane BFF.
- Refusing to start a data-plane BFF whose session store is not Valkey.
- Proving the full OIDC roundtrip through the data-plane BFF on the dev cluster.

## Out of scope

- **Production.** No `deploy/k8s` change: the `prod-dp` Valkey, a data-plane OIDC client
  registration, and whether that client is per-tenant or per-install (ADR-0102 follow-ups). Owner rule,
  2026-09-23: deploy and test on minikube only.
- The control plane's login, which stays as it is (ADR-0102 decision 4).
- Cross-plane session revocation (ADR-0102's third cost).

## Acceptance criteria

- [x] **AC1** A data-plane BFF serves `GET /login`, `GET /callback` and `POST /logout`.
- [x] **AC2** A data-plane BFF registers **no** `/` catch-all. An unmatched path still gets the
      router's coarse `404`, never a redirect into a login flow (SPEC-0070 AC5 preserved).
- [x] **AC3** The data-plane login goes through the data plane's own door only. The OIDC client is
      built on the data-plane connection, and a data-plane deployment still refuses a control-plane
      address (`internal/plane`, unchanged) — so there is nothing to call across.
- [x] **AC4** A data-plane BFF refuses to start unless `GITFROK_SESSION_STORE=valkey` — unset and
      `memory` both refuse, naming ADR-0102 decision 5. The control plane's choice is unchanged.
- [x] **AC5** The control plane still owns the `/` catch-all, and the two planes' registered patterns
      stay disjoint.
- [x] **AC6** On the dev cluster, `scripts/dev-provision.sh`'s OIDC roundtrip through the BFF
      completes: `/login` reaches the issuer, the callback establishes a session, and an authenticated
      request is answered for the logged-in principal.

## Tests to write first

AC1, AC2 and AC5 extend `cmd/bff/partition_test.go`, which already asserts the partition over the
source. AC4 is a function in `internal/plane` with a table test, written failing against the absent
function. AC6 is the dev cluster, not a unit test — it is the thing that was broken.

## Evidence (2026-09-23)

- **AC1–AC5**: `cmd/bff/partition_test.go` and `internal/plane/plane_test.go`, written first and seen
  failing (missing routes; undefined `RequireSessionStore`). Two mutations each caught: a `/`
  catch-all on the data plane, and a store check that accepts anything.
- **AC6**, on minikube with the podman driver: `GET /login` → `302` to the issuer with the recorded
  client id; unmatched paths `404`; `dev-provision.sh` exits 0 with its BFF roundtrip; the session in
  Valkey carries `tenant_id=dev`, the admin's actor id and `actor_roles=[owner]`; and
  `GET /v1/repositories` answers `404` without the session and `200` with it.

**Found on the way, not in this spec:** AC6's first attempt got a correct session that could read
nothing. `dev-provision.sh` had never applied seven module migrations (repository ×3, codereview,
release, notifications, ci); fixed in the super-repo. And `GET /v1/notifications` is denied for every
principal regardless of login — T-0094.
