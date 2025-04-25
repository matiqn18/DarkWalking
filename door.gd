extends Node3D

@onready var area: Area3D = $LeftDoor/Area3D
#@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var main: AudioStreamPlayer = $"../AudioStreamPlayer"
@onready var door_mesh: MeshInstance3D = $LeftDoor

var aktywne = false

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.monitoring = false 

func odblokuj():
	aktywne = true
	area.monitoring = true
	var nowa_tekstura: Texture2D = load("res://addons/open_door.png")
	var nowy_material := StandardMaterial3D.new()
	nowy_material.albedo_texture = nowa_tekstura
	nowy_material.uv1_scale = Vector3(3.0, 2.0, 2.1)
	door_mesh.material_override = nowy_material

func _on_body_entered(body):
	if aktywne and body.is_in_group("player"):
		main.stop()
		aktywne = false
		#audio.play()
		#area.monitoring = false
		#await audio.finished
		queue_free()
		get_tree().quit()
		
