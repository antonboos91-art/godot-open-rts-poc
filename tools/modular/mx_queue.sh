cd /c/Users/anton/Desktop/Assets-Pipeline
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
heavy="--chest-w 0.76 --shoulder-size 0.5"
scout="--chest-w 0.6 --shoulder-size 0.32"
norm="--chest-w 0.66 --shoulder-size 0.40"
while read fac unit weapon wlen kind; do
  case $kind in heavy) X="$heavy";; scout) X="$scout";; norm) X="$norm";; esac
  "$B" -b -P game/tools/blender/build_modular_mx.py -- --parts out/mod/parts_$fac.json --pal $fac --weapon $weapon --weapon-len $wlen --wflip 1 $X --out out/mod/mx_${fac}_$unit --size 192 2>&1 | grep -E "Traceback|SHEET"
  cp out/mod/mx_${fac}_$unit.png game/assets/sprites/infantry/${fac}_$unit.png
  cp out/mod/mx_${fac}_$unit.json game/assets/sprites/infantry/${fac}_$unit.json
  echo done $fac $unit
done <<L
shibas trooper AK 0.95 norm
shibas zapper Shotgun 1.0 heavy
shibas schnueffler SMG 0.65 scout
shibas ingenieur Pistol 0.4 norm
katzen streuner AK 0.95 norm
katzen scharfschuetzin Sniper 1.3 scout
katzen hackerin SMG 0.65 norm
katzen saboteur Pistol 0.4 scout
baeren grunzer AK 0.95 norm
baeren feuertatze ShortCannon 0.85 heavy
baeren bazooka RocketLauncher 1.1 heavy
baeren mechaniker Shotgun 1.0 norm
L
echo ALLDONE
