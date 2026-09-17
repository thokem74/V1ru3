class_name ScoreManager
extends RefCounted
signal score_changed
signal extra_life
const REWARDS := [250,300,100,600]
const FRIENDLY_PENALTY := 75
var score := 0
var lives := 3
var bombs := 2
var missiles := 2
var next_life := 5000
func add(amount: int) -> void:
 score += amount
 while score>=next_life:
  next_life+=5000
  lives+=1; bombs+=1; missiles+=1
  extra_life.emit()
 score_changed.emit()
func cannon() -> void: add(-1)
