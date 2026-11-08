cd /c/Users/anton/Desktop/Assets-Pipeline/blender
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
PY=/c/Users/anton/Desktop/Assets-Pipeline/trellis/venv/Scripts/python.exe
# faction variant model shibaJsonSource
while read fac v model src; do
  [ -f ../game/assets/sprites/vehicles/${fac}_${v}_hull.png ] && continue
  FACTION=$fac "$B" -b -P render_vehicle.py -- --model $model --mode sheet --out ../out/veh/${fac}_$v --dirs 64 --size 192 --samples 32 2>&1 | grep -E "FERTIG|Error|Traceback"
  (cd ../game && $PY tools/make_vehicle_sheets.py ../out/veh/${fac}_${v}_frames assets/sprites/vehicles/${fac}_$v 0.8)
  cp ../game/assets/sprites/vehicles/shibas_$src.json ../game/assets/sprites/vehicles/${fac}_$v.json
  echo done $fac $v
done <<L
katzen phantom wheeled_buggy buggy
katzen sammler wheeled_sammler sammler
katzen prisma tank_tesla tesla
katzen nebelwerfer tank_raketen raketen
katzen nestmobil wheeled_baumobil baumobil
katzen nachtfalter heli_wespe wespe
katzen kreischer heli_gewitter gewitter
baeren rammbock wheeled_buggy buggy
baeren kipper wheeled_sammler sammler
baeren grizzly tank_tesla tesla
baeren moerser tank_raketen raketen
baeren hoehlenmobil wheeled_baumobil baumobil
baeren brummkopter heli_wespe wespe
baeren flugkessel heli_gewitter gewitter
L
echo ALLDONE
