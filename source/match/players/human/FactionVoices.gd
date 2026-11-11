## Automatisch erzeugt von tools/voice_pipeline/build_voices.py - nicht von Hand bearbeiten.
## Stimmen aller Voelker: LINES[volk][paket][kategorie] = [AudioStream, ...]
## Pakete: all, worker, vehicle, air, beast, engineer, announcer
extends RefCounted

const LINES = {
	"baeren": {
		"air": {
			"attack": [
				preload("res://assets/voice/baeren/air/attack_0.wav"),
				preload("res://assets/voice/baeren/air/attack_1.wav"),
				preload("res://assets/voice/baeren/air/attack_2.wav"),
			],
			"move": [
				preload("res://assets/voice/baeren/air/move_0.wav"),
				preload("res://assets/voice/baeren/air/move_1.wav"),
				preload("res://assets/voice/baeren/air/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/air/select_0.wav"),
				preload("res://assets/voice/baeren/air/select_1.wav"),
				preload("res://assets/voice/baeren/air/select_2.wav"),
			],
		},
		"all": {
			"annoyed": [
				preload("res://assets/voice/baeren/all/annoyed_0.wav"),
				preload("res://assets/voice/baeren/all/annoyed_1.wav"),
				preload("res://assets/voice/baeren/all/annoyed_2.wav"),
				preload("res://assets/voice/baeren/all/annoyed_3.wav"),
				preload("res://assets/voice/baeren/all/annoyed_4.wav"),
				preload("res://assets/voice/baeren/all/annoyed_5.wav"),
				preload("res://assets/voice/baeren/all/annoyed_6.wav"),
				preload("res://assets/voice/baeren/all/annoyed_7.wav"),
			],
			"attack": [
				preload("res://assets/voice/baeren/all/attack_0.wav"),
				preload("res://assets/voice/baeren/all/attack_1.wav"),
				preload("res://assets/voice/baeren/all/attack_2.wav"),
				preload("res://assets/voice/baeren/all/attack_3.wav"),
				preload("res://assets/voice/baeren/all/attack_4.wav"),
				preload("res://assets/voice/baeren/all/attack_5.wav"),
				preload("res://assets/voice/baeren/all/attack_6.wav"),
				preload("res://assets/voice/baeren/all/attack_7.wav"),
			],
			"death": [
				preload("res://assets/voice/baeren/all/death_0.wav"),
				preload("res://assets/voice/baeren/all/death_1.wav"),
				preload("res://assets/voice/baeren/all/death_2.wav"),
			],
			"move": [
				preload("res://assets/voice/baeren/all/move_0.wav"),
				preload("res://assets/voice/baeren/all/move_1.wav"),
				preload("res://assets/voice/baeren/all/move_2.wav"),
				preload("res://assets/voice/baeren/all/move_3.wav"),
				preload("res://assets/voice/baeren/all/move_4.wav"),
				preload("res://assets/voice/baeren/all/move_5.wav"),
				preload("res://assets/voice/baeren/all/move_6.wav"),
				preload("res://assets/voice/baeren/all/move_7.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/all/select_0.wav"),
				preload("res://assets/voice/baeren/all/select_1.wav"),
				preload("res://assets/voice/baeren/all/select_2.wav"),
				preload("res://assets/voice/baeren/all/select_3.wav"),
				preload("res://assets/voice/baeren/all/select_4.wav"),
				preload("res://assets/voice/baeren/all/select_5.wav"),
				preload("res://assets/voice/baeren/all/select_6.wav"),
				preload("res://assets/voice/baeren/all/select_7.wav"),
			],
		},
		"announcer": {
			"base_under_attack": [
				preload("res://assets/voice/baeren/announcer/base_under_attack_0.wav"),
			],
			"building": [
				preload("res://assets/voice/baeren/announcer/building_0.wav"),
			],
			"building_lost": [
				preload("res://assets/voice/baeren/announcer/building_lost_0.wav"),
			],
			"construction_complete": [
				preload("res://assets/voice/baeren/announcer/construction_complete_0.wav"),
			],
			"harvester_under_attack": [
				preload("res://assets/voice/baeren/announcer/harvester_under_attack_0.wav"),
			],
			"insufficient_funds": [
				preload("res://assets/voice/baeren/announcer/insufficient_funds_0.wav"),
			],
			"low_power": [
				preload("res://assets/voice/baeren/announcer/low_power_0.wav"),
			],
			"mission_accomplished": [
				preload("res://assets/voice/baeren/announcer/mission_accomplished_0.wav"),
			],
			"mission_failed": [
				preload("res://assets/voice/baeren/announcer/mission_failed_0.wav"),
			],
			"power_restored": [
				preload("res://assets/voice/baeren/announcer/power_restored_0.wav"),
			],
			"select_target": [
				preload("res://assets/voice/baeren/announcer/select_target_0.wav"),
			],
			"superweapon_ready": [
				preload("res://assets/voice/baeren/announcer/superweapon_ready_0.wav"),
			],
			"training_complete": [
				preload("res://assets/voice/baeren/announcer/training_complete_0.wav"),
			],
			"unit_lost": [
				preload("res://assets/voice/baeren/announcer/unit_lost_0.wav"),
			],
			"unit_under_attack": [
				preload("res://assets/voice/baeren/announcer/unit_under_attack_0.wav"),
			],
			"welcome": [
				preload("res://assets/voice/baeren/announcer/welcome_0.wav"),
			],
		},
		"beast": {
			"annoyed": [
				preload("res://assets/voice/baeren/beast/annoyed_0.wav"),
				preload("res://assets/voice/baeren/beast/annoyed_1.wav"),
				preload("res://assets/voice/baeren/beast/annoyed_2.wav"),
			],
			"attack": [
				preload("res://assets/voice/baeren/beast/attack_0.wav"),
				preload("res://assets/voice/baeren/beast/attack_1.wav"),
				preload("res://assets/voice/baeren/beast/attack_2.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/beast/select_0.wav"),
				preload("res://assets/voice/baeren/beast/select_1.wav"),
				preload("res://assets/voice/baeren/beast/select_2.wav"),
			],
		},
		"engineer": {
			"capture": [
				preload("res://assets/voice/baeren/engineer/capture_0.wav"),
				preload("res://assets/voice/baeren/engineer/capture_1.wav"),
			],
			"repair": [
				preload("res://assets/voice/baeren/engineer/repair_0.wav"),
				preload("res://assets/voice/baeren/engineer/repair_1.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/engineer/select_0.wav"),
				preload("res://assets/voice/baeren/engineer/select_1.wav"),
				preload("res://assets/voice/baeren/engineer/select_2.wav"),
			],
		},
		"vehicle": {
			"attack": [
				preload("res://assets/voice/baeren/vehicle/attack_0.wav"),
				preload("res://assets/voice/baeren/vehicle/attack_1.wav"),
				preload("res://assets/voice/baeren/vehicle/attack_2.wav"),
				preload("res://assets/voice/baeren/vehicle/attack_3.wav"),
			],
			"move": [
				preload("res://assets/voice/baeren/vehicle/move_0.wav"),
				preload("res://assets/voice/baeren/vehicle/move_1.wav"),
				preload("res://assets/voice/baeren/vehicle/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/vehicle/select_0.wav"),
				preload("res://assets/voice/baeren/vehicle/select_1.wav"),
				preload("res://assets/voice/baeren/vehicle/select_2.wav"),
				preload("res://assets/voice/baeren/vehicle/select_3.wav"),
				preload("res://assets/voice/baeren/vehicle/select_4.wav"),
			],
		},
		"worker": {
			"harvest": [
				preload("res://assets/voice/baeren/worker/harvest_0.wav"),
				preload("res://assets/voice/baeren/worker/harvest_1.wav"),
				preload("res://assets/voice/baeren/worker/harvest_2.wav"),
			],
			"move": [
				preload("res://assets/voice/baeren/worker/move_0.wav"),
				preload("res://assets/voice/baeren/worker/move_1.wav"),
				preload("res://assets/voice/baeren/worker/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/baeren/worker/select_0.wav"),
				preload("res://assets/voice/baeren/worker/select_1.wav"),
				preload("res://assets/voice/baeren/worker/select_2.wav"),
			],
		},
	},
	"katzen": {
		"air": {
			"attack": [
				preload("res://assets/voice/katzen/air/attack_0.wav"),
				preload("res://assets/voice/katzen/air/attack_1.wav"),
				preload("res://assets/voice/katzen/air/attack_2.wav"),
			],
			"move": [
				preload("res://assets/voice/katzen/air/move_0.wav"),
				preload("res://assets/voice/katzen/air/move_1.wav"),
				preload("res://assets/voice/katzen/air/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/air/select_0.wav"),
				preload("res://assets/voice/katzen/air/select_1.wav"),
				preload("res://assets/voice/katzen/air/select_2.wav"),
			],
		},
		"all": {
			"annoyed": [
				preload("res://assets/voice/katzen/all/annoyed_0.wav"),
				preload("res://assets/voice/katzen/all/annoyed_1.wav"),
				preload("res://assets/voice/katzen/all/annoyed_2.wav"),
				preload("res://assets/voice/katzen/all/annoyed_3.wav"),
				preload("res://assets/voice/katzen/all/annoyed_4.wav"),
				preload("res://assets/voice/katzen/all/annoyed_5.wav"),
				preload("res://assets/voice/katzen/all/annoyed_6.wav"),
				preload("res://assets/voice/katzen/all/annoyed_7.wav"),
			],
			"attack": [
				preload("res://assets/voice/katzen/all/attack_0.wav"),
				preload("res://assets/voice/katzen/all/attack_1.wav"),
				preload("res://assets/voice/katzen/all/attack_2.wav"),
				preload("res://assets/voice/katzen/all/attack_3.wav"),
				preload("res://assets/voice/katzen/all/attack_4.wav"),
				preload("res://assets/voice/katzen/all/attack_5.wav"),
				preload("res://assets/voice/katzen/all/attack_6.wav"),
				preload("res://assets/voice/katzen/all/attack_7.wav"),
			],
			"death": [
				preload("res://assets/voice/katzen/all/death_0.wav"),
				preload("res://assets/voice/katzen/all/death_1.wav"),
				preload("res://assets/voice/katzen/all/death_2.wav"),
			],
			"move": [
				preload("res://assets/voice/katzen/all/move_0.wav"),
				preload("res://assets/voice/katzen/all/move_1.wav"),
				preload("res://assets/voice/katzen/all/move_2.wav"),
				preload("res://assets/voice/katzen/all/move_3.wav"),
				preload("res://assets/voice/katzen/all/move_4.wav"),
				preload("res://assets/voice/katzen/all/move_5.wav"),
				preload("res://assets/voice/katzen/all/move_6.wav"),
				preload("res://assets/voice/katzen/all/move_7.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/all/select_0.wav"),
				preload("res://assets/voice/katzen/all/select_1.wav"),
				preload("res://assets/voice/katzen/all/select_2.wav"),
				preload("res://assets/voice/katzen/all/select_3.wav"),
				preload("res://assets/voice/katzen/all/select_4.wav"),
				preload("res://assets/voice/katzen/all/select_5.wav"),
				preload("res://assets/voice/katzen/all/select_6.wav"),
				preload("res://assets/voice/katzen/all/select_7.wav"),
			],
		},
		"announcer": {
			"base_under_attack": [
				preload("res://assets/voice/katzen/announcer/base_under_attack_0.wav"),
			],
			"building": [
				preload("res://assets/voice/katzen/announcer/building_0.wav"),
			],
			"building_lost": [
				preload("res://assets/voice/katzen/announcer/building_lost_0.wav"),
			],
			"construction_complete": [
				preload("res://assets/voice/katzen/announcer/construction_complete_0.wav"),
			],
			"harvester_under_attack": [
				preload("res://assets/voice/katzen/announcer/harvester_under_attack_0.wav"),
			],
			"insufficient_funds": [
				preload("res://assets/voice/katzen/announcer/insufficient_funds_0.wav"),
			],
			"low_power": [
				preload("res://assets/voice/katzen/announcer/low_power_0.wav"),
			],
			"mission_accomplished": [
				preload("res://assets/voice/katzen/announcer/mission_accomplished_0.wav"),
			],
			"mission_failed": [
				preload("res://assets/voice/katzen/announcer/mission_failed_0.wav"),
			],
			"power_restored": [
				preload("res://assets/voice/katzen/announcer/power_restored_0.wav"),
			],
			"select_target": [
				preload("res://assets/voice/katzen/announcer/select_target_0.wav"),
			],
			"superweapon_ready": [
				preload("res://assets/voice/katzen/announcer/superweapon_ready_0.wav"),
			],
			"training_complete": [
				preload("res://assets/voice/katzen/announcer/training_complete_0.wav"),
			],
			"unit_lost": [
				preload("res://assets/voice/katzen/announcer/unit_lost_0.wav"),
			],
			"unit_under_attack": [
				preload("res://assets/voice/katzen/announcer/unit_under_attack_0.wav"),
			],
			"welcome": [
				preload("res://assets/voice/katzen/announcer/welcome_0.wav"),
			],
		},
		"beast": {
			"annoyed": [
				preload("res://assets/voice/katzen/beast/annoyed_0.wav"),
				preload("res://assets/voice/katzen/beast/annoyed_1.wav"),
				preload("res://assets/voice/katzen/beast/annoyed_2.wav"),
			],
			"attack": [
				preload("res://assets/voice/katzen/beast/attack_0.wav"),
				preload("res://assets/voice/katzen/beast/attack_1.wav"),
				preload("res://assets/voice/katzen/beast/attack_2.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/beast/select_0.wav"),
				preload("res://assets/voice/katzen/beast/select_1.wav"),
				preload("res://assets/voice/katzen/beast/select_2.wav"),
			],
		},
		"engineer": {
			"capture": [
				preload("res://assets/voice/katzen/engineer/capture_0.wav"),
				preload("res://assets/voice/katzen/engineer/capture_1.wav"),
			],
			"repair": [
				preload("res://assets/voice/katzen/engineer/repair_0.wav"),
				preload("res://assets/voice/katzen/engineer/repair_1.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/engineer/select_0.wav"),
				preload("res://assets/voice/katzen/engineer/select_1.wav"),
				preload("res://assets/voice/katzen/engineer/select_2.wav"),
			],
		},
		"vehicle": {
			"attack": [
				preload("res://assets/voice/katzen/vehicle/attack_0.wav"),
				preload("res://assets/voice/katzen/vehicle/attack_1.wav"),
				preload("res://assets/voice/katzen/vehicle/attack_2.wav"),
				preload("res://assets/voice/katzen/vehicle/attack_3.wav"),
			],
			"move": [
				preload("res://assets/voice/katzen/vehicle/move_0.wav"),
				preload("res://assets/voice/katzen/vehicle/move_1.wav"),
				preload("res://assets/voice/katzen/vehicle/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/vehicle/select_0.wav"),
				preload("res://assets/voice/katzen/vehicle/select_1.wav"),
				preload("res://assets/voice/katzen/vehicle/select_2.wav"),
				preload("res://assets/voice/katzen/vehicle/select_3.wav"),
				preload("res://assets/voice/katzen/vehicle/select_4.wav"),
			],
		},
		"worker": {
			"harvest": [
				preload("res://assets/voice/katzen/worker/harvest_0.wav"),
				preload("res://assets/voice/katzen/worker/harvest_1.wav"),
				preload("res://assets/voice/katzen/worker/harvest_2.wav"),
			],
			"move": [
				preload("res://assets/voice/katzen/worker/move_0.wav"),
				preload("res://assets/voice/katzen/worker/move_1.wav"),
				preload("res://assets/voice/katzen/worker/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/katzen/worker/select_0.wav"),
				preload("res://assets/voice/katzen/worker/select_1.wav"),
				preload("res://assets/voice/katzen/worker/select_2.wav"),
			],
		},
	},
	"shibas": {
		"air": {
			"attack": [
				preload("res://assets/voice/shibas/air/attack_0.wav"),
				preload("res://assets/voice/shibas/air/attack_1.wav"),
				preload("res://assets/voice/shibas/air/attack_2.wav"),
			],
			"move": [
				preload("res://assets/voice/shibas/air/move_0.wav"),
				preload("res://assets/voice/shibas/air/move_1.wav"),
				preload("res://assets/voice/shibas/air/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/air/select_0.wav"),
				preload("res://assets/voice/shibas/air/select_1.wav"),
				preload("res://assets/voice/shibas/air/select_2.wav"),
			],
		},
		"all": {
			"annoyed": [
				preload("res://assets/voice/shibas/all/annoyed_0.wav"),
				preload("res://assets/voice/shibas/all/annoyed_1.wav"),
				preload("res://assets/voice/shibas/all/annoyed_2.wav"),
				preload("res://assets/voice/shibas/all/annoyed_3.wav"),
				preload("res://assets/voice/shibas/all/annoyed_4.wav"),
				preload("res://assets/voice/shibas/all/annoyed_5.wav"),
				preload("res://assets/voice/shibas/all/annoyed_6.wav"),
				preload("res://assets/voice/shibas/all/annoyed_7.wav"),
			],
			"attack": [
				preload("res://assets/voice/shibas/all/attack_0.wav"),
				preload("res://assets/voice/shibas/all/attack_1.wav"),
				preload("res://assets/voice/shibas/all/attack_2.wav"),
				preload("res://assets/voice/shibas/all/attack_3.wav"),
				preload("res://assets/voice/shibas/all/attack_4.wav"),
				preload("res://assets/voice/shibas/all/attack_5.wav"),
				preload("res://assets/voice/shibas/all/attack_6.wav"),
				preload("res://assets/voice/shibas/all/attack_7.wav"),
			],
			"death": [
				preload("res://assets/voice/shibas/all/death_0.wav"),
				preload("res://assets/voice/shibas/all/death_1.wav"),
				preload("res://assets/voice/shibas/all/death_2.wav"),
			],
			"move": [
				preload("res://assets/voice/shibas/all/move_0.wav"),
				preload("res://assets/voice/shibas/all/move_1.wav"),
				preload("res://assets/voice/shibas/all/move_2.wav"),
				preload("res://assets/voice/shibas/all/move_3.wav"),
				preload("res://assets/voice/shibas/all/move_4.wav"),
				preload("res://assets/voice/shibas/all/move_5.wav"),
				preload("res://assets/voice/shibas/all/move_6.wav"),
				preload("res://assets/voice/shibas/all/move_7.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/all/select_0.wav"),
				preload("res://assets/voice/shibas/all/select_1.wav"),
				preload("res://assets/voice/shibas/all/select_2.wav"),
				preload("res://assets/voice/shibas/all/select_3.wav"),
				preload("res://assets/voice/shibas/all/select_4.wav"),
				preload("res://assets/voice/shibas/all/select_5.wav"),
				preload("res://assets/voice/shibas/all/select_6.wav"),
				preload("res://assets/voice/shibas/all/select_7.wav"),
			],
		},
		"announcer": {
			"base_under_attack": [
				preload("res://assets/voice/shibas/announcer/base_under_attack_0.wav"),
			],
			"building": [
				preload("res://assets/voice/shibas/announcer/building_0.wav"),
			],
			"building_lost": [
				preload("res://assets/voice/shibas/announcer/building_lost_0.wav"),
			],
			"construction_complete": [
				preload("res://assets/voice/shibas/announcer/construction_complete_0.wav"),
			],
			"harvester_under_attack": [
				preload("res://assets/voice/shibas/announcer/harvester_under_attack_0.wav"),
			],
			"insufficient_funds": [
				preload("res://assets/voice/shibas/announcer/insufficient_funds_0.wav"),
			],
			"low_power": [
				preload("res://assets/voice/shibas/announcer/low_power_0.wav"),
			],
			"mission_accomplished": [
				preload("res://assets/voice/shibas/announcer/mission_accomplished_0.wav"),
			],
			"mission_failed": [
				preload("res://assets/voice/shibas/announcer/mission_failed_0.wav"),
			],
			"power_restored": [
				preload("res://assets/voice/shibas/announcer/power_restored_0.wav"),
			],
			"select_target": [
				preload("res://assets/voice/shibas/announcer/select_target_0.wav"),
			],
			"superweapon_ready": [
				preload("res://assets/voice/shibas/announcer/superweapon_ready_0.wav"),
			],
			"training_complete": [
				preload("res://assets/voice/shibas/announcer/training_complete_0.wav"),
			],
			"unit_lost": [
				preload("res://assets/voice/shibas/announcer/unit_lost_0.wav"),
			],
			"unit_under_attack": [
				preload("res://assets/voice/shibas/announcer/unit_under_attack_0.wav"),
			],
			"welcome": [
				preload("res://assets/voice/shibas/announcer/welcome_0.wav"),
			],
		},
		"beast": {
			"annoyed": [
				preload("res://assets/voice/shibas/beast/annoyed_0.wav"),
				preload("res://assets/voice/shibas/beast/annoyed_1.wav"),
				preload("res://assets/voice/shibas/beast/annoyed_2.wav"),
			],
			"attack": [
				preload("res://assets/voice/shibas/beast/attack_0.wav"),
				preload("res://assets/voice/shibas/beast/attack_1.wav"),
				preload("res://assets/voice/shibas/beast/attack_2.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/beast/select_0.wav"),
				preload("res://assets/voice/shibas/beast/select_1.wav"),
				preload("res://assets/voice/shibas/beast/select_2.wav"),
			],
		},
		"engineer": {
			"capture": [
				preload("res://assets/voice/shibas/engineer/capture_0.wav"),
				preload("res://assets/voice/shibas/engineer/capture_1.wav"),
			],
			"repair": [
				preload("res://assets/voice/shibas/engineer/repair_0.wav"),
				preload("res://assets/voice/shibas/engineer/repair_1.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/engineer/select_0.wav"),
				preload("res://assets/voice/shibas/engineer/select_1.wav"),
				preload("res://assets/voice/shibas/engineer/select_2.wav"),
			],
		},
		"vehicle": {
			"attack": [
				preload("res://assets/voice/shibas/vehicle/attack_0.wav"),
				preload("res://assets/voice/shibas/vehicle/attack_1.wav"),
				preload("res://assets/voice/shibas/vehicle/attack_2.wav"),
				preload("res://assets/voice/shibas/vehicle/attack_3.wav"),
			],
			"move": [
				preload("res://assets/voice/shibas/vehicle/move_0.wav"),
				preload("res://assets/voice/shibas/vehicle/move_1.wav"),
				preload("res://assets/voice/shibas/vehicle/move_2.wav"),
				preload("res://assets/voice/shibas/vehicle/move_3.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/vehicle/select_0.wav"),
				preload("res://assets/voice/shibas/vehicle/select_1.wav"),
				preload("res://assets/voice/shibas/vehicle/select_2.wav"),
				preload("res://assets/voice/shibas/vehicle/select_3.wav"),
				preload("res://assets/voice/shibas/vehicle/select_4.wav"),
			],
		},
		"worker": {
			"harvest": [
				preload("res://assets/voice/shibas/worker/harvest_0.wav"),
				preload("res://assets/voice/shibas/worker/harvest_1.wav"),
				preload("res://assets/voice/shibas/worker/harvest_2.wav"),
			],
			"move": [
				preload("res://assets/voice/shibas/worker/move_0.wav"),
				preload("res://assets/voice/shibas/worker/move_1.wav"),
				preload("res://assets/voice/shibas/worker/move_2.wav"),
			],
			"select": [
				preload("res://assets/voice/shibas/worker/select_0.wav"),
				preload("res://assets/voice/shibas/worker/select_1.wav"),
				preload("res://assets/voice/shibas/worker/select_2.wav"),
				preload("res://assets/voice/shibas/worker/select_3.wav"),
			],
		},
	},
}
