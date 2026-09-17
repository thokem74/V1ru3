## Campaign score, lives, special-weapon stocks, and monotonic extra-life thresholds.
class_name ScoreManager
extends RefCounted
signal score_changed
signal extra_life
const REWARDS := [250, 300, 100, 600]
const FRIENDLY_PENALTY := 75
var score := 0
var lives := 3
var bombs := 2
var missiles := 2
var next_life := 5000

## Apply a signed score change and award each newly crossed 5,000-point life threshold.
## Thresholds only advance, so losing and regaining points cannot farm extra lives.
func add(amount: int) -> void:
	score += amount
	while score >= next_life:
		next_life += 5000
		lives += 1
		bombs += 1
		missiles += 1
		extra_life.emit()
	score_changed.emit()

## Deduct one point per fired round, allowing the score to become negative.
func cannon() -> void:
	add(-1)
