class_name TavernDialogueFlow
extends RefCounted
## The v2 JSON owns text and destinations. Named handlers own game rules; no eval.

var nodes: Dictionary = {}
var balance: Dictionary = {}
var node_id: String = "B00"
var revision: int = 0
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}
var settled: Dictionary = {}
var selected: Array[int] = []
var dice_p: Array[int] = []
var dice_n: Array[int] = []
var dice_dealer: Array[int] = []
var hand_p: Array[int] = []
var hand_n: Array[int] = []
var amount: int = 50
var chosen: int = 0
var held_dice: bool = false
var feedback: String = ""
var blocked: String = ""
var _round: int = 0
var _table: int = 0
var _stake_paid: int = 0
var _npc_keeps: bool = false
var npc_roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/underground_npcs.json"))
var candidate: int = 0


func _init() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_v2.json"))
	if not source is Dictionary or not source.get("nodes") is Array:
		push_error("TavernDialogueFlow: invalid dialogue_v2.json")
		blocked = "对白资料无法载入。请返回标题。"
		return
	for entry: Dictionary in source["nodes"]:
		nodes[entry["id"]] = entry
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/playtest_balance.json"))
	rng.randomize()
	state = {"gold": 100, "rescue_wine_count": 1, "initialized": false,
		"intro_taken": false, "intro_drunk": false, "descent_reason": "VOLUNTARY",
		"underground": false, "mode": "TRIO", "draft_mode": "TRIO", "npc_kind": "CALCULATING", "npc_selected": false, "npc_id": "calculating", "npc_name": "落单的冒险者",
		"player_chips": 0, "npc_chips": 0, "private_chips": 0, "npc_private": 0,
		"promised_p": 50, "promised_n": 50, "actual_p": 0, "actual_n": 0,
		"draft_actual_p": 50, "strategy": "HONEST", "public_pot": 0,
		"pool_contrib_p": 0, "pool_contrib_n": 0, "responsible_party": "PLAYER",
		"player_penalties": 0, "failed_rounds": 0, "paid_organ": "", "keys": {},
		"next_open_p": false, "next_open_n": false, "open_p": false, "open_n": false,
		"failure_origin": "", "tool": "", "peek_used": false, "opponent_locked": false,
		"surrender_confirmed": false, "face_p": 0, "face_n": 0}


func node() -> Dictionary:
	return nodes.get(node_id, {})


func lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not blocked.is_empty():
		return [{"speaker": "酒馆", "text": blocked}]
	for item: Dictionary in node().get("lines", []):
		if _line_allowed(item.get("when", "true")):
			var speaker: String = item["speaker"]
			if state.underground:
				if speaker == "荷官": speaker = "酒保 · 荷官"
				elif speaker == "同伴": speaker = String(state.npc_name)
			result.append({"speaker": speaker, "text": String(item["text"]).format(variables())})
	return result


func choose_candidate(index: int) -> bool:
	if node_id not in ["N00", "N01"] or index < 0 or index >= npc_roster.size(): return false
	candidate = index
	revision += 1
	return true


func _line_allowed(condition: String) -> bool:
	match condition:
		"true": return true
		"descent_reason==VOLUNTARY": return state.descent_reason == "VOLUNTARY"
		"descent_reason==TUTORIAL_LOSS": return state.descent_reason == "TUTORIAL_LOSS"
		"mode==SOLO": return state.mode == "SOLO"
		"mode==TRIO": return state.mode == "TRIO"
		"paid_organ==EYE": return state.paid_organ == "EYE"
		"paid_organ==HAND": return state.paid_organ == "HAND"
		_:
			return condition == "mode==TRIO and npc_kind==" + String(state.npc_kind) and state.mode == "TRIO"


func options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not blocked.is_empty() or node().get("kind") in ["terminal", "pending"]:
		return [{"event": "TITLE", "text": "返回标题", "enabled": true}]
	for edge: Dictionary in node().get("transitions", []):
		if node_id == "T06" and edge != node()["transitions"][0 if int(state.gold) == 0 and int(state.rescue_wine_count) > 0 else 1]: continue
		if node_id in ["P02", "P03"] and edge != node()["transitions"][1 if state.failure_origin == "POOL" else 0]: continue
		if not String(edge["label"]).is_empty():
			var hint: String = _disabled_reason(edge["event"]) if not allowed(edge["event"]) else _runtime_hint(edge["event"], edge["hint"])
			result.append({"event": edge["event"], "text": edge["label"],
				"enabled": allowed(edge["event"]), "hint": hint})
	if result.is_empty():
		result.append({"event": "CONTINUE_SYSTEM", "text": "继续", "enabled": true})
	return result


