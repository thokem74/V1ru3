extends SceneTree
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
 checks+=1
 if not condition:
  failures+=1; push_error(message)
func _initialize() -> void:
 var delta := WrapMath.delta(Vector3(1020,2,5),Vector3(4,4,1019))
 check(delta.is_equal_approx(Vector3(8,2,-10)),"Shortest wrapped delta across both seams")
 check(WrapMath.canonical(Vector3(-3,10,1028)).is_equal_approx(Vector3(1021,10,4)),"Canonical coordinates")
 var a := TerrainData.new(); a.generate(1987,1)
 var b := TerrainData.new(); b.generate(1987,1)
 check(a.heights==b.heights,"Terrain must be deterministic")
 check(a.land_count>2000 and a.land_count<16384,"Landscape contains both water and land")
 for t in range(0,1024,17):
  check(is_equal_approx(a.generated_height(0,t),a.generated_height(1024,t)),"X seam")
  check(is_equal_approx(a.generated_height(t,0),a.generated_height(t,1024)),"Z seam")
  check(absf(a.surface(Vector3(-0.001,0,t))-a.surface(Vector3(1023.999,0,t)))<0.001,"Wrapped surface query")
 var previous := a.land_count
 for landscape in [2,3]:
  b.generate(1987,landscape)
  check(b.land_count<previous,"Later landscapes contain more water")
  previous=b.land_count
 var land_index := -1
 var water_index := -1
 for i in range(16384):
  if a.land[i]: land_index=i
  else: water_index=i
 a.infect(water_index,100)
 check(a.healthy()==1.0 and a.infection[water_index]==0,"Water excluded from infection")
 a.infect(land_index,100)
 check(a.infection[land_index]==1,"Infection clamps at 1")
 check(absf(a.healthy()-(1.0-1.0/a.land_count))<0.000001,"Infection denominator is land only")
 a.infect(land_index,-100)
 check(a.infection[land_index]==0 and is_equal_approx(a.healthy(),1),"Infection clamps at zero")
 var score := ScoreManager.new()
 score.cannon(); check(score.score==-1,"Cannon costs a point even at zero score")
 score.add(10001)
 check(score.lives==5 and score.bombs==4 and score.missiles==4 and score.next_life==15000,"Multiple extra-life thresholds")
 score.add(-6000); score.add(6000)
 check(score.lives==5,"Threshold rewards cannot be farmed by losing score")
 var waves := WaveController.new()
 check(waves.roster()==[0,0,0],"First wave consists of three seeders")
 for i in range(3): check(waves.advance()=="wave","Four waves per landscape")
 check(waves.wave==4 and waves.landscape==1,"No early landscape advance")
 check(waves.advance()=="landscape" and waves.landscape==2 and waves.wave==1,"New landscape after fourth wave")
 check(3 in waves.roster(),"Bombers introduced on landscape two")
 for i in range(7): waves.advance()
 check(waves.landscape==3 and waves.wave==4 and waves.advance()=="victory","Campaign has a victory endpoint")
 print("LOGIC: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
