$( Theory: hol_wov $)

$c
  type
  term
  |-
  :
  ->
  (
  )
  [
  ]
$.
$v al be ga A B F $.

hal $f type al $.
hbe $f type be $.
hga $f type ga $.
ta $f term A $.
tb $f term B $.
tf $f term F $.
${
  ax-wov.0 $e |- F : ( al -> ( be -> ga ) ) $.
  ax-wov.1 $e |- A : al $.
  ax-wov.2 $e |- B : be $.
  ax-wov $a |- [ A F B ] : ga $.
$}
${
  wov.0 $e |- F : ( al -> ( be -> ga ) ) $.
  wov.1 $e |- A : al $.
  wov.2 $e |- B : be $.
  wov $p |- [ A F B ] : ga $=
( ax-wov ) 
ABCDEFGHIJ
$.
$}

$( hol_wov End $)

