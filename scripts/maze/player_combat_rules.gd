extends RefCounted
## 场景与模拟共用的正常探索能力判断，不读取节点或写存档。
const REGIONS=["maze_entry","fenshui","salt_pool","moss_pool","waterkeeper_cottage"]

static func enabled(combat: Dictionary) -> bool:
 return combat.get("region","maze_entry") in REGIONS and not combat.get("fs01_trial",false) and not combat.has("lock_left")
