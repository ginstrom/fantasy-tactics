extends Control

## Party management now lives in Parties (reached from Units). This scene is
## kept only as a testable redirect so GameManager.open_party_manager() and
## the debug-menu "party_manager" scenario still land somewhere real instead
## of a dead-ending second management UI.


func _ready() -> void:
	# change_scene_to_file cannot run while the tree is still building this
	# node, so the actual redirect is deferred to the next idle frame.
	call_deferred("_redirect_to_parties")


func _redirect_to_parties() -> void:
	GameManager.go_to_parties()
