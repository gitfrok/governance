# The deliberately-false assertion. `allow` is defined and denies here, so asserting it holds must
# fail — and the gate asserts that it does.
package fixture.failing_test

import data.fixture.failing

test_this_must_fail if {
	failing.allow with input as {"action": "write"}
}
