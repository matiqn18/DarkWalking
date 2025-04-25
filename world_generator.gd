extends Node3D

# Ustawienia mapy
var map_width := 50
var map_depth := 50
var wall_height := 3.0
var wall_chance := 0.3
var elapsed_time := 0.0
var door: Node3D
var kremowka: Node3D

@onready var timer_label: Label = $TimerLabel
@onready var game_timer: Timer = $Timer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var koniec: AudioStreamPlayer = $Koniec

# Prefaby
@export var player_prefab: PackedScene
@export var door_prefab: PackedScene
@export var kremowka_prefab: PackedScene

var walls := []

func _ready():
	randomize()
	generate_floor()
	generate_map()
	generate_border_wall()
	spawn_player_and_door()
	game_timer.start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	kremowka.collected.connect(door.odblokuj)

func _process(delta):
	if game_timer.is_stopped():
		return
		
	if elapsed_time >= 7:
		game_timer.stop()
		print(">> zatrzymuję audio")
		audio.stop()
		print(">> odtwarzam koniec")
		koniec.play()
		print(">> czy gra koniec? ", koniec.playing)
		await koniec.finished
		print(">> dźwięk zakończony")
		get_tree().quit()

		

	elapsed_time += delta
	var minutes = floor(elapsed_time / 60)
	var seconds = floor(fmod(elapsed_time, 60))
	timer_label.text = "%02d.%02d" % [minutes, seconds]

func generate_map():
	walls.resize(map_width)
	for x in map_width:
		walls[x] = []
		for z in map_depth:
			walls[x].append(false)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1, wall_height, 1)

	for x in map_width:
		for z in map_depth:
			if randf() < wall_chance:
				walls[x][z] = true
				if would_block_surroundings(x, z):
					walls[x][z] = false
				else:
					spawn_wall(wall_mesh, x, z)

func would_block_surroundings(x: int, z: int) -> bool:
	var directions = [
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1)
	]

	for dir in directions:
		var nx = x + int(dir.x)
		var nz = z + int(dir.y)
		if is_in_bounds(nx, nz):
			if is_accessible(nx, nz):
				return false
	return true

func is_in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < map_width and z < map_depth

func is_accessible(x: int, z: int) -> bool:
	if not walls[x][z]:
		return true
	var directions = [
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1)
	]
	for dir in directions:
		var nx = x + int(dir.x)
		var nz = z + int(dir.y)
		if is_in_bounds(nx, nz) and not walls[nx][nz]:
			return true
	return false

func spawn_wall(mesh: Mesh, x: int, z: int):
	var wall := MeshInstance3D.new()
	wall.mesh = mesh
	wall.position = Vector3(x, wall_height / 2.0, z)
	add_child(wall)
	
	var wall_material :=StandardMaterial3D.new()
	
	var wall_texture: Texture2D = load("res://addons/W750Ztz.png")
	wall_material.albedo_texture = wall_texture
	wall.material_override = wall_material

	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1, wall_height, 1)
	collision.shape = box_shape

	static_body.add_child(collision)
	wall.add_child(static_body)

func generate_floor():
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(map_width, 0.1, map_depth)
	floor.mesh = floor_mesh

	# ustawiamy czarny materiał
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0, 0, 0) # RGB = (0, 0, 0)
	floor.material_override = floor_material

	floor.position = Vector3(map_width / 2.0, -0.05, map_depth / 2.0)
	add_child(floor)


	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(map_width, 0.1, map_depth)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor.add_child(floor_body)


func get_random_empty_position() -> Vector2i:
	var empty_positions := []
	for x in map_width:
		for z in map_depth:
			if not walls[x][z]:
				empty_positions.append(Vector2i(x, z))
	if empty_positions.is_empty():
		return Vector2i(-1, -1) # Nie znaleziono pustej pozycji (co nie powinno się zdarzyć przy Twojej logice)
	return empty_positions.pick_random()

func generate_border_wall():
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1, wall_height, 1)
	add_child(wall)
	
	var wall_material :=StandardMaterial3D.new()
	
	var wall_texture: Texture2D = load("res://addons/W750Ztz.png")
	wall_material.albedo_texture = wall_texture
	wall.material_override = wall_material
	
	for x in range(map_width):
		spawn_wall(wall_mesh, x, 0)
		spawn_wall(wall_mesh, x, map_depth - 1)

	for z in range(1, map_depth - 1): 
		spawn_wall(wall_mesh, 0, z)
		spawn_wall(wall_mesh, map_width - 1, z)

	for x in range(map_width):
		walls[x][0] = true
		walls[x][map_depth - 1] = true
	for z in range(map_depth):
		walls[0][z] = true
		walls[map_width - 1][z] = true

func spawn_player_and_door():
	var player_pos = get_random_empty_position()
	if player_pos == Vector2i(-1, -1):
		printerr("Nie udało się znaleźć pustej pozycji dla gracza!")
		return

	var player_instance = player_prefab.instantiate()
	player_instance.position = Vector3(player_pos.x, 0.5, player_pos.y)
	add_child(player_instance)

	var door_pos = find_accessible_door_position(player_pos)
	if door_pos == Vector2i(-1, -1):
		printerr("Nie udało się znaleźć dostępnej pozycji dla drzwi!")
		return

	var door_instance = door_prefab.instantiate()
	door_instance.position = Vector3(door_pos.x, 0.5, door_pos.y) 
	add_child(door_instance)
	
	var kremowka_pos = Vector2i(-1, -1) 
	var attempts = 0
	var max_attempts = 100

	while attempts < max_attempts:
		attempts += 1
		var potential_pos = get_random_empty_position()

		if potential_pos == Vector2i(-1, -1):
			printerr("Nie udało się znaleźć ŻADNEJ pustej pozycji dla kremówki w próbie nr ", attempts)
			continue 


		if potential_pos == player_pos or potential_pos == door_pos:
			continue

		if path_exists(player_pos, potential_pos):
			kremowka_pos = potential_pos
			break 

	if kremowka_pos == Vector2i(-1, -1):
		return
		
	var kremowka_instance = kremowka_prefab.instantiate()
	kremowka_instance.position = Vector3(kremowka_pos.x, 0.5, kremowka_pos.y)
	add_child(kremowka_instance)
	
	door = door_instance
	kremowka = kremowka_instance


func find_accessible_door_position(start_pos: Vector2i) -> Vector2i:
	var empty_positions := []
	for x in map_width:
		for z in map_depth:
			if not walls[x][z] and Vector2i(x, z) != start_pos:
				empty_positions.append(Vector2i(x, z))

	if empty_positions.is_empty():
		return Vector2i(-1, -1)

	for _i in range(100):
		var potential_door_pos = empty_positions.pick_random()
		if path_exists(start_pos, potential_door_pos):
			return potential_door_pos
	return Vector2i(-1, -1)

func path_exists(start: Vector2i, end: Vector2i) -> bool:
	var queue := [start]
	var visited := {}
	visited[start] = true 
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	while not queue.is_empty():
		var current = queue.pop_front()
		if current == end:
			return true

		for dir in directions:
			var next_pos = current + dir
			if is_in_bounds(next_pos.x, next_pos.y) and not walls[next_pos.x][next_pos.y] and not visited.has(next_pos):
				visited[next_pos] = true
				queue.append(next_pos)

	return false
