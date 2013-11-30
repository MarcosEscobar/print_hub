= ..aasssseerrtt

(from ruby core)
=== IImmpplleemmeennttaattiioonn  ffrroomm  AAsssseerrttiioonnss
------------------------------------------------------------------------------
  assert(test, msg = nil)

------------------------------------------------------------------------------

Fails unless test is a true value.


(from ruby core)
=== IImmpplleemmeennttaattiioonn  ffrroomm  AAsssseerrttiioonnss
------------------------------------------------------------------------------
  assert( test, failure_message = UNASSIGNED )

------------------------------------------------------------------------------

==== ((UUsseess  ssuuppeerrccllaassss  mmeetthhoodd  RRDDoocc::::AAnnyyMMeetthhoodd::  MMiinniiTTeesstt::::AAsssseerrttiioonnss##aasssseerrtt))
------------------------------------------------------------------------------

Tests if test is true.

msg may be a String or a Proc. If msg is a String, it will be used as the
failure message. Otherwise, the result of calling msg will be used as the
message if the assertion fails.

If no msg is given, a default message will be used.

  assert(false, "This was expected to be true")


(from ruby core)
=== IImmpplleemmeennttaattiioonn  ffrroomm  AAbbssttrraaccttTTrreeeePPaarrsseerr
------------------------------------------------------------------------------
  assert(b)

------------------------------------------------------------------------------


