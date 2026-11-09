cd /c/Users/anton/Desktop/Assets-Pipeline/blender
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
PY=/c/Users/anton/Desktop/Assets-Pipeline/trellis/venv/Scripts/python.exe
FACTION=katzen "$B" -b -P render_vehicle.py -- --model wheeled_katzen_phantom --mode sheet --out ../out/veh/katzen_phantom --dirs 64 --size 192 --samples 32 2>&1 | grep -E "Traceback|Error"
(cd ../game && $PY tools/make_vehicle_sheets.py ../out/veh/katzen_phantom_frames assets/sprites/vehicles/katzen_phantom 0.8)
cp ../game/assets/sprites/vehicles/shibas_buggy.json ../game/assets/sprites/vehicles/katzen_phantom.json
echo PHANTOMDONE
