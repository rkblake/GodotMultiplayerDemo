extends Node2D

const SPEED = 120
@onready var label: Label = $Label


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if is_multiplayer_authority(): $Camera2D.make_current()
	label.text = Network.get_player_name(get_multiplayer_authority())

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	global_position += input * SPEED  * delta
