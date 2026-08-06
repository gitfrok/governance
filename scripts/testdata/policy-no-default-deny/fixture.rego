# Fixture: proves the deny-by-default check in check-policies.sh can fail.
#
# This package defines `allow` but declares no `default allow := false`, so with an input that
# matches nothing `data.fixture.opendefault.allow` is *undefined* rather than false. Undefined is
# not a denial — it is the absence of an answer, and an adapter that has to interpret it is one
# refactor away from interpreting it as permission (ADR-0006, invariant 2).
#
# If the gate reports this fixture as compliant, the check is not looking at anything.
package fixture.opendefault

allow if input.action == "read"
