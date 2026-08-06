# Fixture: proves `opa test` in check-policies.sh actually evaluates assertions.
#
# If this directory ever PASSES, the policy test step is reporting success without running
# anything, and the real suite's green tick means nothing. See scripts/check-policies.sh.
package fixture.failing

default allow := false

allow if input.action == "read"