func allowed(event: String) -> bool:
	if not blocked.is_empty() or int(state.player_penalties) >= 3:
		return node_id in ["P04", "E02"] and event == "CONTINUE_SYSTEM"
	var wallet: int = int(state.gold) if node_id.begins_with("T") else funds()
	match event:
		"TAKE_WINE": return not state.intro_taken
		"DRINK_INTRO": return state.intro_taken and not state.intro_drunk
		"DECLARE_AMOUNT": return amount >= 0 and amount <= wallet
		"SELECT_HONEST": return wallet >= int(state.promised_p) and state.mode == "TRIO"
		"SELECT_HIDE": return int(state.promised_p) > 0 and state.mode == "TRIO"
		"SELECT_SOLO", "CONFIRM_SOLO": return node_id.begins_with("T") and wallet >= 100
		"CONFIRM_TRIO": return state.npc_selected
		"CONFIRM_STAKE": return wallet >= int(state.draft_actual_p)
		"CONFIRM_DICE":
			if selected.is_empty(): return false
			var seen: Dictionary = {}
			for index: int in selected:
				if index < 0 or index >= dice_p.size() or seen.has(index): return false
				seen[index] = true
			return true
		"ALL_IN", "KEEP_ONE", "KEEP_TWO": return dice_p.size() == 3
		"USE_RESCUE": return int(state.rescue_wine_count) > 0 and int(state.gold) == 0
		"BUY_CHANGE": return false
		"BUY_PEEK": return state.tool == "" and funds() >= int(balance.peek_price) and _hand_free()
		"BUY_DUMMY": return funds() >= int(balance.dummy_price) and hand_p.is_empty() and _hand_free()
		"FINISH_PREP": return not hand_p.is_empty()
		"PREPARE": return not hand_p.is_empty()
		"NO_DICE": return hand_p.is_empty()
		"CONFIRM_CLEAR": return chosen >= 0 and chosen < hand_p.size()
		"CONFIRM_SURRENDER": return bool(state.surrender_confirmed)
		_: return true


func _disabled_reason(event: String) -> String:
	if event in ["SELECT_SOLO", "CONFIRM_SOLO"] and not node_id.begins_with("T"):
		return "独狼的清桌手牌尚未裁定，本次先开放三人局。"
	if event == "BUY_CHANGE": return "改点范围尚未裁定；本次不可购买。"
	if event == "CONFIRM_SURRENDER": return "认负将支付下一器官；还需要单独确认。"
	if event == "BUY_PEEK" and state.tool != "": return "已持有一件道具。"
	if event in ["BUY_PEEK", "BUY_DUMMY"]:
		var cost: int = int(balance.peek_price) if event == "BUY_PEEK" else int(balance.dummy_price)
		if funds() < cost: return "还差 %d 筹码。" % (cost - funds())
	if not _hand_free() and event in ["BUY_PEEK", "BUY_DUMMY", "CONFIRM_CLEAR"]:
		return "先将手中骰子放回托盘。"
	if event == "CONFIRM_TRIO" and not state.npc_selected: return "请先查看并选择同伴。"
	if not allowed(event): return "当前筹码、手牌或持有道具不满足条件。"
	return ""


