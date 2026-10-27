extends SceneTree
const Salt=preload("res://data/maze/salt_pool_roads.gd")
func _initialize():
 call_deferred('_run')
func _run():
 var seen={}
 var queue: Array[Vector2i]=[]
 var start=Vector2i(Salt.SPAWN/4.0)
 queue.append(start)
 seen[start]=true
 var index=0
 while index<queue.size():
  var p=queue[index]
  index+=1
  for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
   var q=p+delta
   if not seen.has(q) and Salt.is_walkable(Vector2(q)*4.0) and Salt.move_on_road(Vector2(p)*4.0,Vector2(delta)*4.0).distance_to(Vector2(q)*4.0)<0.01:
    seen[q]=true
    queue.append(q)
 var unreachable=0
 for y in range(1,243):
  for x in range(1,404):
   var p=Vector2i(x,y)
   if Salt.is_walkable(Vector2(p)*4.0) and not seen.has(p):
    unreachable+=1
    print('UNREACHABLE ',Vector2(p)*4.0)
 print("SALT_CONNECTIVITY reached=",seen.size()," unreachable=",unreachable)
 quit(1 if unreachable else 0)



