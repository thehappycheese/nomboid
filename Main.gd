extends Node2D

@export var boid_count: int = 100
@export var max_speed: float = 100.0
@export var max_force: float = 50.0
@export var separation_radius: float = 25.0
@export var alignment_radius: float = 50.0
@export var cohesion_radius: float = 50.0
@export var separation_weight: float = 2.0
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0

var boids: Array[Node2D] = []
var boids_container: Node2D
var screen_size: Vector2

const BOID_SCENE = preload("res://Boid.gd")
const PLAYER_BOID_SCENE = preload("res://PlayerBoid.gd")

var player_boid: Node2D

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	boids_container = $BoidsContainer
	
	# Create player boid first
	create_player_boid()
	
	# Create regular boids
	for i in range(boid_count):
		create_boid()

func create_boid():
	var boid = Node2D.new()
	boid.set_script(BOID_SCENE)
	
	# Random starting position
	boid.position = Vector2(
		randf() * screen_size.x,
		randf() * screen_size.y
	)
	
	# Random starting velocity
	var angle = randf() * TAU
	boid.velocity = Vector2(cos(angle), sin(angle)) * randf_range(50, max_speed)
	
	# Set simulation parameters
	boid.max_speed = max_speed
	boid.max_force = max_force
	boid.separation_radius = separation_radius
	boid.alignment_radius = alignment_radius
	boid.cohesion_radius = cohesion_radius
	boid.separation_weight = separation_weight
	boid.alignment_weight = alignment_weight
	boid.cohesion_weight = cohesion_weight
	boid.screen_size = screen_size
	boid.simulation = self
	
	boids_container.add_child(boid)
	boids.append(boid)

func create_player_boid():
	player_boid = Node2D.new()
	player_boid.set_script(PLAYER_BOID_SCENE)
	
	# Start player boid in center of screen
	player_boid.position = screen_size * 0.5
	player_boid.screen_size = screen_size
	
	boids_container.add_child(player_boid)

func get_nearby_boids(boid: Node2D, radius: float) -> Array[Node2D]:
	var nearby: Array[Node2D] = []
	
	for other_boid in boids:
		if other_boid == boid:
			continue
			
		var distance = boid.position.distance_to(other_boid.position)
		if distance < radius:
			nearby.append(other_boid)
	
	return nearby

func _process(_delta):
	# Check for collisions between player and boids
	check_eating_collisions()
	
	# Update boids
	for boid in boids:
		boid.update_boid(boids)

func check_eating_collisions():
	if not player_boid:
		return
		
	# Check each boid for collision with player
	var boids_to_remove = []
	
	for i in range(boids.size() - 1, -1, -1):  # Iterate backwards for safe removal
		var boid = boids[i]
		var distance = player_boid.position.distance_to(boid.position)
		
		if distance < player_boid.collision_radius:
			# Boid gets eaten!
			player_boid.eat_boid()
			
			# Remove the boid
			boid.queue_free()
			boids.remove_at(i)
			
			# Optionally create a new boid to maintain population
			create_boid()