func _runtime_hint(event: String, fallback: String) -> String:
	var unit: String = "金币" if node_id.begins_with("T") else "筹码"
	match event:
		"SELECT_HONEST": return "承诺 %d，实际投入 %d %s。" % [int(state.promised_p), int(state.promised_p), unit]
		"SELECT_HIDE": return "承诺 %d，实际投入 %d %s；总额可能不足。" % [int(state.promised_p), maxi(0, int(state.promised_p) - 20), unit]
		"SELECT_SOLO": return "独自投入 100 金币，不再由同伴出资。"
		"CONFIRM_TRIO": return "底注 %d；你的可用筹码 %d。" % [int(balance.formal_stake), funds()]
		"DECLARE_AMOUNT": return "只记下承诺，不在此处扣款。"
		"CONFIRM_STAKE": return "本次实际投入 %d %s，提交后无法撤回。" % [int(state.draft_actual_p), unit]
		"ALL_IN": return "投入全部三枚，共 %d 点；不保留骰子。" % _total(dice_p)
		"KEEP_ONE": return "默认投入 %d 点，留 1 枚；确认前可逐枚调整。" % (dice_p[0] + dice_p[1])
		"KEEP_TWO": return "只投最小的 %d 点，保留另两枚。" % dice_p.min()
		"CONFIRM_DICE": return "投入 %d 点。确认后才揭晓对方的真实贡献。" % _sum_selected(dice_p, selected)
		"BUY_PEEK": return "%d 筹码；查看对手本轮已锁定的暗骰，一次使用。" % int(balance.peek_price)
		"BUY_DUMMY": return "%d 筹码；获得一枚 1 点哑骰。" % int(balance.dummy_price)
		"FINISH_PREP": return "检查托盘，开始出骰。"
		"SELECT_DIE", "CONFIRM_CLEAR": return "当前选中 %d 点骰，亮牌前会再次确认。" % hand_p[chosen]
		_: return fallback.replace("按图", "")


func send(event: String, expected_node: String, expected_revision: int) -> bool:
	if expected_node != node_id or expected_revision != revision or not allowed(event):
		return false
	feedback = ""
	if event == "CONTINUE_SYSTEM":
		return _system_step()
	var known_event: bool = false
	for edge: Dictionary in node().get("transitions", []):
		if edge["event"] == event: known_event = true
	if not known_event: return false
	if node_id == "T06" and event == "CONTINUE": return _system_step()
	if node_id in ["P02", "P03"] and event == "CONTINUE": return _follow(event, 1 if state.failure_origin == "POOL" else 0)
	if node_id == "F15" and event == "CONTINUE": state.failure_origin = "STAKE"
	match event:
		"TAKE_WINE": state.intro_taken = true
		"DRINK_INTRO": state.intro_drunk = true
		"PUT_DOWN", "WAIT": return true
		"DECLARE_AMOUNT": state.promised_p = amount
		"SELECT_NPC":
			state.npc_selected = true
			state.npc_id = npc_roster[candidate].id
			state.npc_name = npc_roster[candidate].name
			state.npc_kind = npc_roster[candidate].kind
		"CONFIRM_TRIO": _new_table()
		"SELECT_HONEST":
			state.draft_mode = "TRIO"
			state.draft_actual_p = int(state.promised_p)
			state.strategy = "HONEST"
		"SELECT_HIDE":
			state.draft_mode = "TRIO"
			state.draft_actual_p = maxi(0, int(state.promised_p) - 20)
			state.strategy = "HIDE"
		"SELECT_SOLO":
			state.draft_mode = "SOLO"
			state.draft_actual_p = 100
		"CONFIRM_STAKE": _commit_stake()
		"ALL_IN": selected.assign([0, 1, 2])
		"KEEP_ONE": selected.assign([0, 1])
		"KEEP_TWO": selected.assign([_smallest(dice_p)])
		"CONFIRM_DICE": _commit_pool()
		"USE_RESCUE":
			state.rescue_wine_count -= 1
			state.gold += int(balance.rescue_gold_amount)
		"PLAY_MORE", "DRINK_DESCENT": state.descent_reason = "VOLUNTARY"
		"BUY_PEEK":
			_pay(int(balance.peek_price))
			state.tool = "窥牌眼"
		"BUY_DUMMY":
			_pay(int(balance.dummy_price))
			hand_p.append(1)
		"CONFIRM_SURRENDER":
			state.surrender_confirmed = false
			state.failure_origin = "CLEAR"
			state.failed_rounds += 1
		"SELECT_DIE":
			if chosen < 0 or chosen >= hand_p.size(): return false
		"CONFIRM_CLEAR":
			state.face_p = hand_p[chosen]
			state.face_n = hand_n[int(state.opponent_index)]
		_: pass
	return _follow(event)


