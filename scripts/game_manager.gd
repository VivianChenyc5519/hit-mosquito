extends Node
class_name gameManager

enum MatchState {
	WAITING,
	PLAYING,
	FINISHED
}

enum Winner {
	NONE,
	HUMAN,
	MOSQUITO
}

enum EndReason {
	NONE,
	MOSQUITO_DEAD,
	HUMAN_DEAD,
	TIME_EXPIRED #mosquito wins
}

@export_category("Match")
@export var match_duration: float = 60.0;

@export_category("Human")
@export var human_max_hp: int = 4;
@export var human_stun_duration: float = 1.5;
@export var slap_cooldown: float = 4.0;

@export_category("Mosquito") 
@export var bite_cooldown: float = 8.0;
@export var mosquito_boost_duration: float = 1.5;

var match_state := MatchState.WAITING
var winner := Winner.NONE
var end_reason := EndReason.NONE

var remaining_time: float = 0.0

var human_hp: int = 0

var slap_cooldown_remaining: float = 0.0
var bite_cooldown_remaining: float = 0.0

var human_stun_remaining: float = 0.0
var mosquito_boost_remaining: float = 0.0

signal match_started(duration: float)
signal match_ended(winner: int, reason: int)

signal human_hp_changed(current_hp: int, max_hp: int)

signal human_stunned(duration: float)
signal human_recovered

signal mosquito_boost_started(duration: float)
signal mosquito_boost_ended

signal slap_resolved(hit: bool)
signal bite_resolved(hit: bool)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match_state = MatchState.PLAYING
	winner = Winner.NONE
	end_reason = EndReason.NONE

	remaining_time = match_duration

	human_hp = human_max_hp

	slap_cooldown_remaining = 0.0
	bite_cooldown_remaining = 0.0

	human_stun_remaining = 0.0
	mosquito_boost_remaining = 0.0

	match_started.emit(match_duration)
	human_hp_changed.emit(human_hp, human_max_hp)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if match_state != MatchState.PLAYING:
		return
	update_match_timer(delta)
	update_cooldowns(delta);
	update_status_effect(delta);
	
func update_match_timer(delta: float) -> void:
	remaining_time = maxf(remaining_time - delta, 0.0)
	if remaining_time <= 0:
		finish_match(Winner.MOSQUITO, EndReason.TIME_EXPIRED)
		
func update_cooldowns(delta: float) -> void:
	slap_cooldown_remaining = maxf(slap_cooldown_remaining - delta, 0.0)
	bite_cooldown_remaining = maxf(bite_cooldown_remaining - delta, 0.0)
	
func update_status_effect(delta: float) -> void:
	var human_was_stunned:= human_stun_remaining > 0.0
	var mosquito_was_boosted:=mosquito_boost_remaining > 0.0
	
	human_stun_remaining = maxf(human_stun_duration - delta, 0.0)
	mosquito_boost_remaining = maxf(mosquito_boost_remaining - delta, 0.0)
	
	if human_was_stunned and human_stun_remaining <= 0.0:
		human_recovered.emit()
	if mosquito_was_boosted and mosquito_boost_remaining <= 0.0:
		mosquito_boost_ended.emit()
		
func attempt_slap(hit_confirmed: bool) -> bool:
	if match_state != MatchState.PLAYING:
		return false
	if human_stun_remaining > 0.0:
		return false
	if slap_cooldown_remaining > 0.0:
		return false
	slap_cooldown_remaining = slap_cooldown
	slap_resolved.emit(hit_confirmed)
	if hit_confirmed:
		finish_match(
			Winner.HUMAN,
			EndReason.MOSQUITO_DEAD
		)
		
func attempt_bite(hit_confirmed: bool) -> bool:
	if match_state != MatchState.PLAYING:
		return false
	if bite_cooldown_remaining > 0.0:
		return false
	bite_resolved.emit(hit_confirmed)
	if not hit_confirmed:
		return true
	human_hp -= 1
	human_hp_changed.emit(
		human_hp,
		human_max_hp
	)
	if human_hp <= 0:
		finish_match(
			Winner.MOSQUITO,
			EndReason.HUMAN_HP_DEPLETED
		)

		return true
	bite_cooldown_remaining = bite_cooldown
	human_stun_remaining = human_stun_duration
	mosquito_boost_remaining = mosquito_boost_duration
	human_stunned.emit(human_stun_duration)
	mosquito_boost_started.emit(
		mosquito_boost_duration
	)
	return true
	
			
		
