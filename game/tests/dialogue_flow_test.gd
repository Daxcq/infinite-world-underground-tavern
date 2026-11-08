extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	for method: StringName in [&"test_full_path", &"test_penalties", &"test_guards_and_pending", &"test_failure_routes"]:
		if call(method) != true:
			check(false, "%s completed" % method)
	print("DIALOGUE_FLOW: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(label)


func act(flow: TavernDialogueFlow, event: String) -> void:
	check(flow.send(event, flow.node_id, flow.revision), "%s accepts %s" % [flow.node_id, event])


func test_full_path() -> bool:
	var f := TavernDialogueFlow.new()
	check(f.nodes.size() == 59, "All 59 authored nodes loaded")
	act(f, "START")
	act(f, "TAKE_WINE")
	act(f, "DRINK_INTRO")
	check(f.state.initialized and f.state.gold == 100, "Tutorial initializes once")
	act(f, "CONTINUE")
	act(f, "CONTINUE")
	f.amount = 50
	act(f, "DECLARE_AMOUNT")
	act(f, "SELECT_SOLO")
	act(f, "CANCEL")
	check(f.state.mode == "TRIO" and f.state.gold == 100, "Cancelling solo draft does not change mode or debit")
	act(f, "SELECT_HONEST")
	var old_revision: int = f.revision
	act(f, "CONFIRM_STAKE")
	check(not f.send("CONFIRM_STAKE", "T03", old_revision) and f.state.gold == 50, "Stale submit cannot debit twice")
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "T05", "Exact tutorial stake 100 passes")
	act(f, "CONTINUE")
	f.dice_p.assign([6, 4, 1])
	f.dice_n.assign([3, 2, 1])
	f.dice_dealer.assign([5, 5, 5])
	f.state.npc_dice_locked = [0, 1]
	act(f, "CONTINUE")
	act(f, "KEEP_ONE")
	act(f, "CONFIRM_DICE")
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "T13" and f.state.gold == 100, "Equal pool total passes and returns only tutorial principal")
	check(f.state["keys"].is_empty() and f.state.player_penalties == 0, "Teaching awards no organ penalties or fragments")
	act(f, "PLAY_MORE")
	act(f, "DRINK_DESCENT")
	act(f, "CONTINUE_SYSTEM")
	check(f.state.player_chips == 100 and f.state.private_chips == 100, "Base chips and 1:1 converted gold are separate")
	act(f, "CONTINUE")
	act(f, "CONTINUE")
	act(f, "INSPECT_NPC")
	act(f, "SELECT_NPC")
	act(f, "CONTINUE")
	f.state.npc_kind = "OATH"
	act(f, "CONFIRM_TRIO")
	act(f, "CLAIM_READY")
	f.amount = 60
	act(f, "DECLARE_AMOUNT")
	act(f, "SELECT_HONEST")
	act(f, "CONFIRM_STAKE")
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "F14" and f.state.public_pot == 240, "Actual 60+60 forms matched pot")
	f.award("STAKE")
	check(f.state["keys"].size() == 1, "Repeated same-type reward deduplicates")
	act(f, "CONTINUE")
	f.dice_p.assign([6, 4, 1])
	f.dice_n.assign([3, 2, 1])
	f.dice_dealer.assign([3, 3, 3])
	f.state.npc_dice_locked = [0, 1]
	act(f, "CONTINUE_SYSTEM")
	var all_lines: String = str(f.lines())
	check(all_lines.contains("不会临时收回") and not all_lines.contains("GENERIC"), "Only matching NPC text branch is displayed")
	act(f, "CONTINUE")
	act(f, "KEEP_ONE")
	f.toggle_die(0)
	f.toggle_die(2)
	act(f, "CONFIRM_DICE")
	check(f.state.pool_contrib_p == 5 and f.hand_p == [6], "Dice selected by index, actual total and reserve are correct")
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "F25" and f.state["keys"].size() == 2, "Pool success does not skip CLEAR")
	act(f, "CONTINUE")
	act(f, "PREPARE")
	var money: int = f.funds()
	act(f, "BUY_PEEK")
	check(f.funds() == money - 25 and not f.allowed("BUY_PEEK"), "Tool purchase debits once and respects one-tool cap")
	act(f, "FINISH_PREP")
	check(f.use_peek() and f.feedback.contains("1 点"), "Peek reveals already locked die")
	var locked_die: int = int(f.state.opponent_index)
	act(f, "SELECT_DIE")
	act(f, "CANCEL")
	check(f.state.peek_used and f.state.opponent_index == locked_die, "Cancel after peek preserves opponent locked die and information")
	act(f, "SELECT_DIE")
	act(f, "CONFIRM_CLEAR")
	act(f, "CONTINUE_SYSTEM")
	check(f.hand_p == [6] and f.hand_n.is_empty(), "Higher die survives, lower die destroyed")
	act(f, "CONTINUE_SYSTEM")
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "E00" and f.state["keys"].size() == 3, "Three distinct victories unlock key")
	act(f, "OPEN_DOOR")
	check(f.node_id == "E01" and f.state.player_penalties == 0, "Escape ending restores body")
	return true


