extends Node3D 

signal collected

@onready var area_3d: Area3D = $"Kremówkawidok/AreaKremówka"
@onready var pickup_sound: AudioStreamPlayer = $"Kremówkawidok/AreaKremówka/CollisionShape3D/AudioStreamPlayer"
@onready var main: AudioStreamPlayer = $"../AudioStreamPlayer"

func _ready():
	area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		pickup_sound.play()
		await pickup_sound.finished
		collected.emit() 
		area_3d.get_node("CollisionShape3D").disabled = true
		hide()
