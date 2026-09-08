extends Control

@export_file("*.tscn") var idle_game_scene_path: String

const CARD_SCENE := preload("res://features/upgrades/upgrade_card.tscn")


func _ready() -> void:
	%Back.text = tr("Back")
	_build_cards()
	refresh()


func refresh() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(GameState.prestige())
	for child in %Cards.get_children():
		var card := child as UpgradeCard
		if card == null:
			continue
		card.refresh()


func _build_cards() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		var card := CARD_SCENE.instantiate() as UpgradeCard
		%Cards.add_child(card)
		card.setup(upgrade)
		card.purchased.connect(refresh)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)
