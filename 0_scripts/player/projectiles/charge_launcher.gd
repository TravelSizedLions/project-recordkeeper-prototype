extends Node2D
class_name ChargeLauncher

@onready var special_charger: Charger = Charger.new()
@onready var main_charger: Charger = Charger.new()

@onready var player: Player = Player.retrieve()
@onready var arcdrawer: ArcDrawer = N.get_child(self, ArcDrawer)

@export_group('Launcher Settings')
## The hardest the player can throw the thing
@export var max_lob_force: float = 500

## The max amount of time it takes to charge a shot, in seconds
@export var charge_time_seconds: float = 2

## The amount to start charging from
@export_range(0, 1) var start_charge_percentage: float = 0

## How far away the projectile starts from the player
@export var buffer_radius: float = 25

## The maximum number of launchables this launcher can carry
@export var max_special_ammo: int = 5

## The type of projectile to use for normal ammo
@export var main_projectile: PackedScene

## The type of projectile to use for special ammo
@export var special_projectile: PackedScene

@export_group('Burst Fire Settings')
@export var number_of_projectiles: int = 3
@export var time_between_projectiles: float = 0.1

var __burst_fire_timer: float = -1
var __burst_fire_left: int = 0


var __enabled: bool = true
var __remaining_special_ammo: int
var __last_known_direction: Vector2

signal on_update_capacity

func _ready():
	__connect_to_ui()
	__reset_to_max()
	main_charger.set_max_charge_time(charge_time_seconds)
	special_charger.set_max_charge_time(charge_time_seconds)
	player.on_player_died.connect(__reset_to_max)

func _physics_process(physicsDelta):
	if not __enabled:
		return

	handle_main(physicsDelta)
	if not main_charger.is_charging():
		handle_special(physicsDelta)

func handle_main(physicsDelta):
	if player.pressed_fire():
		if start_charge_percentage > 0:
			main_charger.set_charge_percent(start_charge_percentage)
		else:
			main_charger.start_charge(physicsDelta)
	elif main_charger.is_charging() && player.released_fire():
		fire(main_charger, main_projectile)
		if should_burst_fire():
			start_burst_fire()
		else:
			main_charger.reset_charge()
	
	if __burst_fire_left == 0:
		main_charger.handle_charge(physicsDelta)
		update_aim(main_charger)

	handle_burst_fire(physicsDelta)

func should_burst_fire():
	var actual_percent = main_charger.percent_charged() - start_charge_percentage
	return actual_percent*charge_time_seconds > time_between_projectiles*number_of_projectiles

func start_burst_fire():
	__burst_fire_left = number_of_projectiles - 1
	__burst_fire_timer = time_between_projectiles

func handle_burst_fire(physicsDelta):
	if __burst_fire_left == 0:
		return
	
	__burst_fire_timer -= physicsDelta
	if __burst_fire_timer < 0:
		__burst_fire_timer = time_between_projectiles
		__burst_fire_left -= 1
		fire(main_charger, main_projectile)
		if __burst_fire_left == 0:
			main_charger.reset_charge()


func handle_special(physicsDelta):
	if __remaining_special_ammo > 0 && player.pressed_special():
		if start_charge_percentage > 0:
			special_charger.set_charge_percent(start_charge_percentage)
		else:
			special_charger.start_charge(physicsDelta)
	elif special_charger.is_charging() && player.released_special():
		fire(special_charger, special_projectile)
		__remaining_special_ammo -= 1
		on_update_capacity.emit(__remaining_special_ammo, max_special_ammo)
		special_charger.reset_charge()

	special_charger.handle_charge(physicsDelta)
	update_aim(special_charger)

func update_aim(charger: Charger):
	if charger.is_charging():
		if player.is_aiming():
			__last_known_direction = player.get_firing_direction()

		arcdrawer.predict_arc(
			global_position + __last_known_direction*buffer_radius, 
			__last_known_direction*max_lob_force*charger.percent_charged()
		)

func fire(charger: Charger, projectile: PackedScene):
	var p = N.create_scene(projectile)
	var force = max_lob_force*charger.percent_charged()
	p.set_initial_position(global_position + __last_known_direction*buffer_radius)
	p.set_initial_velocity(__last_known_direction, force)
	arcdrawer.clear_arc()

func __connect_to_ui():
	var ammo_tracker: AmmoTracker = N.find(AmmoTracker)
	if ammo_tracker:
		ammo_tracker.connect_to_entity(self)

func __reset_to_max():
	__remaining_special_ammo = max_special_ammo
	on_update_capacity.emit(__remaining_special_ammo, max_special_ammo)

func enable():
	__enabled = true

func disable():
	__enabled = false