func _follow(event: String, branch: int = 0) -> bool:
	for edge: Dictionary in node().get("transitions", []):
		if edge["event"] != event: continue
		if branch > 0:
			branch -= 1
			continue
		if edge["status"] == "proposal":
			blocked = "本局代价已结清。此处下一桌的衔接尚未裁定，本次试玩暂止于此。"
			revision += 1
			return true
		if edge["target"] == "N03" and state.failure_origin in ["STAKE", "CLEAR"]:
			state.npc_selected = false
		_enter(edge["target"])
		return true
	return false


func _enter(target: String) -> void:
	node_id = target
	revision += 1
	match target:
		"T00":
			if not state.initialized:
				state.initialized = true
				state.gold = 100
				state.rescue_wine_count = 1
		"T01":
			state.promised_n = 50
			state.npc_actual_locked = 50
			amount = mini(50, int(state.gold))
		"T09", "F20": _roll_pool()
		"I01":
			if not state.underground:
				state.underground = true
				state.private_chips = int(state.gold) * int(balance.gold_to_chip_ratio)
				state.player_chips = int(balance.formal_initial_chips)
				state.npc_chips = int(balance.formal_initial_chips)
		"F10":
			state.promised_n = mini(60, int(state.npc_chips) + int(state.npc_private))
			_npc_keeps = state.npc_kind == "CALCULATING" and rng.randf() < 0.35
			state.npc_actual_locked = maxi(0, int(state.promised_n) - (20 if _npc_keeps else 0))
			amount = mini(60, funds())
		"C00":
			if hand_n.is_empty() and int(state.npc_chips) + int(state.npc_private) >= int(balance.dummy_price):
				_npc_pay(int(balance.dummy_price))
				hand_n.append(1)
		"C03":
			if hand_n.is_empty():
				_enter("C07")
				return
			if not state.opponent_locked:
				state.opponent_index = rng.randi_range(0, hand_n.size() - 1)
				state.peek_used = false
				state.opponent_locked = true
			chosen = clampi(chosen, 0, hand_p.size() - 1)
		"C07":
			if state.strategy == "HIDE" and _npc_keeps:
				blocked = "清桌已分胜负，但双方都曾暗藏筹码，奖池归属尚无裁定。本次试玩暂止于此。"
			else:
				award("CLEAR")
				_settle_pot(true)
		"Q01": blocked = "酒保拦住了你。这笔酒账与离席的条件尚无裁定，本次试玩暂止于此。"
		"Q02": blocked = "最后两枚骰子同时碎裂。这场平局尚无裁定，本次试玩暂止于此。"
		"E01": state.player_penalties = 0
		_: pass


func _new_table() -> void:
	if _table > 0:
		state.player_chips += maxi(0, int(balance.new_table_minimum) - funds())
		state.npc_chips += maxi(0, int(balance.new_table_minimum) - int(state.npc_chips) - int(state.npc_private))
	_table += 1
	state.mode = "TRIO"
	state.public_pot = 0
	state.tool = ""
	state.strategy = "HONEST"
	state.opponent_locked = false
	hand_p.clear()
	hand_n.clear()


func _commit_stake() -> void:
	_round += 1
	state.mode = state.draft_mode
	state.actual_p = int(state.draft_actual_p)
	state.actual_n = 0 if state.mode == "SOLO" else int(state.npc_actual_locked)
	_stake_paid = int(state.actual_p)
	if node_id == "T03": state.gold -= _stake_paid
	else:
		_pay(_stake_paid)
		_npc_pay(int(state.actual_n))


func _roll_pool() -> void:
	dice_p = _roll_three()
	dice_n.assign(_roll_three() if state.mode == "TRIO" else [])
	dice_dealer = _roll_three()
	selected.assign([0, 1])
	state.npc_dice_locked = [0, 1] if state.npc_kind == "OATH" else [_smallest(dice_n)]
	state.open_p = state.next_open_p
	state.open_n = state.next_open_n
	state.next_open_p = false
	state.next_open_n = false
	state.pool_contrib_p = 0
	state.pool_contrib_n = 0
	if node_id == "F20": held_dice = true


func _roll_three() -> Array[int]:
	var result: Array[int] = []
	for _i: int in range(3): result.append(rng.randi_range(1, 6))
	return result


func _smallest(values: Array[int]) -> int:
	if values.is_empty(): return 0
	return values.find(values.min())


