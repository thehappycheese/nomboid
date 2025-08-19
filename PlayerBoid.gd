extends Node2D

var facing_direction: Vector2 = Vector2.RIGHT
var momentum_speed: Vector2 = Vector2.ZERO
var base_forward_speed: float = 5.0  # Small constant forward movement
var turn_speed: float = 3.0
var screen_size: Vector2

# Physics parameters
var acceleration: float = 80.0  # How fast we accelerate in facing direction
var base_drag: float = 0.8  # Base drag coefficient (higher = more drag)
var cross_drag_multiplier: float = 0.3  # Additional drag when momentum doesn't match facing
var impulse_strength: float = 10.0  # Spacebar impulse power

# Stamina system
var max_stamina: float = 50.0
var current_stamina: float = 50.0
var stamina_regen_rate: float = 2.0  # Per second
var impulse_stamina_cost: float = 60.0

# Progression
var boids_eaten: int = 0
var speed_increase_per_eat: float = 0.5
var fear_level: float = 0.0

# Visual properties
var boid_size: float = 8.0
var boid_color: Color = Color.CYAN
var collision_radius: float = 8.0

func _ready():
	facing_direction = Vector2.RIGHT

func _draw():
	# Draw player boid as a larger triangle
	var direction = facing_direction
	var perpendicular = direction.rotated(PI/2)
	
	# Triangle vertices (larger than regular boids)
	var tip = direction * boid_size
	var left_wing = -direction * boid_size * 0.6 + perpendicular * boid_size * 0.6
	var right_wing = -direction * boid_size * 0.6 - perpendicular * boid_size * 0.6
	
	var points = PackedVector2Array([tip, left_wing, right_wing])
	draw_colored_polygon(points, boid_color)
	
	# Draw a small outline to make it stand out more
	draw_polyline(PackedVector2Array([tip, left_wing, right_wing, tip]), Color.WHITE, 2.0)
	
	# Draw momentum vector for debugging (optional)
	if momentum_speed.length() > 5.0:
		draw_line(Vector2.ZERO, momentum_speed.normalized() * boid_size * 1.5, Color.GREEN, 1.0)
	
	# Draw stamina bar above the player
	var bar_width = 30.0
	var bar_height = 4.0
	var bar_pos = Vector2(-bar_width/2, -boid_size - 10)
	
	# Background bar
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.BLACK)
	# Stamina bar
	var stamina_percent = current_stamina / max_stamina
	draw_rect(Rect2(bar_pos, Vector2(bar_width * stamina_percent, bar_height)), Color.YELLOW)

func _process(delta):
	handle_input(delta)
	update_physics(delta)
	update_stamina(delta)
	
	# Calculate total velocity (base forward + momentum)
	var total_velocity = facing_direction * base_forward_speed + momentum_speed
	
	# Update position
	position += total_velocity * delta
	
	# Wrap around screen edges
	wrap_around()
	
	# Trigger redraw
	queue_redraw()

func handle_input(delta):
	var turn_amount = 0.0
	
	# Handle turning
	if Input.is_action_pressed("ui_left"):
		turn_amount = -turn_speed * delta
	elif Input.is_action_pressed("ui_right"):
		turn_amount = turn_speed * delta
	#elif Input.is_action_pressed("ui_up"):
		#turn_amount = -turn_speed * delta
	#elif Input.is_action_pressed("ui_down"):
		#turn_amount = turn_speed * delta
	
	# Apply rotation to facing direction
	if turn_amount != 0:
		facing_direction = facing_direction.rotated(turn_amount)
	
	# Handle spacebar impulse
	if Input.is_action_just_pressed("ui_up"):
		if current_stamina >= impulse_stamina_cost:
			current_stamina -= impulse_stamina_cost
			# Apply impulse in facing direction
			momentum_speed += facing_direction * impulse_strength
		else:
			momentum_speed += facing_direction * impulse_strength * current_stamina/impulse_stamina_cost*0.9
			current_stamina = 0
			

func update_physics(delta):
	# Apply acceleration in facing direction
	momentum_speed += facing_direction * acceleration * delta
	
	# Calculate drag
	var drag_force = calculate_drag()
	
	# Apply drag to momentum
	momentum_speed -= momentum_speed * drag_force * delta

func calculate_drag() -> float:
	var total_drag = base_drag
	
	# Add cross-product drag (when momentum direction differs from facing direction)
	if momentum_speed.length() > 0.1:
		var momentum_direction = momentum_speed.normalized()
		# Calculate how much momentum is perpendicular to facing direction
		var cross_component = abs(facing_direction.cross(momentum_direction))
		total_drag += cross_component * cross_drag_multiplier
	
	return total_drag

func update_stamina(delta):
	# Natural stamina regeneration
	var bonus_rate = 1.0
	if current_stamina<max_stamina*0.3:
		bonus_rate = 1.5
	elif current_stamina <max_stamina*0.5:
		bonus_rate = 1.2
	current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta*bonus_rate)

func eat_boid():
	boids_eaten += 1
	
	# Increase base speed slightly
	base_forward_speed += speed_increase_per_eat
	
	# Restore significant stamina
	current_stamina = min(max_stamina, current_stamina + 10.0)
	turn_speed+=0.1
	impulse_strength+=10
	stamina_regen_rate+=2
	
	# Increase fear level
	fear_level += 5.0
	boid_size += 0.5
	collision_radius += 0.5
	
	# Visual feedback - briefly change color
	boid_color = Color.RED
	await get_tree().create_timer(0.1).timeout
	boid_color = Color.CYAN

func get_fear_level() -> float:
	return fear_level

func wrap_around():
	if position.x < 0:
		position.x = screen_size.x
	elif position.x > screen_size.x:
		position.x = 0
		
	if position.y < 0:
		position.y = screen_size.y
	elif position.y > screen_size.y:
		position.y = 0
