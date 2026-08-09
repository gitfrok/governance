# SPEC-0020: CI v0 job dispatch and isolated-runner contract

- **Status:** Draft
- **Owner:** platform
- **Context(s):** CI/CD, Repository/Git, Identity&Access, Policy, Audit
- **ADRs:** 0005, 0006, 0007, 0012, 0022, 0025
- **Task(s):** T-0017
- **PRD:** PR-12

## Problem / context

SPEC-0010 requires queue-driven, ephemeral gVisor jobs but does not define how a ref update becomes
one safe job, what a runner may receive, or when a sandbox is proven gone. Leaving those choices to
the runner would allow a shared worker, a mutable ref, an actor-supplied authorization result, or a
job that survives after its result. This specification defines the smallest CI v0 boundary before
the scheduler, runner, queue, and KEDA manifests are implemented.

## In scope

- An additive `contracts/proto/ci/v1/ci.proto` command/event surface for enqueueing, reading, and
  cancelling one immutable CI job, plus Repository/Git's `RefUpdated` trigger input.
- One v0 job declared by a repository's versioned `.gitfrok/ci.yaml` at the immutable new commit.
  The file permits exactly one container image reference and one argv command; matrix expansion,
  includes, reusable workflows, caches, services, and a general pipeline DSL are out of scope.
- A tenant-scoped job lifecycle `QUEUED → RUNNING → SUCCEEDED | FAILED | CANCELLED`, where every
  terminal outcome includes cleanup confirmation. A job/attempt is never reused.
- An ephemeral Kubernetes Job per attempt using the configured gVisor `RuntimeClass`; KEDA scales
  runner dispatch from the count of tenant-scoped `QUEUED` records and may scale to zero.
- A short-lived, single-job source-read capability issued only to the runner after queue admission.
  It is restricted to the immutable repository revision and expires on terminal cleanup. It is not
  a PAT, browser session, agent-stream field, event field, or reusable repository credential.
- PDP-gated enqueue/cancel actions and immutable audit evidence for accepted dispatch and terminal
  outcome. A ref trigger retains the verified actor context from `RefUpdated`; no event can assert
  a policy allow result.

## Out of scope

- A general pipeline language, multi-job DAG, cache/artifact product, secrets injection, external
  runner registration, privileged builds, host networking, Docker socket access, and build-image
  publishing.
- Kata/Firecracker selection, tenant billing/quotas, customer operator deployment, and browser UI.
- Running a repository revision different from the immutable ref SHA recorded at enqueue.

## Contracts touched

Additive `contracts/proto/ci/v1/ci.proto` defines `CIJobService` with
`EnqueueJob`, `GetJob`, and `CancelJob`, together with these invariant shapes:

- `JobContext` carries tenant ID, repository ID, verified actor ID, verified actor roles, and
  request ID. It is mandatory for commands and never carries source bytes, a credential, a
  filesystem path, a Kubernetes object, or an authorization result.
- `EnqueueJob` accepts a repository ref and immutable commit SHA. On a `RefUpdated` trigger the CI
  subscriber obtains both server-side and rejects a ref/SHA mismatch. Manual enqueue validates
  the ref resolves to the supplied SHA through Repository/Git before any queue write.
- `CIJob` contains opaque job/attempt IDs, tenant/repository IDs, ref, commit SHA, lifecycle state,
  timestamps, bounded outcome summary, and immutable configuration digest. It has no raw log,
  source, secret, pod name, node name, service-account token, or source-read capability field.
- `CancelJob` is idempotent and only requests cancellation. It reports terminal state after the
  runner deletes the sandbox and revokes the attempt capability; a cancelled queue record never
  launches a pod.

The event surface contains `CIJobQueued`, `CIJobStarted`, and `CIJobFinished`, each tenant-scoped
and keyed by opaque job/attempt ID. Events expose state and bounded outcome only. The queue is a
CI-owned implementation port, not a contract and not a cross-context database table.

Policy adds reviewed actions `ci.run` and `ci.cancel` on a `repository` and `ci_job` resource
respectively. The CI PEP supplies only server-derived context: ref, immutable revision, trigger
kind, and whether the request is terminal/cancellable. The runner does not authorize itself.