func toggle_die(index: int) -> void:
	if not node_id in ["T11", "F23"] or index < 0 or index >= dice_p.size(): return
	if selected.has(index): selected.erase(index)
	else: selected.append(index)


func _commit_pool() -> void:
	state.pool_contrib_p = _sum_selected(dice_p, selected)
	state.pool_contrib_n = _sum_selected(dice_n, state.npc_dice_locked)
	hand_p.clear()
	hand_n.clear()
	for index: int in range(dice_p.size()):
		if not selected.has(index): hand_p.append(dice_p[index])
	for index: int in range(dice_n.size()):
		if not state.npc_dice_locked.has(index): hand_n.append(dice_n[index])


func _sum_selected(values: Array[int], indices: Array) -> int:
	var total: int = 0
	for index: int in indices:
		if index >= 0 and index < values.size(): total += values[index]
	return total


func _system_step() -> bool:
	match node_id:
		"T04": return _follow("REVEAL_DONE", 0 if stake_total() >= 100 else 1)
		"T06": return _follow("CONTINUE", 0 if int(state.gold) == 0 and int(state.rescue_wine_count) > 0 else 1)
		"T12":
			if pool_total() >= _total(dice_dealer):
				state.gold += _stake_paid
				feedback = "教学本金已返还；奖金数值尚未裁定，本次不虚构额外奖励。"
				return _follow("REVEAL_DONE", 0)
			state.gold = 0
			state.descent_reason = "TUTORIAL_LOSS"
			return _follow("REVEAL_DONE", 1)
		"F13":
			if stake_total() >= int(balance.formal_stake):
				state.public_pot = stake_total() * 2
				award("STAKE")
				return _follow("REVEAL_DONE", 0)
			state.failed_rounds += 1
			return _follow("REVEAL_DONE", 1)
		"F24":
			if pool_total() >= _total(dice_dealer):
				var id: String = "pool:%d:%d" % [_table, _round]
				if not settled.has(id):
					settled[id] = true
					state.private_chips += _total(hand_p)
					state.npc_private += _total(hand_n)
				award("POOL")
				return _follow("REVEAL_DONE", 0)
			state.failed_rounds += 1
			state.failure_origin = "POOL"
			hand_p.clear()
			hand_n.clear()
			return _follow("REVEAL_DONE", 1)
		"P00":
			var p: int = int(state.actual_p) if state.failure_origin == "STAKE" else int(state.pool_contrib_p)
			var n: int = int(state.actual_n) if state.failure_origin == "STAKE" else int(state.pool_contrib_n)
			state.responsible_party = responsibility(p, n, state.mode == "SOLO" or state.failure_origin == "CLEAR")
			return _follow("ASSIGN_RESPONSIBILITY")
		"P01":
			apply_penalty("penalty:%d:%d" % [_table, _round])
			return _follow("APPLY_PENALTY", 0 if state.responsible_party == "NPC" else (2 if int(state.player_penalties) == 3 else 1))
		"P04": return _follow("CINEMATIC_DONE")
		"I00": return _follow("TRANSITION_DONE")
		"F20": return _follow("ROLL_DONE")
		"C00": return _follow("PREPARE" if not hand_p.is_empty() else "NO_DICE")
		"C05":
			var p_face: int = int(state.face_p)
			var n_face: int = int(state.face_n)
			if p_face <= n_face: hand_p.remove_at(chosen)
			if p_face >= n_face: hand_n.remove_at(int(state.opponent_index))
			if p_face > n_face:
				var gain: int = mini(20, int(state.npc_chips) + int(state.npc_private))
				_npc_pay(gain)
				state.private_chips += gain
			elif p_face < n_face:
				var loss: int = mini(20, funds())
				_pay(loss)
				state.npc_private += loss
			return _follow("REVEAL_DONE", 0 if p_face > n_face else (1 if p_face < n_face else 2))
		"C06":
			var branch: int = 0
			if hand_p.is_empty(): branch = 3 if hand_n.is_empty() else 2
			elif hand_n.is_empty(): branch = 1
			if branch == 2:
				state.failure_origin = "CLEAR"
				state.failed_rounds += 1
				_settle_pot(false)
			if branch == 0: state.opponent_locked = false
			return _follow("ROUND_DONE", branch)
		"C07": return _follow("CHECK_KEYS", 0 if state["keys"].has_all(["STAKE", "POOL", "CLEAR"]) else 1)
		_: return false


