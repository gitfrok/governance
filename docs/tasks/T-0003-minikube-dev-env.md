    # T-0003: Minikube dev environment

    - **Status:** Todo
    - **Phase / Epic:** 0 / EP-1
    - **Spec:** chore — acceptance criteria below
    - **ADRs:** 0024, 0023
    - **Owner:** unassigned

    ## Goal
    One-command local cluster matching prod topology, with real TLS.

    ## Acceptance criteria (test-first)
    - [ ] AC1: `make dev-up` starts Minikube with `ingress` + `ingress-dns` addons.
- [ ] AC2: PostgreSQL 18, Valkey 9.1, Redpanda v26.1, Zitadel, SeaweedFS 4.40 come up from
      manifests using image tags in `deploy/dev/versions.env`.
- [ ] AC3: Services are reachable at `*.gitsaas.test` over HTTPS via a mkcert wildcard secret.
- [ ] AC4: No OrbStack and no Docker Compose anywhere; works on macOS and Linux.

    ## Tests to write first
    - integration: a smoke test hits an ingress host over TLS and gets 200 from a hello service.

    ## Definition of Done
    See `../process/definition-of-done.md`.

    ## Notes / open questions
    Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.
