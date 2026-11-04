class_name LadderVolume
extends Area3D

@export var face_normal := Vector3.FORWARD

func _init() -> void:
	collision_layer = 2
	collision_mask = 0
