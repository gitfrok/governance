# Fixture: proves `opa check` runs with --strict.
#
# The unused import below is accepted by a plain `opa check` and rejected under --strict. If this
# directory passes, the compile step has quietly dropped the strict flag and a class of dead or
# shadowed policy would ship unnoticed.
package fixture.strict

import data.gitsaas.authz

default allow := false
