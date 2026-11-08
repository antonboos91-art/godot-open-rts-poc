cd /c/Users/anton/Desktop/Assets-Pipeline
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
BASE="--head-size 0.42 --two-hand 0 --grip 0.25 --chest-h 0.62 --chest-z 1.36 --suit cyber"
heavy="--weapon-len 0.7 --chest-w 0.76 --shoulder-size 0.5 --shoulder-lift 0.02"
scout="--weapon-len 0.3 --chest-w 0.6 --shoulder-size 0.32 --shoulder-lift 0.02"
tech="--weapon-len 0.01 --chest-w 0.66 --shoulder-size 0.36 --shoulder-lift 0.02"
while read fac unit kind; do
  case $kind in heavy) X="$heavy";; scout) X="$scout";; tech) X="$tech";; esac
  P=out/mod/parts_$fac.json
  [ $fac = shibas ] && P=out/mod/parts_shibas.json
  [ $kind = tech ] && { P2=out/mod/parts_${fac}_norifle.json; sed 's|"rifle": "[^"]*", ||' $P > $P2; P=$P2; }
  "$B" -b -P game/tools/blender/build_modular.py -- --parts $P $BASE $X --pal $fac --out out/mod/var_${fac}_$unit --size 192 2>&1 | grep -E "SHEET|Traceback"
  cp out/mod/var_${fac}_$unit.png game/assets/sprites/infantry/${fac}_$unit.png
  cp out/mod/var_${fac}_$unit.json game/assets/sprites/infantry/${fac}_$unit.json
  echo done $fac $unit
done <<L
shibas zapper heavy
shibas schnueffler scout
shibas ingenieur tech
katzen scharfschuetzin heavy
katzen hackerin tech
katzen saboteur scout
baeren feuertatze heavy
baeren bazooka heavy
baeren mechaniker tech
L
echo ALLDONE
