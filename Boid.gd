extends Node2D

var velocity: Vector2 = Vector2.ZERO
var acceleration: Vector2 = Vector2.ZERO

# Simulation parameters (set by main scene)
var max_speed: float = 100.0
var max_force: float = 50.0
var separation_radius: float = 25.0
var alignment_radius: float = 50.0
var cohesion_radius: float = 50.0
var separation_weight: float = 2.0
var alignment_weight: float = 1.0
var cohesion_weight: float = 1.0
var screen_size: Vector2
var simulation: Node2D

# Visual properties
var boid_size: float = 6.0
var boid_color: Color = Color.WHITE

func _ready():
	# Random color for each boid
	boid_color = Color(randf(), randf(), randf(), 1.0)

func _draw():
	# Draw boid as a triangle pointing in direction of movement
	var direction = velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	
	var perpendicular = direction.rotated(PI/2)
	
	# Triangle vertices
	var tip = direction * boid_size
	var left_wing = -direction * boid_size * 0.5 + perpendicular * boid_size * 0.5
	var right_wing = -direction * boid_size * 0.5 - perpendicular * boid_size * 0.5
	
	var points = PackedVector2Array([tip, left_wing, right_wing])
	draw_colored_polygon(points, boid_color)
	
	# Optional: draw direction line
	# draw_line(Vector2.ZERO, direction * boid_size * 2, Color.RED, 1.0)

func update_boid(all_boids: Array[Node2D]):
	# Calculate steering forces
	var sep = separate(all_boids) * separation_weight
	var ali = align(all_boids) * alignment_weight  
	var coh = cohesion(all_boids) * cohesion_weight
	
	# Add fear of player
	var fear = fear_player() * 3.0  # Strong weight for fear
	
	# Apply forces
	acceleration = sep + ali + coh + fear
	
	# Update physics
	velocity += acceleration * get_process_delta_time()
	velocity = velocity.limit_length(max_speed)
	position += velocity * get_process_delta_time()
	
	# Wrap around screen edges
	wrap_around()
	
	# Clear acceleration for next frame
	acceleration = Vector2.ZERO
	
	# Trigger redraw
	queue_redraw()

func fear_player() -> Vector2:
	# Get reference to player from simulation
	var player = simulation.player_boid
	if not player:
		return Vector2.ZERO
	
	var distance = position.distance_to(player.position)
	var fear_radius = 5.0 + player.get_fear_level()  # Radius grows with player's fear level
	
	if distance > 0 and distance < fear_radius:
		# Run away from player
		var flee_direction = position - player.position
		flee_direction = flee_direction.normalized()
		
		# Stronger fear when player is closer
		var fear_strength = (fear_radius - distance) / fear_radius
		fear_strength *= (1.0 + player.get_fear_level() * 0.1)  # Fear grows with player's level
		
		var desired_velocity = flee_direction * max_speed * fear_strength
		var steer = desired_velocity - velocity
		return steer.limit_length(max_force * 2.0)  # Allow stronger steering for fear
	
	return Vector2.ZERO

func separate(boids: Array[Node2D]) -> Vector2:
	var steer = Vector2.ZERO
	var count = 0
	
	for boid in boids:
		if boid == self:
			continue
			
		var distance = position.distance_to(boid.position)
		if distance > 0 and distance < separation_radius:
			var diff = position - boid.position
			diff = diff.normalized() / distance  # Weight by distance
			steer += diff
			count += 1
	
	if count > 0:
		steer /= count
		steer = steer.normalized() * max_speed
		steer -= velocity
		steer = steer.limit_length(max_force)
	
	return steer

func align(boids: Array[Node2D]) -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	
	for boid in boids:
		if boid == self:
			continue
			
		var distance = position.distance_to(boid.position)
		if distance > 0 and distance < alignment_radius:
			sum += boid.velocity
			count += 1
	
	if count > 0:
		sum /= count
		sum = sum.normalized() * max_speed
		var steer = sum - velocity
		steer = steer.limit_length(max_force)
		return steer
	
	return Vector2.ZERO

func cohesion(boids: Array[Node2D]) -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	
	for boid in boids:
		if boid == self:
			continue
			
		var distance = position.distance_to(boid.position)
		if distance > 0 and distance < cohesion_radius:
			sum += boid.position
			count += 1
	
	if count > 0:
		sum /= count
		return seek(sum)
	
	return Vector2.ZERO

func seek(target: Vector2) -> Vector2:
	var desired = target - position
	desired = desired.normalized() * max_speed
	
	var steer = desired - velocity
	steer = steer.limit_length(max_force)
	return steer

func wrap_around():
	if position.x < 0:
		position.x = screen_size.x
	elif position.x > screen_size.x:
		position.x = 0
		
	if position.y < 0:
		position.y = screen_size.y
	elif position.y > screen_size.y:
		position.y = 0
