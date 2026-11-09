# Jede Infanterie-Einheit mit eigenem Look, Ausrüstung, Körperbau, Beinpanzerung und eigenen Animationen.
# Aufruf aus Assets-Pipeline:  bash game/tools/modular/unit_queue.sh [volk] [einheit]
cd /c/Users/anton/Desktop/Assets-Pipeline
B="/c/Program Files/Blender Foundation/Blender 4.5/blender.exe"
G=out/3d
mkdir -p out/mod
part() { echo "$G/$1_LowPoly_Textured_00001_.glb"; }

# volk einheit waffe wlen bw bh chest sh fo th sn cw chh ss muscle gear gl pl gn c_idle c_walk c_shoot c_die c_a c_b
while IFS='|' read -r fac unit weapon wlen bw bh chest sh fo th sn cw chh ss muscle gear gl pl gn c_idle c_walk c_shoot c_die c_a c_b; do
  fac=$(echo "$fac" | xargs)
  [ -z "$fac" ] && continue
  unit=$(echo "$unit" | xargs)
  [ -n "$1" ] && [ "$1" != "$fac" ] && continue
  [ -n "$2" ] && [ "$2" != "$unit" ] && continue
  weapon=$(echo "$weapon" | xargs); wlen=$(echo "$wlen" | xargs)
  bw=$(echo "$bw" | xargs); bh=$(echo "$bh" | xargs)
  chest=$(echo "$chest" | xargs); sh=$(echo "$sh" | xargs); fo=$(echo "$fo" | xargs); th=$(echo "$th" | xargs); sn=$(echo "$sn" | xargs)
  cw=$(echo "$cw" | xargs); chh=$(echo "$chh" | xargs); ss=$(echo "$ss" | xargs)
  muscle=$(echo "$muscle" | xargs); gear=$(echo "$gear" | xargs)
  gl=$(echo "$gl" | xargs); pl=$(echo "$pl" | xargs); gn=$(echo "$gn" | xargs)
  c_idle=$(echo "$c_idle" | xargs); c_walk=$(echo "$c_walk" | xargs); c_shoot=$(echo "$c_shoot" | xargs)
  c_die=$(echo "$c_die" | xargs); c_a=$(echo "$c_a" | xargs); c_b=$(echo "$c_b" | xargs)

  J=out/mod/parts_unit_${fac}_${unit}.json
  if [ "$fac" = "shibas" ]; then
    HEAD=$G/shibas_head6_LowPoly_Textured_00001_.glb; NT=0; CK=0.92; CZ=1.40
    CH=$G/armor_chest_LowPoly_Textured_00001_.glb; SH=$G/armor_shoulder_LowPoly_Textured_00001_.glb
    FO=$G/armor_forearm_LowPoly_Textured_00001_.glb; SN=$G/armor_shin_LowPoly_Textured_00001_.glb
  else
    HEAD=$G/${fac}_head_LowPoly_Textured_00001_.glb; NT=1; CK=0.62; CZ=1.37
    CH=$(part fa_${fac}_chest_$chest)
    SH=$(part fa_${fac}_shoulder); FO=$(part fa_${fac}_forearm); SN=$(part fa_${fac}_shin)
  fi
  GA=""; [ "$gl" != "-" ] && GA="--glow $gl"; [ "$pl" != "-" ] && GA="$GA --plate $pl"
  [ "$gear" != "-" ] && GA="$GA --gear $gear"
  P="\"head\": \"$HEAD\""
  [ "$chest" != "-" ] && P="$P, \"a_chest\": \"$CH\""
  [ "$sh" = "1" ] && P="$P, \"a_shoulder\": \"$SH\""
  [ "$fo" = "1" ] && P="$P, \"a_forearm\": \"$FO\""
  [ "$th" = "1" ] && P="$P, \"a_thigh\": \"$SN\""
  [ "$sn" = "1" ] && P="$P, \"a_shin\": \"$SN\""
  echo "{$P}" > "$J"
  rm -f game/assets/models/infantry/${fac}_${unit}*.import game/assets/models/infantry/${fac}_${unit}_*.jpg*
  "$B" -b -P game/tools/blender/build_modular_mx.py -- --parts "$J" --pal "$fac" --weapon "$weapon" --weapon-len "$wlen" --wflip 1 \
     --bw "$bw" --bh "$bh" --notint "$NT" --core-k "$CK" --chest-z "$CZ" --chest-w "$cw" --chest-h "$chh" --shoulder-size "$ss" \
     --muscle "$muscle" $GA --gain "$gn" \
     --clip-idle "$c_idle" --clip-walk "$c_walk" --clip-shoot "$c_shoot" --clip-die "$c_die" --clip-a "$c_a" --clip-b "$c_b" \
     --export-glb "game/assets/models/infantry/${fac}_${unit}.glb" 2>&1 | grep -E "Traceback|Error|GLB"
  echo done "$fac" "$unit"
