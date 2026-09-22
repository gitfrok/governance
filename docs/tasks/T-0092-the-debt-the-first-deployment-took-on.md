# T-0092: The debt the first real deployment took on

- **Status:** Todo — filed 2026-09-23, unowned. **This is a ledger, not a plan.** Each item below is
  a thing the live deployment does that the tree says it should not, or does not say at all. Several
  want their own task; the point of one file is that none of them is discovered twice.
- **Phase / Epic:** first production deployment (ADR-0106 / ADR-0107 carry)
- **Repo(s):** **several, and never in one commit** (invariant 23). Each item names its own.
- **ADRs:** 0107 (Accepted 2026-09-23 — items 1 and 2 are its own follow-ups), 0047, 0044, 0035, 0034, 0098,
  0095, 0099, 0066, 0101
- **Owner:** unassigned

## Why this file exists

A deployment that works is the point at which shortcuts stop being visible. Everything here was
taken knowingly, during the bring-up that first made `git clone` work against
`git-gitfrok.7.solutions` on 2026-09-23. None of it is a surprise and none of it is recorded
anywhere else.

## 1. No gate reads `deploy/k8s/dataplane/` — super-repo

`make verify` runs eleven checks and not one of them looks at the newest overlay, which is also the
**only one that opens a port to the internet**. `check-platform-kustomize.sh` and
`check-controlplane-kustomize.sh` are hard-coded to their own trees (`PLATFORM_OVERLAYS` / `CP_OVERLAY`
exist only so their fixtures can run). So the data-plane overlay gets no `secretGenerator` walk, no
authored-Secret refusal, no `storageClassName` assertion, and no image-pin report.

It happens to render no Secret and to state its storage class. **Nothing checks either**, and the two
existing gates each needed a task and a failability proof before anyone believed them.

## 2. A PAT does not survive a data-plane restart — `backend`, needs a spec

**Measured on the live cluster, not inferred.** Issue a PAT, clone successfully, then
`kubectl rollout restart deploy/dataplane`; the same PAT then fails with `remote: authentication
required`. Every user's Git credential dies with every restart — a node upgrade, an eviction, a
scale-down, a deploy.

The cause is one line. `backend/cmd/dataplane-app/main.go:240`:

```go
authenticator = identity.NewInMemory(frontCfg.patKey, dp.policy)
```

unconditionally — while the two compositions immediately below it **do** branch on the pool:

```go
grants  = identity.NewAuditorGrantsPostgres(dbPool, ...)   // line 401, with an in-memory fallback
members = identity.NewDirectory(dbPool)                     // line 415, with an in-memory fallback
```

So this is not a missing environment variable, and setting `GITFROK_DATABASE_URL` does not help —
this composition never consults the pool at all.

**The Postgres-backed authenticator already exists and nothing calls it.**
`backend/modules/identity/module.go:42` exports

```go
func NewPostgres(pool *db.Pool, activeKeyID string, keys map[string][]byte, pdp policyapi.DecisionPoint) api.Authenticator
```

backed by `internal/adapters/postgres/store.go`, and a tree-wide search finds no non-test caller. The
`identity.credentials` table exists on both production clusters (migration
`0001_identity_credentials.sql`). So this is unfinished wiring, not an undesigned feature.

**It is not a one-line change, which is why it needs a spec rather than a patch.** `NewPostgres`
takes an `activeKeyID` and a **map** of key IDs to keys — a rotation surface — while `NewInMemory`
takes a single `[]byte` from `GITFROK_PAT_VERIFIER_KEY`. Selecting the durable store therefore means
deciding a multi-key configuration format and what happens to tokens signed under a retired key.
That is a decision, and invariant 12 says it gets an ADR or a spec, not an implementer's guess.

