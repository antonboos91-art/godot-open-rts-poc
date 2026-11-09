cd /c/Users/anton/Desktop/Assets-Pipeline/blender
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
PY=/c/Users/anton/Desktop/Assets-Pipeline/trellis/venv/Scripts/python.exe
while read fac v model src mz md; do
  FACTION=$fac "$B" -b -P render_vehicle.py -- --model $model --mode sheet --out ../out/veh/${fac}_$v --dirs 64 --size 256 --ortho 5.0 --samples 32 2>&1 | grep -E "Traceback|Error"
  (cd ../game && $PY tools/make_vehicle_sheets.py ../out/veh/${fac}_${v}_frames assets/sprites/vehicles/${fac}_$v 0.8)
  $PY - <<P
import json
p="../game/assets/sprites/vehicles/shibas_$src.json"
d=json.load(open(p)); d["ortho"]=5.0; d["muzzle_z"]=$mz; d["muzzle_dist"]=$md
if "muzzle_side" in d and "$v"=="moerser": d["muzzle_side"]=0.36
json.dump(d,open("../game/assets/sprites/vehicles/${fac}_$v.json","w"),indent=1)
P
  echo done $fac $v
done <<L
baeren grizzly tank_baeren_grizzly tesla 1.0 2.4
baeren moerser tank_baeren_moerser raketen 1.3 0.6
katzen prisma tank_katzen_prisma tesla 1.09 1.85
katzen nebelwerfer tank_katzen_nebel raketen 1.3 0.45
L
echo ALLDONE