done <<'L'
shibas | trooper        | AK             | 0.92 | 1.00 | 1.00 | a | 1 | 1 | 1 | 1 | 0.58 | 0.54 | 0.36 | 0.6 | pack_radio    | -             | -             | 1.0 | basic_shooter_pack/rifle aiming idle.fbx | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_back.fbx     | basic_shooter_pack/reloading.fbx          | mixamo/idle_military_salute.fbx
shibas | zapper         | Shotgun        | 0.96 | 1.08 | 1.00 | a | 1 | 1 | 1 | 1 | 0.64 | 0.56 | 0.42 | 1.2 | tesla_pack    | 0.2,0.92,1.0  | 0.25,0.4,0.65 | 1.1 | mixamo/idle_rifle_relaxed.fbx            | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_front.fbx    | mixamo/special_grenade_pull_pin_teeth.fbx | mixamo/idle_rifle_look_around.fbx
shibas | schnueffler    | SMG            | 0.65 | 0.90 | 1.02 | a | 0 | 1 | 0 | 1 | 0.52 | 0.50 | 0.30 | 0.0 | scout_pack    | 0.1,1.0,0.75  | -             | 1.0 | mixamo/katzen_crouch_look_corner.fbx     | mixamo/katzen_crouch_walk_rifle.fbx  | mixamo/katzen_crouch_fire_rifle.fbx       | mixamo/death_crouch_headshot.fbx| mixamo/idle_look_around_nervous.fbx       | mixamo/katzen_crouch_reload.fbx
shibas | ingenieur      | Briefcase      | 0.40 | 0.96 | 1.00 | a | 0 | 1 | 1 | 1 | 0.54 | 0.52 | 0.32 | 0.4 | engi_pack     | 0.15,0.95,0.9 | 0.85,0.62,0.12| 1.1 | mixamo/idle_bored.fbx                    | basic_shooter_pack/walking.fbx       | mixamo/special_kneel_inspect_repair.fbx   | mixamo/death_rifle_standing.fbx | mixamo/special_kneel_inspect_repair.fbx   | mixamo/special_work_on_device.fbx
katzen | streuner       | AK             | 0.92 | 0.94 | 1.03 | a | 1 | 1 | 1 | 1 | 0.56 | 0.54 | 0.36 | 0.4 | katzen_fins   | 0.75,0.2,1.0  | -             | 2.5 | basic_shooter_pack/rifle aiming idle.fbx | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_front.fbx    | basic_shooter_pack/reloading.fbx          | mixamo/idle_rifle_look_around.fbx
katzen | scharfschuetzin| Sniper         | 1.28 | 0.88 | 1.06 | b | 0 | 1 | 1 | 1 | 0.52 | 0.54 | 0.30 | 0.0 | sniper_pack   | 0.3,0.5,1.0   | 0.08,0.08,0.28| 2.2 | mixamo/katzen_sniper_kneel_idle.fbx      | mixamo/katzen_crouch_walk_rifle.fbx  | mixamo/katzen_crouch_fire_rifle.fbx       | mixamo/death_crouch_headshot.fbx| mixamo/katzen_crouch_reload.fbx           | mixamo/katzen_sniper_aim_to_kneel.fbx
katzen | hackerin       | Cyberdeck      | 0.50 | 0.90 | 1.02 | b | 0 | 1 | 0 | 1 | 0.52 | 0.52 | 0.32 | 0.0 | hacker_pack   | 1.0,0.2,0.85  | 0.32,0.06,0.28| 2.6 | mixamo/special_work_on_device.fbx        | basic_shooter_pack/walking.fbx       | mixamo/special_work_on_device.fbx         | mixamo/death_rifle_standing.fbx | mixamo/idle_look_around_nervous.fbx       | mixamo/idle_arm_stretch.fbx
katzen | saboteur       | C4Charge       | 0.40 | 0.92 | 0.98 | a | 1 | 1 | 1 | 1 | 0.54 | 0.52 | 0.34 | 0.3 | saboteur_pack | 0.85,0.1,0.95 | 0.07,0.04,0.14| 2.0 | mixamo/katzen_crouch_look_corner.fbx     | mixamo/katzen_crouch_walk_rifle.fbx  | mixamo/special_kneel_plant_charge.fbx     | mixamo/death_crouch_headshot.fbx| mixamo/special_kneel_plant_charge.fbx     | mixamo/special_grenade_pull_pin_teeth.fbx
baeren | grunzer        | AK             | 0.98 | 1.12 | 1.04 | a | 1 | 1 | 1 | 1 | 0.60 | 0.54 | 0.38 | 2.8 | ammo_pack     | -             | -             | 1.1 | basic_shooter_pack/rifle aiming idle.fbx | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_back.fbx     | mixamo/baeren_taunt_chest_thump.fbx       | basic_shooter_pack/reloading.fbx
baeren | feuertatze     | ShortCannon    | 0.82 | 1.16 | 1.05 | a | 1 | 1 | 1 | 1 | 0.62 | 0.56 | 0.40 | 3.2 | flame_tanks   | 1.0,0.32,0.06 | 0.35,0.07,0.04| 1.1 | mixamo/idle_rifle_relaxed.fbx            | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_front.fbx    | mixamo/baeren_taunt_battlecry.fbx         | mixamo/baeren_melee_swipe.fbx
baeren | bazooka        | RocketLauncher | 0.86 | 1.14 | 1.04 | b | 1 | 1 | 1 | 1 | 0.60 | 0.55 | 0.38 | 3.0 | rocket_pack   | -             | -             | 1.1 | basic_shooter_pack/rifle aiming idle.fbx | basic_shooter_pack/rifle run.fbx     | basic_shooter_pack/firing rifle.fbx       | mixamo/death_rifle_back.fbx     | basic_shooter_pack/reloading.fbx          | mixamo/baeren_taunt_flex_muscles.fbx
baeren | mechaniker     | WelderCase     | 0.50 | 1.10 | 1.02 | b | 0 | 1 | 1 | 1 | 0.58 | 0.53 | 0.36 | 2.6 | mech_pack     | 1.0,0.88,0.25 | 0.58,0.45,0.12| 1.1 | mixamo/idle_neck_stretch.fbx             | basic_shooter_pack/walking.fbx       | mixamo/special_kneel_inspect_repair.fbx   | mixamo/death_rifle_standing.fbx | mixamo/special_kneel_inspect_repair.fbx   | mixamo/baeren_taunt_flex_muscles.fbx
L

