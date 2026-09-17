class_name GameHUD
extends Control
const INK := Color("d9ece0")
const MUTED := Color("8ca9ac")
const AQUA := Color("8ee5cf")
const GOLD := Color("efd295")
const PANEL := Color(0.027,0.063,0.083,0.91)
var game: Node3D
var font: Font=ThemeDB.fallback_font
var radar: ImageTexture
var large_map := false
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func text(at: Vector2, words: String, size_px: int = 18, color: Color = INK) -> void:
 draw_string(font,at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func panel(rect: Rect2) -> void:
 draw_rect(rect,PANEL)
 draw_rect(rect,Color("43616b"),false,1)
func refresh_radar() -> void:
 if game.terrain==null or game.scenery==null: return
 var img := Image.create(128,128,false,Image.FORMAT_RGB8)
 for z in range(128):
  for x in range(128):
   var i := z*128+x
   img.set_pixel(x,z,game.terrain.color_at(i) if game.scenery.covered[i] else Color("101e28"))
 if radar==null: radar=ImageTexture.create_from_image(img)
 else: radar.update(img)
func map_point(p: Vector3, rect: Rect2) -> Vector2:
 return rect.position+Vector2(fposmod(p.x,1024),fposmod(p.z,1024))/1024*rect.size
func draw_radar(rect: Rect2) -> void:
 panel(Rect2(rect.position-Vector2(8,30),rect.size+Vector2(16,54)))
 text(rect.position-Vector2(0,10),"TACTICAL / %02d"%game.waves.landscape,14,AQUA)
 if radar: draw_texture_rect(radar,rect,false)
 for i in range(1,4):
  var offset := rect.size.x*i/4
  draw_line(rect.position+Vector2(offset,0),rect.position+Vector2(offset,rect.size.y),Color(0.6,0.85,0.8,0.12))
  draw_line(rect.position+Vector2(0,offset),rect.position+Vector2(rect.size.x,offset),Color(0.6,0.85,0.8,0.12))
 var home := map_point(game.terrain.home,rect)
 draw_rect(Rect2(home-Vector2.ONE*3,Vector2.ONE*6),GOLD,false,2)
 for tower in game.scenery.towers:
  if tower.alive: draw_circle(map_point(tower.p,rect),1.5,MUTED)
 for enemy in game.enemies:
  if game.scenery.covered[game.terrain.tile(enemy.position)]:
   draw_circle(map_point(enemy.position,rect),3,Color("ff6875"))
 var pos := map_point(game.player.position,rect)
 draw_circle(pos,3,Color.WHITE)
 draw_line(pos,pos+Vector2(-sin(game.player.yaw),-cos(game.player.yaw))*10,Color.WHITE,2)
 text(rect.position+Vector2(0,rect.size.y+17),"TAB  EXPAND     ◇ HOME",12,MUTED)
func _draw() -> void:
 if game.terrain==null: return
 # Design coordinates remain stable under window resizing.
 draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,720))
 if game.mode=="title":
  title_screen(); return
 draw_radar(Rect2(26,56,176,176))
 panel(Rect2(230,18,1024,66))
 text(Vector2(248,40),"VECTOR PLAGUE",14,AQUA)
 text(Vector2(248,68),"%07d"%game.score.score,25,GOLD)
 text(Vector2(430,41),"CRAFT",12,MUTED)
 text(Vector2(430,67),"%02d"%game.score.lives,24)
 text(Vector2(530,41),"LANDSCAPE / WAVE",12,MUTED)
 text(Vector2(530,67),"%02d / %02d"%[game.waves.landscape,game.waves.wave],24)
 text(Vector2(750,41),"HEALTHY LAND",12,MUTED)
 text(Vector2(750,67),"%05.1f %%"%(game.terrain.healthy()*100),24,AQUA)
 text(Vector2(966,41),"HOSTILES",12,MUTED)
 text(Vector2(966,67),"%02d"%game.enemies.size(),24,Color("f18e80"))
 text(Vector2(1100,41),"INFECTION",12,MUTED)
 text(Vector2(1100,67),"%.1f %%"%((1-game.terrain.healthy())*100),24)
 draw_flight_hud()
 if large_map: draw_radar(Rect2(414,138,448,448))
 if game.mode!="playing": modal()
