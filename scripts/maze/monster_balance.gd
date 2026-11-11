extends RefCounted
## 2026-11-10 按用户要求恢复 B02 调整前怪物数值；保留统一配置读取。
const STATS = {
	"rockmane":{"attack":8,"hp":120,"windup":0.7},
	"mimic_crab":{"attack":5,"hp":28,"interval":2.0,"windup":0.65,"speed":80.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":34.0},
	"blind_scorpion":{"attack":4,"hp":22,"interval":1.8,"windup":0.6,"speed":90.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":42.0},
	"wind_frog":{"attack":6,"hp":96},
	"silverfish":{"attack":4,"hp":20,"interval":1.8,"windup":0.55,"speed":65.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":35.0},
	"thunder_eel":{"attack":5,"hp":30,"interval":2.2,"windup":0.8,"speed":55.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":70.0},
	"slime":{"attack":3,"hp":14,"interval":1.8,"windup":0.45,"speed":85.0,"trigger":150.0,"leash":420.0,"home_limit":600.0,"reach":32.0},
	"snail":{"attack":5,"hp":28,"interval":2.0,"windup":0.6,"speed":65.0,"trigger":140.0,"leash":380.0,"home_limit":520.0,"reach":32.0},
	"beetle":{"attack":4,"hp":21,"interval":1.3,"windup":0.35,"speed":145.0,"trigger":190.0,"leash":500.0,"home_limit":750.0,"reach":32.0},
	"lizard":{"attack":8,"hp":84,"interval":2.2,"windup":0.7,"speed":100.0,"trigger":200.0,"leash":550.0,"home_limit":700.0,"reach":40.0}
}
const EXPERIENCE = {"slime":20,"snail":35,"beetle":35,"lizard":150,"silverfish":25,"thunder_eel":40,"wind_frog":120,"mimic_crab":35,"blind_scorpion":30,"rockmane":150}
