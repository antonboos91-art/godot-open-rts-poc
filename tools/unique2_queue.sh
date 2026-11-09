cd /c/Users/anton/Desktop/Assets-Pipeline/blender
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
PY=/c/Users/anton/Desktop/Assets-Pipeline/trellis/venv/Scripts/python.exe
while read fac v model src scale lift ortho; do
  FACTION=$fac "$B" -b -P render_vehicle.py -- --model $model --mode sheet --out ../out/veh/${fac}_$v --dirs 64 --size 256 --ortho $ortho --samples 32 2>&1 | grep -E "Traceback|Error"
  (cd ../game && $PY tools/make_vehicle_sheets.py ../out/veh/${fac}_${v}_frames assets/sprites/vehicles/${fac}_$v 0.8)
  $PY - <<P
import json
d=json.load(open("../game/assets/sprites/vehicles/shibas_$src.json"))
d["ortho"]=$ortho
for k in ("muzzle_z","muzzle_dist","muzzle_side"):
    if k in d: d[k]=d[k]*$scale
d["muzzle_z"]=d.get("muzzle_z",0)+$lift
json.dump(d,open("../game/assets/sprites/vehicles/${fac}_$v.json","w"),indent=1)
P
  echo done $fac $v
done <<L
baeren rammbock wheeled_baeren_rammbock buggy 1.5 0 6.0
baeren kipper wheeled_baeren_kipper sammler 1.35 0 5.0
baeren hoehlenmobil wheeled_baeren_hoehle baumobil 1.35 0 5.0
baeren brummkopter heli_baeren_brumm wespe 1.35 0 5.0
baeren flugkessel heli_baeren_kessel gewitter 1.35 0 5.0
katzen sammler wheeled_katzen_sammler sammler 1.0 0.3 3.6
katzen nestmobil wheeled_katzen_nest baumobil 1.0 0.3 3.6
katzen nachtfalter heli_katzen_nacht wespe 1.0 0 3.6
katzen kreischer heli_katzen_kreisch gewitter 1.0 0 3.6
L
echo ALLDONE