func draw_flight_hud() -> void:
 var p: LanderController=game.player
 panel(Rect2(26,618,1228,78))
 text(Vector2(44,640),"FUEL",12,MUTED)
 draw_rect(Rect2(44,653,170,12),Color("273f4a"))
 draw_rect(Rect2(44,653,p.fuel*1.7,12),AQUA if p.fuel>20 else Color("f17e68"))
 text(Vector2(222,666),"%03d"%p.fuel,18)
 text(Vector2(298,642),"ALTITUDE",12,MUTED)
 text(Vector2(298,674),"%03dm"%p.altitude(),24)
 text(Vector2(438,642),"SPEED",12,MUTED)
 text(Vector2(438,674),"%02d m/s"%p.velocity.length(),24)
 text(Vector2(608,642),"M / MISSILE",12,MUTED)
 text(Vector2(608,674),"%02d"%game.score.missiles,24)
 text(Vector2(758,642),"B / SMART BOMB",12,MUTED)
 text(Vector2(758,674),"%02d"%game.score.bombs,24)
 text(Vector2(958,642),"LMB  THRUST    RMB  CANNON",14,AQUA)
 text(Vector2(958,675),"R  UPRIGHT    ESC  PAUSE",14,MUTED)
 var status := ""
 if p.landed: status="REFUELING • KEEP UPRIGHT TO LAND"
 elif p.position.y>=p.flight_ceiling: status="THRUST CEILING"
 elif p.fuel<20: status="LOW FUEL • RETURN TO HOME"
 if game.notice_time>0: status=game.notice
 if not status.is_empty():
  var width := font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
  panel(Rect2(640-width/2-20,560,width+40,38))
  text(Vector2(640-width/2,586),status,20,GOLD)
 # Virtual mouse instrument: the small inner ring is the safe landing attitude.
 var center := Vector2(1176,502)
 draw_circle(center,52,Color(0.02,0.05,0.07,0.75))
 draw_arc(center,51,0,TAU,48,MUTED,1)
 draw_arc(center,24,0,TAU,32,Color("416e76"),1)
 draw_line(center-Vector2(56,0),center+Vector2(56,0),MUTED)
 draw_line(center-Vector2(0,56),center+Vector2(0,56),MUTED)
 draw_circle(center+p.virtual_mouse_offset/p.virtual_mouse_radius*50,4,GOLD)
 text(Vector2(1126,576),"TILT %03d°"%rad_to_deg(p.tilt),14)
 if p.alive:
  var nose := p.position-p.basis.z*90
  if not game.camera.is_position_behind(nose):
   var aim: Vector2 = game.camera.unproject_position(nose)*Vector2(1280,720)/size
   if Rect2(220,95,880,440).has_point(aim):
    draw_arc(aim,9,0,TAU,16,Color(0.9,1,0.85,0.7),1)
    draw_line(aim-Vector2(14,0),aim-Vector2(5,0),INK)
    draw_line(aim+Vector2(5,0),aim+Vector2(14,0),INK)
  for enemy in game.enemies:
   var distance := WrapMath.delta(p.position,enemy.position).length()
   if distance>330 or game.camera.is_position_behind(enemy.position): continue
   var screen: Vector2 = game.camera.unproject_position(enemy.position)*Vector2(1280,720)/size
   if Rect2(220,100,865,430).has_point(screen):
    draw_rect(Rect2(screen-Vector2(14,12),Vector2(28,24)),Color(1,0.55,0.5,0.7),false)
    text(screen+Vector2(17,4),"%dm"%distance,12,Color("ffb49d"))
func title_screen() -> void:
 draw_rect(Rect2(0,0,1280,720),Color(0.01,0.04,0.055,0.4))
 panel(Rect2(66,64,625,590))
 text(Vector2(98,111),"O R B I T A L   D E F E N C E   /   1 9 8 7",15,AQUA)
 text(Vector2(94,187),"VECTOR",66,INK)
 text(Vector2(94,251),"PLAGUE",66,GOLD)
 text(Vector2(98,296),"ONE CRAFT.  THREE LANDSCAPES.  NO SECOND EARTH.",16,AQUA)
 text(Vector2(98,346),"Destroy every invader. Keep the living terrain green.",19)
 text(Vector2(98,376),"Four waves per landscape. Survive all twelve to win.",19)
 text(Vector2(98,421),"MOVE MOUSE  lean toward the pointer; momentum stays",17,MUTED)
 text(Vector2(98,451),"LEFT BUTTON  thrust        RIGHT BUTTON  cannon",17,MUTED)
 text(Vector2(98,481),"R  return upright             M  missile     B  smart bomb",17,MUTED)
 text(Vector2(98,511),"Land gently on the marked home pad to refuel.",17,MUTED)
 draw_rect(Rect2(98,554,558,57),AQUA)
 text(Vector2(180,592),"ENTER  /  CLICK TO LAUNCH",24,Color("102c35"))
 panel(Rect2(718,540,516,156))
 text(Vector2(740,577),"FLIGHT SCHOOL",17,AQUA)
 text(Vector2(740,608),"Lift straight up. Use small mouse movements.",18,INK)
 text(Vector2(740,637),"Tilt to travel. Counter-tilt to brake. R to level.",18,INK)
 text(Vector2(740,674),"LOCAL RECORD   %07d"%game.best_score,16,MUTED)
func modal() -> void:
 draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.04,0.65))
 panel(Rect2(340,184,600,340))
 var headline := "FLIGHT PAUSED"
 var detail := "The simulation is paused. Your craft is safe here."
 var info := "WASD / ARROWS tilt & heading · SPACE thrust · F / CTRL fire"
 var prompt := "ENTER / CLICK TO RESUME"
 match game.mode:
  "results":
   headline="LANDSCAPE CLEAR" if game.waves.wave==4 else "WAVE CLEAR"
   detail="Healthy land  %.1f%%   /   Survival bonus  +%d"%[game.terrain.healthy()*100,game.result_bonus]
   info="Fuel restored at home. Score, lives and weapons carry forward."
   prompt="ENTER / CLICK TO CONTINUE"
  "gameover":
   headline="GAME OVER"
   detail=game.loss_reason+"   /   SCORE %d"%game.score.score
   info="Small corrections. Conserve fuel. Protect your radar towers."
   prompt="ENTER / CLICK TO TRY AGAIN"
  "victory":
   headline="THE LAND SURVIVES"
   detail="Three landscapes secured. Final score: %d"%game.score.score
   info="Transmission complete. Every living tile was worth defending."
   prompt="ENTER / CLICK FOR A NEW CAMPAIGN"
 text(Vector2(376,246),headline,34,AQUA)
 text(Vector2(376,300),detail,19,GOLD)
 text(Vector2(376,346),info,15,MUTED)
 if game.mode=="pause": text(Vector2(376,382),"TAB radar  ·  R upright  ·  M missile  ·  B bomb  ·  ESC resume",16)
 text(Vector2(376,468),prompt,23,INK)