`scripts/dev-provision.sh` and `north-star.sh` both describe this as a dev property ("the data
plane's identity store is the in-memory composition"). It is not a dev property; it is the
composition in every deployment, and in production it is the difference between a credential and a
session.

## 3. The images bypass all three of ADR-0047's gates — super-repo / CI

`bff`, `controlplane-app`, `webfrontend`, `dataplane-app` and `git-storaged` at `0.1.0` were built
with podman and pushed by hand during bring-up. Consequences, stated rather than implied:

- **Unsigned.** No cosign signature, so ADR-0044's verify-before-apply has nothing to verify.
- **`0.1.0` is burned.** The registry has `immutableTags`, so the publish workflow cannot reuse that
  tag. The next real publish needs a new version, or the tag deleted deliberately.
- **No `.release` manifest**, which is why both overlays pin by **tag and not digest** and say so on
  their own output line. ADR-0096 decision 9's AC5 is NOT met on either plane and is not silently
  passed.

Related and pre-existing: `deploy/releases/dataplane-app-0.1.0.release` and `operator-app-0.1.0.release`
still reference `docker.io/gitfrok/*`, which ADR-0098 decision 4 retired.

## 4. Database migrations are a manual step nothing owns — super-repo, probably a gate

Both production `gitfrok` databases had **zero tables** until 2026-09-23. Twelve migrations, applied
by hand with `kubectl exec ... psql`. No installer applies them, no gate asserts them, and
`deploy/k8s/README.md`'s Secret table — the closest thing to an operator checklist — does not mention
them.

The failure mode is quiet: `policy.Decide` **fails closed** without `policy.decision_records`, so a
plane on an unmigrated database denies every protected action rather than reporting a missing table.

## 5. `scripts/openbao-operator.sh` is unproven against a real barrier — super-repo

Its `wire` and `unseal` paths have **never run**, because the barrier is still uninitialised and
initialising it is the share-holder's act. What *was* proven, against the live sealed barrier: that
`bao status` exits **2** when sealed and that its JSON keys are lowercase — two bugs that would each
have failed the ceremony at the moment it mattered. The rest is read, not run. Say so when it is
first used, and record what it got wrong.

Related: **MVP-RUNBOOK §6a claims the share shape is recorded on the StatefulSet**
(`custody.gitsaas/key-shares`, `custody.gitsaas/key-threshold`) "so this command and the deployment
assertion cannot drift apart". Those annotations do **not exist** in
`deploy/k8s/platform/base/openbao/`. The drift the runbook says is impossible is unprevented.

## 6. Every OpenBao restart re-seals, and that is an availability design question — needs an ADR

Shamir + Raft with no auto-unseal (ADR-0066 decision 4) means **every** pod restart takes custody
down until a human assembles three of five shares. On a zonal `min_nodes=2 / max_nodes=4` pool that
is every node upgrade, every eviction and every scale-down — not an incident, a Tuesday.

T-0084 AC9 is already recorded as false: workloads **crash-loop** on a sealed barrier rather than
reporting unready, which is what the control plane is doing right now.

KMS auto-unseal is the standard answer and **contradicts ADR-0066 decision 4 as written**. That is a
decision for the owner, not a fix for an implementer, and it is the single largest gap between this
deployment and something operable as a SaaS.

## 7. Repository creation and credential issuance have no tenant-facing path — `backend`

Creating a repository is `kubectl exec` into `git-storaged` and `git init --bare`; the `git/v1`
contract has no create-repository RPC. Issuing a PAT is a port-forward plus `grpcurl`. Both are
operator actions. **"Ready to use" is therefore true for an operator and not for a tenant**, and that
distinction should not have to be rediscovered from a runbook.

## 8. Login is unreachable for everyone — two independent causes

Recorded here because either one alone is enough, and fixing only one changes nothing.

- **No Login V2 service.** Every OIDC authorize redirects to `/ui/v2/login/login`, which returns
  **404**. `deploy/dev/zitadel-login.yaml` exists; `deploy/k8s/platform/base/zitadel/` has no
  equivalent, and none of `ZITADEL_FIRSTINSTANCE_LOGINCLIENTPATPATH`,
  `ZITADEL_FIRSTINSTANCE_ORG_LOGINCLIENT_MACHINE_USERNAME` or
  `ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_*` is set in production. Because `FirstInstance` has
  already run, the login-client machine user and its PAT cannot be created by adding environment
  variables now.
- **The control plane cannot serve OIDC login at all, by design.**
  `backend/cmd/controlplane-app/bffdoor.go` registers three services and states it: *"OIDCLogin is
  the fourth service ADR-0100 decision 1 assigns here and it is NOT registered ... no verifier
  configuration on this plane."* `RegisterOIDCLogin` is called only in `cmd/dataplane-app`. So
  `app-gitfrok.7.solutions`, served by the **control plane's** bff and webfrontend, returns 401
  `login failed` from `/callback` no matter what Zitadel is doing. ADR-0094 decision 3 already moved
  the repository surface data-plane-side; the browser surface has not followed.

## 9. TLS is now three different mechanisms — ADR-0095 wants amending

| host | origin certificate | edge |
|---|---|---|
| `app-gitfrok`, `auth-gitfrok` | **Let's Encrypt via cert-manager** (ADR-0095 decision 7's own mechanism) | Cloudflare proxied |
| `git-gitfrok`, `gitfrok` | **Google-managed**, Certificate Manager (ADR-0107 decision 3, ADR-0108) | DNS-only |
| `agents-gitfrok` | custody-minted, CA-pinned | DNS-only, never proxied |