## Execution boundary

1. Repository/Git publishes verified `RefUpdated`; CI validates tenant/repository/ref/SHA and asks
   the PDP for `ci.run` under the event actor before atomically recording and queueing a job.
2. A dispatcher claims one queued job transactionally, revalidates that it is not cancelled, and
   creates one Kubernetes Job with `runtimeClassName` set to the environment's gVisor class.
3. The sandbox has a unique service account, `automountServiceAccountToken: false`, no host paths,
   no privileged containers, no host PID/IPC/network, read-only root filesystem except explicit
   empty ephemeral work volumes, dropped Linux capabilities, and a default-deny network policy.
   Its only initial egress allowance is the source-read endpoint using its single-job capability.
4. The source endpoint permits only the recorded tenant/repository/commit SHA and expires at the
   earlier of job terminal transition or attempt deadline. It cannot read another ref, tenant, or
   repository and cannot call a browser/API/Git write endpoint.
5. The dispatcher records a terminal result only after Kubernetes reports the Job terminated and
   the Job object, pod(s), capability, and ephemeral volumes are deleted. Cleanup uncertainty is
   `FAILED`, never a reusable or successful sandbox.

## Data owned

CI/CD owns job state, attempt leases, queue records, config digests, runner cleanup evidence, and
CI events. Repository/Git owns ref resolution and source bytes. Identity&Access owns the short-lived
attempt capability. Policy owns allow/deny. Audit owns immutable evidence. Contexts communicate by
contract/event; none reads another's tables.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A valid `RefUpdated` enqueues exactly one job for its tenant/repository/ref/new SHA;
  duplicate event delivery and duplicate request ID produce one job, while mismatched or unknown
  ref/SHA creates none.
- [ ] AC2: A queued job launches exactly one gVisor RuntimeClass sandbox and reaches a terminal
  state only after pod, Job, capability, and ephemeral work volume cleanup are observed. No attempt
  is reused for a later job or tenant.
- [ ] AC3: KEDA receives the queued-depth metric and scales dispatch workers from zero; a cancelled
  queued job never launches, and a runner crash reclaims an expired lease without executing two
  attempts.
- [ ] AC4: A sandbox cannot mount host paths, run privileged, acquire a Kubernetes service-account
  token, reach host services, use a Docker socket, or read another tenant/repository/ref through
  its capability; isolation tests prove all denied paths.
- [ ] AC5: The runner can read only the immutable SHA recorded by the job. Moving the branch after
  enqueue does not alter executed bytes; the job config digest binds the one parsed v0 manifest.
- [ ] AC6: Enqueue and cancel are PDP decisions with verified actor context; no contract, event,
  queue message, or Kubernetes label carries an `allowed` result. Cross-tenant job reads/cancels
  are coarse denials.
- [ ] AC7: Accepted dispatch and terminal outcome produce one immutable, tenant-scoped audit record
  each without source, raw log, source capability, secret, or Kubernetes-node details.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G1 isolation | job, capability, queue, source, and sandbox all bind one tenant and immutable SHA |
| G2 least privilege | PDP admits commands; sandbox starts without host, service-account, or write credentials |
| G3 supply chain | immutable configuration/source identity makes a run attributable and reproducible |
| G5 auditability | dispatch and outcome become immutable bounded evidence |
| G9 least-privilege footprint | no source/secrets reach the agent stream; runner gets only a single-job read capability |

## Non-functional

- Job claim and idempotency are transactional per tenant/repository/ref/SHA/config digest.
- The queue-depth scaler and runner may retry control operations, but retries never create a second
  live attempt for one job.
- Logs are bounded operational output with credential redaction; artifact persistence is deferred.

## Open questions / assumptions

- RuntimeClass and KEDA endpoint names are environment configuration, never hard-coded protocol
  values. A cluster without the configured gVisor class fails admission rather than silently using
  the default runtime.
- The short-lived source-read capability extends Identity&Access additively after its credential
  persistence decision is approved; its concrete token encoding is an adapter concern.
- The v0 manifest's image allowlist and outbound dependency destinations are reviewed policy data.
  This specification fixes default-deny networking but does not select an initial allowlist.
