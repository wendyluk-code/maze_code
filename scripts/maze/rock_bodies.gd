extends RefCounted
const Boss=preload("res://data/maze/salt_boss.gd")
const Existing=preload("res://scripts/maze/fenshui_bodies.gd")
static func footprint(id: String) -> Vector2:
 return Existing.footprint(id)
static func step(run: Dictionary,id: String,origin: Vector2,target: Vector2,include_hero: bool=true) -> bool:
 return Existing.step(run,id,origin,target,include_hero)
static func move(run: Dictionary,id: String,origin: Vector2,target: Vector2,include_hero: bool=true) -> Vector2:
 return Existing.move(run,id,origin,target,include_hero)
static func hero_contact(origin: Vector2,target: Vector2,hero: Vector2) -> bool:
 var size:=footprint(Boss.ID)+footprint("hero")
 return Geometry2D.get_closest_point_to_segment(hero/size,origin/size,target/size).distance_to(hero/size)<=1.0

