# Alle Skript-Fahrzeuge als 3D-Modelle exportieren (assets/models/vehicles/<volk>_<einheit>.glb)
#   bash tools/export_all_vehicles.sh   (aus dem game-Ordner)
cd "$(dirname "$0")/blender"
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
while read fac v model; do
  FACTION=$fac "$B" -b -P export_vehicle.py -- --model $model --out ../../assets/models/vehicles/${fac}_$v.glb 2>&1 | grep -E "Traceback|Error|EXPORT"
done <<L
shibas tesla tank_tesla
shibas raketen tank_raketen
shibas buggy wheeled_buggy
shibas sammler wheeled_sammler
shibas baumobil wheeled_baumobil
shibas wespe heli_wespe
shibas gewitter heli_gewitter
katzen prisma tank_katzen_prisma
katzen nebelwerfer tank_katzen_nebel
katzen phantom wheeled_katzen_phantom
katzen sammler wheeled_katzen_sammler
katzen nestmobil wheeled_katzen_nest
katzen nachtfalter heli_katzen_nacht
katzen kreischer heli_katzen_kreisch
baeren grizzly tank_baeren_grizzly
baeren moerser tank_baeren_moerser
baeren rammbock wheeled_baeren_rammbock
baeren kipper wheeled_baeren_kipper
baeren hoehlenmobil wheeled_baeren_hoehle
baeren brummkopter heli_baeren_brumm
baeren flugkessel heli_baeren_kessel
L
echo ALLDONE
