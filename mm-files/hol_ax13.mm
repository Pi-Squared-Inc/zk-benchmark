$( Theory: hol_ax13 $)

$c
  type
  term
  |-
  :
  |=
  bool
  ->
  (
  )
  ,
  =
  T.
  [
  ]
  ==>
$.
$v al be A B C F R S T $.

hal $f type al $.
hbe $f type be $.
ta $f term A $.
tb $f term B $.
tc $f term C $.
tf $f term F $.
tr $f term R $.
ts $f term S $.
tt $f term T $.
hb $a type bool $.
kc $a term ( F T ) $.
ke $a term = $.
kt $a term T. $.
kbr $a term [ A F B ] $.
kct $a term ( A , B ) $.
${
  simpr.0 $e |- R : bool $.
  simpr.1 $e |- S : bool $.
  simpr $a |- ( R , S ) |= S $.
$}
wtru $a |- T. : bool $.
${
  wct.0 $e |- S : bool $.
  wct.1 $e |- T : bool $.
  wct $a |- ( S , T ) : bool $.
$}
${
  wc.0 $e |- F : ( al -> be ) $.
  wc.1 $e |- T : al $.
  wc $a |- ( F T ) : be $.
$}
${
  adantr.0 $e |- R |= T $.
  adantr.1 $e |- S : bool $.
  adantr $a |- ( R , S ) |= T $.
$}
${
  weqi.0 $e |- A : al $.
  weqi.1 $e |- B : al $.
  weqi $a |- [ A = B ] : bool $.
$}
${
  mpbi.0 $e |- R |= A $.
  mpbi.1 $e |- R |= [ A = B ] $.
  mpbi $a |- R |= B $.
$}
${
  ceq2.0 $e |- F : ( al -> be ) $.
  ceq2.1 $e |- A : al $.
  ceq2.2 $e |- R |= [ A = B ] $.
  ceq2 $a |- R |= [ ( F A ) = ( F B ) ] $.
$}
tim $a term ==> $.
${
  ex.0 $e |- ( R , S ) |= T $.
  ex $a |- R |= [ S ==> T ] $.
$}
${
  ax13.0 $e |- A : al $.
  ax13.1 $e |- B : al $.
  ax13.2 $e |- C : ( al -> bool ) $.
  ax13 $p |- T. |= [ [ A = B ] ==> [ ( C A ) ==> ( C B ) ] ] $=
( kt ke kbr kc tim kct wtru weqi wct hb wc simpr ex ceq2 adantr mpbi ) 
HBCIJZDBKZDCKZLJHUDMZUEUFUEUFUGUEMUGUEHUDNABCEFOZPAQDBGERZSUGUEUEUFIJAQBCDUGGEH
UDNUHSUAUIUBUCTT
$.
$}

$( hol_ax13 End $)

