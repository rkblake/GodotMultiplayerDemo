extends Control

const ONLINE_GAME_INFO = preload('res://online_game_info.tscn')

func _ready() -> void:
	$Back.pressed.connect(func(): get_tree().change_scene_to_file('res://main_menu.tscn'))
	refresh()

func refresh() -> void:
	$NoMatches.hide()
	for c in $ScrollContainer/VBoxContainer.get_children():
		c.queue_free()
	var matches = Network.get_matches()
	if len(matches) == 0:
		$NoMatches.show()
		return
	for m in matches:
		var game_info = ONLINE_GAME_INFO.instantiate()
		$ScrollContainer/VBoxContainer.add_child(game_info)
