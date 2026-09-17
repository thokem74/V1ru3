class_name Effects
extends Node3D
const LIMIT := 480
var particles: Array[Dictionary] = []
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
# A missing audio device falls back to Dummy. Do not allocate silent playbacks.
var audio_enabled := AudioServer.get_driver_name() != "Dummy"
var pending_sounds: Array[String] = []
var engine_active := false
func _ready() -> void:
 rng.randomize()
 for key in ["thrust","cannon","explosion","infection","missile","bomb","warning"]:
  sounds[key]=load("res://assets/audio/"+key+".wav")
 for i in range(12):
  var voice := AudioStreamPlayer.new()
  voice.volume_db=-17
  add_child(voice); voices.append(voice)
 engine=AudioStreamPlayer.new()
 sounds.thrust.loop_mode=AudioStreamWAV.LOOP_FORWARD
 sounds.thrust.loop_end=int(sounds.thrust.get_length()*sounds.thrust.mix_rate)
 engine.stream=sounds.thrust
 engine.volume_db=-23
 add_child(engine)
func sound(key: String) -> void:
 if audio_enabled and not key in pending_sounds and pending_sounds.size()<12:
  pending_sounds.append(key)
func _process(_dt: float) -> void:
 # Coalesce bursts and start each voice at most once per rendered frame.
 # Simulation can run multiple physics ticks before the audio server consumes commands.
 for voice in voices:
  if pending_sounds.is_empty(): break
  if not voice.playing:
   voice.stream=sounds[pending_sounds.pop_front()]
   voice.play()
 pending_sounds.clear()
func thrust(active: bool) -> void:
 if not audio_enabled or active==engine_active: return
 engine_active=active
 if active: engine.play()
 else: engine.stop()
func burst(p: Vector3, color: Color, count: int = 14, force: float = 9.0, duration: float = 0.8, drift: Vector3 = Vector3.ZERO) -> void:
 for i in range(mini(count,LIMIT-particles.size())):
  var mesh := BoxMesh.new(); mesh.size=Vector3.ONE*rng.randf_range(0.12,0.4)
  var node := Models.part(self,mesh,color,p)
  node.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  var v := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.4,1),rng.randf_range(-1,1))*force+drift
  particles.append({"node":node,"v":v,"life":duration,"max":duration})
func shockwave(p: Vector3) -> void:
 for i in range(80):
  var angle := i*TAU/80
  burst(p,Color("96f7ed"),1,0,1.0,Vector3(cos(angle),0,sin(angle))*145)
func tick(dt: float, reference: Vector3) -> void:
 for i in range(particles.size()-1,-1,-1):
  var item := particles[i]
  item.life-=dt
  if item.life<=0:
   item.node.queue_free(); particles.remove_at(i); continue
  item.v.y-=7*dt
  item.node.position=WrapMath.near(item.node.position+item.v*dt,reference)
  item.node.scale=Vector3.ONE*maxf(0.1,item.life/item.max)
func clear() -> void:
 for item in particles: item.node.queue_free()
 particles.clear()
 thrust(false)
func _exit_tree() -> void:
 for voice in voices:
  voice.stop()
 engine.stop()
