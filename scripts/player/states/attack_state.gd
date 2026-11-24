extends PlayerState
## A melee swing: windup -> active (the hitbox is live) -> recovery.
## Light attacks chain into a three-hit combo; heavy attacks can be held to charge.

enum Phase { WINDUP, CHARGE, ACTIVE, RECOVERY }

const LUNGE_SPEED: float = 3.2

var phase: Phase = Phase.WINDUP
var is_heavy: bool = false
var combo_index: int = 0
var charge: float = 0.0

var _weapon: WeaponData
var _time: float = 0.0
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0


func enter(_previous: StringName, message: Dictionary) -> void:
	_weapon = player.weapon
	is_heavy = message.get("heavy", false)
	combo_index = int(message.get("combo", 0)) % maxi(_weapon.light_clips.size(), 1)
	_time = 0.0
	charge = 0.0
	phase = Phase.WINDUP
	player.is_sprinting = false
	player.snap_facing(player.get_attack_direction())
	var visuals: PlayerVisuals = player.visuals
	if is_heavy:
		_windup = _weapon.heavy_windup
		_active = _weapon.heavy_active
		_recovery = _weapon.heavy_recovery
		player.spend_stamina(_weapon.heavy_stamina * Upgrades.stamina_multiplier(_weapon.id))
		visuals.play_action(_weapon.heavy_clip)
		var impact: float = visuals.get_clip_length(_weapon.heavy_clip) * visuals.animation_set.heavy_impact_fraction
		visuals.set_action_speed(impact / _windup)
	else:
		_windup = _weapon.light_windup
		_active = _weapon.light_active
		_recovery = _weapon.light_recovery
		player.spend_stamina(_weapon.light_stamina * Upgrades.stamina_multiplier(_weapon.id))
		var clip := StringName(_weapon.light_clips[combo_index])
		visuals.play_action(clip)
		var impact: float = visuals.get_clip_length(clip) * visuals.animation_set.light_impact_fraction
		visuals.set_action_speed(impact / (_windup + _active * 0.5))


func exit(_next: StringName) -> void:
	player.hitbox.end()


func physics_update(delta: float) -> void:
	_time += delta
	match phase:
		Phase.WINDUP:
			_step_forward(delta, LUNGE_SPEED if not is_heavy else LUNGE_SPEED * 0.4)
			if _time >= _windup:
				if is_heavy and player.is_action_held(&"heavy_attack") and player.combat.heavy_charge_time > 0.0:
					phase = Phase.CHARGE
					player.visuals.set_action_speed(0.0)
				else:
					_begin_active()
		Phase.CHARGE:
			_step_forward(delta, 0.0)
			charge = minf(charge + delta, player.combat.heavy_charge_time)
			player.face_direction(player.get_attack_direction(), 5.0, delta)
			if not player.is_action_held(&"heavy_attack") or charge >= player.combat.heavy_charge_time:
				_begin_active()
		Phase.ACTIVE:
			_step_forward(delta, LUNGE_SPEED * 0.5)
			if _time >= _active:
				player.hitbox.end()
				phase = Phase.RECOVERY
				_time = 0.0
		Phase.RECOVERY:
			_step_forward(delta, 0.0)
			# Recovery can be cancelled into a dodge straight away...
			if player.is_action_just_pressed(&"dodge") and player.try_dodge():
				return
			# ...and into the next swing once it is nearly over.
			if _time >= _recovery * 0.5 and player.stamina > 0.0:
				if player.consume_heavy_buffer():
					machine.transition_to(&"Attack", {"heavy": true})
					return
				if not is_heavy and combo_index < _weapon.light_clips.size() - 1 and player.consume_light_buffer():
					machine.transition_to(&"Attack", {"combo": combo_index + 1})
					return
			if _time >= _recovery:
				machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")


## Fraction of full charge, 0..1.
func get_charge_ratio() -> float:
	return charge / maxf(player.combat.heavy_charge_time, 0.001)


func build_hit() -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.is_heavy = is_heavy
	hit.armor_multiplier = _weapon.armor_multiplier + Upgrades.special(_weapon.id, "armor_bonus")
	hit.echo_multiplier = _weapon.echo_multiplier
	if is_heavy:
		hit.damage = (_weapon.heavy_damage * Upgrades.damage_multiplier(_weapon.id)
				* (1.0 + (player.combat.heavy_charge_bonus + Upgrades.special(_weapon.id, "charge_bonus")) * get_charge_ratio()))
		hit.poise = _weapon.heavy_poise
		hit.breaks_guard = true
	else:
		var finisher: bool = combo_index == _weapon.light_clips.size() - 1
		hit.damage = (_weapon.light_damage * Upgrades.damage_multiplier(_weapon.id)
				* ((_weapon.combo_finisher_multiplier + Upgrades.special(_weapon.id, "finisher_bonus")) if finisher else 1.0))
		hit.poise = _weapon.light_poise * (1.6 if finisher else 1.0)
	return hit


func _begin_active() -> void:
	phase = Phase.ACTIVE
	_time = 0.0
	if is_heavy:
		player.visuals.set_action_speed(1.5)
	player.hitbox.begin(build_hit(), _weapon.reach, _weapon.hit_radius, Player.LAYER_ENEMY)
	CombatFX.sfx(&"swing_heavy" if is_heavy else &"swing_light", player.global_position + Vector3.UP * 1.2, -3.0)
	player.emit_noise(player.tuning.noise_jog)


func _step_forward(delta: float, speed: float) -> void:
	player.accelerate_horizontal(player.get_facing_direction(), speed, 40.0, delta)
	player.ground_move(delta)
