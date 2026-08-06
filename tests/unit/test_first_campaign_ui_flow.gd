extends GutTest

const PartiesScene := preload("res://scenes/ui/parties.tscn")
const PartyDetailsScene := preload("res://scenes/ui/party_details.tscn")
const AddMemberScene := preload("res://scenes/ui/add_member.tscn")
const DeployPartyScene := preload("res://scenes/ui/deploy_party.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func test_fresh_campaign_ui_reaches_a_deployed_first_party() -> void:
	assert_eq(GameSession.parties.size(), 0)
	var parties: Control = PartiesScene.instantiate()
	add_child_autofree(parties)
	var create_button: Button = parties.get_node("Center/VBox/CreatePartyButton")
	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
	assert_eq(GameSession.parties.size(), 1)

	var party_table: Tree = parties.get_node("Center/VBox/PartyTable/Tree")
	party_table.get_root().get_first_child().select(0)
	party_table.emit_signal("item_activated")
	var details: Control = PartyDetailsScene.instantiate()
	add_child_autofree(details)
	assert_eq(details.party_id, GameSession.FIRST_PARTY_ID)

	var add_member_button: Button = details.get_node("Center/VBox/AddMemberButton")
	assert_true(add_member_button.visible)
	assert_false(add_member_button.disabled)
	add_member_button.emit_signal("pressed")
	var add_member: Control = AddMemberScene.instantiate()
	add_child_autofree(add_member)
	var adventurer_table: Tree = add_member.get_node("Center/VBox/AdventurerTable/Tree")
	adventurer_table.get_root().get_first_child().select(0)
	adventurer_table.emit_signal("item_activated")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])

	GameManager.go_to_deploy_party()
	var deploy_party: Control = DeployPartyScene.instantiate()
	add_child_autofree(deploy_party)
	var deploy_table: Tree = deploy_party.get_node("Center/VBox/PartyTable/Tree")
	assert_ne(deploy_table.get_root().get_first_child(), null)
	deploy_table.get_root().get_first_child().select(0)
	deploy_table.emit_signal("item_activated")

	assert_true(GameSession.has_deployed_party())
	assert_eq(GameManager.route_context_id, "")