The first row was self-signed-behind-Cloudflare until 2026-09-23 and is now what decision 7 asked
for. The second is not decision 7's mechanism and ADR-0107 says why. **ADR-0095 decision 7 should be
amended to describe all three**, because "ACME at the origin" now under-describes the tree.

Also: the Cloudflare zone is on **Full**, not **Full (strict)**. Both proxied origins now present
real certificates, so strict is available — but the setting is zone-wide and this zone serves hosts
outside this project, so it is the zone owner's call and not a tidy-up.

## 10. The `_acme-challenge` CNAMEs are load-bearing and ungated — super-repo / operations

The Certificate Manager DNS authorization CNAMEs — `_acme-challenge.git-gitfrok` and, since
ADR-0108, `_acme-challenge.gitfrok` — are what let the Git door's two certificates renew.
Deleting it breaks renewal **months later and silently**. Nothing in this tree records that the
record exists, and the Cloudflare console will not say what it is for.

## 11. The Git door's infrastructure is not in OpenTofu — super-repo (`deploy/gcp`)

ADR-0092 makes OpenTofu the provisioner of this tree's infrastructure. Everything that publishes the
Git door was created by hand with gcloud on 2026-09-23: the global address `prod-dp-git-gateway`, the
Certificate Manager DNS authorizations (`git-gitfrok-dnsauth`, `gitfrok-apex-dnsauth`), certificates
(`git-gitfrok-cert`, `gitfrok-apex-cert`) and map (`gitfrok-dp-certmap`). So `terragrunt destroy`
leaves the address billing, a rebuild does not recreate any of it, and
`deploy/gcp/modules/addresses` is still instantiated for `prod-cp` only. `deploy/TEARDOWN-RUNBOOK.md`
step 4a now lists the manual deletions, which is a stopgap, not the fix. The fix is a `prod-dp`
addresses unit (or the existing module with `gateway = true`) plus Certificate Manager resources,
imported rather than recreated so the certificates do not re-issue.

## 12. The repository volume violates ADR-0106 decision 4 — super-repo

ADR-0106 decision 4 (Accepted): *"When the git tier lands it must declare its own `premium-rwo`
claim."* It landed on 2026-09-23 as `standard-rwo`, and the manifest comment at the time presented
that as correct. It is not.

`storageClassName` is **immutable** on a PVC, so this is a migration rather than an edit: scale
`git-storaged` to zero, copy the bare repositories out (`tenant/`-rooted, currently `dev/hello.git`
and `7solutions/welcome.git`), delete the claim, re-apply with `premium-rwo`, copy back, scale up.
Git is down for the duration and **the copy must be verified before the old claim is deleted** — it
holds a tenant's only copy. Changing the manifest line alone makes the next `kubectl apply` fail.

Related and also unmet in production: **PR-6** (a push is acknowledged only after the primary and one
synchronous replica hold it). There is one `git-storaged` node and one volume.

## Definition of Done

There isn't one, and that is deliberate: this file is closed by being emptied into real tasks, not by
being worked. **Items 2, 6 and 12 are the ones that make the product wrong rather than incomplete**, and
they are the ones to schedule first.
