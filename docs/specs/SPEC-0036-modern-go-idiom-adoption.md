# SPEC-0036: Modern Go idiom adoption across backend and bff

- **Status:** Approved (2026-08-14)
- **Owner:** platform
- **Context(s):** cross-cutting (backend modules + bff internals; no bounded-context behavior change)
- **ADRs:** none new — behavior-preserving refactor; no architectural decision required.
  Cites ADR-0089 for the toolchain floor the ALLOWED set is resolved against.
- **Task(s):** — (approved plan; per-module PRs declare `Ceremony: full` citing this spec)

## Problem / context

Both `backend/` and `bff/` are on Go 1.27 (Go 1.26 when this spec was approved; ADR-0089 raised
the floor), but much of the handwritten code predates idioms the
Modern Go Guidelines prescribe (standard-library `slices`/`maps`/`cmp` helpers, `any`,
`errors.Is`, `time.Since`, iterator-friendly loops, `sync.OnceFunc`, and friends). Adopting them
is mechanical and behavior-preserving, but the change touches security-sensitive modules, so the
`full` ceremony tier applies (verified via `scripts/check-ceremony-tier.sh`): an Approved spec is
required before work begins. This spec fixes the scope, the binding guideline triage, the frozen
surfaces, and the execution model so that every resulting PR is reviewable against a closed list
of allowed transformations.

Emphasis modules: `modules/security`, `modules/codesearch`, `modules/policy`, `modules/audit`,
`modules/identity`.

## In scope

- Behavior-preserving adoption of the Modern Go Guidelines across **all handwritten Go** in
  `backend/` and `bff/`, limited to the ALLOWED and CONDITIONAL guideline sets triaged below.
- New **test-only** and **benchmark-only** files to pin behavior before and after transformation.
- Comment-only clarification at the detached `context.Background()` sites listed below.

## Out of scope

- Performance or allocation surgery of any kind.
- Any contract, API, wire-format or behavior change.
- Migrations and schema changes.
- `gen/` regeneration in either repo.

## Contracts touched

none — `contracts/` is frozen by AC1; no proto or event change is permitted.

## Data owned

none — no data ownership, schema, or storage boundary changes. No cross-context access is
introduced (ADR-0022).

## Acceptance criteria (each becomes a test)

- [ ] AC1: Zero changes to: `gen/` in both repos; all `migrations/*.sql`;
  `backend/internal/arch/**` and `bff/internal/arch/**`; `backend/platform/db/db.go`;
  `backend/platform/tenancy/tenancy.go`; all `//arch:allow-inline-authz <reason>` waiver comments
  (byte-identical); `scripts/*.sh`; `AGENTS.md` files; `contracts/`; `policies/`.
- [ ] AC2: All existing tests pass **unmodified**; new test-only and benchmark-only files are
  allowed.
- [ ] AC3: The guideline triage below is embedded in this spec **verbatim and binding**; a
  transformation not listed as ALLOWED, or a CONDITIONAL transformation applied outside its
  stated conditions, is a spec violation.
- [ ] AC4: Every consumer PR declares `Ceremony: full` and cites SPEC-0036.
- [ ] AC5: Byte-identity where it matters: `modules/policy/internal/app/digest.go` canonical
  digest output (SPEC-0030) is unchanged; all `api/` JSON tags are unchanged.

## Guideline triage (verbatim, binding)

**ALLOWED** (mechanical, behavior-preserving): any, errors_is, time_since, time_until, min_max,
range_over_int, slices_contains, slices_index, slices_index_func, slices_sort, slices_sort_func,
slices_max_min, slices_reverse, slices_compact, slices_clip, slices_clone, maps_clone, maps_copy,
maps_delete_func, maps_keys_values_iter, strings_cut, bytes_cut, strings_cut_prefix_suffix,
cmp_or, fmt_appendf, new_expression, reflect_type_for, sync_once_func, sync_once_value, clear.

Sort stability rule: `sort.SliceStable` → `slices.SortStableFunc`; `sort.Slice` →
`slices.SortFunc` + `cmp.Compare`.

**CONDITIONAL** (case-by-case, comment the intent): errors_join,
context_cancel_cause/context_after_func (only where a cause is actually consumed),
http_servemux_patterns (backend `cmd/`/`internal/health` only; bff already compliant),
testing_t_context/testing_b_loop (test files only), atomic_types (test-file sites only).

**SKIP this round**: json_omitzero on api/handler/event DTOs (wire-format risk),
strings_split_seq/slices_collect/slices_sorted in hot paths with later index access,
loopvar_capture copy removal, sync_waitgroup_go, time_tick_gc, strings_clone/bytes_clone,
errors_as_type.

**Detached context.Background() sites** (`policy/adapters/opa/pdp.go`,
`codesearch/internal/app/service.go`, `audit/internal/app/evidence.go`): comment-only
clarification allowed, no behavior change.

## Execution model

- One PR per module, committed in **ascending risk order**, on branches named
  `refactor/modern-go-idioms` (per-repo suffix as needed).
- The gate suite runs green between commits: `gofmt`, `go build`, `go vet`, arch fitness tests,
  `go test -race`.
- Ordering: `backend` before `bff`.
- Super-repo pin bumps target **merged** commits only (ADR-0027), and never within this spec's
  own commits.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
| --- | --- |
| G2 least privilege | no authz surface is touched; waiver comments are byte-identical (AC1) |
| G4 change governance | full-ceremony, spec-first, closed triage list; gated per commit |
| G5 auditability | audit module behavior and evidence paths are behavior-preserved |
| G7 verifiability | existing tests pass unmodified; byte-identity pinned for digest and JSON tags (AC2, AC5) |

## Non-functional

- No measurable behavior change: canonical digest output, JSON wire shape, and test outcomes are
  identical before and after.
- Race detector stays green across the refactor (`go test -race` in the gate suite).

## Open questions / assumptions

- **Assumption:** the floor never moves *down* under this spec; a toolchain downgrade would
  invalidate the ALLOWED set. It moved *up* on 2026-08-22 — ADR-0089 raised the floor from Go
  1.26 to 1.27 — which widens what is available without invalidating anything already allowed.
  Per the closing note below, the five idioms 1.27 adds (generic methods, promoted field names in
  embedded-struct literals, `strings`/`bytes.CutLast`, the standard-library `uuid` package,
  `url.URL.Clone` and `Values.Clone`) are a **new spec**, not this one's remit. The `uuid` one is
  a dependency removal, not a rewrite, so it needs its own justification either way.
- **Assumption:** the `full` ceremony tier verdict from `scripts/check-ceremony-tier.sh` holds
  for every consumer PR; if a module PR is re-tiered, this spec still binds via AC4.
- No parked human decisions: the triage is closed for this round; future guideline adoption is a
  new spec.
