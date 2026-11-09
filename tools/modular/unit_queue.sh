# Jede Infanterie-Einheit mit eigenem Look: Volks-Ruestung (Krea->TRELLIS, tools/comfyui/gen_faction_armor.py),
# eigene Teilauswahl, Koerperbau (bw/bh), Waffe. Aufruf aus Assets-Pipeline:  bash game/tools/modular/unit_queue.sh [volk] [einheit]
cd /c/Users/anton/Desktop/Assets-Pipeline
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
G=out/3d
mkdir -p out/mod
part() { echo "$G/$1_LowPoly_Textured_00001_.glb"; }
# volk einheit waffe waffenlaenge bw bh chest shoulder forearm shin chest-w chest-h shoulder-size
# gl = Glow-Farbe r,g,b (oder -), pl = Platten-Farbe, gn = Aufhellung der Ruestungstextur
# chest: a|b ; shoulder/forearm/shin: 1|0
while read fac unit weapon wlen bw bh chest sh fo sn cw chh ss gl pl gn; do
  [ -n "$1" ] && [ "$1" != "$fac" ] && continue
  [ -n "$2" ] && [ "$2" != "$unit" ] && continue
  J=out/mod/parts_unit_${fac}_${unit}.json
  if [ $fac = shibas ]; then
    HEAD=$G/shibas_head6_LowPoly_Textured_00001_.glb; PFX=armor; NT=0; CK=1.0; CZ=1.42
    CH=$G/armor_chest_LowPoly_Textured_00001_.glb; SH=$G/armor_shoulder_LowPoly_Textured_00001_.glb
    FO=$G/armor_forearm_LowPoly_Textured_00001_.glb; SN=$G/armor_shin_LowPoly_Textured_00001_.glb
  else
    HEAD=$G/${fac}_head_LowPoly_Textured_00001_.glb; NT=1; CK=0.62; CZ=1.38
    CH=$(part fa_${fac}_chest_$chest); [ $chest = a ] && [ $fac = shibas ] || true
    SH=$(part fa_${fac}_shoulder); FO=$(part fa_${fac}_forearm); SN=$(part fa_${fac}_shin)
  fi
  GA=""; [ "$gl" != "-" ] && GA="--glow $gl"; [ "$pl" != "-" ] && GA="$GA --plate $pl"
  P="\"head\": \"$HEAD\""
  [ $chest != - ] && P="$P, \"a_chest\": \"$CH\""
  [ $sh = 1 ] && P="$P, \"a_shoulder\": \"$SH\""
  [ $fo = 1 ] && P="$P, \"a_forearm\": \"$FO\""
  [ $sn = 1 ] && P="$P, \"a_shin\": \"$SN\""
  echo "{$P}" > $J
  "$B" -b -P game/tools/blender/build_modular_mx.py -- --parts $J --pal $fac --weapon $weapon --weapon-len $wlen --wflip 1 \
     --bw $bw --bh $bh --notint $NT --core-k $CK --chest-z $CZ --chest-w $cw --chest-h $chh --shoulder-size $ss $GA --gain $gn \
     --export-glb game/assets/models/infantry/${fac}_${unit}.glb 2>&1 | grep -E "Traceback|Error|GLB"
  echo done $fac $unit
done <<L
shibas trooper AK 0.95 1.0 1.0 a 1 1 1 0.66 0.62 0.40 - - 1.0
shibas zapper Shotgun 1.0 1.12 0.98 a 1 0 0 0.76 0.62 0.50 - - 1.0
shibas schnueffler SMG 0.65 0.9 1.0 a 0 1 0 0.6 0.58 0.32 - - 1.0
shibas ingenieur Pistol 0.4 0.97 1.0 a 1 1 1 0.64 0.6 0.36 - - 1.0
katzen streuner AK 0.95 0.93 1.04 a 1 1 1 0.66 0.64 0.44 0.75,0.2,1.0 - 2.6
katzen scharfschuetzin Sniper 1.3 0.88 1.07 b 0 0 1 0.64 0.66 0.3 0.35,0.4,1.0 0.07,0.07,0.26 2.2
katzen hackerin SMG 0.65 0.9 1.02 b 0 1 0 0.64 0.64 0.4 1.0,0.25,0.85 0.3,0.06,0.26 2.6
katzen saboteur Pistol 0.4 0.86 1.0 a 1 0 0 0.6 0.62 0.36 0.6,0.0,0.95 0.05,0.03,0.1 1.9
baeren grunzer AK 0.95 1.18 1.0 a 1 1 1 0.84 0.66 0.5 - - 1.0
baeren feuertatze ShortCannon 0.85 1.3 1.04 a 1 0 1 0.92 0.7 0.56 1.0,0.35,0.08 0.3,0.05,0.03 1.0
baeren bazooka RocketLauncher 1.1 1.22 1.02 b 1 0 0 0.86 0.68 0.52 - - 1.0
baeren mechaniker Shotgun 1.0 1.12 0.97 b 0 1 1 0.8 0.64 0.4 1.0,0.9,0.35 0.55,0.45,0.12 1.0
L

# Vierbeiner (kampfhund, panther, kodiak)
while read fac unit model length tint; do
  [ -n "$1" ] && [ "$1" != "$fac" ] && continue
  [ -n "$2" ] && [ "$2" != "$unit" ] && continue
  TA=""; [ "$tint" != "-" ] && TA="--tint $tint"
  "$B" -b -P game/tools/blender/build_quadruped.py -- --model $model --pal $fac --length $length $TA \
     --export-glb game/assets/models/infantry/${fac}_${unit}.glb 2>&1 | grep -E "Traceback|Error|GLB"
  echo done $fac $unit
done <<Q
shibas kampfhund dog_shiba 1.7 -
katzen panther cat 1.65 0.14,0.12,0.16
baeren kodiak bear_panda 1.85 0.55,0.38,0.22
Q
echo ALLDONE
