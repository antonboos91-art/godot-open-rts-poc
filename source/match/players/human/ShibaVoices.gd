## Automatisch erzeugt von Assets-Pipeline/voice/build_pack.py - nicht von Hand bearbeiten.
## Shiba-Funkstimmen: LINES[einheit][kategorie] = [AudioStream, ...]
extends RefCounted

const LINES = {
	"all": {
		"ack_build": [
			preload("res://assets/voice/shibas/all/ack_build_0.wav"),
			preload("res://assets/voice/shibas/all/ack_build_1.wav"),
		],
		"annoyed": [
			preload("res://assets/voice/shibas/all/annoyed_0.wav"),
			preload("res://assets/voice/shibas/all/annoyed_1.wav"),
			preload("res://assets/voice/shibas/all/annoyed_2.wav"),
			preload("res://assets/voice/shibas/all/annoyed_3.wav"),
			preload("res://assets/voice/shibas/all/annoyed_4.wav"),
			preload("res://assets/voice/shibas/all/annoyed_5.wav"),
			preload("res://assets/voice/shibas/all/annoyed_6.wav"),
			preload("res://assets/voice/shibas/all/annoyed_7.wav"),
			preload("res://assets/voice/shibas/all/annoyed_8.wav"),
		],
		"attack": [
			preload("res://assets/voice/shibas/all/attack_0.wav"),
			preload("res://assets/voice/shibas/all/attack_1.wav"),
			preload("res://assets/voice/shibas/all/attack_2.wav"),
			preload("res://assets/voice/shibas/all/attack_3.wav"),
			preload("res://assets/voice/shibas/all/attack_4.wav"),
		],
		"death": [
			preload("res://assets/voice/shibas/all/death_0.wav"),
			preload("res://assets/voice/shibas/all/death_1.wav"),
		],
		"move": [
			preload("res://assets/voice/shibas/all/move_0.wav"),
			preload("res://assets/voice/shibas/all/move_1.wav"),
			preload("res://assets/voice/shibas/all/move_2.wav"),
			preload("res://assets/voice/shibas/all/move_3.wav"),
			preload("res://assets/voice/shibas/all/move_4.wav"),
		],
		"select": [
			preload("res://assets/voice/shibas/all/select_0.wav"),
			preload("res://assets/voice/shibas/all/select_1.wav"),
			preload("res://assets/voice/shibas/all/select_2.wav"),
			preload("res://assets/voice/shibas/all/select_3.wav"),
			preload("res://assets/voice/shibas/all/select_4.wav"),
		],
	},
	"announcer": {
		"base_under_attack": [
			preload("res://assets/voice/shibas/announcer/base_under_attack_0.wav"),
		],
		"unit_lost": [
			preload("res://assets/voice/shibas/announcer/unit_lost_0.wav"),
		],
		"power_low": [
			preload("res://assets/voice/shibas/announcer/power_low_0.wav"),
		],
		"construction_complete": [
			preload("res://assets/voice/shibas/announcer/construction_complete_0.wav"),
		],
		"training_complete": [
			preload("res://assets/voice/shibas/announcer/training_complete_0.wav"),
		],
		"superweapon_ready": [
			preload("res://assets/voice/shibas/announcer/superweapon_ready_0.wav"),
		],
		"treat_supplies_low_please_resupply": [
			preload("res://assets/voice/shibas/announcer/treat_supplies_low_please_resupply_0.wav"),
		],
	},
	"attack_hound": {
		"annoyed": [
			preload("res://assets/voice/shibas/attack_hound/annoyed_0.wav"),
			preload("res://assets/voice/shibas/attack_hound/annoyed_1.wav"),
			preload("res://assets/voice/shibas/attack_hound/annoyed_2.wav"),
		],
		"attack": [
			preload("res://assets/voice/shibas/attack_hound/attack_0.wav"),
			preload("res://assets/voice/shibas/attack_hound/attack_1.wav"),
			preload("res://assets/voice/shibas/attack_hound/attack_2.wav"),
		],
		"select": [
			preload("res://assets/voice/shibas/attack_hound/select_0.wav"),
			preload("res://assets/voice/shibas/attack_hound/select_1.wav"),
			preload("res://assets/voice/shibas/attack_hound/select_2.wav"),
		],
	},
	"engineer": {
		"capture": [
			preload("res://assets/voice/shibas/engineer/capture_0.wav"),
			preload("res://assets/voice/shibas/engineer/capture_1.wav"),
		],
		"repair": [
			preload("res://assets/voice/shibas/engineer/repair_0.wav"),
		],
		"select": [
			preload("res://assets/voice/shibas/engineer/select_0.wav"),
			preload("res://assets/voice/shibas/engineer/select_1.wav"),
		],
	},
}