# Vierbeiner Cyber-Kampfmaschinen (kampfhund, panther, kodiak)
while read fac unit model length tint c_a c_b; do
  [ -z "$fac" ] && continue
  [ -n "$1" ] && [ "$1" != "$fac" ] && continue
  [ -n "$2" ] && [ "$2" != "$unit" ] && continue
  TA=""; [ "$tint" != "-" ] && TA="--tint $tint"
  rm -f game/assets/models/infantry/${fac}_${unit}*.import game/assets/models/infantry/${fac}_${unit}_*.jpg*
  "$B" -b -P game/tools/blender/build_quadruped.py -- --model "$model" --pal "$fac" --length "$length" $TA \
     --clip-idle idle-alert --clip-walk run --clip-shoot bite --clip-die death --clip-a "$c_a" --clip-b "$c_b" \
     --export-glb "game/assets/models/infantry/${fac}_${unit}.glb" 2>&1 | grep -E "Traceback|Error|GLB"
  echo done "$fac" "$unit"
done <<'Q'
shibas kampfhund dog_shiba 1.75 0.72,0.68,0.65 bark howl
katzen panther cat 1.72 0.14,0.11,0.18 sneak jump
baeren kodiak bear_panda 1.92 0.28,0.17,0.09 howl bark
Q
echo ALLDONE
