$( Theory: hol_cbvf $)

$c
  var
  type
  term
  |-
  :
  .
  |=
  bool
  ->
  (
  )
  \
  =
  T.
  [
  ]
$.
$v al be ga de x y z p A B C F R S T $.

hal $f type al $.
hbe $f type be $.
hga $f type ga $.
hde $f type de $.
vx $f var x $.
vy $f var y $.
vz $f var z $.
vp $f var p $.
ta $f term A $.
tb $f term B $.
tc $f term C $.
tf $f term F $.
tr $f term R $.
ts $f term S $.
tt $f term T $.
tv $a term x : al $.
ht $a type ( al -> be ) $.
hb $a type bool $.
kc $a term ( F T ) $.
kl $a term \ x : al . T $.
ke $a term = $.
kt $a term T. $.
kbr $a term [ A F B ] $.
${
  id.0 $e |- R : bool $.
  id $a |- R |= R $.
$}
${
  a1i.0 $e |- R : bool $.
  a1i.1 $e |- T. |= A $.
  a1i $a |- R |= A $.
$}
${
  ax-cb1.0 $e |- R |= A $.
  ax-cb1 $a |- R : bool $.
$}
weq $a |- = : ( al -> ( al -> bool ) ) $.
${
  wc.0 $e |- F : ( al -> be ) $.
  wc.1 $e |- T : al $.
  wc $a |- ( F T ) : be $.
$}
wv $a |- x : al : al $.
${
  wl.0 $e |- T : be $.
  wl $a |- \ x : al . T : ( al -> be ) $.
$}
${
  weqi.0 $e |- A : al $.
  weqi.1 $e |- B : al $.
  weqi $a |- [ A = B ] : bool $.
$}
${
  eqtypi.0 $e |- A : al $.
  eqtypi.1 $e |- R |= [ A = B ] $.
  eqtypi $a |- B : al $.
$}
${
  eqcomi.0 $e |- A : al $.
  eqcomi.1 $e |- R |= [ A = B ] $.
  eqcomi $a |- R |= [ B = A ] $.
$}
${
  ceq2.0 $e |- F : ( al -> be ) $.
  ceq2.1 $e |- A : al $.
  ceq2.2 $e |- R |= [ A = B ] $.
  ceq2 $a |- R |= [ ( F A ) = ( F B ) ] $.
$}
${
  $d x R $.
  leq.0 $e |- A : be $.
  leq.1 $e |- R |= [ A = B ] $.
  leq $a |- R |= [ \ x : al . A = \ x : al . B ] $.
$}
${
  beta.0 $e |- A : be $.
  beta $a |- T. |= [ ( \ x : al . A x : al ) = A ] $.
$}
${
  eqtri.0 $e |- A : al $.
  eqtri.1 $e |- R |= [ A = B ] $.
  eqtri.2 $e |- R |= [ B = C ] $.
  eqtri $a |- R |= [ A = C ] $.
$}
${
  3eqtr3i.0 $e |- A : al $.
  3eqtr3i.1 $e |- R |= [ A = B ] $.
  3eqtr3i.2 $e |- R |= [ A = S ] $.
  3eqtr3i.3 $e |- R |= [ B = T ] $.
  3eqtr3i $a |- R |= [ S = T ] $.
$}
${
  oveq12.0 $e |- F : ( al -> ( be -> ga ) ) $.
  oveq12.1 $e |- A : al $.
  oveq12.2 $e |- B : be $.
  oveq12.3 $e |- R |= [ A = C ] $.
  oveq12.4 $e |- R |= [ B = T ] $.
  oveq12 $a |- R |= [ [ A F B ] = [ C F T ] ] $.
$}
${
  hbl1.0 $e |- A : ga $.
  hbl1.1 $e |- B : al $.
  hbl1.2 $e |- R : bool $.
  hbl1 $a |- R |= [ ( \ x : al . \ x : be . A B ) = \ x : be . A ] $.
$}
${
  $d x A $.
  ax-17.0 $e |- A : be $.
  ax-17.1 $e |- B : al $.
  ax-17 $a |- T. |= [ ( \ x : al . A B ) = A ] $.
$}
${
  hbc.0 $e |- F : ( be -> ga ) $.
  hbc.1 $e |- A : be $.
  hbc.2 $e |- B : al $.
  hbc.3 $e |- R |= [ ( \ x : al . F B ) = F ] $.
  hbc.4 $e |- R |= [ ( \ x : al . A B ) = A ] $.
  hbc $a |- R |= [ ( \ x : al . ( F A ) B ) = ( F A ) ] $.
$}
${
  hbov.0 $e |- F : ( be -> ( ga -> de ) ) $.
  hbov.1 $e |- A : be $.
  hbov.2 $e |- B : al $.
  hbov.3 $e |- C : ga $.
  hbov.4 $e |- R |= [ ( \ x : al . F B ) = F ] $.
  hbov.5 $e |- R |= [ ( \ x : al . A B ) = A ] $.
  hbov.6 $e |- R |= [ ( \ x : al . C B ) = C ] $.
  hbov $a |- R |= [ ( \ x : al . [ A F C ] B ) = [ A F C ] ] $.
$}
${
  $d x y $.
  $d y B $.
  $d y R $.
  hbl.0 $e |- A : ga $.
  hbl.1 $e |- B : al $.
  hbl.2 $e |- R |= [ ( \ x : al . A B ) = A ] $.
  hbl $a |- R |= [ ( \ x : al . \ y : be . A B ) = \ y : be . A ] $.
$}
${
  $d x y R $.
  $d y B $.
  insti.0 $e |- C : al $.
  insti.1 $e |- B : bool $.
  insti.2 $e |- R |= A $.
  insti.3 $e |- T. |= [ ( \ x : al . B y : al ) = B ] $.
  insti.4 $e |- [ x : al = C ] |= [ A = B ] $.
  insti $a |- R |= B $.
$}
${
  $d y A $.
  $d y B $.
  $d y C $.
  $d x y al $.
  clf.0 $e |- A : be $.
  clf.1 $e |- C : al $.
  clf.2 $e |- [ x : al = C ] |= [ A = B ] $.
  clf.3 $e |- T. |= [ ( \ x : al . B y : al ) = B ] $.
  clf.4 $e |- T. |= [ ( \ x : al . C y : al ) = C ] $.
  clf $a |- T. |= [ ( \ x : al . A C ) = B ] $.
$}
${
  $d x F $.
  $d x al $.
  $d x be $.
  eta.0 $e |- F : ( al -> be ) $.
  eta $a |- T. |= [ \ x : al . ( F x : al ) = F ] $.
$}
${
  $d p z A $.
  $d p z B $.
  $d p x y z al $.
  $d p be $.
  cbvf.0 $e |- A : be $.
  cbvf.1 $e |- T. |= [ ( \ y : al . A z : al ) = A ] $.
  cbvf.2 $e |- T. |= [ ( \ x : al . B z : al ) = B ] $.
  cbvf.3 $e |- [ x : al = y : al ] |= [ A = B ] $.
  cbvf $p |- T. |= [ \ x : al . A = \ y : al . B ] $=
( vp ht kl tv kc kt wc ke kbr wl eqtypi weqi ax-17 clf weq hbl hbc ax-cb1 wv hb hbl1 hbov ceq2 beta eqcomi a1i eqtri oveq12 insti leq eta 3eqtr3i id ) 
ABMALACFNZALOZPZNALADGNZVFPZNQVEVHABLVGABVEVFABCFHUAZALUJZRZUAABLVGVIQVLADEVE
ADOZPZGSTVGVISTVFQVKBVGVIVLABVHVFABDGBFGACOVMSTHKUBZUAZVKRZUCABCEFGVMHADUJZKJAAC
VMAEOZVRAEUJZUDUEABBUKDVGVSVISQBUFZVLVTVQABBUKMMDSVSWAVTUDAABDVFVSVEQVJVKVTAABDCFVSQHVTIUGA
ADVFVSVKVTUDZUHAABDVFVSVHQVPVKVTAABDGVSQVOVTADFNVSPFSTQIUIULWBUHUMBBUKVNGVGSVMVFSTZVIWAABVEVMVJ
VRRVOABVMVFVEWCVJVRWCAVMVFVRVKUCVDZUNZBGVHVMPZVIWCVOGWFSTWCVNVGSTWCWEUIBWFGQABVHVMVPVRRABDGVOUOUPUQAB
VMVFVHWCVPVRWDUNURUSUTVAABLVEVJVBABLVHVPVBVC
$.
$}

$( hol_cbvf End $)