func test_penalties() -> bool:
	var f := TavernDialogueFlow.new()
	f.state.failure_origin = "POOL"
	f.state.responsible_party = "NPC"
	f.apply_penalty("npc-only")
	check(f.state.player_penalties == 0, "NPC-only responsibility never harms player")
	f.state.responsible_party = "PLAYER"
	f.apply_penalty("eye")
	f.apply_penalty("eye")
	check(f.state.player_penalties == 1 and f.state.paid_organ == "EYE", "Repeated action cannot consume two organs")
	f.state.responsible_party = "BOTH"
	f.apply_penalty("hand")
	check(f.state.player_penalties == 2 and f.state.paid_organ == "HAND", "Both responsibility consumes exactly next organ")
	f.node_id = "C01"
	f.state.player_chips = 100
	f.held_dice = true
	check(not f.allowed("BUY_PEEK"), "One-handed player must put dice back before another object")
	f.held_dice = false
	check(f.allowed("BUY_PEEK"), "Putting dice back makes tool operation legal")
	f.apply_penalty("heart")
	f.apply_penalty("fourth")
	check(f.state.player_penalties == 3 and f.state.paid_organ == "HEART", "Third penalty stops at heart")
	check(TavernDialogueFlow.responsibility(1, 4) == "PLAYER", "Lower contribution player liable")
	check(TavernDialogueFlow.responsibility(10, 4) == "NPC", "Lower contribution NPC liable")
	check(TavernDialogueFlow.responsibility(4, 4) == "BOTH", "Equal contribution both liable")
	check(TavernDialogueFlow.responsibility(9, 0, true) == "PLAYER", "Solo never invents NPC responsibility")
	return true


func test_guards_and_pending() -> bool:
	var f := TavernDialogueFlow.new()
	var before: Dictionary = f.state.duplicate(true)
	check(not f.send("TAKE_WINE", "B00", f.revision) and f.state == before, "Event outside current node has no effects")
	f._enter("F23")
	f.dice_p.assign([4, 4, 1])
	f.selected.assign([0, 1])
	check(f.allowed("CONFIRM_DICE") and f.variables().selected_total == 8, "Equal-valued dice remain two distinct dice")
	f.selected.assign([0, 0])
	check(not f.allowed("CONFIRM_DICE"), "Duplicate die IDs rejected")
	f.selected.clear()
	check(not f.allowed("CONFIRM_DICE"), "Zero dice cannot be submitted")
	f._enter("C06")
	f.hand_p.clear()
	f.hand_n.clear()
	act(f, "CONTINUE_SYSTEM")
	check(f.node_id == "Q02" and not f.blocked.is_empty(), "Final simultaneous destruction remains undecided")
	f = TavernDialogueFlow.new()
	f._enter("Q01")
	check(f.options()[0].event == "TITLE", "Unresolved bill has no fabricated exit")
	f = TavernDialogueFlow.new()
	f._enter("P03")
	f.state.failure_origin = "POOL"
	act(f, "CONTINUE")
	check(not f.blocked.is_empty(), "Proposed pool-retry edge is not silently activated")
	f = TavernDialogueFlow.new()
	f._enter("N03")
	check(not f.allowed("CONFIRM_SOLO"), "Undefined solo CLEAR hand source stays unavailable")
	for id: String in f.nodes:
		f._enter(id)
		for line: Dictionary in f.lines():
			check(not String(line.text).contains("{"), "All runtime text variables resolve at %s" % id)
	return true


func test_failure_routes() -> bool:
	for contributions: Array in [[40, 60, "PLAYER"], [60, 40, "NPC"], [40, 40, "BOTH"]]:
		var f := TavernDialogueFlow.new()
		f.state.actual_p = contributions[0]
		f.state.actual_n = contributions[1]
		f.state.npc_selected = true
		f._enter("F15")
		act(f, "CONTINUE")
		act(f, "CONTINUE_SYSTEM")
		check(f.state.responsible_party == contributions[2], "Failed stake computes responsibility from actual contributions")
		act(f, "CONTINUE_SYSTEM")
		check(f.state.player_penalties == (0 if contributions[2] == "NPC" else 1), "Failed stake pays only responsible organ")
		act(f, "CONTINUE")
		check(f.node_id == "N03" and not f.state.npc_selected, "Ejected table requires selecting a companion again")
	var f := TavernDialogueFlow.new()
	f.state.gold = 0
	f._enter("T07")
	act(f, "USE_RESCUE")
	check(f.state.gold == 40 and f.state.rescue_wine_count == 0, "Approved rescue wine restores 40 and is consumed once")
	f._enter("T07")
	check(not f.allowed("USE_RESCUE"), "Reopening rescue text cannot refill wine")
	f._enter("N03")
	f.state.player_chips = 0
	f.state.private_chips = 5
	f.state.npc_chips = 0
	f.state.npc_private = 0
	f.state.npc_selected = true
	f._table = 1
	act(f, "CONFIRM_TRIO")
	check(f.funds() == 60 and f.state.npc_chips == 60, "New table tops low available balances to 60, preserving private chips")
	return true
