class_name TagTestZone
extends Area3D

const MC := preload("res://shared/scripts/movement_constants.gd")

@export var tag_speed: float = MC.SPEED_AK47

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("apply_bullet_tag"):
		body.apply_bullet_tag(tag_speed)