static func responsibility(p: int, n: int, alone: bool = false) -> String:
	if alone: return "PLAYER"
	return "PLAYER" if p < n else ("NPC" if p > n else "BOTH")


func apply_penalty(action_id: String) -> void:
	if settled.has(action_id) or int(state.player_penalties) >= 3: return
	settled[action_id] = true
	if state.responsible_party in ["PLAYER", "BOTH"]:
		state.paid_organ = ["EYE", "HAND", "HEART"][int(state.player_penalties)]
		state.player_penalties += 1
		if state.failure_origin == "STAKE": state.next_open_p = true
	if state.responsible_party in ["NPC", "BOTH"]:
		state.npc_private = 0
		if state.failure_origin == "STAKE": state.next_open_n = true


func award(kind: String) -> void:
	if kind in ["STAKE", "POOL", "CLEAR"]: state["keys"][kind] = true


func _settle_pot(player_won: bool) -> void:
	var id: String = "pot:%d" % _table
	if settled.has(id): return
	settled[id] = true
	var pot: int = int(state.public_pot)
	if not player_won: state.npc_private += pot
	elif state.strategy == "HIDE": state.private_chips += pot
	elif _npc_keeps: state.npc_private += pot
	else:
		var share: int = int(float(pot) * float(state.actual_p) / float(maxi(1, stake_total())))
		state.private_chips += share
		state.npc_private += pot - share
	state.public_pot = 0


func funds() -> int:
	return int(state.player_chips) + int(state.private_chips)


func _pay(value: int) -> void:
	var private_part: int = mini(value, int(state.private_chips))
	state.private_chips -= private_part
	state.player_chips -= value - private_part


func _npc_pay(value: int) -> void:
	var private_part: int = mini(value, int(state.npc_private))
	state.npc_private -= private_part
	state.npc_chips -= value - private_part


func _hand_free() -> bool:
	return int(state.player_penalties) < 2 or not held_dice


func use_peek() -> bool:
	if not _hand_free():
		feedback = "先将手中的骰子放回托盘。"
		return false
	if node_id != "C03" or state.tool != "窥牌眼": return false
	state.peek_used = true
	state.tool = ""
	feedback = "对方已锁定的暗骰：%d 点。" % hand_n[int(state.opponent_index)]
	return true


func stake_total() -> int:
	return int(state.actual_p) + int(state.actual_n)


func pool_total() -> int:
	return int(state.pool_contrib_p) + int(state.pool_contrib_n)


func _total(values: Array[int]) -> int:
	var total: int = 0
	for value: int in values: total += value
	return total


func variables() -> Dictionary:
	var values: Dictionary = state.duplicate()
	values.merge(balance, true)
	values["tutorial_stake"] = 100
	values["player_chips"] = funds()
	values["promised_p"] = state.promised_p
	values["dice_p_text"] = str(dice_p)
	values["dealer_total"] = _total(dice_dealer)
	values["selected_total"] = _sum_selected(dice_p, selected)
	var reserves: Array[int] = []
	for i: int in range(dice_p.size()):
		if not selected.has(i): reserves.append(dice_p[i])
	values["reserve_text"] = "无" if reserves.is_empty() else str(reserves)
	values["reserve_total"] = _total(hand_p)
	values["pool_total"] = pool_total()
	values["stake_total"] = stake_total()
	values["stake_shortfall"] = maxi(0, int(balance.formal_stake) - stake_total())
	values["draft_balance"] = (int(state.gold) if node_id.begins_with("T") else funds()) - int(state.draft_actual_p)
	values["npc_public_trait"] = npc_roster[candidate].trait
	values["candidate_name"] = npc_roster[candidate].name
	values["paid_organ"] = {"EYE": "眼", "HAND": "手", "HEART": "心"}.get(state.paid_organ, "无")
	values["responsible_party_text"] = {"PLAYER": "你", "NPC": "同伴", "BOTH": "双方"}[state.responsible_party]
	values["chosen_face"] = hand_p[chosen] if chosen >= 0 and chosen < hand_p.size() else 0
	values["tool_summary"] = "窥牌眼" if state.peek_used else "无"
	values["hand_count_p"] = hand_p.size()
	values["hand_count_n"] = hand_n.size()
	return values
