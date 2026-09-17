class_name WaveController
extends RefCounted
const LANDSCAPES := 3
var landscape := 1
var wave := 1
func roster() -> Array[int]:
 var counts := [wave+2,0 if wave==1 else wave,0 if wave<3 else wave,0]
 if landscape>1:
  counts[0]+=landscape-1
  counts[3]=landscape
 var result: Array[int]=[]
 for kind in range(4):
  for i in range(counts[kind]):
   if result.size()<24: result.append(kind)
 return result
func advance() -> String:
 if wave<4:
  wave+=1
  return "wave"
 if landscape>=LANDSCAPES: return "victory"
 wave=1; landscape+=1
 return "landscape"
